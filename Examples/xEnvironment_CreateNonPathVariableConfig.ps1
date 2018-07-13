<#PSScriptInfo
.VERSION 1.0.1
.GUID ee586cfa-237c-4e5f-929e-9b420afabc91
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
        Configuration that creates or modifies an environment variable.

    .DESCRIPTION
        Configuration that creates or modifies an environment variable.
        If the environment variable does not exist, the environment variable is
        created, and the value will be added.
        If the environment variable already exist, and the value differs, then
        the value will be changed.

    .PARAMETER Name
        The name of the environment variable to create or modify.

    .PARAMETER Value
        The value to set on the environment variable.

    .PARAMETER Target
        The scope to set the environment variable. Can be set to either the
        'Machine', the 'Process' or both. Default value is 'Machine'.
        { Process | Machine }

    .EXAMPLE
        xEnvironment_CreateNonPathVariableConfig -Name 'TestVariable' -Value 'TestValue' -Target @('Process', 'Machine')

        Compiles a configuration that creates the environment variable
        'TestVariable' and sets the value to 'TestValue' both on the machine
        scope and within the process scope.

    .EXAMPLE
        $configurationParameters = @{
            Name = 'TestVariable'
            Value = 'TestValue'
            Target = @('Process', 'Machine')
        }
        Start-AzureRmAutomationDscCompilationJob -ResourceGroupName '<resource-group>' -AutomationAccountName '<automation-account>' -ConfigurationName 'xEnvironment_CreateNonPathVariableConfig' -Parameters $configurationParameters

        Compiles a configuration in Azure Automation that creates the environment
        variable 'TestVariable' and sets the value to 'TestValue' both on the
        machine scope and within the process scope.

        Replace the <resource-group> and <automation-account> with correct values.
#>
Configuration xEnvironment_CreateNonPathVariableConfig
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Value,

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
            Value  = $Value
            Ensure = 'Present'
            Path   = $false
            Target = $Target
        }
    }
}
