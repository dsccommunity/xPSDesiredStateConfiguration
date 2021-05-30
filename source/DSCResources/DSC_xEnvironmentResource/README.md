# Description

Provides a mechanism to configure and manage environment variables for a
machine or process.

#### Parameters

* **[String] Name** _(Key)_: The name of the environment variable to create,
  modify, or remove.
* **[String] Value** _(Write)_: The desired value for the environment variable.
  The default value is an empty string which either indicates that the variable
  should be removed entirely or that the value does not matter when testing its
  existence. Multiple entries can be entered and separated by semicolons (see
  [Examples](/source/Examples)).
* **[String] Ensure** _(Write)_: Specifies if the environment varaible should
  exist. { *Present* | Absent }.
* **[Boolean] Path** _(Write)_: Indicates whether or not the environment
  variable is a path variable. If the variable being configured is a path
  variable, the value provided will be appended to or removed from the existing
  value, otherwise the existing value will be replaced by the new value. When
  configured as a Path variable, multiple entries separated by semicolons are
  ensured to be either present or absent without affecting other Path entries
  (see [Examples](/source/Examples)). The default value is False.
* **[String[]] Target** _(Write)_: Indicates the target where the environment
  variable should be set. { Process | Machine | *Process, Machine* }.

