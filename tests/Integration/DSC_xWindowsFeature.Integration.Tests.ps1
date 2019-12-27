<#
    Integration tests for Installing/uninstalling a Windows Feature. Currently Telnet-Client is
    set as the feature to test since it's fairly small and doesn't require a restart.
    RSAT-File-Services is set as the feature to test installing/uninstalling a feature with
    subfeatures.
#>
# Suppressing this rule since we need to create a plaintext password to test this resource
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param ()

$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'DSC_xWindowsFeature'

try
{
    Import-Module -Name DscResource.Test -Force
}
catch [System.IO.FileNotFoundException]
{
    throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -Tasks build" first.'
}

$script:testEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:dscModuleName `
    -DSCResourceName $script:dscResourceName `
    -ResourceType 'Mof' `
    -TestType 'Unit'

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\CommonTestHelper.psm1')
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\DSC_xUserResource.TestHelper.psm1')

<#
    If this is set to $true then the tests that test installing/uninstalling a feature with
    its subfeatures will not run.
#>
$script:skipLongTests = $false

# Begin Testing
try
{
    InModuleScope $script:dscResourceName {
        Describe 'xWindowsFeature Integration Tests' {
            BeforeAll {
                $script:testFeatureName = 'Telnet-Client'
                $script:testFeatureWithSubFeaturesName = 'RSAT-File-Services'

                # Saving the state so we can clean up afterwards
                $testFeature = Get-WindowsFeature -Name $script:testFeatureName
                $script:installStateOfTestFeature = $testFeature.Installed

                $testFeatureWithSubFeatures = Get-WindowsFeature -Name $script:testFeatureWithSubFeaturesName
                $script:installStateOfTestWithSubFeatures = $testFeatureWithSubFeatures.Installed

                $script:configFile = Join-Path -Path $PSScriptRoot -ChildPath 'DSC_xWindowsFeature.config.ps1' -Resolve
            }

            AfterAll {
                # Ensure that features used for testing are re-installed/uninstalled
                $feature = Get-WindowsFeature -Name $script:testFeatureName

                if ($script:installStateOfTestFeature -and -not $feature.Installed)
                {
                    Add-WindowsFeature -Name $script:testFeatureName
                }
                elseif ( -not $script:installStateOfTestFeature -and $feature.Installed)
                {
                    Remove-WindowsFeature -Name $script:testFeatureName
                }

                if (-not $script:skipLongTests)
                {
                    $feature = Get-WindowsFeature -Name $script:testFeatureWithSubFeaturesName

                    if ($script:installStateOfTestWithSubFeatures -and -not $feature.Installed)
                    {
                        Add-WindowsFeature -Name $script:testFeatureWithSubFeaturesName -IncludeAllSubFeature
                    }
                    elseif ( -not $script:installStateOfTestWithSubFeatures -and $feature.Installed)
                    {
                        Remove-WindowsFeature -Name $script:testFeatureWithSubFeaturesName
                    }
                }
            }

            Context "Should Install the Windows Feature: $script:testFeatureName" {
                $configurationName = 'DSC_xWindowsFeature_InstallFeature'
                $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

                $logPath = Join-Path -Path $TestDrive -ChildPath 'InstallFeatureTest.log'

                try
                {
                    # Ensure the feature is not already on the machine
                    Remove-WindowsFeature -Name $script:testFeatureName

                    It 'Should compile without throwing' {
                        {
                            . $script:configFile -ConfigurationName $configurationName
                            & $configurationName -Name $script:testFeatureName `
                                                -IncludeAllSubFeature $false `
                                                -Ensure 'Present' `
                                                -OutputPath $configurationPath `
                                                -ErrorAction 'Stop'
                            Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                        } | Should -Not -Throw
                    }

                    It 'Should be able to call Get-DscConfiguration without throwing' {
                        { Get-DscConfiguration -ErrorAction 'Stop' } | Should -Not -Throw
                    }

                    It 'Should return the correct configuration' {
                    $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                    $currentConfig.Name | Should -Be $script:testFeatureName
                    $currentConfig.IncludeAllSubFeature | Should -BeFalse
                    $currentConfig.Ensure | Should -Be 'Present'
                    }

                    It 'Should be Installed' {
                        $feature = Get-WindowsFeature -Name $script:testFeatureName
                        $feature.Installed | Should -BeTrue
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

            Context "Should Uninstall the Windows Feature: $script:testFeatureName" {
                $configurationName = 'DSC_xWindowsFeature_UninstallFeature'
                $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

                $logPath = Join-Path -Path $TestDrive -ChildPath 'UninstallFeatureTest.log'

                try
                {
                    It 'Should compile without throwing' {
                        {
                            . $script:configFile -ConfigurationName $configurationName
                            & $configurationName -Name $script:testFeatureName `
                                                -IncludeAllSubFeature $false `
                                                -Ensure 'Absent' `
                                                -OutputPath $configurationPath `
                                                -ErrorAction 'Stop'
                            Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                        } | Should -Not -Throw
                    }

                    It 'Should be able to call Get-DscConfiguration without throwing' {
                        { Get-DscConfiguration -ErrorAction 'Stop' } | Should -Not -Throw
                    }

                    It 'Should return the correct configuration' {
                    $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                    $currentConfig.Name | Should -Be $script:testFeatureName
                    $currentConfig.IncludeAllSubFeature | Should -BeFalse
                    $currentConfig.Ensure | Should -Be 'Absent'
                    }

                    It 'Should not be installed' {
                        $feature = Get-WindowsFeature -Name $script:testFeatureName
                        $feature.Installed | Should -BeFalse
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

            Context "Should Install the Windows Feature: $script:testFeatureWithSubFeaturesName" {
                $configurationName = 'DSC_xWindowsFeature_InstallFeatureWithSubFeatures'
                $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

                if (-not $script:skipLongTests)
                {
                    # Ensure that the feature is not already installed
                    Remove-WindowsFeature -Name $script:testFeatureWithSubFeaturesName
                }

                It 'Should compile without throwing' -Skip:$script:skipLongTests {
                    {
                        . $script:configFile -ConfigurationName $configurationName
                        & $configurationName -Name $script:testFeatureWithSubFeaturesName `
                                                -IncludeAllSubFeature $true `
                                                -Ensure 'Present' `
                                                -OutputPath $configurationPath `
                                                -ErrorAction 'Stop'
                        Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Should be able to call Get-DscConfiguration without throwing' -Skip:$script:skipLongTests {
                    { Get-DscConfiguration -ErrorAction 'Stop' } | Should -Not -Throw
                }

                It 'Should return the correct configuration' -Skip:$script:skipLongTests {
                    $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                    $currentConfig.Name | Should -Be $script:testFeatureWithSubFeaturesName
                    $currentConfig.IncludeAllSubFeature | Should -BeTrue
                    $currentConfig.Ensure | Should -Be 'Present'
                }

                It 'Should be Installed (includes check for subFeatures)' -Skip:$script:skipLongTests {
                    $feature = Get-WindowsFeature -Name $script:testFeatureWithSubFeaturesName
                    $feature.Installed | Should -BeTrue

                    foreach ($subFeatureName in $feature.SubFeatures)
                    {
                        $subFeature = Get-WindowsFeature -Name $subFeatureName
                        $subFeature.Installed | Should -BeTrue
                    }
                }
            }

            Context "Should Uninstall the Windows Feature: $script:testFeatureWithSubFeaturesName" {
                $configurationName = 'DSC_xWindowsFeature_UninstallFeatureWithSubFeatures'
                $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

                It 'Should compile without throwing' -Skip:$script:skipLongTests {
                    {
                        . $script:configFile -ConfigurationName $configurationName
                        & $configurationName -Name $script:testFeatureWithSubFeaturesName `
                                                -IncludeAllSubFeature $true `
                                                -Ensure 'Absent' `
                                                -OutputPath $configurationPath `
                                                -ErrorAction 'Stop'
                        Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Should be able to call Get-DscConfiguration without throwing' -Skip:$script:skipLongTests {
                    { Get-DscConfiguration -ErrorAction 'Stop' } | Should -Not -Throw
                }

                It 'Should return the correct configuration' -Skip:$script:skipLongTests  {
                    $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                    $currentConfig.Name | Should -Be $script:testFeatureWithSubFeaturesName
                    $currentConfig.IncludeAllSubFeature | Should -BeFalse
                    $currentConfig.Ensure | Should -Be 'Absent'
                }

                It 'Should not be installed (includes check for subFeatures)' -Skip:$script:skipLongTests {
                    $feature = Get-WindowsFeature -Name $script:testFeatureWithSubFeaturesName
                    $feature.Installed | Should -BeFalse

                    foreach ($subFeatureName in $feature.SubFeatures)
                    {
                        $subFeature = Get-WindowsFeature -Name $subFeatureName
                        $subFeature.Installed | Should -BeFalse
                    }
                }
            }
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
