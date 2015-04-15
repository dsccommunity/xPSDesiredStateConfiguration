data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData @'
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
'@
}

Import-LocalizedData  LocalizedData -filename MSFT_xProcessResource.strings.psd1

function ExtractArguments($functionBoundParameters,[string[]]$argumentNames,[string[]]$newArgumentNames)
{
    $returnValue=@{}
    for($i=0;$i -lt $argumentNames.Count;$i++)
    {
        $argumentName=$argumentNames[$i]

        if($newArgumentNames -eq $null)
        {
            $newArgumentName=$argumentName
        }
        else
        {
            $newArgumentName=$newArgumentNames[$i]
        }

        if($functionBoundParameters.ContainsKey($argumentName))
        {
            $null=$returnValue.Add($newArgumentName,$functionBoundParameters[$argumentName])
        }
    }

    return $returnValue
}

function Get-TargetResource
{
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [System.String]
        $Arguments,

        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    $Path=(ResolvePath $Path)
    $PSBoundParameters["Path"] = $Path
    $getArguments = ExtractArguments $PSBoundParameters ("Path","Arguments","Credential")
    $processes = @(GetWin32_Process @getArguments)

    if($processes.Count -eq 0)
    {
        return @{
            Path=$Path
            Arguments=$Arguments
            Ensure='Absent'
        }
    }

    foreach($process in $processes)
    {
        # in case the process was killed between GetWin32_Process and this point, we should
        # ignore errors which will generate empty entries in the return
        $gpsProcess = (get-process -id $process.ProcessId -ErrorAction Ignore)

        @{
            Path=$process.Path
            Arguments=(GetProcessArgumentsFromCommandLine $process.CommandLine)
            PagedMemorySize=$gpsProcess.PagedMemorySize64
            NonPagedMemorySize=$gpsProcess.NonpagedSystemMemorySize64
            VirtualMemorySize=$gpsProcess.VirtualMemorySize64
            HandleCount=$gpsProcess.HandleCount
            Ensure='Present'
            ProcessId=$process.ProcessId
        }
    }
}


function Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [System.String]
        $Arguments,

        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [System.String]
        [ValidateSet("Present", "Absent")]
        $Ensure="Present",

        [System.String]
        $StandardOutputPath,

        [System.String]
        $StandardErrorPath,

        [System.String]
        $StandardInputPath,

        [System.String]
        $WorkingDirectory
    )

    $Path=ResolvePath $Path
    $PSBoundParameters["Path"] = $Path
    $getArguments = ExtractArguments $PSBoundParameters ("Path","Arguments","Credential")
    $processes = @(GetWin32_Process @getArguments)

    if($Ensure -eq 'Absent')
    {
        "StandardOutputPath","StandardErrorPath","StandardInputPath","WorkingDirectory" | AssertParameterIsNotSpecified $PSBoundParameters

        if ($processes.Count -gt 0)
        {
           $processIds=$processes.ProcessId

           $err=Stop-Process -Id $processIds -force 2>&1

           if($err -eq $null)
           {
               Write-Log ($LocalizedData.ProcessesStopped -f $Path,($processIds -join ","))
           }
           else
           {
               Write-Log ($LocalizedData.ErrorStopping -f $Path,($processIds -join ","),($err | out-string))
               throw $err
           }

           # Before returning from Set-TargetResource we have to ensure a subsequent Test-TargetResource is going to work
           if (!(WaitForProcessCount @getArguments -waitCount 0))
           {
                $message = $LocalizedData.ErrorStopping -f $Path,($processIds -join ","),$LocalizedData.FailureWaitingForProcessesToStop
                Write-Log $message
                ThrowInvalidArgumentError "FailureWaitingForProcessesToStop" $message
           }
        }
        else
        {
            Write-Log ($LocalizedData.ProcessAlreadyStopped -f $Path)
        }
    }
    else
    {
        "StandardInputPath","WorkingDirectory" |  AssertAbsolutePath $PSBoundParameters -Exist
        "StandardOutputPath","StandardErrorPath" | AssertAbsolutePath $PSBoundParameters

        if ($processes.Count -eq 0)
        {
            $startArguments = ExtractArguments $PSBoundParameters `
                 ("Path",     "Arguments",    "Credential", "StandardOutputPath",     "StandardErrorPath",     "StandardInputPath", "WorkingDirectory") `
                 ("FilePath", "ArgumentList", "Credential",  "RedirectStandardOutput", "RedirectStandardError", "RedirectStandardInput", "WorkingDirectory")

            if([string]::IsNullOrEmpty($Arguments))
            {
                $null=$startArguments.Remove("ArgumentList")
            }

            if($PSCmdlet.ShouldProcess($Path,$LocalizedData.StartingProcessWhatif))
            {
                if($PSBoundParameters.ContainsKey("Credential"))
                {
                    $argumentError = $false
                    try
                    {
                        if($PSBoundParameters.ContainsKey("StandardOutputPath") -or $PSBoundParameters.ContainsKey("StandardInputPath") -or $PSBoundParameters.ContainsKey("WorkingDirectory"))
                        {
                            $argumentError = $true
                            $errorMessage = "Can't specify StandardOutptPath, StandardInputPath or WorkingDirectory when trying to run a process under a user context"
                            throw $errorMessage
                        }
                        else
                        {
                            CallPInvoke
                            [Source.NativeMethods]::CreateProcessAsUser(("$Path "+$Arguments), $Credential.GetNetworkCredential().Domain, $Credential.GetNetworkCredential().UserName, $Credential.GetNetworkCredential().Password)
                        }
                    }
                    catch
                    {
                        $exception = New-Object System.ArgumentException $_;
                        if($argumentError)
                        {
                            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                            $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception,"Invalid combination of arguments", $errorCategory, $null
                        }
                        else
                        {
                            $errorCategory = [System.Management.Automation.ErrorCategory]::OperationStopped
                            $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, "Win32Exception", $errorCategory, $null
                        }
                        $err = $errorRecord
                    }

                }
                else
                {
                    $err=Start-Process @startArguments 2>&1
                }
                if($err -eq $null)
                {
                    Write-Log ($LocalizedData.ProcessStarted -f $Path)
                }
                else
                {
                    Write-Log ($LocalizedData.ErrorStarting -f $Path,($err | Out-String))
                    throw $err
                }

                # Before returning from Set-TargetResource we have to ensure a subsequent Test-TargetResource is going to work
                if (!(WaitForProcessCount @getArguments -waitCount 1))
                {
                    $message = $LocalizedData.ErrorStarting -f $Path,$LocalizedData.FailureWaitingForProcessesToStart
                    Write-Log $message
                    ThrowInvalidArgumentError "FailureWaitingForProcessesToStart" $message
                }
            }
        }
        else
        {
            Write-Log ($LocalizedData.ProcessAlreadyStarted -f $Path)
        }
    }
}

function Test-TargetResource
{
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [System.String]
        $Arguments,

        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [System.String]
        [ValidateSet("Present", "Absent")]
        $Ensure="Present",

        [System.String]
        $StandardOutputPath,

        [System.String]
        $StandardErrorPath,

        [System.String]
        $StandardInputPath,

        [System.String]
        $WorkingDirectory
    )

    $Path=ResolvePath $Path
    $PSBoundParameters["Path"] = $Path
    $getArguments = ExtractArguments $PSBoundParameters ("Path","Arguments","Credential")
    $processes = @(GetWin32_Process @getArguments)


    if($Ensure -eq 'Absent')
    {
        return ($processes.Count -eq 0)
    }
    else
    {
        return ($processes.Count -gt 0)
    }
}

function GetWin32ProcessOwner
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $process
    )

    # if the process was killed by the time this is called, GetOwner
    # will throw a WMIMethodException "Not found"
    try
    {
        $owner = $process.GetOwner()
    }
    catch
    {
    }

    if($owner.Domain -ne $null)
    {
        return $owner.Domain + "\" + $owner.User
    }
    else
    {
        return $owner.User
    }
}

