[![Build status](https://ci.appveyor.com/api/projects/status/s35s7sxuyym8yu6c/branch/master?svg=true)](https://ci.appveyor.com/project/PowerShell/xpsdesiredstateconfiguration/branch/master)

# xPSDesiredStateConfiguration

The **xPSDesiredStateConfiguration** module is a more recent, experimental version of the PSDesiredStateConfiguration module that ships in Windows as part of PowerShell 4.0.
The module contains the **xDscWebService**, **xWindowsProcess**, **xService**, **xPackage**, **xRemoteFile**, and **xGroup** DSC resources, as well as the **xFileUpload** composite DSC resource. 

## Contributing
Please check out common DSC Resources [contributing guidelines](https://github.com/PowerShell/DscResource.Kit/blob/master/CONTRIBUTING.md).


## Resources

* **xDscWebService** configures an OData endpoint for DSC service to make a node a DSC pull server.
* **xWindowsProcess** configures and manages Windows processes.
* **xService** configures and manages Windows services.
* **xRemoteFile** ensures the presence of remote files on a local machine.
* **xPackage** manages the installation of .msi and .exe packages.
* **xGroup** configures and manages local Windows groups
* **xFileUpload** is a composite resource which ensures that local files exist on an SMB share. 

### xDscWebService

* **EndpointName**: The desired web service name. 
* **CertificateThumbPrint**: Certificate thumbprint for creating an HTTPS endpoint.
* **Port**: Port for web service.
* **PhysicalPath**: Folder location where the content of the web service resides.
* **State**: State of the web service: { Started | Stopped }
* **ModulePath**: Folder location where DSC resources are stored. 
* **ConfiguraitonPath**: Folder location where DSC configurations are stored. 
* **IsComplianceServer**: Determines whether the web service endpoint exposes compliance data.
* **Ensure**: Ensures that the web service is **Present** or **Absent**

### xWindowsProcess

For a complete list of properties, please use Get-DscResource

* **Path**: The full path or the process executable 
* **Arguments**: This is a mandatory parameter for passing arguments to the process executable. 
Specify an empty string if you don't want to pass any arguments.
* **Credential**: The credentials of the user under whose context you want to run the process. 
* **Ensure**: Ensures that the process is running or stopped: { Present | Absent }

### xService

For a complete list of properties, please use Get-DscResource

* **Name**: The name for the service.
* **Ensure**: An enumeration which stating whether the service needs to be created (when set to 'Present') or deleted (when set to 'Absent') 
* **Path**: The path to the service executable file. This is a requied parameter if Ensure is set to true 

### xRemoteFile

* **DestinationPath**: Path where the remote file should be downloaded.
* **Uri**: URI of the file which should be downloaded.
* **UserAgent**: User agent for the web request.
* **Headers**: Headers of the web request.
* **Credential**: Specifies credential of a user which has permissions to send the request.
* **Ensure**: Ensures that the local file is **Present** or **Absent** on the local system

### xPackage

For a complete list, please use Get-DscResource.

* **Ensure**: Ensures that the package is **Present** or **Absent**.
* **Name**: The name of the package.
* **Path**: The source path of the package.
* **ProductId**: The product ID of the package (usually a GUID).
* **Arguments**: Command line arguments passed on the installation command line.
* **Credential**: PSCredential needed to access Path.
* **ReturnCode**: An array of return codes that are returned after a successful installation. 
* **LogPath**: The destination path of the log.
* **PackageDescription**: A text description of the package being installed.
* **Publisher**: Publisher's name.
* **InstalledOn**: Date of installation.
* **Size**: Size of the installation.
* **Version**: Version of the package.
* **Installed**: Is the package installed?
* **RunAsCredential**: Credentials to use when installing the package.
* **InstalledCheckRegKey**: Registry key to open to check for package installation status.
* **InstalledCheckRegValueName**: Registry value name to check for package installation status. 
* **InstalledCheckRegValueData**: Value to compare against the retrieved value to check for package installation.

### xGroup

This resource extends PowerShell 4.0 Group resource by supporting cross-domain account lookup where a valid trust relationship exists.
In addition, limited support for UPN-formatted names are supported for identifying user, computer, and group domain-based accounts.

* **GroupName**: The name of the group.
* **Ensure**: Ensures that the group is **Present** or **Absent**.
* **Description**: Description of the group.
* **Members**: The members that form the group.
Note: If the group already exists, the listed items in this property replaces what is in the group. 
* **MembersToInclude**: List of users to add to the group. 
Note: This property is ignored if 'Members' is specified. 
* **MembersToExclude**: List of users you want to ensure are not members of the group. 
Note: This property is ignored if 'Members' is specified. 
* **Credential**: Indicates the credentials required to access remote resources. 
Note: This account must have the appropriate Active Directory permissions to add all non-local accounts to the group or an error will occur. 

Local accounts may be specified in one of the following ways:

* The simple name of the account of the group or local user.
* The account name scoped to the explicit machine name (eg. myserver\users or myserver\username).
* The account name scoped using the explicit local machine qualifier (eg. .\users or .\username).

Domain members may be specified using domain\name or Universal Principal Name (UPN) formatting. The following illustrates the various formats

* Domain joined machines: mydomain\myserver or myserver@mydomain.com
* Domain user accounts: mydomain\username or username@mydomain.com
* Domain group accounts: mydomain\groupname or groupname@mydomain.com

### xFileUpload

* **DestinationPath**: Path where the local file should be uploaded.
* **SourcePath**: Path to the local file which should be uploaded.
* **Credential**: PSCredential for the user with access to DestinationPath.
* **CertificateThumbprint**: Thumbprint of the certificate which should be used for encryption/decryption.


## Versions

### 3.3.0.0

* Add support to xPackage resource for checking different registry hives
* Added support for new registration properties in xDscWebService resource

### 3.2.0.0

* xArchive:
    - Fix problems with file names containing square brackets.
* xDSCWebService:
    - Fix default culture issue.
* xPackage:
    - Security enhancements.

### 3.0.3.4

* Multiple issues addressed 
    - Corrected output type for Set- and Test-TargetResource functions in xWebSite, xPackage, xArchive, xGroup, xProcess, xService
    - xRemoteFile modified to support creating a directory that does not exist when specified, ensuring idempotency. 
    Also improved error messages.
    - xDSCWebService updated so that Get-TargetResource returns the OData Endpoint URL correctly.
    - In xWindowsOptionalFeature, fixed Test-TargetResource issue requiring Ensure = True.
        + Note: this change requires the previous Ensure values of Enable and Disable to change to Present and Absent

### 3.0.2.0

* Adding following resources: 
    * xGroup

### 3.0.1.0

* Adding following resources: 
    * xFileUpload

### 2.0.0.0

* Adding following resources: 
    * xWindowsProcess
    * xService
    * xRemoteFile
    * xPackage

### 1.1.0.0

* Fix to remove and recreate the SSL bindings when performing a new HTTPS IIS Endpoint setup.
* Fix in the resource module to consume WebSite Name parameter correctly

### 1.0.0.0

* Initial release with the following resources:
    * DscWebService

## Examples
### Change the name and the workgroup name 

This configuration will set a machine name and change its workgroup.

### Switch from a workgroup to a domain 

This configuration sets the machine name and joins a domain.
Note: this requires a credential.

### Change the name while staying on the domain

This example will change the machines name while remaining on the domain.
Note: this requires a credential.

### Change the name while staying on the workgroup 

This example will change a machine's name while remaining on the workgroup.

### Switch from a domain to a workgroup 

This example switches the computer from a domain to a workgroup.
Note: this requires a credential.

### Download file from URI, specifying headers and user agent

This configuration will download a file from a specific URI to DestinationPath.
The web request will contain specific headers and will be sent using a specified user agent.

### Upload file to an SMB share

This configuration will upload a file from SourcePath to the remote DestinationPath. 
Username and password will be used to access the DestinationPath.

### Sample1.ps1 installs a package that uses an .exe file

This configuration will install a .exe package, verifying the package using the package name. 

### Sample1.ps2 installs a package that uses an .exe file

This configuration will install a .exe package and verify the package using the product ID and package name.

### Sample1.ps3 installs a package that uses an .msi file. 

This configuration will install a .msi package and verify the package using the product ID and package name and requires credentials to read the share and install the package.   

### Sample1.ps4 installs a package that uses an .exe file

This configuration will install a .exe package and verify the package using the product ID and package name and requires credentials to read the share and install the package. It also uses custom registry values to check for the package presence.
