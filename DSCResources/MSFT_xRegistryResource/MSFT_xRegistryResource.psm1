# This PS module contains functions for Desired State Configuration (DSC) Registry provider. It enables querying, creation, removal and update of Windows registry keys through Get, Set and Test operations on DSC managed nodes.

# Fallback message strings in en-US
DATA localizedData
{
    # culture = "en-US"
    ConvertFrom-StringData @'
        ParameterValueInvalid = (ERROR) Parameter '{0}' has an invalid value '{1}' for type '{2}'
        InvalidPSDriveSpecified = (ERROR) Invalid PSDrive '{0}' specified in registry key '{1}'
        InvalidRegistryHiveSpecified = (ERROR) Invalid registry hive was specified in registry key '{0}'
        SetRegValueFailed = (ERROR) Failed to set registry key value '{0}' to value '{1}' of type '{2}'
        SetRegValueUnchanged = (UNCHANGED) No change to registry key value '{0}' containing '{1}'
        SetRegKeyUnchanged = (UNCHANGED) No change to registry key '{0}'
        SetRegValueSucceeded = (SET) Set registry key value '{0}' to '{1}' of type '{2}'
        SetRegKeySucceeded = (SET) Create registry key '{0}'
        SetRegKeyFailed = (ERROR) Failed to created registry key '{0}'
        RemoveRegKeyTreeFailed = (ERROR) Registry Key '{0}' has subkeys, cannot remove without Force flag
        RemoveRegKeySucceeded = (REMOVAL) Registry key '{0}' removed
        RemoveRegKeyFailed = (ERROR) Failed to remove registry key '{0}'
        RemoveRegValueSucceeded = (REMOVAL) Registry key value '{0}' removed
        RemoveRegValueFailed = (ERROR) Failed to remove registry key value '{0}'
        RegKeyDoesNotExist = Registry key '{0}' does not exist
        RegKeyExists = Registry key '{0}' exists
        RegValueExists = Found registry key value '{0}' with type '{1}' and data '{2}'
        RegValueDoesNotExist = Registry key value '{0}' does not exist
        RegValueTypeMismatch = Registry key value '{0}' of type '{1}' does not exist
        RegValueDataMismatch = Registry key value '{0}' of type '{1}' does not contain data '{2}'
        DefaultValueDisplayName = (Default)
'@
}
Import-LocalizedData LocalizedData -filename MSFT_xRegistryResource.strings.psd1

#--------------------------------------
# The Get-TargetResourceInternal cmdlet
#--------------------------------------
FUNCTION Get-TargetResourceInternal
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Key,

        # Default is [String]::Empty to cater for the (Default) RegValue
        [System.String]
        $ValueName = [String]::Empty
    )

    # Perform any required setup steps for the provider
    SetupProvider -KeyName ([ref]$Key)

    $ValueNameSpecified = $PSBoundParameters.ContainsKey("ValueName")

    # First check if the specified key exists
    $keyInfo = GetRegistryKey -Path $Key -ErrorAction SilentlyContinue

    # If $keyInfo is $null, the registry key doesn't exist
    if ($keyInfo -eq $null)
    {
        Write-Verbose ($localizedData.RegKeyDoesNotExist -f $Key)

        $retVal = @{Ensure='Absent'; Key=$Key}

        return $retVal
    }

    # If the control reaches here, the key has been found at least
    $retVal = @{Ensure='Present'; Key=$Key; Data=$keyInfo}

    # If $ValueName parameter has not been specified then we simply report success on finding the $Key
    if (!$ValueNameSpecified)
    {
        Write-Verbose ($localizedData.RegKeyExists -f $Key)

        return $retVal
    }

    # If the control reaches here, the $ValueName has been specified as a parameter and we should query it now
    $valData = $keyInfo.GetValue($ValueName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)

    # If $ValueName is not found in the specified $Key
    if($valData -eq $null)
    {
        Write-Verbose ($localizedData.RegValueDoesNotExist -f "$Key\$ValueName")

        $retVal = @{Ensure='Absent'; Key=$Key; ValueName=(GetValueDisplayName -ValueName $ValueName)}

        return $retVal
    }

    # Finalize name, type and data to be returned
    $finalName = GetValueDisplayName -ValueName $ValueName
    $finalType = $keyInfo.GetValueKind($ValueName)
    $finalData = $valData

    # Special case: For Binary type data we convert the received bytes back to a readable hex-strin
    if ($finalType -ieq "Binary")
    {
        $finalData = ConvertByteArrayToHexString -Data $valData
    }

    # Populate all config in the return object
    $retVal.ValueName = $finalName
    $retVal.ValueType = $finalType
    $retVal.Data =  $finalData

    # If the control reaches here, both the $Key and the $ValueName have been found, query is fully successful
    Write-Verbose ($localizedData.RegValueExists -f "$Key\$ValueName", $retVal.ValueType, (ArrayToString $retVal.Data))

    return $retVal
}