function WaitForProcessCount
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [System.String]
        $Arguments,

        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [parameter(Mandatory=$true)]
        $waitCount
    )

    $start = [DateTime]::Now
    do
    {
        $getArguments = ExtractArguments $PSBoundParameters ("Path","Arguments","Credential")
        $value = @(GetWin32_Process @getArguments).Count -eq $waitCount
    } while(!$value -and ([DateTime]::Now - $start).TotalMilliseconds -lt 2000)

    return $value
}

function GetWin32_Process
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [System.String]
        $Arguments,

        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential,

        $useWmiObjectCount=8
    )



    $fileName = [io.path]::GetFileNameWithoutExtension($Path)

    $gpsProcesses = @(get-process -Name $fileName -ErrorAction SilentlyContinue)

    if($gpsProcesses.Count -ge $useWmiObjectCount)
    {
        # if there are many processes it is faster to perform a Get-WmiObject
        # in order to get Win32_Process objects for all processes
        Write-Verbose "When gpsprocess.count is greater than usewmiobjectcount"
        $Path=WQLEscape $Path
        $filter = "ExecutablePath = '$Path'"
        $processes = Get-WmiObject Win32_Process -Filter $filter
    }
    else
    {
        # if there are few processes, building a Win32_Process for
        # each matching result of get-process is faster
        $processes = foreach($gpsProcess in $gpsProcesses)
        {
            if(!($gpsProcess.Path -ieq $Path))
            {
                continue
            }

            try
            {
                Write-Verbose "in process handle, $($gpsProcess.Id)"
                [wmi]"Win32_Process.Handle='$($gpsProcess.Id)'"
            }
            catch
            {
                #ignore if could not retrieve process
            }
        }
    }

    if($PSBoundParameters.ContainsKey('Credential'))
    {
        # Since there are credentials we need to call the GetOwner method in each process to search for matches
        $processes = $processes | where { (GetWin32ProcessOwner $_) -eq $Credential.UserName }

    }

    if($Arguments -eq $null) {$Arguments = ""}
    $processes = $processes | where { (GetProcessArgumentsFromCommandLine $_.CommandLine) -eq $Arguments }

    return $processes
}

<#
.Synopsis
   Strips the Arguments part of a commandLine. In "c:\temp\a.exe X Y Z" the Arguments part is "X Y Z".
#>
function GetProcessArgumentsFromCommandLine
{
    param
    (
        [System.String]
        $commandLine
    )

    if($commandLine -eq $null)
    {
        return ""
    }

    $commandLine=$commandLine.Trim()

    if($commandLine.Length -eq 0)
    {
        return ""
    }

    if($commandLine[0] -eq '"')
    {
        $charToLookfor=[char]'"'
    }
    else
    {
        $charToLookfor=[char]' '
    }

    $endofCommand=$commandLine.IndexOf($charToLookfor ,1)
    if($endofCommand -eq -1)
    {
        return ""
    }

    return $commandLine.Substring($endofCommand+1).Trim()
}

<#
.Synopsis
   Escapes a string to be used in a WQL filter as the one passed to get-wmiobject
