Configuration Sample_xService_ServiceWithCredential
{

    param
    (
        [string[]] 
        $nodeName = 'localhost',

        [System.String]
        $Name,
        
        [System.String]
        [ValidateSet("Automatic", "Manual", "Disabled")]
        $StartupType="Automatic",

        [System.String]
        [ValidateSet("LocalSystem", "LocalService", "NetworkService")]
        $BuiltInAccount="LocalSystem",

        [System.Management.Automation.PSCredential]
        $Credential,

        [System.String]
        [ValidateSet("Running", "Stopped")]
        $State="Running",

        [System.String]
        [ValidateSet("Present", "Absent")]
        $Ensure="Present",

        [System.String]
        $Path,

        [System.String]
        $DisplayName,

        [System.String]
        $Description,

        [System.String[]]
        $Dependencies
    )

    Import-DscResource -Name MSFT_xServiceResource -ModuleName xPSDesiredStateConfiguration

    Node $nodeName
    {
        xService service
        {
            Name = $Name
            DisplayName = $DisplayName
            Ensure = $Ensure
            Path = $Path
            StartupType = $StartupType
            Credential = $credential
        }
    }
}

# To use the sample(s) with credentials, see blog at http://blogs.msdn.com/b/powershell/archive/2014/01/31/want-to-secure-credentials-in-windows-powershell-desired-state-configuration.aspx







