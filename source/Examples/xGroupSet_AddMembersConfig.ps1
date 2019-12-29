<#PSScriptInfo
.VERSION 1.0.1
.GUID db98d037-c170-43cc-a716-da521731e84f
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
        Configuration that add members to multiple groups.

    .DESCRIPTION
        Configuration that add members to multiple groups and make sure the users
        are added back as members of the groups if they are ever removed.

        If a group does not exist, the group is created and the members are added.

    .PARAMETER Name
        The name of one or more groups to add members to.

    .PARAMETER MembersToInclude
        One or more usernames of the users that should be added as members of the
        group.

    .EXAMPLE
        xGroupSet_AddMembersConfig -Name @('Administrators', 'GroupName1') -Members @('Username1', 'Username2')

        Compiles a configuration that adds the users that have the usernames
        'Username1' and 'Username2' to each of the groups 'GroupName1' and
        'Administrators'.
        If the groups named 'GroupName1' or 'Administrators' do not exist, creates
        the groups named 'GroupName1' and 'Administrators' and adds the users
        with the usernames 'Username1' and 'Username2' to both groups.

    .EXAMPLE
        Start-AzureRmAutomationDscCompilationJob -ResourceGroupName '<resource-group>' -AutomationAccountName '<automation-account>' -ConfigurationName 'xGroupSet_AddMembersConfig' -Parameters @{ Name = @('Administrators', 'GroupName1'); Members = @('Username1', 'Username2') }

        Compiles a configuration in Azure Automation that adds the users that
        have the usernames 'Username1' and 'Username2' to each of the groups
        'GroupName1' and 'Administrators'.
        If the groups named 'GroupName1' or 'Administrators' do not exist, creates
        the groups named 'GroupName1' and 'Administrators' and adds the users
        with the usernames 'Username1' and 'Username2' to both groups.

        Replace the <resource-group> and <automation-account> with correct values.
#>
Configuration xGroupSet_AddMembersConfig
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String[]]
        $Name,

        [Parameter()]
        [System.String[]]
        $MembersToInclude
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xGroupSet 'AddMembers'
        {
            GroupName        = $Name
            Ensure           = 'Present'
            MembersToInclude = $MembersToInclude
        }
    }
}
