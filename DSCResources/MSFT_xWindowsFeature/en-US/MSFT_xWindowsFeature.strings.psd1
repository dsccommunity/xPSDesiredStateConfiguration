# Localized strings for MSFT_xWindowsFeature.psd1

ConvertFrom-StringData @'
    SetTargetResourceInstallwhatIfMessage=Trying to install feature {0}
    SetTargetResourceUnInstallwhatIfMessage=Trying to Uninstall feature {0}
    FeatureNotFoundError=The requested feature {0} is not found on the target machine.
    FeatureDiscoveryFailureError=Failure to get the requested feature {0} information from the target machine. Wildcard pattern is not supported in the feature name.
    FeatureInstallationFailureError=Failure to successfully install the feature {0} .
    FeatureUnInstallationFailureError=Failure to successfully Unintstall the feature {0} .
    QueryFeature=Querying for feature {0} using Server Manager cmdlet Get-WindowsFeature.
    InstallFeature=Trying to install feature {0} using Server Manager cmdlet Add-WindowsFeature.
    UninstallFeature=Trying to Uninstall feature {0} using Server Manager cmdlet Remove-WindowsFeature.
    RestartNeeded=The Target machine needs to be restarted.
    GetTargetResourceStartVerboseMessage=Begin executing Get functionality on the {0} feature.
    GetTargetResourceEndVerboseMessage=End executing Get functionality on the {0} feature.
    SetTargetResourceStartVerboseMessage=Begin executing Set functionality on the {0} feature.
    SetTargetResourceEndVerboseMessage=End executing Set functionality on the {0} feature.
    TestTargetResourceStartVerboseMessage=Begin executing Test functionality on the {0} feature.
    TestTargetResourceEndVerboseMessage=End executing Test functionality on the {0} feature.
    ServerManagerModuleNotFoundDebugMessage=ServerManager module is not installed on the machine.
    SkuNotSupported=Installing roles and features using PowerShell Desired State Configuration is supported only on Server SKU's. It is not supported on Client SKU.
    SourcePropertyNotSupportedDebugMessage=Source property in MSFT_RoleResource is not supported on this operating system and it was ignored.
    EnableServerManagerPSHCmdletsFeature=Windows Server 2008R2 Core operating system detected: ServerManager-PSH-Cmdlets feature has been enabled.
    UninstallSuccess=Successfully uninstalled the feature {0}.
    InstallSuccess=Successfully installed the feature {0}.
'@
