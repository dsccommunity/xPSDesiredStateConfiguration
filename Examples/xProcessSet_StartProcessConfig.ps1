<#PSScriptInfo
.VERSION 1.0.1
.GUID c95c81b4-0e63-495c-8bc0-4a106931c463
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
        Configuration that starts one or more processes.

    .DESCRIPTION
        Configuration that starts one or more processes, without any arguments.

    .PARAMETER Path
        One or more paths to the executable to start a process for.

    .EXAMPLE
        xProcessSet_StartProcessConfig -Path @('C:\Windows\System32\cmd.exe', 'C:\TestPath\TestProcess.exe')

        Compiles a configuration that starts the processes with the executable
        with no arguments at the file paths 'C:\Windows\cmd.exe' and
        'C:\TestPath\TestProcess.exe'.

    .EXAMPLE
        Start-AzureRmAutomationDscCompilationJob -ResourceGroupName '<resource-group>' -AutomationAccountName '<automation-account>' -ConfigurationName 'xProcessSet_StartProcessConfig' -Parameters @{ Path = @('C:\Windows\System32\cmd.exe', 'C:\TestPath\TestProcess.exe') }

        Compiles a configuration in Azure Automation that starts the processes
        with the executable with no arguments at the file paths 'C:\Windows\cmd.exe'
        and 'C:\TestPath\TestProcess.exe'.

        Replace the <resource-group> and <automation-account> with correct values.
#>
Configuration xProcessSet_StartProcessConfig
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String[]]
        $Path
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xProcessSet 'StartProcess'
        {
            Path = $Path
            Ensure = 'Present'
        }
    }
}
