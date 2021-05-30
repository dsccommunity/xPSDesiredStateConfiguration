# Description

Provides a mechanism to configure and manage Windows services.
This resource works on Nano Server.

#### Parameters

* **[String] Name** _(Key)_: Indicates the service name. This may be different
  from the service's display name. To retrieve a list of all services with
  their names and current states, use the Get-Service cmdlet.
* **[String] Ensure** _(Write)_: Indicates whether the service is present or
  absent. { *Present* | Absent }.
* **[String] Path** _(Write)_: The path to the service executable file.
  Required when creating a service. The user account specified by
  BuiltInAccount or Credential must have access to this path in order to start
  the service.
* **[String] DisplayName** _(Write)_: The display name of the service.
* **[String] Description** _(Write)_: The description of the service.
* **[String[]] Dependencies** _(Write)_: The names of the dependencies of the
  service.
* **[String] BuiltInAccount** _(Write)_: The built-in account the service
  should start under. Cannot be specified at the same time as Credential or
  GroupManagedServiceAccount. The user account specified by this property must
  have access to the service executable path defined by Path in order to start
  the service. { LocalService | LocalSystem | NetworkService }.
* **[String] GroupManagedServiceAccount** _(Write)_: The Group Managed Service
  Account the service should start under. Cannot be specified at the same time
  as Credential or BuiltinAccount. The user account specified by this property
  must have access to the service executable path defined by Path in order to
  start the service. When specified in a DOMAIN\User$ form, remember to also
  input the trailing dollar sign. Get-TargetResource outputs the name of the
  user to the BuiltinAccount property.
* **[PSCredential] Credential** _(Write)_: The credential of the user account
  the service should start under. Cannot be specified at the same time as
  BuiltInAccount or GroupManagedServiceAccount. The user specified by this
  credential will automatically be granted the Log on as a Service right. The
  user account specified by this property must have access to the service
  executable path defined by Path in order to start the service.
  Get-TargetResource outputs the name of the user to the BuiltinAccount
  property.
* **[Boolean] DesktopInteract** _(Write)_: Indicates whether or not the service
  should be able to communicate with a window on the desktop. Must be false for
  services not running as LocalSystem. The default value is False.
* **[String] StartupType** _(Write)_: The startup type of the service.
  { Automatic | Disabled | Manual }. If StartupType is "Disabled" and Service
  is not installed the resource will complete as being DSC compliant.
* **[String] State** _(Write)_: The state of the service.
  { *Running* | Stopped | Ignore }.
* **[Uint32] StartupTimeout** _(Write)_: The time to wait for the service to
  start in milliseconds. Defaults to 30000 (30 seconds).
* **[Uint32] TerminateTimeout** _(Write)_: The time to wait for the service to
  stop in milliseconds. Defaults to 30000 (30 seconds).
