<#PSScriptInfo
.VERSION 1.0.1
.GUID c24aa186-1765-4d8a-9204-14624e7b7f8a
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
        Configuration that modifies an environment variable containing paths.

    .DESCRIPTION
        Configuration that removes one or more path values, if the values exist,
        from and environment variable containing paths. Other values of the
        environment variable will not be modified and will be left intact.

    .PARAMETER Name
        The name of the environment variable to modify.

    .PARAMETER Value
        The paths to remove from the environment variable as a comma-separated
        list, e.g. 'C:\test123;C:\test456'.

    .PARAMETER Target
        The scope in which to modify the environment variable. Can be set to
        either the 'Machine', the 'Process' or both. Default value is 'Machine'.
        { Process | Machine }

    .EXAMPLE
        xEnvironment_RemoveMultiplePathsConfig -Name 'TestPath' -Value 'C:\test456;C:\test123' -Target @('Process', 'Machine')

        Compiles a configuration that removes the paths 'C:\test123' and
        'C:\test456', if the values exist, from the environment variable 'TestPath'
        in both the scopes 'Machine' and 'Process'.
        Other values of the environment variable 'TestPath' will not be modified,
        and will be left intact.

    .EXAMPLE
        $configurationParameters = @{
            Name = 'TestPath'
            Value = 'C:\test456;C:\test123'
            Target = @('Process', 'Machine')
        }
        Start-AzureRmAutomationDscCompilationJob -ResourceGroupName '<resource-group>' -AutomationAccountName '<automation-account>' -ConfigurationName 'xEnvironment_RemoveMultiplePathsConfig' -Parameters $configurationParameters

        Compiles a configuration in Azure Automation that removes the paths
        'C:\test123' and 'C:\test456', if the values exist, from the environment
        variable 'TestPath' in both the scopes 'Machine' and 'Process'.
        Other values of the environment variable 'TestPath' will not be modified,
        and will be left intact.

        Replace the <resource-group> and <automation-account> with correct values.
#>
Configuration xEnvironment_RemoveMultiplePathsConfig
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
        xEnvironment 'RemoveMultiplePaths'
        {
            Name   = $Name
            Value  = $Value
            Ensure = 'Absent'
            Path   = $true
            Target = $Target
        }
    }
}
