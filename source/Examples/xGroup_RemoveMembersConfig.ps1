<#PSScriptInfo
.VERSION 1.0.1
.GUID 84717cb3-a5d9-41dd-82c3-32b3068502f2
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
        Configuration that make sure a group exist and the specified users are
        not member of the group.

    .DESCRIPTION
        Configuration that make sure a group exist and have the correct members.

        If the group does not exist, adds the users and make sure the members of
        the group are only those that are in the configuration. If the group
        already exists and if there are any members not in the configuration,
        those members will be removed from the group, and any missing members
        that are in the configuration will be added to the group.

    .PARAMETER Name
        The name of the group to create or/and remove members from.

    .PARAMETER MembersToExclude
        One or more usernames of the users that should be removed as member of
        the group.

    .EXAMPLE
        xGroup_RemoveMembersConfig -Name 'GroupName1' -MembersToExclude @('Username1', 'Username2')

        Compiles a configuration that creates the group 'GroupName1, if it does
        not already exist, and will the make sure the users with the usernames
        'Username1' or 'Username2' are removed as member from the group if the
        users are ever added as members.
        If the group named GroupName1 already exists, will make sure the users
        with the usernames 'Username1' or 'Username2' are removed as member from
        the group if the users are ever added as members.

    .EXAMPLE
        Start-AzureRmAutomationDscCompilationJob -ResourceGroupName '<resource-group>' -AutomationAccountName '<automation-account>' -ConfigurationName 'xGroup_RemoveMembersConfig' -Parameters @{ Name = 'GroupName1'; MembersToExclude = @('Username1', 'Username2') }

        Compiles a configuration in Azure Automation that creates the group
        'GroupName1, if it does not already exist, and will the make sure the
        users with the usernames 'Username1' or 'Username2' are removed as member
        from the group if the users are ever added as members.
        If the group named GroupName1 already exists, will make sure the users
        with the usernames 'Username1' or 'Username2' are removed as member from
        the group if the users are ever added as members.

        Replace the <resource-group> and <automation-account> with correct values.
#>
Configuration xGroup_RemoveMembersConfig
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [System.String[]]
        $MembersToExclude
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xGroup 'RemoveMembers'
        {
            GroupName        = $Name
            Ensure           = 'Present'
            MembersToExclude = $MembersToExclude
        }
    }
}
