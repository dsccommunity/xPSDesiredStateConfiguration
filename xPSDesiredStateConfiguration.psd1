@{
# Version number of this module.
moduleVersion = '8.4.0.0'

# ID used to uniquely identify this module
GUID = 'cc8dc021-fa5f-4f96-8ecf-dfd68a6d9d48'

# Author of this module
Author = 'Microsoft Corporation'

# Company or vendor of this module
CompanyName = 'Microsoft Corporation'

# Copyright statement for this module
Copyright = '(c) 2014 Microsoft Corporation. All rights reserved.'

# Description of the functionality provided by this module
Description = 'The xPSDesiredStateConfiguration module is a part of the Windows PowerShell Desired State Configuration (DSC) Resource Kit, which is a collection of DSC Resources produced by the PowerShell Team. This module contains the xDscWebService, xWindowsProcess, xService, xPackage, xArchive, xRemoteFile, xPSEndpoint and xWindowsOptionalFeature resources. Please see the Details section for more information on the functionalities provided by these resources.

All of the resources in the DSC Resource Kit are provided AS IS, and are not supported through any Microsoft standard support program or service. The "x" in xPSDesiredStateConfiguration stands for experimental, which means that these resources will be fix forward and monitored by the module owner(s).'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '4.0'

# Minimum version of the common language runtime (CLR) required by this module
CLRVersion = '4.0'

# Functions to export from this module
FunctionsToExport = '*'

# Cmdlets to export from this module
CmdletsToExport = '*'

#Root module
RootModule = 'DSCPullServerSetup\PublishModulesAndMofsToPullServer.psm1'

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('DesiredStateConfiguration', 'DSC', 'DSCResourceKit', 'DSCResource')

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/PowerShell/xPSDesiredStateConfiguration/blob/master/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/PowerShell/xPSDesiredStateConfiguration'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = '* Changes to xPSDesiredStateConfiguration
  * Opt-in for the common tests validate module files and script files.
  * All files change to encoding UTF-8 (without byte order mark).
  * Opt-in for the common test for example validation.
  * Added Visual Studio Code workspace settings that helps with formatting
    against the style guideline.
  * Update all examples for them to be able pass the common test validation.
* xEnvironment path documentation update demonstrating usage with multiple values  ([issue 415](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/415). [Alex Kokkinos (@alexkokkinos)](https://github.com/alexkokkinos)
* Changes to xWindowsProcess
  * Increased the wait time in the integration tests since the tests
    still failed randomly ([issue 420](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/420)).
* Renamed and updated examples to be able to publish them to PowerShell Gallery.
  * Sample\_xScript.ps1 to xScript\_WatchFileContentConfig.ps1
  * Sample\_xService\_UpdateStartupTypeIgnoreState.ps1 to xService\_UpdateStartupTypeIgnoreStateConfig.ps1
  * Sample\_xWindowsProcess\_Start.ps1 to xWindowsProcess\_StartProcessConfig.ps1
  * Sample\_xWindowsProcess\_StartUnderUser.ps1 to xWindowsProcess\_StartProcessUnderUserConfig.ps1
  * Sample\_xWindowsProcess\_Stop.ps1 to xWindowsProcess\_StopProcessConfig.ps1
  * Sample\_xWindowsProcess\_StopUnderUser.ps1 to xWindowsProcess\_StopProcessUnderUserConfig.ps1
  * Sample\_xUser\_CreateUser.ps1.ps1 to xUser\_CreateUserConfig.ps1
  * Sample\_xUser\_Generic.ps1.ps1 to xUser\_CreateUserDetailedConfig.ps1
  * Sample\_xWindowsFeature.ps1 to xWindowsFeature\_AddFeatureConfig.ps1
  * Sample\_xWindowsFeatureSet\_Install.ps1 to xWindowsFeatureSet\_AddFeaturesConfig.ps1
  * Sample\_xWindowsFeatureSet\_Uninstall.ps1 to xWindowsFeatureSet\_RemoveFeaturesConfig.ps1
  * Sample\_xRegistryResource\_AddKey.ps1 to xRegistryResource\_AddKeyConfig.ps1
  * Sample\_xRegistryResource\_RemoveKey.ps1 to xRegistryResource\_RemoveKeyConfig.ps1
  * Sample\_xRegistryResource\_AddOrModifyValue.ps1 to xRegistryResource\_AddOrModifyValueConfig.ps1
  * Sample\_xRegistryResource\_RemoveValue.ps1 to xRegistryResource\_RemoveValueConfig.ps1
  * Sample\_xService\_CreateService.ps1 to xService\_CreateServiceConfig.ps1
  * Sample\_xService\_DeleteService.ps1 to xService\_RemoveServiceConfig.ps1
  * Sample\_xServiceSet\_StartServices.ps1 to xServiceSet\_StartServicesConfig.ps1
  * Sample\_xServiceSet\_BuiltInAccount to xServiceSet\_EnsureBuiltInAccountConfig.ps1
  * Sample\_xWindowsPackageCab to xWindowsPackageCab\_InstallPackageConfig
  * Sample\_xWindowsOptionalFeature.ps1 to xWindowsOptionalFeature\_EnableConfig.ps1
  * Sample\_xWindowsOptionalFeatureSet\_Enable.ps1 to xWindowsOptionalFeatureSet\_EnableConfig.ps1
  * Sample\_xWindowsOptionalFeatureSet\_Disable.ps1 to xWindowsOptionalFeatureSet\_DisableConfig.ps1
  * Sample\_xRemoteFileUsingProxy.ps1 to xRemoteFile\_DownloadFileUsingProxyConfig.ps1
  * Sample\_xRemoteFile.ps1 to xRemoteFile\_DownloadFileConfig.ps1
  * Sample\_xProcessSet\_Start.ps1 to xProcessSet\_StartProcessConfig.ps1
  * Sample\_xProcessSet\_Stop.ps1 to xProcessSet\_StopProcessConfig.ps1
  * Sample\_xMsiPackage\_UninstallPackageFromHttps.ps1 to xMsiPackage\_UninstallPackageFromHttpsConfig.ps1
  * Sample\_xMsiPackage\_UninstallPackageFromFile.ps1 to xMsiPackage\_UninstallPackageFromFileConfig.ps1
  * Sample\_xMsiPackage\_InstallPackageFromFile to xMsiPackage\_InstallPackageConfig.ps1
  * Sample\_xGroup\_SetMembers.ps1 to xGroup\_SetMembersConfig.ps1
  * Sample\_xGroup\_RemoveMembers.ps1 to xGroup\_RemoveMembersConfig.ps1
  * Sample\_xGroupSet\_AddMembers.ps1 to xGroupSet\_AddMembersConfig.ps1
  * Sample\_xFileUpload.ps1 to xFileUpload\_UploadToSMBShareConfig.ps1
  * Sample\_xEnvironment\_CreateMultiplePathVariables.ps1 to xEnvironment\_AddMultiplePathsConfig.ps1
  * Sample\_xEnvironment\_RemovePathVariables.ps1 to xEnvironment\_RemoveMultiplePathsConfig.ps1
  * Sample\_xEnvironment\_CreateNonPathVariable.ps1 to xEnvironment\_CreateNonPathVariableConfig.ps1
  * Sample\_xEnvironment\_Remove.ps1 to xEnvironment\_RemoveVariableConfig.ps1
  * Sample\_xArchive\_ExpandArchiveChecksumAndForce.ps1 to xArchive\_ExpandArchiveChecksumAndForceConfig.ps1
  * Sample\_xArchive\_ExpandArchiveDefaultValidationAndForce.ps1 to xArchive\_ExpandArchiveDefaultValidationAndForceConfig.ps1
  * Sample\_xArchive\_ExpandArchiveNoValidation.ps1 to xArchive\_ExpandArchiveNoValidationConfig.ps1
  * Sample\_xArchive\_ExpandArchiveNoValidationCredential.ps1 to xArchive\_ExpandArchiveNoValidationCredentialConfig.ps1
  * Sample\_xArchive\_RemoveArchiveChecksum.ps1 to xArchive\_RemoveArchiveChecksumConfig.ps1
  * Sample\_xArchive\_RemoveArchiveNoValidation.ps1 to xArchive\_RemoveArchiveNoValidationConfig.ps1
  * Sample\_InstallExeCreds\_xPackage.ps1 to xPackage\_InstallExeUsingCredentialsConfig.ps1
  * Sample\_InstallExeCredsRegistry\_xPackage.ps1 to xPackage\_InstallExeUsingCredentialsAndRegistryConfig.ps1
  * Sample\_InstallMSI\_xPackage.ps1 to xPackage\_InstallMsiConfig.ps1
  * Sample\_InstallMSIProductId\_xPackage.ps1 to xPackage\_InstallMsiUsingProductIdConfig.ps1
* New examples
  * xUser\_RemoveUserConfig.ps1
  * xWindowsFeature\_AddFeatureUsingCredentialConfig.ps1
  * xWindowsFeature\_AddFeatureWithLogPathConfig.ps1
  * xWindowsFeature\_RemoveFeatureConfig.ps1
  * xService\_ChangeServiceStateConfig.ps1
  * xWindowsOptionalFeature\_DisableConfig.ps1
  * xPSEndpoint\_NewConfig.ps1
  * xPSEndpoint\_NewWithDefaultsConfig.ps1
  * xPSEndpoint\_RemoveConfig.ps1
  * xPSEndpoint\_NewCustomConfig.ps1
* Removed examples
  * Sample\_xPSSessionConfiguration.ps1 - This file was split up in several examples,
    those starting with "xPSEndpoint*".
  * Sample\_xMsiPackage\_InstallPackageFromHttp - This was added to the example
    xMsiPackage\_InstallPackageConfig.ps1 so the example sows either URI scheme.
  * Sample\_xEnvironment\_CreatePathVariable.ps1 - Same as the new example
    xEnvironment\_AddMultiplePaths.ps1

'

    } # End of PSData hashtable

} # End of PrivateData hashtable
}
