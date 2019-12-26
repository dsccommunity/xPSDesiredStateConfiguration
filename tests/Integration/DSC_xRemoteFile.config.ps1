$TestConfigPath = Join-Path -Path $PSScriptRoot -ChildPath "DSC_xRemoteFile.config.ps1"
$TestURI = "file://$TestConfigPath"
$TestDestinationPath = Join-Path -Path $ENV:Temp -ChildPath "DSC_xRemoteFile.config.ps1"

# Integration Test Config Template Version: 1.0.0
configuration DSC_xRemoteFile_config {
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    node localhost {
        xRemoteFile Integration_Test {
            DestinationPath = $TestDestinationPath
            Uri = $TestURI
        }
    }
}
