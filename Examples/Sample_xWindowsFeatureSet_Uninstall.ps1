<#
    .SYNOPSIS
        Uninstalls the TelnetClient and RSAT-File-Services Windows features, including all their
        subfeatures. Logs the operation to the file at 'C:\LogPath\Log.log'.
#>
Configuration Sample_xWindowsFeatureSet_Uninstall
{
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xWindowsFeatureSet WindowsFeatureSet1
        {
            Name                 = @( 'Telnet-Client', 'RSAT-File-Services' )
            Ensure               = 'Absent'
            IncludeAllSubFeature = $true
            LogPath              = 'C:\LogPath\Log.log'
        }
    }
}
