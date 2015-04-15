Configuration Sample_xService_CreateService
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
            Ensure = $Ensure
            Path = $Path
        }
    }
}


Sample_xService_CreateService -Name "Sample Service" -Ensure "Present" -Path "C:\DSC\TestService.exe"






