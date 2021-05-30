# Description

Provides a mechanism to manage local groups on the target node.
This resource works on Nano Server.

* **[String] GroupName** _(Key)_: The name of the group to create, modify, or
  remove.
* **[String] Ensure** _(Write)_: Indicates if the group should exist or not. To
  add a group or modify an existing group, set this property to Present. To
  remove a group, set this property to Absent. The default value is Present.
  { *Present* | Absent }.
* **[String] Description** _(Write)_: The description the group should have.
* **[String[]] Members** _(Write)_: The members the group should have. This
  property will replace all the current group members with the specified
  members. Members should be specified as strings in the format of their domain
  qualified name (domain\username), their UPN (username@domainname), their
  distinguished name (CN=username,DC=...), or their username (for local machine
  accounts). Using either the MembersToExclude or MembersToInclude properties
  in the same configuration as this property will generate an error.
* **[String[]] MembersToInclude** _(Write)_: The members the group should
  include. This property will only add members to a group. Members should be
  specified as strings in the format of their domain qualified name
  (domain\username), their UPN (username@domainname), their distinguished name
  (CN=username,DC=...), or their username (for local machine accounts). Using
  the Members property in the same configuration as this property will generate
  an error.
* **[String[]] MembersToExclude** _(Write)_: The members the group should
  exclude. This property will only remove members from a group. Members should
  be specified as strings in the format of their domain qualified name
  (domain\username), their UPN (username@domainname), their distinguished name
  (CN=username,DC=...), or their username (for local machine accounts). Using
  the Members property in the same configuration as this property will generate
  an error.
* **[System.Management.Automation.PSCredential] Credential** _(Write)_: A
  credential to resolve non-local group members.