#------------------------------
# The Get-TargetResource cmdlet
#------------------------------
FUNCTION Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Key,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [AllowEmptyString()]
        [System.String]
        $ValueName,

        # Special-case: Used only as a boolean flag (along with ValueType) to determine if the target entity is the Default Value or the key itself.
        [System.String[]]
        $ValueData,

        # Special-case: Used only as a boolean flag (along with ValueData) to determine if the target entity is the Default Value or the key itself.
        [ValidateSet("String", "Binary", "Dword", "Qword", "MultiString", "ExpandString")]
        [System.String]
        $ValueType
    )

    # If $ValueName is "" and ValueType and ValueData are both not specified, then we target the key itself (not Default Value)
    if ($ValueName -eq "" -and !$PSBoundParameters.ContainsKey("ValueType") -and !$PSBoundParameters.ContainsKey("ValueData"))
    {
        $retVal = Get-TargetResourceInternal -Key $Key
    }
    else
    {
        $retVal = Get-TargetResourceInternal -Key $Key -ValueName $ValueName

        if ($retVal.Ensure -eq 'Present')
        {
            [string[]]$retVal.ValueData += $retVal.Data

            if ($retVal.ValueType -ieq "MultiString")
            {
                $retVal.ValueData = $retVal.Data
            }
        }
    }

    $retVal.Remove("Data")

    return $retVal
}


