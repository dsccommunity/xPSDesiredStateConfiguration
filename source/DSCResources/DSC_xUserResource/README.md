# Description

Provides a mechanism to manage local users on a target node.

## Parameters

* **[String] UserName** _(Key)_: Indicates the account name for which you want
  to ensure a specific state.
* **[String] Description** _(Write)_: Indicates the description you want to use
  for the user account.
* **[Boolean] Disabled** _(Write)_: Indicates if the account is enabled. Set
  this property to $true to ensure that this account is disabled, and set it to
  $false to ensure that it is enabled.
  * Suported values: $true, $false
  * Default value: $false
* **[String] Ensure** _(Write)_: Ensures that the feature is present or absent.
  * Supported values: Present, Absent
  * Default Value: Present
* **[String] FullName** _(Write)_: Represents a string with the full name you
  want to use for the user account.
* **[PSCredential] Password** _(Write)_: Indicates the password you want to use
  for this account.
* **[Boolean] PasswordChangeNotAllowed** _(Write)_: Indicates if the user can
  change the password. Set this property to $true to ensure that the user
  cannot change the password, and set it to $false to allow the user to change
  the password.
  * Suported values: $true, $false
  * Default value: $false
* **[Boolean] PasswordChangeRequired** _(Write)_: Indicates if the user must
  change the password at the next sign in. Set this property to $true if the
  user must change the password.
  * Suported values: $true, $false
  * Default value: $true
* **[Boolean] PasswordNeverExpires** _(Write)_: Indicates if the password will
  expire. To ensure that the password for this account will never expire, set
  this property to $true, and set it to $false if the password will expire.
  * Suported values: $true, $false
  * Default value: $false
