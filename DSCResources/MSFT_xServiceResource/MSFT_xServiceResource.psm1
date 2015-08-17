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
ErrorStartingService=Failure starting service '{0}'. Message: '{1}'
OnlyOneParameterCanBeSpecified=Only one of the following parameters can be specified: '{0}', '{1}'.
StartServiceWhatIf=Start Service
ServiceAlreadyStopped=Service '{0}' already stopped, no action required.
ErrorStoppingService=Failure stopping service '{0}'. Message: '{1}'
ErrorRetrievingServiceInformation=Failure retrieving information for service '{0}'. Message: '{1}'
ErrorSettingServiceCredential=Failure setting credentials for service '{0}'. Message: '{1}'
SetCredentialWhatIf=Set Credential
SetStartupTypeWhatIf=Set Start Type
ErrorSettingServiceStartupType=Failure setting start type for service '{0}'. Message: '{1}'
TestUserNameMismatch=User name for service '{0}' is '{1}'. It does not match '{2}.
TestStartupTypeMismatch=Startup type for service '{0}' is '{1}'. It does not match '{2}'.
MethodFailed=The '{0}' method of '{1}' failed with error code: '{2}'.
ErrorChangingProperty=Failed to change '{0}' property. Message: '{1}'
ErrorSetingLogOnAsServiceRightsForUser=Error granting '{0}' the right to log on as a service. Message: '{1}'.
CannotOpenPolicyErrorMessage=Cannot open policy manager
UserNameTooLongErrorMessage=User name is too long
CannotLookupNamesErrorMessage=Failed to lookup user name
CannotOpenAccountErrorMessage=Failed to open policy for user
CannotCreateAccountAccessErrorMessage=Failed to create policy for user
CannotGetAccountAccessErrorMessage=Failed to get user policy rights
CannotSetAccountAccessErrorMessage=Failed to set user policy rights
"@
}

#Import-LocalizedData  LocalizedData -filename MSFT_ServiceResource.strings.psd1

<#
.Synopsis
Gets a service resource
#>
function Get-TargetResource
{
    [OutputType([System.Collections.Hashtable])]
    param
    (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    )

    $svc = GetServiceResource -Name $Name
    $svcWmi = GetWMIService -Name $Name

    return @{
        Name=$svc.Name
        StartupType=(NormalizeStartupType -StartupType $svcWmi.StartMode).ToString()
        BuiltInAccount=if($svcWmi.StartName -ieq "LocalSystem") {"LocalSystem"} `
            elseif($svcWmi.StartName -ieq "NT Authority\NetworkService") {"NetworkService"} `
            elseif($svcWmi.StartName -ieq "NT Authority\LocalService") {"LocalService"} else {$null}
        State=$svc.Status.ToString()
        Path=$svcWmi.PathName
        DisplayName=$svc.DisplayName
        Description=$svcWmi.Description
        Dependencies=[string[]](@() + ($svc.ServicesDependedOn | %{$_.Name}))
    }
}