#------------------------------
# The Set-TargetResource cmdlet
#------------------------------
FUNCTION Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Key,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [AllowEmptyString()]
        [System.String]
        $ValueName,

        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = "Present",

        [ValidateNotNull()]
        [System.String[]]
        $ValueData = @(),

        [ValidateSet("String", "Binary", "Dword", "Qword", "MultiString", "ExpandString")]
        [System.String]
        $ValueType = "String",

        [System.Boolean]
        $Hex = $false,

        [System.Boolean]
        $Force = $false
    )

    # Perform any required setup steps for the provider
    SetupProvider -KeyName ([ref]$Key)

    # Query if the RegVal related parameters have been specified
    $ValueNameSpecified = $PSBoundParameters.ContainsKey("ValueName")
    $ValueTypeSpecified = $PSBoundParameters.ContainsKey("ValueType")
    $ValueDataSpecified = $PSBoundParameters.ContainsKey("ValueData")
    $keyCreated = $false

    # If an empty string ValueName has been specified and no ValueType and no ValueData has been specified,
    # treat this case as if ValueName was not specified and target the Key itself. This is to cater the limitation
    # that both Key and ValueName are mandatory now and we must special-case like this to target the Key only.
    if ($ValueName -eq "" -and !$ValueTypeSpecified -and !$ValueDataSpecified)
    {
        $ValueNameSpecified = $false
    }

    # Now, query the specified key
    $keyInfo = Get-TargetResourceInternal -Key $Key -Verbose:$false

    # ----------------
    # ENSURE = PRESENT
    if ($Ensure -ieq "Present")
    {
        # If key doesn't exist, attempt to create it
        if ($keyInfo.Ensure -ieq "Absent")
        {
            if ($PSCmdlet.ShouldProcess(($localizedData.SetRegKeySucceeded -f "$Key"), $null, $null))
            {
                try
                {
                    $keyInfo = CreateRegistryKey -Key $Key
                    $keyCreated = $true
                }
                catch [Exception]
                {
                    Write-Verbose ($localizedData.SetRegKeyFailed -f "$Key")

                    throw
                }
            }
        }

        # If $ValueName, $ValueType and $ValueData are not specified, the simple existence/creation of the Regkey satisfies the Ensure=Present condition, just return
        if (!$ValueNameSpecified -and !$ValueDataSpecified -and !$ValueTypeSpecified)
        {
            if (!$keyCreated)
            {
                Write-Log ($localizedData.SetRegKeyUnchanged -f "$Key")
            }

            return
        }

        # If $ValueType and $ValueData are both not specified, but $ValueName is specified, check if the Value exists, if yes return with status unchanged, otherwise report input error
        if (!$ValueTypeSpecified -and !$ValueDataSpecified -and $ValueNameSpecified)
        {
            $valData = $keyInfo.Data.GetValue($ValueName)

            if ($valData -ne $null)
            {
                Write-Log ($localizedData.SetRegValueUnchanged -f "$Key\$ValueName", (ArrayToString -Value $valData))

                return
            }
        }

        # Create a strongly-typed object (in accordance with the specified $ValueType)
        $setVal = $null
        GetTypedObject -Type $ValueType -Data $ValueData -Hex $Hex -ReturnValue ([ref]$setVal)

        # Get the appropriate display name for the specified ValueName (to handle the Default RegValue case)
        $valDisplayName = GetValueDisplayName -ValueName $ValueName

        if ($PSCmdlet.ShouldProcess(($localizedData.SetRegValueSucceeded -f "$Key\$valDisplayName", (ArrayToString -Value $setVal), $ValueType), $null, $null))
        {
            try
            {
                # Finally set the $ValueName here
                [Microsoft.Win32.Registry]::SetValue($keyInfo.Data.Name, $ValueName, $setVal, $ValueType)
            }
            catch [Exception]
            {
                Write-Verbose ($localizedData.SetRegValueFailed -f "$Key\$valDisplayName", (ArrayToString -Value $setVal), $ValueType)

                throw
            }
        }
    }

    # ---------------
    # ENSURE = ABSENT
    elseif ($Ensure -ieq "Absent")
    {
        # If key doesn't exist, no action is required
        if ($keyInfo.Ensure -ieq "Absent")
        {
            Write-Log ($localizedData.RegKeyDoesNotExist -f "$Key")

            return
        }

        # If the code reaches here, the key exists

        # If ValueName is "" and ValueType and ValueData have not been specified, target the key for removal
        if(!$ValueNameSpecified -and !$ValueTypeSpecified -and !$ValueDataSpecified)
        {
            # If this is not a Force removal and the Key contains subkeys, report no change and return
            if (!$Force -and ($keyInfo.Data.SubKeyCount -gt 0))
            {
                $errorMessage = $localizedData.RemoveRegKeyTreeFailed -f "$Key"

                Write-Log $errorMessage

                ThrowError -ExceptionName "System.InvalidOperationException" -ExceptionMessage $errorMessage -ExceptionObject $Force -ErrorId "CannotRemoveKeyTreeWithoutForceFlag" -ErrorCategory NotSpecified
            }

            # If the control reaches here, either the $Force flag was specified or the Regkey has no subkeys. In either case we simply remove it.

            if ($PSCmdlet.ShouldProcess(($localizedData.RemoveRegKeySucceeded -f $Key), $null, $null))
            {
                try
                {
                    # Formulate hiveName and subkeyName compatible with .NET APIs
                    $hiveName = $keyInfo.Data.PSDrive.Root.Replace("_","").Replace("HKEY","")
                    $subkeyName = $keyInfo.Data.Name.Substring($keyInfo.Data.Name.IndexOf("\")+1)

                    # Finally remove the subkeytree
                    [Microsoft.Win32.Registry]::$hiveName.DeleteSubKeyTree($subkeyName)
                }
                catch [Exception]
                {
                    Write-Verbose ($localizedData.RemoveRegKeyFailed -f "$Key")

                    throw
                }
            }

            return
        }

        # If the control reaches here, ValueName has been specified so a RegValue needs be removed (if found)

        # Get the appropriate display name for the specified ValueName (to handle the Default RegValue case)
        $valDisplayName = GetValueDisplayName -ValueName $ValueName

        # Query the specified $ValueName
        $valData = $keyInfo.Data.GetValue($ValueName)

        # If $ValueName is not found in the specified $Key
        if($valData -eq $null)
        {
            Write-Log ($localizedData.RegValueDoesNotExist -f "$Key\$valDisplayName")

            return
        }

        # If the control reaches here, the specified Value has been found and should be removed.

        if ($PSCmdlet.ShouldProcess(($localizedData.RemoveRegValueSucceeded -f "$Key\$valDisplayName"), $null, $null))
        {
            try
            {
                # Formulate hiveName and subkeyName compatible with .NET APIs
                $hiveName = $keyInfo.Data.PSDrive.Root.Replace("_","").Replace("HKEY","")
                $subkeyName = $keyInfo.Data.Name.Substring($keyInfo.Data.Name.IndexOf("\")+1)

                # Finally open the subkey and remove the RegValue in subkey
                $subkey = [Microsoft.Win32.Registry]::$hiveName.OpenSubKey($subkeyName, $true)
                $subkey.DeleteValue($ValueName)

            }
            catch [Exception]
            {
                Write-Verbose ($localizedData.RemoveRegValueFailed -f "$Key\$valDisplayName")

                throw
            }
        }
    }
}


#-------------------------------
# The Test-TargetResource cmdlet
#-------------------------------
FUNCTION Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Key,

        [parameter(Mandatory)]
        [AllowEmptyString()]
        [ValidateNotNull()]
        [System.String]
        $ValueName,

        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = "Present",

        [ValidateNotNull()]
        [System.String[]]
        $ValueData = @(),

        [ValidateSet("String", "Binary", "Dword", "Qword", "MultiString", "ExpandString")]
        [System.String]
        $ValueType = "String",

        [System.Boolean]
        $Hex = $false,

        # Force is not used in Test-TargetResource but is required by DSC engine to keep parameter-sets in parity for both SET and TEST
        [System.Boolean]
        $Force = $false
    )

    # Perform any required setup steps for the provider
    SetupProvider -KeyName ([ref]$Key)

    # Query if the RegVal related parameters have been specified
    $ValueNameSpecified = $PSBoundParameters.ContainsKey("ValueName")
    $ValueTypeSpecified = $PSBoundParameters.ContainsKey("ValueType")
    $ValueDataSpecified = $PSBoundParameters.ContainsKey("ValueData")

    # If an empty string ValueName has been specified and no ValueType and no ValueData has been specified,
    # treat this case as if ValueName was not specified and target the Key itself. This is to cater the limitation
    # that both Key and ValueName are mandatory now and we must special-case like this to target the Key only.
    if (($ValueName -eq "") -and !$ValueTypeSpecified -and !$ValueDataSpecified)
    {
        $ValueNameSpecified = $false
    }

    # Now, query the specified key
    $keyInfo = Get-TargetResourceInternal -Key $Key -Verbose:$false

    # ----------------
    # ENSURE = PRESENT
    if ($Ensure -ieq "Present")
    {
        # If key doesn't exist, the test fails
        if ($keyInfo.Ensure -ieq "Absent")
        {
            Write-Verbose ($localizedData.RegKeyDoesNotExist -f $Key)

            return $false
        }

        # If $ValueName, $ValueType and $ValueData are not specified, the simple existence of the Regkey satisfies the Ensure=Present condition, test is successful
        if (!$ValueNameSpecified -and !$ValueDataSpecified -and !$ValueTypeSpecified)
        {
            Write-Verbose ($localizedData.RegKeyExists -f $Key)

            return $true
        }

        # IF THE CONTROL REACHED HERE, THE KEY EXISTS AND A REGVALUE ATTRIBUTE HAS BEEN SPECIFIED

        # Get the appropriate display name for the specified ValueName (to handle the Default RegValue case)
        $valDisplayName = GetValueDisplayName -ValueName $ValueName

        # Now query the specified Reg Value
        $valData = Get-TargetResourceInternal -Key $Key -ValueName $ValueName -Verbose:$false

        # If the Value doesn't exist, the test has failed
        if ($valData.Ensure -ieq "Absent")
        {
            Write-Verbose ($localizedData.RegValueDoesNotExist -f "$Key\$valDisplayName")

            return $false
        }

        # IF THE CONTROL REACHED HERE, THE KEY EXISTS AND THE SPECIFIED (or Default) VALUE EXISTS

        # If the $ValueType has been specified and it doesn't match the type of the found RegValue, test fails
        if ($ValueTypeSpecified -and ($ValueType -ine $valData.ValueType))
        {
            Write-Verbose ($localizedData.RegValueTypeMismatch -f "$Key\$valDisplayName", $ValueType)

            return $false
        }

        # If an explicit ValueType has not been specified, given the Value already exists in Registry, assume the ValueType to be of the existing Value
        if (!$ValueTypeSpecified)
        {
            $ValueType = $valData.ValueType
        }

        # If $ValueData has been specified, match the data of the found Regvalue.
        if ($ValueDataSpecified -and !(ValueDataMatches -RetrievedValue $valData -ValueType $ValueType -ValueData $ValueData))
        {
            # Since the $ValueData specified didn't match the data of the found RegValue, test failed
            Write-Verbose ($localizedData.RegValueDataMismatch -f "$Key\$valDisplayName", $ValueType, (ArrayToString -Value $ValueData))

            return $false
        }

        # IF THE CONTROL REACHED HERE, ALL TESTS HAVE PASSED FOR THE SPECIFIED REGISTRY VALUE AND IT COMPLETELY MATCHES, REPORT SUCCESS

        Write-Verbose ($localizedData.RegValueExists -f "$Key\$valDisplayName", $valData.ValueType, (ArrayToString -Value $valData.Data))

        return $true
    }

    # ---------------
    # ENSURE = ABSENT
    elseif ($Ensure -ieq "Absent")
    {
        # If key doesn't exist, test is successful
        if ($keyInfo.Ensure -ieq "Absent")
        {
            Write-Log ($localizedData.RegKeyDoesNotExist -f "$Key")

            return $true
        }

        # IF CONTROL REACHED HERE, THE SPECIFIED KEY EXISTS

        # If $ValueName, $ValueType and $ValueData are not specified, the simple existence of the Regkey fails the test
        if (!$ValueNameSpecified -and !$ValueDataSpecified -and !$ValueTypeSpecified)
        {
            Write-Verbose ($localizedData.RegKeyExists -f $Key)

            return $false
        }

        # IF THE CONTROL REACHED HERE, THE KEY EXISTS AND A REGVALUE ATTRIBUTE HAS BEEN SPECIFIED

        # Get the appropriate display name for the specified ValueName (to handle the Default RegValue case)
        $valDisplayName = GetValueDisplayName -ValueName $ValueName

        # Now query the specified RegValue
        $valData = Get-TargetResourceInternal -Key $Key -ValueName $ValueName -Verbose:$false

        # If the Value doesn't exist, the test has passed
        if ($valData.Ensure -ieq "Absent")
        {
            Write-Verbose ($localizedData.RegValueDoesNotExist -f "$Key\$valDisplayName")

            return $true
        }

        # IF THE CONTROL REACHED HERE, THE KEY EXISTS AND THE SPECIFIED (or Default) VALUE EXISTS, THUS REPORT FAILURE

        Write-Verbose ($localizedData.RegValueExists -f "$Key\$valDisplayName", $valData.ValueType, (ArrayToString -Value $valData.Data))

        return $false
    }
}

#--------------------------------------------
# Utility to open a registry key
#--------------------------------------------
function GetRegistryKey
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Path
    )

    # By the time we get here, the SetupProvider function has already set up our path to start with a PSDrive,
    # and validated that it exists, is a Registry drive, has a valid root.

    # We're using this method instead of Get-Item so there is no ambiguity between forward slashes being treated
    # as a path separator vs a literal character in a key name (which is legal in the registry.)

    $driveName = $Path -replace ':.*'
    $subKey = $Path -replace '^[^:]+:\\*'

    $drive = Get-Item -literalPath "${driveName}:\"
    return $drive.OpenSubKey($subKey, $true)
}


