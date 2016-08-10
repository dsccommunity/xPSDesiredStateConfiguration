data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData @"
ServiceNotFound=Service '{0}' not found.
CannotStartAndDisable=Cannot start and disable a service.
CannotStopServiceSetToStartAutomatically=Cannot stop a service and set it to start automatically.
ServiceAlreadyStarted=Service '{0}' already started, no action required.
ServiceStarted=Service '{0}' started.
ServiceStopped=Service '{0}' stopped.
ErrorStartingService=Failure starting service '{0}'. Please check the path '{1}' provided for the service. Message: '{2}'
OnlyOneParameterCanBeSpecified=Only one of the following parameters can be specified: '{0}', '{1}'.
StartServiceWhatIf=Start Service
StopServiceWhatIf=Stop Service
ServiceAlreadyStopped=Service '{0}' already stopped, no action required.
ErrorStoppingService=Failure stopping service '{0}'. Message: '{1}'
ErrorRetrievingServiceInformation=Failure retrieving information for service '{0}'. Message: '{1}'
ErrorSettingServiceCredential=Failure setting credentials for service '{0}'. Message: '{1}'
SetCredentialWhatIf=Set Credential
SetStartupTypeWhatIf=Set Start Type
ErrorSettingServiceStartupType=Failure setting start type for service '{0}'. Message: '{1}'
TestBinaryPathMismatch=Binary path for service '{0}' is '{1}'. It does not match '{2}'.
TestUserNameMismatch=User name for service '{0}' is '{1}'. It does not match '{2}'.
TestStartupTypeMismatch=Startup type for service '{0}' is '{1}'. It does not match '{2}'.
TestStateMismatch=State of service '{0}' is '{1}'. It does not match '{2}'.
MethodFailed=The '{0}' method of '{1}' failed with error code: '{2}'.
ErrorChangingProperty=Failed to change '{0}' property. Message: '{1}'
ErrorSettingLogOnAsServiceRightsForUser=Error granting '{0}' the right to log on as a service. Message: '{1}'.
CannotOpenPolicyErrorMessage=Cannot open policy manager
UserNameTooLongErrorMessage=User name is too long
CannotLookupNamesErrorMessage=Failed to lookup user name
CannotOpenAccountErrorMessage=Failed to open policy for user
CannotCreateAccountAccessErrorMessage=Failed to create policy for user
CannotGetAccountAccessErrorMessage=Failed to get user policy rights
CannotSetAccountAccessErrorMessage=Failed to set user policy rights
BinaryPathNotSpecified=Specify the path to the executable when trying to create a new service
ServiceAlreadyExists=The service '{0}' to create already exists
ServiceExistsSamePath=The service '{0}' to create already exists with path '{1}'
ServiceNotExists=The service '{0}' does not exist. Specify the path to the executable to create a new service
ErrorDeletingService=Error in deleting service '{0}'
ServiceDeletedSuccessfully=Service '{0}' Deleted Successfully
TryDeleteAgain=Wait for 2 milliseconds for a service to get deleted
WritePropertiesIgnored=Service '{0}' already exists. Write properties such as Status, DisplayName, Description, Dependencies will be ignored for existing services.
"@
}

# Commented-out until more languages are supported
# Import-LocalizedData LocalizedData -FileName 'MSFT_xServiceResource.strings.psd1'

function Get-TargetResource
{
    [OutputType([Hashtable])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name
    )

    $service = Get-ServiceResource -Name $Name
    $win32ServiceObject = Get-Win32ServiceObject -Name $Name

    $builtInAccount = $null

    if ($win32ServiceObject.StartName -ieq "LocalSystem") 
    {
        $builtInAccount ="LocalSystem"
    }
    elseif ($win32ServiceObject.StartName -ieq "NT Authority\NetworkService") 
    {
        $builtInAccount = "NetworkService"
    }
    elseif ($win32ServiceObject.StartName -ieq "NT Authority\LocalService") 
    {
        $builtInAccount = "LocalService"
    }

    $dependencies = @()

    foreach ($serviceDependedOn in $service.ServicesDependedOn)
    {
        $dependencies += $serviceDependedOn.Name.ToString()
    }

    return @{
        Name = $service.Name
        StartupType = $win32ServiceObject.StartMode.ToString()
        BuiltInAccount = $builtInAccount
        State = $service.Status.ToString()
        Path = $win32ServiceObject.PathName
        DisplayName = $service.DisplayName
        Description = $win32ServiceObject.Description
        Dependencies = $dependencies
    }
}

