$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'DSC_xScriptResource'

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
    Describe 'xScriptResource Integration Tests' {
        BeforeAll {
            # Get test administrator account credentials
            $script:testCredential = Get-TestAdministratorAccountCredential

            $script:configurationNoCredentialFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'DSC_xScriptResource_NoCredential.config.ps1'
            $script:configurationWithCredentialFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'DSC_xScriptResource_WithCredential.config.ps1'

            # Cannot use $TestDrive here because script is run outside of Pester
            $script:testFolderPath = Join-Path -Path $env:SystemDrive -ChildPath 'Test Folder'
            $script:testFilePath = Join-Path -Path $script:testFolderPath -ChildPath 'TestFile.txt'

            # Create the test folder if it doesn't exist
            if (-not (Test-Path -Path $script:testFolderPath))
            {
                New-Item -Path $script:testFolderPath -ItemType Directory
            }

            # Make sure test admin account has permissions on the test folder
            Add-PathPermission `
                -Path $script:testFolderPath `
                -IdentityReference $script:testCredential.UserName

            # Remove the test file if it exists
            if (Test-Path -Path $script:testFilePath)
            {
                Remove-Item -Path $script:testFilePath -Force
            }
        }

        AfterAll {
            if (Test-Path -Path $script:testFilePath)
            {
                Remove-Item -Path $script:testFilePath -Force
            }
        }

        Context 'Get, set, and test scripts specified and Credential not specified' {
            if (Test-Path -Path $script:testFilePath)
            {
                Remove-Item -Path $script:testFilePath -Force
            }

            $configurationName = 'TestScriptNoCredential'

            # Cannot use $TestDrive here because script is run outside of Pester
            $resourceParameters = @{
                FilePath = $script:testFilePath
                FileContent = 'Test file content'
            }

            It 'Should have removed test file before config runs' {
                Test-Path -Path $resourceParameters.FilePath | Should -BeFalse
            }

            It 'Should compile and apply the MOF without throwing' {
                {
                    . $script:configurationNoCredentialFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @resourceParameters
                    Reset-DscLcm
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw
            }

            It 'Should have created the test file' {
                Test-Path -Path $resourceParameters.FilePath | Should -BeTrue
            }

            It 'Should have set file content correctly' {
                Get-Content -Path $resourceParameters.FilePath -Raw | Should -Be "$($resourceParameters.FileContent)`r`n"
            }
        }

        Context 'Get, set, and test scripts specified and Credential specified' {
            if (Test-Path -Path $script:testFilePath)
            {
                Remove-Item -Path $script:testFilePath -Force
            }

            $configurationName = 'TestScriptWithCredential'

            # Cannot use $TestDrive here because script is run outside of Pester
            $resourceParameters = @{
                FilePath = $script:testFilePath
                FileContent = 'Test file content'
                Credential = $script:testCredential
            }

            It 'Should have removed test file before config runs' {
                Test-Path -Path $resourceParameters.FilePath | Should -BeFalse
            }

            $configData = @{
                AllNodes = @(
                    @{
                        NodeName = 'localhost'
                        PSDscAllowPlainTextPassword = $true
                        PSDscAllowDomainUser = $true
                    }
                )
            }

            It 'Should compile and apply the MOF without throwing' {
                {
                    . $script:configurationWithCredentialFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive -ConfigurationData $configData @resourceParameters
                    Reset-DscLcm
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw
            }

            It 'Should have created the test file' {
                Test-Path -Path $resourceParameters.FilePath | Should -BeTrue
            }

            It 'Should have set file content correctly' {
                Get-Content -Path $resourceParameters.FilePath -Raw | Should -Be "$($resourceParameters.FileContent)`r`n"
            }
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