#--------------------------------------------
# Utility to create an arbitrary registry key
#--------------------------------------------
FUNCTION CreateRegistryKey
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Key
    )

    # Trim any "\" back-slash(es) at the end of the specified RegKey
    $Key = ([string]$Key).TrimEnd('\')

    # Extract the parent-key
    $slashIndex = $Key.LastIndexOf('\')
    $parentKey = $Key.Substring(0, $slashIndex)
    $childKey = $Key.Substring($slashIndex + 1)

    # Check if the parent-key exists, if not first create that (recurse).
    if ((Get-TargetResourceInternal -Key $parentKey -Verbose:$false).Ensure -eq "Absent")
    {
        CreateRegistryKey -Key $parentKey | Out-Null
    }

    $parentKeyObject = GetRegistryKey -Path $parentKey

    # Create the Regkey
    try
    {
        $null = $parentKeyObject.CreateSubKey($childKey)
    }
    catch
    {
        throw
    }

    # If the control reaches here, the key was created successfully
    return (Get-TargetResourceInternal -Key $Key -Verbose:$false)
}


#-------------------------------------------
# Validate PSDrive specified in Registry Key
#-------------------------------------------
FUNCTION ValidatePSDrive
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Key
    )

    # Extract the PSDriveName from the specified Key
    $psDriveName = $Key.Substring(0, $Key.IndexOf(':'))

    # Query the specified PSDrive
    $psDrive = Get-PSDrive $psDriveName -ErrorAction SilentlyContinue

    # Validate that the specified psdrive is a valid
    if (($psDrive -eq $null) -or ($psDrive.Provider -eq $null) -or ($psDrive.Provider.Name -ine "Registry") -or !(IsValidRegistryRoot -PSDriveRoot $psDrive.Root))
    {
        $errorMessage = $localizedData.InvalidPSDriveSpecified -f $psDriveName, $Key
        ThrowError -ExceptionName "System.ArgumentException" -ExceptionMessage $errorMessage -ExceptionObject $Key -ErrorId "InvalidPSDrive" -ErrorCategory InvalidArgument
    }
}


