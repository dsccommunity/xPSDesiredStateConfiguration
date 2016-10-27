param 
(
    [Parameter(Mandatory)]
    [System.String]
    $ConfigurationName
)

<#
    Create a custom configuration by passing in whatever values you need. 
    $Name is the only parameter that is required which indicates which
    Windows Feature you want to install (or uninstall if you set Ensure to Absent).
    LogPath is not included here, but if you would like to specify a custom log path
    just pass in that value and add LogPath = $LogPath to the configuration here
#>      

Configuration $ConfigurationName
{
    param 
    (   
        [Parameter(Mandatory = $true)]     
        [System.String]
        $Name,

        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [System.Boolean]
        $IncludeAllSubFeature = $false,

        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [ValidateNotNullOrEmpty()]
        [System.String]
        $LogPath
    )
    
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'
    
    Node Localhost {

        xWindowsFeature WindowsFeatureTest
        {
            Name = $Name
            Ensure = $Ensure
            IncludeAllSubFeature = $IncludeAllSubFeature
            Credential = $Credential
        }
    }
}

