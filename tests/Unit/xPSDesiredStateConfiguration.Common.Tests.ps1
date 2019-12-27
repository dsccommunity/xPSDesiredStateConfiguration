#region HEADER
$script:projectPath = "$PSScriptRoot\..\.." | Convert-Path
$script:projectName = (Get-ChildItem -Path "$script:projectPath\*\*.psd1" | Where-Object -FilterScript {
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try
            { Test-ModuleManifest -Path $_.FullName -ErrorAction Stop
            }
            catch
            { $false
            })
    }).BaseName

$script:parentModule = Get-Module -Name $script:projectName -ListAvailable | Select-Object -First 1
$script:subModulesFolder = Join-Path -Path $script:parentModule.ModuleBase -ChildPath 'Modules'
Remove-Module -Name $script:parentModule -Force -ErrorAction 'SilentlyContinue'

$script:subModuleName = (Split-Path -Path $PSCommandPath -Leaf) -replace '\.Tests.ps1'
$script:subModuleFile = Join-Path -Path $script:subModulesFolder -ChildPath "$($script:subModuleName)/$($script:subModuleName).psm1"

Import-Module $script:subModuleFile -Force -ErrorAction Stop
#endregion HEADER

if (Test-SkipContinuousIntegrationTask -Type 'Unit')
{
    return
}

