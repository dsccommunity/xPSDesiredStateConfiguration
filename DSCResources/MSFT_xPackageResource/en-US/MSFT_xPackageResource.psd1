# Localized MSFT_xPackageResource.psd1

ConvertFrom-StringData @'
###PSLOC
InvalidIdentifyingNumber=The specified IdentifyingNumber ({0}) is not a valid Guid
InvalidPath=The specified Path ({0}) is not in a valid format. Valid formats are local paths, UNC, and HTTP
InvalidNameOrId=The specified Name ({0}) and IdentifyingNumber ({1}) do not match Name ({2}) and IdentifyingNumber ({3}) in the MSI file
NeedsMoreInfo=Either Name or ProductId is required
InvalidBinaryType=The specified Path ({0}) does not appear to specify an EXE or MSI file and as such is not supported
CouldNotOpenLog=The specified LogPath ({0}) could not be opened
CouldNotStartProcess=The process {0} could not be started
UnexpectedReturnCode=The return code {0} was not expected. Configuration is likely not correct
PathDoesNotExist=The given Path ({0}) could not be found
CouldNotOpenDestFile=Could not open the file {0} for writing
CouldNotGetHttpStream=Could not get the HTTP/HTTPS stream for file {0}
ErrorCopyingDataToFile=Encountered error while writing the contents of {0} to {1}
PackageConfigurationComplete=Package configuration finished
PackageConfigurationStarting=Package configuration starting
InstalledPackage=Installed package
UninstalledPackage=Uninstalled package
NoChangeRequired=Package found in desired state, no action required
RemoveExistingLogFile=Remove existing log file
CreateLogFile=Create log file
MountSharePath=Mount share to get media
DownloadHTTPFile=Download the media over HTTP/HTTPS
StartingProcessMessage=Starting process {0} with arguments {1}
RemoveDownloadedFile=Remove the downloaded file
PackageInstalled=Package has been installed
PackageUninstalled=Package has been uninstalled
MachineRequiresReboot=The machine requires a reboot
PackageDoesNotAppearInstalled=The package {0} is not installed
PackageAppearsInstalled=The package {0} is already installed
PostValidationError=Package from {0} was installed, but the specified ProductId and/or Name does not match package details
###PSLOC

'@

