# Description

Provides a mechanism to install and uninstall .msi packages.

## Parameters

* **[String] ProductId** _(Key)_: The identifying number used to find the
  package, usually a GUID.
* **[String] Path** _(Required)_: The path to the MSI file that should be
  installed or uninstalled.
* **[String] Ensure** _(Write)_: Specifies whether or not the MSI file should
  be installed or not. To install the MSI file, specify this property as
  Present. To uninstall the .msi file, specify this property as Absent. The
  default value is Present. { *Present* | Absent }.
* **[String] Arguments** _(Write)_: The arguments to be passed to the MSI
  package during installation or uninstallation if needed.
* **[Boolean] IgnoreReboot** _(Write): Ignore a pending reboot if requested
  by package installation. By default is `$false` and DSC will try to reboot
  the system.
* **[System.Management.Automation.PSCredential] Credential** _(Write)_: The
  credential of a user account to be used to mount a UNC path if needed.
* **[String] LogPath** _(Write)_: The path to the log file to log the output
  from the MSI execution.
* **[String] FileHash** _(Write)_: The expected hash value of the MSI file at
  the given path.
* **[String] HashAlgorithm** _(Write)_: The algorithm used to generate the
  given hash value.
* **[String] SignerSubject** _(Write)_: The subject that should match the
  signer certificate of the digital signature of the MSI file.
* **[String] SignerThumbprint** _(Write)_: The certificate thumbprint that
  should match the signer certificate of the digital signature of the MSI file.
* **[String] ServerCertificateValidationCallback** _(Write)_: PowerShell code
  that should be used to validate SSL certificates for paths using HTTPS.
* **[System.Management.Automation.PSCredential] RunAsCredential** _(Write)_:
  The credential of a user account under which to run the installation or
  uninstallation of the MSI package.
