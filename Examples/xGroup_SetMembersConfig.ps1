<#PSScriptInfo
.VERSION 1.0.1
.GUID 8662bf80-5818-463b-8954-daf8a79525e7
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
        Configuration that make sure a group exist and have the correct members.

    .DESCRIPTION
        Configuration that make sure a group exist and have the correct members.

        If the group does not exist, adds the users and make sure the members of
        the group are only those that are in the configuration. If the group
        already exists and if there are any members not in the configuration,
        those members will be removed from the group, and any missing members
        that are in the configuration will be added to the group.

    .PARAMETER Name
        The name of the group to create or/and add members to.

    .PARAMETER Members
        One or more usernames of the users that should be the only members of the
        group.

    .EXAMPLE
        xGroup_SetMembersConfig -Name 'GroupName1' -Members @('Username1', 'Username2')

        Compiles a configuration that creates the group 'GroupName1, if it does
        not already exist, and adds the users with the usernames 'Username1'
        and 'Username2' to the group. If the group named GroupName1 already
        exists, removes any users that do not have the usernames Username1 or
        Username2 from the group and adds the users that have the usernames
        Username1 and Username2 to the group.

    .EXAMPLE
        Start-AzureRmAutomationDscCompilationJob -ResourceGroupName '<resource-group>' -AutomationAccountName '<automation-account>' -ConfigurationName 'xGroup_SetMembersConfig' -Parameters @{ Name = 'GroupName1'; Members = @('Username1', 'Username2') }

        Compiles a configuration in Azure Automation that creates the group
        'GroupName1, if it does not already exist, and adds the users with the
        usernames 'Username1' and 'Username2' to the group.
        If the group named GroupName1 already exists, removes any users that do
        not have the usernames Username1 or Username2 from the group and adds
        the users that have the usernames Username1 and Username2 to the group.

        Replace the <resource-group> and <automation-account> with correct values.
#>
Configuration xGroup_SetMembersConfig
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [System.String[]]
        $Members
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xGroup 'SetMembers'
        {
            GroupName = $Name
            Ensure    = 'Present'
            Members   = $Members
        }
    }
}
