$script:DSCModuleName   = 'xPSDesiredStateConfiguration'
$script:DSCResourceName = 'MSFT_xServiceResource'

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
    -TestType Integration
#endregion

# Using try/finally to always cleanup even if something awful happens.
try
{
    $script:testServiceName = "DscTestService"
    $script:testServiceCodePath = "$PSScriptRoot\..\DscTestService.cs"
    $script:testServiceDisplayName = "DSC test service display name"
    $script:testServiceDescription = "This is DSC test service used for integration testing MSFT_xServiceResource"
    $script:testServiceDependsOn = "winrm"
    $script:testServiceExecutablePath = Join-Path -Path $ENV:Temp -ChildPath "DscTestService.exe"

    Import-Module "$PSScriptRoot\..\CommonTestHelper.psm1" -Force
    Import-Module "$PSScriptRoot\..\MSFT_xServiceResource.TestHelper.psm1" -Force

    Stop-Service $script:testServiceName -ErrorAction SilentlyContinue

    # Create a new Service binary for the new service.
    New-ServiceBinary `
        -ServiceName $script:testServiceName `
        -ServiceCodePath $script:testServiceCodePath `
        -ServiceDisplayName $script:testServiceDisplayName `
        -ServiceDescription $script:testServiceDescription `
        -ServiceDependencies $script:testServiceDependencies `
        -ServiceExecutablePath $script:testServiceExecutablePath

    #region Integration Tests
    $ConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName)_Add.config.ps1"
    . $ConfigFile

    Describe "$($script:DSCResourceName)_Add_Integration" {
        #region DEFAULT TESTS
        It 'Should compile without throwing' {
            {
                & "$($script:DSCResourceName)_Add_Config" `
                    -OutputPath $TestEnvironment.WorkingFolder `
                    -ServiceName $script:testServiceName `
                    -ServicePath $script:testServiceExecutablePath `
                    -ServiceDisplayName $script:testServiceDisplayName `
                    -ServiceDescription $script:testServiceDescription `
                    -ServiceDependencies $script:testServiceDependencies
                Start-DscConfiguration -Path $TestEnvironment.WorkingFolder `
                    -ComputerName localhost -Wait -Verbose -Force
            } | Should not throw
        }

        It 'should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not throw
        }
        #endregion

        # Get the current service details
        $script:service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($script:testServiceName)'"
        It 'The service should exist' {
            $script:service | Should BeOfType 'Microsoft.Management.Infrastructure.CimInstance'
        }

        It 'Should have set the resource and all the parameters should match' {
            # Get the current service details
            $script:service.status                | Should Be 'OK'
            $script:service.pathname              | Should Be $script:testServiceExecutablePath
            $script:service.description           | Should Be $script:testServiceDescription
            $script:service.displayname           | Should Be $script:testServiceDisplayName
            $script:service.started               | Should Be $true
            $script:service.state                 | Should Be 'Running'
            $script:service.desktopinteract       | Should Be $true
            $script:service.startname             | Should Be 'LocalSystem'
            $script:service.startmode             | Should Be 'Auto'
        }
    }
    #endregion

    #region Integration Tests
    $ConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName)_Remove.config.ps1"
    . $ConfigFile

    Describe "$($script:DSCResourceName)_Remove_Integration" {
        #region DEFAULT TESTS
        It 'Should compile without throwing' {
            {
                & "$($script:DSCResourceName)_Remove_Config" `
                    -OutputPath $TestEnvironment.WorkingFolder `
                    -ServiceName $script:testServiceName
                $null = Start-DscConfiguration -Path $TestEnvironment.WorkingFolder `
                    -ComputerName localhost -Wait -Verbose -Force
            } | Should not throw
        }

        It 'should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not throw
        }
        #endregion

        # Get the current service details
        $script:service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($script:testServiceName)'"
        It 'The service should not exist' {
            $script:service | Should BeNullOrEmpty
        }
    }
    #endregion
}
finally
{
    # Clean up
    Remove-TestService `
        -ServiceName $script:testServiceName `
        -ServiceExecutablePath $script:testServiceExecutablePath

    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}
