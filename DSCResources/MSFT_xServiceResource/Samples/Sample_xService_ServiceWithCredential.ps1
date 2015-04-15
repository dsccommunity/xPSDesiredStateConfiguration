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

$Config = @{
    Allnodes = @(
                    @{
                        Nodename = "localhost"
                        PSDSCAllowPlainTextPassword = $true
                    }
                )
}
#Sample Scenarios

$credential = Get-Credential

Sample_xService_ServiceWithCredential -ConfigurationData $Config -Name "Sample Service" -DisplayName "Sample Display Name" -Ensure "Present" -Path "C:\DSC\TestService.exe" -StartupType Automatic -Credential $credential




