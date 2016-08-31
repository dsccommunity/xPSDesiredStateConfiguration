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
        $script:testServiceCodePath = "$PSScriptRoot\..\DscTestService.cs"
        $script:testServiceDisplayName = "DSC test service display name"
        $script:testServiceDescription = "This is DSC test service used for integration testing MSFT_xServiceResource"
        $script:testServiceDependsOn = @('winrm','spooler')
        $script:testServiceDependsOnHash = @( @{ name = 'winrm' }, @{ name = 'spooler' } )
        $script:testServiceExecutablePath = Join-Path -Path $ENV:Temp -ChildPath "DscTestService.exe"
        $script:testServiceStartupType = 'Automatic'
        $script:testServiceStartupTypeWin32 = 'Auto'
        $script:testServiceStatus = 'Running'

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

        Describe "$DSCResourceName\Get-TargetResource" {
            Context 'Service exists' {
                Mock -CommandName Test-ServiceExists -MockWith { $true } -Verifiable
                Mock -CommandName Get-serviceResource -MockWith { $script:testServiceMockRunning } -verifable
                Mock -CommandName Get-Win32ServiceObject -MockWith { $script:testWin32ServiceMockRunningLocalSystem } -verifable

                It 'Should return the correct hashtable properties' {
                    $service = Get-TargetResource -Name $script:testServiceName

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
        }
    }
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}
