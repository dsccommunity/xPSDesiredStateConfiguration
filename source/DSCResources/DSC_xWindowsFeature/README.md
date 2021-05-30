# Description

Provides a mechanism to install or uninstall Windows roles or features on a
target node.

## Requirements

- Target machine must be running Windows Server 2008 or later.
- Target machine must have access to the DISM PowerShell module.
- Target machine must have access to the ServerManager module.

## Parameters

* **[String] Name** _(Key)_: Indicates the name of the role or feature that you
  want to ensure is added or removed. This is the same as the Name property
  from the Get-WindowsFeature cmdlet, and not the display name of the role or
  feature.
* **[PSCredential] Credential** _(Write)_: Indicates the credential to use to
  add or remove the role or feature if needed.
* **[String] Ensure** _(Write)_: Specifies whether the feature should be
  installed (Present) or uninstalled (Absent) { *Present* | Absent }.
* **[Boolean] IncludeAllSubFeature** _(Write)_: Set this property to $true to
  ensure the state of all required subfeatures with the state of the feature
  you specify with the Name property. The default value is $false.
* **[String] LogPath** _(Write)_: Indicates the path to a log file to log the
  operation.
