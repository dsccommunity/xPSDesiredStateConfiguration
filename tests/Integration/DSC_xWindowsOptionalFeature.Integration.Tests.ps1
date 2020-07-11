$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'DSC_xWindowsOptionalFeature'

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
    Describe 'xWindowsOptionalFeature Integration Tests' {
        BeforeAll {
            $script:enabledStates = @( 'Enabled', 'EnablePending' )
            $script:disabledStates = @( 'Disabled', 'DisablePending' )

            $script:confgurationFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'DSC_xWindowsOptionalFeature.config.ps1'
        }

        It 'Should enable a valid Windows optional feature' {
            $configurationName = 'EnableWindowsOptionalFeature'

            $resourceParameters = @{
                Name                 = 'TelnetClient'
                Ensure               = 'Present'
                LogPath              = Join-Path -Path $TestDrive -ChildPath 'EnableOptionalFeature.log'
                NoWindowsUpdateCheck = $true
            }

            $originalFeature = Dism\Get-WindowsOptionalFeature -FeatureName $resourceParameters.Name -Online

            try
            {
                if ($originalFeature.State -in $script:enabledStates)
                {
                    Dism\Disable-WindowsOptionalFeature -FeatureName $resourceParameters.Name -Online -NoRestart
                }

                {
                    . $script:confgurationFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @resourceParameters
                    Reset-DscLcm
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw

                $windowsOptionalFeature = Dism\Get-WindowsOptionalFeature -FeatureName $resourceParameters.Name -Online

                $windowsOptionalFeature | Should -Not -Be $null
                $windowsOptionalFeature.State -in $script:enabledStates | Should -BeTrue
            }
            finally
            {
                if ($originalFeature.State -in $script:disabledStates)
                {
                    Dism\Disable-WindowsOptionalFeature -FeatureName $resourceParameters.Name -Online -NoRestart
                }
                elseif ($originalFeature.State -in $script:enabledStates)
                {
                    Dism\Enable-WindowsOptionalFeature -FeatureName $resourceParameters.Name -Online -NoRestart
                }

                if (Test-Path -Path $resourceParameters.LogPath)
                {
                    Remove-Item -Path $resourceParameters.LogPath -Recurse -Force
                }
            }
        }

        It 'Should disable a valid Windows optional feature' {
            $configurationName = 'DisableWindowsOptionalFeature'

            $resourceParameters = @{
                Name                 = 'TelnetClient'
                Ensure               = 'Absent'
                LogPath              = Join-Path -Path $TestDrive -ChildPath 'DisableOptionalFeature.log'
                NoWindowsUpdateCheck = $true
                RemoveFilesOnDisable = $false
            }

            $originalFeature = Dism\Get-WindowsOptionalFeature -FeatureName $resourceParameters.Name -Online

            try
            {
                if ($originalFeature.State -in $script:disabledStates)
                {
                    Dism\Enable-WindowsOptionalFeature -FeatureName $resourceParameters.Name -Online -NoRestart
                }

                {
                    . $script:confgurationFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @resourceParameters
                    Reset-DscLcm
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw

                $windowsOptionalFeature = Dism\Get-WindowsOptionalFeature -FeatureName $resourceParameters.Name -Online

                $windowsOptionalFeature | Should -Not -Be $null
                $windowsOptionalFeature.State -in $script:disabledStates | Should -BeTrue
            }
            finally
            {
                if ($originalFeature.State -in $script:disabledStates)
                {
                    Dism\Disable-WindowsOptionalFeature -FeatureName $resourceParameters.Name -Online -NoRestart
                }
                elseif ($originalFeature.State -in $script:enabledStates)
                {
                    Dism\Enable-WindowsOptionalFeature -FeatureName $resourceParameters.Name -Online -NoRestart
                }

                if (Test-Path -Path $resourceParameters.LogPath)
                {
                    Remove-Item -Path $resourceParameters.LogPath -Recurse -Force
                }
            }
        }

        It 'Should not enable an incorrect Windows optional feature' {
            $configurationName = 'EnableIncorrectWindowsOptionalFeature'

            $resourceParameters = @{
                Name                 = 'NonExistentWindowsOptionalFeature'
                Ensure               = 'Present'
                LogPath              = Join-Path -Path $TestDrive -ChildPath 'EnableIncorrectWindowsFeature.log'
                NoWindowsUpdateCheck = $true
            }

            Dism\Get-WindowsOptionalFeature -FeatureName $resourceParameters.Name -Online | Should -Be $null

            try
            {
                {
                    . $script:confgurationFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @resourceParameters
                    Reset-DscLcm
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Throw "Feature name $($resourceParameters.Name) is unknown."

                Test-Path -Path $resourceParameters.LogPath | Should -BeTrue

                Dism\Get-WindowsOptionalFeature -FeatureName $resourceParameters.Name -Online | Should -Be $null
            }
            finally
            {
                if (Test-Path -Path $resourceParameters.LogPath)
                {
                    Remove-Item -Path $resourceParameters.LogPath -Recurse -Force
                }
            }
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
