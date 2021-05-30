<#PSScriptInfo
.VERSION 1.0.1
.GUID f7ec2dc4-ee13-4aba-b475-879661bff837
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
.RELEASENOTES First version.
.PRIVATEDATA 2016-Datacenter,2016-Datacenter-Server-Core
#>

#Requires -Module xPSDesiredStateConfiguration

<#
    .DESCRIPTION
        Configuration that creates and registers a new session configuration
        endpoint.

    .PARAMETER Name
        The name of the session configuration.

    .PARAMETER AccessMode
        The access mode for the session configuration. The default value is 'Remote'.

    .EXAMPLE
        xPSEndpoint_NewConfig -Name 'MaintenanceShell'

        Compiles a configuration that creates and registers a new session configuration
        endpoint named 'MaintenanceShell'.

    .EXAMPLE
        xPSEndpoint_New_Config -Name 'MaintenanceShell'

        Compiles a configuration that creates and registers a new session
        configuration endpoint named 'MaintenanceShell'.

    .EXAMPLE
        xPSEndpoint_New_Config -Name 'Microsoft.PowerShell.Workflow' -AccessMode 'Local'

        Compiles a configuration that sets the access mode to 'Local' for the
        endpoint named 'Microsoft.PowerShell.Workflow'.

    .EXAMPLE
        xPSEndpoint_New_Config -Name 'Microsoft.PowerShell.Workflow' -AccessMode 'Disable'

        Compiles a configuration that disables access for the endpoint named
        'Microsoft.PowerShell.Workflow'.
#>
Configuration xPSEndpoint_New_Config
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateSet('Local', 'Remote', 'Disabled')]
        [System.String]
        $AccessMode = 'Remote'
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node 'localhost'
    {
        xPSEndpoint NewEndpoint
        {
            Name       = $Name
            AccessMode = $AccessMode
            Ensure     = 'Present'
        }
    }
}
