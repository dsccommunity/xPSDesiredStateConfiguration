$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

Import-Module -Name (Join-Path -Path (Split-Path $PSScriptRoot -Parent) `
                               -ChildPath 'CommonTestHelper.psm1')

$script:testEnvironment = Enter-DscResourceTestEnvironment `
    -DscResourceModuleName 'xPSDesiredStateConfiguration' `
    -DscResourceName 'MSFT_xEnvironmentResource' `
    -TestType 'Unit'

try
{
    InModuleScope 'MSFT_xEnvironmentResource' {
        # Mock objects
        $script:mockEnvironmentVarName1 = 'PATH'
        $script:mockEnvironmentVarName2 = 'APPDATA'
        $script:mockEnvironmentVarInvalidName = 'Invalid'

        $script:mockEnvironmentVar1 = @{
            PATH = 'mock path for testing'
        }
            
        $script:mockEnvironmentVar2 = @{
            APPDATA = 'mock path to Application Data directory for testing'
        }

        Describe 'xEnvironmentResource\Get-TargetResource' {
            Mock -CommandName 'Get-ItemPropertyExpanded' -MockWith {
                if ($Name -eq $script:mockEnvironmentVarName1)
                {
                    return $script:mockEnvironmentVar1
                }
                else
                {
                    return $null
                }
            }

            Context 'Environment variable exists' {
                $getTargetResourceResult = Get-TargetResource -Name $script:mockEnvironmentVarName1

                It 'Should retrieve the expanded environment variable object' {
                    Assert-MockCalled -CommandName 'Get-ItemPropertyExpanded' -Exactly 1 -Scope 'Context'
                }

                It 'Should return a hashtable' {
                    $getTargetResourceResult -is [Hashtable] | Should Be $true
                }

                It 'Should return the environment variable name' {
                    $getTargetResourceResult.Name | Should Be $script:mockEnvironmentVarName1
                }

                It 'Should return the environment variable Ensure state as Present' {
                    $getTargetResourceResult.Ensure | Should Be 'Present'
                }

                It 'Should return the value of the environment variable' {
                    $getTargetResourceResult.Value | Should Be $script:mockEnvironmentVar1.$script:mockEnvironmentVarName1
                }
            }

            Context 'Environment variable does not exist' {
                $getTargetResourceResult = Get-TargetResource -Name $script:mockEnvironmentVarInvalidName

                It 'Should retrieve the expanded environment variable object' {
                    Assert-MockCalled -CommandName 'Get-ItemPropertyExpanded' -Exactly 1 -Scope 'Context'
                }

                It 'Should return a hashtable' {
                    $getTargetResourceResult -is [Hashtable] | Should Be $true
                }

                It 'Should return the environment variable name' {
                    $getTargetResourceResult.Name | Should Be $script:mockEnvironmentVarInvalidName
                }

                It 'Should return the environment variable Ensure state as Absent' {
                    $getTargetResourceResult.Ensure | Should Be 'Absent'
                }
            }
        }

        Describe 'xEnvironmentResource\Set-TargetResource' {
            Context 'Add new environment variable without Path and item properties not present' {
                $newPathValue = 'new path value'
                Mock -CommandName Get-ItemPropertyExpanded -MockWith { return $null }
                Mock -CommandName Get-EnvironmentVariable -MockWith { return 'mock environment variable' }
                Mock -CommandName Set-MachineAndProcessEnvironmentVariables -MockWith { $script:mockEnvironmentVar1.PATH = $newPathValue }
                
                It 'Should not throw an exception' {
                    { Set-TargetResource -Name $script:mockEnvironmentVarName1 -Value $newPathValue } | Should Not Throw
                }
                
                It 'Should have set the mock variable value' {
                    $script:mockEnvironmentVar1.PATH | Should Be $newPathValue
                }

                It 'Should have called the correct mocks' {
                    Assert-MockCalled Get-ItemPropertyExpanded -Exactly 1 -Scope Context
                    Assert-MockCalled Get-EnvironmentVariable -Exactly 1 -Scope Context
                    Assert-MockCalled Set-MachineAndProcessEnvironmentVariables -Exactly 1 -Scope Context
                }
            }

            Context 'Add new environment variable with Path and item properties present' {
                $newPathValue = 'new path value2'
                Mock -CommandName Get-ItemProperty -MockWith { return $script:mockEnvironmentVar1 }
                Mock -CommandName Get-EnvironmentVariable -MockWith { return $null }
                Mock -CommandName Set-MachineAndProcessEnvironmentVariables -MockWith { $script:mockEnvironmentVar1.PATH = $newPathValue }
                
                It 'Should not throw an exception' {
                    { Set-TargetResource -Name $script:mockEnvironmentVarName1 -Value $newPathValue -Path $true } | Should Not Throw
                }
                
                It 'Should have set the mock variable value' {
                    $script:mockEnvironmentVar1.PATH | Should Be $newPathValue
                }

                It 'Should have called the correct mocks' {
                    Assert-MockCalled Get-ItemProperty -Exactly 1 -Scope Context
                    Assert-MockCalled Get-EnvironmentVariable -Exactly 1 -Scope Context
                    Assert-MockCalled Set-MachineAndProcessEnvironmentVariables -Exactly 1 -Scope Context
                }
            }

            Context 'Update environment variable but no value specified' {
                Mock -CommandName Get-ItemPropertyExpanded -MockWith { return $script:mockEnvironmentVar1 }
                Mock -CommandName Get-EnvironmentVariable -MockWith { return 'mock environment variable' }
                Mock -CommandName Set-MachineAndProcessEnvironmentVariables -MockWith {}
                
                It 'Should not throw an exception' {
                    { Set-TargetResource -Name $script:mockEnvironmentVarName1 } | Should Not Throw
                }

                It 'Should have called the correct mocks' {
                    Assert-MockCalled Get-ItemPropertyExpanded -Exactly 1 -Scope Context
                    Assert-MockCalled Get-EnvironmentVariable -Exactly 1 -Scope Context
                    Assert-MockCalled Set-MachineAndProcessEnvironmentVariables -Exactly 0 -Scope Context
                }
            }

            Context 'Update environment variable without Path and value given is the value already set' {
                $newPathValue = 'new path value2'
                $script:mockEnvironmentVar1.PATH = $newPathValue
                Mock -CommandName Get-ItemPropertyExpanded -MockWith { return $script:mockEnvironmentVar1 }
                Mock -CommandName Get-EnvironmentVariable -MockWith { return 'mock environment variable' }
                Mock -CommandName Set-MachineAndProcessEnvironmentVariables -MockWith {}
                
                It 'Should not throw an exception' {
                    { Set-TargetResource -Name $script:mockEnvironmentVarName1 -Value $newPathValue } | Should Not Throw
                }
                
                It 'Should not have updated the mock variable value' {
                    $script:mockEnvironmentVar1.PATH | Should Be $newPathValue
                }

                It 'Should have called the correct mocks' {
                    Assert-MockCalled Get-ItemPropertyExpanded -Exactly 1 -Scope Context
                    Assert-MockCalled Get-EnvironmentVariable -Exactly 1 -Scope Context
                    Assert-MockCalled Set-MachineAndProcessEnvironmentVariables -Exactly 0 -Scope Context
                }
            }

            Context 'Update environment variable without Path and new value passed in' {
                $newPathValue = 'new path value3'
                Mock -CommandName Get-ItemPropertyExpanded -MockWith { return $script:mockEnvironmentVar1 }
                Mock -CommandName Get-EnvironmentVariable -MockWith { return 'mock environment variable' }
                Mock -CommandName Set-MachineAndProcessEnvironmentVariables -MockWith { $script:mockEnvironmentVar1.PATH = $newPathValue }
                
                It 'Should not throw an exception' {
                    { Set-TargetResource -Name $script:mockEnvironmentVarName1 -Value $newPathValue } | Should Not Throw
                }
                
                It 'Should have updated the mock variable value' {
                    $script:mockEnvironmentVar1.PATH | Should Be $newPathValue
                }

                It 'Should have called the correct mocks' {
                    Assert-MockCalled Get-ItemPropertyExpanded -Exactly 1 -Scope Context
                    Assert-MockCalled Get-EnvironmentVariable -Exactly 1 -Scope Context
                    Assert-MockCalled Set-MachineAndProcessEnvironmentVariables -Exactly 1 -Scope Context
                }
            }

            Context 'Update environment variable with Path and invalid value (;) passed in' {
                $newPathValue = ';'
                Mock -CommandName Get-ItemProperty -MockWith { return $script:mockEnvironmentVar1 }
                Mock -CommandName Get-EnvironmentVariable -MockWith { return 'mock environment variable' }
                Mock -CommandName Set-MachineAndProcessEnvironmentVariables -MockWith { $script:mockEnvironmentVar1.PATH = $newPathValue }
                
                It 'Should not throw an exception' {
                    { Set-TargetResource -Name $script:mockEnvironmentVarName1 -Value $newPathValue -Path $true } | Should Not Throw
                }
                
                It 'Should not have updated the mock variable value' {
                    $script:mockEnvironmentVar1.PATH | Should Not Be $newPathValue
                }

                It 'Should have called the correct mocks' {
                    Assert-MockCalled Get-ItemProperty -Exactly 1 -Scope Context
                    Assert-MockCalled Get-EnvironmentVariable -Exactly 1 -Scope Context
                    Assert-MockCalled Set-MachineAndProcessEnvironmentVariables -Exactly 0 -Scope Context
                }
            }

            Context 'Update environment variable with Path and invalid value ( ) passed in' {
                $newPathValue = '    '
                Mock -CommandName Get-ItemProperty -MockWith { return $script:mockEnvironmentVar1 }
                Mock -CommandName Get-EnvironmentVariable -MockWith { return 'mock environment variable' }
                Mock -CommandName Set-MachineAndProcessEnvironmentVariables -MockWith { $script:mockEnvironmentVar1.PATH = $newPathValue }
                
                It 'Should not throw an exception' {
                    { Set-TargetResource -Name $script:mockEnvironmentVarName1 -Value $newPathValue -Path $true } | Should Not Throw
                }
                
                It 'Should not have updated the mock variable value' {
                    $script:mockEnvironmentVar1.PATH | Should Not Be $newPathValue
                }

                It 'Should have called the correct mocks' {
                    Assert-MockCalled Get-ItemProperty -Exactly 1 -Scope Context
                    Assert-MockCalled Get-EnvironmentVariable -Exactly 1 -Scope Context
                    Assert-MockCalled Set-MachineAndProcessEnvironmentVariables -Exactly 0 -Scope Context
                }
            }

            Context 'Update environment variable with new Path and valid value passed in' {
                $newPathValue = 'new path value 4'
                $newFullPathValue = ($script:mockEnvironmentVar1.PATH +';' + $newPathValue)
                Mock -CommandName Get-ItemProperty -MockWith { return $script:mockEnvironmentVar1 }
                Mock -CommandName Get-EnvironmentVariable -MockWith { return 'mock environment variable' }
                Mock -CommandName Set-MachineAndProcessEnvironmentVariables -MockWith { $script:mockEnvironmentVar1.PATH = $newFullPathValue }
                
                It 'Should not throw an exception' {
                    { Set-TargetResource -Name $script:mockEnvironmentVarName1 -Value $newPathValue -Path $true } | Should Not Throw
                }
                
                It 'Should not have updated the mock variable value' {
                    $script:mockEnvironmentVar1.PATH | Should Be $newFullPathValue
                }

                It 'Should have called the correct mocks' {
                    Assert-MockCalled Get-ItemProperty -Exactly 1 -Scope Context
                    Assert-MockCalled Get-EnvironmentVariable -Exactly 1 -Scope Context
                    Assert-MockCalled Set-MachineAndProcessEnvironmentVariables -Exactly 1 -Scope Context
                }
            }
        }

        Describe 'xEnvironmentResource\Test-TargetResource' {
        }

        Describe 'xEnvironmentResource\Get-EnvironmentVariable' {
        }

        Describe 'xEnvironmentResource\Set-EnvironmentVariable' {
        }

        Describe 'xEnvironmentResource\Set-MachineAndProcessEnvironmentVariables' {
        }

        Describe 'xEnvironmentResource\Remove-EnvironmentVariable' {
        }

        Describe 'xEnvironmentResource\Test-PathInPathListWithCriteria' {
        }

        Describe 'xEnvironmentResource\Test-PathInPathList' {
        }

        Describe 'xEnvironmentResource\Get-ItemPropertyExpanded' {
        }
    }
}
finally
{
    Exit-DscResourceTestEnvironment -TestEnvironment $script:testEnvironment
}

