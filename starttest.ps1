param(
    [switch]$PerfTest,
    [switch]$AccuracyTest,
    [int]$Iterations=100,
    [switch]$LargScriptBlockTest,
    [int]$Segments=2,
    [switch]$SkipEnable
    [ValidateSet('azla','splunk')]
    [string]$Provider="azla"
    )
if($PerfTest.IsPresent)
{
    $times = 1..$Iterations | ForEach-Object{measure-command { $null = Get-Command}}
    $times | measure-object -Average -Property TotalMilliseconds
}
<#
Query

PowerShell_ScriptBlock_Log_Prototype_11_CL
| where ScriptBlockText_s <> "prompt" and
    (ScriptBlockText_s startswith "function PSConsoleHostReadLine") == "False" and
    (ScriptBlockText_s startswith "{ Set-StrictMode -Version 1;") == "False"
| sort by UtcTime_t, BatchOrder_d  desc
| project ScriptBlockText_s, CommandName_s, ScriptBlockHash_s, ParentScriptBlockHash_s, File_s, PsProcessId_s, Computer, User_s, UtcTime_t, PartNumber_d, NumberOfParts_d, BatchOrder_d, RunspaceId_d, RunspaceName_s

#>
<#
Create setloggingenv.ps1 with the following contents

# get workspaceid from properties
$env:CustomerId = 'Put the workspace id here'

# get the sharedKey from Advanced Setting -> Connected Sources - > Windows Server -> Primare or Secondary Key
$env:sharedKey = 'put share key here'

#>
if(!$SkipEnable.IsPresent)
{
    ."$PSScriptRoot\setloggingenv-$provider.ps1"
}
$env:NewLogging = "$provider"
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
$blocks=@{}
if($LargScriptBlockTest.IsPresent)
{
    $utf8 = [System.Text.UTF8Encoding]::new()
    $sb=[System.Text.StringBuilder]::new()
    $sbLine = '$null="'
    Write-Verbose "Generating sb Line..." -Verbose
    128513..128591| ForEach-Object {
        $charCreateScriptBlock=[scriptblock]::create(('write-output `u{0}{1:x}{2}' -f '{', $_, '}'))
        &$charCreateScriptBlock
    } | ForEach-Object {
        $sbLine += $_
    }
    128640..128704| ForEach-Object {
        $charCreateScriptBlock=[scriptblock]::create(('write-output `u{0}{1:x}{2}' -f '{', $_, '}'))
        &$charCreateScriptBlock
    } | ForEach-Object {
        $sbLine += $_
    }
    $sbLine+='";'
    $blocks[0] = $sbLine
    $null=$sb.AppendLine($sbLine);
    #Write-Host $sbLine
    $mbSize = (32768*$segments)/1mb
    Write-Verbose "Generating sb of $mbSize MB ..." -Verbose
    $powerToUse = 2

    while($utf8.GetByteCount($sb.ToString()) -lt (32768*($segments-1)))
    {
        $string = $sb.ToString()
        $size = $utf8.GetByteCount($string)
        #Write-Verbose "script of $($size / 1MB) MB ..." -Verbose
        $pow = [MATH]::Round([Math]::Log($size,$powerToUse))
        #Write-Verbose "updating $pow" -Verbose
        $blocks[$pow] = $string
        $remainingSize = (32768*($segments-1)) - $size
        $remainingPow = [Math]::Floor( [Math]::Log($remainingSize,$powerToUse))
        if($remainingPow -gt 0)
        {
            #$remainingPow--
        }
        #Write-Verbose "should add $remainingPow" -Verbose


        if($blocks.ContainsKey($remainingPow))
        {
            #Write-Verbose "adding $remainingPow" -Verbose
            $null=$sb.AppendLine($blocks.$remainingPow)
        }
        else{
            $maxPow = ($blocks.Keys | Where-Object { $_ -le $remainingPow} | Measure-Object -Maximum).Maximum
            #Write-Verbose "adding max- $maxPow" -Verbose
            $null=$sb.AppendLine($blocks.$maxPow)
        }
    }
    $sbString = $sb.ToString()
    $Global:LargeSbString = $sbString
    Write-Verbose "Executing script of $([int] ($utf8.GetByteCount($sbString) / 1MB)) MB ..." -Verbose
    & ([scriptblock]::Create($sbString))
}

Invoke-Expression('$p'+"i"+'d')

$null=ge`T`-cOMmA`ND get-*; $null=ge`T`-module
$null=Invoke-Expression('d'+"i"+'r')

