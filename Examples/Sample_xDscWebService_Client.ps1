<#PSScriptInfo
.VERSION 1.0.0
.GUID 119f0689-7410-4b2d-a805-d5df9f582cad
.AUTHOR Microsoft Corporation
.COMPANYNAME Microsoft Corporation
.COPYRIGHT
.TAGS DSCConfiguration
.LICENSEURI https://github.com/PowerShell/xPSDesiredStateConfiguration/blob/master/LICENSE
.PROJECTURI https://github.com/PowerShell/xPSDesiredStateConfiguration
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
#>
<#
    .SYNOPSIS
        The Sample_xDscWebService_Client registers
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

        Sample_xDscWebService_Client -RegistrationKey $registrationKey
#>
[DSCLocalConfigurationManager()]
Configuration Sample_xDscWebService_Client
{
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $NodeName = 'localhost',

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
