$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'xPSDesiredStateConfiguration' `
    -DSCResourceName 'MSFT_xServiceResource' `
    -TestType Unit

InModuleScope 'MSFT_xServiceResource' {

    Describe 'xService Unit Tests' {
        BeforeAll {
            Import-Module "$PSScriptRoot\MSFT_xServiceResource.TestHelper.psm1" -Force

            $global:ServiceLocalizedData = $local:ServiceLocalizedData

            $script:testServiceName = "DscTestService"
            $script:testServiceCodePath = "$PSScriptRoot\DscTestService.cs"
            $script:testServiceDisplayName = "DSC test service display name"
            $script:testServiceDescription = "This is DSC test service used for testing ServiceSet composite resource"
            $script:testServiceDependsOn = "winrm"
            $script:testServiceExecutablePath = Join-Path -Path (Get-Location) -ChildPath "DscTestService.exe"

            Stop-Service $script:testServiceName -ErrorAction SilentlyContinue

            New-TestService `
                -ServiceName $script:testServiceName `
                -ServiceCodePath $script:testServiceCodePath `
                -ServiceDisplayName $script:testServiceDisplayName `
                -ServiceDescription $script:testServiceDescription `
                -ServiceDependsOn $script:testServiceDependsOn `
                -ServiceExecutablePath $script:testServiceExecutablePath
        }

        AfterAll {
            Remove-TestService -Name $script:testServiceName -ServiceExecutablePath $script:testServiceExecutablePath
        }

        BeforeEach {
            # Create new service DSCTestServiceName
            Set-TargetResource `
                -Name $script:testServiceName `
                -DisplayName $global:testServiceDisplayName `
                -Description $script:testServiceDescription `
                -Path $script:testServiceExecutablePath `
                -Dependencies $script:testServiceDependsOn `
                -BuiltInAccount 'LocalSystem' `
                -State 'Stopped' `
                -StartupType 'Manual'

            SetServiceCredentialBuiltIn -name $dscTestServiceName -userName "LocalSystem" -userPassword ""
        }

        AfterEach {
            Invoke-Remotely {
                #Delete service DSCTestServiceName
                Set-TargetResource -Name $dscTestServiceName -Ensure Absent
            }
        }
    
        It 'Get-TargetResource' -Pending {
            $getTargetResourceResult = Get-TargetResource $script:testServiceName

            $getTargetResourceResult.Name | Should Be $script:testServiceName
            $getTargetResourceResult.StartupType | Should Be 'Manual'
            $getTargetResourceResult.DisplayName | Should Be $script:testServiceDisplayName
            $getTargetResourceResult.Description | Should Be $script:testServiceDescription
            $getTargetResourceResult.State | Should Be 'Stopped'
            $getTargetResourceResult.Path.IndexOf($script:testServiceName, [System.StringComparison]::OrdinalIgnoreCase)  | Should Not Be -1
            $getTargetResourceResult.Dependencies | Should Be $script:testServiceDependsOn
        }
    
        It 'Set-TargetResource' -Pending {
            Set-TargetResource -Name $script:testServiceName
            $getTargetResourceResult = Get-TargetResource $script:testServiceName
            $getTargetResourceResult.State | Should Be 'Running'

            Set-TargetResource -Name $script:testServiceName -State 'Stopped'
            $getTargetResourceResult = Get-TargetResource $script:testServiceName
            $getTargetResourceResult.State | Should Be 'Stopped'
        }
    
        It 'SimpleTestService' -Pending {
            Invoke-Remotely {
                SetServiceState $dscTestServiceName "Running"
                $r = MSFT_ServiceResource\Test-TargetResource $dscTestServiceName
                AssertEquals $r  $True "Test Running True"
                $r = MSFT_ServiceResource\Test-TargetResource $dscTestServiceName -State Stopped
                AssertEquals $r  $False "Test Stopped False"
                stop-service $dscTestServiceName
                $r = MSFT_ServiceResource\Test-TargetResource $dscTestServiceName
                AssertEquals $r  $False "Test Running False"
                $r = MSFT_ServiceResource\Test-TargetResource $dscTestServiceName -State Stopped
                AssertEquals $r  $True "Test Stopped True"
            }
        }
    
        It 'TestServiceNotSameStartType' -Pending {
            Invoke-Remotely {
                SetServiceState $dscTestServiceName "Running"
                $r = MSFT_ServiceResource\Test-TargetResource $dscTestServiceName -BuiltInAccount NetworkService
                AssertEquals $r  $False "Test Present False because it is not NetworkService"
                $r = MSFT_ServiceResource\Test-TargetResource $dscTestServiceName -StartupType Automatic
                AssertEquals $r  $False "Test Present False because it is not disabled"
            }
        }
    
        It 'SetAlreadyStarted' -Pending {
            Invoke-Remotely {
                SetServiceState $dscTestServiceName "Running"
                $verboseFileName=join-path $script:serviceTestPath '\..\verboseOutput.txt'
                del $verboseFileName -ErrorAction SilentlyContinue
                MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -Verbose 4> $verboseFileName
                $actual=(Get-Content $verboseFileName -Raw).Trim().Replace("`r`n", "").Replace("`n", "")
                $expected = $ServiceLocalizedData.WritePropertiesIgnored -f $dscTestServiceName + $ServiceLocalizedData.ServiceAlreadyStarted -f $dscTestServiceName
                AssertEquals $actual $expected "verbose"
            }
        }
    
        It 'SetAlreadyStopped' -Pending {
            Invoke-Remotely {
                SetServiceState $dscTestServiceName "Stopped"
                $verboseFileName=join-path $script:serviceTestPath '\..\verboseOutput.txt'
                del $verboseFileName -ErrorAction SilentlyContinue
                MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -State Stopped -Verbose 4> $verboseFileName
                $actual=(Get-Content $verboseFileName -Raw).Trim().Replace("`r`n", "").Replace("`n", "")
                $expected = $ServiceLocalizedData.WritePropertiesIgnored -f $dscTestServiceName + $ServiceLocalizedData.ServiceAlreadyStopped -f $dscTestServiceName
                AssertEquals $actual  $expected "verbose"
            }
        }
    
        It 'InvalidStartupType' -Pending {
            Invoke-Remotely {
                MSFT_ServiceResource\Set-TargetResource $dscTestServiceName

                $thrown=$false
                try
                {
                    MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -State Stopped -StartupType Automatic
                }
                catch
                {
                    $thrown=$true
                }

                Assert $thrown "Cannot set to automatic and stop"

                MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -State Stopped

                $thrown=$false
                try
                {
                    MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -StartupType Disabled
                }
                catch
                {
                    $thrown=$true
                }

                Assert $thrown "Cannot disable and start"
            }
        }
    
        It 'ConflictBetweenBuiltInAndCredentials' -Pending {
            Invoke-Remotely {
                $thrown=$false
                try
                {
                    $creds=New-Object System.Management.Automation.PSCredential "a",(ConvertTo-SecureString "b" -AsPlainText -Force)
                    MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -BuiltInAccount LocalService -Credential $creds
                }
                catch
                {
                    $thrown=$true
                }

                Assert $thrown "Cannot specify creds and builtin"
            }
        }
    
        It 'ChangeStartupType' -Pending {
            Invoke-Remotely {
                MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -State Stopped -StartupType Disabled
                $r=MSFT_ServiceResource\Get-TargetResource  $dscTestServiceName
                AssertEquals $r.StartupType "Disabled" "Disabled successfully"
                MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -State Stopped -StartupType Manual
                $r=MSFT_ServiceResource\Get-TargetResource  $dscTestServiceName
                AssertEquals $r.StartupType "Manual" "Set to Manual successfully"
            }
        }
    
        It 'ChangeBuiltInAccount' -Pending {
            Invoke-Remotely {
                MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -State Stopped -BuiltInAccount NetworkService
                $r=MSFT_ServiceResource\Get-TargetResource  $dscTestServiceName
                Assert (MSFT_ServiceResource\Test-TargetResource  $dscTestServiceName -State Stopped -BuiltInAccount NetworkService) "BuiltInAccount set"

                MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -State Stopped -BuiltInAccount  LocalService
                $r=MSFT_ServiceResource\Get-TargetResource  $dscTestServiceName
                Assert (MSFT_ServiceResource\Test-TargetResource  $dscTestServiceName -State Stopped -BuiltInAccount LocalService) "LocalSystem set"

                MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -State Stopped -BuiltInAccount  LocalSystem
                $r=MSFT_ServiceResource\Get-TargetResource  $dscTestServiceName
                Assert (MSFT_ServiceResource\Test-TargetResource  $dscTestServiceName -State Stopped -BuiltInAccount LocalSystem) "LocalSystem set"
            }
        }
    
        It 'ChangeInvalidCredentials' -Pending {
            Invoke-Remotely {
                $creds=New-Object System.Management.Automation.PSCredential "NotAUser",(ConvertTo-SecureString "NotAPassword" -AsPlainText -Force)
                $thrown=$false
                try
                {
                    MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -State Stopped -Credential $creds
                }
                catch
                {
                    $thrown=$true
                }
                Assert $thrown "Invalid creds"
            }
        }
    
        It 'TestWhatifServiceStart' -Skip:(-not $script:shouldRun -or (-not (IsEnUS))) {
            Invoke-Remotely {
                MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -State Stopped
                $script = "MSFT_ServiceResource\Set-TargetResource {0} -Whatif" -f $dscTestServiceName
                TestWhatif $script $ServiceLocalizedData.StartServiceWhatIf

                $script = "MSFT_ServiceResource\Set-TargetResource {0} -State Stopped -Whatif" -f $dscTestServiceName
                TestWhatif $script ($ServiceLocalizedData.ServiceAlreadySttopped -f $dscTestServiceName)
                Assert (MSFT_ServiceResource\Test-TargetResource $dscTestServiceName -State Stopped) "Service is still stopped"
            }
        }
    
        It 'TestWhatifServiceStop' -Skip:(-not $script:shouldRun -or (-not (IsEnUS))) {
            Invoke-Remotely {
                MSFT_ServiceResource\Set-TargetResource $dscTestServiceName
                $script = "MSFT_ServiceResource\Set-TargetResource {0} -State Stopped -Whatif" -f $dscTestServiceName
                TestWhatif $script "Stop-Service"

                $script = "MSFT_ServiceResource\Set-TargetResource {0} -State Running -Whatif" -f $dscTestServiceName
                TestWhatif $script ($ServiceLocalizedData.ServiceAlreadyStarted -f $dscTestServiceName)
                Assert (MSFT_ServiceResource\Test-TargetResource $dscTestServiceName) "Service is still started"
                MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -State Stopped
            }
        }
    
        It 'GetTestAndSetInvalidService' -Pending {
            Invoke-Remotely {
                $thrown=$false
                try
                {
                    MSFT_ServiceResource\Get-TargetResource "NotAService"
                }
                catch
                {
                    $thrown=$true
                }
                Assert $thrown "Invalid Service Name in Get"

                $thrown=$false
                try
                {
                    MSFT_ServiceResource\Set-TargetResource "NotAService"
                }
                catch
                {
                    $thrown=$true
                }
                Assert $thrown "Invalid Service Name in Set"

                $result = MSFT_ServiceResource\Test-TargetResource "NotAService"
        
                Assert !$result "Invalid output from Test"
            }
        }
    
        It 'StartDisabledService' -Pending {
            Invoke-Remotely {
                MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -State Stopped -StartupType Disabled
                $thrown=$false
                try
                {
                    MSFT_ServiceResource\Set-TargetResource $dscTestServiceName
                }
                catch
                {
                    $thrown=$true
                }
                Assert $thrown "Start Disabled service"

                MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -State Stopped -StartupType Manual
            }
        }

        # This test case verifies something meaningful, but with functionality that no longer exists
        # TestCase StopServiceThatCantBeStopped -tags @("DRT") { 
            # MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -State Stopped
            # MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -State Running -Arguments "FailToStop"
            # $thrown=$false
            # try
            # {
                # MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -State Stopped
            # }
            # catch
            # {
                # $thrown=$true
            # }
            # Assert $thrown "Stop Service that can't be stopped"

            # # After a service refuses to Stop once the Stop method will not be called again.
            # # The system caches the result and refuses to stop the service.
            # # The service can only be stopped through the process.
            # Get-Process "DscTestService*" | Stop-Process -Force
        # }
    
        It 'WriteInvalidStartupProperty' -Pending {
            Invoke-Remotely {
                $svcWmi = new-object management.managementobject "Win32_Service.Name='$dscTestServiceName'"
                $thrown=$false
                try
                {
                    WriteStartupTypeProperty $svcWmi "NotAStartupValue"
                }
                catch
                {
                    $thrown=$true
                }
                Assert $thrown "write invalid startup property"
            }
        }
    
        It 'SetNonExistentUser' -Pending {
            Invoke-Remotely {
                $thrown=$false
                try
                {
                    $cred = new-object pscredential "non existent user",(ConvertTo-SecureString "non existent password" -AsPlainText -Force)
                    MSFT_ServiceResource\Set-TargetResource $dscTestServiceName -State Stopped -Credential $cred
                }
                catch
                {
                    $thrown=$true
                }
                Assert $thrown "Should not be able to set to start as non existing credential"
            }
        }
    }
}
