# Description

Provides a mechanism to configure and manage multiple xGroup resources with
common settings but different names

## Parameters

- **[String] GroupName** _(Key)_: The names of the groups to create, modify, or
  remove.

The following parameters will be the same for each group in the set:

- **[String] Ensure** _(Write)_: Indicates if the groups should exist or not.
  To add groups or modify existing groups, set this property to Present. To
  remove groups, set this property to Absent. { Present | Absent }.
- **[String[]] MembersToInclude** _(Write)_: The members the groups should
  include. This property will only add members to groups. Members should be
  specified as strings in the format of their domain qualified name
  (domain\username), their UPN (username@domainname), their distinguished name
  (CN=username,DC=...), or their username (for local machine accounts).
- **[String[]] MembersToExclude** _(Write)_: The members the groups should
  exclude. This property will only remove members groups. Members should be
  specified as strings in the format of their domain qualified name
  (domain\username), their UPN (username@domainname), their distinguished name
  (CN=username,DC=...), or their username (for local machine accounts).
- **[System.Management.Automation.PSCredential] Credential** _(Write)_: A
  credential to resolve non-local group members.
