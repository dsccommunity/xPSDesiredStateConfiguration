<#PSScriptInfo
.VERSION 1.0.0
.GUID 119f0689-7410-4b2d-a805-d5df9f582cad
.AUTHOR Microsoft Corporation
.COMPANYNAME Microsoft Corporation
.COPYRIGHT
.TAGS DSCConfiguration
.LICENSEURI https://github.com/dsccommunity/xPSDesiredStateConfiguration/blob/main/LICENSE
.PROJECTURI https://github.com/dsccommunity/xPSDesiredStateConfiguration
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
#>

<#
    .DESCRIPTION
        This meta configuration configures the LCM to registers a node with the
        pull server.

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

        LCM_RegisterNode_Config -RegistrationKey $registrationKey
#>
[DSCLocalConfigurationManager()]
Configuration LCM_RegisterNode_Config
{
    param
    (
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

    Node localhost
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
