# Description

Creates and registers a new session configuration endpoint.

## Parameters

* **Ensure**: Indicates if the session configuration is **Present** or
  **Absent**.
* **Name**: Specifies the name of the session configuration.
* **StartupScript**: Specifies the startup script for the configuration. Enter
  the fully qualified path of a Windows PowerShell script.
* **RunAsCredential**: Specifies the credential for commands of this session
  configuration. By default, commands run with the permissions of the current
  user.
* **SecurityDescriptorSDDL**: Specifies the Security Descriptor Definition
  Language (SDDL) string for the configuration. This string determines the
  permissions that are required to use the new session configuration. To use a
  session configuration in a session, users must have at least Execute(Invoke)
  permission for the configuration.
* **AccessMode**: Enables and disables the session configuration and determines
  whether it can be used for remote or local sessions on the computer. The
  default value is "Remote". { Local | *Remote* | Disabled }
