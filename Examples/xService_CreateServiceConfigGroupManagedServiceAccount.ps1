<#PSScriptInfo
.VERSION 1.0.0
.GUID 9c377df3-c4d5-4cbd-b631-78e320bdcdd9
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
.RELEASENOTES First version.
.PRIVATEDATA 2016-Datacenter,2016-Datacenter-Server-Core
#>

#Requires -module @{ModuleName = 'xPSDesiredStateConfiguration';ModuleVersion = '8.2.0.0'}

<#
    .SYNOPSIS
        Configuration that creates a new Windows service from an executable
        and uses a Group Managed Service Account to start the service.

    .DESCRIPTION
        Configuration that creates a new Windows service from an executable.
        The executable must be built to run as a Windows service.

    .PARAMETER Path
        The path to the executable for the Windows service.

    .PARAMETER Name
        The name of the Windows service to be created.

    .PARAMETER GroupManagedServiceAccount
        The name of the GroupManagedServiceAccount to run the service.

    .EXAMPLE
        $gmsaSplat = @{
            Path                        = 'C:\FilePath\MyServiceExecutable.exe'
            Name                        = 'Service1'
            GroupManagedServiceAccount  = 'DOMAIN\gMSA$'
        }

        xService_CreateServiceConfigGroupManagedServiceAccount @gmsaSplat

        Compiles a configuration that creates a new service with the name Service1
        using the executable path 'C:\FilePath\MyServiceExecutable.exe'.
        If the service with the name Service1 already exists and the executable
        path is different, then the executable will be changed for the service.
        The service is started by default if it is not running already. The user
        DOMAIN\gMSA$ is used to start the service, the username could also be provided
        in UPN format (gMSA$@domain.fqdn).
#>
Configuration xService_CreateServiceConfigGroupManagedServiceAccount
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $GroupManagedServiceAccount
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xService 'CreateService'
        {
            Name                        = $Name
            Ensure                      = 'Present'
            Path                        = $Path
            GroupManagedServiceAccount  = $GroupManagedServiceAccount
        }
    }
}
