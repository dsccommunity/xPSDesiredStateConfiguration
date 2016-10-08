$script:DSCModuleName   = 'xPSDesiredStateConfiguration'
$script:DSCResourceName = 'MSFT_xServiceResource'

Import-Module -Name (Join-Path -Path (Split-Path $PSScriptRoot -Parent) `
                               -ChildPath 'CommonTestHelper.psm1') `
                               -Force

$script:testEnvironment = Enter-DscResourceTestEnvironment `
    -DscResourceModuleName 'xPSDesiredStateConfiguration' `
    -DscResourceName 'MSFT_xServiceResource' `
    -TestType 'Integration'

try
{
    $script:testServiceName = 'DscTestService'
    $script:testServiceCodePath = Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath 'DscTestService.cs'
    $script:testServiceDisplayName = 'DSC test service display name'
    $script:testServiceDescription = 'This is a DSC test service used for integration testing MSFT_xServiceResource'
    $script:testServiceDependsOn = 'winrm'
    $script:testServiceExecutablePath = Join-Path -Path $ENV:Temp -ChildPath 'DscTestService.exe'
    $script:testServiceNewCodePath = Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath 'DscTestService.cs'
    $script:testServiceNewDisplayName = 'New: DSC test service display name'
    $script:testServiceNewDescription = 'New: This is a DSC test service used for integration testing MSFT_xServiceResource'
    $script:testServiceNewDependsOn = 'spooler'
    $script:testServiceNewExecutablePath = Join-Path -Path $ENV:Temp -ChildPath 'NewDscTestService.exe'
    
    <#
        Nano Server doesn't recognize 'spooler', so if these tests are being run on Nano
        this value must stay as 'winrm'
    #>
    if ($PSVersionTable.PSEdition -ieq 'Core') { $script:testServiceNewDependsOn = 'winrm' }

    Import-Module -Name (Join-Path -Path (Split-Path $PSScriptRoot -Parent) `
                               -ChildPath 'MSFT_xServiceResource.TestHelper.psm1') `
                               -Force

    Stop-Service $script:testServiceName -ErrorAction SilentlyContinue

    # Create new Service binaries for the new service.
    New-ServiceBinary `
        -ServiceName $script:testServiceName `
        -ServiceCodePath $script:testServiceCodePath `
        -ServiceDisplayName $script:testServiceDisplayName `
        -ServiceDescription $script:testServiceDescription `
        -ServiceDependsOn $script:testServiceDependsOn `
        -ServiceExecutablePath $script:testServiceExecutablePath

    New-ServiceBinary `
        -ServiceName $script:testServiceName `
        -ServiceCodePath $script:testServiceNewCodePath `
        -ServiceDisplayName $script:testServiceNewDisplayName `
        -ServiceDescription $script:testServiceNewDescription `
        -ServiceDependsOn $script:testServiceNewDependsOn `
        -ServiceExecutablePath $script:testServiceExecutablePath

    #region Integration Tests
    $configFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName)_Add.config.ps1"
    . $configFile

    Describe "$($script:DSCResourceName)_Add_Integration" {
        #region DEFAULT TESTS
        It 'Should compile and apply the MOF without throwing' {
            {
                & "$($script:DSCResourceName)_Add_Config" `
                    -OutputPath $TestEnvironment.WorkingFolder `
                    -ServiceName $script:testServiceName `
                    -ServicePath $script:testServiceExecutablePath `
                    -ServiceDisplayName $script:testServiceDisplayName `
                    -ServiceDescription $script:testServiceDescription `
                    -ServiceDependsOn $script:testServiceDependsOn
                Start-DscConfiguration -Path $TestEnvironment.WorkingFolder `
                    -ComputerName localhost -Wait -Verbose -Force
            } | Should not throw
        }

        It 'Should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not Throw
        }
        #endregion

        # Get the current service details
        $script:service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($script:testServiceName)'"
        It 'Should return a service of type CimInstance' {
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

    Reset-DSC

    #region Integration Tests
    $configFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName)_Edit.config.ps1"
    . $configFile

    Describe "$($script:DSCResourceName)_Edit_Integration" {
        #region DEFAULT TESTS
        It 'Should compile and apply the MOF without throwing' {
            {
                & "$($script:DSCResourceName)_Edit_Config" `
                    -OutputPath $TestEnvironment.WorkingFolder `
                    -ServiceName $script:testServiceName `
                    -ServicePath $script:testServiceNewExecutablePath `
                    -ServiceDisplayName $script:testServiceNewDisplayName `
                    -ServiceDescription $script:testServiceNewDescription `
                    -ServiceDependsOn $script:testServiceNewDependsOn
                Start-DscConfiguration -Path $TestEnvironment.WorkingFolder `
                    -ComputerName localhost -Wait -Verbose -Force
            } | Should not throw
        }

        It 'Should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not Throw
        }
        #endregion

        # Get the current service details
        $script:service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($script:testServiceName)'"
        It 'Should return a service or type CimInstance' {
            $script:service | Should BeOfType 'Microsoft.Management.Infrastructure.CimInstance'
        }

        It 'Should have set the resource and all the parameters should match' {
            # Get the current service details
            $script:service.status                | Should Be 'OK'
            $script:service.pathname              | Should Be $script:testServiceNewExecutablePath
            $script:service.description           | Should Be $script:testServiceNewDescription
            $script:service.displayname           | Should Be $script:testServiceNewDisplayName
            $script:service.started               | Should Be $false
            $script:service.state                 | Should Be 'Stopped'
            $script:service.desktopinteract       | Should Be $false
            $script:service.startname             | Should Be 'NT Authority\LocalService'
            $script:service.startmode             | Should Be 'Manual'
        }
    }
    #endregion

    Reset-DSC

    #region Integration Tests
    $configFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName)_Remove.config.ps1"
    . $configFile

    Describe "$($script:DSCResourceName)_Remove_Integration" {
        #region DEFAULT TESTS
        It 'Should compile and apply the MOF without throwing' {
            {
                & "$($script:DSCResourceName)_Remove_Config" `
                    -OutputPath $TestEnvironment.WorkingFolder `
                    -ServiceName $script:testServiceName
                Start-DscConfiguration -Path $TestEnvironment.WorkingFolder `
                    -ComputerName localhost -Wait -Verbose -Force
            } | Should not throw
        }

        It 'Should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not throw
        }
        #endregion

        # Get the current service details
        $script:service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($script:testServiceName)'"
        It 'Should return the service as null' {
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
