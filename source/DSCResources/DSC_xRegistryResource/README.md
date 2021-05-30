# Description

Provides a mechanism to manage registry keys and values on a target node.

## Parameters

* **[String] Key** _(Key)_: The path of the registry key to add, modify, or
  remove. This path must include the registry hive/drive (e.g.
  HKEY_LOCAL_MACHINE, HKLM:).
* **[String] ValueName** _(Key)_: The name of the registry value. To add or
  remove a registry key, specify this property as an empty string without
  specifying ValueType or ValueData. To modify or remove the default value of a
  registry key, specify this property as an empty string while also specifying
  ValueType or ValueData.
* **[String] Ensure** _(Write)_: Specifies whether or not the registry key or
  value should exist. To add or modify a registry key or value, set this
  property to Present. To remove a registry key or value, set this property to
  Absent. { *Present* | Absent }.
* **[String] ValueData** _(Write)_: The data the specified registry key value
  should have as a string or an array of strings (MultiString only).
* **[String] ValueType** _(Write)_: The type the specified registry key value
  should have.
  { *String* | Binary | DWord | QWord | MultiString | ExpandString }
* **[Boolean] Hex** _(Write)_: Specifies whether or not the specified DWord or
  QWord registry key data is provided in a hexadecimal format. Not valid for
  types other than DWord and QWord. The default value is $false.
* **[Boolean] Force** _(Write)_: Specifies whether or not to overwrite the
  specified registry key value if it already has a value or whether or not to
  delete a registry key that has subkeys. The default value is $false.
