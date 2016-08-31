[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param ()

$script:DSCModuleName      = 'xPSDesiredStateConfiguration'
$script:DSCResourceName    = 'MSFT_xServiceResource'

#region HEADER
# Integration Test Template Version: 1.1.0
[String] $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:DSCModuleName `
    -DSCResourceName $script:DSCResourceName `
    -TestType Unit
#endregion

# Begin Testing
try
{
    InModuleScope $script:DSCResourceName {
        $DSCResourceName = 'MSFT_xServiceResource'

        $script:testServiceName = "DscTestService"
        $script:testServiceDisplayName = "DSC test service display name"
        $script:testServiceDescription = "This is DSC test service used for integration testing MSFT_xServiceResource"
        $script:testServiceDependsOn = @('winrm','spooler')
        $script:testServiceDependsOnHash = @( @{ name = 'winrm' }, @{ name = 'spooler' } )
        $script:testServiceExecutablePath = Join-Path -Path $ENV:Temp -ChildPath "DscTestService.exe"
        $script:testServiceStartupType = 'Automatic'
        $script:testServiceStartupTypeWin32 = 'Auto'
        $script:testServiceStatus = 'Running'
        $script:testUsername = 'TestUser'
        $script:testPassword = 'DummyPassword'
        $script:testCredential = New-Object System.Management.Automation.PSCredential $script:testUsername, (ConvertTo-SecureString $script:testPassword -AsPlainText -Force)

        $script:testServiceMockRunning = @{
            Name               = $script:testServiceName
            ServiceName        = $script:testServiceName
            DisplayName        = $script:testServiceDisplayName
            StartType          = $script:testServiceStartupType
            Status             = $script:testServiceStatus
            ServicesDependedOn = $script:testServiceDependsOnHash
        }
        $script:testWin32ServiceMockRunningLocalSystem = @{
            Name                    = $script:testServiceName
            Status                  = 'OK'
            DesktopInteract         = $true
            PathName                = $script:testServiceExecutablePath
            StartMode               = $script:testServiceStartupTypeWin32
            Description             = $script:testServiceDescription
            Started                 = $true
            DisplayName             = $script:testServiceDisplayName
            StartName               = 'LocalSystem'
            State                   = $script:testServiceStatus
        }
        $script:splatServiceExistsAutomatic = @{
            Name                    = $script:testServiceName
            StartupType             = $script:testServiceStartupType
            BuiltInAccount          = 'LocalSystem'
            DesktopInteract         = $true
            State                   = $script:testServiceStatus
            Ensure                  = 'Present'
            Path                    = $script:testServiceExecutablePath
            DisplayName             = $script:testServiceDisplayName
            Description             = $script:testServiceDescription
        }

        function Get-InvalidArgumentError
        {
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [System.String]
                $ErrorId,

                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [System.String]
                $ErrorMessage
            )

            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $ErrorMessage
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $ErrorId, $errorCategory, $null
            return $errorRecord
        } # end function Get-InvalidArgumentError

        Describe "$DSCResourceName\Get-TargetResource" {
            Context 'Service exists' {
                # Mocks that should be called
                Mock `
                    -CommandName Test-ServiceExists `
                    -MockWith { $true } `
                    -Verifiable
                Mock `
                    -CommandName Get-ServiceResource `
                    -MockWith { $script:testServiceMockRunning } `
                    -Verifiable
                Mock `
                    -CommandName Get-Win32ServiceObject `
                    -MockWith { $script:testWin32ServiceMockRunningLocalSystem } `
                    -Verifiable

                It 'Should not throw an exception' {
                    { $script:service = Get-TargetResource -Name $script:testServiceName -Verbose } | Should Not Throw
                }

                It 'Should return the correct hashtable properties' {
                    $service.Ensure          | Should Be 'Present'
                    $service.Name            | Should Be $script:testServiceName
                    $service.StartupType     | Should Be $script:testServiceStartupType
                    $service.BuiltInAccount  | Should Be 'LocalSystem'
                    $service.State           | Should Be $script:testServiceStatus
                    $service.Path            | Should Be $script:testServiceExecutablePath
                    $service.DisplayName     | Should Be $script:testServiceDisplayName
                    $service.Description     | Should Be $script:testServiceDescription
                    $service.DesktopInteract | Should Be $true
                    $service.Dependencies    | Should Be $script:testServiceDependsOn
                }

                It 'Should call expected Mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled -CommandName Test-ServiceExists -Exactly 1
                    Assert-MockCalled -CommandName Get-ServiceResource -Exactly 1
                    Assert-MockCalled -CommandName Get-Win32ServiceObject -Exactly 1
                }
            }

            Context 'Service does not exist' {
                # Mocks that should be called
                Mock -CommandName Test-ServiceExists -MockWith { $false } -Verifiable

                # Mocks that should not be called
                Mock -CommandName Get-serviceResource
                Mock -CommandName Get-Win32ServiceObject

                It 'Should not throw an exception' {
                    { $script:service = Get-TargetResource -Name $script:testServiceName -Verbose } | Should Not Throw
                }

                It 'Should return the correct hashtable properties' {
                    $service.Ensure          | Should Be 'Absent'
                    $service.Name            | Should Be $script:testServiceName
                }

                It 'Should call expected Mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled -CommandName Test-ServiceExists -Exactly 1
                    Assert-MockCalled -CommandName Get-serviceResource -Exactly 0
                    Assert-MockCalled -CommandName Get-Win32ServiceObject -Exactly 0
                }
            }
        }

        Describe "$DSCResourceName\Test-TargetResource" {
            Mock `
                -CommandName Test-StartupType `
                -Verifiable

            Context 'Service exists and should, and all parameters match' {
                # Mocks that should be called
                Mock `
                    -CommandName Test-ServiceExists `
                    -MockWith { $true } `
                    -Verifiable
                Mock `
                    -CommandName Get-ServiceResource `
                    -MockWith { $script:testServiceMockRunning } `
                    -Verifiable
                Mock `
                    -CommandName Get-Win32ServiceObject `
                    -MockWith { $script:testWin32ServiceMockRunningLocalSystem } `
                    -Verifiable
                Mock `
                    -CommandName Compare-ServicePath `
                    -MockWith { $true } `
                    -Verifiable

                It 'Should not throw an exception' {
                    { $script:result = Test-TargetResource @script:splatServiceExistsAutomatic -Verbose } | Should Not Throw
                }

                It 'Should return true' {
                    $script:result | Should Be $True
                }

                It 'Should call expected Mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled -CommandName Test-StartupType -Exactly 1
                    Assert-MockCalled -CommandName Test-ServiceExists -Exactly 1
                    Assert-MockCalled -CommandName Get-ServiceResource -Exactly 1
                    Assert-MockCalled -CommandName Get-Win32ServiceObject -Exactly 1
                    Assert-MockCalled -CommandName Compare-ServicePath -Exactly 1
                }
            }

        }

        Describe "$DSCResourceName\Set-TargetResource" {
        }

        Describe "$DSCResourceName\Test-StartupType" {
            Context 'Service is stopped, startup is automatic' {
                $errorRecord = Get-InvalidArgumentError `
                    -ErrorId "CannotStopServiceSetToStartAutomatically" `
                    -ErrorMessage ($LocalizedData.CannotStopServiceSetToStartAutomatically -f $script:testServiceName)

                It 'Shoult throw CannotStopServiceSetToStartAutomatically exception' {
                    { Test-StartupType `
                        -Name $script:testServiceName `
                        -StartupType 'Automatic' `
                        -State 'Stopped' } | Should Throw $errorRecord
                }
            }

            Context 'Service is stopped, startup is not automatic' {
                It 'Shoult not throw exception' {
                    { Test-StartupType `
                        -Name $script:testServiceName `
                        -StartupType 'Disabled' `
                        -State 'Stopped' } | Should Not Throw
                }
            }

            Context 'Service is running, startup is disabled' {
                $errorRecord = Get-InvalidArgumentError `
                    -ErrorId "CannotStartAndDisable" `
                    -ErrorMessage ($LocalizedData.CannotStartAndDisable -f $script:testServiceName)

                It 'Shoult throw CannotStartAndDisable exception' {
                    { Test-StartupType `
                        -Name $script:testServiceName `
                        -StartupType 'Disabled' `
                        -State 'Running' } | Should Throw $errorRecord
                }
            }

            Context 'Service is running, startup is not disabled' {
                It 'Shoult not throw exception' {
                    { Test-StartupType `
                        -Name $script:testServiceName `
                        -StartupType 'Manual' `
                        -State 'Running' } | Should Not Throw
                }
            }
        }

        Describe "$DSCResourceName\ConvertTo-StartModeString" {
            Context "StartupType is 'Automatic'" {
                It "Should return 'Automatic'" {
                    ConvertTo-StartModeString -StartupType 'Automatic' | Should Be 'Auto'
                }
            }
            Context "StartupType is 'Disabled'" {
                It "Should return 'Disabled'" {
                    ConvertTo-StartModeString -StartupType 'Disabled' | Should Be 'Disabled'
                }
            }
        }

        Describe "$DSCResourceName\ConvertTo-StartupTypeString" {
            Context "StartupType is 'Auto'" {
                It "Should return 'Automatic'" {
                    ConvertTo-StartupTypeString -StartupType 'Auto' | Should Be 'Automatic'
                }
            }
            Context "StartupType is 'Disabled'" {
                It "Should return 'Disabled'" {
                    ConvertTo-StartupTypeString -StartupType 'Disabled' | Should Be 'Disabled'
                }
            }
        }

        Describe "$DSCResourceName\Write-WriteProperties" {
        }

        Describe "$DSCResourceName\Get-Win32ServiceObject" {
        }

        Describe "$DSCResourceName\Set-ServiceStartupType" {
        }

        Describe "$DSCResourceName\Write-CredentialProperties" {
        }

        Describe "$DSCResourceName\Write-BinaryProperties" {
        }

        Describe "$DSCResourceName\Test-UserName" {
            Context 'Username matches' {
                It 'Should not thrown an exception' {
                    { $script:result = Test-Username `
                        -SvcWmi $script:testWin32ServiceMockRunningLocalSystem `
                        -Username $script:testUsername } | Should Not Throw
                }
                It 'Should return true' {
                    $script:result = $true
                }
            }
            Context 'Username does not match' {
                It 'Should not thrown an exception' {
                    { $script:result = Test-Username `
                        -SvcWmi $script:testWin32ServiceMockRunningLocalSystem `
                        -Username 'mismatch' } | Should Not Throw
                }
                It 'Should return false' {
                    $script:result = $false
                }
            }
        }

        Describe "$DSCResourceName\Get-UserNameAndPassword" {
            Context 'Built-in account provided' {
                $script:result = Get-UserNameAndPassword -BuiltInAccount 'LocalService'

                It "Should return 'NT Authority\LocalService' and `$null" {
                     $script:result[0] | Should Be 'NT Authority\LocalService'
                     $script:result[1] | Should BeNullOrEmpty
                }
            }
            Context 'Credential provided' {
                $script:result = Get-UserNameAndPassword -Credential $script:testCredential

                It "Should return '.\$($script:testUsername)' and '$($script:testPassword)'" {
                     $script:result[0] | Should Be ".\$script:testUsername"
                     $script:result[1] | Should Be $script:testPassword
                }
            }
            Context 'Neither built-in account or credential provided' {
                $script:result = Get-UserNameAndPassword

                It "Should return '$null' and '$null'" {
                     $script:result[0] | Should BeNullOrEmpty
                     $script:result[1] | Should BeNullOrEmpty
                }
            }
        }

        Describe "$DSCResourceName\Stop-ServiceResource" {
        }

        Describe "$DSCResourceName\Remove-Service" {
        }

        Describe "$DSCResourceName\Start-ServiceResource" {
        }

        Describe "$DSCResourceName\Resolve-UserName" {
            Context "Username is 'NetworkService'" {
                It "Should return 'NT Authority\NetworkService'" {
                    Resolve-UserName -Username 'NetworkService' | Should Be 'NT Authority\NetworkService'
                }
            }
            Context "Username is 'LocalService'" {
                It "Should return 'NT Authority\LocalService'" {
                    Resolve-UserName -Username 'LocalService' | Should Be 'NT Authority\LocalService'
                }
            }
            Context "Username is 'LocalSystem'" {
                It "Should return '.\LocalSystem'" {
                    Resolve-UserName -Username 'LocalSystem' | Should Be '.\LocalSystem'
                }
            }
            Context "Username is 'Domain\svcAccount'" {
                It "Should return 'Domain\svcAccount'" {
                    Resolve-UserName -Username 'Domain\svcAccount' | Should Be 'Domain\svcAccount'
                }
            }
            Context "Username is 'svcAccount'" {
                It "Should return '.\svcAccount'" {
                    Resolve-UserName -Username 'svcAccount' | Should Be '.\svcAccount'
                }
            }
        }

        Describe "$DSCResourceName\New-InvalidArgumentError" {
            Context 'Throws exception' {
                $errorRecord = Get-InvalidArgumentError `
                    -ErrorId "ErrorId" `
                    -ErrorMessage "ErrorMessage"

                It 'Throws exception' {
                    { New-InvalidArgumentError `
                        -ErrorId "ErrorId" `
                        -ErrorMessage "ErrorMessage"
                    } | Should Throw $errorRecord
                }
            }
        }

        Describe "$DSCResourceName\Test-ServiceExists" {
            Context 'Service exists' {
                # Mocks that should be called
                Mock `
                    -CommandName Get-Service `
                    -ParameterFilter { $Name -eq $script:testServiceName } `
                    -MockWith { $script:testServiceMockRunning } `
                    -Verifiable

                It 'Should not throw an exception' {
                    { $script:result = Test-ServiceExists -Name $script:testServiceName -Verbose } | Should Not Throw
                }

                It 'Result is true' {
                    $script:Result | Should Be $true
                }

                It 'Should call expected Mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Get-Service `
                        -ParameterFilter { $Name -eq $script:testServiceName } `
                        -Exactly 1
                }
            }

            Context 'Service does not exist' {
                # Mocks that should be called
                Mock `
                    -CommandName Get-Service `
                    -ParameterFilter { $Name -eq $script:testServiceName } `
                    -Verifiable

                It 'Should not throw an exception' {
                    { $script:result = Test-ServiceExists -Name $script:testServiceName -Verbose } | Should Not Throw
                }

                It 'Result is false' {
                    $script:Result | Should Be $false
                }


                It 'Should call expected Mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Get-Service `
                        -ParameterFilter { $Name -eq $script:testServiceName } `
                        -Exactly 1
                }
            }
        }

        Describe "$DSCResourceName\Compare-ServicePath" {
            Context 'Service exists, path matches' {
                # Mocks that should be called
                Mock `
                    -CommandName Get-CimInstance `
                    -MockWith { $script:testWin32ServiceMockRunningLocalSystem } `
                    -Verifiable

                It 'Should not throw an exception' {
                    { $script:result = Compare-ServicePath `
                        -Name $script:testServiceName `
                        -Path $script:testServiceExecutablePath `
                        -Verbose } | Should Not Throw
                }

                It 'Result is true' {
                    $script:Result | Should Be $true
                }

                It 'Should call expected Mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Get-CimInstance `
                        -Exactly 1
                }
            }

            Context 'Service exists, path does not match' {
                # Mocks that should be called
                Mock `
                    -CommandName Get-CimInstance `
                    -MockWith { $script:testWin32ServiceMockRunningLocalSystem } `
                    -Verifiable

                It 'Should not throw an exception' {
                    { $script:result = Compare-ServicePath `
                        -Name $script:testServiceName `
                        -Path 'c:\differentpath' `
                        -Verbose } | Should Not Throw
                }

                It 'Result is false' {
                    $script:Result | Should Be $false
                }

                It 'Should call expected Mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Get-CimInstance `
                        -Exactly 1
                }
            }

            Context 'Service does not exist' {
                # Mocks that should be called
                Mock `
                    -CommandName Get-CimInstance `
                    -Verifiable

                It 'Should not throw an exception' {
                    { $script:result = Compare-ServicePath `
                        -Name $script:testServiceName `
                        -Path 'c:\differentpath' `
                        -Verbose } | Should Not Throw
                }

                It 'Result is false' {
                    $script:Result | Should Be $false
                }

                It 'Should call expected Mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Get-CimInstance `
                        -Exactly 1
                }
            }
        }

        Describe "$DSCResourceName\Get-ServiceResource" {
            Context 'Service exists' {
                # Mocks that should be called
                Mock `
                    -CommandName Get-Service `
                    -ParameterFilter { $Name -eq $script:testServiceName } `
                    -MockWith { $script:testServiceMockRunning } `
                    -Verifiable

                It 'Should not throw an exception' {
                    { $script:service = Get-ServiceResource -Name $script:testServiceName -Verbose } | Should Not Throw
                }

                It 'Should return the correct hashtable properties' {
                    $script:service.Name               | Should Be $script:testServiceName
                    $script:service.ServiceName        | Should Be $script:testServiceName
                    $script:service.DisplayName        | Should Be $script:testServiceDisplayName
                    $script:service.StartType          | Should Be $script:testServiceStartupType
                    $script:service.Status             | Should Be $script:testServiceStatus
                    $script:service.ServicesDependedOn | Should Be $script:testServiceDependsOnHash
                }

                It 'Should call expected Mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Get-Service `
                        -ParameterFilter { $Name -eq $script:testServiceName } `
                        -Exactly 1
                }
            }

            Context 'Service does not exist' {
                # Mocks that should be called
                Mock `
                    -CommandName Get-Service `
                    -ParameterFilter { $Name -eq $script:testServiceName } `
                    -Verifiable

                $errorRecord = Get-InvalidArgumentError `
                    -ErrorId "ServiceNotFound" `
                    -ErrorMessage ($LocalizedData.ServiceNotFound -f $script:testServiceName)

                It 'Should throw a ServiceNotFound exception' {
                    { $script:service = Get-ServiceResource -Name $script:testServiceName -Verbose } | Should Throw $errorRecord
                }

                It 'Should call expected Mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Get-Service `
                        -ParameterFilter { $Name -eq $script:testServiceName } `
                        -Exactly 1
                }
            }
        }

        Describe "$DSCResourceName\Set-LogOnAsServicePolicy" {
            # TODO: a non-destructive method of testing this function
        }
    }
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}
