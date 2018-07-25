<#PSScriptInfo
.VERSION 1.0.1
.GUID 845b267f-e47e-4305-88b6-d1086e6c1405
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
        Configuration that removes an environment variable.

    .DESCRIPTION
        Configuration that removes an environment variable.

    .PARAMETER Name
        The name of the environment variable to remove.

    .PARAMETER Target
        The scope in which to remove the environment variable. Can be set to
        either the 'Machine', the 'Process' or both. Default value is 'Machine'.
        { Process | Machine }

    .EXAMPLE
        xEnvironment_RemoveVariableConfig -Name 'TestVariable' -Target @('Process', 'Machine')

        Compiles a configuration that removes the environment variable
        'TestVariable' from both the machine and the process scope.

    .EXAMPLE
        $configurationParameters = @{
            Name = 'TestVariable'
            Target = @('Process', 'Machine')
        }
        Start-AzureRmAutomationDscCompilationJob -ResourceGroupName '<resource-group>' -AutomationAccountName '<automation-account>' -ConfigurationName 'xEnvironment_RemoveVariableConfig' -Parameters $configurationParameters

        Compiles a configuration in Azure Automation that removes the environment
        variable 'TestVariable' from both the machine and the process scope.

        Replace the <resource-group> and <automation-account> with correct values.
#>
Configuration xEnvironment_RemoveVariableConfig
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateSet('Process', 'Machine')]
        [System.String[]]
        $Target = 'Machine'
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xEnvironment 'NewVariable'
        {
            Name   = $Name
            Ensure = 'Absent'
            Path   = $false
            Target = $Target
        }
    }
}
