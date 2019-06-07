param(
    [switch]$PerfTest,
    [switch]$AccuracyTest,
    [int]$Iterations=100
    )
if($PerfTest.IsPresent)
{
    $times = 1..$Iterations | ForEach-Object{measure-command { $null = Get-Command}}
    $times | measure-object -Average -Property TotalMilliseconds
}
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
        Start-Sleep -Milliseconds 50
    }
}


Invoke-Expression('$p'+"i"+'d')

$null=ge`T`-cOMmA`ND get-*
$null=Invoke-Expression('d'+"i"+'r')

