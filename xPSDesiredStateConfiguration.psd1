@{
# Version number of this module.
ModuleVersion = '4.0.0.0'

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
        ReleaseNotes = '* xDSCWebService:
    * Added setting of enhanced security
    * Cleaned up Examples
    * Cleaned up pull server verification test
* xProcess:
    * Fixed PSSA issues
    * Corrected most style guideline issues
* xPSSessionConfiguration:
    * Fixed PSSA and style issues
    * Renamed internal functions to follow verb-noun formats
    * Decorated all functions with comment-based help
* xRegistry:
    * Fixed PSSA and style issues
    * Renamed internal functions to follow verb-noun format
    * Decorated all functions with comment-based help
    * Merged with in-box Registry
    * Fixed registry key and value removal
    * Added unit tests
* xService:
    * Added descriptions to MOF file.
    * Added additional details to parameters in Readme.md in a format that can be generated from the MOF.
    * Added DesktopInteract parameter.
    * Added standard help headers to *-TargetResource functions.
    * Changed indent/format of all function help headers to be consistent.
    * Fixed line length violations.
    * Changed localization code so only a single copy of localization strings are required.
    * Removed localization strings from inside module file.
    * Updated unit tests to use standard test enviroment configuration and header.
    * Recreated unit tests to be non-destructive.
    * Created integration tests.
    * Allowed service to be restarted immediately rather than wait for next LCM run.
    * Changed helper function names to valid verb-noun format.
    * Removed New-TestService function from MSFT_xServiceResource.TestHelper.psm1 because it should not be used.
    * Fixed error calling Get-TargetResource when service does not exist.
    * Fixed bug with Get-TargetResource returning StartupType "Auto" instead of "Automatic".
    * Converted to HQRM standards.
    * Removed obfuscation of exception in Get-Win32ServiceObject function.
    * Fixed bug where service start mode would be set to auto when it already was set to auto.
    * Fixed error message content when start mode can not be changed.
    * Removed shouldprocess from functions as not required.
    * Optimized Test-TargetResource and Set-TargetResource by removing repeated calls to Get-Service and Get-CimInstance.
    * Added integration test for testing changes to additional service properties as well as changing service binary path.
    * Modified Set-TargetResource so that newly created service created with minimal properties and then all additional properties updated (simplification of code).
    * Added support for changing Service Description and DisplayName parameters.
    * Fixed bug when changing binary path of existing service.
* Removed test log output from repo.
* xDSCWebService:
    * Added setting of enhanced security
    * Cleaned up Examples
    * Cleaned up pull server verification test
* xWindowsOptionalFeature:
    * Cleaned up resource (PSSA issues, formatting, etc.)
    * Added example script
    * Added integration test
    * BREAKING CHANGE: Removed the unused Source parameter
    * Updated to a high quality resource
* Removed test log output from repo.
* Removed the prefix MSFT_ from all files and folders of the composite resources in this module
because they were unavailable to Get-DscResource and Import-DscResource.
    * xFileUpload
    * xGroupSet
    * xProcessSet
    * xServiceSet
    * xWindowsFeatureSet
    * xWindowsOptionalFeatureSet

'

    } # End of PSData hashtable

} # End of PrivateData hashtable
}






