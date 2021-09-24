<#PSScriptInfo
.VERSION 1.0.1
.GUID 73eb39e7-fdc0-4dae-af0e-0c1458d3c8c8
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
        Configuration that stops the process under the given credential, that is
        provided in the given file path, where the argument matches, and if the
        process is running.

    .PARAMETER FilePath
        The path to the executable file to (process) to stop.

    .PARAMETER Argument
        The arguments for the process to stop. Defaults to no argument.

    .PARAMETER Credential
        Credential that the process is running under.

    .NOTES
        The FilePath could be set to just the process name only if the number of
        returned processed is less than or equal to 8. If more than 8 processes
        are returned, another filter is used to optimize performance, and that
        filter needs the full path to the executable file.

        To use the sample(s) with credentials, see blog at:
        http://blogs.msdn.com/b/powershell/archive/2014/01/31/want-to-secure-credentials-in-windows-powershell-desired-state-configuration.aspx

    .EXAMPLE
        xWindowsProcess_StopProcessUnderUser_Config -FilePath 'C:\WINDOWS\system32\PING.EXE' -Argument '-t localhost' -Credential (Get-Credential)

        Compiles a configuration that stops a 'ping' process under the given
        credential, if the process exist.
#>
Configuration xWindowsProcess_StopProcessUnderUser_Config
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
        $Argument,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xWindowsProcess StopProcess
        {
            Path       = $FilePath
            Arguments  = $Argument
            Credential = $Credential
            Ensure     = 'Absent'
        }
    }
}


