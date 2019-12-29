$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'DSC_xRemoteFile'

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
        Describe 'xRemoteFile Unit Tests' {
            BeforeAll {
                function Get-InvalidDataException
                {
                    param (
                        [Parameter(Mandatory = $true)]
                        [System.String]
                        $errorId,

                        [Parameter(Mandatory = $true)]
                        [System.String]
                        $errorMessage
                    )

                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidData
                    $exception = New-Object `
                        -TypeName System.InvalidOperationException `
                        -ArgumentList $errorMessage
                    $errorRecord = New-Object `
                        -TypeName System.Management.Automation.ErrorRecord `
                        -ArgumentList $exception, $errorId, $errorCategory, $null
                    return $errorRecord
                }

                $script:testDirectoryPath = Join-Path -Path $TestDrive -ChildPath 'MSFT_xRemoteFile.Tests'

                if (Test-Path -Path $script:testDirectoryPath)
                {
                    $null = Remove-Item -Path $script:testDirectoryPath -Recurse -Force
                }

                $null = New-Item -Path $script:testDirectoryPath -ItemType 'Directory'

                $script:testURIFile = 'test.xml'
                $script:testURI = "http://contoso.com/$script:testURIFile"
                $script:testURIFileNotExist = 'testnotexist.xml'
                $script:testURINotExist = "http://contoso.com/$script:testURIFileNotExist"

                $script:testDestinationFolder = Join-Path `
                    -Path $script:testDirectoryPath -ChildPath 'UnitTest_Folder'
                $script:testDestinationFolderFile = Join-Path `
                    -Path $script:testDestinationFolder -ChildPath $script:testURIFile
                $script:testDestinationFile = Join-Path `
                    -Path $script:testDirectoryPath -ChildPath 'UnitTest_File.xml'
                $script:testDestinationNotExist = Join-Path `
                    -Path $script:testDirectoryPath -ChildPath 'UnitTest_NotExist'

                # Create the splats
                $script:testSplatFile = @{
                    DestinationPath = $script:testDestinationFile
                    Uri = $script:testURI
                }
                $script:testSplatFileChecksum = $script:testSplatFile.clone()
                $script:testSplatFileChecksum.ChecksumType = 'MD5'

                $script:testSplatFolderFileExists = @{
                    DestinationPath = $script:testDestinationFolder;
                    Uri = $script:testURI;
                }
                $script:testSplatFolderFileExistsChecksum = $script:testSplatFolderFileExists.clone()
                $script:testSplatFolderFileExistsChecksum.ChecksumType = 'MD5'

                $script:testSplatFolderFileNotExist = @{
                    DestinationPath = $script:testDestinationFolder;
                    Uri = $script:testURINotExist;
                }

                $script:testFileHash = @{
                    Hash = 'abc12345'
                }

                $null = New-Item -Path $script:testDestinationFolder -ItemType Directory
                $null = Set-Content -Path $script:testDestinationFile -Value 'Dummy Content'
                $null = Set-Content -Path $script:testDestinationFolderFile -Value 'Dummy Content'
            }

            Describe 'xRemoteFile\Get-TargetResource' {
                $result = Get-TargetResource @testSplatFile

                It 'Returns "Present" when DestinationPath is a File and exists' {
                    $Result.Ensure | Should -Be 'Present'
                }

                Mock Get-FileHash -MockWith { return $script:testFileHash }
                $result = Get-TargetResource @testSplatFileChecksum

                It 'Returns "Present" and file checksum value when DestinationPath is a File and exists' {
                    $Result.Ensure | Should -Be 'Present'
                    $Result.Checksum | Should -Be $script:testFileHash.Hash
                }

                $result = Get-TargetResource @testSplatFolderFileExists

                It 'Returns "Present" when DestinationPath is a Directory and exists and URI file exists' {
                    $Result.Ensure | Should -Be 'Present'
                }

                Mock Get-FileHash -MockWith { return $script:testFileHash }
                $result = Get-TargetResource @testSplatFolderFileExistsChecksum

                It 'Returns "Present" and a file checksum when DestinationPath is a Directory and exists and URI file exists' {
                    $Result.Ensure | Should -Be 'Present'
                    $Result.Checksum | Should -Be $script:testFileHash.Hash
                }

                $result = Get-TargetResource @testSplatFolderFileNotExist

                It 'Returns "Absent" when DestinationPath is a Directory and exists but URI file does not' {
                    $Result.Ensure | Should -Be 'Absent'
                }

                Mock Get-PathItemType -MockWith { return 'Other' }
                $result = Get-TargetResource @testSplatFile

                It 'Returns "Absent" when DestinationPath is Other' {
                    $Result.Ensure | Should -Be 'Absent'
                }
            }

            Describe 'xRemoteFile\Set-TargetResource' {
                Context 'URI is "bad://.."' {
                    It 'Throws a UriValidationFailure exeception' {
                        $splat = $script:testSplatFile.Clone()
                        $splat.Uri = 'bad://contoso.com/test.xml'
                        $errorMessage = $($LocalizedData.InvalidWebUriError) `
                                    -f $splat.Uri
                        $errorRecord = Get-InvalidDataException `
                            -errorId "UriValidationFailure" `
                            -errorMessage $errorMessage
                        { Set-TargetResource @splat } | Should -Throw -ExpectedMessage $errorRecord
                    }
                }

                Context 'DestinationPath is "bad://.."' {
                    It 'Throws a DestinationPathSchemeValidationFailure exeception' {
                        $splat = $script:testSplatFile.Clone()
                        $splat.DestinationPath = 'bad://c:\test.xml'
                        $errorMessage = $($LocalizedData.InvalidDestinationPathSchemeError) `
                                    -f $splat.DestinationPath
                        $errorRecord = Get-InvalidDataException `
                            -errorId "DestinationPathSchemeValidationFailure" `
                            -errorMessage $errorMessage
                        { Set-TargetResource @splat } | Should -Throw -ExpectedMessage $errorRecord
                    }
                }

                Context 'DestinationPath starts with "\\"' {
                    It 'Throws a DestinationPathIsUncFailure exeception' {
                        $splat = $script:testSplatFile.Clone()
                        $splat.DestinationPath = '\\myserver\share\test.xml'
                        $errorMessage = $($LocalizedData.DestinationPathIsUncError) `
                                    -f $splat.DestinationPath
                        $errorRecord = Get-InvalidDataException `
                            -errorId "DestinationPathIsUncFailure" `
                            -errorMessage $errorMessage
                        { Set-TargetResource @splat } | Should -Throw -ExpectedMessage $errorRecord
                    }
                }

                Context 'DestinationPath contains invalid characters "*"' {
                    It 'Throws a DestinationPathHasInvalidCharactersError exeception' {
                        $splat = $script:testSplatFile.Clone()
                        $splat.DestinationPath = 'c:\*.xml'
                        $errorMessage = $($LocalizedData.DestinationPathHasInvalidCharactersError) `
                                    -f $splat.DestinationPath
                        $errorRecord = Get-InvalidDataException `
                            -errorId "DestinationPathHasInvalidCharactersError" `
                            -errorMessage $errorMessage
                        { Set-TargetResource @splat } | Should -Throw -ExpectedMessage $errorRecord
                    }
                }

                Mock Update-Cache

                Context 'URI is invalid, DestinationPath is a file' {
                    It 'Throws a DownloadException exeception' {
                        $splat = $script:testSplatFile.Clone()
                        $splat.Uri = 'http://definitelydoesnotexist.com/reallydoesntexist.xml'
                        $errorMessage = $($LocalizedData.DownloadException) `
                                    -f "The remote name could not be resolved: 'definitelydoesnotexist.com'"
                        $errorRecord = Get-InvalidDataException `
                            -errorId "DownloadException" `
                            -errorMessage $errorMessage
                        { Set-TargetResource @splat } | Should -Throw -ExpectedMessage $errorRecord
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Update-Cache -Exactly 0
                    }
                }

                Mock Invoke-WebRequest

                Context 'URI is valid, DestinationPath is a file, download successful' {
                    It 'Does not throw' {
                        { Set-TargetResource @testSplatFile } | Should -Not -Throw
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Invoke-WebRequest -Exactly 1
                        Assert-MockCalled Update-Cache -Exactly 1
                    }
                }

                Mock Invoke-WebRequest
                Mock Get-FileHash -MockWith { return $script:testFileHash }

                Context 'URI is valid, DestinationPath is a file, Checksum provided, download successful' {
                    $splat = $script:testSplatFile.Clone()
                    $splat.Checksum = $script:testFileHash.Hash
                    $splat.ChecksumType = 'MD5'

                    It 'Does not throw' {
                        { Set-TargetResource @Splat } | Should -Not -Throw
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Invoke-WebRequest -Exactly 1
                        Assert-MockCalled Get-FileHash -Exactly 1
                        Assert-MockCalled Update-Cache -Exactly 1
                    }
                }

                Mock Invoke-WebRequest
                Mock Get-FileHash -MockWith { return $script:testFileHash }

                Context 'URI is valid, DestinationPath is a file, Checksum provided, Checksum fails' {
                    $splat = $script:testSplatFile.Clone()
                    $splat.Checksum = 'badhash'
                    $splat.ChecksumType = 'MD5'

                    It 'Does not throw' {
                        { Set-TargetResource @Splat } | Should -Throw
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Invoke-WebRequest -Exactly 1
                        Assert-MockCalled Get-FileHash -Exactly 1
                        Assert-MockCalled Update-Cache -Exactly 0
                    }
                }
            }

            Describe 'xRemoteFile\Test-TargetResource' {
                Mock Get-Cache

                Context 'URI is valid, DestinationPath is a File, file exists' {
                    It 'Returns "False"' {
                        Test-TargetResource @testSplatFile | Should -BeFalse
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Get-Cache -Exactly 1
                    }
                }

                Mock Get-FileHash -MockWith { return $script:testFileHash }

                Context 'URI is valid, DestinationPath is a File, file exists, Does not check checksum when MatchSource fails' {
                    It 'Returns "False"' {
                        $splat = $script:testSplatFile.Clone()
                        $splat.Checksum = $script:testFileHash.Hash
                        Test-TargetResource @Splat | Should -BeFalse
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Get-Cache -Exactly 1
                        Assert-MockCalled Get-FileHash -Exactly 0
                    }
                }

                Context 'URI is valid, DestinationPath is a File, file exists, matchsource is "False"' {
                    It 'Returns "True"' {
                        $splat = $script:testSplatFile.Clone()
                        $splat.MatchSource = $false
                        Test-TargetResource @splat | Should -BeTrue
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Get-Cache -Exactly 0
                    }
                }

                Mock Get-FileHash -MockWith { return $script:testFileHash }

                Context 'URI is valid, DestinationPath is a File, file exists, matchsource is "False", Checksum matches' {
                    It 'Returns "True"' {
                        $splat = $script:testSplatFileChecksum.Clone()
                        $splat.MatchSource = $false
                        $splat.Checksum = $script:testFileHash.Hash
                        Test-TargetResource @splat | Should -BeTrue
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Get-Cache -Exactly 0
                        Assert-MockCalled Get-FileHash -Exactly 1
                    }
                }

                Mock Get-FileHash -MockWith { return $script:testFileHash }

                Context 'URI is valid, DestinationPath is a File, file exists, matchsource is "False", Checksum does not match' {
                    It 'Returns "False"' {
                        $splat = $script:testSplatFileChecksum.Clone()
                        $splat.MatchSource = $false
                        $splat.Checksum = 'badHash'
                        Test-TargetResource @splat | Should -BeFalse
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Get-Cache -Exactly 0
                        Assert-MockCalled Get-FileHash -Exactly 1
                    }
                }

                Context 'URI is valid, DestinationPath is a Folder, file exists' {
                    It 'Returns "False"' {
                        Test-TargetResource @testSplatFolderFileExists | Should -BeFalse
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Get-Cache -Exactly 1
                    }
                }

                Context 'URI is valid, DestinationPath is a Folder, file exists, matchsource is "False"' {
                    It 'Returns "True"' {
                        $splat = $script:testSplatFolderFileExists.Clone()
                        $splat.MatchSource = $false
                        Test-TargetResource @splat | Should -BeTrue
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Get-Cache -Exactly 0
                    }
                }

                Context 'URI is valid, DestinationPath is a Folder, file does not exist' {
                    It 'Returns "False"' {
                        Test-TargetResource @testSplatFolderFileNotExist | Should -BeFalse
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Get-Cache -Exactly 0
                    }
                }

                Mock Get-FileHash

                Context 'URI is valid, DestinationPath is a Folder, file exists, matchsource is "False"' {
                    It 'Returns "False"' {
                        $splat = $script:testSplatFolderFileNotExist.Clone()
                        $splat.MatchSource = $false
                        Test-TargetResource @splat | Should -BeFalse
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Get-Cache -Exactly 0
                        Assert-MockCalled Get-FileHash -Exactly 0
                    }
                }

                Mock Get-FileHash -MockWith { return $script:testFileHash }

                Context 'URI is valid, DestinationPath is a Folder, file exists, matchsource is "False", checksum matches' {
                    It 'Returns "True"' {
                        $splat = $script:testSplatFolderFileExistsChecksum.Clone()
                        $splat.MatchSource = $false
                        $splat.Checksum = $script:testFileHash.Hash
                        Test-TargetResource @splat | Should -BeTrue
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Get-Cache -Exactly 0
                        Assert-MockCalled Get-FileHash -Exactly 1
                    }
                }

                Mock Get-FileHash -MockWith { return $script:testFileHash }

                Context 'URI is valid, DestinationPath is a Folder, file exists, matchsource is "False", checksum does not match' {
                    It 'Returns "False"' {
                        $splat = $script:testSplatFolderFileExistsChecksum.Clone()
                        $splat.MatchSource = $false
                        $splat.Checksum = 'badHash'
                        Test-TargetResource @splat | Should -BeFalse
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Get-Cache -Exactly 0
                        Assert-MockCalled Get-FileHash -Exactly 1
                    }
                }
            }

            Describe 'xRemoteFile\Test-UriScheme' {
                It 'Returns "True" when URI is "http://.." and scheme is "http|https|file"' {
                    Test-UriScheme -Uri $script:testURI -Scheme 'http|https|file' | Should -BeTrue
                }

                It 'Returns "True" when URI is "http://.." and scheme is "http"' {
                    Test-UriScheme -Uri $script:testURI -Scheme 'http' | Should -BeTrue
                }

                It 'Returns "False" when URI is "http://.." and scheme is "https"' {
                    Test-UriScheme -Uri $script:testURI -Scheme 'https' | Should -BeFalse
                }

                It 'Returns "False" when URI is "bad://.." and scheme is "http|https|file"' {
                    Test-UriScheme -Uri 'bad://contoso.com' -Scheme 'http|https|file' | Should -BeFalse
                }
            }

            Describe 'xRemoteFile\Get-PathItemType' {
                It 'Returns "Directory" when Path is a Directory' {
                    Get-PathItemType -Path $script:testDestinationFolder | Should -Be 'Directory'
                }

                It 'Returns "File" when Path is a File' {
                    Get-PathItemType -Path $script:testDestinationFile | Should -Be 'File'
                }

                It 'Returns "NotExists" when Path does not exist' {
                    Get-PathItemType -Path $script:testDestinationNotExist | Should -Be 'NotExists'
                }
                It 'Returns "Other" when Path is not in File System' {
                    Get-PathItemType -Path HKLM:\Software | Should -Be 'Other'
                }
            }

            Describe 'xRemoteFile\Get-Cache' {
                Mock Import-CliXml -MockWith { 'Expected Content' }
                Mock Test-Path -MockWith { $true }

                Context "DestinationPath 'c:\' and Uri $script:testURI and Cached Content exists" {
                    $Result = Get-Cache -DestinationPath 'c:\' -Uri $script:testURI

                    It "Returns Expected Content" {
                        $Result | Should -Be 'Expected Content'
                    }

                    It "Calls expected mocks" {
                        Assert-MockCalled Import-CliXml -Exactly 1
                        Assert-MockCalled Test-Path -Exactly 1
                    }
                }

                Mock Test-Path -MockWith { $false }

                Context "DestinationPath 'c:\' and Uri $script:testURI and Cached Content does not exist" {
                    $Result = Get-Cache -DestinationPath 'c:\' -Uri $script:testURI

                    It 'Returns Null' {
                        $Result | Should -BeNullOrEmpty
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Import-CliXml -Exactly 0
                        Assert-MockCalled Test-Path -Exactly 1
                    }
                }
            }

            Describe 'xRemoteFile\Update-Cache' {
                Mock Export-CliXml
                Mock Test-Path -MockWith { $true }
                Mock New-Item

                Context "DestinationPath 'c:\' and Uri $script:testURI and CacheLocation Exists" {
                    It 'Does Not Throw' {
                        { Update-Cache -DestinationPath 'c:\' -Uri $script:testURI -InputObject @{} } | Should -Not -Throw
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Export-CliXml -Exactly 1
                        Assert-MockCalled Test-Path -Exactly 1
                        Assert-MockCalled New-Item -Exactly 0
                    }
                }

                Mock Test-Path -MockWith { $false }

                Context "DestinationPath 'c:\' and Uri $script:testURI and CacheLocation does not exist" {
                    It 'Does Not Throw' {
                        { Update-Cache -DestinationPath 'c:\' -Uri $script:testURI -InputObject @{} } | Should -Not -Throw
                    }

                    It 'Calls expected mocks' {
                        Assert-MockCalled Export-CliXml -Exactly 1
                        Assert-MockCalled Test-Path -Exactly 1
                        Assert-MockCalled New-Item -Exactly 1
                    }
                }
            }

            Describe 'xRemoteFile\Get-CacheKey' {
                It "Returns -799765921 as Cache Key for DestinationPath 'c:\' and Uri $script:testURI" {
                    Get-CacheKey -DestinationPath 'c:\' -Uri $script:testURI | Should -Be -799765921
                }

                It "Returns 1266535016 as Cache Key for DestinationPath 'c:\Windows\System32' and Uri $script:testURINotExist" {
                    Get-CacheKey -DestinationPath 'c:\Windows\System32' -Uri $script:testURINotExist | Should -Be 1266535016
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}
