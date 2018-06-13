@{
# Version number of this module.
moduleVersion = '8.3.0.0'

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
  * README.md: Fixed typo. [Steve Banik (@stevebanik-ndsc)](https://github.com/stevebanik-ndsc)
  * Adding a Branches section to the README.md with Codecov badges for both
    master and dev branch ([issue 416](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/416)).
* Changes to xWindowsProcess
  * Integration tests for this resource should no longer fail randomly. A timing
    issue made the tests fail in certain scenarios ([issue 420](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/420)).
* Changes to xDSCWebService
    * Added the option to use a certificate based on it"s subject and template name instead of it"s thumbprint. Resolves [issue 205](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/205).
    * xDSCWebService: Fixed an issue where Test-WebConfigModulesSetting would return $true when web.config contains a module and the desired state was for it to be absent. Resolves [issue 418](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/418).
* Updated the main DSCPullServerSetup readme to read easier, then updates the PowerShell comment based help for each function to follow normal help standards. [James Pogran (@jpogran)](https://github.com/jpogran)
* xRemoteFile: Remove progress bar for file download. This resolves issues [165](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/165) and [383](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/383) [Claudio Spizzi (@claudiospizzi)](https://github.com/claudiospizzi)

'

    } # End of PSData hashtable

} # End of PrivateData hashtable
}



















