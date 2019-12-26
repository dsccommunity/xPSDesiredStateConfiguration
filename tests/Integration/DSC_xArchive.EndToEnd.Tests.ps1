$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'DSC_xArchive'

function Invoke-TestSetup
{
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
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\DSC_xArchive.TestHelper.psm1') -Force
}

function Invoke-TestCleanup
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}

Invoke-TestSetup

# Begin Testing
try
{
    InModuleScope $script:dscResourceName {
        # Set up the paths to the test configurations
        $script:confgurationFilePathValidateOnly = Join-Path -Path $PSScriptRoot -ChildPath 'DSC_xArchive_ValidateOnly.config.ps1'
        $script:confgurationFilePathValidateAndChecksum = Join-Path -Path $PSScriptRoot -ChildPath 'DSC_xArchive_ValidateAndChecksum.config.ps1'
        $script:confgurationFilePathCredentialOnly = Join-Path -Path $PSScriptRoot -ChildPath 'DSC_xArchive_CredentialOnly.config.ps1'

        # Create the test archive
        $script:testArchiveName = 'TestArchive1'

        $script:testArchiveFileStructure = @{
            Folder1 = @{ }
            Folder2 = @{
                Folder21 = @{
                    Folder22 = @{
                        Folder23 = @{ }
                    }
                }
            }
            Folder3 = @{
                Folder31 = @{
                    Folder31 = @{
                        Folder33 = @{
                            Folder34 = @{
                                File31 = 'Fake file contents'
                            }
                        }
                    }
                }
            }
            Folder4 = @{
                Folder41 = @{
                    Folder42 = @{
                        Folder43 = @{
                            Folder44 = @{ }
                        }
                    }
                }
            }
            File1   = 'Fake file contents'
            File2   = 'Fake file contents'
        }

        $newZipFileFromHashtableParameters = @{
            Name             = $script:testArchiveName
            ParentPath       = $TestDrive
            ZipFileStructure = $script:testArchiveFileStructure
        }

        $script:testArchiveFilePath = New-ZipFileFromHashtable @newZipFileFromHashtableParameters
        $script:testArchiveFilePathWithoutExtension = $script:testArchiveFilePath.Replace('.zip', '')

        # Create another test archive with the same name and file structure but different file content
        $script:testArchiveWithDifferentFileContentName = $script:testArchiveName

        $script:testArchiveFileWithDifferentFileContentStructure = @{
            Folder1 = @{ }
            Folder2 = @{
                Folder21 = @{
                    Folder22 = @{
                        Folder23 = @{ }
                    }
                }
            }
            Folder3 = @{
                Folder31 = @{
                    Folder31 = @{
                        Folder33 = @{
                            Folder34 = @{
                                File31 = 'Different fake file contents'
                            }
                        }
                    }
                }
            }
            Folder4 = @{
                Folder41 = @{
                    Folder42 = @{
                        Folder43 = @{
                            Folder44 = @{ }
                        }
                    }
                }
            }
            File1   = 'Different fake file contents'
            File2   = 'Different fake file contents'
        }

        $script:testArchiveFileWithDifferentFileContentParentPath = Join-Path -Path $TestDrive -ChildPath 'MismatchingArchive'
        $null = New-Item -Path $script:testArchiveFileWithDifferentFileContentParentPath -ItemType 'Directory'

        $newZipFileFromHashtableParameters = @{
            Name             = $script:testArchiveWithDifferentFileContentName
            ParentPath       = $script:testArchiveFileWithDifferentFileContentParentPath
            ZipFileStructure = $script:testArchiveFileWithDifferentFileContentStructure
        }

        $script:testArchiveFileWithDifferentFileContentPath = New-ZipFileFromHashtable @newZipFileFromHashtableParameters
        $script:testArchiveFileWithDifferentFileContentPathWithoutExtension = $script:testArchiveFileWithDifferentFileContentPath.Replace('.zip', '')

        Describe 'xArchive End to End Tests' {
            Context 'When expanding an archive to a destination that does not yet exist' {
                $configurationName = 'ExpandArchiveToNonExistentDestination'

                $destination = Join-Path -Path $TestDrive -ChildPath 'NonExistentDestinationForExpand'

                It 'Destination should not exist before configuration' {
                    Test-Path -Path $destination | Should -Be $false
                }

                $archiveParameters = @{
                    Path        = $script:testArchiveFilePath
                    Destination = $destination
                    Ensure      = 'Present'
                }

                It 'Should return false from Test-TargetResource with the same parameters before configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $false
                }

                It 'Should compile and apply the MOF without throwing an exception' {
                    {
                        . $script:confgurationFilePathValidateOnly -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @archiveParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction Stop -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Destination should exist after configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure of destination should match the file structure of the archive after configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $true
                }

                It 'Should return true from Test-TargetResource with the same parameters after configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $true
                }
            }

            Context 'When expanding an archive to an existing destination with items that are not in the archive' {
                $configurationName = 'ExpandArchiveToDestinationWithOtherItems'

                $destination = Join-Path -Path $TestDrive -ChildPath 'DestinationWithOtherItemsForExpand'
                $null = New-Item -Path $destination -ItemType 'Directory'

                # Keys are the paths to the items. Values are the items' contents with an empty string denoting a directory
                $otherItems = @{ }

                $otherDirectoryPath = Join-Path -Path $destination -ChildPath 'OtherDirectory'
                $null = New-Item -Path $otherDirectoryPath -ItemType 'Directory'
                $otherItems[$otherDirectoryPath] = ''

                $otherSubDirectoryPath = Join-Path -Path $otherDirectoryPath -ChildPath 'OtherSubDirectory'
                $null = New-Item -Path $otherSubDirectoryPath -ItemType 'Directory'
                $otherItems[$otherSubDirectoryPath] = ''

                $otherFilePath = Join-Path $otherSubDirectoryPath -ChildPath 'OtherFile'
                $otherFileContent = 'Other file content'
                $null = New-Item -Path $otherFilePath -ItemType 'File'
                $null = Set-Content -Path $otherFilePath -Value $otherFileContent
                $otherItems[$otherFilePath] = $otherFileContent

                It 'Destination should exist before configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                foreach ($otherItemPath in $otherItems.Keys)
                {
                    $otherItemName = Split-Path -Path $otherItemPath -Leaf
                    $otherItemExpectedContent = $otherItems[$otherItemPath]
                    $otherItemIsDirectory = [System.String]::IsNullOrEmpty($otherItemExpectedContent)

                    if ($otherItemIsDirectory)
                    {
                        It "Other item under destination $otherItemName should exist as a directory before configuration" {
                            Test-Path -Path $otherItemPath -PathType 'Container' | Should -Be $true
                        }
                    }
                    else
                    {
                        It "Other item under destination $otherItemName should exist as a file before configuration" {
                            Test-Path -Path $otherItemPath -PathType 'Leaf' | Should -Be $true
                        }

                        It "Other file under destination $otherItemName should have the expected content before configuration" {
                            Get-Content -Path $otherItemPath -Raw -ErrorAction 'SilentlyContinue' | Should -Be ($otherItemExpectedContent + "`r`n")
                        }
                    }
                }

                $archiveParameters = @{
                    Path        = $script:testArchiveFilePath
                    Destination = $destination
                    Ensure      = 'Present'
                }

                It 'Should return false from Test-TargetResource with the same parameters before configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $false
                }

                It 'Should compile and apply the MOF without throwing an exception' {
                    {
                        . $script:confgurationFilePathValidateOnly -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @archiveParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction Stop -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Destination should exist after configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure of destination should match the file structure of the archive after configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $true
                }

                foreach ($otherItemPath in $otherItems.Keys)
                {
                    $otherItemName = Split-Path -Path $otherItemPath -Leaf
                    $otherItemExpectedContent = $otherItems[$otherItemPath]
                    $otherItemIsDirectory = [System.String]::IsNullOrEmpty($otherItemExpectedContent)

                    if ($otherItemIsDirectory)
                    {
                        It "Other item under destination $otherItemName should exist as a directory after configuration" {
                            Test-Path -Path $otherItemPath -PathType 'Container' | Should -Be $true
                        }
                    }
                    else
                    {
                        It "Other item under destination $otherItemName should exist as a file after configuration" {
                            Test-Path -Path $otherItemPath -PathType 'Leaf' | Should -Be $true
                        }

                        It "Other file under destination $otherItemName should have the expected after before configuration" {
                            Get-Content -Path $otherItemPath -Raw -ErrorAction 'SilentlyContinue' | Should -Be ($otherItemExpectedContent + "`r`n")
                        }
                    }
                }

                It 'Should return true from Test-TargetResource with the same parameters after configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $true
                }
            }

            Context 'When expanding an archive to an existing destination that already contains the same archive files' {
                $configurationName = 'ExpandArchiveToDestinationWithArchive'

                $destination = Join-Path -Path $TestDrive -ChildPath 'DestinationWithMatchingArchiveForExpand'
                $null = New-Item -Path $destination -ItemType 'Directory'

                $null = Expand-Archive -Path $script:testArchiveFilePath -DestinationPath $destination -Force

                It 'Destination should exist before configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure of destination should match the file structure of the archive before configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $true
                }

                $archiveParameters = @{
                    Path        = $script:testArchiveFilePath
                    Destination = $destination
                    Ensure      = 'Present'
                }

                It 'Should return true from Test-TargetResource with the same parameters before configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $true
                }

                It 'Should compile and apply the MOF without throwing an exception' {
                    {
                        . $script:confgurationFilePathValidateOnly -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @archiveParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction Stop -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Destination should exist after configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure of destination should match the file structure of the archive after configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $true
                }

                It 'Should return true from Test-TargetResource with the same parameters after configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $true
                }
            }

            Context 'When expanding an archive to a destination that contains archive files that do not match by the specified SHA Checksum without Force specified' {
                $configurationName = 'ExpandArchiveToDestinationWithMismatchingArchive'

                $destination = Join-Path -Path $TestDrive -ChildPath 'DestinationWithMismatchingArchiveWithSHANoForceForExpand'
                $null = New-Item -Path $destination -ItemType 'Directory'

                $null = Expand-Archive -Path $script:testArchiveFileWithDifferentFileContentPath -DestinationPath $destination -Force

                It 'Destination should exist before configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure of destination should match the file structure of the archive before configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $true
                }

                It 'File contents of destination should not match the file contents of the archive' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination -CheckContents | Should -Be $false
                }

                $archiveParameters = @{
                    Path        = $script:testArchiveFilePath
                    Destination = $destination
                    Ensure      = 'Present'
                    Validate    = $true
                    Checksum    = 'SHA-256'
                    Force       = $false
                }

                It 'Should return false from Test-TargetResource with the same parameters before configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $false
                }

                It 'Should compile and run configuration and throw an error for attempting to overwrite files without Force specified' {
                    # We don't know which file will throw the error, so we will only check that an error was thrown rather than checking the specific error message
                    {
                        . $script:confgurationFilePathValidateAndChecksum -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @archiveParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction Stop -Wait -Force
                    } | Should -Throw
                }

                It 'Destination should exist after configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure of destination should match the file structure of the archive after configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $true
                }

                It 'File contents of destination should not match the file contents of the archive after configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination -CheckContents | Should -Be $false
                }

                It 'Should return false from Test-TargetResource with the same parameters after configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $false
                }
            }

            Context 'When expanding an archive to a destination that contains archive files that do not match by the specified SHA Checksum with Force specified' {
                $configurationName = 'ExpandArchiveToDestinationWithMismatchingArchive'

                $destination = Join-Path -Path $TestDrive -ChildPath 'DestinationWithMismatchingArchiveWithSHAAndForceForExpand'
                $null = New-Item -Path $destination -ItemType 'Directory'

                $null = Expand-Archive -Path $script:testArchiveFileWithDifferentFileContentPath -DestinationPath $destination -Force

                It 'Destination should exist before configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure of destination should match the file structure of the archive before configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $true
                }

                It 'File contents of destination should not match the file contents of the archive before configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination -CheckContents | Should -Be $false
                }

                $archiveParameters = @{
                    Path        = $script:testArchiveFilePath
                    Destination = $destination
                    Ensure      = 'Present'
                    Validate    = $true
                    Checksum    = 'SHA-256'
                    Force       = $true
                }

                It 'Should return false from Test-TargetResource with the same parameters before configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $false
                }

                It 'Should compile and apply the MOF without throwing an exception' {
                    {
                        . $script:confgurationFilePathValidateAndChecksum -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @archiveParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction Stop -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Destination should exist after configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure of destination should match the file structure of the archive after configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $true
                }

                It 'File contents of destination should match the file contents of the archive after configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination -CheckContents | Should -Be $true
                }

                It 'Should return true from Test-TargetResource with the same parameters after configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $true
                }
            }

            Context 'When expanding an archive to a destination that contains archive files that match by the specified SHA Checksum' {
                $configurationName = 'ExpandArchiveToDestinationWithMatchingArchive'

                $destination = Join-Path -Path $TestDrive -ChildPath 'DestinationWithMatchingArchiveWithSHAForExpand'
                $null = New-Item -Path $destination -ItemType 'Directory'

                $null = Expand-Archive -Path $script:testArchiveFilePath -DestinationPath $destination -Force

                It 'Destination should exist before configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure of destination should match the file structure of the archive before configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $true
                }

                It 'File contents of destination should match the file contents of the archive before configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination -CheckContents | Should -Be $true
                }

                $archiveParameters = @{
                    Path        = $script:testArchiveFilePath
                    Destination = $destination
                    Ensure      = 'Present'
                    Validate    = $true
                    Checksum    = 'SHA-256'
                    Force       = $true
                }

                It 'Should return true from Test-TargetResource with the same parameters before configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $true
                }

                It 'Should compile and apply the MOF without throwing an exception' {
                    {
                        . $script:confgurationFilePathValidateAndChecksum -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @archiveParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction Stop -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Destination should exist after configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure of destination should match the file structure of the archive after configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $true
                }

                It 'File contents of destination should match the file contents of the archive after configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination -CheckContents | Should -Be $true
                }

                It 'Should return true from Test-TargetResource with the same parameters after configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $true
                }
            }

            Context 'When removing an expanded archive from an existing destination that contains only the expanded archive' {
                $configurationName = 'RemoveArchiveAtDestinationWithArchive'

                $destination = Join-Path -Path $TestDrive -ChildPath 'DestinationWithMatchingArchiveForRemove'
                $null = New-Item -Path $destination -ItemType 'Directory'

                $null = Expand-Archive -Path $script:testArchiveFilePath -DestinationPath $destination -Force

                It 'Destination should exist before configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure of destination should match the file structure of the archive before configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $true
                }

                $archiveParameters = @{
                    Path        = $script:testArchiveFilePath
                    Destination = $destination
                    Ensure      = 'Absent'
                }

                It 'Should return false from Test-TargetResource with the same parameters before configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $false
                }

                It 'Should compile and apply the MOF without throwing an exception' {
                    {
                        . $script:confgurationFilePathValidateOnly -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @archiveParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction Stop -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Destination should exist after configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure of destination should not match the file structure of the archive after configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $false
                }

                It 'Should return true from Test-TargetResource with the same parameters after configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $true
                }
            }

            Context 'When removing an expanded archive from an existing destination that contains the expanded archive and other files' {
                $configurationName = 'RemoveArchiveAtDestinationWithArchiveAndOtherFiles'

                $destination = Join-Path -Path $TestDrive -ChildPath 'DestinationWithMatchingArchiveAndOtherFilesForRemove'
                $null = New-Item -Path $destination -ItemType 'Directory'

                $null = Expand-Archive -Path $script:testArchiveFilePath -DestinationPath $destination -Force

                # Keys are the paths to the items. Values are the items' contents with an empty string denoting a directory
                $otherItems = @{ }

                $otherDirectoryPath = Join-Path -Path $destination -ChildPath 'OtherDirectory'
                $null = New-Item -Path $otherDirectoryPath -ItemType 'Directory'
                $otherItems[$otherDirectoryPath] = ''

                $otherSubDirectoryPath = Join-Path -Path $otherDirectoryPath -ChildPath 'OtherSubDirectory'
                $null = New-Item -Path $otherSubDirectoryPath -ItemType 'Directory'
                $otherItems[$otherSubDirectoryPath] = ''

                $otherFilePath = Join-Path $otherSubDirectoryPath -ChildPath 'OtherFile'
                $otherFileContent = 'Other file content'
                $null = New-Item -Path $otherFilePath -ItemType 'File'
                $null = Set-Content -Path $otherFilePath -Value $otherFileContent
                $otherItems[$otherFilePath] = $otherFileContent

                It 'Destination should exist before configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                foreach ($otherItemPath in $otherItems.Keys)
                {
                    $otherItemName = Split-Path -Path $otherItemPath -Leaf
                    $otherItemExpectedContent = $otherItems[$otherItemPath]
                    $otherItemIsDirectory = [System.String]::IsNullOrEmpty($otherItemExpectedContent)

                    if ($otherItemIsDirectory)
                    {
                        It "Other item under destination $otherItemName should exist as a directory before configuration" {
                            Test-Path -Path $otherItemPath -PathType 'Container' | Should -Be $true
                        }
                    }
                    else
                    {
                        It "Other item under destination $otherItemName should exist as a file before configuration" {
                            Test-Path -Path $otherItemPath -PathType 'Leaf' | Should -Be $true
                        }

                        It "Other file under destination $otherItemName should have the expected content before configuration" {
                            Get-Content -Path $otherItemPath -Raw -ErrorAction 'SilentlyContinue' | Should -Be ($otherItemExpectedContent + "`r`n")
                        }
                    }
                }

                It 'File structure of destination should match the file structure of the archive before configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $true
                }

                $archiveParameters = @{
                    Path        = $script:testArchiveFilePath
                    Destination = $destination
                    Ensure      = 'Absent'
                }

                It 'Should return false from Test-TargetResource with the same parameters before configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $false
                }

                It 'Should compile and apply the MOF without throwing an exception' {
                    {
                        . $script:confgurationFilePathValidateOnly -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @archiveParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction Stop -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Destination should exist after configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                foreach ($otherItemPath in $otherItems.Keys)
                {
                    $otherItemName = Split-Path -Path $otherItemPath -Leaf
                    $otherItemExpectedContent = $otherItems[$otherItemPath]
                    $otherItemIsDirectory = [System.String]::IsNullOrEmpty($otherItemExpectedContent)

                    if ($otherItemIsDirectory)
                    {
                        It "Other item under destination $otherItemName should exist as a directory before configuration" {
                            Test-Path -Path $otherItemPath -PathType 'Container' | Should -Be $true
                        }
                    }
                    else
                    {
                        It "Other item under destination $otherItemName should exist as a file before configuration" {
                            Test-Path -Path $otherItemPath -PathType 'Leaf' | Should -Be $true
                        }

                        It "Other file under destination $otherItemName should have the expected content before configuration" {
                            Get-Content -Path $otherItemPath -Raw -ErrorAction 'SilentlyContinue' | Should -Be ($otherItemExpectedContent + "`r`n")
                        }
                    }
                }

                It 'File structure of destination should not match the file structure of the archive after configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $false
                }

                It 'Should return true from Test-TargetResource with the same parameters after configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $true
                }
            }

            Context 'When removing an expanded archive from an existing destination that does not contain any archive files' {
                $configurationName = 'RemoveArchiveAtDestinationWithoutArchive'

                $destination = Join-Path -Path $TestDrive -ChildPath 'EmptyDestinationForRemove'
                $null = New-Item -Path $destination -ItemType 'Directory'

                It 'Destination should exist before configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure of destination should not match the file structure of the archive before configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $false
                }

                $archiveParameters = @{
                    Path        = $script:testArchiveFilePath
                    Destination = $destination
                    Ensure      = 'Absent'
                }

                It 'Should return true from Test-TargetResource with the same parameters before configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $true
                }

                It 'Should compile and apply the MOF without throwing an exception' {
                    {
                        . $script:confgurationFilePathValidateOnly -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @archiveParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction Stop -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Destination should exist after configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure of destination should not match the file structure of the archive after configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $false
                }

                It 'Should return true from Test-TargetResource with the same parameters after configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $true
                }
            }

            Context 'When removing an expanded archive from a destination that does not exist' {
                $configurationName = 'RemoveArchiveFromMissingDestination'

                $destination = Join-Path -Path $TestDrive -ChildPath 'NonexistentDestinationForRemove'

                It 'Destination should not exist before configuration' {
                    Test-Path -Path $destination | Should -Be $false
                }

                $archiveParameters = @{
                    Path        = $script:testArchiveFilePath
                    Destination = $destination
                    Ensure      = 'Absent'
                }

                It 'Should return true from Test-TargetResource with the same parameters before configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $true
                }

                It 'Should compile and apply the MOF without throwing an exception' {
                    {
                        . $script:confgurationFilePathValidateOnly -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @archiveParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction Stop -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Destination should not exist after configuration' {
                    Test-Path -Path $destination | Should -Be $false
                }

                It 'Should return true from Test-TargetResource with the same parameters after configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $true
                }
            }

            Context 'When removing an archive from a destination that contains archive files that do not match by the specified SHA Checksum' {
                $configurationName = 'RemoveArchiveFromDestinationWithMismatchingArchiveWithSHA'

                $destination = Join-Path -Path $TestDrive -ChildPath 'DestinationWithMismatchingArchiveWithSHAForRemove'
                $null = New-Item -Path $destination -ItemType 'Directory'

                $null = Expand-Archive -Path $script:testArchiveFileWithDifferentFileContentPath -DestinationPath $destination -Force

                It 'Destination should exist before configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure of destination should match the file structure of the archive before configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $true
                }

                It 'File contents of destination should not match the file contents of the archive before configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination -CheckContents | Should -Be $false
                }

                $archiveParameters = @{
                    Path        = $script:testArchiveFilePath
                    Destination = $destination
                    Ensure      = 'Absent'
                    Validate    = $true
                    Checksum    = 'SHA-256'
                    Force       = $true
                }

                It 'Should return true from Test-TargetResource with the same parameters before configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $true
                }

                It 'Should compile and apply the MOF without throwing an exception' {
                    {
                        . $script:confgurationFilePathValidateAndChecksum -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @archiveParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction Stop -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Destination should exist after configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure of destination should match the file structure of the archive after configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $true
                }

                It 'File contents of destination should not match the file contents of the archive after configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination -CheckContents | Should -Be $false
                }

                It 'Should return true from Test-TargetResource with the same parameters after configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $true
                }
            }

            Context 'When removing an archive from a destination that contains archive files that match by the specified SHA Checksum' {
                $configurationName = 'RemoveArchiveFromDestinationWithMatchingArchiveWithSHA'

                $destination = Join-Path -Path $TestDrive -ChildPath 'DestinationWithMatchingArchiveWithSHAForRemove'
                $null = New-Item -Path $destination -ItemType 'Directory'

                $null = Expand-Archive -Path $script:testArchiveFilePath -DestinationPath $destination -Force

                It 'Destination should exist before configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure and contents of destination should match the file contents of the archive before configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination -CheckContents | Should -Be $true
                }

                $archiveParameters = @{
                    Path        = $script:testArchiveFilePath
                    Destination = $destination
                    Ensure      = 'Absent'
                    Validate    = $true
                    Checksum    = 'SHA-256'
                    Force       = $true
                }

                It 'Should return false from Test-TargetResource with the same parameters before configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $false
                }

                It 'Should compile and apply the MOF without throwing an exception' {
                    {
                        . $script:confgurationFilePathValidateAndChecksum -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @archiveParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction Stop -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Destination should exist after configuration' {
                    Test-Path -Path $destination | Should -Be $true
                }

                It 'File structure of destination should not match the file structure of the archive after configuration' {
                    Test-FileStructuresMatch -SourcePath $script:testArchiveFilePathWithoutExtension -DestinationPath $destination | Should -Be $false
                }

                It 'Should return false from Test-TargetResource with the same parameters after configuration' {
                    DSC_xArchive\Test-TargetResource @archiveParameters | Should -Be $true
                }
            }
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}

