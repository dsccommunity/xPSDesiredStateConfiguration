# Description

Provides a mechanism to run PowerShell script blocks on a target node.
This resource works on Nano Server.

#### Parameters

* **[String] GetScript** _(Key)_: A string that can be used to create a
  PowerShell script block that retrieves the current state of the resource.
  This script block runs when the Get-DscConfiguration cmdlet is called. This
  script block should return a hash table containing one key named Result with
  a string value.
* **[String] SetScript** _(Key)_: A string that can be used to create a
  PowerShell script block that sets the resource to the desired state. This
  script block runs conditionally when the Start-DscConfiguration cmdlet is
  called. The TestScript script block will run first. If the TestScript block
  returns False, this script block will run. If the TestScript block returns
  True, this script block will not run. This script block should not return.
* **[String] TestScript** _(Key)_: A string that can be used to create a
  PowerShell script block that validates whether or not the resource is in the
  desired state. This script block runs when the Start-DscConfiguration cmdlet
  is called or when the Test-DscConfiguration cmdlet is called. This script
  block should return a boolean with True meaning that the resource is in the
  desired state and False meaning that the resource is not in the desired
  state.
* **[PSCredential] Credential** _(Write)_: The credential of the user account
  to run the script under if needed.