#--------------------------------------------------
# Check if the PSDriveRoot is a valid registry root
#--------------------------------------------------
FUNCTION IsValidRegistryRoot
{
    param
    (
        [System.String]
        $PSDriveRoot
    )

    # List of valid registry roots
    $validRegistryRoots = @("HKEY_CLASSES_ROOT", "HKEY_CURRENT_USER", "HKEY_LOCAL_MACHINE", "HKEY_USERS", "HKEY_CURRENT_CONFIG")

    # Extract the base of the PSDrive root
    if ($PSDriveRoot.Contains('\'))
    {
        $PSDriveRoot = $PSDriveRoot.Substring(0, $PSDriveRoot.IndexOf('\'))
    }

    return ($validRegistryRoots -icontains $PSDriveRoot)
}


#----------------------------------------
# Utility to write WhatIf or Verbose logs
#----------------------------------------
FUNCTION Write-Log
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


#------------------------------------
# Utility to throw an error/exception
#------------------------------------
FUNCTION ThrowError
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionName,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionMessage,

         [System.Object]
        $ExceptionObject,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorCategory]
        $ErrorCategory
    )

    $exception = New-Object $ExceptionName $ExceptionMessage;
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $ErrorId, $ErrorCategory, $ExceptionObject
    throw $errorRecord
}


#----------------------------------------------------------------------
# Utility to construct a strongly-typed object based on specified $Type
#----------------------------------------------------------------------
FUNCTION GetTypedObject
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Type,

        [System.String[]]
        $Data,

        [ValidateNotNull()]
        [Boolean]
        $Hex,

        [ref] $ReturnValue
    )

    $ArgumentExceptionScriptBlock =
    {
        Param($ErrorId)

        $errorMessage = $localizedData.ParameterValueInvalid -f "ValueData", (ArrayToString -Value $Data), $Type
        Write-Verbose $errorMessage
        ThrowError -ExceptionName "System.ArgumentException" -ExceptionMessage $errorMessage -ExceptionObject $Data -ErrorId $ErrorId -ErrorCategory InvalidArgument
    }

    # The the $Type specified is not a multistring then we always expect a non-array $Data. If this is not the case, throw an error and let the user know.
    if (($Type -ine "Multistring") -and ($Data -ne $null) -and ($Data.Count -gt 1))
    {
        Invoke-Command -ScriptBlock $ArgumentExceptionScriptBlock -ArgumentList ([String]::Format("ArrayNotExpectedForType{0}", $Type))
    }

    Switch($Type)
    {
        # Case: String
        "String"
        {
            if (($Data -eq $null) -or ($Data.Length -eq 0))
            {
                $ReturnValue.Value = [String]::Empty

                return
            }

            $ReturnValue.Value = [String]$Data[0]
        }

        # Case: ExpandString
        "ExpandString"
        {
            if (($Data -eq $null) -or ($Data.Length -eq 0))
            {
                $ReturnValue.Value = [String]::Empty

                return
            }

            $ReturnValue.Value = [String]$Data[0]
        }

        # Case: MultiString
        "MultiString"
        {
            if (($Data -eq $null) -or ($Data.Length -eq 0))
            {
                $ReturnValue.Value = [String[]]@()

                return
            }

            $ReturnValue.Value = [String[]]$Data
        }

        # Case: DWord
        "DWord"
        {
            if (($Data -eq $null) -or ($Data.Length -eq 0))
            {
                $ReturnValue.Value = [Int32]0
            }
            elseif ($Hex)
            {
                $retVal = $null
                $val = $Data[0].TrimStart("0x")

                if ([Int32]::TryParse($val, "HexNumber", [System.Globalization.CultureInfo]::CurrentCulture, [ref] $retVal))
                {
                    $ReturnValue.Value = $retVal
                }
                else
                {
                    Invoke-Command -ScriptBlock $ArgumentExceptionScriptBlock -ArgumentList "ValueDataNotInHexFormat"
                }
            }
            else
            {
                $ReturnValue.Value = [Int32]::Parse($Data[0])
            }
        }

        # Case: QWord
        "QWord"
        {
            if (($Data -eq $null) -or ($Data.Length -eq 0))
            {
                $ReturnValue.Value = [Int64]0
            }
            elseif ($Hex)
            {
                $retVal = $null
                $val = $Data[0].TrimStart("0x")

                if ([Int64]::TryParse($val, "HexNumber", [System.Globalization.CultureInfo]::CurrentCulture, [ref] $retVal))
                {
                    $ReturnValue.Value = $retVal
                }
                else
                {
                    Invoke-Command -ScriptBlock $ArgumentExceptionScriptBlock -ArgumentList "ValueDataNotInHexFormat"
                }
            }
            else
            {
                $ReturnValue.Value = [Int64]::Parse($Data[0])
            }
        }

        # Case: Binary
        "Binary"
        {
            if (($Data -eq $null) -or ($Data.Length -eq 0))
            {
                $ReturnValue.Value = [Byte[]]@()

                return
            }

            $binaryVal = $null
            $val = $Data[0].TrimStart("0x")
            if ($val.Length % 2 -ne 0)
            {
                $val = $val.PadLeft($val.Length+1, "0")
            }

            try
            {
                $byteArray = [Byte[]]@()

                for ($i = 0 ; $i -lt ($val.Length-1) ; $i = $i+2)
                {
                    $byteArray += [Byte]::Parse($val.Substring($i, 2), "HexNumber")
                }

                $ReturnValue.Value = [Byte[]]$byteArray
            }
            catch [Exception]
            {
                Invoke-Command -ScriptBlock $ArgumentExceptionScriptBlock -ArgumentList "ValueDataNotInHexFormat"
            }
        }
    }
}


