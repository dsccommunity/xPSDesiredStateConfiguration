# Localized    09/04/2013 09:53 AM (GMT)    303:4.80.0411     MSFT_ProcessResource.strings.psd1
# Localized resources for MSFT_xProcessResource

ConvertFrom-StringData @'
###PSLOC
FileNotFound=File not found in the environment path.
AbsolutePathOrFileName=Absolute path or file name expected.
InvalidArgument=Invalid argument: '{0}' with value: '{1}'.
InvalidArgumentAndMessage={0} {1}
ProcessStarted=Process matching path '{0}' started
ProcessesStopped=Proceses matching path '{0}' with Ids '({1})' stopped.
ProcessAlreadyStarted=Process matching path '{0}' found running and no action required.
ProcessAlreadyStopped=Process matching path '{0}' not found running and no action required.
ErrorStopping=Failure stopping processes matching path '{0}' with IDs '({1})'. Message: {2}.
ErrorStarting=Failure starting process matching path '{0}'. Message: {1}.
StartingProcessWhatif=Start-Process
ProcessNotFound=Process matching path '{0}' not found
PathShouldBeAbsolute="The path should be absolute"
PathShouldExist="The path should exist"
ParameterShouldNotBeSpecified="Parameter {0} should not be specified."
FailureWaitingForProcessesToStart="Failed to wait for processes to start"
FailureWaitingForProcessesToStop="Failed to wait for processes to stop"
###PSLOC

'@


