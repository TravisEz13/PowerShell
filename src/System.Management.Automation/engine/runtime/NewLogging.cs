// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Newtonsoft.Json;

namespace System.Management.Automation
{
    class NewLogging
    {
        static string hmacTemplate = "POST\n{0}\n{1}\nx-ms-date:{2}\n/api/logs";
        static ThreadLocal<System.Net.Http.HttpClient> tlsClient = new ThreadLocal<System.Net.Http.HttpClient>(()=>{
                var client = new System.Net.Http.HttpClient();
                client.DefaultRequestHeaders
                    .Accept
                    .Add(new MediaTypeWithQualityHeaderValue("application/json"));
                //client.DefaultRequestHeaders.Add("Accept", "application/json");
                client.DefaultRequestHeaders.Add("Log-Type", LogType);
                return client;
            });
        // An example JSON object, with key/value pairs
        // static string json = @"[{""OriginalScriptBlock"":""DemoValue1"",""DemoField2"":""DemoValue2""},{""DemoField3"":""DemoValue3"",""DemoField4"":""DemoValue4""}]";

        // Update customerId to your Log Analytics workspace ID
        static string customerId {
            get {
                return System.Environment.GetEnvironmentVariable("CustomerId");
            }
        }

        static Process currentProcess = Process.GetCurrentProcess();

        static int pid {
            get {
                return currentProcess.Id;
            }
        }


        // For sharedKey, use either the primary or the secondary Connected Sources client authentication key
        static string sharedKey {
            get {
                return System.Environment.GetEnvironmentVariable("sharedKey");
            }
        }

        // LogType is name of the event type that is being submitted to Azure Monitor
        static string LogType = "PowerShell_ScriptBlock_Log_Prototype_9";

        // You can use an optional field to specify the timestamp from the data. If the time field is not specified, Azure Monitor assumes the time is the message ingestion time
        static string TimeStampField = "";

        static ConcurrentQueue<LoggingParams> loggingQueue = new ConcurrentQueue<LoggingParams>();

        static Task loggingTask = null;

        internal class LoggingParams{
            internal string ScriptBlockText{get;set;}
            internal string ScriptBlockHash{get;set;}
            internal string File{get;set;}
            internal string ParentScriptBlockHash{get;set;}
            internal int PartNumber{get;set;}
            internal int NumberOfParts{get;set;}
            internal DateTime UtcTime{get;set;}
            internal string CommandName{get;set;}
        }

        // Maximum size of Azure Log Analytics events is 32kb. Split a message if it is larger than 20k (Unicode) characters.
        // https://docs.microsoft.com/en-us/azure/azure-monitor/platform/data-collector-api
        static int maxSegmentChars = 10000;
        public static void PostLog(string scriptBlockText, string file, string scriptBlockHash, string parentScriptBlockHash, DateTime utcTime, string commandName)
        {

            if (scriptBlockText.Length < maxSegmentChars)
            {
                var loggingParams = new LoggingParams() {
                    ScriptBlockText = scriptBlockText,
                    ScriptBlockHash = scriptBlockHash,
                    File = file,
                    ParentScriptBlockHash = parentScriptBlockHash,
                    PartNumber = 1,
                    NumberOfParts = 1,
                    UtcTime=utcTime,
                    CommandName= commandName
                };
                loggingQueue.Enqueue(loggingParams);
                StartLoggingTask();
                //PostLog(loggingParams);
            }
            else
            {
                // But split the segments into random sizes (half the maxSegmentChars + between 0 and an extra half the maxSegmentChars)
                // so that attackers can't creatively force their scripts to span well-known
                // segments (making simple rules less reliable).
                int segmentSize = (maxSegmentChars /2) + (new Random()).Next(maxSegmentChars /2);
                int segments = (int)Math.Floor((double)(scriptBlockText.Length / segmentSize)) + 1;
                int currentLocation = 0;
                int currentSegmentSize = 0;

                for (int segment = 0; segment < segments; segment++)
                {
                    currentLocation = segment * segmentSize;
                    currentSegmentSize = Math.Min(segmentSize, scriptBlockText.Length - currentLocation);

                    string textToLog = scriptBlockText.Substring(currentLocation, currentSegmentSize);
                    var loggingParams = new LoggingParams() {
                        ScriptBlockText = textToLog,
                        File = file,
                        ParentScriptBlockHash = parentScriptBlockHash,
                        PartNumber = segment,
                        NumberOfParts = segments,
                        UtcTime=utcTime,
                        CommandName= commandName
                    };
                    loggingQueue.Enqueue(loggingParams);
                    StartLoggingTask();

                    //PostLog(loggingParams);
                }
            }
        }

