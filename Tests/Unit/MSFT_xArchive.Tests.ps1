Import-Module "$PSScriptRoot\..\..\DscResource.Tests\TestHelper.psm1" -Force

$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'xPSDesiredStateConfiguration' `
    -DSCResourceName 'MSFT_xArchive' `
    -TestType Unit

InModuleScope 'MSFT_xArchive' {
    Describe 'xArchive Unit Tests' {
        BeforeAll {
            Import-Module "$PSScriptRoot\MSFT_xArchive.TestHelper.psm1" -Force

            $script:currentTestCount = 0

            $script:allTestsDirectoryPath = Join-Path -Path (Get-Location) -ChildPath 'xArchiveResourceTests'

            if (Test-Path -Path $script:allTestsDirectoryPath)
            {
                Remove-Item -Path $script:allTestsDirectoryPath -Recurse
            }

            New-Item -Path $script:allTestsDirectoryPath -ItemType Directory

            Add-Type -AssemblyName System.IO.Compression.FileSystem
        }

        AfterAll {
            if (Test-Path -Path $script:allTestsDirectoryPath)
            {
                Remove-Item -Path $script:allTestsDirectoryPath -Recurse
            }
        }

        BeforeEach {
            Remove-Item -Path $script:cacheLocation -Recurse -ErrorAction SilentlyContinue

            $script:currentTestCount++
            $script:currentTestDirectoryPath = Join-Path -Path $script:allTestsDirectoryPath -ChildPath "Test$script:currentTestCount"

            New-Item -Path $script:currentTestDirectoryPath -ItemType Directory | Out-Null
        }

        Context 'Set-TargetResource' {
            It 'Should unzip the correct file with two zip files with the same timestamp' {
                $zipFileName1 = 'SameTimestamp1'

                $zipFileStructure1 = @{
                    Folder1 = @{
                        File1 = 'Fake file contents'
                    }
                }

                $zipFilePath1 = New-ZipFileFromHashtable -Name $zipFileName1 -ParentPath $script:currentTestDirectoryPath -ZipFileStructure $zipFileStructure1

                $zipFileName2 = 'SameTimestamp2'

                $zipFileStructure2 = @{
                    Folder2 = @{
                        File2 = 'Fake file contents'
                    }
                }

                $zipFilePath2 = New-ZipFileFromHashtable -Name $zipFileName2 -ParentPath $script:currentTestDirectoryPath -ZipFileStructure $zipFileStructure2

                $currentTimestamp = Get-Date

                Set-ItemProperty -Path $zipFilePath1 -Name 'LastWriteTime' -Value $currentTimestamp
                Set-ItemProperty -Path $zipFilePath2 -Name 'LastWriteTime' -Value $currentTimestamp

                $destinationDirectoryName = 'UnzippedArchive'
                $destinationDirectoryPath = Join-Path -Path $script:currentTestDirectoryPath -ChildPath $destinationDirectoryName

                Set-TargetResource -Ensure 'Present' -Path $zipFilePath1 -Destination $destinationDirectoryPath

                Test-FileStructuresMatch -SourcePath $zipFilePath1.Replace('.zip', '') -DestinationPath $destinationDirectoryPath

                $testTargetResourceResult = Test-TargetResource -Ensure 'Present' -Path $zipFilePath1 -Destination $destinationDirectoryPath
                $testTargetResourceResult | Should Be $true

                $testTargetResourceResult = Test-TargetResource -Ensure 'Present' -Path $zipFilePath2 -Destination $destinationDirectoryPath
                $testTargetResourceResult | Should Be $false
            }

            It 'Should correctly unzip and remove a basic archive' {
                $zipFileName = 'SetFunctionality'
                $subfolderName = 'Folder1'

                $zipFileStructure = @{
                    $subfolderName = @{
                        File1 = 'Fake file contents'
                    }
                }

                $zipFilePath = New-ZipFileFromHashtable -Name $zipFileName -ParentPath $script:currentTestDirectoryPath -ZipFileStructure $zipFileStructure

                $destinationDirectoryName = 'UnzippedArchive'
                $destinationDirectoryPath = Join-Path -Path $script:currentTestDirectoryPath -ChildPath $destinationDirectoryName

                Set-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath

                Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath

                $testTargetResourceResult = Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath
                $testTargetResourceResult | Should Be $true

                $testTargetResourceResult = Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath
                $testTargetResourceResult | Should Be $false

                $subfolderPath = Join-Path -Path $destinationDirectoryPath -ChildPath $subfolderName

                $testPathResult = Test-Path $subfolderPath
                $testPathResult | Should Be $true

                Set-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath

                $testPathResult = Test-Path $subfolderPath
                $testPathResult | Should Be $false
            }

            It 'Should correctly unzip and remove an archive with nested directories' {
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

                $zipFilePath = New-ZipFileFromHashtable -Name $zipFileName -ParentPath $script:currentTestDirectoryPath -ZipFileStructure $zipFileStructure

                $destinationDirectoryName = 'UnzippedArchive'
                $destinationDirectoryPath = Join-Path -Path $script:currentTestDirectoryPath -ChildPath $destinationDirectoryName

                Set-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath

                Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath

                $testTargetResourceResult = Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath
                $testTargetResourceResult | Should Be $true

                $testTargetResourceResult = Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath
                $testTargetResourceResult | Should Be $false

                foreach ($fileName in $zipFileStructure.Keys)
                {
                    $filePath = Join-Path -Path $destinationDirectoryPath -ChildPath $fileName

                    $testPathResult = Test-Path -Path $filePath
                    $testPathResult | Should Be $true
                }

                Set-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath

                $testTargetResourceResult = Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath
                $testTargetResourceResult | Should Be $false

                $testTargetResourceResult = Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath
                $testTargetResourceResult | Should Be $true

                foreach ($fileName in $zipFileStructure.Keys)
                {
                    $filePath = Join-Path -Path $destinationDirectoryPath -ChildPath $fileName

                    $testPathResult = Test-Path -Path $filePath
                    $testPathResult | Should Be $false
                }
            }

            It 'Should not remove an added file when removing a nested archive' {
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

                $zipFilePath = New-ZipFileFromHashtable -Name $zipFileName -ParentPath $script:currentTestDirectoryPath -ZipFileStructure $zipFileStructure

                $destinationDirectoryName = 'UnzippedArchive'
                $destinationDirectoryPath = Join-Path -Path $script:currentTestDirectoryPath -ChildPath $destinationDirectoryName

                Set-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath

                Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath

                $testTargetResourceResult = Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath
                $testTargetResourceResult | Should Be $true

                $newFilePath = "$destinationDirectoryPath\Folder1\Folder11\Folder12\AddedFile"
                New-Item -Path $newFilePath -ItemType File | Out-Null
                Set-Content -Path $newFilePath -Value 'Fake text' | Out-Null

                $testTargetResourceResult = Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath
                $testTargetResourceResult | Should Be $true

                Set-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath
                $testPathResult = Test-Path -Path "$destinationDirectoryPath\Folder1"
                $testPathResult | Should Be $true

                $testPathResult = Test-Path -Path "$destinationDirectoryPath\Folder1\Folder12\Folder13\Folder14"
                $testPathResult | Should Be $false
            }

            It 'Should not remove an added file with Validate and any Checksum value specified'{
                $zipFileName = 'ChecksumWithModifiedFile'
                $fileToEditName = 'File1'
                $fileNotToEditName = 'File2'

                $zipFileStructure = @{
                    $fileToEditName = 'Fake file contents'
                    $fileNotToEditName = 'Fake file contents'
                }

                $zipFilePath = New-ZipFileFromHashtable -Name $zipFileName -ParentPath $script:currentTestDirectoryPath -ZipFileStructure $zipFileStructure

                $destinationDirectoryName = 'UnzippedArchive'
                $destinationDirectoryPath = Join-Path -Path $script:currentTestDirectoryPath -ChildPath $destinationDirectoryName

                $fileToEditPath = Join-Path -Path $destinationDirectoryPath -ChildPath $fileToEditName

                $possibleChecksumValues = @( 'SHA-1', 'SHA-256', 'SHA-512', 'CreatedDate', 'ModifiedDate' )

                foreach ($possibleChecksumValue in $possibleChecksumValues)
                {
                    Write-Verbose -Message "Evaluating checksum value '$possibleChecksumValue'"

                    $testTargetResourceResult = Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true -Checksum $possibleChecksumValue
                    $testTargetResourceResult | Should Be $false

                    Write-Verbose -Message 'Ensuring that the files are present with Force specified'
                    Set-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true -Checksum $possibleChecksumValue -Force $true

                    $fileToEditContents = Get-Content -Path $fileToEditPath
                    $fileToEditContents.Contains('Different false text') | Should Be $false

                    Write-Verbose -Message 'Replacing file'
                    Remove-Item -Path $fileToEditPath | Out-Null

                    Set-Content -Path $fileToEditPath -Value 'Different false text' | Out-Null
                    Set-ItemProperty -Path $fileToEditPath -Name 'LastWriteTime' -Value ([DateTime]::MaxValue)
                    Set-ItemProperty -Path $fileToEditPath -Name 'CreationTime' -Value ([DateTime]::MaxValue)

                    Write-Verbose -Message 'Ensuring that the files are absent'
                    Set-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true -Checksum $possibleChecksumValue

                    $testPathResult = Test-Path -Path $fileToEditPath
                    $testPathResult | Should Be $true

                    $fileNotToEditPath = Join-Path -Path $destinationDirectoryPath -ChildPath $fileNotToEditName

                    $testPathResult = Test-Path -Path $fileNotToEditPath
                    $testPathResult | Should Be $false

                    Write-Verbose -Message 'Ensuring that the files are present, Force not specified'
                    { Set-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true -Checksum $possibleChecksumValue } | Should Throw
                }
            }
        }

        Context 'Test-TargetResource' {
            It 'Should return correct value based on presence or absence of an archive at the given location' {
                $zipFileName = 'ReturnCorrectValue'

                $zipFileStructure = @{
                    Folder1 = @{
                        File1 = 'Fake file contents'
                    }
                }

                $zipFilePath = New-ZipFileFromHashtable -Name $zipFileName -ParentPath $script:currentTestDirectoryPath -ZipFileStructure $zipFileStructure

                $testTargetResourceResult = Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $script:currentTestDirectoryPath
                $testTargetResourceResult | Should Be $false

                $testTargetResourceResult = Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $script:currentTestDirectoryPath
                $testTargetResourceResult | Should Be $true

                $destinationPath = Join-Path -Path $script:currentTestDirectoryPath -ChildPath $zipFileName

                $testTargetResourceResult = Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationPath
                $testTargetResourceResult | Should Be $true

                $testTargetResourceResult = Test-TargetResource -Ensure 'Absent' -Path $zipFilePath -Destination $destinationPath
                $testTargetResourceResult | Should Be $false
            }

            It 'Should return false when file modified and Validate specified' {
                $zipFileName = 'FileModifiedValidateSpecified'
                $fileToEditName = 'File1'
                $fileNotToEditName = 'File2'

                $zipFileStructure = @{
                    $fileToEditName = 'Fake file contents'
                    $fileNotToEditName = 'Fake file contents'
                }

                $zipFilePath = New-ZipFileFromHashtable -Name $zipFileName -ParentPath $script:currentTestDirectoryPath -ZipFileStructure $zipFileStructure

                $destinationDirectoryName = 'UnzippedArchive'
                $destinationDirectoryPath = Join-Path -Path $script:currentTestDirectoryPath -ChildPath $destinationDirectoryName

                Set-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true

                Test-FileStructuresMatch -SourcePath $zipFilePath.Replace('.zip', '') -DestinationPath $destinationDirectoryPath

                $testTargetResourceResult = Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath
                $testTargetResourceResult | Should Be $true

                $fileToEditPath = Join-Path -Path $destinationDirectoryPath -ChildPath $fileToEditName
                Set-Content -Path $fileToEditPath -Value 'Different false text' | Out-Null

                $testTargetResourceResult = Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath
                $testTargetResourceResult | Should Be $true

                $testTargetResourceResult = Test-TargetResource -Ensure 'Present' -Path $zipFilePath -Destination $destinationDirectoryPath -Validate $true
                $testTargetResourceResult | Should Be $false
            }
        }
    }
}