#-------------------------------------------------------
# Utility to convert an array to a string representation
#-------------------------------------------------------
FUNCTION ArrayToString
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Object]
        $Value
    )

    if (!$Value.GetType().IsArray)
    {
        return $Value.ToString()
    }
    if ($Value.Length -eq 1)
    {
        return $Value[0].ToString()
    }

    [System.Text.StringBuilder]$retString = "("

    $Value | % {$retString = ($retString.ToString() + $_.ToString() + ", ")}

    $retString = $retString.ToString().TrimEnd(", ") + ")"

    return $retString.ToString()
}


#-------------------------------------------------------
# Utility to convert an array to a string representation
#-------------------------------------------------------
FUNCTION ConvertByteArrayToHexString
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Object]
        $Data
    )

    $retString = ""
    $Data | % {$retString += [String]::Format("{0:x}", $_)}

    return $retString
}


#--------------------------------------------------------------
# Utility to handle the display name for the (Default) RegValue
#--------------------------------------------------------------
FUNCTION GetValueDisplayName
{
    param
    (
        [System.String]
        $ValueName
    )

    if ([String]::IsNullOrEmpty($ValueName))
    {
        return $localizedData.DefaultValueDisplayName
    }

    return $ValueName
}


#---------------------------------------------------------
# Utility to mount the optional Registry hives as PSDrives
#---------------------------------------------------------
FUNCTION MountRequiredRegistryHives
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $KeyName
    )

    $psDriveNames = (Get-PSDrive).Name.ToUpperInvariant()

    if ($KeyName.StartsWith("HKCR","OrdinalIgnoreCase") -and !$psDriveNames.Contains("HKCR"))
    {
        New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -Scope "Script" -WhatIf:$false | Out-Null
    }
    elseif ($KeyName.StartsWith("HKUS","OrdinalIgnoreCase") -and !$psDriveNames.Contains("HKUS"))
    {
        New-PSDrive -Name HKUS -PSProvider Registry -Root HKEY_USERS -Scope "Script" -WhatIf:$false | Out-Null
    }
    elseif ($KeyName.StartsWith("HKCC","OrdinalIgnoreCase") -and !$psDriveNames.Contains("HKCC"))
    {
        New-PSDrive -Name HKCC -PSProvider Registry -Root HKEY_CURRENT_CONFIG -Scope "Script" -WhatIf:$false | Out-Null
    }
    elseif ($KeyName.StartsWith("HKCU","OrdinalIgnoreCase") -and !$psDriveNames.Contains("HKCU"))
    {
        New-PSDrive -Name HKCU -PSProvider Registry -Root HKEY_CURRENT_USER -Scope "Script" -WhatIf:$false | Out-Null
    }
    elseif ($KeyName.StartsWith("HKLM","OrdinalIgnoreCase") -and !$psDriveNames.Contains("HKLM"))
    {
        New-PSDrive -Name HKLM -PSProvider Registry -Root HKEY_LOCAL_MACHINE -Scope "Script" -WhatIf:$false | Out-Null
    }
}