#>
function WQLEscape
{
    param
    (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $query
    )

    return $query.Replace("\","\\").Replace('"','\"').Replace("'","\'")
}

function ThrowInvalidArgumentError
{
    [CmdletBinding()]
    param
    (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $errorId,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $errorMessage
    )

    $errorCategory=[System.Management.Automation.ErrorCategory]::InvalidArgument
    $exception = New-Object System.ArgumentException $errorMessage;
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null
    throw $errorRecord
}

function ResolvePath
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path
    )

    $Path = [Environment]::ExpandEnvironmentVariables($Path)

    if(IsRootedPath $Path)
    {
        if(!(Test-Path $Path -PathType Leaf))
        {
            ThrowInvalidArgumentError "CannotFindRootedPath" ($LocalizedData.InvalidArgumentAndMessage -f ($LocalizedData.InvalidArgument -f "Path",$Path), $LocalizedData.FileNotFound)
        }

        return $Path
    }

    if([string]::IsNullOrEmpty($env:Path))
    {
        ThrowInvalidArgumentError "EmptyEnvironmentPath" ($LocalizedData.InvalidArgumentAndMessage -f ($LocalizedData.InvalidArgument -f "Path",$Path), $LocalizedData.FileNotFound)
    }

    # This will block relative paths. The statement is only true id $Path contains a plain file name.
    # Checking a relative path against segments of the $env:Path does not make sense
    if((Split-Path $Path -Leaf) -ne $Path)
    {
        ThrowInvalidArgumentError "NotAbsolutePathOrFileName" ($LocalizedData.InvalidArgumentAndMessage -f ($LocalizedData.InvalidArgument -f "Path",$Path), $LocalizedData.AbsolutePathOrFileName)
    }

    foreach($rawSegment in $env:Path.Split(";"))
    {
        $segment = [Environment]::ExpandEnvironmentVariables($rawSegment)

        # if an exception causes $segmentedRooted not to be set, we will consider it $false
        $segmentRooted = $false
        try
        {
            # If the whole path passed through [IO.Path]::IsPathRooted with no exceptions, it does not have
            # invalid characters, so segment has no invalid characters and will not throw as well
            $segmentRooted=[IO.Path]::IsPathRooted($segment)
        }
        catch {}

        if(!$segmentRooted)
        {
            continue
        }

        $candidate = join-path $segment $Path

        if(Test-Path $candidate -PathType Leaf)
        {
            return $candidate
        }
    }

    ThrowInvalidArgumentError "CannotFindRelativePath" ($LocalizedData.InvalidArgumentAndMessage -f ($LocalizedData.InvalidArgument -f "Path",$Path), $LocalizedData.FileNotFound)
}


function AssertAbsolutePath
{
    [CmdletBinding()]
    param
    (
        $ParentBoundParameters,

        [System.String]
        [Parameter (ValueFromPipeline=$true)]
        $ParameterName,

        [switch]
        $Exist
    )

    Process
    {
        if(!$ParentBoundParameters.ContainsKey($ParameterName))
        {
            return
        }

        $path=$ParentBoundParameters[$ParameterName]

        if(!(IsRootedPath $Path))
        {
            ThrowInvalidArgumentError "PathShouldBeAbsolute" ($LocalizedData.InvalidArgumentAndMessage -f ($LocalizedData.InvalidArgument -f $ParameterName,$Path),
                $LocalizedData.PathShouldBeAbsolute)
        }

        if(!$Exist.IsPresent)
        {
            return
        }

        if(!(Test-Path $Path))
        {
            ThrowInvalidArgumentError "PathShouldExist" ($LocalizedData.InvalidArgumentAndMessage -f ($LocalizedData.InvalidArgument -f $ParameterName,$Path),
                $LocalizedData.PathShouldExist)
        }
    }
}

function AssertParameterIsNotSpecified
{
    [CmdletBinding()]
    param
    (
        $ParentBoundParameters,

        [System.String]
        [Parameter (ValueFromPipeline=$true)]
        $ParameterName
    )

    Process
    {
        if($ParentBoundParameters.ContainsKey($ParameterName))
        {
            ThrowInvalidArgumentError "ParameterShouldNotBeSpecified" ($LocalizedData.ParameterShouldNotBeSpecified -f $ParameterName)
        }
    }
}

function IsRootedPath
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path
    )

    try
    {
        return [IO.Path]::IsPathRooted($Path)
    }
    catch
    {
        # if the Path has invalid characters like >, <, etc, we cannot determine if it is rooted so we do not go on
        ThrowInvalidArgumentError "CannotGetIsPathRooted" ($LocalizedData.InvalidArgumentAndMessage -f ($LocalizedData.InvalidArgument -f "Path",$Path), $_.Exception.Message)
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
        Write-Verbose $Message
    }
}

