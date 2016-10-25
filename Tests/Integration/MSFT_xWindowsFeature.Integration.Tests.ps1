<#
    <Description of Integration tests>
#> 

# Suppressing this rule since we need to create a plaintext password to test this resource
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param ()

Import-Module -Name (Join-Path -Path (Split-Path $PSScriptRoot -Parent) `
                               -ChildPath 'CommonTestHelper.psm1') `
                               -Force

$script:testEnvironment = Enter-DscResourceTestEnvironment `
    -DscResourceModuleName 'xPSDesiredStateConfiguration' `
    -DscResourceName 'MSFT_xWindowsFeature' `
    -TestType 'Integration'

$script:testFeatureName = 'Telnet-Client'
$script:installStateOfTestFeature

try {

    #Saving the state so we can clean up afterwards
    $testFeature = Get-WindowsFeature -Name $script:testFeatureName
    $script:installStateOfTestFeature = $testFeature.InstallState

    $configFile = Join-Path -Path $PSScriptRoot -ChildPath 'MSFT_xWindowsFeature.config.ps1'

    Describe 'xWindowsFeature Integration Tests' {

        $testIncludeAllSubFeature = $false

        Remove-WindowsFeature -Name $script:testFeatureName

        Context "Should Install the Windows Feature: $testFeatureName" {
            $configurationName = 'MSFT_xWindowsFeature_InstallFeature'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            $logPath = Join-Path -Path $TestDrive -ChildPath 'InstallFeatureTest.log'

            try
            {
                It 'Should compile without throwing' {
                    {
                        . $configFile -ConfigurationName $configurationName
                        & $configurationName -Name $script:testFeatureName `
                                             -IncludeAllSubFeature $testIncludeAllSubFeature `
                                             -Ensure 'Present' `
                                             -OutputPath $configurationPath `
                                             -ErrorAction 'Stop'
                        Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                    } | Should Not Throw
                }

                It 'Should be able to call Get-DscConfiguration without throwing' {
                    { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
                }
                
                It 'Should return the correct configuration' {
                   $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                   $currentConfig.Name | Should Be $script:testFeatureName
                   $currentConfig.IncludeAllSubFeature | Should Be $testIncludeAllSubFeature
                   $currentConfig.Ensure | Should Be 'Present'
                }
            }
            finally
            {
                if (Test-Path -Path $logPath) {
                    Remove-Item -Path $logPath -Recurse -Force
                }

                if (Test-Path -Path $configurationPath)
                {
                    Remove-Item -Path $configurationPath -Recurse -Force
                }
            }
        }

        Context "Should Uninstall the Windows Feature: $testFeatureName" {
            $configurationName = 'MSFT_xWindowsFeature_UninstallFeature'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            $logPath = Join-Path -Path $TestDrive -ChildPath 'InstallFeatureTest.log'

            try
            {
                It 'Should compile without throwing' {
                    {
                        . $configFile -ConfigurationName $configurationName
                        & $configurationName -Name $script:testFeatureName `
                                             -IncludeAllSubFeature $testIncludeAllSubFeature `
                                             -Ensure 'Absent' `
                                             -OutputPath $configurationPath `
                                             -ErrorAction 'Stop'
                        Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                    } | Should Not Throw
                }

                It 'Should be able to call Get-DscConfiguration without throwing' {
                    { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
                }
                
                It 'Should return the correct configuration' {
                   $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                   $currentConfig.Name | Should Be $script:testFeatureName
                   $currentConfig.IncludeAllSubFeature | Should Be $testIncludeAllSubFeature
                   $currentConfig.Ensure | Should Be 'Absent'
                }
            }
            finally
            {
                if (Test-Path -Path $logPath) {
                    Remove-Item -Path $logPath -Recurse -Force
                }

                if (Test-Path -Path $configurationPath)
                {
                    Remove-Item -Path $configurationPath -Recurse -Force
                }
            }
        }
    }
}
finally
{

    if ($script:installStateOfTestFeature -eq 'Installed')
    {
        Add-WindowsFeature -Name $script:testFeatureName
    }
    else
    {
        Remove-WindowsFeature -Name $script:testFeatureName
    }

    Exit-DscResourceTestEnvironment -TestEnvironment $script:testEnvironment
}


