# Description

Provides a mechanism to configure and manage multiple xService resources with
common settings but different names. This resource can only modify or delete
existing services. It cannot create services.

#### Parameters

* **[String[]] Name** _(Key)_: The names of the services to modify or delete.
  This may be different from the service's display name. To retrieve a list of
  all services with their names and current states, use the Get-Service cmdlet.

The following parameters will be the same for each service in the set:

* **[String] Ensure** _(Write)_: Indicates whether the services are present or
  absent. { *Present* | Absent }.
* **[String] BuiltInAccount** _(Write)_: The built-in account the services
  should start under. Cannot be specified at the same time as Credential. The
  user account specified by this property must have access to the service
  executable paths in order to start the services.
  { LocalService | LocalSystem | NetworkService }.
* **[PSCredential] Credential** _(Write)_: The credential of the user account
  the services should start under. Cannot be specified at the same time as
  BuiltInAccount. The user specified by this credential will automatically be
  granted the Log on as a Service right. The user account specified by this
  property must have access to the service executable paths in order to start
  the services.
* **[String] StartupType** _(Write)_: The startup type of the services.
  { Automatic | Disabled | Manual }.
* **[String] State** _(Write)_: The state the services.
  { *Running* | Stopped | Ignore }.
