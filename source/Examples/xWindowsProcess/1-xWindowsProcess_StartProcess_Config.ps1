<#PSScriptInfo
.VERSION 1.0.1
.GUID 675c8d2d-f3b8-4715-a831-92591becd725
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
        Configuration that starts a process that is provided in the given file
        path with the specified arguments.

    .PARAMETER FilePath
        The path to the executable file to start.

    .PARAMETER Argument
        The arguments for the process to start. Defaults to no argument.

    .EXAMPLE
        xWindowsProcess_StartProcess_Config -FilePath 'C:\WINDOWS\system32\PING.EXE' -Argument '-t localhost'

        Compiles a configuration that starts a process that continuously ping
        localhost, and monitors that the process 'ping' is always started.
#>
Configuration xWindowsProcess_StartProcess_Config
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $FilePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Argument
    )

    Import-DSCResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xWindowsProcess StartProcess
        {
            Path      = $FilePath
            Arguments = $Argument
            Ensure    = 'Present'
        }
    }
}
