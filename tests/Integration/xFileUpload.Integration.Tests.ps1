$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'xFileUpload'

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
    Describe 'xFileUpload Integration Tests' {
        BeforeAll {
            $script:configurationName = 'xFileUpload_Config'
            $script:configurationFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'xFileUpload.config.ps1'

            # File content to use for testing
            $script:testFileContent = 'Test Content'

            # Create a folder to be used as the destination SMB Share
            $script:smbShareName = 'xFileUploadSMBShare'
            $script:smbSharePath = Join-Path -Path $TestDrive -ChildPath 'xFileUploadFolder'
            $null = New-Item -Path $script:smbSharePath -ItemType Directory -ErrorAction SilentlyContinue
            $null = New-SmbShare -Name $script:smbShareName -Path $script:smbSharePath -FullAccess 'Everyone' -Temporary
            $script:destinationPath = "\\localhost\$script:smbShareName\"

            # Create a file to be used as the source
            $script:sourceFileName = 'testfile.txt'
            $script:sourcePathFile = Join-Path -Path $TestDrive -ChildPath $script:sourceFileName
            $null = Set-Content -Path $script:sourcePathFile -Value $script:testFileContent -Force

            # Create a folder and file to be used as the source
            $script:sourceFolderName = 'testfolder'
            $script:sourcePathFolder = Join-Path -Path $TestDrive -ChildPath $script:sourceFolderName
            $null = New-Item -Path $script:sourcePathFolder -ItemType Directory -ErrorAction SilentlyContinue
            $script:sourcePathFolderFile = Join-Path -Path $script:sourcePathFolder -ChildPath $script:sourceFileName
            $null = Set-Content -Path $script:sourcePathFolderFile -Value $script:testFileContent -Force
        }

        AfterAll {
            $null = Remove-SmbShare -Name $script:smbShareName -Force
        }

        Context 'When uploading a single file to an SMB file share' {
            It 'Should compile and run configuration' {
                {
                    $ConfigurationData = @{
                        AllNodes = @(
                            @{
                                NodeName        = 'localhost'
                                CertificateFile = $env:DscPublicCertificatePath
                                DestinationPath = $script:destinationPath
                                SourcePath      = $script:sourcePathFile
                            }
                        )
                    }

                    . $script:configurationFilePath -ConfigurationName $script:configurationName
                    & $script:configurationName `
                        -OutputPath $TestDrive `
                        -ConfigurationData $ConfigurationData
                    Reset-DscLcm
                    Start-DscConfiguration `
                        -Path $TestDrive `
                        -ErrorAction 'Stop' `
                        -Wait `
                        -Force `
                } | Should -Not -Throw
            }

            It 'Should have copied the file to the destination' {
                $uploadedFilePath = Join-Path -Path $script:smbSharePath -ChildPath $script:sourceFileName
                Test-Path -Path $uploadedFilePath | Should -BeTrue
                Get-Content -Path $uploadedFilePath | Should -Be $script:testFileContent
            }
        }

        Context 'When uploading a folder to an SMB file share' {
            It 'Should compile and run configuration' {
                {
                    $ConfigurationData = @{
                        AllNodes = @(
                            @{
                                NodeName        = 'localhost'
                                CertificateFile = $env:DscPublicCertificatePath
                                DestinationPath = $script:destinationPath
                                SourcePath      = $script:sourcePathFolder
                            }
                        )
                    }

                    . $script:configurationFilePath -ConfigurationName $script:configurationName
                    & $script:configurationName `
                        -OutputPath $TestDrive `
                        -ConfigurationData $ConfigurationData
                    Reset-DscLcm
                    Start-DscConfiguration `
                        -Path $TestDrive `
                        -ErrorAction 'Stop' `
                        -Wait `
                        -Force `
                } | Should -Not -Throw
            }

            It 'Should have copied the folder to the destination' {
                $uploadedFolderPath = Join-Path -Path $script:smbSharePath -ChildPath $script:sourceFolderName
                $uploadedFilePath = Join-Path -Path $uploadedFolderPath -ChildPath $script:sourceFileName
                Test-Path -Path $uploadedFolderPath | Should -BeTrue
                Test-Path -Path $uploadedFilePath | Should -BeTrue
                Get-Content -Path $uploadedFilePath | Should -Be $script:testFileContent
            }
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