function CallPInvoke
{
$script:ProgramSource = @"
using System;
using System.Collections.Generic;
using System.Text;
using System.Security;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Security.Principal;
using System.ComponentModel;
using System.IO;

namespace Source
{
    [SuppressUnmanagedCodeSecurity]
    public static class NativeMethods
    {
        //The following structs and enums are used by the various Win32 API's that are used in the code below

        [StructLayout(LayoutKind.Sequential)]
        public struct STARTUPINFO
        {
            public Int32 cb;
            public string lpReserved;
            public string lpDesktop;
            public string lpTitle;
            public Int32 dwX;
            public Int32 dwY;
            public Int32 dwXSize;
            public Int32 dwXCountChars;
            public Int32 dwYCountChars;
            public Int32 dwFillAttribute;
            public Int32 dwFlags;
            public Int16 wShowWindow;
            public Int16 cbReserved2;
            public IntPtr lpReserved2;
            public IntPtr hStdInput;
            public IntPtr hStdOutput;
            public IntPtr hStdError;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct PROCESS_INFORMATION
        {
            public IntPtr hProcess;
            public IntPtr hThread;
            public Int32 dwProcessID;
            public Int32 dwThreadID;
        }

        [Flags]
        public enum LogonType
        {
            LOGON32_LOGON_INTERACTIVE = 2,
            LOGON32_LOGON_NETWORK = 3,
            LOGON32_LOGON_BATCH = 4,
            LOGON32_LOGON_SERVICE = 5,
            LOGON32_LOGON_UNLOCK = 7,
            LOGON32_LOGON_NETWORK_CLEARTEXT = 8,
            LOGON32_LOGON_NEW_CREDENTIALS = 9
        }

        [Flags]
        public enum LogonProvider
        {
            LOGON32_PROVIDER_DEFAULT = 0,
            LOGON32_PROVIDER_WINNT35,
            LOGON32_PROVIDER_WINNT40,
            LOGON32_PROVIDER_WINNT50
        }
        [StructLayout(LayoutKind.Sequential)]
        public struct SECURITY_ATTRIBUTES
        {
            public Int32 Length;
            public IntPtr lpSecurityDescriptor;
            public bool bInheritHandle;
        }

        public enum SECURITY_IMPERSONATION_LEVEL
        {
            SecurityAnonymous,
            SecurityIdentification,
            SecurityImpersonation,
            SecurityDelegation
        }

        public enum TOKEN_TYPE
        {
            TokenPrimary = 1,
            TokenImpersonation
        }

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        internal struct TokPriv1Luid
        {
            public int Count;
            public long Luid;
            public int Attr;
        }

        public const int GENERIC_ALL_ACCESS = 0x10000000;
        public const int CREATE_NO_WINDOW = 0x08000000;
        internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
        internal const int TOKEN_QUERY = 0x00000008;
        internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
        internal const string SE_INCRASE_QUOTA = "SeIncreaseQuotaPrivilege";

        [DllImport("kernel32.dll",
              EntryPoint = "CloseHandle", SetLastError = true,
              CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
        public static extern bool CloseHandle(IntPtr handle);

        [DllImport("advapi32.dll",
              EntryPoint = "CreateProcessAsUser", SetLastError = true,
              CharSet = CharSet.Ansi, CallingConvention = CallingConvention.StdCall)]
        public static extern bool CreateProcessAsUser(
            IntPtr hToken,
            string lpApplicationName,
            string lpCommandLine,
            ref SECURITY_ATTRIBUTES lpProcessAttributes,
            ref SECURITY_ATTRIBUTES lpThreadAttributes,
            bool bInheritHandle,
            Int32 dwCreationFlags,
            IntPtr lpEnvrionment,
            string lpCurrentDirectory,
            ref STARTUPINFO lpStartupInfo,
            ref PROCESS_INFORMATION lpProcessInformation
            );

        [DllImport("advapi32.dll", EntryPoint = "DuplicateTokenEx")]
        public static extern bool DuplicateTokenEx(
            IntPtr hExistingToken,
            Int32 dwDesiredAccess,
            ref SECURITY_ATTRIBUTES lpThreadAttributes,
            Int32 ImpersonationLevel,
            Int32 dwTokenType,
            ref IntPtr phNewToken
            );

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern Boolean LogonUser(
            String lpszUserName,
            String lpszDomain,
            String lpszPassword,
            LogonType dwLogonType,
            LogonProvider dwLogonProvider,
            out IntPtr phToken
            );

        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
        internal static extern bool AdjustTokenPrivileges(
            IntPtr htok,
            bool disall,
            ref TokPriv1Luid newst,
            int len,
            IntPtr prev,
            IntPtr relen
            );

        [DllImport("kernel32.dll", ExactSpelling = true)]
        internal static extern IntPtr GetCurrentProcess();

        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
        internal static extern bool OpenProcessToken(
            IntPtr h,
            int acc,
            ref IntPtr phtok
            );

        [DllImport("advapi32.dll", SetLastError = true)]
        internal static extern bool LookupPrivilegeValue(
            string host,
            string name,
            ref long pluid
            );

        public static void CreateProcessAsUser(string strCommand, string strDomain, string strName, string strPassword)
        {
            var hToken = IntPtr.Zero;
            var hDupedToken = IntPtr.Zero;
            TokPriv1Luid tp;
            var pi = new PROCESS_INFORMATION();
            var sa = new SECURITY_ATTRIBUTES();
            sa.Length = Marshal.SizeOf(sa);
            Boolean bResult = false;
            try
            {
                bResult = LogonUser(
                    strName,
                    strDomain,
                    strPassword,
                    LogonType.LOGON32_LOGON_BATCH,
                    LogonProvider.LOGON32_PROVIDER_DEFAULT,
                    out hToken
                    );
                if (!bResult)
                {
                    throw new Win32Exception("The user could not be logged on. Ensure that the user has an existing profile on the machine and that correct credentials are provided. Logon error #" + Marshal.GetLastWin32Error().ToString());
                }
                IntPtr hproc = GetCurrentProcess();
                IntPtr htok = IntPtr.Zero;
                bResult = OpenProcessToken(
                        hproc,
                        TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY,
                        ref htok
                    );
                if(!bResult)
                {
                    throw new Win32Exception("Open process token error #" + Marshal.GetLastWin32Error().ToString());
                }
                tp.Count = 1;
                tp.Luid = 0;
                tp.Attr = SE_PRIVILEGE_ENABLED;
                bResult = LookupPrivilegeValue(
                    null,
                    SE_INCRASE_QUOTA,
                    ref tp.Luid
                    );
                if(!bResult)
                {
                    throw new Win32Exception("Error in looking up privilege of the process. This should not happen if DSC is running as LocalSystem Lookup privilege error #" + Marshal.GetLastWin32Error().ToString());
                }
                bResult = AdjustTokenPrivileges(
                    htok,
                    false,
                    ref tp,
                    0,
                    IntPtr.Zero,
                    IntPtr.Zero
                    );
                if(!bResult)
                {
                    throw new Win32Exception("Token elevation error #" + Marshal.GetLastWin32Error().ToString());
                }

                bResult = DuplicateTokenEx(
                    hToken,
                    GENERIC_ALL_ACCESS,
                    ref sa,
                    (int)SECURITY_IMPERSONATION_LEVEL.SecurityIdentification,
                    (int)TOKEN_TYPE.TokenPrimary,
                    ref hDupedToken
                    );
                if(!bResult)
                {
                    throw new Win32Exception("Duplicate Token error #" + Marshal.GetLastWin32Error().ToString());
                }
                var si = new STARTUPINFO();
                si.cb = Marshal.SizeOf(si);
                si.lpDesktop = "";
                bResult = CreateProcessAsUser(
                    hDupedToken,
                    null,
                    strCommand,
                    ref sa,
                    ref sa,
                    false,
                    0,
                    IntPtr.Zero,
                    null,
                    ref si,
                    ref pi
                    );
                if(!bResult)
                {
                    throw new Win32Exception("The process could not be created. Create process as user error #" + Marshal.GetLastWin32Error().ToString());
                }
            }
            finally
            {
                if (pi.hThread != IntPtr.Zero)
                {
                    CloseHandle(pi.hThread);
                }
                if (pi.hProcess != IntPtr.Zero)
                {
                    CloseHandle(pi.hProcess);
                }
                 if (hDupedToken != IntPtr.Zero)
                {
                    CloseHandle(hDupedToken);
                }
            }
        }
    }
}

"@
            Add-Type -TypeDefinition $ProgramSource -ReferencedAssemblies "System.ServiceProcess"
}

Export-ModuleMember -function Get-TargetResource, Set-TargetResource, Test-TargetResource

