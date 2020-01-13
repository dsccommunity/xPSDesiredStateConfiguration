$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'xWindowsFeatureSet'

try
{
    Import-Module -Name DscResource.Test -Force -ErrorAction 'Stop'
}
catch [System.IO.FileNotFoundException]
{
    throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -Tasks build" first.'
}

$script:testEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:dscModuleName `
    -DSCResourceName $script:dscResourceName `
    -ResourceType 'Mof' `
    -TestType 'Integration'

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\CommonTestHelper.psm1')

# Begin Testing
try
{
    Describe 'xWindowsFeatureSet Integration Tests' {
        BeforeAll {
            $script:validFeatureNames = @( 'Telnet-Client', 'RSAT-File-Services' )

            $script:originalFeatures = @{}

            foreach ($validFeatureName in $script:validFeatureNames)
            {
                $script:originalFeatures[$validFeatureName] = Get-WindowsFeature -Name $validFeatureName
            }

            $script:configurationFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'xWindowsFeatureSet.config.ps1'
        }

        AfterAll {
            foreach ($validFeatureaName in $script:originalFeatures.Keys)
            {
                $feature = Get-WindowsFeature -Name $validFeatureaName

                if ($script:originalFeatures[$validFeatureaName].Installed -and -not $feature.Installed)
                {
                    Add-WindowsFeature -Name $validFeatureaName
                }
                elseif (-not $script:originalFeatures[$validFeatureaName].Installed -and $feature.Installed)
                {
                    Remove-WindowsFeature -Name $validFeatureaName
                }
            }
        }

        Context 'Install two Windows Features' {
            $configurationName = 'InstallTwoFeatures'

            $windowsFeatureSetParameters = @{
                WindowsFeatureNames = $script:validFeatureNames
                Ensure = 'Present'
                LogPath = Join-Path -Path $TestDrive -ChildPath 'InstallFeatureSetTest.log'
            }

            foreach ($windowsFeatureName in $windowsFeatureSetParameters.WindowsFeatureNames)
            {
                $windowsFeature = Get-WindowsFeature -Name $windowsFeatureName

                It "Should be able to retrieve Windows feature $windowsFeatureName before the configuration" {
                    $windowsFeature | Should -Not -Be $null
                }

                if ($windowsFeature.Installed)
                {
                    $null = Remove-WindowsFeature -Name $windowsFeatureName
                    $windowsFeature = Get-WindowsFeature -Name $windowsFeatureName

                    # May need to wait a moment for the correct state to populate
                    $millisecondsElapsed = 0
                    $startTime = Get-Date
                    while ($windowsFeature.Installed -and $millisecondsElapsed -lt 3000)
                    {
                        $windowsFeature = Get-WindowsFeature -Name $windowsFeatureName
                        $millisecondsElapsed = ((Get-Date) - $startTime).TotalMilliseconds
                    }
                }

                It "Should have uninstalled Windows feature $windowsFeatureName before the configuration" {
                    $windowsFeature.Installed | Should -BeFalse
                }
            }

            It 'Should compile and run configuration' {
                {
                    . $script:configurationFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @windowsFeatureSetParameters
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw
            }

            foreach ($windowsFeatureName in $windowsFeatureSetParameters.WindowsFeatureNames)
            {
                $windowsFeature = Get-WindowsFeature -Name $windowsFeatureName

                It "Should be able to retrieve Windows feature $windowsFeatureName after the configuration" {
                    $windowsFeature | Should -Not -Be $null
                }

                if (-not $windowsFeature.Installed)
                {
                    # May need to wait a moment for the correct state to populate
                    $millisecondsElapsed = 0
                    $startTime = Get-Date
                    while (-not $windowsFeature.Installed -and $millisecondsElapsed -lt 3000)
                    {
                        $windowsFeature = Get-WindowsFeature -Name $windowsFeatureName
                        $millisecondsElapsed = ((Get-Date) - $startTime).TotalMilliseconds
                    }
                }

                It "Should have installed Windows feature $windowsFeatureName after the configuration" {
                    $windowsFeature.Installed | Should -BeTrue
                }
            }

            It 'Should have created the log file' {
                Test-Path -Path $windowsFeatureSetParameters.LogPath | Should -BeTrue
            }

            It 'Should have created content in the log file' {
                Get-Content -Path $windowsFeatureSetParameters.LogPath -Raw | Should -Not -Be $null
            }
        }

        Context 'Uninstall two Windows features' {
            $configurationName = 'UninstallTwoFeatures'

            $windowsFeatureSetParameters = @{
                WindowsFeatureNames = $script:validFeatureNames
                Ensure = 'Absent'
                LogPath = Join-Path -Path $TestDrive -ChildPath 'UninstallFeatureSetTest.log'
            }

            foreach ($windowsFeatureName in $windowsFeatureSetParameters.WindowsFeatureNames)
            {
                $windowsFeature = Get-WindowsFeature -Name $windowsFeatureName

                It "Should be able to retrieve Windows feature $windowsFeatureName before the configuration" {
                    $windowsFeature | Should -Not -Be $null
                }

                if (-not $windowsFeature.Installed)
                {
                    $null = Add-WindowsFeature -Name $windowsFeatureName
                    $windowsFeature = Get-WindowsFeature -Name $windowsFeatureName

                    # May need to wait a moment for the correct state to populate
                    $millisecondsElapsed = 0
                    $startTime = Get-Date
                    while (-not $windowsFeature.Installed -and $millisecondsElapsed -lt 3000)
                    {
                        $windowsFeature = Get-WindowsFeature -Name $windowsFeatureName
                        $millisecondsElapsed = ((Get-Date) - $startTime).TotalMilliseconds
                    }
                }

                It "Should have installed Windows feature $windowsFeatureName before the configuration" {
                    $windowsFeature.Installed | Should -BeTrue
                }
            }

            It 'Should compile and run configuration' {
                {
                    . $script:configurationFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @windowsFeatureSetParameters
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw
            }

            foreach ($windowsFeatureName in $windowsFeatureSetParameters.WindowsFeatureNames)
            {
                $windowsFeature = Get-WindowsFeature -Name $windowsFeatureName

                It "Should be able to retrieve Windows feature $windowsFeatureName after the configuration" {
                    $windowsFeature | Should -Not -Be $null
                }

                if ($windowsFeature.Installed)
                {
                    # May need to wait a moment for the correct state to populate
                    $millisecondsElapsed = 0
                    $startTime = Get-Date
                    while ($windowsFeature.Installed -and $millisecondsElapsed -lt 3000)
                    {
                        $windowsFeature = Get-WindowsFeature -Name $windowsFeatureName
                        $millisecondsElapsed = ((Get-Date) - $startTime).TotalMilliseconds
                    }
                }

                It "Should have uninstalled Windows feature $windowsFeatureName after the configuration" {
                    $windowsFeature.Installed | Should -BeFalse
                }
            }

            It 'Should have created the log file' {
                Test-Path -Path $windowsFeatureSetParameters.LogPath | Should -BeTrue
            }

            It 'Should have created content in the log file' {
                Get-Content -Path $windowsFeatureSetParameters.LogPath -Raw | Should -Not -Be $null
            }
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
