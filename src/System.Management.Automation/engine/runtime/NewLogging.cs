// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

using System;
using System.Collections;
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
        static ThreadLocal<System.Net.Http.HttpClient> tlsClient = new ThreadLocal<System.Net.Http.HttpClient>(()=>{
                var client = new System.Net.Http.HttpClient();
                client.DefaultRequestHeaders
                    .Accept
                    .Add(new MediaTypeWithQualityHeaderValue("application/json"));
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
        static string LogType = "PowerShellThree";

        // You can use an optional field to specify the timestamp from the data. If the time field is not specified, Azure Monitor assumes the time is the message ingestion time
        static string TimeStampField = "";

        internal class LoggingParams{
            internal string ScriptBlockText{get;set;}
            internal Guid ScriptBlockId{get;set;}
            internal string File{get;set;}
        }

        public static void PostLog(string readableScriptBlock,Guid scriptBlockId, string file)
        {
            var loggingParams = new LoggingParams() {
                ScriptBlockText = readableScriptBlock,
                ScriptBlockId =scriptBlockId,
                File = file
            };

            Action<object> action = (object loggingParamsObj)=>{
                LoggingParams loggingParams = loggingParamsObj as LoggingParams;
                Hashtable[] headers = {new Hashtable()};
                headers[0].Add("PsMachineName", Environment.MachineName);
                headers[0].Add("PsProcessId", pid.ToString());
                headers[0].Add("PsScriptBlockId", loggingParams.ScriptBlockId.ToString());
                headers[0].Add("File", loggingParams.File);
                //headers[0].Add("OriginalScriptBlock", originalScriptBlock);
                headers[0].Add("ScriptBlockText", loggingParams.ScriptBlockText);
                var json =  JsonConvert.SerializeObject(headers);
                            // Create a hash for the API signature
                var datestring = DateTime.UtcNow.ToString("r");
                var jsonBytes = Encoding.UTF8.GetBytes(json);
                string stringToHash = "POST\n" + jsonBytes.Length + "\napplication/json\n" + "x-ms-date:" + datestring + "\n/api/logs";
                string hashedString = BuildSignature(stringToHash, sharedKey);
                string signature = "SharedKey " + customerId + ":" + hashedString;

                PostData(signature, datestring, json);
            };
            var task = new Task(action,loggingParams);
            task.Start();
            //task.Wait();
        }

        // Build the API signature
        public static string BuildSignature(string message, string secret)
        {
            var encoding = new System.Text.ASCIIEncoding();
            byte[] keyByte = Convert.FromBase64String(secret);
            byte[] messageBytes = encoding.GetBytes(message);
            using (var hmacsha256 = new HMACSHA256(keyByte))
            {
                byte[] hash = hmacsha256.ComputeHash(messageBytes);
                return Convert.ToBase64String(hash);
            }
        }

        // Send a request to the POST API endpoint
        public static void PostData(string signature, string date, string json)
        {
            try
            {
                string url = "https://" + customerId + ".ods.opinsights.azure.com/api/logs?api-version=2016-04-01";

                System.Net.Http.HttpClient client = tlsClient.Value;

                System.Net.Http.HttpRequestMessage request = new HttpRequestMessage(HttpMethod.Post,new Uri(url));
                request.Content = new StringContent(json, Encoding.UTF8, "application/json");
                request.Headers.Add("x-ms-date", date);
                request.Headers.Add("Authorization", signature);
                request.Headers.Add("time-generated-field", TimeStampField);
                Task<System.Net.Http.HttpResponseMessage> response = client.SendAsync(request);

                System.Net.Http.HttpContent responseContent = response.Result.Content;
                string result = responseContent.ReadAsStringAsync().Result;
                //Console.WriteLine("Return Result: " + result + "("+ response.Result.StatusCode.ToString()+")");
            }
            catch (Exception excep)
            {
                Console.WriteLine("API Post Exception: " + excep.Message);
            }
        }
    }
}