        public static void StartLoggingTask()
        {
            if(loggingTask == null ||
                (loggingTask.Status != TaskStatus.Running &&
                loggingTask.Status != TaskStatus.Created &&
                loggingTask.Status != TaskStatus.WaitingForActivation &&
                loggingTask.Status != TaskStatus.WaitingToRun))
            {
                loggingTask = new Task(LoggingImpl);
                loggingTask.Start();
                return;
            }
        }

        static int maxEventsPerBatch = 100;
        static void LoggingImpl()
        {
            List<LoggingParams> readyToLog = new List<LoggingParams>();
            int waits = 5;
            while (waits > 0)
            {
                while(!loggingQueue.IsEmpty)
                {
                    waits = 5;
                    loggingQueue.TryDequeue(out LoggingParams itemToLog);
                    if(itemToLog != null)
                    {
                        readyToLog.Add(itemToLog);
                    }
                    if(readyToLog.Count >= maxEventsPerBatch)
                    {
                        PostLog(readyToLog);
                        readyToLog.Clear();
                    }
                }
                if(readyToLog.Count > 0 && waits < 5)
                {
                    PostLog(readyToLog);
                    readyToLog.Clear();
                }

                waits--;
                Thread.Sleep(1000);
            }
        }

        public static void PostLog(IEnumerable<LoggingParams> loggingParamsArray)
        {
                // Maximum size of ETW events is 64kb. Split a message if it is larger than 20k (Unicode) characters.
                    List<Hashtable> hashtables = new List<Hashtable>();
                    foreach(LoggingParams loggingParams in loggingParamsArray)
                    {
                        Hashtable  fields =  new Hashtable();
                        fields.Add("Computer", Environment.MachineName);
                        fields.Add("User", Environment.UserName);
                        //fields[0].Add("PsMachineName", Environment.MachineName);
                        fields.Add("PsProcessId", pid.ToString());
                        if(!string.IsNullOrEmpty(loggingParams.File))
                        {
                            fields.Add("File", loggingParams.File);
                        }

                        //fields.Add("OriginalScriptBlock", originalScriptBlock);
                        fields.Add("ScriptBlockText", loggingParams.ScriptBlockText);
                        fields.Add("PartNumber", loggingParams.PartNumber);
                        fields.Add("NumberOfParts", loggingParams.PartNumber);

                        fields.Add("ScriptBlockHash", loggingParams.ScriptBlockHash);
                        fields.Add("UtcTime", loggingParams.UtcTime);
                        fields.Add("CommandName",loggingParams.CommandName);

                        if(!string.IsNullOrEmpty(loggingParams.ParentScriptBlockHash))
                        {
                            fields.Add("ParentScriptBlockHash", loggingParams.ParentScriptBlockHash);
                        }
                        hashtables.Add(fields);
                    }

                    var json =  JsonConvert.SerializeObject(hashtables.ToArray());
                    var datestring = DateTime.UtcNow.ToString("r");

                    PostData(datestring, json);
        }

        // Build the API signature
        public static string BuildSignature(string message, string secret)
        {
            var encoding = new System.Text.UTF8Encoding();
            byte[] keyByte = Convert.FromBase64String(secret);
            byte[] messageBytes = encoding.GetBytes(message);
            using (var hmacsha256 = new HMACSHA256(keyByte))
            {
                byte[] hash = hmacsha256.ComputeHash(messageBytes);
                return Convert.ToBase64String(hash);
            }
        }

        // Send a request to the POST API endpoint
        public static void PostData(string date, string json)
        {
            try
            {

                string url = "https://" + customerId + ".ods.opinsights.azure.com/api/logs?api-version=2016-04-01";

                System.Net.Http.HttpClient client = tlsClient.Value;

                System.Net.Http.HttpRequestMessage request = new HttpRequestMessage(HttpMethod.Post,new Uri(url));
                request.Content = new StringContent(json, Encoding.UTF8, "application/json");

                // Create a hash for the API signature
                var jsonBytes = Encoding.UTF8.GetBytes(json);
                string stringToHash = string.Format(hmacTemplate,jsonBytes.Length,request.Content.Headers.ContentType.ToString(), date);
                string hashedString = BuildSignature(stringToHash, sharedKey);
                string signature = "SharedKey " + customerId + ":" + hashedString;

                request.Headers.Add("x-ms-date", date);
                request.Headers.Add("Authorization", signature);
                request.Headers.Add("time-generated-field", TimeStampField);
                Task<System.Net.Http.HttpResponseMessage> response = client.SendAsync(request);

                System.Net.Http.HttpContent responseContent = response.Result.Content;
                string result = responseContent.ReadAsStringAsync().Result;
                if(response.Result.StatusCode != System.Net.HttpStatusCode.OK)
                {
                    Console.WriteLine("Return Result: " + result + "("+ response.Result.StatusCode.ToString()+")");
                }
            }
            catch (Exception excep)
            {
                Console.WriteLine("API Post Exception: " + excep.Message);
            }
        }
    }
}
