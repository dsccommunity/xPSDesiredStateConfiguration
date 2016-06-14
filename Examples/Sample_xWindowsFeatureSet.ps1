<# 
    .SYNOPSIS
    Installs the set of features named with all their subfeatures from the specified source.
#>
Configuration $configurationName
{
    param (
        [Parameter(Mandatory = $true)]
        [String[]]
        $FeatureNames,
       
        [Parameter(Mandatory = $true)]
        [String]
        $LogPath,
        
        [Parameter(Mandatory = $true)]
        [String]
        $Source 
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    xWindowsFeatureSet WindowsFeatureSet1
    {
        Name = $FeatureNames
        Ensure = "Present"
        IncludeAllSubFeature = $true
        LogPath = $LogPath
        Source = $Source
    }
}
