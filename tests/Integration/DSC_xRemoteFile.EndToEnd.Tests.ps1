$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'DSC_xRemoteFile'

try
{
    Import-Module -Name DscResource.Test -Force
}
catch [System.IO.FileNotFoundException]
{
    throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -Tasks build" first.'
}

# This contains both tests of *-TargetResource functions and DSC tests
$script:testEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:dscModuleName `
    -DSCResourceName $script:dscResourceName `
    -ResourceType 'Mof' `
    -TestType 'All'

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\CommonTestHelper.psm1')

# Begin Testing
try
{
    InModuleScope $script:dscResourceName {
        Describe 'xRemoteFile End to End Tests' {
            BeforeAll {
                $script:confgurationDownloadFile = Join-Path -Path $PSScriptRoot -ChildPath 'DSC_xRemoteFile_DownloadFile.config.ps1'
                $script:confgurationDownloadFileWithChecksum = Join-Path -Path $PSScriptRoot -ChildPath 'DSC_xRemoteFile_DownloadFileWithChecksum.config.ps1'

                $script:testSourcePath = Join-Path -Path $TestDrive -ChildPath 'xRemoteFile.txt'
                "hashtest" | Out-File -FilePath $script:testSourcePath
                $script:testUri = "file://$script:testSourcePath"
                $script:testChecksumType = 'MD5'
                $script:testChecksum = '31C1D431BBEB65E66113A8EBB06630DC'
            }

            Context 'Download a remote file' {
                $configurationName = 'DownloadFile'
                $testDestinationPath = Join-Path -Path $TestDrive -ChildPath 'xRemoteFileDestination1.txt'
                $remoteFileParameters = @{
                    DestinationPath = $testDestinationPath
                    URI = $script:testURI
                }

                It 'Should compile and run configuration' {
                    {
                        . $script:confgurationDownloadFile -ConfigurationName $configurationName
                            $script:testDestinationPath = Join-Path -Path $TestDrive -ChildPath 'xRemoteFileDestination1.txt'

                        & $configurationName -OutputPath $TestDrive @remoteFileParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Should have set the resource and all the parameters should match' {
                    $Result = Get-DscConfiguration
                    $Result.Ensure          | Should -Be 'Present'
                    $Result.Uri             | Should -Be $script:testUri
                    $Result.DestinationPath | Should -Be $testDestinationPath
                }

                It 'The downloaded content should match the source content' {
                    $DownloadedContent = Get-Content -Path $testDestinationPath -Raw
                    $ExistingContent = Get-Content -Path $script:testSourcePath -Raw
                    $DownloadedContent | Should -Be $ExistingContent
                }
            }

            Context 'Download a remote file with checksum' {
                $configurationName = 'DownloadFileWithChecksum'
                $testDestinationPath = Join-Path -Path $TestDrive -ChildPath 'xRemoteFileDestination2.txt'
                $remoteFileParameters = @{
                    DestinationPath = $testDestinationPath
                    URI = $script:testURI
                    ChecksumType = 'MD5'
                    Checksum = $script:testChecksum
                }

                It 'Should compile and run configuration' {
                    {
                        . $script:confgurationDownloadFileWithChecksum -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @remoteFileParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                    } | Should -Not -Throw
                }

                It 'Should have set the resource and all the parameters should match' {
                    $Result = Get-DscConfiguration
                    $Result.Ensure          | Should -Be 'Present'
                    $Result.Uri             | Should -Be $script:testUri
                    $Result.DestinationPath | Should -Be $testDestinationPath
                    $Result.Checksum        | Should -Be $script:testChecksum
                }

                It 'The downloaded content should match the source content' {
                    $DownloadedContent = Get-Content -Path $testDestinationPath -Raw
                    $ExistingContent = Get-Content -Path $script:testSourcePath -Raw
                    $DownloadedContent | Should -Be $ExistingContent
                }
            }
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
