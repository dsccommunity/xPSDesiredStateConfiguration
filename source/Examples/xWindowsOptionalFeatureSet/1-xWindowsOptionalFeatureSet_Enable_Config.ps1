<#PSScriptInfo
.VERSION 1.0.1
.GUID a2793140-4351-4310-8062-edb2af9f4429
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
        Enables one or more Windows optional features with the specified name and
        outputs a log to the specified path.

    .PARAMETER Name
        The name of one or more Windows optional features to enable.

    .PARAMETER LogPath
        The path to the file to log the enable operation to.

    .NOTES
        Can only be run on Windows client operating systems and Windows Server 2012 or later.
        The DISM PowerShell module must be available on the target machine.

    .EXAMPLE
        xWindowsOptionalFeatureSet_Enable_Config -Name @('MicrosoftWindowsPowerShellV2', 'Internet-Explorer-Optional-amd64') -LogPath 'c:\log\feature.log'

        Compiles a configuration that enables the Windows optional features
        MicrosoftWindowsPowerShellV2 and Internet-Explorer-Optional-amd64 and
        outputs a log of the operations to a file at the path 'C:\LogPath\Log.txt'.

    .EXAMPLE
        Start-AzureRmAutomationDscCompilationJob -ResourceGroupName '<resource-group>' -AutomationAccountName '<automation-account>' -ConfigurationName 'xWindowsOptionalFeatureSet_EnableConfig' -Parameters @{ Name = @('MicrosoftWindowsPowerShellV2', 'Internet-Explorer-Optional-amd64'); LogPath = 'c:\log\feature.log' }

        Compiles a configuration in Azure Automation that that enables the
        Windows optional features MicrosoftWindowsPowerShellV2 and
        Internet-Explorer-Optional-amd64 and outputs a log of the operations to
        a file at the path 'C:\LogPath\Log.txt'.

        Replace the <resource-group> and <automation-account> with correct values.
#>
Configuration xWindowsOptionalFeatureSet_Enable_Config
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String[]]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $LogPath
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xWindowsOptionalFeatureSet WindowsOptionalFeatureSet1
        {
            Name    = $Name
            Ensure  = 'Present'
            LogPath = $LogPath
        }
    }
}
