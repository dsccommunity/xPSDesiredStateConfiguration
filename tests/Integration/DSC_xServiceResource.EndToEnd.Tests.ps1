<#
    Please note that these tests are currently dependent on each other.
    They must be run in the order given and if one test fails, subsequent tests will
    also fail.
#>
$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'DSC_xServiceResource'

try
{
    Import-Module -Name DscResource.Test -Force -ErrorAction 'Stop'
}
catch [System.IO.FileNotFoundException]
{
    throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -Tasks build" first.'
}

# This contains both tests of *-TargetResource functions and DSC tests
$script:testEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:dscModuleName `
    -DSCResourceName $script:dscResourceName `
    -ResourceType 'Mof' `
    -TestType 'All'

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\CommonTestHelper.psm1')
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\DSC_xServiceResource.TestHelper.psm1')

# Begin Testing
try
{
    InModuleScope $script:dscResourceName {
        Describe 'xServiceResource End to End Tests' {
            BeforeAll {
                # Configuration file paths
                $script:configurationAllExceptCredentialFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'DSC_xServiceResource_AllExceptCredential.config.ps1'
                $script:configurationCredentialOnlyFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'DSC_xServiceResource_CredentialOnly.config.ps1'

                # Create test service binary to be the existing service
                $script:existingServiceProperties = @{
                    Name = 'TestService'
                    DisplayName = 'TestDisplayName'
                    Description = 'Test service description'
                    Dependencies = @( 'winrm' )
                    Path = Join-Path -Path $TestDrive -ChildPath 'DscTestService.exe'
                }

                $existingServiceNewExecutableParameters = @{
                    ServiceName = $script:existingServiceProperties.Name
                    ServiceCodePath = Join-Path -Path $PSScriptRoot -ChildPath 'DscTestService.cs'
                    ServiceDisplayName = $script:existingServiceProperties.DisplayName
                    ServiceDescription = $script:existingServiceProperties.Description
                    ServiceDependsOn = $script:existingServiceProperties.Dependencies -join ', '
                    OutputPath = $script:existingServiceProperties.Path
                }

                New-ServiceExecutable @existingServiceNewExecutableParameters

                # Create test service binary to be the new service with the same name as the existing service
                $script:newServiceProperties = @{
                    Name = $script:existingServiceProperties.Name
                    DisplayName = 'NewTestDisplayName'
                    Description = 'New test service description'
                    Dependencies = @( 'spooler' )
                    Path = Join-Path -Path $TestDrive -ChildPath 'NewDscTestService.exe'
                }

                if (Test-IsNanoServer)
                {
                    # Nano Server does not recognize 'spooler', so keep the dependencies value as 'winrm'
                    $newServiceProperties['Dependencies'] = @( 'winrm' )
                }

                $newServiceNewExecutableParameters = @{
                    ServiceName = $script:newServiceProperties.Name
                    ServiceCodePath = Join-Path -Path $PSScriptRoot -ChildPath 'DscTestServiceNew.cs'
                    ServiceDisplayName = $script:newServiceProperties.DisplayName
                    ServiceDescription = $script:newServiceProperties.Description
                    ServiceDependsOn = $script:newServiceProperties.Dependencies -join ', '
                    OutputPath = $script:newServiceProperties.Path
                }

                New-ServiceExecutable @newServiceNewExecutableParameters

                $script:testServiceNames = @( $script:existingServiceProperties.Name )
                $script:testServiceExecutables = @( $script:existingServiceProperties.Path, $script:newServiceProperties.Path )
            }

            AfterAll {
                # Remove any created services
                foreach ($testServiceName in $script:testServiceNames)
                {
                    if (Test-ServiceExists -Name $testServiceName)
                    {
                        Remove-ServiceWithTimeout -Name $testServiceName
                    }
                }
            }

            Context 'Create a service' {
                Clear-DscLcmConfiguration

                $configurationName = 'TestCreateService'
                $resourceParameters = $script:existingServiceProperties

                It 'Should compile and apply the MOF without throwing' {
                    {
                        . $script:configurationAllExceptCredentialFilePath -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @resourceParameters
                        Reset-DscLcm
                        Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                    } | Should -Not -Throw
                }

                $service = Get-Service -Name $resourceParameters.Name -ErrorAction 'SilentlyContinue'
                $serviceCimInstance = Get-CimInstance -ClassName 'Win32_Service' -Filter "Name='$($resourceParameters.Name)'" -ErrorAction 'SilentlyContinue'

                It 'Should have created a new service with the specified name' {
                    $service | Should -Not -Be $null
                    $serviceCimInstance | Should -Not -Be $null

                    $service.Name | Should -Be $resourceParameters.Name
                    $serviceCimInstance.Name | Should -Be $resourceParameters.Name
                }

                It 'Should have created a new service with the specified path' {
                    $serviceCimInstance.PathName | Should -Be $resourceParameters.Path
                }

                It 'Should have created a new service with the specified display name' {
                    $service.DisplayName | Should -Be $resourceParameters.DisplayName
                }

                It 'Should have created a new service with the specified description' {
                    $serviceCimInstance.Description | Should -Be $resourceParameters.Description
                }

                It 'Should have created a new service with the specified dependencies' {
                    $differentDependencies = Compare-Object -ReferenceObject $resourceParameters.Dependencies -DifferenceObject $service.ServicesDependedOn.Name
                    $differentDependencies | Should -Be $null
                }

                It 'Should have created a new service with the default state as Running' {
                    $service.Status | Should -Be 'Running'
                }

                It 'Should have created a new service with the default startup type as Auto' {
                    $serviceCimInstance.StartMode | Should -Be 'Auto'
                }

                It 'Should have created a new service with the default startup account name as LocalSystem' {
                    $serviceCimInstance.StartName | Should -Be 'LocalSystem'
                }

                It 'Should have created a new service with the default desktop interaction setting as False' {
                    $serviceCimInstance.DesktopInteract | Should -BeFalse
                }

                It 'Should return true from Test-TargetResource with the same parameters' {
                    DSC_xServiceResource\Test-TargetResource @resourceParameters | Should -BeTrue
                }
            }

            Context 'Edit the service path, display name, description, and dependencies' {
                Clear-DscLcmConfiguration

                $configurationName = 'TestCreateService'
                $resourceParameters = $script:newServiceProperties

                It 'Should compile and apply the MOF without throwing' {
                    {
                        . $script:configurationAllExceptCredentialFilePath -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @resourceParameters
                        Reset-DscLcm
                        Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                    } | Should -Not -Throw
                }

                $service = Get-Service -Name $resourceParameters.Name -ErrorAction 'SilentlyContinue'
                $serviceCimInstance = Get-CimInstance -ClassName 'Win32_Service' -Filter "Name='$($resourceParameters.Name)'" -ErrorAction 'SilentlyContinue'

                It 'Should not have removed service with specified name' {
                    $service | Should -Not -Be $null
                    $serviceCimInstance | Should -Not -Be $null

                    $service.Name | Should -Be $resourceParameters.Name
                    $serviceCimInstance.Name | Should -Be $resourceParameters.Name
                }

                It 'Should have edited service to have the specified path' {
                    $serviceCimInstance.PathName | Should -Be $resourceParameters.Path
                }

                It 'Should have edited service to have the specified display name' {
                    $service.DisplayName | Should -Be $resourceParameters.DisplayName
                }

                It 'Should have edited service to have the specified description' {
                    $serviceCimInstance.Description | Should -Be $resourceParameters.Description
                }

                It 'Should have edited service to have the specified dependencies' {
                    $differentDependencies = Compare-Object -ReferenceObject $resourceParameters.Dependencies -DifferenceObject $service.ServicesDependedOn.Name
                    $differentDependencies | Should -Be $null
                }

                It 'Should not have changed the service state from Running' {
                    $service.Status | Should -Be 'Running'
                }

                It 'Should not have changed the service startup type from Auto' {
                    $serviceCimInstance.StartMode | Should -Be 'Auto'
                }

                It 'Should not have changed the service startup account name from LocalSystem' {
                    $serviceCimInstance.StartName | Should -Be 'LocalSystem'
                }

                It 'Should not have changed the service desktop interaction setting from False' {
                    $serviceCimInstance.DesktopInteract | Should -BeFalse
                }

                It 'Should return true from Test-TargetResource with the same parameters' {
                    DSC_xServiceResource\Test-TargetResource @resourceParameters | Should -BeTrue
                }
            }

            Context 'Edit the service startup type and state' {
                Clear-DscLcmConfiguration

                $configurationName = 'TestCreateService'
                $resourceParameters = @{
                    Name = $script:existingServiceProperties.Name
                    Path = $script:newServiceProperties.Path
                    StartupType = 'Manual'
                    State = 'Stopped'
                }

                It 'Should compile and apply the MOF without throwing' {
                    {
                        . $script:configurationAllExceptCredentialFilePath -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @resourceParameters
                        Reset-DscLcm
                        Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                    } | Should -Not -Throw
                }

                $service = Get-Service -Name $resourceParameters.Name -ErrorAction 'SilentlyContinue'
                $serviceCimInstance = Get-CimInstance -ClassName 'Win32_Service' -Filter "Name='$($resourceParameters.Name)'" -ErrorAction 'SilentlyContinue'

                It 'Should not have removed service with specified name' {
                    $service | Should -Not -Be $null
                    $serviceCimInstance | Should -Not -Be $null

                    $service.Name | Should -Be $resourceParameters.Name
                    $serviceCimInstance.Name | Should -Be $resourceParameters.Name
                }

                It 'Should have edited the service to have the specified state' {
                    $service.Status | Should -Be $resourceParameters.State
                }

                It 'Should have edited the service to have the specified startup type' {
                    $serviceCimInstance.StartMode | Should -Be $resourceParameters.StartupType
                }

                It 'Should return true from Test-TargetResource with the same parameters' {
                    DSC_xServiceResource\Test-TargetResource @resourceParameters | Should -BeTrue
                }
            }

            Context 'Edit the service start name and start password with Credential' {
                Clear-DscLcmConfiguration

                $configData = @{
                    AllNodes = @(
                        @{
                            NodeName = 'localhost'
                            PSDscAllowPlainTextPassword = $true
                        }
                    )
                }

                $configurationName = 'TestCreateService'
                $resourceParameters = @{
                    Name = 'TestService'
                    Credential = Get-TestAdministratorAccountCredential
                }

                It 'Should compile and apply the MOF without throwing' {
                    {
                        . $script:configurationCredentialOnlyFilePath -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive -ConfigurationData $configData @resourceParameters
                        Reset-DscLcm
                        Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                    } | Should -Not -Throw
                }

                $service = Get-Service -Name $resourceParameters.Name -ErrorAction 'SilentlyContinue'
                $serviceCimInstance = Get-CimInstance -ClassName 'Win32_Service' -Filter "Name='$($resourceParameters.Name)'" -ErrorAction 'SilentlyContinue'

                It 'Should not have removed service with specified name' {
                        $service | Should -Not -Be $null
                        $serviceCimInstance | Should -Not -Be $null

                        $service.Name | Should -Be $resourceParameters.Name
                        $serviceCimInstance.Name | Should -Be $resourceParameters.Name
                }

                It 'Should have edited the service to have the specified startup account name' {
                    $expectedStartName = $resourceParameters.Credential.UserName

                    if ($expectedStartName.StartsWith("$env:COMPUTERNAME\"))
                    {
                        $expectedStartName = $expectedStartName.TrimStart("$env:COMPUTERNAME\")
                    }

                    $serviceCimInstance.StartName | Should -Be ".\$expectedStartName"
                }

                It 'Should return true from Test-TargetResource with the same parameters' {
                    DSC_xServiceResource\Test-TargetResource @resourceParameters | Should -BeTrue
                }
            }

            Context 'Edit the service start name and start password with BuiltInAccount' {
                Clear-DscLcmConfiguration

                $configurationName = 'TestCreateService'
                $resourceParameters = @{
                    Name = 'TestService'
                    Path = $script:newServiceProperties.Path
                    BuiltInAccount = 'LocalService'
                }

                It 'Should compile and apply the MOF without throwing' {
                    {
                        . $script:configurationAllExceptCredentialFilePath -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @resourceParameters
                        Reset-DscLcm
                        Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                    } | Should -Not -Throw
                }

                $service = Get-Service -Name $resourceParameters.Name -ErrorAction 'SilentlyContinue'
                $serviceCimInstance = Get-CimInstance -ClassName 'Win32_Service' -Filter "Name='$($resourceParameters.Name)'" -ErrorAction 'SilentlyContinue'

                It 'Should not have removed service with specified name' {
                    $service | Should -Not -Be $null
                    $serviceCimInstance | Should -Not -Be $null

                    $service.Name | Should -Be $resourceParameters.Name
                    $serviceCimInstance.Name | Should -Be $resourceParameters.Name
                }

                It 'Should have edited the service to have the specified startup account name' {
                    $serviceCimInstance.StartName | Should -Be 'NT Authority\LocalService'
                }

                It 'Should return true from Test-TargetResource with the same parameters' {
                    DSC_xServiceResource\Test-TargetResource @resourceParameters | Should -BeTrue
                }
            }

            Context 'Remove the service' {
                Clear-DscLcmConfiguration

                $configurationName = 'TestCreateService'
                $resourceParameters = @{
                    Name = $script:existingServiceProperties.Name
                    Path = $script:existingServiceProperties.Path
                    Ensure = 'Absent'
                }

                It 'Should compile and apply the MOF without throwing' {
                    {
                        . $script:configurationAllExceptCredentialFilePath -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @resourceParameters
                        Reset-DscLcm
                        Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                    } | Should -Not -Throw
                }

                $service = Get-Service -Name $resourceParameters.Name -ErrorAction 'SilentlyContinue'
                $serviceCimInstance = Get-CimInstance -ClassName 'Win32_Service' -Filter "Name='$($resourceParameters.Name)'" -ErrorAction 'SilentlyContinue'

                It 'Should have removed the service with specified name' {
                    $service | Should -Be $null
                    $serviceCimInstance | Should -Be $null
                }

                It 'Should return true from Test-TargetResource with the same parameters' {
                    DSC_xServiceResource\Test-TargetResource @resourceParameters | Should -BeTrue
                }
            }
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
