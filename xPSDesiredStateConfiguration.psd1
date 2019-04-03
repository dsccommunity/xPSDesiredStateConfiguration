@{
    # Version number of this module.
    moduleVersion = '8.6.0.0'

    # ID used to uniquely identify this module
    GUID              = 'cc8dc021-fa5f-4f96-8ecf-dfd68a6d9d48'

    # Author of this module
    Author            = 'Microsoft Corporation'

    # Company or vendor of this module
    CompanyName       = 'Microsoft Corporation'

    # Copyright statement for this module
    Copyright         = '(c) Microsoft Corporation. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'The xPSDesiredStateConfiguration module is a part of the Windows PowerShell Desired State Configuration (DSC) Resource Kit, which is a collection of DSC Resources produced by the PowerShell Team. This module contains the xDscWebService, xWindowsProcess, xService, xPackage, xArchive, xRemoteFile, xPSEndpoint and xWindowsOptionalFeature resources. Please see the Details section for more information on the functionalities provided by these resources.

All of the resources in the DSC Resource Kit are provided AS IS, and are not supported through any Microsoft standard support program or service. The "x" in xPSDesiredStateConfiguration stands for experimental, which means that these resources will be fix forward and monitored by the module owner(s).'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '4.0'

    # Minimum version of the common language runtime (CLR) required by this module
    CLRVersion        = '4.0'

    # Functions to export from this module
    FunctionsToExport = '*'

    # Cmdlets to export from this module
    CmdletsToExport   = '*'

    # Root module
    RootModule        = 'DSCPullServerSetup\PublishModulesAndMofsToPullServer.psm1'

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResourceKit', 'DSCResource')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/PowerShell/xPSDesiredStateConfiguration/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/PowerShell/xPSDesiredStateConfiguration'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
        ReleaseNotes = '- Fixes style inconsistencies in PublishModulesAndMofsToPullServer.psm1.
  [issue 530](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/530)
- Suppresses forced Verbose output in MSFT_xArchive.EndToEnd.Tests.ps1,
  MSFT_xDSCWebService.Integration.tests.ps1,
  MSFT_xPackageResource.Integration.Tests.ps1, MSFT_xRemoteFile.Tests.ps1,
  MSFT_xUserResource.Integration.Tests.ps1,
  MSFT_xWindowsProcess.Integration.Tests.ps1, and
  xFileUpload.Integration.Tests.ps1.
  [issue 514](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/514)
- Fixes issue in xGroupResource Integration tests where the tests would fail
  if the System.DirectoryServices.AccountManagement namespace was not loaded.
- Tests\Integration\MSFT_xDSCWebService.Integration.tests.ps1:
  - Fixes issue where tests fail if a self signed certificate for DSC does not
    already exist.
    [issue 581](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/581)
- Fixes all instances of the following PSScriptAnalyzer issues:
  - PSUseOutputTypeCorrectly
  - PSAvoidUsingConvertToSecureStringWithPlainText
  - PSPossibleIncorrectComparisonWithNull
  - PSAvoidDefaultValueForMandatoryParameter
  - PSAvoidUsingInvokeExpression
  - PSUseDeclaredVarsMoreThanAssignments
  - PSAvoidGlobalVars
- xPackage and xMsiPackage
  - Add an ability to ignore a pending reboot if requested by package installation.
- xRemoteFile
  - Updated MatchSource description in README.md.
    [issue 409](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/409)
  - Improved layout of MOF file to move description left.
  - Added function help for all functions.
  - Moved `New-InvalidDataException` to CommonResourceHelper.psm1.
    [issue 544](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/544)
- Added full stops to the end of all functions help in CommonResourceHelper.psm1.
- Added unit tests for `New-InvalidArgumentException`,
  `New-InvalidDataException` and `New-InvalidOperationException`
  CommonResourceHelper.psm1 functions.
- Changes to `MSFT_xDSCWebService`
  - Fixed
    [issue 528](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/528)
    : Unable to disable selfsigned certificates using AcceptSelfSignedCertificates=$false
  - Fixed
    [issue 460](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/460)
    : Redeploy DSC Pull Server fails with error
- Opt-in to the following Meta tests:
  - Common Tests - Custom Script Analyzer Rules
  - Common Tests - Flagged Script Analyzer Rules
  - Common Tests - New Error-Level Script Analyzer Rules
  - Common Tests - Relative Path Length
  - Common Tests - Required Script Analyzer Rules
  - Common Tests - Validate Markdown Links
- Add .markdownlint.json file using settings from
  [here](https://raw.githubusercontent.com/PowerShell/SqlServerDsc/dev/.markdownlint.json)
  as a starting point.
- Changes to `Tests\Unit\MSFT_xMsiPackage.Tests.ps1`
  - Fixes issue where tests fail if executed from a drive other than C:.
    [issue 573](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/573)
- Changes to
  `Tests\Integration\xWindowsOptionalFeatureSet.Integration.Tests.ps1`
  - Fixes issue where tests fail if a Windows Optional Feature that is expected
    to be disabled has a feature state of "DisabledWithPayloadRemoved".
    [issue 586](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/586)
- Changes to
  `Tests\Unit\MSFT_xPackageResource.Tests.ps1`
  - Fixes issue where tests fail if run from a folder that contains spaces.
    [issue 580](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/580)
- Changes to test helper Enter-DscResourceTestEnvironment so that it only
  updates DSCResource.Tests when it is longer than 60 minutes since
  it was last pulled. This is to improve performance of test execution
  and reduce the likelihood of connectivity issues caused by inability to
  pull DSCResource.Tests.
  [issue 505](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/505)
- Updated `CommonTestHelper.psm1` to resolve style guideline violations.
- Adds helper functions for use when creating test administrator user accounts,
  and updates the following tests to use credentials created with these
  functions:
  - MSFT_xScriptResource.Integration.Tests.ps1
  - MSFT_xServiceResource.Integration.Tests.ps1
  - MSFT_xWindowsProcess.Integration.Tests.ps1
  - xServiceSet.Integration.Tests.ps1
- Fixes the following issues:
  - [issue 582](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/582)
  - [issue 583](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/583)
  - [issue 584](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/584)
  - [issue 585](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/585)

'

        } # End of PSData hashtable
    } # End of PrivateData hashtable
}


