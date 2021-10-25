# xPSDesiredStateConfiguration

[![Build Status](https://dev.azure.com/dsccommunity/xPSDesiredStateConfiguration/_apis/build/status/dsccommunity.xPSDesiredStateConfiguration?branchName=main)](https://dev.azure.com/dsccommunity/xPSDesiredStateConfiguration/_build/latest?definitionId=8&branchName=main)
![Code Coverage](https://img.shields.io/azure-devops/coverage/dsccommunity/xPSDesiredStateConfiguration/8/main)
[![Azure DevOps tests](https://img.shields.io/azure-devops/tests/dsccommunity/xPSDesiredStateConfiguration/8/main)](https://dsccommunity.visualstudio.com/xPSDesiredStateConfiguration/_test/analytics?definitionId=8&contextType=build)
[![PowerShell Gallery (with prereleases)](https://img.shields.io/powershellgallery/vpre/xPSDesiredStateConfiguration?label=xPSDesiredStateConfiguration%20Preview)](https://www.powershellgallery.com/packages/xPSDesiredStateConfiguration/)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/xPSDesiredStateConfiguration?label=xPSDesiredStateConfiguration)](https://www.powershellgallery.com/packages/xPSDesiredStateConfiguration/)
[![codecov](https://codecov.io/gh/dsccommunity/xPSDesiredStateConfiguration/branch/main/graph/badge.svg)](https://codecov.io/gh/dsccommunity/xPSDesiredStateConfiguration)

The **xPSDesiredStateConfiguration** module contains the same resources as
the module [PSDscResources](https://github.com/PowerShell/PSDscResources)
but also includes bugfixes and new features, including additional resources.
Some resources in this module use the prefix 'x' to not conflict with the
older built-in resources in the Windows PowerShell `PSDesiredStateConfiguration`
module and the `PSDscResources` module. The prefix 'x' has no other
meaning and does not indicate that these are experimental resources.

This module is no longer comparable with the module [PSDscResources](https://github.com/PowerShell/PSDscResources)
as they are completely separate modules and they have a different lifecycle.
The `xPSDesiredStateConfiguration` module surpasses the `PSDscResources`
module in both features and bugfixes.

The module xPSDesiredStateConfiguration is supported by the DSC community
who fixes bugs and adds features.

> The module [PSDscResources](https://github.com/PowerShell/PSDscResources)
> is supported by Microsoft and is meant to be 1:1 replacement for the
> built-in resources (in Windows PowerShell), with the exception for the
> File resource. For that reason new features are no longer being added to
> the PSDscResource module, and bugfixes must be approved (most likely through
> a Microsoft Support case) to be merged. If you require new features or
> missing bugfixes, please migrate to **xPSDesiredStateConfiguration** and
> request/add the features or bugfixes against this module.

This module is automatically tested using PowerShell 5.1 on servers running
Windows 2016 and Windows 2019, and is expected to work on other operating
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
- **xGroup** provides a mechanism to manage local groups on a target node.
- **xMsiPackage** provides a mechanism to install and uninstall .msi packages.
- **xPackage** manages the installation of .msi and .exe packages.
- **xRegistry** provides a mechanism to manage registry keys and values on a
  target node.
- **xRemoteFile** ensures the presence of remote files on a local machine.
- **xScript** provides a mechanism to run PowerShell script blocks on a target
  node.
- **xService** provides a mechanism to configure and manage Windows services.
- **xUser** provides a mechanism to manage local users on the target node.
- **xWindowsFeature** provides a mechanism to install or uninstall Windows
  roles or features on a target node.
- **xWindowsOptionalFeature** provides a mechanism to enable or disable
  optional features on a target node.
- **xWindowsPackageCab** provides a mechanism to install or uninstall a package
  from a Windows cabinet (cab) file on a target node.
- **xWindowsProcess** provides a mechanism to start and stop a Windows process.

## Composite Resources

- **xFileUpload** is a composite resource which ensures that local files exist
  on an SMB share.
- **xGroupSet** provides a mechanism to configure and manage multiple xGroup
  resources with common settings but different names.
- **xProcessSet** allows starting and stopping of a group of windows processes
  with no arguments.
- **xServiceSet** provides a mechanism to configure and manage multiple
  xService resources with common settings but different names.
- **xWindowsFeatureSet** provides a mechanism to configure and manage multiple
  xWindowsFeature resources on a target node.
- **xWindowsOptionalFeatureSet** provides a mechanism to configure and manage
  multiple xWindowsOptionalFeature resources on a target node.

## Nano Server Support

The following resources and composite resources work on Nano Server:

- xGroup
- xService
- xScript
- xUser
- xWindowsOptionalFeature
- xWindowsOptionalFeatureSet
- xWindowsPackageCab

## Register a Node with DSC Pull Server

This module contains an example meta configuration that can be used to configure
the Local Configuration Manager to register with a DSC Pull Server.

[LCM Register Node](\source\Examples\LCM\1-LCM_RegisterNode_Config.ps1)

## Functions

This resource also contains support functions that can be used to manage a deployed
DSC pull server.

### Publish-ModuleToPullServer

Publishes a 'ModuleInfo' object(s) to the pull server module repository or user
provided path. It accepts its input from a pipeline so it can be used in
conjunction with Get-Module as in 'Get-Module -Name ModuleName' |
Publish-Module

### Publish-MofToPullServer

Publishes a 'FileInfo' object(s) to the pull server configuration repository. It
accepts FileInfo input from a pipeline so it can be used in conjunction with
Get-ChildItem .*.mof | Publish-MOFToPullServer
