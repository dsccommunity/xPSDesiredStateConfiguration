$TestConfigPath = Join-Path -Path $ENV:Temp -ChildPath "xRemoteFileChecksumTest.txt"
"hashtest" | Out-File -FilePath $testConfigPath
$TestURI = "file://$TestConfigPath"
$TestDestinationPath = Join-Path -Path $ENV:Temp -ChildPath "FinalDestination.txt"
$TestChecksumType = 'MD5'
$TestChecksum = '31C1D431BBEB65E66113A8EBB06630DC'


# Integration Test Config Template Version: 1.0.0
Configuration MSFT_xRemoteFile_WithChecksum_config {
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'
    node localhost {
        xRemoteFile Integration_Test {
            DestinationPath = $TestDestinationPath
            Uri             = $TestURI
            ChecksumType    = $TestChecksumType
            Checksum        = $TestChecksum
        }
    }
}