<#
.Synopsis
Tests a service resource
#>
function Test-TargetResource
{
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,
        
        [System.String]
        [ValidateSet("Automatic", "Manual", "Disabled")]
        $StartupType,

        [System.String]
        [ValidateSet("LocalSystem", "LocalService", "NetworkService")]
        $BuiltInAccount,

        [System.Management.Automation.PSCredential]
        [ValidateNotNull()]
        $Credential,

        [System.String]
        [ValidateSet("Running", "Stopped")]
        $State="Running",

        [System.String]
        [ValidateSet("Present", "Absent")]
        $Ensure="Present",

        [System.String]
        [ValidateNotNullOrEmpty()]
        $Path,

        [System.String]
        [ValidateNotNullOrEmpty()]
        $DisplayName,

        [System.String]
        [ValidateNotNullOrEmpty()]
        $Description,

        [System.String[]]
        [ValidateNotNullOrEmpty()]
        $Dependencies,

        [System.UInt32]
        $StartupTimeout
    )

    ValidateStartupType -Name $Name -StartupType $StartupType -State $State
    if($PSBoundParameters.ContainsKey("Ensure"))
    {
        if($Ensure -eq "Present")
        {
            if(!($PSBoundParameters.ContainsKey("Path")))
            {
                ThrowInvalidArgumentError -ErrorId "BinaryPathNotSpecified" -ErrorMessage "Specify the path to the executable when trying to create a new service"
            }
            else
            {
                $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
                if($service -ne $null)
                {
                    Write-Verbose -Message "The service to create already exists"
                }
                else
                {
                    return $false
                }
            }
        }
        else
        {
            $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
            if($service -ne $null)
            {
                return $false
            }
            else
            {
                return $true
            }
        }
    }
    
    $svc=GetServiceResource -Name $Name

    if($PSBoundParameters.ContainsKey("StartupType") -or $PSBoundParameters.ContainsKey("BuiltInAccount") -or $PSBoundParameters.ContainsKey("Credential"))
    {
        $svcWmi = GetWMIService -Name $Name

        $getUserNameAndPasswordArgs=@{}
        if($PSBoundParameters.ContainsKey("BuiltInAccount")) {$null=$getUserNameAndPasswordArgs.Add("BuiltInAccount",$BuiltInAccount)}
        if($PSBoundParameters.ContainsKey("Credential")) {$null=$getUserNameAndPasswordArgs.Add("Credential",$Credential)}

        $userName,$password=GetUserNameAndPassword @getUserNameAndPasswordArgs
        if($userName -ne $null -and !(TestUserName $SvcWmi $userName))
        {
            Write-Verbose -Message ($LocalizedData.TestUserNameMismatch -f $svcWmi.Name,$svcWmi.StartName,$userName)
            return $false
        }

        if($PSBoundParameters.ContainsKey("StartupType") -and !(TestStartupType -SvcWmi $SvcWmi -StartupType $StartupType))
        {
            Write-Verbose -Message ($LocalizedData.TestStartupTypeMismatch -f $svcWmi.Name,$svcWmi.StartMode,$StartupType)
            return $false
        }
    }

    return ($State -eq "Stopped" -and $svc.Status -eq "Stopped") -or ($svc.Status -eq "Running" -and $State -eq "Running")
    
}