#---------------------------------------------------------
# Utility to mount the optional Registry hives as PSDrives
#---------------------------------------------------------
FUNCTION SetupProvider
{
    param
    (
        [ValidateNotNull()]
        [ref] $KeyName
    )

    # Fix $KeyName if required
    if (!$KeyName.Value.ToString().Contains(":"))
    {
        if ($KeyName.Value.ToString().StartsWith("hkey_users","OrdinalIgnoreCase"))
        {
            $KeyName.Value =  $KeyName.Value.ToString() -replace "hkey_users", "HKUS:"
        }
        elseif ($KeyName.Value.ToString().StartsWith("hkey_current_config","OrdinalIgnoreCase"))
        {
            $KeyName.Value =  $KeyName.Value.ToString() -replace "hkey_current_config", "HKCC:"
        }
        elseif ($KeyName.Value.ToString().StartsWith("hkey_classes_root","OrdinalIgnoreCase"))
        {
            $KeyName.Value =  $KeyName.Value.ToString() -replace "hkey_classes_root", "HKCR:"
        }
        elseif ($KeyName.Value.ToString().StartsWith("hkey_local_machine","OrdinalIgnoreCase"))
        {
            $KeyName.Value =  $KeyName.Value.ToString() -replace "hkey_local_machine", "HKLM:"
        }
        elseif ($KeyName.Value.ToString().StartsWith("hkey_current_user","OrdinalIgnoreCase"))
        {
            $KeyName.Value =  $KeyName.Value.ToString() -replace "hkey_current_user", "HKCU:"
        }
        else
        {
            $errorMessage = $localizedData.InvalidRegistryHiveSpecified -f $Key
            ThrowError -ExceptionName "System.ArgumentException" -ExceptionMessage $errorMessage -ExceptionObject $KeyName -ErrorId "InvalidRegistryHive" -ErrorCategory InvalidArgument
        }
    }

    # Mount any required registry hives
    MountRequiredRegistryHives -KeyName $KeyName.Value.ToString()

    # Check the target PSDrive to be a valid Registry Hive root
    ValidatePSDrive -Key $KeyName.Value.ToString()
}

