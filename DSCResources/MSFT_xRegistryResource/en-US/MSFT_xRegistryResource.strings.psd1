# Localized    10/30/2015 03:58 AM (GMT)    303:4.80.0411     MSFT_xRegistryResource.strings.psd1
# Localized resources for MSFT_xRegistryResource

ConvertFrom-StringData @'
###PSLOC
ParameterValueInvalid=(ERROR) Parameter '{0}' has an invalid value '{1}' for type '{2}'
InvalidPSDriveSpecified=(ERROR) Invalid PSDrive '{0}' specified in registry key '{1}'
InvalidRegistryHiveSpecified=(ERROR) Invalid registry hive was specified in registry key '{0}'
SetRegValueFailed=(ERROR) Failed to set registry key value '{0}' to value '{1}' of type '{2}'
SetRegValueUnchanged=(UNCHANGED) No change to registry key value '{0}' containing '{1}'
SetRegKeyUnchanged=(UNCHANGED) No change to registry key '{0}'
SetRegValueSucceeded=(SET) Set registry key value '{0}' to '{1}' of type '{2}'
SetRegKeySucceeded=(SET) Create registry key '{0}'
SetRegKeyFailed=(ERROR) Failed to created registry key '{0}'
RemoveRegKeyTreeFailed=(ERROR) Registry Key '{0}' has subkeys, cannot remove without Force flag
RemoveRegKeySucceeded=(REMOVAL) Registry key '{0}' removed
RemoveRegKeyFailed=(ERROR) Failed to remove registry key '{0}'
RemoveRegValueSucceeded=(REMOVAL) Registry key value '{0}' removed
RemoveRegValueFailed=(ERROR) Failed to remove registry key value '{0}'
RegKeyDoesNotExist=Registry key '{0}' does not exist
RegKeyExists=Registry key '{0}' exists
RegValueExists=Found registry key value '{0}' with type '{1}' and data '{2}'
RegValueDoesNotExist=Registry key value '{0}' does not exist
RegValueTypeMismatch=Registry key value '{0}' of type '{1}' does not exist
RegValueDataMismatch=Registry key value '{0}' of type '{1}' does not contain data '{2}'
DefaultValueDisplayName=(Default)
###PSLOC
'@
