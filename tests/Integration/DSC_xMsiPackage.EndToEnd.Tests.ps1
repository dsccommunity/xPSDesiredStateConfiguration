<#
    Please note that some of these tests depend on each other.
    They must be run in the order given - if one test fails, subsequent tests may
    also fail.
#>
$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'DSC_xMsiPackage'

try
{
    Import-Module -Name DscResource.Test -Force
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
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\DSC_xPackageResource.TestHelper.psm1')

# Begin Testing
try
{
    InModuleScope $script:dscResourceName {
        Describe 'xMsiPackage End to End Tests' {
            BeforeAll {
                # Set up the paths to the test configurations
                $script:configurationFilePathNoOptionalParameters = Join-Path -Path $PSScriptRoot -ChildPath 'DSC_xMsiPackage_NoOptionalParameters'
                $script:configurationFilePathLogPath = Join-Path -Path $PSScriptRoot -ChildPath 'DSC_xMsiPackage_LogPath'

                <#
                    This log file is used to log messages from the mock server which is important for debugging since
                    most of the work of the mock server is done within a separate process.
                #>
                $script:logFile = Join-Path -Path $PSScriptRoot -ChildPath 'PackageTestLogFile.txt'
                $script:environmentInIncorrectStateErrorMessage = 'The current environment is not in the expected state for this test - either something was setup incorrectly on your machine or a previous test failed - results after this may be invalid.'

                $script:msiName = 'DSCSetupProject.msi'
                $script:msiLocation = Join-Path -Path $TestDrive -ChildPath $script:msiName

                $script:packageId = '{deadbeef-80c6-41e6-a1b9-8bdb8a05027f}'

                $null = New-TestMsi -DestinationPath $script:msiLocation

                $script:testHttpPort = Get-UnusedTcpPort
                $script:testHttpsPort = Get-UnusedTcpPort -ExcludePorts @($script:testHttpPort)

                # Clear the log file
                'Beginning integration tests' > $script:logFile
            }

            AfterAll {
                # Remove the test MSI if it is still installed
                if (Test-PackageInstalledById -ProductId $script:packageId)
                {
                    $null = Start-Process -FilePath 'msiexec.exe' -ArgumentList @("/x$script:packageId", '/passive') -Wait
                    $null = Start-Sleep -Seconds 1
                }

                if (Test-PackageInstalledById -ProductId $script:packageId)
                {
                    throw 'Test package could not be uninstalled after running all tests. It may cause errors in subsequent test runs.'
                }
            }

            Context 'Uninstall package that is already Absent' {
                $configurationName = 'RemoveAbsentMsiPackage'

                $msiPackageParameters = @{
                    ProductId = $script:packageId
                    Path = $script:msiLocation
                    Ensure = 'Absent'
                }

                It 'Should return True from Test-TargetResource with the same parameters before configuration' {
                    $testTargetResourceInitialResult = DSC_xMsiPackage\Test-TargetResource @msiPackageParameters
                    $testTargetResourceInitialResult | Should -BeTrue

                    if ($testTargetResourceInitialResult -ne $true)
                    {
                        <#
                            Not throwing an error here since the tests should still run correctly after this,
                            we just want to notify the user that the tests aren't necessarily testing what
                            they should be
                        #>
                        Write-Error -Message $script:environmentInIncorrectStateErrorMessage
                    }
                }

                It 'Package should not exist on the machine before configuration is run' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeFalse
                }

                It 'Should compile and run configuration' {
                    {
                        . $script:configurationFilePathNoOptionalParameters -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @msiPackageParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Should return True from Test-TargetResource with the same parameters after configuration' {
                    DSC_xMsiPackage\Test-TargetResource @msiPackageParameters | Should -BeTrue
                }

                It 'Package should not exist on the machine' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeFalse
                }
            }

            Context 'Install package that is not installed yet' {
                $configurationName = 'InstallMsiPackage'

                $msiPackageParameters = @{
                    ProductId = $script:packageId
                    Path = $script:msiLocation
                    Ensure = 'Present'
                }

                It 'Should return False from Test-TargetResource with the same parameters before configuration' {
                    $testTargetResourceInitialResult = DSC_xMsiPackage\Test-TargetResource @msiPackageParameters
                    $testTargetResourceInitialResult | Should -BeFalse

                    if ($testTargetResourceInitialResult -ne $false)
                    {
                        <#
                            Not throwing an error here since the tests should still run correctly after this,
                            we just want to notify the user that the tests aren't necessarily testing what
                            they should be
                        #>
                        Write-Error -Message $script:environmentInIncorrectStateErrorMessage
                    }
                }

                It 'Package should not exist on the machine before configuration is run' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeFalse
                }

                It 'Should compile and run configuration' {
                    {
                        . $script:configurationFilePathNoOptionalParameters -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @msiPackageParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Should return True from Test-TargetResource with the same parameters after configuration' {
                    DSC_xMsiPackage\Test-TargetResource @msiPackageParameters | Should -BeTrue
                }

                It 'Package should exist on the machine' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeTrue
                }
            }

            Context 'Install package that is already installed' {
                $configurationName = 'InstallExistingMsiPackage'

                $msiPackageParameters = @{
                    ProductId = $script:packageId
                    Path = $script:msiLocation
                    Ensure = 'Present'
                }

                It 'Should return True from Test-TargetResource with the same parameters before configuration' {
                    $testTargetResourceInitialResult = DSC_xMsiPackage\Test-TargetResource @msiPackageParameters
                    $testTargetResourceInitialResult | Should -BeTrue

                    if ($testTargetResourceInitialResult -ne $true)
                    {
                        <#
                            Not throwing an error here since the tests should still run correctly after this,
                            we just want to notify the user that the tests aren't necessarily testing what
                            they should be
                        #>
                        Write-Error -Message $script:environmentInIncorrectStateErrorMessage
                    }
                }

                It 'Package should exist on the machine before configuration is run' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeTrue
                }

                It 'Should compile and run configuration' {
                    {
                        . $script:configurationFilePathNoOptionalParameters -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @msiPackageParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Should return True from Test-TargetResource with the same parameters after configuration' {
                    DSC_xMsiPackage\Test-TargetResource @msiPackageParameters | Should -BeTrue
                }

                It 'Package should exist on the machine' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeTrue
                }
            }

            Context 'Uninstall package that is installed' {
                $configurationName = 'UninstallExistingMsiPackage'

                $msiPackageParameters = @{
                    ProductId = $script:packageId
                    Path = $script:msiLocation
                    Ensure = 'Absent'
                }

                It 'Should return False from Test-TargetResource with the same parameters before configuration' {
                    $testTargetResourceInitialResult = DSC_xMsiPackage\Test-TargetResource @msiPackageParameters
                    $testTargetResourceInitialResult | Should -BeFalse

                    if ($testTargetResourceInitialResult -ne $false)
                    {
                        <#
                            Not throwing an error here since the tests should still run correctly after this,
                            we just want to notify the user that the tests aren't necessarily testing what
                            they should be
                        #>
                        Write-Error -Message $script:environmentInIncorrectStateErrorMessage
                    }
                }

                It 'Package should exist on the machine before configuration is run' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeTrue
                }

                It 'Should compile and run configuration' {
                    {
                        . $script:configurationFilePathNoOptionalParameters -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @msiPackageParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Should return True from Test-TargetResource with the same parameters after configuration' {
                    DSC_xMsiPackage\Test-TargetResource @msiPackageParameters | Should -BeTrue
                }

                It 'Package should not exist on the machine' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeFalse
                }
            }

            Context 'Install package that is not installed and write to specified log file' {
                $configurationName = 'InstallWithLogFile'

                $logPath = Join-Path -Path $TestDrive -ChildPath 'TestMsiLog.txt'

                if (Test-Path -Path $logPath)
                {
                    Remove-Item -Path $logPath -Force
                }

                $msiPackageParameters = @{
                    ProductId = $script:packageId
                    Path = $script:msiLocation
                    Ensure = 'Present'
                    LogPath = $logPath
                }

                It 'Should return False from Test-TargetResource with the same parameters before configuration' {
                    $testTargetResourceInitialResult = DSC_xMsiPackage\Test-TargetResource @msiPackageParameters
                    $testTargetResourceInitialResult | Should -BeFalse

                    if ($testTargetResourceInitialResult -ne $false)
                    {
                        <#
                            Not throwing an error here since the tests should still run correctly after this,
                            we just want to notify the user that the tests aren't necessarily testing what
                            they should be
                        #>
                        Write-Error -Message $script:environmentInIncorrectStateErrorMessage
                    }
                }

                It 'Package should not exist on the machine before configuration is run' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeFalse
                }

                It 'Should compile and run configuration' {
                    {
                        . $script:configurationFilePathLogPath -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @msiPackageParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Should return True from Test-TargetResource with the same parameters after configuration' {
                    DSC_xMsiPackage\Test-TargetResource @msiPackageParameters | Should -BeTrue
                }

                It 'Should have created the log file' {
                    Test-Path -Path $logPath | Should -BeTrue
                }

                It 'Package should exist on the machine' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeTrue
                }
            }

            Context 'Uninstall package that is installed and write to specified log file' {
                $configurationName = 'InstallWithLogFile'

                $logPath = Join-Path -Path $TestDrive -ChildPath 'TestMsiLog.txt'

                if (Test-Path -Path $logPath)
                {
                    Remove-Item -Path $logPath -Force
                }

                $msiPackageParameters = @{
                    ProductId = $script:packageId
                    Path = $script:msiLocation
                    Ensure = 'Absent'
                    LogPath = $logPath
                }

                It 'Should return False from Test-TargetResource with the same parameters before configuration' {
                    $testTargetResourceInitialResult = DSC_xMsiPackage\Test-TargetResource @msiPackageParameters
                    $testTargetResourceInitialResult | Should -BeFalse

                    if ($testTargetResourceInitialResult -ne $false)
                    {
                        <#
                            Not throwing an error here since the tests should still run correctly after this,
                            we just want to notify the user that the tests aren't necessarily testing what
                            they should be
                        #>
                        Write-Error -Message $script:environmentInIncorrectStateErrorMessage
                    }
                }

                It 'Package should exist on the machine before configuration is run' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeTrue
                }

                It 'Should compile and run configuration' {
                    {
                        . $script:configurationFilePathLogPath -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @msiPackageParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Should return True from Test-TargetResource with the same parameters after configuration' {
                    DSC_xMsiPackage\Test-TargetResource @msiPackageParameters | Should -BeTrue
                }

                It 'Should have created the log file' {
                    Test-Path -Path $logPath | Should -BeTrue
                }

                It 'Package should not exist on the machine' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeFalse
                }
            }

            Context 'Install package from HTTP Url' {
                $configurationName = 'UninstallExistingMsiPackageFromHttp'

                $uriBuilder = [System.UriBuilder]::new('http', 'localhost', $script:testHttpPort)
                $uriBuilder.Path = 'package.msi'
                $msiUrl = $uriBuilder.Uri.AbsoluteUri

                $fileServerStarted = $null
                $job = $null

                $msiPackageParameters = @{
                    ProductId = $script:packageId
                    Path = $msiUrl
                    Ensure = 'Present'
                }

                It 'Should return False from Test-TargetResource with the same parameters before configuration' {
                    $testTargetResourceInitialResult = DSC_xMsiPackage\Test-TargetResource @msiPackageParameters
                    $testTargetResourceInitialResult | Should -BeFalse

                    if ($testTargetResourceInitialResult -ne $false)
                    {
                        <#
                            Not throwing an error here since the tests should still run correctly after this,
                            we just want to notify the user that the tests aren't necessarily testing what
                            they should be
                        #>
                        Write-Error -Message $script:environmentInIncorrectStateErrorMessage
                    }
                }

                It 'Package should not exist on the machine before configuration is run' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeFalse
                }

                try
                {
                    # Make sure no existing HTTP(S) test servers are running
                    Stop-EveryTestServerInstance

                    $serverResult = Start-Server -FilePath $script:msiLocation -LogPath $script:logFile -Https $false -HttpPort $script:testHttpPort -HttpsPort $script:testHttpsPort
                    $fileServerStarted = $serverResult.FileServerStarted
                    $job = $serverResult.Job

                    $fileServerStarted.WaitOne(30000)

                    It 'Should compile and run configuration' {
                        {
                            . $script:configurationFilePathNoOptionalParameters -ConfigurationName $configurationName
                            & $configurationName -OutputPath $TestDrive @msiPackageParameters
                            Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                        } | Should -Not -Throw
                    }
                }
                finally
                {
                    <#
                        This must be called after Start-Server to ensure the listening port is closed,
                        otherwise subsequent tests may fail until the machine is rebooted.
                    #>
                    Stop-Server -FileServerStarted $fileServerStarted -Job $job
                }

                It 'Should return True from Test-TargetResource with the same parameters after configuration' {
                    DSC_xMsiPackage\Test-TargetResource @msiPackageParameters | Should -BeTrue
                }

                It 'Package should exist on the machine' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeTrue
                }
            }

            Context 'Uninstall Msi package from HTTP Url' {
                $configurationName = 'InstallMsiPackageFromHttp'

                $uriBuilder = [System.UriBuilder]::new('http', 'localhost', $script:testHttpPort)
                $uriBuilder.Path = 'package.msi'
                $msiUrl = $uriBuilder.Uri.AbsoluteUri

                $fileServerStarted = $null
                $job = $null

                $msiPackageParameters = @{
                    ProductId = $script:packageId
                    Path = $msiUrl
                    Ensure = 'Absent'
                }

                It 'Should return False from Test-TargetResource with the same parameters before configuration' {
                    $testTargetResourceInitialResult = DSC_xMsiPackage\Test-TargetResource @msiPackageParameters
                    $testTargetResourceInitialResult | Should -BeFalse

                    if ($testTargetResourceInitialResult -ne $false)
                    {
                        <#
                            Not throwing an error here since the tests should still run correctly after this,
                            we just want to notify the user that the tests aren't necessarily testing what
                            they should be
                        #>
                        Write-Error -Message $script:environmentInIncorrectStateErrorMessage
                    }
                }

                It 'Package should exist on the machine before configuration is run' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeTrue
                }

                try
                {
                    # Make sure no existing HTTP(S) test servers are running
                    Stop-EveryTestServerInstance

                    $serverResult = Start-Server -FilePath $script:msiLocation -LogPath $script:logFile -Https $false -HttpPort $script:testHttpPort -HttpsPort $script:testHttpsPort
                    $fileServerStarted = $serverResult.FileServerStarted
                    $job = $serverResult.Job

                    $fileServerStarted.WaitOne(30000)

                    It 'Should compile and run configuration' {
                        {
                            . $script:configurationFilePathNoOptionalParameters -ConfigurationName $configurationName
                            & $configurationName -OutputPath $TestDrive @msiPackageParameters
                            Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                        } | Should -Not -Throw
                    }
                }
                finally
                {
                    <#
                        This must be called after Start-Server to ensure the listening port is closed,
                        otherwise subsequent tests may fail until the machine is rebooted.
                    #>
                    Stop-Server -FileServerStarted $fileServerStarted -Job $job
                }

                It 'Should return true from Test-TargetResource with the same parameters after configuration' {
                    DSC_xMsiPackage\Test-TargetResource @msiPackageParameters | Should -BeTrue
                }

                It 'Package should not exist on the machine' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeFalse
                }
            }

            Context 'Install Msi package from HTTPS Url' {
                $configurationName = 'InstallMsiPackageFromHttpS'

                $uriBuilder = [System.UriBuilder]::new('https', 'localhost', $script:testHttpsPort)
                $uriBuilder.Path = 'package.msi'
                $msiUrl = $uriBuilder.Uri.AbsoluteUri

                $fileServerStarted = $null
                $job = $null

                $msiPackageParameters = @{
                    ProductId = $script:packageId
                    Path = $msiUrl
                    Ensure = 'Present'
                }

                It 'Should return False from Test-TargetResource with the same parameters before configuration' {
                    $testTargetResourceInitialResult = DSC_xMsiPackage\Test-TargetResource @msiPackageParameters
                    $testTargetResourceInitialResult | Should -BeFalse

                    if ($testTargetResourceInitialResult -ne $false)
                    {
                        <#
                            Not throwing an error here since the tests should still run correctly after this,
                            we just want to notify the user that the tests aren't necessarily testing what
                            they should be
                        #>
                        Write-Error -Message $script:environmentInIncorrectStateErrorMessage
                    }
                }

                It 'Package should not exist on the machine before configuration is run' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeFalse
                }

                try
                {
                    # Make sure no existing HTTP(S) test servers are running
                    Stop-EveryTestServerInstance

                    $serverResult = Start-Server -FilePath $script:msiLocation -LogPath $script:logFile -Https $true -HttpPort $script:testHttpPort -HttpsPort $script:testHttpsPort
                    $fileServerStarted = $serverResult.FileServerStarted
                    $job = $serverResult.Job

                    $fileServerStarted.WaitOne(30000)

                    It 'Should compile and run configuration' {
                        {
                            . $script:configurationFilePathNoOptionalParameters -ConfigurationName $configurationName
                            & $configurationName -OutputPath $TestDrive @msiPackageParameters
                            Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                        } | Should -Not -Throw
                    }
                }
                finally
                {
                    <#
                        This must be called after Start-Server to ensure the listening port is closed,
                        otherwise subsequent tests may fail until the machine is rebooted.
                    #>
                    Stop-Server -FileServerStarted $fileServerStarted -Job $job
                }

                It 'Should return true from Test-TargetResource with the same parameters after configuration' {
                    DSC_xMsiPackage\Test-TargetResource @msiPackageParameters | Should -BeTrue
                }

                It 'Package should exist on the machine' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeTrue
                }
            }

            Context 'Uninstall Msi package from HTTPS Url' {
                $configurationName = 'UninstallMsiPackageFromHttps'

                $uriBuilder = [System.UriBuilder]::new('https', 'localhost', $script:testHttpsPort)
                $uriBuilder.Path = 'package.msi'
                $msiUrl = $uriBuilder.Uri.AbsoluteUri

                $fileServerStarted = $null
                $job = $null

                $msiPackageParameters = @{
                    ProductId = $script:packageId
                    Path = $msiUrl
                    Ensure = 'Absent'
                }

                It 'Should return False from Test-TargetResource with the same parameters before configuration' {
                    $testTargetResourceInitialResult = DSC_xMsiPackage\Test-TargetResource @msiPackageParameters
                    $testTargetResourceInitialResult | Should -BeFalse

                    if ($testTargetResourceInitialResult -ne $false)
                    {
                        <#
                            Not throwing an error here since the tests should still run correctly after this,
                            we just want to notify the user that the tests aren't necessarily testing what
                            they should be
                        #>
                        Write-Error -Message $script:environmentInIncorrectStateErrorMessage
                    }
                }

                It 'Package should exist on the machine before configuration is run' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeTrue
                }

                try
                {
                    # Make sure no existing HTTP(S) test servers are running
                    Stop-EveryTestServerInstance

                    $serverResult = Start-Server -FilePath $script:msiLocation -LogPath $script:logFile -Https $true -HttpPort $script:testHttpPort -HttpsPort $script:testHttpsPort
                    $fileServerStarted = $serverResult.FileServerStarted
                    $job = $serverResult.Job

                    $fileServerStarted.WaitOne(30000)

                    It 'Should compile and run configuration' {
                        {
                            . $script:configurationFilePathNoOptionalParameters -ConfigurationName $configurationName
                            & $configurationName -OutputPath $TestDrive @msiPackageParameters
                            Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                        } | Should -Not -Throw
                    }
                }
                finally
                {
                    <#
                        This must be called after Start-Server to ensure the listening port is closed,
                        otherwise subsequent tests may fail until the machine is rebooted.
                    #>
                    Stop-Server -FileServerStarted $fileServerStarted -Job $job
                }

                It 'Should return true from Test-TargetResource with the same parameters after configuration' {
                    DSC_xMsiPackage\Test-TargetResource @msiPackageParameters | Should -BeTrue
                }

                It 'Package should not exist on the machine' {
                    Test-PackageInstalledById -ProductId $script:packageId | Should -BeFalse
                }
            }
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
