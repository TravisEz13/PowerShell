# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
Describe "Standard IO Mediator Basic tests" -Tags @('Feature') {
    BeforeAll {
        function Test-Elevated {
            [CmdletBinding()]
            [OutputType([bool])]
            Param()

            # if the current Powershell session was called with administrator privileges,
            # the Administrator Group's well-known SID will show up in the Groups for the current identity.
            # Note that the SID won't show up unless the process is elevated.
            return (([Security.Principal.WindowsIdentity]::GetCurrent()).Groups -contains "S-1-5-32-544")
        }

        $typeTable = [System.Management.Automation.Runspaces.TypeTable]::LoadDefaultTypeFiles()
        $psversion = $PSVersionTable.PSVersion
        $version = "$($psversion.Major).$($psversion.Minor).$($psversion.Patch)"
    }

    Context "Verify basic mediator functionality via Start-Job" {
        it "Should be able to start a job" {
            Start-Job -ScriptBlock { 'In Test Job' } | Receive-Job -Wait | Should -Be 'In Test Job'
        }
    }

    Context "Connect to an OutOfProcessRunspace with default parameters" {
        BeforeAll {
            $expectedValue = $psversion.Major
        }

        It "Should be able to connect" {
            $ppi = [System.Management.Automation.Runspaces.PowerShellProcessInstance]::new($version, $null, {}, $false, $pwd)
            $runspace = [runspacefactory]::CreateOutOfProcessRunspace($typeTable, $ppi)
            $runspace.Open()
            $powershell = [Powershell]::Create($runspace)
            $null = $powershell.AddScript({
                    $psversiontable.psversion.Major
                })
            $output = $powershell.Invoke()
            $powershell.HadErrors | Should -Be $false
            $output | Should -Be $expectedValue
        }

    }
}
Describe "Standard IO Mediator Configuration" -Tags @('Feature', 'RequireAdminOnWindows') {
    Context "Connect to a ConfigurationName" {
        BeforeAll {
            $randomNuber = Get-Random -Minimum 1 -Maximum 10000
            if ((Test-Elevated)) {
                #& "$pshome\Install-PowerShellRemoting.ps1" -force -PowerShellHome $pshome
                $configurationName = "TestConfiguration-${randomNuber}"
                $scriptPath = 'TestDrive:/session.ps1'
                '$testsession=1' | out-file $scriptPath -Encoding utf8NoBOM
                $resolvedScriptPath = (Resolve-Path $scriptPath).ProviderPath
                $command = "Register-PSSessionConfiguration -Name $configurationName -StartupScript $resolvedScriptPath -Force"
                powershell -nologo -noprofile -c $command
                $verificationScript = {
                    $testsession
                }
                $expectedValue = 1
            }
        }

        It "Should be able to connect to a configuration name ($ConfigurationName)" -Skip:(!(Test-Elevated)) {
            $ppi = [System.Management.Automation.Runspaces.PowerShellProcessInstance]::new($version, $null, {}, $false, $pwd, @('-ConfigurationName', $configurationName))
            $runspace = [runspacefactory]::CreateOutOfProcessRunspace($typeTable, $ppi)
            $runspace.Open()
            $powershell = [Powershell]::Create($runspace)
            $null = $powershell.AddScript($verificationScript)
            $output = $powershell.Invoke()
            $powershell.HadErrors | Should -Be $false
            $output | Should -Be $expectedValue
        }

        AfterAll {
            if ((Test-Elevated)) {
                Get-PSSessionConfiguration -name TestConfiguration-* | Unregister-PSSessionConfiguration -Force -ErrorAction SilentlyContinue
            }
        }

    }
}
