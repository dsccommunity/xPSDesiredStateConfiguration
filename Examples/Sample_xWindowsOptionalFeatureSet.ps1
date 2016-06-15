# Installs the Windows optional features 'MicrosoftWindowsPowerShellV2' and 'Internet-Explorer-Optional-amd64'

Configuration xWindowsOptionalFeatureSetExample
{
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $LogPath
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    xWindowsOptionalFeatureSet WindowsOptionalFeatureSet1
    {
        Name = @('MicrosoftWindowsPowerShellV2', 'Internet-Explorer-Optional-amd64')
        Ensure = 'Present'
        LogPath = $LogPath
    }
}
