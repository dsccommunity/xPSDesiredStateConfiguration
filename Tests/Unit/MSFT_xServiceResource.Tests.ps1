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
                Mock -CommandName Test-ServiceExists -MockWith { $true } -Verifiable
                Mock -CommandName Get-serviceResource -MockWith { $script:testServiceMockRunning } -Verifiable
                Mock -CommandName Get-Win32ServiceObject -MockWith { $script:testWin32ServiceMockRunningLocalSystem } -Verifiable

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
                    Assert-MockCalled -CommandName Get-serviceResource -Exactly 1
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
        }

        Describe "$DSCResourceName\Set-TargetResource" {
        }

        Describe "$DSCResourceName\Test-StartupType" {
        }

        Describe "$DSCResourceName\ConvertTo-StartModeString" {
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
        }

        Describe "$DSCResourceName\Get-UserNameAndPassword" {
        }

        Describe "$DSCResourceName\Stop-ServiceResource" {
        }

        Describe "$DSCResourceName\Remove-Service" {
        }

        Describe "$DSCResourceName\Start-ServiceResource" {
        }

        Describe "$DSCResourceName\Resolve-StartupType" {
        }

        Describe "$DSCResourceName\Resolve-UserName" {
        }

        Describe "$DSCResourceName\New-InvalidArgumentError" {
        }

        Describe "$DSCResourceName\Test-ServiceExists" {
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
                    -MockWith { $script:testServiceMockRunning } -Verifiable

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