#----------------------------------------------------------------------------------------
# Refactored utility to decide if the ValueData specified matches the ValueData retrieved
#----------------------------------------------------------------------------------------
FUNCTION ValueDataMatches
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Object]
        $RetrievedValue,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ValueType,

        [System.String[]]
        $ValueData
    )

    # Convert the specified $ValueData into strongly-typed data for correct comparsion
    $specifiedData = $null
    $retrievedData = $RetrievedValue.Data

    GetTypedObject -Type $ValueType -Data $ValueData -Hex $Hex -ReturnValue ([ref]$specifiedData)

    # Special case for binary comparison (do hex-string comparison)
    if ($ValueType -ieq "Binary")
    {
        $specifiedData = $ValueData[0]
    }

    # If the ValueType is not multistring, do a simple comparison
    if ($ValueType -ine "Multistring")
    {
        return ($specifiedData -ieq $retrievedData)
    }

    # IF THE CONTROL REACHES HERE, THE ValueType IS A "MultiString" and we need a size-based and element-by-element comparsion for it

    # Array-size comparison
    if ($specifiedData.Length -ne $retrievedData.Length)
    {
        # Size mismatch
        return $false
    }

    # Element-by-Element comparison
    for ($i = 0 ; $i -lt $specifiedData.Length ; $i++)
    {
        if ($specifiedData[$i] -ine $retrievedData[$i])
        {
            return $false
        }
    }

    # IF THE CONTROL REACHED HERE, THE Multistring COMPARISON WAS SUCCESSFUL
    return $true
}

Export-ModuleMember -function Get-TargetResource, Set-TargetResource, Test-TargetResource
