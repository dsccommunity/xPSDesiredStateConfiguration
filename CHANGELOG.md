# Change log for xPSDesiredStateConfiguration

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- xPSDesiredStateConfiguration
  - Added support for Checksum on xRemoteFile - [issue #423](https://github.com/PowerShell/PSDscResources/issues/423)
  - Added `Test-DscParameterState` support function to `xPSDesiredStateConfiguration.Common.psm1`.
  - Added standard unit tests for `xPSDesiredStateConfiguration.Common.psm1`.
  - Added automatic release with a new CI pipeline.

### Changed

- xPSDesiredStateConfiguration
  - PublishModulesAndMofsToPullServer.psm1:
    - Fixes issue in Publish-MOFToPullServer that incorrectly tries to create a
      new MOF file instead of reading the existing one.
      [issue #575](https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/575)
  - Fix minor style issues with missing spaces between `param` statements and '('.
  - MSFT_xDSCWebService:
    - Removal of commented out code.
    - Updated to meet HQRM style guidelines - Fixes [issue #623](https://github.com/PowerShell/PSDscResources/issues/623)
    - Added MOF descriptions.
  - Corrected minor style issues.
  - Fix minor style issues in hashtable layout.
  - Shared modules moved to `source/Modules` folder and renamed:
    - `CommonResourceHelper.psm1` -> `xPSDesiredStateConfiguration.Common.psm1`
    - `xPSDesiredStateConfiguration.psm1` -> `xPSDesiredStateConfiguration.ResourceSetHelper.psm1`
  - BREAKING CHANGE: Changed resource prefix from MSFT to DSC.
  - Pinned `ModuleBuilder` to v1.0.0.
  - Updated build badges in README.MD.
  - Remove unused localization strings.
  - Adopt DSC Community Code of Conduct.
  - DSC_xPSSessionConfiguration:
    - Moved strings to localization file.
  - DSC_xScriptResource:
    - Updated parameter descriptions to match MOF file.
  - Correct miscellaneous style issues.
- DSCPullServerSetup
  - Fixed markdown errors in README.MD.
  - Moved strings to Localization file.
  - Corrected style violations.
- DSC_xWindowsOptionalFeature
  - Fix localization strings.
- DSC_xEnvironmentResource
  - Remove unused localization strings.
- DSC_xDSCWebService
  - Merged util modules `Firewall.psm1`, `PSWSIISEndpoint.psm1`,
    `SecureTLSProtocols.psm1` and `UseSecurityBestPractices.psm1` into resource.
- BREAKING CHANGE: Renamed `PublishModulesAndMofsToPullServer` module to
  `DscPullServerSetup` and moved to Modules folder.

### Deprecated

- None

### Removed

- xPSDesiredStateConfiguration
  - Removed files no longer required by new CI process.

### Fixed

- None

### Security

- None
