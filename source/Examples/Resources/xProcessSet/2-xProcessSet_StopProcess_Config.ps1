<#PSScriptInfo
.VERSION 1.0.1
.GUID 215fd763-50ac-4b04-94cd-b125d6ba86d0
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
        Configuration that stop one or more processes. Logs any output to the
        path 'C:\Output.log'.

    .PARAMETER Path
        One or more paths to the executable to stop the process for.

    .EXAMPLE
        xProcessSet_StopProcess_Config -Path @('C:\Windows\System32\cmd.exe', 'C:\TestPath\TestProcess.exe')

        Compiles a configuration that stops the processes with the executable
        at the file paths 'C:\Windows\cmd.exe' and 'C:\TestPath\TestProcess.exe'.

    .EXAMPLE
        Start-AzureRmAutomationDscCompilationJob -ResourceGroupName '<resource-group>' -AutomationAccountName '<automation-account>' -ConfigurationName 'xProcessSet_StopProcessConfig' -Parameters @{ Path = @('C:\Windows\System32\cmd.exe', 'C:\TestPath\TestProcess.exe') }

        Compiles a configuration in Azure Automation that stop the processes
        with the executable at the file paths 'C:\Windows\cmd.exe'
        and 'C:\TestPath\TestProcess.exe'.

        Replace the <resource-group> and <automation-account> with correct values.
#>
Configuration xProcessSet_StopProcess_Config
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String[]]
        $Path
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xProcessSet StartProcess
        {
            Path = $Path
            Ensure = 'Absent'
            StandardOutputPath = 'C:\Output.log'
        }
    }
}
