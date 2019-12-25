<#PSScriptInfo
.VERSION 1.0.1
.GUID d8734507-59a8-4ad4-9716-7eb52362aee2
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
        Configuration that starts one or more services.

    .DESCRIPTION
        Configuration that starts one or more services.

    .PARAMETER Name
        The name of one or more the Windows services to start.

    .EXAMPLE
        xServiceSet_StartServicesConfig -Name @('Dhcp', 'MpsSvc')

        Compiles a configuration that ensures that the DHCP Client and
        Windows Firewall services are running.

    .EXAMPLE
        Start-AzureRmAutomationDscCompilationJob -ResourceGroupName '<resource-group>' -AutomationAccountName '<automation-account>' -ConfigurationName 'xServiceSet_StartServicesConfig' -Parameters @{ Name = @('Dhcp', 'MpsSvc') }

        Compiles a configuration in Azure Automation that ensures that the
        DHCP Client and Windows Firewall services are running.

        Replace the <resource-group> and <automation-account> with correct values.
#>
Configuration xServiceSet_StartServicesConfig
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String[]]
        $Name
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xServiceSet 'StartServices'
        {
            Name   = $Name
            Ensure = 'Present'
            State  = 'Running'
        }
    }
}
