<#
    .SYNOPSIS
        The Sample_MetaConfigurationToRegisterWithSecurePullServer registers
        a DSC client node with the pull server.

    .PARAMETER NodeName
        The name of the node being configured as a DSC Pull Server.

    .PARAMETER RegistrationKey
        This key will be used by client nodes as a shared key to authenticate
        during registration. This should be a string with enough entropy
        (randomness) to protect the registration of clients to the pull server.
        The example creates a new GUID for the registration key.

    .PARAMETER ServerName
        The HostName to use when configuring the Pull Server URL on the DSC
        client.

    .PARAMETER Port
        The port on which the PullServer is listening for connections

    .EXAMPLE
        $registrationKey = [System.Guid]::NewGuid()

        Sample_MetaConfigurationToRegisterWithSecurePullServer -RegistrationKey $registrationKey
#>
[DSCLocalConfigurationManager()]
Configuration Sample_MetaConfigurationToRegisterWithSecurePullServer
{
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $NodeName = 'localhost',

        [Parameter()]
        [Parameter(Mandatory = $true)]
        [System.String]
        $RegistrationKey,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName = 'localhost',

        [Parameter()]
        [ValidateRange(1, 65535)]
        [System.UInt16]
        $Port = 8080
    )

    Import-DSCResource -ModuleName 'xPSDesiredStateConfiguration'

    Node $NodeName
    {
        Settings
        {
            RefreshMode = 'Pull'
        }

        ConfigurationRepositoryWeb CONTOSO-PullSrv
        {
            ServerURL          = "https://$ServerName`:$Port/PSDSCPullServer.svc"
            RegistrationKey    = $RegistrationKey
            ConfigurationNames = @('ClientConfig')
        }

        ReportServerWeb CONTOSO-PullSrv
        {
            ServerURL       = "https://$ServerName`:$Port/PSDSCPullServer.svc"
            RegistrationKey = $RegistrationKey
        }
    }
}
