$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

Describe 'xArchive Integration Tests' {
    BeforeAll {
        # Import CommonTestHelper for Enter-DscResourceTestEnvironment, Exit-DscResourceTestEnvironment
        $testsFolderFilePath = Split-Path $PSScriptRoot -Parent
        $commonTestHelperFilePath = Join-Path -Path $testsFolderFilePath -ChildPath 'CommonTestHelper.psm1'
        Import-Module -Name $commonTestHelperFilePath

        $script:testEnvironment = Enter-DscResourceTestEnvironment `
            -DscResourceModuleName 'xPSDesiredStateConfiguration' `
            -DscResourceName 'MSFT_xArchive' `
            -TestType 'Unit'

        # Import archive test helper for New-ZipFileFromHashtable, Test-FileStructuresMatch
        $archiveTestHelperFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'MSFT_xArchive.TestHelper.psm1'
        Import-Module -Name $archiveTestHelperFilePath -Force
    }

    AfterAll {
        Exit-DscResourceTestEnvironment -TestEnvironment $script:testEnvironment
    }

    Context 'Expand a basic archive' {
        $zipFileName = 'SetFunctionality'
        $subfolderName = 'Folder1'

        $zipFileStructure = @{
            $subfolderName = @{
                File1 = 'Fake file contents'
            }
        }

        $zipFilePath = New-ZipFileFromHashtable -Name $zipFileName -ParentPath $TestDrive -ZipFileStructure $zipFileStructure

        $destinationDirectoryName = 'ExpandBasicArchive'
        $destinationDirectoryPath = Join-Path -Path $TestDrive -ChildPath $destinationDirectoryName

        It 'File structure and contents of the destination should not match the file structure and contents of the archive before Set-TargetResource' {
            Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath -CheckContents | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Present should return false before Set-TargetResource' {
            Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Absent should return true before Set-TargetResource' {
            Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $true
        }

        $null = Set-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath

        It 'File structure and contents of the destination should match the file structure and contents of the archive after Set-TargetResource' {
            Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath -CheckContents | Should Be $true
        }

        It 'Test-TargetResource with Ensure as Present should return true after Set-TargetResource' {
            Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $true
        }

        It 'Test-TargetResource with Ensure as Absent should return false after Set-TargetResource' {
            Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $false
        }
    }

    Context 'Remove a basic archive' {
        $zipFileName = 'SetFunctionality'
        $subfolderName = 'Folder1'

        $zipFileStructure = @{
            $subfolderName = @{
                File1 = 'Fake file contents'
            }
        }

        $zipFilePath = New-ZipFileFromHashtable -Name $zipFileName -ParentPath $TestDrive -ZipFileStructure $zipFileStructure

        $destinationDirectoryName = 'RemoveBasicArchive'
        $destinationDirectoryPath = Join-Path -Path $TestDrive -ChildPath $destinationDirectoryName

        It 'File structure and contents of the destination should not match the file structure and contents of the archive before Set-TargetResource' {
            Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath -CheckContents | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Present should return false before Set-TargetResource' {
            Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Absent should return true before Set-TargetResource' {
            Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $true
        }

        $null = Set-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath

        It 'File structure and contents of the destination should not match the file structure and contents of the archive after Set-TargetResource' {
            Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath -CheckContents | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Present should return false after Set-TargetResource' {
            Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Absent should return true after Set-TargetResource' {
            Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $true
        }
    }

    Context 'Expand an archive with nested directories' {
        $zipFileName = 'NestedArchive'

        $zipFileStructure = @{
            Folder1 = @{}
            Folder2 = @{
                Folder21 = @{
                    Folder22 = @{
                        Folder23 = @{}
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
                            Folder44 = @{}
                        }
                    }
                }
            }
            File1 = 'Fake file contents'
            File2 = 'Fake file contents'
        }

        $zipFilePath = New-ZipFileFromHashtable -Name $zipFileName -ParentPath $TestDrive -ZipFileStructure $zipFileStructure

        $destinationDirectoryName = 'ExpandNestedArchive'
        $destinationDirectoryPath = Join-Path -Path $TestDrive -ChildPath $destinationDirectoryName

        It 'File structure and contents of the destination should not match the file structure and contents of the archive before Set-TargetResource' {
            Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath -CheckContents | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Present should return false before Set-TargetResource' {
            Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Absent should return true before Set-TargetResource' {
            Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $true
        }

        $null = Set-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath

        It 'File structure and contents of the destination should match the file structure and contents of the archive after Set-TargetResource' {
            Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath -CheckContents | Should Be $true
        }

        It 'Test-TargetResource with Ensure as Present should return true after Set-TargetResource' {
            Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $true
        }

        It 'Test-TargetResource with Ensure as Absent should return false after Set-TargetResource' {
            Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $false
        }
    }

    Context 'Remove an archive with nested directories' {
        $zipFileName = 'NestedArchive'

        $zipFileStructure = @{
            Folder1 = @{}
            Folder2 = @{
                Folder21 = @{
                    Folder22 = @{
                        Folder23 = @{}
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
                            Folder44 = @{}
                        }
                    }
                }
            }
            File1 = 'Fake file contents'
            File2 = 'Fake file contents'
        }

        $zipFilePath = New-ZipFileFromHashtable -Name $zipFileName -ParentPath $TestDrive -ZipFileStructure $zipFileStructure

        $destinationDirectoryName = 'RemoveNestedArchive'
        $destinationDirectoryPath = Join-Path -Path $TestDrive -ChildPath $destinationDirectoryName

        It 'File structure and contents of the destination should not match the file structure and contents of the archive before Set-TargetResource' {
            Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath -CheckContents | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Present should return false before Set-TargetResource' {
            Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Absent should return true before Set-TargetResource' {
            Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $true
        }

        $null = Set-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath

        It 'File structure and contents of the destination should not match the file structure and contents of the archive after Set-TargetResource' {
            Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath -CheckContents | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Present should return false after Set-TargetResource' {
            Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Absent should return true after Set-TargetResource' {
            Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $true
        }
    }

    Context 'Expand an archive when another archive with the same timestamp exists in the same folder' {
        $zipFileName1 = 'SameTimestamp1'

        $zipFileStructure1 = @{
            Folder1 = @{
                File1 = 'Fake file contents'
            }
        }

        $zipFilePath1 = New-ZipFileFromHashtable -Name $zipFileName1 -ParentPath $TestDrive -ZipFileStructure $zipFileStructure1

        $zipFileName2 = 'SameTimestamp2'

        $zipFileStructure2 = @{
            Folder2 = @{
                File2 = 'Fake file contents'
            }
        }

        $zipFilePath2 = New-ZipFileFromHashtable -Name $zipFileName2 -ParentPath $TestDrive -ZipFileStructure $zipFileStructure2

        $currentTimestamp = Get-Date
        $null = Set-ItemProperty -Path $zipFilePath1 -Name 'LastWriteTime' -Value $currentTimestamp
        $null = Set-ItemProperty -Path $zipFilePath2 -Name 'LastWriteTime' -Value $currentTimestamp

        $destinationDirectoryName = 'ArchiveWithMatchingTimeStampDestination'
        $destinationDirectoryPath = Join-Path -Path $TestDrive -ChildPath $destinationDirectoryName

        It 'File structure and contents of the destination should not match the file structure and contents of the archive before Set-TargetResource' {
            Test-FileStructuresMatch -SourcePath $zipFilePath1.Replace('.zip', '') -DestinationPath $destinationDirectoryPath -CheckContents | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Present should return false for specified archive before Set-TargetResource' {
            Test-TargetResource -Ensure 'Present' -Path $zipFilePath1 -Destination $destinationDirectoryPath | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Absent should return true for specified archive before Set-TargetResource' {
            Test-TargetResource -Ensure 'Absent' -Path $zipFilePath1 -Destination $destinationDirectoryPath | Should Be $true
        }

        It 'Test-TargetResource with Ensure as Present should return false for other archive with same timestamp with before Set-TargetResource' {
            Test-TargetResource -Ensure 'Present' -Path $zipFilePath2 -Destination $destinationDirectoryPath | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Absent should return true for other archive with same timestamp before Set-TargetResource' {
            Test-TargetResource -Ensure 'Absent' -Path $zipFilePath2 -Destination $destinationDirectoryPath | Should Be $true
        }

        $null = Set-TargetResource -Ensure 'Present' -Path $zipFilePath1 -Destination $destinationDirectoryPath

        It 'File structure and contents of the destination should match the file structure and contents of the archive after Set-TargetResource' {
            Test-FileStructuresMatch -SourcePath $zipFilePath1.Replace('.zip', '') -DestinationPath $destinationDirectoryPath -CheckContents | Should Be $true
        }

        It 'Test-TargetResource with Ensure as Present should return true for specified archive after Set-TargetResource' {
            Test-TargetResource -Ensure 'Present' -Path $zipFilePath1 -Destination $destinationDirectoryPath | Should Be $true
        }

        It 'Test-TargetResource with Ensure as Absent should return false for specified archive after Set-TargetResource' {
            Test-TargetResource -Ensure 'Absent' -Path $zipFilePath1 -Destination $destinationDirectoryPath | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Present should return false for other archive with same timestamp with before Set-TargetResource' {
            Test-TargetResource -Ensure 'Present' -Path $zipFilePath2 -Destination $destinationDirectoryPath | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Absent should return true for other archive with same timestamp before Set-TargetResource' {
            Test-TargetResource -Ensure 'Absent' -Path $zipFilePath2 -Destination $destinationDirectoryPath | Should Be $true
        }
    }

    Context 'Remove an archive with an extra file in a nested directory' {
        $zipFileName = 'NestedArchiveWithAdd'

        $zipFileStructure = @{
            Folder1 = @{
                Folder11 = @{
                    Folder12 = @{
                        Folder13 = @{
                            Folder14 = @{
                                File11 = 'Fake file contents'
                            }
                        }
                    }
                }
            }
            File1 = 'Fake file contents'
            File2 = 'Fake file contents'
        }

        $zipFilePath = New-ZipFileFromHashtable -Name $zipFileName -ParentPath $TestDrive -ZipFileStructure $zipFileStructure

        $destinationDirectoryName = 'RemoveArchiveWithExtra'
        $destinationDirectoryPath = Join-Path -Path $TestDrive -ChildPath $destinationDirectoryName

        $null = Expand-Archive -Path $zipFilePath -DestinationPath $destinationDirectoryPath -Force

        $newFilePath = "$destinationDirectoryPath\Folder1\Folder11\Folder12\AddedFile"
        $null = New-Item -Path $newFilePath -ItemType 'File'
        $null = Set-Content -Path $newFilePath -Value 'Fake text'

        It 'File structure and contents of the destination should match the file structure and contents of the archive before Set-TargetResource' {
            Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath -CheckContents | Should Be $true
        }

        It 'Test-TargetResource with Ensure as Present should return true before Set-TargetResource' {
            Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $true
        }

        It 'Test-TargetResource with Ensure as Absent should return false before Set-TargetResource' {
            Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $false
        }

        It 'Extra file should be present before Set-TargetResource' {
            Test-Path -Path $newFilePath | Should Be $true
        }

        Set-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath
        
        It 'File structure and contents of the destination should not match the file structure and contents of the archive after Set-TargetResource' {
            Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath -CheckContents | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Present should return false after Set-TargetResource' {
            Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $false
        }

        It 'Test-TargetResource with Ensure as Absent should return true after Set-TargetResource' {
            Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath | Should Be $true
        }

        It 'Extra file should be present after Set-TargetResource' {
            Test-Path -Path $newFilePath | Should Be $true
        }
    }
    
    $possibleChecksumValues = @( 'SHA-1', 'SHA-256', 'SHA-512', 'CreatedDate', 'ModifiedDate' )
    
    foreach ($possibleChecksumValue in $possibleChecksumValues)
    {        
        Context "Expand an archive with an edited file, Validate and Force specified, and Checksum specified as $possibleChecksumValue" {
            $zipFileName = 'ChecksumWithModifiedFile'
            $fileToEditName = 'File1'
            $fileNotToEditName = 'File2'

            $zipFileStructure = @{
                $fileToEditName = 'Fake file contents'
                $fileNotToEditName = 'Fake file contents'
            }

            $zipFilePath = New-ZipFileFromHashtable -Name $zipFileName -ParentPath $TestDrive -ZipFileStructure $zipFileStructure

            $destinationDirectoryName = 'ExpandModifiedArchiveWithCheck'
            $destinationDirectoryPath = Join-Path -Path $TestDrive -ChildPath $destinationDirectoryName

            $null = Expand-Archive -Path $zipFilePath -DestinationPath $destinationDirectoryPath -Force

            $fileToEditPath = Join-Path -Path $destinationDirectoryPath -ChildPath $fileToEditName

            It 'File to edit should exist at the destination before Set-TargetResource' {
                Test-Path -Path $fileToEditPath | Should Be $true
            }

            $fileBeforeEdit = Get-Item -Path $fileToEditPath
            $lastWriteTimeBeforeEdit = $fileBeforeEdit.LastWriteTime
            $creationTimeBeforeEdit = $fileBeforeEdit.CreationTime

            $null = Set-Content -Path $fileToEditPath -Value 'Different false text' -Force
            Set-ItemProperty -Path $fileToEditPath -Name 'LastWriteTime' -Value ([DateTime]::MaxValue)
            Set-ItemProperty -Path $fileToEditPath -Name 'CreationTime' -Value ([DateTime]::MaxValue)

            $fileAfterEdit = Get-Item -Path $fileToEditPath

            It 'Edited file at the destination should have different content than the same file in the archive before Set-TargetResource' {
                Get-Content -Path $fileToEditPath -Raw | Should Not Be ($zipFileStructure[$fileToEditName] + "`r`n")
            }

            It 'Edited file at the destination should have different last write time than the same file in the archive before Set-TargetResource' {
                $fileAfterEdit.LastWriteTime | Should Not Be $lastWriteTimeBeforeEdit
            }

            It 'Edited file at the destination should have different creation time than the last write time of the the same file in the archive before Set-TargetResource' {
                $fileAfterEdit.CreationTime | Should Not Be $lastWriteTimeBeforeEdit
            }

            It 'Test-TargetResource with Ensure as Present should return false before Set-TargetResource' {
                Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true -Checksum $possibleChecksumValue | Should Be $false
            }

            It 'Test-TargetResource with Ensure as Absent should return true before Set-TargetResource' {
                Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true -Checksum $possibleChecksumValue | Should Be $true
            }

            It 'File structure and contents of the destination should not match the file structure and contents of the archive before Set-TargetResource' {
                Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath -CheckContents | Should Be $false
            }

            Set-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true -Checksum $possibleChecksumValue -Force $true

            $fileAfterSetTargetResource = Get-Item -Path $fileToEditPath

            It 'Edited file should exist at the destination after Set-TargetResource' {
                Test-Path -Path $fileToEditPath | Should Be $true
            }

            It 'Edited file at the destination should have the same content as the same file in the archive after Set-TargetResource' {
                Get-Content -Path $fileToEditPath -Raw | Should Be ($zipFileStructure[$fileToEditName] + "`r`n")
            }

            It 'Edited file at the destination should have the same last write time as the same file in the archive after Set-TargetResource' {
                $fileAfterSetTargetResource.LastWriteTime | Should Be $lastWriteTimeBeforeEdit
            }

            It 'Edited file at the destination should have the same creation time as last write time of the the same file in the archive after Set-TargetResource' {
                $fileAfterSetTargetResource.CreationTime | Should Be $lastWriteTimeBeforeEdit
            }

            It 'Test-TargetResource with Ensure as Present should return true after Set-TargetResource' {
                Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true -Checksum $possibleChecksumValue | Should Be $true
            }

            It 'Test-TargetResource with Ensure as Absent should return false after Set-TargetResource' {
                Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true -Checksum $possibleChecksumValue | Should Be $false
            }

            It 'File structure and contents of the destination should match the file structure and contents of the archive after Set-TargetResource' {
                Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath -CheckContents | Should Be $true
            }
        }

        Context "Expand an archive with an edited file, Validate specfied, Force not specified, and Checksum specified as $possibleChecksumValue" {
            $zipFileName = 'ChecksumWithModifiedFile'
            $fileToEditName = 'File1'
            $fileNotToEditName = 'File2'

            $zipFileStructure = @{
                $fileToEditName = 'Fake file contents'
                $fileNotToEditName = 'Fake file contents'
            }

            $zipFilePath = New-ZipFileFromHashtable -Name $zipFileName -ParentPath $TestDrive -ZipFileStructure $zipFileStructure

            $destinationDirectoryName = 'ExpandModifiedArchiveWithCheckFail'
            $destinationDirectoryPath = Join-Path -Path $TestDrive -ChildPath $destinationDirectoryName

            $null = Expand-Archive -Path $zipFilePath -DestinationPath $destinationDirectoryPath -Force

            $fileToEditPath = Join-Path -Path $destinationDirectoryPath -ChildPath $fileToEditName

            It 'File to edit should exist at the destination before Set-TargetResource' {
                Test-Path -Path $fileToEditPath | Should Be $true
            }

            $fileBeforeEdit = Get-Item -Path $fileToEditPath
            $lastWriteTimeBeforeEdit = $fileBeforeEdit.LastWriteTime
            $creationTimeBeforeEdit = $fileBeforeEdit.CreationTime

            $null = Set-Content -Path $fileToEditPath -Value 'Different false text' -Force
            Set-ItemProperty -Path $fileToEditPath -Name 'LastWriteTime' -Value ([DateTime]::MaxValue)
            Set-ItemProperty -Path $fileToEditPath -Name 'CreationTime' -Value ([DateTime]::MaxValue)

            $fileAfterEdit = Get-Item -Path $fileToEditPath

            It 'Edited file at the destination should have different content than the same file in the archive before Set-TargetResource' {
                Get-Content -Path $fileToEditPath -Raw | Should Not Be ($zipFileStructure[$fileToEditName] + "`r`n")
            }

            It 'Edited file at the destination should have different last write time than the same file in the archive before Set-TargetResource' {
                $fileAfterEdit.LastWriteTime | Should Not Be $lastWriteTimeBeforeEdit
            }

            It 'Edited file at the destination should have different creation time than the last write time of the the same file in the archive before Set-TargetResource' {
                $fileAfterEdit.CreationTime | Should Not Be $lastWriteTimeBeforeEdit
            }

            It 'Test-TargetResource with Ensure as Present should return false before Set-TargetResource' {
                Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true -Checksum $possibleChecksumValue | Should Be $false
            }

            It 'Test-TargetResource with Ensure as Absent should return true before Set-TargetResource' {
                Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true -Checksum $possibleChecksumValue | Should Be $true
            }

            It 'File structure and contents of the destination should not match the file structure and contents of the archive before Set-TargetResource' {
                Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath -CheckContents | Should Be $false
            }

            { Set-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true -Checksum $possibleChecksumValue } | Should Throw
        }

        Context "Remove an archive with an edited file, Validate specified, and Checksum specified as $possibleChecksumValue" {
            $zipFileName = 'ChecksumWithModifiedFile'
            $fileToEditName = 'File1'
            $fileNotToEditName = 'File2'

            $zipFileStructure = @{
                $fileToEditName = 'Fake file contents'
                $fileNotToEditName = 'Fake file contents'
            }

            $zipFilePath = New-ZipFileFromHashtable -Name $zipFileName -ParentPath $TestDrive -ZipFileStructure $zipFileStructure

            $destinationDirectoryName = 'RemoveModifiedArchiveWithCheck'
            $destinationDirectoryPath = Join-Path -Path $TestDrive -ChildPath $destinationDirectoryName

            $null = Expand-Archive -Path $zipFilePath -DestinationPath $destinationDirectoryPath -Force

            $fileToEditPath = Join-Path -Path $destinationDirectoryPath -ChildPath $fileToEditName

            It 'File to edit should exist at the destination before Set-TargetResource' {
                Test-Path -Path $fileToEditPath | Should Be $true
            }

            $fileBeforeEdit = Get-Item -Path $fileToEditPath
            $lastWriteTimeBeforeEdit = $fileBeforeEdit.LastWriteTime
            $creationTimeBeforeEdit = $fileBeforeEdit.CreationTime

            $null = Set-Content -Path $fileToEditPath -Value 'Different false text' -Force
            Set-ItemProperty -Path $fileToEditPath -Name 'LastWriteTime' -Value ([DateTime]::MaxValue)
            Set-ItemProperty -Path $fileToEditPath -Name 'CreationTime' -Value ([DateTime]::MaxValue)

            $fileAfterEdit = Get-Item -Path $fileToEditPath

            It 'Edited file at the destination should have the edited content' {
                Get-Content -Path $fileToEditPath -Raw | Should Be ('Different false text' + "`r`n")
            }

            It 'Edited file at the destination should have different last write time than the same file in the archive before Set-TargetResource' {
                $fileAfterEdit.LastWriteTime | Should Not Be $lastWriteTimeBeforeEdit
            }

            It 'Edited file at the destination should have different creation time than the last write time of the the same file in the archive before Set-TargetResource' {
                $fileAfterEdit.CreationTime | Should Not Be $lastWriteTimeBeforeEdit
            }

            It 'Test-TargetResource with Ensure as Present should return false before Set-TargetResource' {
                Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true -Checksum $possibleChecksumValue | Should Be $false
            }

            It 'Test-TargetResource with Ensure as Absent should return true before Set-TargetResource' {
                Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true -Checksum $possibleChecksumValue | Should Be $true
            }

            It 'File structure and contents of the destination should not match the file structure and contents of the archive before Set-TargetResource' {
                Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath -CheckContents | Should Be $false
            }

            Set-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true -Checksum $possibleChecksumValue

            $fileAfterSetTargetResource = Get-Item -Path $fileToEditPath

            It 'Edited file should exist at the destination after Set-TargetResource' {
                Test-Path -Path $fileToEditPath | Should Be $true
            }

            It 'Edited file at the destination should have the edited content' {
                Get-Content -Path $fileToEditPath -Raw | Should Be ('Different false text' + "`r`n")
            }

            It 'Edited file at the destination should have different last write time than the same file in the archive after Set-TargetResource' {
                $fileAfterEdit.LastWriteTime | Should Not Be $lastWriteTimeBeforeEdit
            }

            It 'Edited file at the destination should have different creation time than the last write time of the the same file in the archive after Set-TargetResource' {
                $fileAfterEdit.CreationTime | Should Not Be $lastWriteTimeBeforeEdit
            }

            It 'Test-TargetResource with Ensure as Present should return false after Set-TargetResource' {
                Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true -Checksum $possibleChecksumValue | Should Be $false
            }

            It 'Test-TargetResource with Ensure as Absent should return true after Set-TargetResource' {
                Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true -Checksum $possibleChecksumValue | Should Be $true
            }

            It 'File structure and contents of the destination should not match the file structure and contents of the archive before Set-TargetResource' {
                Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath -CheckContents | Should Be $false
            }
        }
    }

    Context 'Archive name contains a bracket' {
        $zipFileName = 'ReturnCorrectValue['

        $zipFileStructure = @{
            Folder1 = @{
                File1 = 'Fake file contents'
            }
        }

        $zipFilePath = New-ZipFileFromHashtable -Name $zipFileName -ParentPath $TestDrive -ZipFileStructure $zipFileStructure

        $destination = Join-Path -Path $TestDrive -ChildPath 'ArchiveNameWithBracket'

        It 'Set-TargetResource should not throw' {
            { Set-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destination } | Should Not Throw
        }

        It 'Get-TargetResource should not throw' {
            { $null = Get-TargetResource -Path $zipFilePath -Destination $destination } | Should Not Throw
        }

        It 'Test-TargetResource should not throw' {
            { $null = Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destination } | Should Not Throw
        }
    }
}