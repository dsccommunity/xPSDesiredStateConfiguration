@{
    # Version number of this module.
    moduleVersion = '8.5.0.0'

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
        ReleaseNotes = '- Pull server module publishing
  - Removed forced verbose logging from CreateZipFromSource, Publish-DSCModulesAndMof and Publish-MOFToPullServer as it polluted the console
- Corrected GitHub Pull Request template to remove referral to
  `BestPractices.MD` which has been combined into `StyleGuidelines.md`
  ([issue 520](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/520)).
- xWindowsOptionalFeature
  - Suppress useless verbose output from `Import-Module` cmdlet.
    ([issue 453](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/453)).
- Changes to xRemoteFile
  - Corrected a resource name in the example xRemoteFile_DownloadFileConfig.ps1
- Fix `MSFT_xDSCWebService` to find
 `Microsoft.Powershell.DesiredStateConfiguration.Service.Resources.dll`
  when server is configured with pt-BR Locales
  ([issue 284](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/284)).
- Changes to xDSCWebService
  - Fixed an issue which prevented the removal of the IIS Application Pool
    created during deployment of an DSC Pull Server instance.
    ([issue 464](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/464))
  - Fixed an issue where a Pull Server cannot be deployed on a machine when IIS
    Express is installed aside a full blown IIS
    ([issue 191](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/191))
- Update `CommonResourceHelper` unit tests to meet Pester 4.0.0
  standards
  ([issue 473](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/473)).
- Update `ResourceHelper` unit tests to meet Pester 4.0.0
  standards
  ([issue 473](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/473)).
- Update `MSFT_xDSCWebService` unit tests to meet Pester 4.0.0
  standards
  ([issue 473](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/473)).
- Update `MSFT_xDSCWebService` integration tests to meet Pester 4.0.0
  standards
  ([issue 473](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/473)).
- Refactored `MSFT_xDSCWebService` integration tests to meet current
  standards and to use Pester TestDrive.
- xArchive
  - Fix end-to-end tests
    ([issue 457](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/457)).
  - Update integration tests to meet Pester 4.0.0 standards.
  - Update end-to-end tests to meet Pester 4.0.0 standards.
  - Update unit and integration tests to meet Pester 4.0.0 standards.
  - Wrapped all path and identifier strings in verbose messages with
    quotes to make it easier to identify the limit of the string when
    debugging.
  - Refactored date/time checksum code to improve testability and ensure
    tests can run on machines with localized datetime formats that are not
    US.
  - Fix "Get-ArchiveEntryLastWriteTime" to return `[datetime]`
    ([issue 471](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/471)).
  - Improved verbose logging to make debugging path issues easier.
  - Added handling for "/" as a path seperator by backporting code from
    PSDscResources -
    ([issue 469](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/469)).
  - Copied unit tests from
    [PSDscResources](https://github.com/PowerShell/PSDscResources).
  - Added .gitattributes file and removed git configuration from AppVeyor
    to ensure CRLF settings are configured correctly for the repository.
- Updated ".vscode\settings.json" to refer to AnalyzerSettings.psd1 so that
  custom syntax problems are highlighted in Visual Studio Code.
- Fixed style guideline violations in `CommonResourceHelper.psm1`.
- Changes to xService
  - Fixes issue where Get-TargetResource or Test-TargetResource will throw an
    exception if the target service is configured with a non-existent
    dependency.
  - Refactored Get-TargetResource Unit tests.
- Changes to xPackage
  - Fixes an issue where incorrect verbose output was displayed if product
    found.
    ([issue 446](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/446))
- Fixes files which are getting triggered for re-encoding after recent pull
  request (possibly 472).
- Moves version and change history from README.MD to new file, CHANGELOG.MD.
- Fixes markdown issues in README.MD and HighQualityResourceModulePlan.md.
- Opted in to "Common Tests - Validate Markdown Files"
- Changes to xPSDesiredStateConfiguration
  - In AppVeyor CI the tests are split into three separate jobs, and also
    run tests on two different build worker images (Windows Server 2012R2
    and Windows Server 2016). The common tests are only run on the
    Windows Server 2016 build worker image. Helps with
    [issue 477](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/477).
- xGroup
  - Corrected style guideline violations. ([issue 485](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/485))
- xWindowsProcess
  - Corrected style guideline violations. ([issue 496](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/496))
- Changes to PSWSIISEndpoint.psm1
  - Fixes most PSScriptAnalyzer issues.
- Changes to xRegistry
  - Fixed an issue that fails to remove reg key when the `Key` is specified as
    common registry path.
    ([issue 444](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/444))
- Changes to xService
  - Added support for Group Managed Service Accounts
- Adds new Integration tests for MSFT_xDSCWebService and removes old
  Integration test file, MSFT_xDSCWebService.xxx.ps1.
- xRegistry
  - Corrected style guideline violations. ([issue 489](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/489))
...
Continued release notes can be found at https://github.com/PowerShell/xPSDesiredStateConfiguration/blob/dev/CHANGELOG.md
'

        } # End of PSData hashtable
    } # End of PrivateData hashtable
}

