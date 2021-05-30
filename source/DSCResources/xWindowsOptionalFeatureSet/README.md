# Description

Provides a mechanism to configure and manage multiple xWindowsOptionalFeature
resources on a target node. This resource works on Nano Server.

## Requirements

- Target machine must be running a Windows client operating system, Windows
  Server 2012 or later, or Nano Server.
- Target machine must have access to the DISM PowerShell module.

## Parameters

* **[String[]] Name** _(Key)_: The names of the Windows optional features to
  enable or disable.

The following parameters will be the same for each Windows optional feature in
the set:

* **[String] Ensure** _(Write)_: Specifies whether the Windows optional
  features should be enabled or disabled. To enable the features, set this
  property to Present. To disable the features, set this property to Absent.
  { Present | Absent }.
* **[Boolean] RemoveFilesOnDisable** _(Write)_: Specifies whether or not to
  remove the files associated with the Windows optional features when they are
  disabled.
* **[Boolean] NoWindowsUpdateCheck** _(Write)_: Specifies whether or not DISM
  should contact Windows Update (WU) when searching for the source files to
  restore Windows optional features on an online image.
* **[String] LogPath** _(Write)_: The file path to which to log the operation.
* **[String] LogLevel** _(Write)_: The level of detail to include in the log.
  { ErrorsOnly | ErrorsAndWarning | ErrorsAndWarningAndInformation }.
