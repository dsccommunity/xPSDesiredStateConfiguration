# Description

Provides a mechanism to enable or disable optional features on a target node.
This resource works on Nano Server.

## Requirements

- Target machine must be running a Windows client operating system, Windows
  Server 2012 or later, or Nano Server.
- Target machine must have access to the DISM PowerShell module.

## Parameters

* **[String] Name** _(Key)_: The name of the Windows optional feature to enable
  or disable.
* **[String] Ensure** _(Write)_: Specifies whether the feature should be
  enabled or disabled. To enable the feature, set this property to Present. To
  disable the feature, set the property to Absent. The default value is
  Present. { *Present* | Absent }.
* **[Boolean] RemoveFilesOnDisable** _(Write)_: Specifies that all files
  associated with the feature should be removed if the feature is being
  disabled.
* **[Boolean] NoWindowsUpdateCheck** _(Write)_: Specifies whether or not DISM
  contacts Windows Update (WU) when searching for the source files to enable
  the feature. If $true, DISM will not contact WU.
* **[String] LogPath** _(Write)_: The path to the log file to log this
  operation. There is no default value, but if not set, the log will appear at
  %WINDIR%\Logs\Dism\dism.log.
* **[String] LogLevel** _(Write)_: The maximum output level to show in the log.
  ErrorsOnly will log only errors. ErrorsAndWarning will log only errors and
  warnings. ErrorsAndWarningAndInformation will log errors, warnings, and debug
  information). The default value is "ErrorsAndWarningAndInformation".
  { ErrorsOnly | ErrorsAndWarning | *ErrorsAndWarningAndInformation* }.
