<#
    .SYNOPSIS
        Disables the Windows optional features TelnetClient and LegacyComponents and removes all
        files associated with these features.
#>
Configuration Sample_xWindowsOptionalFeatureSet_Disable
{
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    xWindowsOptionalFeatureSet WindowsOptionalFeatureSet1
    {
        Name = @('TelnetClient', 'LegacyComponents')
        Ensure = 'Absent'
        RemoveFilesOnDisable = $true
    }
}
