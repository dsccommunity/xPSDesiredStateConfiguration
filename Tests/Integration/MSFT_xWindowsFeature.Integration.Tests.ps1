<#
    Integration tests for Installing/uninstalling a Windows Feature. Currently Telnet-Client is
<<<<<<< .mine
    set as the feature to test since it's fairly small and doesn't require a restart. ADRMS
    is set as the feature to test installing/uninstalling a feature with subfeatures 
    and management tools, but this takes a good chunk of time, so by default 
    these tests are set to be skipped.
    If there's any major changes to the resource, then set the skipLongTests variable to $false
    and run those tests at least once to test the new functionality more completely. 
=======
    set as the feature to test since it's fairly small and doesn't require a restart.
    RSAT-File-Services is set as the feature to test installing/uninstalling a feature with
    subfeatures.



>>>>>>> .theirs
#> 

# Suppressing this rule since we need to create a plaintext password to test this resource
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param ()

Import-Module -Name (Join-Path -Path (Split-Path $PSScriptRoot -Parent) `
                               -ChildPath 'CommonTestHelper.psm1') `
                               -Force

# Import module for Get-WindowsFeatureManagamentTool
Import-Module -Name "$PSScriptRoot\..\..\DSCResources\MSFT_xWindowsFeature\ManagementToolUtils.psm1"

$script:testEnvironment = Enter-DscResourceTestEnvironment `
    -DscResourceModuleName 'xPSDesiredStateConfiguration' `
    -DscResourceName 'MSFT_xWindowsFeature' `
    -TestType 'Integration'

$script:testFeatureName = 'Telnet-Client'
$script:testFeatureWithSubFeaturesName = 'ADRMS'
$script:testFeatureWithMgmtToolsName = 'ADRMS'
$script:installStateOfTestFeature
$script:installStateOfTestWithSubFeatures

<#
    If this is set to $true then the tests that test installing/uninstalling a feature with
    its subfeatures or management tools will not run.
#>
$script:skipLongTests = $false

try {
    Describe 'xWindowsFeature Integration Tests' {
        BeforeAll {
            $script:testFeatureName = 'Telnet-Client'
            $script:testFeatureWithSubFeaturesName = 'RSAT-File-Services'

            #Saving the state so we can clean up afterwards
            $testFeature = Get-WindowsFeature -Name $script:testFeatureName
            $script:installStateOfTestFeature = $testFeature.Installed

            $testFeatureWithSubFeatures = Get-WindowsFeature -Name $script:testFeatureWithSubFeaturesName
            $script:installStateOfTestWithSubFeatures = $testFeatureWithSubFeatures.Installed

<<<<<<< .mine
    $testFeatureWithMgmtTools = Get-WindowsFeature -Name $script:testFeatureWithMgmtToolsName
    $script:installStateOfTestWithMgmtTools = $testFeatureWithMgmtTools.Installed

    $configFile = Join-Path -Path $PSScriptRoot -ChildPath 'MSFT_xWindowsFeature.config.ps1'
=======
            $configFile = Join-Path -Path $PSScriptRoot -ChildPath 'MSFT_xWindowsFeature.config.ps1'
        }


>>>>>>> .theirs

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
        $testIncludeMgmtTools = $false

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
            $configurationName = 'MSFT_xWindowsFeature_InstallFeature'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            $logPath = Join-Path -Path $TestDrive -ChildPath 'InstallFeatureTest.log'

            try
            {
                # Ensure the feature is not already on the machine
                Remove-WindowsFeature -Name $script:testFeatureName

                It 'Should compile without throwing' {
                    {
                        . $configFile -ConfigurationName $configurationName
                        & $configurationName -Name $script:testFeatureName `
                                             -IncludeAllSubFeature $false `
                                             -IncludeManagementTools $testIncludeMgmtTools `
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
                   $currentConfig.IncludeAllSubFeature | Should Be $false
                   $currentConfig.IncludeManagementTools | Should Be $testIncludeMgmtTools
                   $currentConfig.Ensure | Should Be 'Present'
                }

                It 'Should be Installed' {
                    $feature = Get-WindowsFeature -Name $script:testFeatureName
                    $feature.Installed | Should Be $true
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
            $configurationName = 'MSFT_xWindowsFeature_UninstallFeature'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            $logPath = Join-Path -Path $TestDrive -ChildPath 'UninstallFeatureTest.log'

            try
            {
                It 'Should compile without throwing' {
                    {
                        . $configFile -ConfigurationName $configurationName
                        & $configurationName -Name $script:testFeatureName `
                                             -IncludeAllSubFeature $false `
                                             -IncludeManagementTools $testIncludeMgmtTools `
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
                   $currentConfig.IncludeAllSubFeature | Should Be $false
                   $currentConfig.IncludeManagementTools | Should Be $testIncludeMgmtTools
                   $currentConfig.Ensure | Should Be 'Absent'
                }

                It 'Should not be installed' {
                    $feature = Get-WindowsFeature -Name $script:testFeatureName
                    $feature.Installed | Should Be $false
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

        Context "Should Install the Windows Feature: $script:testFeatureWithSubFeaturesName with subfeatures" {
            $configurationName = 'MSFT_xWindowsFeature_InstallFeatureWithSubFeatures'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            $logPath = Join-Path -Path $TestDrive -ChildPath 'InstallSubFeatureTest.log'

            if (-not $script:skipLongTests)
            {
                # Ensure that the feature is not already installed
                Remove-WindowsFeature -Name $script:testFeatureWithSubFeaturesName
            }

            It 'Should compile without throwing' -Skip:$script:skipLongTests {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $script:testFeatureWithSubFeaturesName `
                                            -IncludeAllSubFeature $true `
                                            -Ensure 'Present' `
                                            -OutputPath $configurationPath `
                                            -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

<<<<<<< .mine
                It 'Should compile without throwing' -Skip:$script:skipLongTests {
                    {
                        . $configFile -ConfigurationName $configurationName
                        & $configurationName -Name $script:testFeatureWithSubFeaturesName `
                                             -IncludeAllSubFeature $true `
                                             -IncludeManagementTools $testIncludeMgmtTools `
                                             -Ensure 'Present' `
                                             -OutputPath $configurationPath `
                                             -ErrorAction 'Stop'
                        Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                    } | Should Not Throw
                }

                It 'Should be able to call Get-DscConfiguration without throwing' -Skip:$script:skipLongTests {
                    { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
                }
=======
            It 'Should be able to call Get-DscConfiguration without throwing' -Skip:$script:skipLongTests {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }













>>>>>>> .theirs
                
            It 'Should return the correct configuration' -Skip:$script:skipLongTests {
                $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                $currentConfig.Name | Should Be $script:testFeatureWithSubFeaturesName
                $currentConfig.IncludeAllSubFeature | Should Be $true
                $currentConfig.Ensure | Should Be 'Present'
            }

            It 'Should be Installed (includes check for subFeatures)' -Skip:$script:skipLongTests {
                $feature = Get-WindowsFeature -Name $script:testFeatureWithSubFeaturesName
                $feature.Installed | Should Be $true

                foreach ($subFeatureName in $feature.SubFeatures)
                {
                    $subFeature = Get-WindowsFeature -Name $subFeatureName
                    $subFeature.Installed | Should Be $true
                }
            }
        }

        Context "Should Uninstall the Windows Feature: $script:testFeatureWithSubFeaturesName" {
            $configurationName = 'MSFT_xWindowsFeature_UninstallFeatureWithSubFeatures'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            $logPath = Join-Path -Path $TestDrive -ChildPath 'UninstallSubFeatureTest.log'

            It 'Should compile without throwing' -Skip:$script:skipLongTests {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $script:testFeatureWithSubFeaturesName `
                                            -IncludeAllSubFeature $true `
                                            -Ensure 'Absent' `
                                            -OutputPath $configurationPath `
                                            -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' -Skip:$script:skipLongTests {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
                
            It 'Should return the correct configuration' -Skip:$script:skipLongTests  {
                $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                $currentConfig.Name | Should Be $script:testFeatureWithSubFeaturesName
                $currentConfig.IncludeAllSubFeature | Should Be $false
                $currentConfig.Ensure | Should Be 'Absent'
            }

            It 'Should not be installed (includes check for subFeatures)' -Skip:$script:skipLongTests {
                $feature = Get-WindowsFeature -Name $script:testFeatureWithSubFeaturesName
                $feature.Installed | Should Be $false

                foreach ($subFeatureName in $feature.SubFeatures)
                {
                    $subFeature = Get-WindowsFeature -Name $subFeatureName
                    $subFeature.Installed | Should Be $false
                }
            }
        }

        Context "Should Install the Windows Feature: $script:testFeatureWithMgmtToolsName with management tools" {
            $configurationName = 'MSFT_xWindowsFeature_InstallFeatureWithMgmtTools'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            $logPath = Join-Path -Path $TestDrive -ChildPath 'InstallMgmtToolsTest.log'

            try
            {
                if (-not $script:skipLongTests)
                {
                    # Ensure that the feature is not already installed
                    Remove-WindowsFeature -Name $script:testFeatureWithMgmtToolsName -IncludeManagementTools
                }

                It 'Should compile without throwing' -Skip:$script:skipLongTests {
                    {
                        . $configFile -ConfigurationName $configurationName
                        & $configurationName -Name $script:testFeatureWithMgmtToolsName `
                                             -IncludeAllSubFeature $testIncludeAllSubFeature `
                                             -IncludeManagementTools $true `
                                             -Ensure 'Present' `
                                             -OutputPath $configurationPath `
                                             -ErrorAction 'Stop'
                        Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                    } | Should Not Throw
                }

                It 'Should be able to call Get-DscConfiguration without throwing' -Skip:$script:skipLongTests {
                    { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
                }
                
                It 'Should return the correct configuration' -Skip:$script:skipLongTests {
                   $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                   $currentConfig.Name | Should Be $script:testFeatureWithMgmtToolsName
                   $currentConfig.IncludeManagementTools | Should Be $true
                   $currentConfig.Ensure | Should Be 'Present'
                }

                It 'Should be Installed (includes check for management tools)' -Skip:$script:skipLongTests {
                    $feature = Get-WindowsFeature -Name $script:testFeatureWithMgmtToolsName
                    $feature.Installed | Should Be $true
                    
                    $mgmtTools = Get-WindowsFeatureManagementTool -Name $script:testFeatureWithMgmtToolsName
                    foreach ($mgmtToolName in $mgmtTools)
                    {
                        $mgmtTool = Get-WindowsFeature -Name $mgmtToolName
                        $mgmtTool.Installed | Should Be $true
                    }
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

        Context "Should Uninstall the Windows Feature: $script:testFeatureWithMgmtToolsName" {
            $configurationName = 'MSFT_xWindowsFeature_UninstallFeatureWithMgmtTools'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            $logPath = Join-Path -Path $TestDrive -ChildPath 'UninstallMgmtToolsTest.log'

            try
            {
                It 'Should compile without throwing' -Skip:$script:skipLongTests {
                    {
                        . $configFile -ConfigurationName $configurationName
                        & $configurationName -Name $script:testFeatureWithMgmtToolsName `
                                             -IncludeAllSubFeature $testIncludeAllSubFeature `
                                             -IncludeManagementTools $true `
                                             -Ensure 'Absent' `
                                             -OutputPath $configurationPath `
                                             -ErrorAction 'Stop'
                        Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                    } | Should Not Throw
                }

                It 'Should be able to call Get-DscConfiguration without throwing' -Skip:$script:skipLongTests {
                    { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
                }
                
                It 'Should return the correct configuration' -Skip:$script:skipLongTests  {
                   $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
                   $currentConfig.Name | Should Be $script:testFeatureWithMgmtToolsName
                   $currentConfig.IncludeManagementTools | Should Be $false
                   $currentConfig.Ensure | Should Be 'Absent'
                }

                It 'Should not be installed (includes check for management tools)' -Skip:$script:skipLongTests {
                    $feature = Get-WindowsFeature -Name $script:testFeatureWithMgmtToolsName
                    $feature.Installed | Should Be $false
                    
                    $mgmtTools = Get-WindowsFeatureManagementTool -Name $script:testFeatureWithMgmtToolsName
                    foreach ($mgmtToolName in $mgmtTools)
                    {
                        $mgmtTool = Get-WindowsFeature -Name $mgmtToolName
                        $mgmtTool.Installed | Should Be $false
                    }
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
    # Ensure that features used for testing are re-installed/uninstalled
    if ($script:installStateOfTestFeature)
    {
        Add-WindowsFeature -Name $script:testFeatureName
    }
    else
    {
        Remove-WindowsFeature -Name $script:testFeatureName
    }

    if (-not $script:skipLongTests)
    {
        if ($script:installStateOfTestWithSubFeatures)
        {
            Add-WindowsFeature -Name $script:testFeatureWithSubFeaturesName -IncludeAllSubFeature
        }
        else
        {
            Remove-WindowsFeature -Name $script:testFeatureWithSubFeaturesName
        }

        if ($script:installStateOfTestWithMgmtTools)
        {
            Add-WindowsFeature -Name $script:testFeatureWithMgmtToolsName -IncludeManagementTools
        }
        else
        {
            Remove-WindowsFeature -Name $script:testFeatureWithMgmtToolsName -IncludeManagementTools
        }
    }
    Exit-DscResourceTestEnvironment -TestEnvironment $script:testEnvironment
}
