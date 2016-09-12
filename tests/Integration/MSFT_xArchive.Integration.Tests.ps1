Import-Module "$PSScriptRoot\..\CommonTestHelper.psm1"

$script:testEnvironment = Enter-DscResourceTestEnvironment `
    -DscResourceModuleName 'xPSDesiredStateConfiguration' `
    -DscResourceName 'MSFT_xArchive' `
    -TestType 'Integration'
try
{
    Describe 'xArchive Integration Tests' {
        BeforeAll {
            Import-Module "$PSScriptRoot\..\Unit\MSFT_xArchive.TestHelper.psm1" -Force
            Import-Module "$PSScriptRoot\..\..\DSCResources\CommonResourceHelper.psm1" -Force
        }

        It 'Expand Archive' {
            $configurationName = 'ExpandArchive'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName
            $errorPath = Join-Path -Path $TestDrive -ChildPath 'StdErrorPath.txt'
            $outputPath = Join-Path -Path $TestDrive -ChildPath 'StdOutputPath.txt'
            
            try
            {
            
                New-Item -Path $TestDrive -ItemType 'Directory' -Name 'TestArchive' | Out-Null
                New-Item -Path "$TestDrive/TestArchive" -ItemType 'File' -Name 'testFile.txt' | Out-Null

                Compress-Archive -Path "$TestDrive/TestArchive" -DestinationPath 'testArchive.zip'

                Configuration $configurationName
                {
                    Import-DscResource -ModuleName xPSDesiredStateConfiguration

                    xArchive TestArchive
                    {
                        Path = "$TestDrive/TestArchive/testArchive.zip"
                        Ensure = 'Present'
                        Destination = $TestDrive
                    }
                }
                
                {
                    & $configurationName -OutputPath $configurationPath

                    Start-DscConfiguration -Path $configurationPath -Wait -Force -Verbose
                } | Should Not Throw
                
                #Get-DscConfiguration -Verbose -ErrorAction Stop | Should Not throw

            }
            finally
            {

            }
        }
    }
}
finally
{
    Exit-DscResourceTestEnvironment -TestEnvironment $script:testEnvironment
}
