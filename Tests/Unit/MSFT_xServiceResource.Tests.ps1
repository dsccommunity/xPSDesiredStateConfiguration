[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

Import-Module "$PSScriptRoot\..\..\DSCResource.Tests\TestHelper.psm1" -Force

$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'xPSDesiredStateConfiguration' `
    -DSCResourceName 'MSFT_xServiceResource' `
    -TestType Unit

InModuleScope 'MSFT_xServiceResource' {
    Describe 'xService Unit Tests' {
        BeforeAll {
            Import-Module "$PSScriptRoot\..\CommonTestHelper.psm1" -Force
            Import-Module "$PSScriptRoot\..\MSFT_xServiceResource.TestHelper.psm1" -Force

            $script:getTargetResourceResultProperties = @('Name', 'StartupType', 'DisplayName', 'Description', 'State', 'Path', 'Dependencies')

            $script:testServiceName = "DscTestService"
            $script:testServiceCodePath = "$PSScriptRoot\..\DscTestService.cs"
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
            Remove-TestService -ServiceName $script:testServiceName -ServiceExecutablePath $script:testServiceExecutablePath
        }

        BeforeEach {
            Set-TargetResource `
                -Name $script:testServiceName `
                -DisplayName $script:testServiceDisplayName `
                -Description $script:testServiceDescription `
                -Path $script:testServiceExecutablePath `
                -Dependencies $script:testServiceDependsOn `
                -BuiltInAccount 'LocalSystem' `
                -State 'Stopped' `
                -StartupType 'Manual'
        }

        AfterEach {
            Set-TargetResource -Name $script:testServiceName -Ensure 'Absent'
        }

        Context 'Get-TargetResource' {
            It 'Should return the correct hashtable properties' {
                $getTargetResourceResult = Get-TargetResource -Name $script:testServiceName

                Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $script:getTargetResourceResultProperties

                $getTargetResourceResult.Name | Should Be $script:testServiceName
                $getTargetResourceResult.StartupType | Should Be 'Manual'
                $getTargetResourceResult.DisplayName | Should Be $script:testServiceDisplayName
                $getTargetResourceResult.Description | Should Be $script:testServiceDescription
                $getTargetResourceResult.State | Should Be 'Stopped'
                $getTargetResourceResult.Path.IndexOf($script:testServiceName, [System.StringComparison]::OrdinalIgnoreCase)  | Should Not Be -1
                $getTargetResourceResult.Dependencies | Should Be $script:testServiceDependsOn
            }

            It 'Should throw with an invalid service name'{
                { Get-TargetResource -Name "NotAService" } | Should Throw
            }
        }

        Context 'Set-TargetResource' {

            It 'Should set the correct state' {
                Set-TargetResource -Name $script:testServiceName
                $getTargetResourceResult = Get-TargetResource $script:testServiceName
                $getTargetResourceResult.State | Should Be 'Running'

                Set-TargetResource -Name $script:testServiceName -State 'Stopped'
                $getTargetResourceResult = Get-TargetResource $script:testServiceName
                $getTargetResourceResult.State | Should Be 'Stopped'
            }

            It 'Should provide correct verbose output when setting State to Running with the service already started' {
                Set-TargetResource -Name $script:testServiceName

                $verboseFilePath = Join-Path -Path (Get-Location) -ChildPath 'SetTargetResourceRunningTestVerboseOutput.txt'

                if (Test-Path $verboseFilePath)
                {
                    Remove-Item $verboseFilePath -ErrorAction SilentlyContinue
                }

                try
                {
                    Set-TargetResource -Name $script:testServiceName -Verbose 4> $verboseFilePath

                    $actualVerboseOutput = (Get-Content -Path $verboseFilePath -Raw).Trim().Replace("`r`n", "").Replace("`n", "")
                    $expectedVerboseOutputWritePropertiesIgnored = $serviceLocalizedData.WritePropertiesIgnored -f $script:testServiceName
                    $expectedVerboseOutputServiceAlreadyStarted = $serviceLocalizedData.ServiceAlreadyStarted -f $script:testServiceName

                    $actualVerboseOutput.Contains($expectedVerboseOutputWritePropertiesIgnored) | Should Be $true
                    $actualVerboseOutput.Contains($expectedVerboseOutputServiceAlreadyStarted) | Should Be $true
                }
                finally
                {
                    if (Test-Path $verboseFilePath)
                    {
                        Remove-Item $verboseFilePath -ErrorAction SilentlyContinue
                    }
                }
            }

            It 'Should provide correct verbose output when setting State to Stopped with the service already stopped' {
                Set-TargetResource -Name $script:testServiceName -State 'Stopped'

                $verboseFilePath = Join-Path -Path (Get-Location) -ChildPath 'SetTargetResourceStoppedTestVerboseOutput.txt'

                if (Test-Path $verboseFilePath)
                {
                    Remove-Item $verboseFilePath -ErrorAction SilentlyContinue
                }

                try
                {
                    Set-TargetResource -Name $script:testServiceName -State 'Stopped' -Verbose 4> $verboseFilePath

                    $actualVerboseOutput = (Get-Content -Path $verboseFilePath -Raw).Trim().Replace("`r`n", "").Replace("`n", "")
                    $expectedVerboseOutputWritePropertiesIgnored = $serviceLocalizedData.WritePropertiesIgnored -f $script:testServiceName
                    $expectedVerboseOutputServiceAlreadyStopped = $serviceLocalizedData.ServiceAlreadyStopped -f $script:testServiceName

                    $actualVerboseOutput.Contains($expectedVerboseOutputWritePropertiesIgnored) | Should Be $true
                    $actualVerboseOutput.Contains($expectedVerboseOutputServiceAlreadyStopped) | Should Be $true
                }
                finally
                {
                    if (Test-Path $verboseFilePath)
                    {
                        Remove-Item $verboseFilePath -ErrorAction SilentlyContinue
                    }
                }
            }

            It 'Should throw when setting State to Stopped and StartupType to Automatic' {
                Set-TargetResource -Name $script:testServiceName
                { Set-TargetResource -Name $script:testServiceName -State 'Stopped' -StartupType 'Automatic' } | Should Throw
            }

            It 'Should throw when setting State to Running and StartupType to Disabled' {
                Set-TargetResource -Name $script:testServiceName -State 'Stopped'
                { Set-TargetResource -Name $script:testServiceName -StartupType 'Disabled' } | Should Throw
            }

            It 'Should throw when both BuiltInAccount and Credential specified' {
                $testUsername = 'username'
                $testPassword = 'password'
                $secureTestPassword = ConvertTo-SecureString $testPassword  -AsPlainText -Force

                $testCredential = New-Object System.Management.Automation.PSCredential ($testUsername, $secureTestPassword)
                { Set-TargetResource -Name $script:testServiceName -BuiltInAccount 'LocalService' -Credential $testCredential } | Should Throw
            }

            It 'Should correctly change StartupType' {
                Set-TargetResource -Name $script:testServiceName -State 'Stopped' -StartupType 'Disabled'
                $getTargetResourceResult = Get-TargetResource -Name $script:testServiceName
                $getTargetResourceResult.StartupType | Should Be "Disabled"

                Set-TargetResource -Name $script:testServiceName -State 'Stopped' -StartupType 'Manual'
                $getTargetResourceResult = Get-TargetResource -Name $script:testServiceName
                $getTargetResourceResult.StartupType | Should Be "Manual"
            }

            It 'Should correctly change BuiltInAccount' {
                Set-TargetResource -Name $script:testServiceName -State 'Stopped' -BuiltInAccount 'NetworkService'
                $testTargetResourceResult = Test-TargetResource -Name $script:testServiceName -State 'Stopped' -BuiltInAccount 'NetworkService'
                $testTargetResourceResult | Should Be $true

                Set-TargetResource -Name $script:testServiceName -State 'Stopped' -BuiltInAccount 'LocalService'
                $testTargetResourceResult = Test-TargetResource -Name $script:testServiceName -State 'Stopped' -BuiltInAccount 'LocalService'
                $testTargetResourceResult | Should Be $true

                Set-TargetResource -Name $script:testServiceName -State 'Stopped' -BuiltInAccount 'LocalSystem'
                $testTargetResourceResult = Test-TargetResource -Name $script:testServiceName -State 'Stopped' -BuiltInAccount 'LocalSystem'
                $testTargetResourceResult | Should Be $true
            }

            It 'Should throw when trying to set an invalid credential' {
                $testUsername = 'username'
                $testPassword = 'password'
                $secureTestPassword = ConvertTo-SecureString $testPassword  -AsPlainText -Force

                $testCredential = New-Object System.Management.Automation.PSCredential ($testUsername, $secureTestPassword)

                { Set-TargetResource -Name $script:testServiceName -State 'Stopped' -Credential $testCredential } | Should Throw
            }

            It 'Should output correct description and not start a stopped service when WhatIf is specified' {
                Set-TargetResource -Name $script:testServiceName -State 'Stopped'

                $transcriptPath = Join-Path -Path (Get-Location) -ChildPath 'WhatIfTestTranscript.txt'
                if (Test-Path $transcriptPath)
                {
                    Wait-ScriptBlockReturnTrue -ScriptBlock {-not (Test-IsFileLocked -Path $transcriptPath)}
                    Remove-Item $transcriptPath
                }

                try
                {
                    Wait-ScriptBlockReturnTrue -ScriptBlock {-not (Test-IsFileLocked -Path $transcriptPath)}

                    Start-Transcript -Path $transcriptPath
                    Set-TargetResource -Name $script:testServiceName -WhatIf
                    Stop-Transcript

                    Wait-ScriptBlockReturnTrue -ScriptBlock {-not (Test-IsFileLocked -Path $transcriptPath)}

                    $transcriptContent = Get-Content -Path $transcriptPath -Raw
                    $transcriptContent | Should Not Be $null

                    $expectedTranscriptMessage = $LocalizedData.StartServiceWhatIf -f $script:testServiceName

                    $transcriptContent = $transcriptContent.Replace("`r`n", "").Replace("`n", "")
                    $transcriptContent.Contains($expectedTranscriptMessage) | Should Be $true

                    $testTargetResourceResult = Test-TargetResource -Name $script:testServiceName -State 'Stopped'
                    $testTargetResourceResult | Should Be $true
                }
                finally
                {
                    if (Test-Path $transcriptPath)
                    {
                        Wait-ScriptBlockReturnTrue -ScriptBlock {-not (Test-IsFileLocked -Path $transcriptPath)}
                        Remove-Item $transcriptPath
                    }
                }
            }

            It 'Should output correct description and not stop a started service when WhatIf is specified' {
                Set-TargetResource -Name $script:testServiceName

                $transcriptPath = Join-Path -Path (Get-Location) -ChildPath 'WhatIfTestTranscript.txt'
                if (Test-Path $transcriptPath)
                {
                    Wait-ScriptBlockReturnTrue -ScriptBlock {-not (Test-IsFileLocked -Path $transcriptPath)}
                    Remove-Item $transcriptPath
                }

                try
                {
                    Wait-ScriptBlockReturnTrue -ScriptBlock {-not (Test-IsFileLocked -Path $transcriptPath)}

                    Start-Transcript -Path $transcriptPath
                    Set-TargetResource -Name $script:testServiceName -State 'Stopped' -WhatIf
                    Stop-Transcript

                    Wait-ScriptBlockReturnTrue -ScriptBlock {-not (Test-IsFileLocked -Path $transcriptPath)}

                    $transcriptContent = Get-Content -Path $transcriptPath -Raw
                    $transcriptContent | Should Not Be $null

                    $expectedTranscriptMessage = $LocalizedData.StopServiceWhatIf -f $script:testServiceName

                    $transcriptContent = $transcriptContent.Replace("`r`n", "").Replace("`n", "")
                    $transcriptContent.Contains($expectedTranscriptMessage) | Should Be $true

                    $testTargetResourceResult = Test-TargetResource -Name $script:testServiceName
                    $testTargetResourceResult | Should Be $true
                }
                finally
                {
                    if (Test-Path $transcriptPath)
                    {
                        Wait-ScriptBlockReturnTrue -ScriptBlock {-not (Test-IsFileLocked -Path $transcriptPath)}
                        Remove-Item $transcriptPath
                    }
                }
            }

            It 'Should throw with invalid service name' {
                { Set-TargetResource -Name "NotAService" } | Should Throw
            }

            It 'Should throw when trying to start a disabled service' {
                Set-TargetResource -Name $script:testServiceName -State 'Stopped' -StartupType 'Disabled'
                { Set-TargetResource -Name $script:testServiceName } | Should Throw
            }
        }

        Context 'Test-TargetResource' {
            It 'Should return correct value based on State' {
                Set-TargetResource -Name $script:testServiceName
                $testTargetResourceResult = Test-TargetResource -Name $script:testServiceName
                $testTargetResourceResult | Should Be $true

                $testTargetResourceResult = Test-TargetResource -Name $script:testServiceName -State 'Stopped'
                $testTargetResourceResult | Should Be $false

                Set-TargetResource -Name $script:testServiceName -State 'Stopped'
                $testTargetResourceResult = Test-TargetResource -Name $script:testServiceName
                $testTargetResourceResult | Should Be $false

                $testTargetResourceResult = Test-TargetResource -Name $script:testServiceName -State 'Stopped'
                $testTargetResourceResult | Should Be $true
            }

            It 'Should return true with the Automatic StartupType' {
                Set-TargetResource -Name $script:testServiceName -StartupType 'Automatic'
                $testTargetResourceResult = Test-TargetResource -Name $script:testServiceName -StartupType 'Automatic'
                $testTargetResourceResult | Should Be $true
            }

            It 'Should return true with the Manual StartupType' {
                Set-TargetResource -Name $script:testServiceName -StartupType 'Manual'
                $testTargetResourceResult = Test-TargetResource -Name $script:testServiceName -StartupType 'Manual'
                $testTargetResourceResult | Should Be $true
            }

            It 'Should return true with the Disabled StartupType' {
                Set-TargetResource -Name $script:testServiceName -State 'Stopped' -StartupType 'Disabled'
                $testTargetResourceResult = Test-TargetResource -Name $script:testServiceName -State 'Stopped' -StartupType 'Disabled'
                $testTargetResourceResult | Should Be $true
            }

            It 'Should return false with different StartType' {
                Set-TargetResource -Name $script:testServiceName
                $testTargetResourceResult = Test-TargetResource -Name $script:testServiceName -StartupType 'Automatic'
                $testTargetResourceResult | Should Be $false
            }

            It 'Should return false with different BuiltInAccount' {
                Set-TargetResource -Name $script:testServiceName
                $testTargetResourceResult = Test-TargetResource -Name $script:testServiceName -BuiltInAccount NetworkService
                $testTargetResourceResult | Should Be $false
            }

            It 'Should return false with invalid service name' {
                Test-TargetResource -Name "NotAService" | Should Be $false
            }
        }

        Context 'Set-ServiceStartupType' {
            It 'Should throw with invalid StartupType' {
                $win32ServiceObject = Get-Win32ServiceObject -Name $script:testServiceName
                { Set-ServiceStartupType -Win32ServiceObject $win32ServiceObject -StartupType "NotAStartupValue" } | Should Throw
            }
        }
    }
}
