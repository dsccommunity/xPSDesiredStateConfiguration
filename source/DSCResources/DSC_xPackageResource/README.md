# Description

This resource installs or uninstalls a package on the host.

## Parameters

* **Ensure**: Ensures that the package is **Present** or **Absent**.
* **Name**: The name of the package.
* **Path**: The source path of the package.
* **ProductId**: The product ID of the package (usually a GUID).
* **Arguments**: Command line arguments passed on the installation command line.
  * When installing MSI packages, the `/quiet` and `/norestart` arguments are
    automatically applied.
* **IgnoreReboot**: Ignore a pending reboot if requested by package
  installation. By default is `$false` and DSC will try to reboot the system.
* **Credential**: PSCredential needed to access Path.
* **ReturnCode**: An array of return codes that are returned after a successful
  installation.
* **LogPath**: The destination path of the log.
* **FileHash**: The hash that should match the hash of the package file.
* **HashAlgorithm**: The algorithm to use to get the hash of the package file.
  * Supported values: SHA1, SHA256, SHA384, SHA512, MD5, RIPEMD160
* **SignerSubject**: The certificate subject that should match that of the
  package file's signing certificate.
* **SignerThumbprint**: The certificate thumbprint that should match that of
  the package file's signing certificate.
* **ServerCertificateValidationCallback**: A callback function to validate the
  server certificate.
* **RunAsCredential**: Credential used to install the package on the local
  system.
* **CreateCheckRegValue**: If a registry value should be created.
* **InstalledCheckRegHive**: The hive in which to create the registry key.
  Defaults to 'LocalMachine'. { LocalMachine | CurrentUser }
* **InstalledCheckRegKey**: That path in the registry where the value should
  be created.
* **InstalledCheckRegValueName**: The name of the registry value to create.
* **InstalledCheckRegValueData**: The data that should be set to the registry
  value.