function Test-TargetResource
{
    [OutputType([Boolean])]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [ValidateSet("Automatic", "Manual", "Disabled")]
        [String]
        $StartupType,
        
        [ValidateSet("LocalSystem", "LocalService", "NetworkService")]
        [String]
        $BuiltInAccount,
        
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential,
   
        [ValidateSet("Running", "Stopped")]
        [String]
        $State = "Running",
       
        [ValidateSet("Present", "Absent")]
        [String]
        $Ensure = "Present",
  
        [ValidateNotNullOrEmpty()]
        [String]
        $Path,
 
        [ValidateNotNullOrEmpty()]
        [String]
        $DisplayName,

        [ValidateNotNull()]
        [String]
        $Description,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Dependencies,

        [uint32]
        $StartupTimeout = 30000,

        [uint32]
        $TerminateTimeout = 30000
    )

    if ($PSBoundParameters.ContainsKey('StartupType')) 
    {
        Test-StartupType -Name $Name -StartupType $StartupType -State $State
    }

    $serviceExists = Test-ServiceExists -Name $Name -ErrorAction SilentlyContinue

    if ($Ensure -eq 'Absent')
    {
        return -not $serviceExists
    }

    if (-not $serviceExists)
    {
        return $false
    }

    $svc = Get-TargetResource -Name $Name
    $svcWmi = Get-Win32ServiceObject -Name $Name

    # Check the binary path
    if ($PSBoundParameters.ContainsKey("Path") -and -not (Compare-ServicePath -Name $Name -Path $Path))
    {
        Write-Verbose -Message ($LocalizedData.TestBinaryPathMismatch -f $svcWmi.Name, $svcWmi.PathName, $Path)
        return $false
    }

    # Check the optional parameters
    if ($PSBoundParameters.ContainsKey("StartupType") -or $PSBoundParameters.ContainsKey("BuiltInAccount") -or $PSBoundParameters.ContainsKey("Credential"))
    {
        $getUserNameAndPasswordArgs = @{}
        if($PSBoundParameters.ContainsKey("BuiltInAccount")) {$null=$getUserNameAndPasswordArgs.Add("BuiltInAccount",$BuiltInAccount)}
        if($PSBoundParameters.ContainsKey("Credential")) {$null=$getUserNameAndPasswordArgs.Add("Credential",$Credential)}

        $userName,$password=GetUserNameAndPassword @getUserNameAndPasswordArgs
        if($userName -ne $null -and !(TestUserName $SvcWmi $userName))
        {
            Write-Verbose -Message ($LocalizedData.TestUserNameMismatch -f $svcWmi.Name,$svcWmi.StartName,$userName)
            return $false
        }

        if ($PSBoundParameters.ContainsKey("StartupType") -and $SvcWmi.StartMode -ine (ConvertTo-StartModeString -StartupType $StartupType))
        {
            Write-Verbose -Message ($LocalizedData.TestStartupTypeMismatch -f $svcWmi.Name,$svcWmi.StartMode,$StartupType)
            return $false
        }
    }

    if ($State -ne $svc.State)
    {
        Write-Verbose -Message ($LocalizedData.TestStateMismatch -f $svcWmi.Name, $svc.State, $State)
        return $false
    }

    return $true
}

function Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,
 
        [ValidateSet("Automatic", "Manual", "Disabled")]
        [String]
        $StartupType,

        [ValidateSet("LocalSystem", "LocalService", "NetworkService")]
        [String]
        $BuiltInAccount,

        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential,
 
        [ValidateSet("Running", "Stopped")]
        [String]
        $State = "Running",

        [ValidateSet("Present", "Absent")]
        [String]
        $Ensure = "Present",

        [ValidateNotNullOrEmpty()]
        [String]
        $Path,
  
        [ValidateNotNullOrEmpty()]
        [String]
        $DisplayName,

        [ValidateNotNull()]
        [String]
        $Description,
        
        [ValidateNotNullOrEmpty()]
        [String[]]
        $Dependencies,

        [uint32]
        $StartupTimeout = 30000,

        [uint32]
        $TerminateTimeout = 30000
    )

    if ($PSBoundParameters.ContainsKey('StartupType')) 
    {
        Test-StartupType -Name $Name -StartupType $StartupType -State $State
    }

    if ($Ensure -eq "Absent")
    {
        Stop-ServiceResource -Name $Name -TerminateTimeout $TerminateTimeout
        DeleteService $Name
        return
    }

    $serviceExists = Test-ServiceExists -Name $Name -ErrorAction SilentlyContinue
    $serviceIsNew = $false

    if ($PSBoundParameters.ContainsKey("Path") -and $serviceExists)
    {
        if (-not (Compare-ServicePath -Name $Name -Path $Path))
        {
            # Update the path
        }
    }
    elseif ($PSBoundParameters.ContainsKey("Path") -and -not $serviceExists)
    {
        $argumentsToNewService = @{}
        $argumentsToNewService.Add("Name", $Name)
        $argumentsToNewService.Add("BinaryPathName", $Path)
        if($PSBoundParameters.ContainsKey("Credential"))
        {
            $argumentsToNewService.Add("Credential", $Credential)
        }
        if($PSBoundParameters.ContainsKey("StartupType"))
        {
            $argumentsToNewService.Add("StartupType", $StartupType)
        }
        if($PSBoundParameters.ContainsKey("DisplayName"))
        {
            $argumentsToNewService.Add("DisplayName", $DisplayName)
        }
        if($PSBoundParameters.ContainsKey("Description"))
        {
            $argumentsToNewService.Add("Description", $Description)
        }
        if($PSBoundParameters.ContainsKey("Dependencies"))
        {
            $argumentsToNewService.Add("DependsOn", $Dependencies)
        }

        try
        {
            New-Service @argumentsToNewService
            $serviceIsNew = $true
        }
        catch
        {
            Write-Verbose -Message ("Error creating service `"$($argumentsToNewService["Name"])`"; Exception Message: $($_.Exception.Message)")
            throw $_
        }
    }
    elseif (-not $PSBoundParameters.ContainsKey("Path") -and -not $serviceExists)
    {
        throw $LocalizedData.ServiceNotExists -f $Name
    }

    $svc = Get-TargetResource -Name $Name

    if (-not $serviceIsNew)
    {
       Write-Verbose -Message ($LocalizedData.WritePropertiesIgnored -f $Name) 
    }

    $writeWritePropertiesArguments = @{
        Name = $Name
    }

    if ($PSBoundParameters.ContainsKey('Path')) 
    {
        $writeWritePropertiesArguments['Path'] = $Path
    }
    
    if ($PSBoundParameters.ContainsKey('StartupType')) 
    {
        $writeWritePropertiesArguments['StartupType'] = $StartupType
    }
    
    if ($PSBoundParameters.ContainsKey('BuiltInAccount')) 
    {
        $writeWritePropertiesArguments['BuiltInAccount'] = $BuiltInAccount
    }
    
    if ($PSBoundParameters.ContainsKey('Credential')) 
    {
        $writeWritePropertiesArguments['Credential'] = $Credential
    }

    $requiresRestart = WriteWriteProperties @writeWritePropertiesArguments

    # if the service needs to be restarted then go ahead and stop it now in preparation for the next check
    if ($requiresRestart)
    {
        Write-Verbose -Message "Service needs to be restarted."
        Stop-ServiceResource -Name $Name -TerminateTimeout $TerminateTimeout
    }
    elseif ($State -eq "Stopped")
    {
        # Ensure service is stopped
        Stop-ServiceResource -Name $Name -TerminateTimeout $TerminateTimeout
    }
    elseif ($State -eq "Running")
    {
        Start-ServiceResource $Name -StartupTimeout $StartupTimeout
    }
}

<#
    .SYNOPSIS
    Tests if the given StartupType with valid with the given State parameter for the service with the given name.

    .PARAMETER Name
    The name of the service for which to check the StartupType and State
    (For error message only)

    .PARAMETER StartupType
    The StartupType to test.

    .PARAMETER State
    The State to test against.
#>
function Test-StartupType
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Automatic", "Manual", "Disabled")]
        [String]
        $StartupType,
        
        [ValidateSet("Running", "Stopped")]
        [String]
        $State = "Running"
    )

    if ($State -eq "Stopped")
    {
        if ($StartupType -eq "Automatic")
        {
            # State = Stopped conflicts with Automatic or Delayed
            ThrowInvalidArgumentError -ErrorId "CannotStopServiceSetToStartAutomatically" -ErrorMessage ($LocalizedData.CannotStopServiceSetToStartAutomatically -f $Name)
        }
    }
    else
    {
        if ($StartupType -eq "Disabled")
        {
            # State = Running conflicts with Disabled
            ThrowInvalidArgumentError -ErrorId "CannotStartAndDisable" -ErrorMessage ($LocalizedData.CannotStartAndDisable -f $Name)
        }
    }
}

<#
    .SYNOPSIS
        Converts the StartupType string to the correct StartMode string returned in the Win32 service object.

    .PARAMETER StartupType
        The StartupType to convert.
#>
function ConvertTo-StartModeString
{
    [OutputType([String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Automatic', 'Manual', 'Disabled')]
        [String] $StartupType
    )

    if ($StartupType -eq 'Automatic')
    {
        return 'Auto'
    }
    else
    {
        return $StartupType
    }
}

<#
    .SYNOPSIS
    Writes all write properties if not already correctly set, logging errors and respecting whatif
#>
function WriteWriteProperties
{
    [OutputType([System.Boolean])]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Name,

        [System.String]
        [ValidateNotNullOrEmpty()]
        $Path,

        [System.String]
        [ValidateSet("Automatic", "Manual", "Disabled")]
        $StartupType,

        [System.String]
        [ValidateSet("LocalSystem", "LocalService", "NetworkService")]
        $BuiltInAccount,

        [System.Management.Automation.PSCredential]
        [ValidateNotNull()]
        $Credential
    )

    $svcWmi = Get-Win32ServiceObject -Name $Name
    $requiresRestart = $false

    # update binary path
    if ($PSBoundParameters.ContainsKey('Path'))
    {
        $writeBinaryArguments = @{
            SvcWmi = $svcWmi
            Path = $Path
        }

        $requiresRestart = $requiresRestart -or (WriteBinaryProperties @writeBinaryArguments)
    }

    # update credentials
    if($PSBoundParameters.ContainsKey("BuiltInAccount") -or $PSBoundParameters.ContainsKey("Credential"))
    {
        $writeCredentialPropertiesArguments=@{"SvcWmi"=$svcWmi}

        if($PSBoundParameters.ContainsKey("BuiltInAccount"))
        {
            $null=$writeCredentialPropertiesArguments.Add("BuiltInAccount",$BuiltInAccount)
        }

        if($PSBoundParameters.ContainsKey("Credential"))
        {
            $null=$writeCredentialPropertiesArguments.Add("Credential",$Credential)
        }

        WriteCredentialProperties @writeCredentialPropertiesArguments
    }

    # Update startup type
    if($PSBoundParameters.ContainsKey("StartupType"))
    {
        Set-ServiceStartupType -Win32ServiceObject $svcWmi -StartupType $StartupType
    }

    # Return restart status
    return $requiresRestart
}

<#
    .SYNOPSIS
    Retrieves the Win32_Service object for the service with the given name.

    .PARAMETER Name
    The name of the service for which to get the Win32_Service object
#>
function Get-Win32ServiceObject
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        $Name
    )

    try
    {
        return Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'"
    }
    catch
    {
        Write-Verbose -Message ($LocalizedData.ErrorRetrievingServiceInformation -f $Name,$_.Exception.Message)
        throw
    }
}

<#
    .SYNOPSIS
    Sets the StartupType property of the given service to the given value.

    .PARAMETER Win32ServiceObject
    The Win32_Service object for which to set the StartupType

    .PARAMETER StartupType
    The StartupType to set
#>
function Set-ServiceStartupType
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Win32ServiceObject,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Automatic", "Manual", "Disabled")]
        [String]
        $StartupType
    )

    if ($Win32ServiceObject.StartMode -ine $StartupType -and $PSCmdlet.ShouldProcess($Win32ServiceObject.Name, $LocalizedData.SetStartupTypeWhatIf))
    {
        $changeServiceArguments = @{
            StartMode = $StartupType
        }

        $changeResult = Invoke-CimMethod -InputObject $Win32ServiceObject -MethodName Change -Arguments $changeServiceArguments

        if ($changeResult.ReturnValue -ne 0)
        {
            $methodFailedMessage = $LocalizedData.MethodFailed -f "Change", "Win32_Service", $changeResult.ReturnValue
            $errorChangingPropertyMessage = $LocalizedData.ErrorChangingProperty -f "StartupType", $innerMessage
            ThrowInvalidArgumentError -ErrorId "ChangeStartupTypeFailed" -ErrorMessage $errorChangingPropertyMessage
        }
    }
}

<#
.Synopsis
Writes credential properties if not already correctly set, logging errors and respecting whatif
#>
function WriteCredentialProperties
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (

        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $SvcWmi,

        [System.String]
        [ValidateSet("LocalSystem", "LocalService", "NetworkService")]
        $BuiltInAccount,

        [System.Management.Automation.PSCredential]
        $Credential
    )

    if(!$PSBoundParameters.ContainsKey("Credential") -and !$PSBoundParameters.ContainsKey("BuiltInAccount"))
    {
        return
    }

    if($PSBoundParameters.ContainsKey("Credential") -and $PSBoundParameters.ContainsKey("BuiltInAccount"))
    {
        ThrowInvalidArgumentError -ErrorId "OnlyCredentialOrBuiltInAccount" -ErrorMessage ($LocalizedData.OnlyOneParameterCanBeSpecified -f "Credential","BuiltInAccount")
    }

    $getUserNameAndPasswordArgs=@{}
    if($PSBoundParameters.ContainsKey("BuiltInAccount")) {$null=$getUserNameAndPasswordArgs.Add("BuiltInAccount",$BuiltInAccount)}
    if($PSBoundParameters.ContainsKey("Credential")) {$null=$getUserNameAndPasswordArgs.Add("Credential",$Credential)}

    $userName,$password=GetUserNameAndPassword @getUserNameAndPasswordArgs

    if($userName -ne $null -and !(TestUserName $SvcWmi $userName) -and $PSCmdlet.ShouldProcess($SvcWmi.Name,$LocalizedData.SetCredentialWhatIf))
    {
        if($PSBoundParameters.ContainsKey("Credential"))
        {
            SetLogOnAsServicePolicy $userName
        }

        $ret = Invoke-CimMethod -InputObject $SvcWmi -MethodName Change -Arguments @{StartName=$userName;StartPassword=$password}
        if($ret.ReturnValue -ne 0)
        {
            $innerMessage = $LocalizedData.MethodFailed -f "Change","Win32_Service",$ret.ReturnValue
            $message = $LocalizedData.ErrorChangingProperty -f "Credential",$innerMessage
            ThrowInvalidArgumentError -ErrorId "ChangeCredentialFailed" -ErrorMessage $message
        }
    }
}

<#
.Synopsis
Writes binary path if not already correctly set, logging errors and respecting whatif
#>
function WriteBinaryProperties
{
    [OutputType([System.Boolean])]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $SvcWmi,

        [System.String]
        [ValidateNotNullOrEmpty()]
        $Path
    )

    if($SvcWmi.PathName -eq $Path)
    {
        return $false
    }

    $ret = $SvcWmi.Change($null, $Path, $null, $null, $null, $null, $null, $null)
    if($ret.ReturnValue -ne 0)
    {
        $innerMessage = $LocalizedData.MethodFailed -f "Change","Win32_Service",$ret.ReturnValue
        $message = $LocalizedData.ErrorChangingProperty -f "Binary Path",$innerMessage
        ThrowInvalidArgumentError -ErrorId "ChangeBinaryPathFailed" -ErrorMessage $message
    }

    return $true
}

<#
.Synopsis
Returns true if the service's StartName matches $UserName
#>
function TestUserName
{
    param
    (
        $SvcWmi,

        [string]
        $UserName
    )

    return  (NormalizeUserName -UserName $SvcWmi.StartName) -ieq $UserName
}

<#
.Synopsis
Retrieves user name and password out of the BuiltInAccount and Credential parameters
#>
function GetUserNameAndPassword
{
    param
    (
        [System.String]
        [ValidateSet("LocalSystem", "LocalService", "NetworkService")]
        $BuiltInAccount,

        [System.Management.Automation.PSCredential]
        $Credential
    )

    if($PSBoundParameters.ContainsKey("BuiltInAccount"))
    {
        return (NormalizeUserName -UserName $BuiltInAccount.ToString()),$null
    }

    if($PSBoundParameters.ContainsKey("Credential"))
    {
        return (NormalizeUserName -UserName $Credential.UserName),$Credential.GetNetworkCredential().Password
    }

    return $null,$null
}

<#
    .SYNOPSIS
    Stops a service if it is not already stopped.

    .PARAMETER Name
    The name of the service to stop.

    .PARAMETER TerminateTimeout
    The amount of time to wait for the service to stop.
#>
function Stop-ServiceResource
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String]
        $Name,

        [Parameter(Mandatory = $true)]
        [uint32]
        $TerminateTimeout
    )

    $service = Get-ServiceResource -Name $Name

    if ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Stopped)
    {
        Write-Verbose -Message ($LocalizedData.ServiceAlreadyStopped -f  $service.Name)
        return
    }

    if ($PSCmdlet.ShouldProcess($Name, $LocalizedData.StopServiceWhatIf))
    {
        try
        {
            $service.Stop()
            $waitTimeSpan = New-Object -TypeName TimeSpan -ArgumentList ($TerminateTimeout * 10000)
            $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped, $waitTimeSpan)
        }
        catch
        {
            Write-Verbose -Message ($LocalizedData.ErrorStoppingService -f $service.Name, $_.Exception.Message)
            throw
        }

        Write-Verbose -Message ($LocalizedData.ServiceStopped -f $service.Name)
    }
}

<#
.Synopsis
Deletes a service
#>
function DeleteService
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Name
    )
    
    $err = & "sc.exe" "delete" "$Name"
    for($i = 1; $i -lt 1000; $i++)
    {
        if(-not (Test-ServiceExists -Name $Name))
        {
            $serviceDeletedSuccessfully = $true
            break
        }
        #try again after 2 millisecs if the service is not deleted.
        Write-Verbose -Message ($LocalizedData.TryDeleteAgain)
        Start-Sleep .002
    }
    if (-not $serviceDeletedSuccessfully)
    {
        Write-Verbose -Message ($LocalizedData.ErrorDeletingService -f $Name)
        throw $LocalizedData.ErrorDeletingService -f $Name
    }
    else
    {
        Write-Verbose -Message ($LocalizedData.ServiceDeletedSuccessfully -f $Name)
    }
}

<#
    .SYNOPSIS
    Starts a service if it is not already running.

    .PARAMETER Name
    The name of the service to start.

    .PARAMETER StartupTimeout
    The amount of time to wait for the service to start.
#>
function Start-ServiceResource
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String]
        $Name,

        [Parameter(Mandatory = $true)]
        [uint32]
        $StartupTimeout
    )

    $service = Get-ServiceResource -Name $Name

    if ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running)
    {
        Write-Verbose -Message ($LocalizedData.ServiceAlreadyStarted -f $service.Name)
        return
    }

    if ($PSCmdlet.ShouldProcess($Name, $LocalizedData.StartServiceWhatIf))
    {
        try
        {
            $service.Start()
            $waitTimeSpan = New-Object -TypeName TimeSpan -ArgumentList ($StartupTimeout * 10000)
            $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running, $waitTimeSpan)
        }
        catch
        {
            $servicePath = (Get-CimInstance -Class win32_service | Where-Object {$_.Name -eq $Name}).PathName
            $errorMessage = $LocalizedData.ErrorStartingService -f $service.Name, $servicePath,$_.Exception.Message
            ThrowInvalidArgumentError "ErrorStartingService" $errorMessage
        }

        Write-Verbose -Message ($LocalizedData.ServiceStarted -f $service.Name)
    }
}

function NormalizeStartupType([string]$StartupType)
{
    if ($StartupType -ieq 'Auto') {return "Automatic"}
    return $StartupType
}

function NormalizeUserName([string]$UserName)
{
    if ($UserName -ieq 'NetworkService') {return "NT Authority\NetworkService"}
    if ($UserName -ieq 'LocalService') {return "NT Authority\LocalService"}
    if ($UserName -ieq 'LocalSystem') {return ".\LocalSystem"}
    if ($UserName.IndexOf("\") -eq -1) { return ".\" + $userName }
    return $UserName
}

<#
.Synopsis
Throws an argument error
#>
function ThrowInvalidArgumentError
{
    [CmdletBinding()]
    param
    (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorMessage
    )

    $errorCategory=[System.Management.Automation.ErrorCategory]::InvalidArgument
    $exception = New-Object -TypeName System.ArgumentException -ArgumentList $ErrorMessage;
    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception, $ErrorId, $errorCategory, $null
    throw $errorRecord
}

<#
    .SYNOPSIS
    Tests if a service with the given name exists

    .PARAMETER Name
    The name of the service to test for.
#>
function Test-ServiceExists
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name
    )

    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    return $null -ne $service
}

<#
    .SYNOPSIS
    Compares a path to the existing service path. 
    Returns true when the given path is same as the existing service path.

    .PARAMETER Name
    The name of the existing service for which to check the path.

    .PARAMETER Path
    The path to check against.
#>
function Compare-ServicePath
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path
    )
    
    $existingServicePath = (Get-CimInstance -Class win32_service | Where-Object {$_.Name -eq $Name}).PathName
    $stringCompareResult = [String]::Compare($Path, $existingServicePath, [System.Globalization.CultureInfo]::CurrentUICulture)

    return $stringCompareResult -eq 0
}

<#
    .SYNOPSIS
    Retrieves the service with the given name.

    .PARAMETER Name
    The name of the service to retrieve
#>
function Get-ServiceResource
{
    [CmdletBinding()]
    param
    (

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name
    )

    $service = Get-Service -Name $Name -ErrorAction Ignore

    if ($null -eq $service)
    {
        ThrowInvalidArgumentError -ErrorId "ServiceNotFound" -ErrorMessage ($LocalizedData.ServiceNotFound -f $Name)
    }

    return $service
}

<#
.Synopsis
Grants log on as service right to the given user
#>
function SetLogOnAsServicePolicy([string]$UserName)
{
    $logOnAsServiceText=@"
        namespace LogOnAsServiceHelper
        {
            using Microsoft.Win32.SafeHandles;
            using System;
            using System.Runtime.ConstrainedExecution;
            using System.Runtime.InteropServices;
            using System.Security;

            public class NativeMethods
            {
                #region constants
                // from ntlsa.h
                private const int POLICY_LOOKUP_NAMES = 0x00000800;
                private const int POLICY_CREATE_ACCOUNT = 0x00000010;
                private const uint ACCOUNT_ADJUST_SYSTEM_ACCESS = 0x00000008;
                private const uint ACCOUNT_VIEW = 0x00000001;
                private const uint SECURITY_ACCESS_SERVICE_LOGON = 0x00000010;

                // from LsaUtils.h
                private const uint STATUS_OBJECT_NAME_NOT_FOUND = 0xC0000034;

                // from lmcons.h
                private const int UNLEN = 256;
                private const int DNLEN = 15;

                // Extra characteres for "\","@" etc.
                private const int EXTRA_LENGTH = 3;
                #endregion constants

                #region interop structures
                /// <summary>
                /// Used to open a policy, but not containing anything meaqningful
                /// </summary>
                [StructLayout(LayoutKind.Sequential)]
                private struct LSA_OBJECT_ATTRIBUTES
                {
                    public UInt32 Length;
                    public IntPtr RootDirectory;
                    public IntPtr ObjectName;
                    public UInt32 Attributes;
                    public IntPtr SecurityDescriptor;
                    public IntPtr SecurityQualityOfService;

                    public void Initialize()
                    {
                        this.Length = 0;
                        this.RootDirectory = IntPtr.Zero;
                        this.ObjectName = IntPtr.Zero;
                        this.Attributes = 0;
                        this.SecurityDescriptor = IntPtr.Zero;
                        this.SecurityQualityOfService = IntPtr.Zero;
                    }
                }

                /// <summary>
                /// LSA string
                /// </summary>
                [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
                private struct LSA_UNICODE_STRING
                {
                    internal ushort Length;
                    internal ushort MaximumLength;
                    [MarshalAs(UnmanagedType.LPWStr)]
                    internal string Buffer;

                    internal void Set(string src)
                    {
                        this.Buffer = src;
                        this.Length = (ushort)(src.Length * sizeof(char));
                        this.MaximumLength = (ushort)(this.Length + sizeof(char));
                    }
                }

                /// <summary>
                /// Structure used as the last parameter for LSALookupNames
                /// </summary>
                [StructLayout(LayoutKind.Sequential)]
                private struct LSA_TRANSLATED_SID2
                {
                    public uint Use;
                    public IntPtr SID;
                    public int DomainIndex;
                    public uint Flags;
                };
                #endregion interop structures

                #region safe handles
                /// <summary>
                /// Handle for LSA objects including Policy and Account
                /// </summary>
                private class LsaSafeHandle : SafeHandleZeroOrMinusOneIsInvalid
                {
                    [DllImport("advapi32.dll")]
                    private static extern uint LsaClose(IntPtr ObjectHandle);

                    /// <summary>
                    /// Prevents a default instance of the LsaPolicySafeHAndle class from being created.
                    /// </summary>
                    private LsaSafeHandle(): base(true)
                    {
                    }

                    /// <summary>
                    /// Calls NativeMethods.CloseHandle(handle)
                    /// </summary>
                    /// <returns>the return of NativeMethods.CloseHandle(handle)</returns>
                    [ReliabilityContract(Consistency.WillNotCorruptState, Cer.MayFail)]
                    protected override bool ReleaseHandle()
                    {
                        long returnValue = LsaSafeHandle.LsaClose(this.handle);
                        return returnValue != 0;

                    }
                }

                /// <summary>
                /// Handle for IntPtrs returned from Lsa calls that have to be freed with
                /// LsaFreeMemory
                /// </summary>
                private class SafeLsaMemoryHandle : SafeHandleZeroOrMinusOneIsInvalid
                {
                    [DllImport("advapi32")]
                    internal static extern int LsaFreeMemory(IntPtr Buffer);

                    private SafeLsaMemoryHandle() : base(true) { }

                    private SafeLsaMemoryHandle(IntPtr handle)
                        : base(true)
                    {
                        SetHandle(handle);
                    }

                    private static SafeLsaMemoryHandle InvalidHandle
                    {
                        get { return new SafeLsaMemoryHandle(IntPtr.Zero); }
                    }

                    override protected bool ReleaseHandle()
                    {
                        return SafeLsaMemoryHandle.LsaFreeMemory(handle) == 0;
                    }

                    internal IntPtr Memory
                    {
                        get
                        {
                            return this.handle;
                        }
                    }
                }
                #endregion safe handles

                #region interop function declarations
                /// <summary>
                /// Opens LSA Policy
                /// </summary>
                [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
                private static extern uint LsaOpenPolicy(
                    IntPtr SystemName,
                    ref LSA_OBJECT_ATTRIBUTES ObjectAttributes,
                    uint DesiredAccess,
                    out LsaSafeHandle PolicyHandle
                );

                /// <summary>
                /// Convert the name into a SID which is used in remaining calls
                /// </summary>
                [DllImport("advapi32", CharSet = CharSet.Unicode, SetLastError = true), SuppressUnmanagedCodeSecurityAttribute]
                private static extern uint LsaLookupNames2(
                    LsaSafeHandle PolicyHandle,
                    uint Flags,
                    uint Count,
                    LSA_UNICODE_STRING[] Names,
                    out SafeLsaMemoryHandle ReferencedDomains,
                    out SafeLsaMemoryHandle Sids
                );

                /// <summary>
                /// Opens the LSA account corresponding to the user's SID
                /// </summary>
                [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
                private static extern uint LsaOpenAccount(
                    LsaSafeHandle PolicyHandle,
                    IntPtr Sid,
                    uint Access,
                    out LsaSafeHandle AccountHandle);

                /// <summary>
                /// Creates an LSA account corresponding to the user's SID
                /// </summary>
                [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
                private static extern uint LsaCreateAccount(
                    LsaSafeHandle PolicyHandle,
                    IntPtr Sid,
                    uint Access,
                    out LsaSafeHandle AccountHandle);

                /// <summary>
                /// Gets the LSA Account access
                /// </summary>
                [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
                private static extern uint LsaGetSystemAccessAccount(
                    LsaSafeHandle AccountHandle,
                    out uint SystemAccess);

                /// <summary>
                /// Sets the LSA Account access
                /// </summary>
                [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
                private static extern uint LsaSetSystemAccessAccount(
                    LsaSafeHandle AccountHandle,
                    uint SystemAccess);
                #endregion interop function declarations

                /// <summary>
                /// Sets the Log On As A Service Policy for <paramref name="userName"/>, if not already set.
                /// </summary>
                /// <param name="userName">the user name we want to allow logging on as a service</param>
                /// <exception cref="ArgumentNullException">If the <paramref name="userName"/> is null or empty.</exception>
                /// <exception cref="InvalidOperationException">In the following cases:
                ///     Failure opening the LSA Policy.
                ///     The <paramref name="userName"/> is too large.
                ///     Failure looking up the user name.
                ///     Failure opening LSA account (other than account not found).
                ///     Failure creating LSA account.
                ///     Failure getting LSA account policy access.
                ///     Failure setting LSA account policy access.
                /// </exception>
                public static void SetLogOnAsServicePolicy(string userName)
                {
                    if (String.IsNullOrEmpty(userName))
                    {
                        throw new ArgumentNullException("userName");
                    }

                    LSA_OBJECT_ATTRIBUTES objectAttributes = new LSA_OBJECT_ATTRIBUTES();
                    objectAttributes.Initialize();

                    // All handles are delcared in advance so they can be closed on finally
                    LsaSafeHandle policyHandle = null;
                    SafeLsaMemoryHandle referencedDomains = null;
                    SafeLsaMemoryHandle sids = null;
                    LsaSafeHandle accountHandle = null;

                    try
                    {
                        uint status = LsaOpenPolicy(
                            IntPtr.Zero,
                            ref objectAttributes,
                            POLICY_LOOKUP_NAMES | POLICY_CREATE_ACCOUNT,
                            out policyHandle);

                        if (status != 0)
                        {
                            throw new InvalidOperationException("CannotOpenPolicyErrorMessage");
                        }

                        // Unicode strings have a maximum length of 32KB. We don't want to create
                        // LSA strings with more than that. User lengths are much smaller so this check
                        // ensures userName's length is useful
                        if (userName.Length > UNLEN + DNLEN + EXTRA_LENGTH)
                        {
                            throw new InvalidOperationException("UserNameTooLongErrorMessage");
                        }

                        LSA_UNICODE_STRING lsaUserName = new LSA_UNICODE_STRING();
                        lsaUserName.Set(userName);

                        LSA_UNICODE_STRING[] names = new LSA_UNICODE_STRING[1];
                        names[0].Set(userName);

                        status = LsaLookupNames2(
                            policyHandle,
                            0,
                            1,
                            new LSA_UNICODE_STRING[] { lsaUserName },
                            out referencedDomains,
                            out sids);

                        if (status != 0)
                        {
                            throw new InvalidOperationException("CannotLookupNamesErrorMessage");
                        }

                        LSA_TRANSLATED_SID2 sid = (LSA_TRANSLATED_SID2)Marshal.PtrToStructure(sids.Memory, typeof(LSA_TRANSLATED_SID2));

                        status = LsaOpenAccount(policyHandle,
                                            sid.SID,
                                            ACCOUNT_VIEW | ACCOUNT_ADJUST_SYSTEM_ACCESS,
                                            out accountHandle);

                        uint currentAccess = 0;

                        if (status == 0)
                        {
                            status = LsaGetSystemAccessAccount(accountHandle, out currentAccess);

                            if (status != 0)
                            {
                                throw new InvalidOperationException("CannotGetAccountAccessErrorMessage");
                            }

                        }
                        else if (status == STATUS_OBJECT_NAME_NOT_FOUND)
                        {
                            status = LsaCreateAccount(
                                policyHandle,
                                sid.SID,
                                ACCOUNT_ADJUST_SYSTEM_ACCESS,
                                out accountHandle);

                            if (status != 0)
                            {
                                throw new InvalidOperationException("CannotCreateAccountAccessErrorMessage");
                            }
                        }
                        else
                        {
                            throw new InvalidOperationException("CannotOpenAccountErrorMessage");
                        }

                        if ((currentAccess & SECURITY_ACCESS_SERVICE_LOGON) == 0)
                        {
                            status = LsaSetSystemAccessAccount(
                                accountHandle,
                                currentAccess | SECURITY_ACCESS_SERVICE_LOGON);
                            if (status != 0)
                            {
                                throw new InvalidOperationException("CannotSetAccountAccessErrorMessage");
                            }
                        }
                    }
                    finally
                    {
                        if (policyHandle != null) { policyHandle.Close(); }
                        if (referencedDomains != null) { referencedDomains.Close(); }
                        if (sids != null) { sids.Close(); }
                        if (accountHandle != null) { accountHandle.Close(); }
                    }
                }
            }
        }
"@

    try
    {
        $existingType=[LogOnAsServiceHelper.NativeMethods]
    }
    catch
    {
        $logOnAsServiceText=$logOnAsServiceText.Replace("CannotOpenPolicyErrorMessage",$LocalizedData.CannotOpenPolicyErrorMessage)
        $logOnAsServiceText=$logOnAsServiceText.Replace("UserNameTooLongErrorMessage",$LocalizedData.UserNameTooLongErrorMessage)
        $logOnAsServiceText=$logOnAsServiceText.Replace("CannotLookupNamesErrorMessage",$LocalizedData.CannotLookupNamesErrorMessage)
        $logOnAsServiceText=$logOnAsServiceText.Replace("CannotOpenAccountErrorMessage",$LocalizedData.CannotOpenAccountErrorMessage)
        $logOnAsServiceText=$logOnAsServiceText.Replace("CannotCreateAccountAccessErrorMessage",$LocalizedData.CannotCreateAccountAccessErrorMessage)
        $logOnAsServiceText=$logOnAsServiceText.Replace("CannotGetAccountAccessErrorMessage",$LocalizedData.CannotGetAccountAccessErrorMessage)
        $logOnAsServiceText=$logOnAsServiceText.Replace("CannotSetAccountAccessErrorMessage",$LocalizedData.CannotSetAccountAccessErrorMessage)
        $null = Add-Type $logOnAsServiceText -PassThru -Debug:$false
    }

    if($UserName.StartsWith(".\"))
    {
        $UserName = $UserName.Substring(2)
    }

    try
    {
        [LogOnAsServiceHelper.NativeMethods]::SetLogOnAsServicePolicy($UserName)
    }
    catch
    {
        $message = $LocalizedData.ErrorSettingLogOnAsServiceRightsForUser -f $UserName,$_.Exception.Message
        ThrowInvalidArgumentError -ErrorId "ErrorSettingLogOnAsServiceRightsForUser" -ErrorMessage $message
    }
}

Export-ModuleMember -Function *-TargetResource
