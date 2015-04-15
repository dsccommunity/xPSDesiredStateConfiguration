Configuration Sample_xService_DeleteService
{

    param
    (
        [string[]] 
        $nodeName = 'localhost',

        [System.String]
        $Name,
        
        [System.String]
        [ValidateSet("Automatic", "Manual", "Disabled")]
        $StartupType,

        [System.String]
        [ValidateSet("LocalSystem", "LocalService", "NetworkService")]
        $BuiltInAccount,

        [System.Management.Automation.PSCredential]
        $Credential ,

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
            Ensure = $Ensure
        }
    }
}


Sample_xService_DeleteService -Name "Sample Service" -Ensure "Absent" 


