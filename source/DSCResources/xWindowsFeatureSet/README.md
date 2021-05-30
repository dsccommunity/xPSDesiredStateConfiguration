# Description

Provides a mechanism to configure and manage multiple xWindowsFeature resources
on a target node.

## Requirements

- Target machine must be running Windows Server 2008 or later.
- Target machine must have access to the DISM PowerShell module.
- Target machine must have access to the ServerManager module.

## Parameters

* **[String] Name** _(Key)_: The names of the roles or features to install or
  uninstall. This may be different from the display name of the feature/role.
  To retrieve the names of features/roles on a machine use the
  Get-WindowsFeature cmdlet.
* **[String] Ensure** _(Write)_: Specifies whether the feature should be
  installed or uninstalled. To install features, set this property to Present.
  To uninstall features, set this property to Absent. { Present | Absent }.
* **[Boolean] IncludeAllSubFeature** _(Write)_: Specifies whether or not all
  subfeatures should be installed or uninstalled alongside the specified roles
  or features. If this property is true and Ensure is set to Present, all
  subfeatures will be installed. If this property is false and Ensure is set to
  Present, subfeatures will not be installed or uninstalled. If Ensure is set
  to Absent, all subfeatures will be uninstalled.
* **[PSCredential] Credential** _(Write)_: The credential of the user account
  under which to install or uninstall the roles or features.
* **[String] LogPath** _(Write)_: The custom file path to which to log this
  operation. If not passed in, the default log path will be used
  (%windir%\logs\ServerManager.log).
