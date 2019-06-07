param(
    [switch]$PerfTest,
    [switch]$AccuracyTest,
    [int]$Iterations=100,
    [switch]$LargScriptBlockTest,
    [int]$Segments=2
    )
if($PerfTest.IsPresent)
{
    $times = 1..$Iterations | ForEach-Object{measure-command { $null = Get-Command}}
    $times | measure-object -Average -Property TotalMilliseconds
}
<#
Query

PowerShell_ScriptBlock_Log_Prototype_10_CL
| where ScriptBlockText_s <> "prompt" and
    (ScriptBlockText_s startswith "function PSConsoleHostReadLine") == "False" and
    (ScriptBlockText_s startswith "{ Set-StrictMode -Version 1;") == "False"
| sort by UtcTime_t, BatchOrder_d  desc
| project ScriptBlockText_s, CommandName_s, ScriptBlockHash_s, ParentScriptBlockHash_s, File_s, PsProcessId_s, Computer, User_s, UtcTime_t, PartNumber_d, NumberOfParts_d, BatchOrder_d
| limit 300

#>
<#
Create setloggingenv.ps1 with the following contents

# get workspaceid from properties
$env:CustomerId = 'Put the workspace id here'

# get the sharedKey from Advanced Setting -> Connected Sources - > Windows Server -> Primare or Secondary Key
$env:sharedKey = 'put share key here'

#>
."$PSScriptRoot\setloggingenv.ps1"
$env:NewLogging = "True"
if($PerfTest.IsPresent)
{
    $times2 = 1..$Iterations | ForEach-Object{measure-command { $null = Get-Command}}
    $times2 | measure-object -Average -Property TotalMilliseconds
}
if($AccuracyTest.IsPresent)
{
    $max= Get-Random -Minimum $Iterations -Maximum ($Iterations+10)
    write-host "running $max iterations"
    1..$max| ForEach-Object{
        Invoke-Expression('$null='+$_)
        #start-Sleep -Milliseconds 50
    }
}
if($LargScriptBlockTest.IsPresent)
{
    $sb=[System.Text.StringBuilder]::new()
    $sbLine = @'
    $null=Invoke-Expression('d'+"i"+'r');
    $null=Invoke-Expression('$p'+"i"+'d');
    $null=ge`T`-cOMmA`ND get-*;
'@
    while($sb.Length -lt (10000*($segments-1)))
    {
        $null=$sb.AppendLine($sbLine)
    }
    & ([scriptblock]::Create($sb.ToString()))
}

Invoke-Expression('$p'+"i"+'d')

$null=ge`T`-cOMmA`ND get-*
$null=Invoke-Expression('d'+"i"+'r')

