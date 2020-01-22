@{
    # Root module
    RootModule        = 'Modules\DscPullServerSetup\DscPullServerSetup.psm1'

    # Version number of this module.
    moduleVersion     = '0.0.1'

    # ID used to uniquely identify this module
    GUID              = 'cc8dc021-fa5f-4f96-8ecf-dfd68a6d9d48'

    # Author of this module
    Author            = 'DSC Community'

    # Company or vendor of this module
    CompanyName       = 'DSC Community'

    # Copyright statement for this module
    Copyright         = 'Copyright the DSC Community contributors. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'DSC resources for configuring common operating systems features, files and settings.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '4.0'

    # Minimum version of the common language runtime (CLR) required by this module
    CLRVersion        = '4.0'

    # Functions to export from this module
    FunctionsToExport = @(
        'Publish-DscModuleAndMof',
        'Publish-ModulesAndChecksum',
        'Publish-MofsInSource',
        'Publish-ModuleToPullServer',
        'Publish-MofToPullServer'
    )

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport   = @()

    # DSC resources to export from this module
    DscResourcesToExport  = @(
        'xArchive', 'xDSCWebService', 'xEnvironment','xGroup','xMsiPackage',
        'xPackage','xPSEndpoint','xRegistry','xRemoteFile',
        'xScript','xService','xUser','xWindowsFeature','xWindowsOptionalFeature',
        'xWindowsPackageCab','xWindowsProcess'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        PSData = @{
            # Set to a prerelease string value if the release should be a prerelease.
            Prerelease   = ''

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResourceKit', 'DSCResource')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/dsccommunity/xPSDesiredStateConfiguration/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/dsccommunity/xPSDesiredStateConfiguration'

            # A URL to an icon representing this module.
            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            # ReleaseNotes of this module
            ReleaseNotes = ''
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}