InModuleScope $script:subModuleName {
    Describe 'xPSDesiredStateConfiguration.Common\Test-IsNanoServer' {
        $testComputerInfoNanoServer = @{
            OsProductType = 'Server'
            OsServerLevel = 'NanoServer'
        }

        $testComputerInfoServerNotNano = @{
            OsProductType = 'Server'
            OsServerLevel = 'NotNano'
        }

        $testComputerInfoNotServer = @{
            OsProductType = 'NotServer'
            OsServerLevel = 'NotNano'
        }

        Mock -CommandName 'Test-CommandExists' -MockWith { return $true }
        Mock -CommandName 'Get-ComputerInfo' -MockWith { return $testComputerInfoNanoServer }

        Context 'Get-ComputerInfo command exists' {
            Context 'Computer OS type is Server and OS server level is NanoServer' {
                It 'Should not throw' {
                    { $null = Test-IsNanoServer } | Should -Not -Throw
                }

                It 'Should test if the Get-ComputerInfo command exists' {
                    $testCommandExistsParameterFilter = {
                        return $Name -eq 'Get-ComputerInfo'
                    }

                    Assert-MockCalled -CommandName 'Test-CommandExists' -ParameterFilter $testCommandExistsParameterFilter -Exactly 1 -Scope 'Context'
                }

                It 'Should retrieve the computer info' {
                    Assert-MockCalled -CommandName 'Get-ComputerInfo' -Exactly 1 -Scope 'Context'
                }

                It 'Should return true' {
                    Test-IsNanoServer | Should -BeTrue
                }
            }

            Context 'Computer OS type is Server and OS server level is not NanoServer' {
                Mock -CommandName 'Get-ComputerInfo' -MockWith { return $testComputerInfoServerNotNano }

                It 'Should not throw' {
                    { $null = Test-IsNanoServer } | Should -Not -Throw
                }

                It 'Should test if the Get-ComputerInfo command exists' {
                    $testCommandExistsParameterFilter = {
                        return $Name -eq 'Get-ComputerInfo'
                    }

                    Assert-MockCalled -CommandName 'Test-CommandExists' -ParameterFilter $testCommandExistsParameterFilter -Exactly 1 -Scope 'Context'
                }

                It 'Should retrieve the computer info' {
                    Assert-MockCalled -CommandName 'Get-ComputerInfo' -Exactly 1 -Scope 'Context'
                }

                It 'Should return false' {
                    Test-IsNanoServer | Should -BeFalse
                }
            }

            Context 'Computer OS type is not Server' {
                Mock -CommandName 'Get-ComputerInfo' -MockWith { return $testComputerInfoNotServer }

                It 'Should not throw' {
                    { $null = Test-IsNanoServer } | Should -Not -Throw
                }

                It 'Should test if the Get-ComputerInfo command exists' {
                    $testCommandExistsParameterFilter = {
                        return $Name -eq 'Get-ComputerInfo'
                    }

                    Assert-MockCalled -CommandName 'Test-CommandExists' -ParameterFilter $testCommandExistsParameterFilter -Exactly 1 -Scope 'Context'
                }

                It 'Should retrieve the computer info' {
                    Assert-MockCalled -CommandName 'Get-ComputerInfo' -Exactly 1 -Scope 'Context'
                }

                It 'Should return false' {
                    Test-IsNanoServer | Should -BeFalse
                }
            }
        }

        Context 'Get-ComputerInfo command does not exist' {
            Mock -CommandName 'Test-CommandExists' -MockWith { return $false }

            It 'Should not throw' {
                { $null = Test-IsNanoServer } | Should -Not -Throw
            }

            It 'Should test if the Get-ComputerInfo command exists' {
                $testCommandExistsParameterFilter = {
                    return $Name -eq 'Get-ComputerInfo'
                }

                Assert-MockCalled -CommandName 'Test-CommandExists' -ParameterFilter $testCommandExistsParameterFilter -Exactly 1 -Scope 'Context'
            }

            It 'Should not attempt to retrieve the computer info' {
                Assert-MockCalled -CommandName 'Get-ComputerInfo' -Exactly 0 -Scope 'Context'
            }

            It 'Should return false' {
                Test-IsNanoServer | Should -BeFalse
            }
        }
    }

    Describe 'xPSDesiredStateConfiguration.Common\Test-DscParameterState' -Tag TestDscParameterState {
        Context -Name 'When passing values' -Fixture {
            It 'Should return true for two identical tables' {
                $mockDesiredValues = @{ Example = 'test' }

                $testParameters = @{
                    CurrentValues = $mockDesiredValues
                    DesiredValues = $mockDesiredValues
                }

                Test-DscParameterState @testParameters | Should -BeTrue
            }

            It 'Should return false when a value is different for [System.String]' {
                $mockCurrentValues = @{ Example = [System.String] 'something' }
                $mockDesiredValues = @{ Example = [System.String] 'test' }

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                }

                Test-DscParameterState @testParameters | Should -BeFalse
            }

            It 'Should return false when a value is different for [System.Int32]' {
                $mockCurrentValues = @{ Example = [System.Int32] 1 }
                $mockDesiredValues = @{ Example = [System.Int32] 2 }

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                }

                Test-DscParameterState @testParameters | Should -BeFalse
            }

            It 'Should return false when a value is different for [Int16]' {
                $mockCurrentValues = @{ Example = [System.Int16] 1 }
                $mockDesiredValues = @{ Example = [System.Int16] 2 }

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                }

                Test-DscParameterState @testParameters | Should -BeFalse
            }

            It 'Should return false when a value is different for [UInt16]' {
                $mockCurrentValues = @{ Example = [System.UInt16] 1 }
                $mockDesiredValues = @{ Example = [System.UInt16] 2 }

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                }

                Test-DscParameterState @testParameters | Should -BeFalse
            }

            It 'Should return false when a value is different for [Boolean]' {
                $mockCurrentValues = @{ Example = [System.Boolean] $true }
                $mockDesiredValues = @{ Example = [System.Boolean] $false }

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                }

                Test-DscParameterState @testParameters | Should -BeFalse
            }

            It 'Should return false when a value is missing' {
                $mockCurrentValues = @{ }
                $mockDesiredValues = @{ Example = 'test' }

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                }

                Test-DscParameterState @testParameters | Should -BeFalse
            }

            It 'Should return true when only a specified value matches, but other non-listed values do not' {
                $mockCurrentValues = @{ Example = 'test'; SecondExample = 'true' }
                $mockDesiredValues = @{ Example = 'test'; SecondExample = 'false' }

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                    ValuesToCheck = @('Example')
                }

                Test-DscParameterState @testParameters | Should -BeTrue
            }

            It 'Should return false when only specified values do not match, but other non-listed values do ' {
                $mockCurrentValues = @{ Example = 'test'; SecondExample = 'true' }
                $mockDesiredValues = @{ Example = 'test'; SecondExample = 'false' }

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                    ValuesToCheck = @('SecondExample')
                }

                Test-DscParameterState @testParameters | Should -BeFalse
            }

            It 'Should return false when an empty hash table is used in the current values' {
                $mockCurrentValues = @{ }
                $mockDesiredValues = @{ Example = 'test'; SecondExample = 'false' }

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                }

                Test-DscParameterState @testParameters | Should -BeFalse
            }

            It 'Should return true when evaluating a table against a CimInstance' {
                $mockCurrentValues = @{ Handle = '0'; ProcessId = '1000' }

                $mockWin32ProcessProperties = @{
                    Handle    = 0
                    ProcessId = 1000
                }

                $mockNewCimInstanceParameters = @{
                    ClassName  = 'Win32_Process'
                    Property   = $mockWin32ProcessProperties
                    Key        = 'Handle'
                    ClientOnly = $true
                }

                $mockDesiredValues = New-CimInstance @mockNewCimInstanceParameters

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                    ValuesToCheck = @('Handle', 'ProcessId')
                }

                Test-DscParameterState @testParameters | Should -BeTrue
            }

            It 'Should return false when evaluating a table against a CimInstance and a value is wrong' {
                $mockCurrentValues = @{ Handle = '1'; ProcessId = '1000' }

                $mockWin32ProcessProperties = @{
                    Handle    = 0
                    ProcessId = 1000
                }

                $mockNewCimInstanceParameters = @{
                    ClassName  = 'Win32_Process'
                    Property   = $mockWin32ProcessProperties
                    Key        = 'Handle'
                    ClientOnly = $true
                }

                $mockDesiredValues = New-CimInstance @mockNewCimInstanceParameters

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                    ValuesToCheck = @('Handle', 'ProcessId')
                }

                Test-DscParameterState @testParameters | Should -BeFalse
            }

            It 'Should return true when evaluating a hash table containing an array' {
                $mockCurrentValues = @{ Example = 'test'; SecondExample = @('1', '2') }
                $mockDesiredValues = @{ Example = 'test'; SecondExample = @('1', '2') }

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                }

                Test-DscParameterState @testParameters | Should -BeTrue
            }

            It 'Should return false when evaluating a hash table containing an array with wrong values' {
                $mockCurrentValues = @{ Example = 'test'; SecondExample = @('A', 'B') }
                $mockDesiredValues = @{ Example = 'test'; SecondExample = @('1', '2') }

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                }

                Test-DscParameterState @testParameters | Should -BeFalse
            }

            It 'Should return false when evaluating a hash table containing an array, but the CurrentValues are missing an array' {
                $mockCurrentValues = @{ Example = 'test' }
                $mockDesiredValues = @{ Example = 'test'; SecondExample = @('1', '2') }

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                }

                Test-DscParameterState @testParameters | Should -BeFalse
            }

            It 'Should return false when evaluating a hash table containing an array, but the property i CurrentValues is $null' {
                $mockCurrentValues = @{ Example = 'test'; SecondExample = $null }
                $mockDesiredValues = @{ Example = 'test'; SecondExample = @('1', '2') }

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                }

                Test-DscParameterState @testParameters | Should -BeFalse
            }
        }

        Context -Name 'When passing invalid types for DesiredValues' -Fixture {
            It 'Should throw the correct error when DesiredValues is of wrong type' {
                $mockCurrentValues = @{ Example = 'something' }
                $mockDesiredValues = 'NotHashTable'

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                }

                $mockCorrectErrorMessage = ($script:localizedData.PropertyTypeInvalidForDesiredValues -f $testParameters.DesiredValues.GetType().Name)
                { Test-DscParameterState @testParameters } | Should -Throw $mockCorrectErrorMessage
            }

            It 'Should write a warning when DesiredValues contain an unsupported type' {
                Mock -CommandName Write-Warning -Verifiable

                # This is a dummy type to test with a type that could never be a correct one.
                class MockUnknownType
                {
                    [ValidateNotNullOrEmpty()]
                    [System.String]
                    $Property1

                    [ValidateNotNullOrEmpty()]
                    [System.String]
                    $Property2

                    MockUnknownType()
                    {
                    }
                }

                $mockCurrentValues = @{ Example = New-Object -TypeName MockUnknownType }
                $mockDesiredValues = @{ Example = New-Object -TypeName MockUnknownType }

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                }

                Test-DscParameterState @testParameters | Should -BeFalse

                Assert-MockCalled -CommandName Write-Warning -Exactly -Times 1
            }
        }

        Context -Name 'When passing an CimInstance as DesiredValue and ValuesToCheck is $null' -Fixture {
            It 'Should throw the correct error' {
                $mockCurrentValues = @{ Example = 'something' }

                $mockWin32ProcessProperties = @{
                    Handle    = 0
                    ProcessId = 1000
                }

                $mockNewCimInstanceParameters = @{
                    ClassName  = 'Win32_Process'
                    Property   = $mockWin32ProcessProperties
                    Key        = 'Handle'
                    ClientOnly = $true
                }

                $mockDesiredValues = New-CimInstance @mockNewCimInstanceParameters

                $testParameters = @{
                    CurrentValues = $mockCurrentValues
                    DesiredValues = $mockDesiredValues
                    ValuesToCheck = $null
                }

                $mockCorrectErrorMessage = $script:localizedData.PropertyTypeInvalidForValuesToCheck
                { Test-DscParameterState @testParameters } | Should -Throw $mockCorrectErrorMessage
            }
        }

        Assert-VerifiableMock
    }

    Describe 'xPSDesiredStateConfiguration.Common\Get-LocalizedData' {
        $mockTestPath = {
            return $mockTestPathReturnValue
        }

        $mockImportLocalizedData = {
            $BaseDirectory | Should -Be $mockExpectedLanguagePath
        }

        BeforeEach {
            Mock -CommandName Test-Path -MockWith $mockTestPath -Verifiable
            Mock -CommandName Import-LocalizedData -MockWith $mockImportLocalizedData -Verifiable
        }

        Context 'When loading localized data for Swedish' {
            $mockExpectedLanguagePath = 'sv-SE'
            $mockTestPathReturnValue = $true

            It 'Should call Import-LocalizedData with sv-SE language' {
                Mock -CommandName Join-Path -MockWith {
                    return 'sv-SE'
                } -Verifiable

                { Get-LocalizedData -ResourceName 'DummyResource' } | Should -Not -Throw

                Assert-MockCalled -CommandName Join-Path -Exactly -Times 3 -Scope It
                Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName Import-LocalizedData -Exactly -Times 1 -Scope It
            }

            $mockExpectedLanguagePath = 'en-US'
            $mockTestPathReturnValue = $false

            It 'Should call Import-LocalizedData and fallback to en-US if sv-SE language does not exist' {
                Mock -CommandName Join-Path -MockWith {
                    return $ChildPath
                } -Verifiable

                { Get-LocalizedData -ResourceName 'DummyResource' } | Should -Not -Throw

                Assert-MockCalled -CommandName Join-Path -Exactly -Times 4 -Scope It
                Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName Import-LocalizedData -Exactly -Times 1 -Scope It
            }

            Context 'When $ScriptRoot is set to a path' {
                $mockExpectedLanguagePath = 'sv-SE'
                $mockTestPathReturnValue = $true

                It 'Should call Import-LocalizedData with sv-SE language' {
                    Mock -CommandName Join-Path -MockWith {
                        return 'sv-SE'
                    } -Verifiable

                    { Get-LocalizedData -ResourceName 'DummyResource' -ScriptRoot '.' } | Should -Not -Throw

                    Assert-MockCalled -CommandName Join-Path -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Import-LocalizedData -Exactly -Times 1 -Scope It
                }

                $mockExpectedLanguagePath = 'en-US'
                $mockTestPathReturnValue = $false

                It 'Should call Import-LocalizedData and fallback to en-US if sv-SE language does not exist' {
                    Mock -CommandName Join-Path -MockWith {
                        return $ChildPath
                    } -Verifiable

                    { Get-LocalizedData -ResourceName 'DummyResource' -ScriptRoot '.' } | Should -Not -Throw

                    Assert-MockCalled -CommandName Join-Path -Exactly -Times 2 -Scope It
                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName Import-LocalizedData -Exactly -Times 1 -Scope It
                }
            }
        }

        Context 'When loading localized data for English' {
            Mock -CommandName Join-Path -MockWith {
                return 'en-US'
            } -Verifiable

            $mockExpectedLanguagePath = 'en-US'
            $mockTestPathReturnValue = $true

            It 'Should call Import-LocalizedData with en-US language' {
                { Get-LocalizedData -ResourceName 'DummyResource' } | Should -Not -Throw
            }
        }

        Assert-VerifiableMock
    }

    Describe 'xPSDesiredStateConfiguration.Common\New-InvalidResultException' {
        Context 'When calling with Message parameter only' {
            It 'Should throw the correct error' {
                $mockErrorMessage = 'Mocked error'

                { New-InvalidResultException -Message $mockErrorMessage } | Should -Throw $mockErrorMessage
            }
        }

        Context 'When calling with both the Message and ErrorRecord parameter' {
            It 'Should throw the correct error' {
                $mockErrorMessage = 'Mocked error'
                $mockExceptionErrorMessage = 'Mocked exception error message'

                $mockException = New-Object -TypeName System.Exception -ArgumentList $mockExceptionErrorMessage
                $mockErrorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $mockException, $null, 'InvalidResult', $null

                { New-InvalidResultException -Message $mockErrorMessage -ErrorRecord $mockErrorRecord } | Should -Throw ('System.Exception: {0} ---> System.Exception: {1}' -f $mockErrorMessage, $mockExceptionErrorMessage)
            }
        }

        Assert-VerifiableMock
    }

    Describe 'xPSDesiredStateConfiguration.Common\New-ObjectNotFoundException' {
        Context 'When calling with Message parameter only' {
            It 'Should throw the correct error' {
                $mockErrorMessage = 'Mocked error'

                { New-ObjectNotFoundException -Message $mockErrorMessage } | Should -Throw $mockErrorMessage
            }
        }

        Context 'When calling with both the Message and ErrorRecord parameter' {
            It 'Should throw the correct error' {
                $mockErrorMessage = 'Mocked error'
                $mockExceptionErrorMessage = 'Mocked exception error message'

                $mockException = New-Object -TypeName System.Exception -ArgumentList $mockExceptionErrorMessage
                $mockErrorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $mockException, $null, 'InvalidResult', $null

                { New-ObjectNotFoundException -Message $mockErrorMessage -ErrorRecord $mockErrorRecord } | Should -Throw ('System.Exception: {0} ---> System.Exception: {1}' -f $mockErrorMessage, $mockExceptionErrorMessage)
            }
        }

        Assert-VerifiableMock
    }

    Describe 'xPSDesiredStateConfiguration.Common\New-InvalidOperationException' {
        Context 'When calling with Message parameter only' {
            It 'Should throw the correct error' {
                $mockErrorMessage = 'Mocked error'

                { New-InvalidOperationException -Message $mockErrorMessage } | Should -Throw $mockErrorMessage
            }
        }

        Context 'When calling with both the Message and ErrorRecord parameter' {
            It 'Should throw the correct error' {
                $mockErrorMessage = 'Mocked error'
                $mockExceptionErrorMessage = 'Mocked exception error message'

                $mockException = New-Object -TypeName System.Exception -ArgumentList $mockExceptionErrorMessage
                $mockErrorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $mockException, $null, 'InvalidResult', $null

                { New-InvalidOperationException -Message $mockErrorMessage -ErrorRecord $mockErrorRecord } | Should -Throw ('System.InvalidOperationException: {0} ---> System.Exception: {1}' -f $mockErrorMessage, $mockExceptionErrorMessage)
            }
        }

        Assert-VerifiableMock
    }

    Describe 'xPSDesiredStateConfiguration.Common\New-NotImplementedException' {
        Context 'When called with Message parameter only' {
            It 'Should throw the correct error' {
                $mockErrorMessage = 'Mocked error'

                { New-NotImplementedException -Message $mockErrorMessage } | Should -Throw $mockErrorMessage
            }
        }

        Context 'When called with both the Message and ErrorRecord parameter' {
            It 'Should throw the correct error' {
                $mockErrorMessage = 'Mocked error'
                $mockExceptionErrorMessage = 'Mocked exception error message'

                $mockException = New-Object -TypeName System.Exception -ArgumentList $mockExceptionErrorMessage
                $mockErrorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $mockException, $null, 'InvalidResult', $null

                { New-NotImplementedException -Message $mockErrorMessage -ErrorRecord $mockErrorRecord } | Should -Throw ('System.NotImplementedException: {0} ---> System.Exception: {1}' -f $mockErrorMessage, $mockExceptionErrorMessage)
            }
        }

        Assert-VerifiableMock
    }

    Describe 'xPSDesiredStateConfiguration.Common\New-InvalidArgumentException' {
        Context 'When calling with both the Message and ArgumentName parameter' {
            It 'Should throw the correct error' {
                $mockErrorMessage = 'Mocked error'
                $mockArgumentName = 'MockArgument'

                { New-InvalidArgumentException -Message $mockErrorMessage -ArgumentName $mockArgumentName } | Should -Throw ('Parameter name: {0}' -f $mockArgumentName)
            }
        }

        Assert-VerifiableMock
    }

    Describe 'xPSDesiredStateConfiguration.Common\Set-DSCMachineRebootRequired' {
        Context 'When called' {
            It 'Should set the desired DSCMachineStatus value' {
                # Store the previous $global:DSCMachineStatus value
                $prevDSCMachineStatus = $global:DSCMachineStatus

                # Make sure DSCMachineStatus is set to a value that will have to be updated
                $global:DSCMachineStatus = 0

                # Set and test for the new value
                Set-DSCMachineRebootRequired
                $global:DSCMachineStatus | Should -Be 1

                # Revert to previous $global:DSCMachineStatus value
                $global:DSCMachineStatus = $prevDSCMachineStatus
            }
        }
    }

    Describe 'xPSDesiredStateConfiguration.Common\New-ResourceSetCommonParameterString' {
        It 'Should return string containing the string parameter value for one string common parameter' {
            $parameters = @{
                Name                   = 'Name'
                CommonStringParameter1 = 'CommonParameter1'
            }

            $keyParameterName = 'Name'

            $commonParameterString = New-ResourceSetCommonParameterString -KeyParameterName $keyParameterName -Parameters $parameters
            $commonParameterString | Should -Be "CommonStringParameter1 = `"CommonParameter1`"`r`n"
        }

        It 'Should return string containing one variable reference for one credential common parameter' {
            $testUserName = 'testUserName'
            $secureTestPassword = ConvertTo-SecureString -String 'testPassword' -AsPlainText -Force

            $parameters = @{
                Name                       = 'Name'
                CommonCredentialParameter1 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUsername, $secureTestPassword )
            }

            $keyParameterName = 'Name'

            $commonParameterString = New-ResourceSetCommonParameterString -KeyParameterName $keyParameterName -Parameters $parameters
            $commonParameterString | Should -Be "CommonCredentialParameter1 = `$CommonCredentialParameter1`r`n"
        }

        It 'Should return string containing all parameters for two string common parameters and two int common parameters' {
            $parameters = @{
                Name                   = 'Name'
                CommonStringParameter1 = 'CommonParameter1'
                CommonStringParameter2 = 'CommonParameter2'
                CommonIntParameter1    = 1
                CommonIntParameter2    = 2
            }

            $keyParameterName = 'Name'

            $commonParameterString = New-ResourceSetCommonParameterString -KeyParameterName $keyParameterName -Parameters $parameters
            $commonParameterString.Contains("CommonStringParameter1 = `"CommonParameter1`"`r`n") | Should -BeTrue
            $commonParameterString.Contains("CommonStringParameter2 = `"CommonParameter2`"`r`n") | Should -BeTrue
            $commonParameterString.Contains("CommonIntParameter1 = `$CommonIntParameter1`r`n") | Should -BeTrue
            $commonParameterString.Contains("CommonIntParameter2 = `$CommonIntParameter2`r`n") | Should -BeTrue
        }
    }

    Describe 'xPSDesiredStateConfiguration.Common\New-ResourceSetConfigurationString' {
        $newResourceSetConfigurationStringParams = @{
            ResourceName          = 'ResourceName'
            ModuleName            = 'ModuleName'
            KeyParameterName      = 'Name'
            KeyParameterValues    = @( 'KeyValue1' )
            CommonParameterString = "CommonCredentialParameter1 = `$CommonCredentialParameter1`r`n"
        }

        It 'Should return string with module import and one resource for one key value' {
            $resourceString = New-ResourceSetConfigurationString @newResourceSetConfigurationStringParams
            $resourceString | Should -Be ("Import-DscResource -Name ResourceName -ModuleName ModuleName`r`n" + `
                    "ResourceName Resource0`r`n{`r`nName = `"KeyValue1`"`r`n$($newResourceSetConfigurationStringParams['CommonParameterString'])}`r`n")
        }

        $newResourceSetConfigurationStringParams['KeyParameterValues'] = @( 'KeyValue1', 'KeyValue2' )

        It 'Should return string with module import and two resources for two key values' {
            $resourceString = New-ResourceSetConfigurationString @newResourceSetConfigurationStringParams
            $resourceString | Should -Be ("Import-DscResource -Name ResourceName -ModuleName ModuleName`r`n" + `
                    "ResourceName Resource0`r`n{`r`nName = `"KeyValue1`"`r`n$($newResourceSetConfigurationStringParams['CommonParameterString'])}`r`n" + `
                    "ResourceName Resource1`r`n{`r`nName = `"KeyValue2`"`r`n$($newResourceSetConfigurationStringParams['CommonParameterString'])}`r`n")
        }
    }

    Describe 'xPSDesiredStateConfiguration.Common\New-ResourceSetConfigurationScriptBlock' {
        $commonParameterString = 'CommonParameterString'
        $configurationString = 'ConfigurationString'

        Mock -CommandName 'New-ResourceSetCommonParameterString' -MockWith { return $commonParameterString }
        Mock -CommandName 'New-ResourceSetConfigurationString' -MockWith { return $configurationString }

        $newResourceSetConfigurationParams = @{
            ResourceName     = 'ResourceName'
            ModuleName       = 'ModuleName'
            KeyParameterName = 'KeyParameter'
            Parameters       = @{
                KeyParameter     = @( 'KeyParameterValue1', 'KeyParameterValue2' )
                CommonParameter1 = 'CommonParameterValue1'
                CommonParameter2 = 'CommonParameterValue2'
            }
        }

        $newResourceSetConfigurationScriptBlock = New-ResourceSetConfigurationScriptBlock @newResourceSetConfigurationParams

        It 'Should return a ScriptBlock' {
            $newResourceSetConfigurationScriptBlock -is [System.Management.Automation.ScriptBlock] | Should -BeTrue
        }

        It 'Should return ScriptBlock of string returned from New-ResourceSetConfigurationString' {
            $newResourceSetConfigurationScriptBlock | Should -Match ([System.Management.Automation.ScriptBlock]::Create($configurationString))
        }

        It 'Should call New-ResourceSetConfigurationString with the correct ModuleName' {
            Assert-MockCalled -CommandName 'New-ResourceSetConfigurationString' -ParameterFilter {
                $ModuleName -eq $newResourceSetConfigurationParams['ModuleName']
            }
        }

        It 'Should call New-ResourceSetCommonParameterString with the correct KeyParameterName' {
            Assert-MockCalled -CommandName 'New-ResourceSetCommonParameterString' -ParameterFilter {
                $KeyParameterName -eq $newResourceSetConfigurationParams['KeyParameterName']
            }
        }

        It 'Should call New-ResourceSetCommonParameterString with the correct Parameters' {
            Assert-MockCalled -CommandName 'New-ResourceSetCommonParameterString' -ParameterFilter {
                $null -eq (Compare-Object -ReferenceObject $newResourceSetConfigurationParams['Parameters'] -DifferenceObject $Parameters)
            }
        }

        It 'Should call New-ResourceSetConfigurationString with the correct ResourceName' {
            Assert-MockCalled -CommandName 'New-ResourceSetConfigurationString' -ParameterFilter {
                $ResourceName -eq $newResourceSetConfigurationParams['ResourceName']
            }
        }

        It 'Should call New-ResourceSetConfigurationString with the correct KeyParameterValues' {
            Assert-MockCalled -CommandName 'New-ResourceSetConfigurationString' -ParameterFilter {
                $null -eq (Compare-Object -ReferenceObject $newResourceSetConfigurationParams['Parameters']['KeyParameter'] -DifferenceObject $KeyParameterValues)
            }
        }

        It 'Should call New-ResourceSetConfigurationString with the correct CommonParameterString' {
            Assert-MockCalled -CommandName 'New-ResourceSetConfigurationString' -ParameterFilter {
                $CommonParameterString -eq $commonParameterString
            }
        }
    }
}
