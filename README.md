# xPSDesiredStateConfiguration

[![Build Status](https://dev.azure.com/dsccommunity/xPSDesiredStateConfiguration/_apis/build/status/dsccommunity.xPSDesiredStateConfiguration?branchName=main)](https://dev.azure.com/dsccommunity/xPSDesiredStateConfiguration/_build/latest?definitionId=8&branchName=main)
![Code Coverage](https://img.shields.io/azure-devops/coverage/dsccommunity/xPSDesiredStateConfiguration/8/main)
[![Azure DevOps tests](https://img.shields.io/azure-devops/tests/dsccommunity/xPSDesiredStateConfiguration/8/main)](https://dsccommunity.visualstudio.com/xPSDesiredStateConfiguration/_test/analytics?definitionId=8&contextType=build)
[![PowerShell Gallery (with prereleases)](https://img.shields.io/powershellgallery/vpre/xPSDesiredStateConfiguration?label=xPSDesiredStateConfiguration%20Preview)](https://www.powershellgallery.com/packages/xPSDesiredStateConfiguration/)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/xPSDesiredStateConfiguration?label=xPSDesiredStateConfiguration)](https://www.powershellgallery.com/packages/xPSDesiredStateConfiguration/)
[![codecov](https://codecov.io/gh/dsccommunity/xPSDesiredStateConfiguration/branch/main/graph/badge.svg)](https://codecov.io/gh/dsccommunity/xPSDesiredStateConfiguration)

The **xPSDesiredStateConfiguration** module is a more recent, experimental
version of the PSDesiredStateConfiguration module that ships in Windows as part
of PowerShell 4.0.

The supported version of this module is available as
[PSDscResources](https://github.com/PowerShell/PSDscResources).

> Note: New features are no longer being added to the **PSDscResource`** module.
> If you require new features, please migrate to **xPSDesiredStateConfiguration**
> and request the features against that module.

This module is automatically tested using PowerShell 5.1 on servers running
Windows 2012 R2 and Windows 2016, and is expected to work on other operating
systems running PowerShell 5.1. While this module may work with PowerShell
versions going back to PowerShell 4, there is no automatic testing performed
for these versions, and thus no guarantee that the module will work as
expected.

## Code of Conduct

This project has adopted [this code of conduct](CODE_OF_CONDUCT.md).

## Releases

For each merge to the branch `main` a preview release will be
deployed to [PowerShell Gallery](https://www.powershellgallery.com/).
Periodically a release version tag will be pushed which will deploy a
full release to [PowerShell Gallery](https://www.powershellgallery.com/).

## Contributing

Please check out common DSC Community [contributing guidelines](https://dsccommunity.org/guidelines/contributing).

## Change log

A full list of changes in each version can be found in the [change log](CHANGELOG.md).

## Resources

- **xArchive** provides a mechanism to expand an archive (.zip) file to a
  specific path or remove an expanded archive (.zip) file from a specific path
  on a target node.
- **xDscWebService** configures an OData endpoint for DSC service to make a
  node a DSC pull server.
- **xEnvironment** provides a mechanism to configure and manage environment
  variables for a machine or process.
- **xFileUpload** is a composite resource which ensures that local files exist
  on an SMB share.
- **xGroup** provides a mechanism to manage local groups on a target node.
- **xGroupSet** provides a mechanism to configure and manage multiple xGroup
  resources with common settings but different names.
- **xMsiPackage** provides a mechanism to install and uninstall .msi packages.
- **xPackage** manages the installation of .msi and .exe packages.
- **xRegistry** provides a mechanism to manage registry keys and values on a
  target node.
- **xRemoteFile** ensures the presence of remote files on a local machine.
- **xScript** provides a mechanism to run PowerShell script blocks on a target
  node.
- **xService** provides a mechanism to configure and manage Windows services.
- **xServiceSet** provides a mechanism to configure and manage multiple
  xService resources with common settings but different names.
- **xUser** provides a mechanism to manage local users on the target node.
- **xWindowsFeature** provides a mechanism to install or uninstall Windows
  roles or features on a target node.
- **xWindowsFeatureSet** provides a mechanism to configure and manage multiple
  xWindowsFeature resources on a target node.
- **xWindowsOptionalFeature** provides a mechanism to enable or disable
  optional features on a target node.
- **xWindowsOptionalFeatureSet** provides a mechanism to configure and manage
  multiple xWindowsOptionalFeature resources on a target node.
- **xWindowsPackageCab** provides a mechanism to install or uninstall a package
  from a Windows cabinet (cab) file on a target node.
- **xWindowsProcess** provides a mechanism to start and stop a Windows process.
- **xProcessSet** allows starting and stopping of a group of windows processes
  with no arguments.

Resources that work on Nano Server:

- xGroup
- xService
- xScript
- xUser
- xWindowsOptionalFeature
- xWindowsOptionalFeatureSet
- xWindowsPackageCab

## Functions

### Publish-ModuleToPullServer

Publishes a 'ModuleInfo' object(s) to the pull server module repository or user
provided path. It accepts its input from a pipeline so it can be used in
conjunction with Get-Module as in 'Get-Module -Name ModuleName' |
Publish-Module

### Publish-MOFToPullServer

Publishes a 'FileInfo' object(s) to the pull server configuration repository. It
accepts FileInfo input from a pipeline so it can be used in conjunction with
Get-ChildItem .*.mof | Publish-MOFToPullServer