<#
.Synopsis
Sets properties for a service resource
#>
function Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [System.String]
        [ValidateSet("Automatic", "Manual", "Disabled")]
        $StartupType,

        [System.String]
        [ValidateSet("LocalSystem", "LocalService", "NetworkService")]
        $BuiltInAccount,

        [System.Management.Automation.PSCredential]
        [ValidateNotNull()]
        $Credential,

        [System.String]
        [ValidateSet("Running", "Stopped")]
        $State="Running",

        [System.String]
        [ValidateSet("Present", "Absent")]
        $Ensure="Present",

        [System.String]
        [ValidateNotNullOrEmpty()]
        $Path,

        [System.String]
        [ValidateNotNullOrEmpty()]
        $DisplayName,

        [System.String]
        [ValidateNotNullOrEmpty()]
        $Description,

        [System.String[]]
        [ValidateNotNullOrEmpty()]
        $Dependencies,

        [System.UInt32]
        $StartupTimeout = 30000
    )

    ValidateStartupType -Name $Name -StartupType $StartupType -State $State

    if($PSBoundParameters.ContainsKey("Ensure"))
    {
        if($Ensure -eq "Present")
        {
            if(!($PSBoundParameters.ContainsKey("Path")))
            {
                ThrowInvalidArgumentError -ErrorId "BinaryPathNotSpecified" -ErrorMessage "Specify the path to the executable when trying to create a new service"
            }
            else
            {
                $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
                if($service -ne $null)
                {
                    Write-Verbose -Message "The service to create already exists"
                }
                else
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
                        $argumentsToNewService.Add("Dependencies", $Dependencies)
                    }
                    try
                    {
                        New-Service @argumentsToNewService
                    }
                    catch
                    {
                        Write-Log -Message ("Error creating service `"$($argumentsToNewService["Name"])`"", $_.Exception.Message)
                        throw $_
                    }

                }
            }
        }
        else
        {
            $svc = GetServiceResource -Name $Name
            StopService -Svc $svc
            DeleteService -Name $svc.Name
            return
        }
    }

    $svc=GetServiceResource -Name $Name

    $writeWritePropertiesArguments=@{Name=$svc.name}
    if($PSBoundParameters.ContainsKey("StartupType")) {$null=$writeWritePropertiesArguments.Add("StartupType",$StartupType)}
    if($PSBoundParameters.ContainsKey("BuiltInAccount")) {$null=$writeWritePropertiesArguments.Add("BuiltInAccount",$BuiltInAccount)}
    if($PSBoundParameters.ContainsKey("Credential")) {$null=$writeWritePropertiesArguments.Add("Credential",$Credential)}

    WriteWriteProperties @writeWritePropertiesArguments

    if($State -eq "Stopped")
    {
        # Ensuring service is stopped
        StopService -Svc $svc
        return
    }

    # $State is Running, so ensuring service is started unless we are also creating the service in which case the default behavior is that the service is in the stopped state.
    if($Ensure -eq "Present")
    {
         if(( $PSBoundParameters.ContainsKey("State")) -and ($State -eq "Running"))
        {
            StartService -Svc $svc -StartupTimeout $StartupTimeout
        }
    }
    else
    {
        StartService -Svc $svc -StartupTimeout $StartupTimeout
    }
}

<#
.Synopsis
Validates a StartupType against the State parameter
#>
function ValidateStartupType
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [System.String]
        $StartupType,

        [System.String]
        [ValidateSet("Running", "Stopped")]
        $State="Running"
    )

    if($StartupType -eq $null) {return}

    if($State -eq "Stopped")
    {
        if($StartupType -eq "Automatic")
        {
            # State = Stopped conflicts with Automatic or Delayed
            ThrowInvalidArgumentError -ErrorId "CannotStopServiceSetToStartAutomatically" -ErrorMessage ($LocalizedData.CannotStopServiceSetToStartAutomatically -f $Name)
        }
    }
    else
    {
        if($StartupType -eq "Disabled")
        {
            # State = Running conflicts with Disabled
            ThrowInvalidArgumentError -ErrorId "CannotStartAndDisable" -ErrorMessage ($LocalizedData.CannotStartAndDisable -f $Name)
        }
    }
}


<#
.Synopsis
Writes all write properties if not already correctly set, logging errors and respecting whatif
#>
function WriteWriteProperties
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Name,

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

    if(!$PSBoundParameters.ContainsKey("StartupType") -and !$PSBoundParameters.ContainsKey("BuiltInAccount") -and !$PSBoundParameters.ContainsKey("Credential"))
    {
        return
    }

    $svcWmi = GetWMIService -Name $Name

    $writeCredentialPropertiesArguments=@{"SvcWmi"=$svcWmi}
    if($PSBoundParameters.ContainsKey("BuiltInAccount")) {$null=$writeCredentialPropertiesArguments.Add("BuiltInAccount",$BuiltInAccount)}
    if($PSBoundParameters.ContainsKey("Credential")) {$null=$writeCredentialPropertiesArguments.Add("Credential",$Credential)}

    WriteCredentialProperties @writeCredentialPropertiesArguments

    $writeStartupArguments=@{"SvcWmi"=$svcWmi}
    if($PSBoundParameters.ContainsKey("StartupType")) {$null=$writeStartupArguments.Add("StartupType",$StartupType)}
    WriteStartupTypeProperty @writeStartupArguments
}

<#
.Synopsis
Gets a Win32_Service object corresponding to the name
#>
function GetWMIService
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Name
    )

    try
    {
        return New-Object -TypeName System.Management.ManagementObject -ArgumentList "Win32_Service.Name='$Name'"
    }
    catch
    {
        Write-Verbose -Message ($LocalizedData.ErrorRetrievingServiceInformation -f $Name,$_.Exception.Message)
        throw
    }
}

<#
.Synopsis
Writes StartupType if not already correctly set, logging errors and respecting whatif
#>
function WriteStartupTypeProperty
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $SvcWmi,

        [System.String]
        $StartupType
    )

    if($PSBoundParameters.ContainsKey("StartupType") -and !(TestStartupType -SvcWmi $SvcWmi -StartupType $StartupType) -and $PSCmdlet.ShouldProcess($svcWmi.Name,$LocalizedData.SetStartupTypeWhatIf))
    {
        $ret = $svcWmi.Change($null,$null,$null,$null,$StartupType,$null,$null,$null)
        if($ret.ReturnValue -ne 0)
        {
            $innerMessage = $LocalizedData.MethodFailed -f "Change","Win32_Service",$ret.ReturnValue
            $message = $LocalizedData.ErrorChangingProperty -f "StartupType",$innerMessage
            ThrowInvalidArgumentError -ErrorId "ChangeStartupTypeFailed" -ErrorMessage $message
        }
    }
}


<#
.Synopsis
Writes credential properties if not already correctly set, logging errors and respecting whatif
#>
function WriteCredentialProperties
{
    [CmdletBinding(SupportsShouldProcess=$true)]
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

    if(!$PSBoundParameters.ContainsKey("Credential") -and !$PSBoundParameters.ContainsKey("BuiltInAccount") -and !$PSBoundParameters.ContainsKey("BuiltInAccount"))
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

        $ret = $SvcWmi.Change($null,$null,$null,$null,$null,$null,$userName,$password)
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

function TestStartupType
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $SvcWmi,

        [System.String]
        $StartupType
    )

    return (NormalizeStartupType -StartupType $SvcWmi.StartMode) -ieq $StartupType
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
.Synopsis
Stops a service if it is not already stopped logging the result
#>
function StopService
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Svc
    )

    if($Svc.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Stopped)
    {
        Write-Log -Message ($LocalizedData.ServiceAlreadyStopped -f  $Svc.Name)
        return
    }

    # Exceptions will be thrown, caught and logged by the infrastructure
    $err=Stop-Service -Name $Svc.Name -force 2>&1
    if($err -eq $null)
    {
        Write-Log -Message ($LocalizedData.ServiceStopped -f $Svc.Name)
    }
    else
    {
        Write-Log -Message ($LocalizedData.ErrorStoppingService -f $Svc.Name,($err | Out-String))
        throw $err
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

    #Wait for 2 seconds for a service to get deleted
    for($i = 1; $i -lt 1000; $i++)
    {
        if((Get-Service -Name $Name -ErrorAction SilentlyContinue) -eq $null)
        {
            $serviceDeletedSuccessfully = $true
            break
        }
        Start-Sleep .002
    }
    if(!$serviceDeletedSuccessfully)
    {
        Write-Log -Message ("Error in deleting service `"$Name`"")
        throw "Could not delete service `"$Name`""
    }
    else
    {
        Write-Log -Message ("Successfully deleted service `"$Name`"")
        Write-Verbose -Message "Successfully deleted service"
    }
}



<#
.Synopsis
Starts a service if it is not already started logging the result
#>
function StartService
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Svc,

        [parameter(Mandatory = $true)]
        $StartupTimeout
    )

    if($Svc.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running)
    {
        Write-Log -Message ($LocalizedData.ServiceAlreadyStarted -f $Svc.Name)
        return
    }

    if($PSCmdlet.ShouldProcess($Svc.Name,$LocalizedData.StartServiceWhatIf))
    {
        try
        {
            $Svc.Start()
            $timeSpan = New-Object -TypeName TimeSpan -ArgumentList ($StartupTimeout * 10000)
            $Svc.WaitForStatus("Running", $timeSpan)
        }
        catch
        {

            Write-Log -Message ($LocalizedData.ErrorStartingService -f $Svc.Name,$_.Exception.Message)
            throw
        }

        Write-Log -Message ($LocalizedData.ServiceStarted -f $Svc.Name)
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
.Synopsis
Gets a service corresponding to a name, throwing an error if not found
#>
function GetServiceResource
{
    param
    (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    )

    $svc=Get-Service -Name $name -ErrorAction Ignore

    if($svc -eq $null)
    {
        ThrowInvalidArgumentError -ErrorId "ServiceNotFound" -ErrorMessage ($LocalizedData.ServiceNotFound -f $Name)
    }

    return $svc
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
        $message = $LocalizedData.ErrorSetingLogOnAsServiceRightsForUser -f $UserName,$_.Exception.Message
        ThrowInvalidArgumentError -ErrorId "ErrorSetingLogOnAsServiceRightsForUser" -ErrorMessage $message
    }
}

function Write-Log
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message
    )

    if ($PSCmdlet.ShouldProcess($Message, $null, $null))
    {
        Write-Verbose -Message $Message
    }
}

Export-ModuleMember -function Get-TargetResource, Set-TargetResource, Test-TargetResource

