# Description

Provides a mechanism to configure and manage multiple xWindowsProcess resources
on a target node.

#### Parameters

* **[String[]] Path** _(Key)_: The file paths to the executables of the
  processes to start or stop. Only the names of the files may be specified if
  they are all accessible through the environment path. Relative paths are not
  supported.

The following parameters will be the same for each process in the set:

* **[PSCredential] Credential** _(Write)_: The credential of the user account
  to run the processes under. If this user is from the local system, the
  StandardOutputPath, StandardInputPath, and WorkingDirectory parameters cannot
  be provided at the same time.
* **[String] Ensure** _(Write)_: Specifies whether or not the processes should
  be running. To start the processes, specify this property as Present. To stop
  the processes, specify this property as Absent. { Present | Absent }.
* **[String] StandardOutputPath** _(Write)_: The file path to which to write
  the standard output from the processes. Any existing file at this file path
  will be overwritten. This property cannot be specified at the same time as
  Credential when running the processes as a local user.
* **[String] StandardErrorPath** _(Write)_: The file path to which to write the
  standard error output from the processes. Any existing file at this file path
  will be overwritten.
* **[String] StandardInputPath** _(Write)_: The file path from which to receive
  standard input for the processes. This property cannot be specified at the
  same time as Credential when running the processes as a local user.
* **[String] WorkingDirectory** _(Write)_: The file path to the working
  directory under which to run the process. This property cannot be specified
  at the same time as Credential when running the processes as a local user.
