$script:testsFolderFilePath = Split-Path $PSScriptRoot -Parent
$script:commonTestHelperFilePath = Join-Path -Path $testsFolderFilePath -ChildPath 'CommonTestHelper.psm1'
Import-Module -Name $commonTestHelperFilePath

$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceFriendlyName = 'xRemoteFile'
$script:dscResourceName = "MSFT_$($script:dscResourceFriendlyName)"

if (Test-SkipContinuousIntegrationTask -Type 'Unit')
{
    return
}

#region HEADER
# Unit Test Template Version: 1.1.0
[System.String] $moduleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))
if ( (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone', 'https://github.com/PowerShell/DscResource.Tests.git', (Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:dscModuleName `
    -DSCResourceName $script:dscResourceName `
    -TestType Unit
#endregion HEADER

# Begin Testing
try
{
    InModuleScope $script:dscResourceName {
        function Get-InvalidDataException
        {
            param(
                [parameter(Mandatory = $true)]
                [System.String]
                $errorId,

                [parameter(Mandatory = $true)]
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

        try
        {
            # Create a working folder that all files will be created in
            $script:workingFolder = Join-Path -Path $ENV:Temp -ChildPath 'xRemoteFile.Temp'
            if (-not (Test-Path -Path $script:workingFolder))
            {
                $null = New-Item -Path $script:workingFolder -ItemType Directory
            }

            #region Pester Tests
            $testURIFile = 'test.xml'
            $testURI = "http://contoso.com/$testURIFile"
            $testURIFileNotExist = 'testnotexist.xml'
            $testURINotExist = "http://contoso.com/$testURIFileNotExist"

            $testDestinationFolder = Join-Path `
                -Path $script:workingFolder -ChildPath 'UnitTest_Folder'
            $testDestinationFolderFile = Join-Path `
                -Path $testDestinationFolder -ChildPath $testURIFile
            $testDestinationFile = Join-Path `
                -Path $script:workingFolder -ChildPath 'UnitTest_File.xml'
            $testDestinationNotExist = Join-Path `
                -Path $script:workingFolder -ChildPath 'UnitTest_NotExist'

            # Create the splats
            $testSplatFile = @{
                DestinationPath = $testDestinationFile;
                Uri = $testURI;
            }
            $testSplatFolderFileExists = @{
                DestinationPath = $testDestinationFolder;
                Uri = $testURI;
            }
            $testSplatFolderFileNotExist = @{
                DestinationPath = $testDestinationFolder;
                Uri = $testURINotExist;
            }

            # Create the test files/folders by clearing the working folder
            # if it exists and building a set of expected test files
            if (Test-Path -Path $script:workingFolder)
            {
                $null = Remove-Item -Path $script:workingFolder -Force -Recurse
            }
            $null = New-Item -Path $testDestinationFolder -ItemType Directory
            $null = Set-Content -Path $testDestinationFile -Value 'Dummy Content'
            $null = Set-Content -Path $testDestinationFolderFile -Value 'Dummy Content'

            Describe "$($script:dscResourceName)\Get-TargetResource" {
                $result = Get-TargetResource @testSplatFile
                It 'Returns "Present" when DestinationPath is a File and exists' {
                    $Result.Ensure | Should -Be 'Present'
                }

                $result = Get-TargetResource @testSplatFolderFileExists
                It 'Returns "Present" when DestinationPath is a Directory and exists and URI file exists' {
                    $Result.Ensure | Should -Be 'Present'
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
            } #end Describe "$($script:dscResourceName)\Get-TargetResource"

            Describe "$($script:dscResourceName)\Set-TargetResource" {
                Context 'URI is "bad://.."' {
                    It 'Throws a UriValidationFailure exeception' {
                        $splat = $testSplatFile.Clone()
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
                        $splat = $testSplatFile.Clone()
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
                        $splat = $testSplatFile.Clone()
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
                        $splat = $testSplatFile.Clone()
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
                        $splat = $testSplatFile.Clone()
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
            } #end Describe "$($script:dscResourceName)\Set-TargetResource"

            Describe "$($script:dscResourceName)\Test-TargetResource" {
                Mock Get-Cache
                Context 'URI is valid, DestinationPath is a File, file exists' {
                    It 'Returns "False"' {
                        Test-TargetResource @testSplatFile | Should -Be $False
                    }
                    It 'Calls expected mocks' {
                        Assert-MockCalled Get-Cache -Exactly 1
                    }
                }
                Context 'URI is valid, DestinationPath is a File, file exists, matchsource is "False"' {
                    It 'Returns "True"' {
                        $splat = $testSplatFile.Clone()
                        $splat.MatchSource = $False
                        Test-TargetResource @splat | Should -Be $True
                    }
                    It 'Calls expected mocks' {
                        Assert-MockCalled Get-Cache -Exactly 0
                    }
                }
                Context 'URI is valid, DestinationPath is a Folder, file exists' {
                    It 'Returns "False"' {
                        Test-TargetResource @testSplatFolderFileExists | Should -Be $False
                    }
                    It 'Calls expected mocks' {
                        Assert-MockCalled Get-Cache -Exactly 1
                    }
                }
                Context 'URI is valid, DestinationPath is a Folder, file exists, matchsource is "False"' {
                    It 'Returns "True"' {
                        $splat = $testSplatFolderFileExists.Clone()
                        $splat.MatchSource = $False
                        Test-TargetResource @splat | Should -Be $True
                    }
                    It 'Calls expected mocks' {
                        Assert-MockCalled Get-Cache -Exactly 0
                    }
                }
                Context 'URI is valid, DestinationPath is a Folder, file does not exist' {
                    It 'Returns "False"' {
                        Test-TargetResource @testSplatFolderFileNotExist | Should -Be $False
                    }
                    It 'Calls expected mocks' {
                        Assert-MockCalled Get-Cache -Exactly 0
                    }
                }
                Context 'URI is valid, DestinationPath is a Folder, file exists, matchsource is "False"' {
                    It 'Returns "False"' {
                        $splat = $testSplatFolderFileNotExist.Clone()
                        $splat.MatchSource = $False
                        Test-TargetResource @splat | Should -Be $False
                    }
                    It 'Calls expected mocks' {
                        Assert-MockCalled Get-Cache -Exactly 0
                    }
                }

            } #end Describe "$($script:dscResourceName)\Test-TargetResource"

            Describe "$($script:dscResourceName)\Test-UriScheme" {
                It 'Returns "True" when URI is "http://.." and scheme is "http|https|file"' {
                    Test-UriScheme -Uri $testURI -Scheme 'http|https|file' | Should -Be $true
                }
                It 'Returns "True" when URI is "http://.." and scheme is "http"' {
                    Test-UriScheme -Uri $testURI -Scheme 'http' | Should -Be $true
                }
                It 'Returns "False" when URI is "http://.." and scheme is "https"' {
                    Test-UriScheme -Uri $testURI -Scheme 'https' | Should -Be $false
                }
                It 'Returns "False" when URI is "bad://.." and scheme is "http|https|file"' {
                    Test-UriScheme -Uri 'bad://contoso.com' -Scheme 'http|https|file' | Should -Be $false
                }
            } #end Describe "$($script:dscResourceName)\Test-UriScheme"

            Describe "$($script:dscResourceName)\Get-PathItemType" {
                It 'Returns "Directory" when Path is a Directory' {
                    Get-PathItemType -Path $testDestinationFolder | Should -Be 'Directory'
                }
                It 'Returns "File" when Path is a File' {
                    Get-PathItemType -Path $testDestinationFile | Should -Be 'File'
                }
                It 'Returns "NotExists" when Path does not exist' {
                    Get-PathItemType -Path $testDestinationNotExist | Should -Be 'NotExists'
                }
                It 'Returns "Other" when Path is not in File System' {
                    Get-PathItemType -Path HKLM:\Software | Should -Be 'Other'
                }
            } #end Describe "$($script:dscResourceName)\Get-PathItemType"

            Describe "$($script:dscResourceName)\Get-Cache" {
                Mock Import-CliXml -MockWith { 'Expected Content' }
                Mock Test-Path -MockWith { $True }
                Context "DestinationPath 'c:\' and Uri $testURI and Cached Content exists" {
                    $Result = Get-Cache -DestinationPath 'c:\' -Uri $testURI
                    It "Returns Expected Content" {
                        $Result | Should -Be 'Expected Content'
                    }
                    It "Calls expected mocks" {
                        Assert-MockCalled Import-CliXml -Exactly 1
                        Assert-MockCalled Test-Path -Exactly 1
                    }
                }
                Mock Test-Path -MockWith { $False }
                Context "DestinationPath 'c:\' and Uri $testURI and Cached Content does not exist" {
                    $Result = Get-Cache -DestinationPath 'c:\' -Uri $testURI
                    It "Returns Null" {
                        $Result | Should -BeNullOrEmpty
                    }
                    It "Calls expected mocks" {
                        Assert-MockCalled Import-CliXml -Exactly 0
                        Assert-MockCalled Test-Path -Exactly 1
                    }
                }
            } #end Describe "$($script:dscResourceName)\Get-Cache"

            Describe "$($script:dscResourceName)\Update-Cache" {
                Mock Export-CliXml
                Mock Test-Path -MockWith { $True }
                Mock New-Item
                Context "DestinationPath 'c:\' and Uri $testURI and CacheLocation Exists" {
                    It "Does Not Throw" {
                        { Update-Cache -DestinationPath 'c:\' -Uri $testURI -InputObject @{} } | Should -Not -Throw
                    }
                    It "Calls expected mocks" {
                        Assert-MockCalled Export-CliXml -Exactly 1
                        Assert-MockCalled Test-Path -Exactly 1
                        Assert-MockCalled New-Item -Exactly 0
                    }
                }
                Mock Test-Path -MockWith { $False }
                Context "DestinationPath 'c:\' and Uri $testURI and CacheLocation does not exist" {
                    It "Does Not Throw" {
                        { Update-Cache -DestinationPath 'c:\' -Uri $testURI -InputObject @{} } | Should -Not -Throw
                    }
                    It "Calls expected mocks" {
                        Assert-MockCalled Export-CliXml -Exactly 1
                        Assert-MockCalled Test-Path -Exactly 1
                        Assert-MockCalled New-Item -Exactly 1
                    }
                }
            } #end Describe "$($script:dscResourceName)\Update-Cache"

            Describe "$($script:dscResourceName)\Get-CacheKey" {
                It "Returns -799765921 as Cache Key for DestinationPath 'c:\' and Uri $testURI" {
                    Get-CacheKey -DestinationPath 'c:\' -Uri $testURI | Should -Be -799765921
                }
                It "Returns 1266535016 as Cache Key for DestinationPath 'c:\Windows\System32' and Uri $testURINotExist" {
                    Get-CacheKey -DestinationPath 'c:\Windows\System32' -Uri $testURINotExist | Should -Be 1266535016
                }
            } #end Describe "$($script:dscResourceName)\Get-CacheKey"
        }
        finally
        {
            # Clean up the working folder
            $null = Remove-Item -Path $script:workingFolder -Force -Recurse
        }
    }
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}
