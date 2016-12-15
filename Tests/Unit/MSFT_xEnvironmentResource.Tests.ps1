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

