<#PSScriptInfo
.VERSION 1.0.1
.GUID dafafad2-d581-4db2-841c-7095c5c3ed30
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
        Configuration that creates or modifies an environment variable containing
        paths.

    .DESCRIPTION
        Configuration that creates or modifies an environment variable containing
        paths.
        If the environment variable does not exist, the environment variable is
        created, and the paths will added as values.
        If the environment variable already exist, an either of the new path
        values do not exist in the environment variable, they will be appended
        without modifying any preexisting values. If either of the paths already
        exist as a value in in the environment variable, that path will be
        skipped (it is not added twice).

    .PARAMETER Name
        The name of the environment variable to create or modify.

    .PARAMETER Value
        The paths to add to the environment variable as a comma-separated list,
        e.g. 'C:\test123;C:\test456;C:\test789'.

    .PARAMETER Target
        The scope to set the environment variable. Can be set to either the
        'Machine', the 'Process' or both. Default value is 'Machine'.
        { Process | Machine }

    .EXAMPLE
        xEnvironment_AddMultiplePathsConfig -Name 'TestPath' -Value 'C:\test123;C:\test456;C:\test789' -Target @('Process', 'Machine')

        Compiles a configuration that creates the environment variable
        'TestPath' with the paths 'C:\test123', 'C:\test456' and 'C:\test789'
        in both the scopes 'Machine' and 'Process'.

    .EXAMPLE
        $configurationParameters = @{
            Name = 'TestPath'
            Value = 'C:\test123;C:\test456;C:\test789'
            Target = @('Process', 'Machine')
        }
        Start-AzureRmAutomationDscCompilationJob -ResourceGroupName '<resource-group>' -AutomationAccountName '<automation-account>' -ConfigurationName 'xEnvironment_AddMultiplePathsConfig' -Parameters $configurationParameters

        Compiles a configuration in Azure Automation that creates the environment
        variable 'TestPath' with the paths 'C:\test123', 'C:\test456'
        and 'C:\test789' in both the scopes 'Machine' and 'Process'.

        Replace the <resource-group> and <automation-account> with correct values.
#>
Configuration xEnvironment_AddMultiplePathsConfig
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
        xEnvironment 'AddMultiplePaths'
        {
            Name   = $Name
            Value  = $Value
            Ensure = 'Present'
            Path   = $true
            Target = $Target
        }
    }
}
