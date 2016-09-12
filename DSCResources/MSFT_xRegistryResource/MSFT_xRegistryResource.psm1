<#
    This PS module contains functions for Desired State Configuration (DSC) Registry provider.
    It enables querying, creation, removal and update of Windows registry keys through
    Get, Set and Test operations on DSC managed nodes.
#>

# Fallback message strings in en-US
data localizedData
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
        GetTargetResourceStartMessage = Begin executing Get functionality on the Registry key {0}.
        GetTargetResourceEndMessage = End executing Get functionality on the Registry key {0}.
        SetTargetResourceStartMessage = Begin executing Set functionality on the Registry key {0}.
        SetTargetResourceEndMessage = End executing Set functionality on the Registry key {0}.
        TestTargetResourceStartMessage = Begin executing Test functionality on the Registry key {0}.
        TestTargetResourceEndMessage = End executing Test functionality on the Registry key {0}.
'@
}

# Commented-out until more languages are supported
# Import-LocalizedData LocalizedData -FileName MSFT_xRegistryResource.strings.psd1

<#
    .SYNOPSIS
        Gets the current state of the Registry item being managed.

    .PARAMETER Key
        Indicates the path of the registry key for which you want to ensure a specific state.
        This path must include the hive.

    .PARAMETER ValueName
        Indicates the name of the registry value.
#>
function Get-TargetResourceInternal
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Key,

        # Default is [String]::Empty to cater for the (Default) RegValue
        [System.String]
        $ValueName = [System.String]::Empty
    )

    # Perform any required setup steps for the provider
    Invoke-RegistryProviderSetup -KeyName ([ref] $Key)

    $valueNameSpecified = $PSBoundParameters.ContainsKey('ValueName')

    # First check if the specified key exists
    $keyInfo = Get-RegistryKeyInternal -Path $Key -ErrorAction SilentlyContinue

    # If $keyInfo is $null, the registry key doesn't exist
    if ($null -eq $keyInfo)
    {
        Write-Verbose ($localizedData.RegKeyDoesNotExist -f $Key)

        $retVal = @{
            Ensure = 'Absent'
            Key = $Key
        }

        return $retVal
    }

    # If the control reaches here, the key has been found at least
    $retVal = @{
        Ensure = 'Present'
        Key = $Key
        Data = $keyInfo
    }

    <#
        If $ValueName parameter has not been specified
        then we simply report success on finding the $Key
    #>
    if (!$valueNameSpecified)
    {
        Write-Verbose ($localizedData.RegKeyExists -f $Key)

        return $retVal
    }

    <#
        If the control reaches here, the $ValueName has been specified as a parameter
        and we should query it now
    #>
    $registryValueOptions = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
    $valData = $keyInfo.GetValue($ValueName, $null, $registryValueOptions)

    # If $ValueName is not found in the specified $Key
    if ($null -eq $valData)
    {
        Write-Verbose ($localizedData.RegValueDoesNotExist -f "$Key\$ValueName")

        $retVal = @{
            Ensure = 'Absent'
            Key = $Key
            ValueName = (Get-ValueDisplayName -ValueName $ValueName)
        }

        return $retVal
    }

    # Finalize name, type and data to be returned
    $finalName = Get-ValueDisplayName -ValueName $ValueName
    $finalType = $keyInfo.GetValueKind($ValueName)
    $finalData = $valData

    # Special case: For Binary type data we convert the received bytes back to a readable hex-string
    if ($finalType -ieq 'Binary')
    {
        $finalData = Convert-ByteArrayToHexString -Data $valData
    }

    # Populate all config in the return object
    $retVal.ValueName = $finalName
    $retVal.ValueType = $finalType
    $retVal.Data =  $finalData

    <#
        If the control reaches here, both the $Key and the $ValueName have been found,
        query is fully successful
    #>
    Write-Verbose ($localizedData.RegValueExists -f "$Key\$ValueName", $retVal.ValueType,
        (Convert-ArrayToString $retVal.Data))

    return $retVal
}

<#
    .SYNOPSIS
        Returns the current state of the Registry item being managed.

    .PARAMETER Key
        Indicates the path of the registry key for which you want to ensure a specific state.
        This path must include the hive.

    .PARAMETER ValueName
        Indicates the name of the registry value.

    .PARAMETER ValueData
        The data for the registry value.

    .PARAMETER ValueType
        Indicates the type of the value. The supported types are:
            String (REG_SZ)
            Binary (REG-BINARY)
            Dword 32-bit (REG_DWORD)
            Qword 64-bit (REG_QWORD)
            Multi-string (REG_MULTI_SZ)
            Expandable string (REG_EXPAND_SZ)
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Key,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [AllowEmptyString()]
        [System.String]
        $ValueName,

        <#
            Special-case: Used only as a boolean flag (along with ValueType) to determine
            if the target entity is the Default Value or the key itself.
        #>
        [System.String[]]
        $ValueData,

        <#
            Special-case: Used only as a boolean flag (along with ValueData) to determine
            if the target entity is the Default Value or the key itself.
        #>
        [ValidateSet('String', 'Binary', 'DWord', 'QWord', 'MultiString', 'ExpandString')]
        [System.String]
        $ValueType
    )

    Write-Verbose ($localizedData.GetTargetResourceStartMessage -f $Key)

    <#
        If $ValueName is "" and ValueType and ValueData are both not specified,
        then we target the key itself (not Default Value)
    #>
    if ($ValueName -eq '' -and !$PSBoundParameters.ContainsKey('ValueType') -and
        !$PSBoundParameters.ContainsKey('ValueData'))
    {
        $retVal = Get-TargetResourceInternal -Key $Key
    }
    else
    {
        $retVal = Get-TargetResourceInternal -Key $Key -ValueName $ValueName

        if ($retVal.Ensure -eq 'Present')
        {
            $retVal.ValueData = [System.String[]]@()
            $retVal.ValueData += $retVal.Data

            if ($retVal.ValueType -ieq 'MultiString')
            {
                $retVal.ValueData = $retVal.Data
            }
        }
    }

    $retVal.Remove('Data')

    Write-Verbose ($localizedData.GetTargetResourceEndMessage -f $Key)

    return $retVal
}

<#
    .SYNOPSIS
        Ensures the specified state of the Registry item being managed

    .PARAMETER Key
        Indicates the path of the registry key for which you want to ensure a specific state.
        This path must include the hive.

    .PARAMETER ValueName
        Indicates the name of the registry value.

    .PARAMETER Ensure
        Indicates if the key and value should exist.
        To ensure that they do, set this property to "Present".
        To ensure that they do not exist, set the property to "Absent".
        The default value is "Present".

    .PARAMETER ValueData
        The data for the registry value.

    .PARAMETER ValueType
        Indicates the type of the value. The supported types are:
            String (REG_SZ)
            Binary (REG-BINARY)
            Dword 32-bit (REG_DWORD)
            Qword 64-bit (REG_QWORD)
            Multi-string (REG_MULTI_SZ)
            Expandable string (REG_EXPAND_SZ)

    .PARAMETER Hex
        Indicates if data will be expressed in hexadecimal format.
        If specified, the DWORD/QWORD value data is presented in hexadecimal format.
        Not valid for other types. The default value is $false.

    .PARAMETER Force
        If the specified registry key is present, Force overwrites it with the new value.
#>
function Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Key,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [AllowEmptyString()]
        [System.String]
        $ValueName,

        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [ValidateNotNull()]
        [System.String[]]
        $ValueData = @(),

        [ValidateSet('String', 'Binary', 'DWord', 'QWord', 'MultiString', 'ExpandString')]
        [System.String]
        $ValueType = 'String',

        [System.Boolean]
        $Hex = $false,

        [System.Boolean]
        $Force = $false
    )

    Write-Verbose ($localizedData.SetTargetResourceStartMessage -f $Key)

    # Perform any required setup steps for the provider
    Invoke-RegistryProviderSetup -KeyName ([ref] $Key)

    # Query if the RegVal related parameters have been specified
    $valueNameSpecified = $PSBoundParameters.ContainsKey('ValueName')
    $valueTypeSpecified = $PSBoundParameters.ContainsKey('ValueType')
    $valueDataSpecified = $PSBoundParameters.ContainsKey('ValueData')
    $keyCreated = $false

    <#
        If an empty string ValueName has been specified and no ValueType and no ValueData
        has been specified, treat this case as if ValueName was not specified and target
        the Key itself. This is to cater the limitation that both Key and ValueName
        are mandatory now and we must special-case like this to target the Key only.
    #>
    if ($ValueName -eq '' -and !$valueTypeSpecified -and !$valueDataSpecified)
    {
        $valueNameSpecified = $false
    }

    # Now, query the specified key
    $keyInfo = Get-TargetResourceInternal -Key $Key -Verbose:$false

    <#
        ----------------
        ENSURE = PRESENT
    #>
    if ($Ensure -ieq 'Present')
    {
        # If key doesn't exist, attempt to create it
        if ($keyInfo.Ensure -ieq 'Absent')
        {
            if ($PSCmdlet.ShouldProcess(($localizedData.SetRegKeySucceeded -f "$Key"), $null, $null))
            {
                try
                {
                    $keyInfo = New-RegistryKeyInternal -Key $Key
                    $keyCreated = $true
                }
                catch [System.Exception]
                {
                    Write-Verbose ($localizedData.SetRegKeyFailed -f "$Key")

                    throw
                }
            }
        }

        <#
            If $ValueName, $ValueType and $ValueData are not specified, the simple existence/creation
            of the Regkey satisfies the Ensure=Present condition, just return
        #>
        if (!$valueNameSpecified -and !$valueDataSpecified -and !$valueTypeSpecified)
        {
            if (!$keyCreated)
            {
                Write-Log ($localizedData.SetRegKeyUnchanged -f "$Key")
            }

            return
        }

        <#
            If $ValueType and $ValueData are both not specified, but $ValueName is specified, check
            if the Value exists, if yes return with status unchanged, otherwise report input error
        #>
        if (!$ValueTypeSpecified -and !$valueDataSpecified -and $valueNameSpecified)
        {
            $valData = $keyInfo.Data.GetValue($ValueName)

            if ($null -ne $valData)
            {
                Write-Log ($localizedData.SetRegValueUnchanged -f "$Key\$ValueName",
                    (Convert-ArrayToString -Value $valData))

                return
            }
        }

        # Create a strongly-typed object (in accordance with the specified $ValueType)
        $setVal = $null
        Get-TypedObject -Type $ValueType -Data $ValueData -Hex $Hex -ReturnValue ([ref] $setVal)

        <#
            Get the appropriate display name for the specified ValueName
            (to handle the Default RegValue case)
        #>
        $valDisplayName = Get-ValueDisplayName -ValueName $ValueName

        if ($PSCmdlet.ShouldProcess(($localizedData.SetRegValueSucceeded -f "$Key\$valDisplayName",
            (Convert-ArrayToString -Value $setVal), $ValueType), $null, $null))
        {
            try
            {
                # Finally set the $ValueName here
                $keyName = $keyInfo.Data.Name
                [Microsoft.Win32.Registry]::SetValue($keyName, $ValueName, $setVal, $ValueType)
            }
            catch [System.Exception]
            {
                Write-Verbose ($localizedData.SetRegValueFailed -f "$Key\$valDisplayName",
                    (Convert-ArrayToString -Value $setVal), $ValueType)

                throw
            }
        }
    }

    <#
        ---------------
        ENSURE = ABSENT
    #>
    elseif ($Ensure -ieq 'Absent')
    {
        # If key doesn't exist, no action is required
        if ($keyInfo.Ensure -ieq 'Absent')
        {
            Write-Log ($localizedData.RegKeyDoesNotExist -f "$Key")

            return
        }

        # If the code reaches here, the key exists

        <#
            If ValueName is "" and ValueType and ValueData have not been specified,
            target the key for removal
        #>
        if (!$valueNameSpecified -and !$ValueTypeSpecified -and !$valueDataSpecified)
        {
            <#
                If this is not a Force removal and the Key contains subkeys,
                report no change and return
            #>
            if (!$Force -and ($keyInfo.Data.SubKeyCount -gt 0))
            {
                $errorMessage = $localizedData.RemoveRegKeyTreeFailed -f "$Key"

                Write-Log $errorMessage

                $invokeThrowErrorHelperParams = @{
                    ExceptionName = 'System.InvalidOperationException'
                    ExceptionMessage = $errorMessage
                    ExceptionObject = $Force
                    ErrorId = 'CannotRemoveKeyTreeWithoutForceFlag'
                    ErrorCategory = 'NotSpecified'
                }
                Invoke-ThrowErrorHelper @invokeThrowErrorHelperParams
            }

            <#
                If the control reaches here, either the $Force flag was specified
                or the Regkey has no subkeys. In either case we simply remove it.
            #>
            if ($PSCmdlet.ShouldProcess(($localizedData.RemoveRegKeySucceeded -f $Key), $null, $null))
            {
                try
                {
                    $null = Remove-Item -Path $Key -Recurse -Force
                }
                catch [System.Exception]
                {
                    Write-Verbose ($localizedData.RemoveRegKeyFailed -f "$Key")

                    throw
                }
            }

            return
        }

        <#
            If the control reaches here, ValueName has been specified so a RegValue
            needs be removed (if found)
        #>

        <#
            Get the appropriate display name for the specified ValueName
            (to handle the Default RegValue case)
        #>
        $valDisplayName = Get-ValueDisplayName -ValueName $ValueName

        # Query the specified $ValueName
        $valData = $keyInfo.Data.GetValue($ValueName)

        # If $ValueName is not found in the specified $Key
        if ($null -eq $valData)
        {
            Write-Log ($localizedData.RegValueDoesNotExist -f "$Key\$valDisplayName")

            return
        }

        # If the control reaches here, the specified Value has been found and should be removed.

        if ($PSCmdlet.ShouldProcess(
            ($localizedData.RemoveRegValueSucceeded -f "$Key\$valDisplayName"), $null, $null))
        {
            try
            {
                $null = Remove-ItemProperty -Path $Key -Name $ValueName -Force

            }
            catch [System.Exception]
            {
                Write-Verbose ($localizedData.RemoveRegValueFailed -f "$Key\$valDisplayName")

                throw
            }
        }
    }

    Write-Verbose ($localizedData.SetTargetResourceEndMessage -f $Key)
}

<#
    .SYNOPSIS
        Tests if the Registry item being managed is in the desired state

    .PARAMETER Key
        Indicates the path of the registry key for which you want to ensure a specific state.
        This path must include the hive.

    .PARAMETER ValueName
        Indicates the name of the registry value.

    .PARAMETER Ensure
        Indicates if the key and value should exist.
        To test that they exist, set this property to "Present".
        To test that they do not exist, set the property to "Absent".
        The default value is "Present".

    .PARAMETER ValueData
        The data for the registry value.

    .PARAMETER ValueType
        Indicates the type of the value. The supported types are:
            String (REG_SZ)
            Binary (REG-BINARY)
            Dword 32-bit (REG_DWORD)
            Qword 64-bit (REG_QWORD)
            Multi-string (REG_MULTI_SZ)
            Expandable string (REG_EXPAND_SZ)

    .PARAMETER Hex
        Indicates if data will be expressed in hexadecimal format.
        If specified, the DWORD/QWORD value data is presented in hexadecimal format.
        Not valid for other types. The default value is $false.

    .PARAMETER Force
        If the specified registry key is present, Force overwrites it with the new value.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Key,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [ValidateNotNull()]
        [System.String]
        $ValueName,

        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [ValidateNotNull()]
        [System.String[]]
        $ValueData = @(),

        [ValidateSet('String', 'Binary', 'DWord', 'QWord', 'MultiString', 'ExpandString')]
        [System.String]
        $ValueType = 'String',

        [System.Boolean]
        $Hex = $false,

        <#
            Force is not used in Test-TargetResource but is required by DSC engine
            to keep parameter-sets in parity for both SET and TEST
        #>
        [System.Boolean]
        $Force = $false
    )

    Write-Verbose ($localizedData.TestTargetResourceStartMessage -f $Key)

    # Perform any required setup steps for the provider
    Invoke-RegistryProviderSetup -KeyName ([ref] $Key)

    # Query if the RegVal related parameters have been specified
    $valueNameSpecified = $PSBoundParameters.ContainsKey('ValueName')
    $ValueTypeSpecified = $PSBoundParameters.ContainsKey('ValueType')
    $valueDataSpecified = $PSBoundParameters.ContainsKey('ValueData')

    <#
        If an empty string ValueName has been specified and no ValueType and no ValueData
        has been specified, treat this case as if ValueName was not specified and target
        the Key itself.

        This is to cater the limitation that both Key and ValueName are mandatory now and
        we must special-case like this to target the Key only.
    #>
    if (($ValueName -eq '') -and !$ValueTypeSpecified -and !$valueDataSpecified)
    {
        $valueNameSpecified = $false
    }

    # Now, query the specified key
    $keyInfo = Get-TargetResourceInternal -Key $Key -Verbose:$false

    <#
        ----------------
        ENSURE = PRESENT
    #>
    if ($Ensure -ieq 'Present')
    {
        # If key doesn't exist, the test fails
        if ($keyInfo.Ensure -ieq 'Absent')
        {
            Write-Verbose ($localizedData.RegKeyDoesNotExist -f $Key)

            return $false
        }

        <#
            If $ValueName, $ValueType and $ValueData are not specified, the simple existence
            of the Regkey satisfies the Ensure=Present condition, test is successful
        #>
        if (!$valueNameSpecified -and !$valueDataSpecified -and !$ValueTypeSpecified)
        {
            Write-Verbose ($localizedData.RegKeyExists -f $Key)

            return $true
        }

        # IF THE CONTROL REACHED HERE, THE KEY EXISTS AND A REGVALUE ATTRIBUTE HAS BEEN SPECIFIED

        <#
            Get the appropriate display name for the specified ValueName
            (to handle the Default RegValue case)
        #>
        $valDisplayName = Get-ValueDisplayName -ValueName $ValueName

        # Now query the specified Reg Value
        $valData = Get-TargetResourceInternal -Key $Key -ValueName $ValueName -Verbose:$false

        # If the Value doesn't exist, the test has failed
        if ($valData.Ensure -ieq 'Absent')
        {
            Write-Verbose ($localizedData.RegValueDoesNotExist -f "$Key\$valDisplayName")

            return $false
        }

        # IF THE CONTROL REACHED HERE, THE KEY EXISTS AND THE SPECIFIED (or Default) VALUE EXISTS

        <#
            If the $ValueType has been specified and
            it doesn't match the type of the found RegValue, test fails
        #>
        if ($ValueTypeSpecified -and ($ValueType -ine $valData.ValueType))
        {
            Write-Verbose ($localizedData.RegValueTypeMismatch -f "$Key\$valDisplayName", $ValueType)

            return $false
        }

        <#
            If an explicit ValueType has not been specified, given the Value already exists
            in Registry, assume the ValueType to be of the existing Value
        #>
        if (!$ValueTypeSpecified)
        {
            $ValueType = $valData.ValueType
        }

        # If $ValueData has been specified, match the data of the found Regvalue.
        if ($valueDataSpecified -and
            !(Compare-ValueData -RetrievedValue $valData -ValueType $ValueType -ValueData $ValueData))
        {
            # Since the $ValueData specified didn't match the data of the found RegValue, test failed
            Write-Verbose ($localizedData.RegValueDataMismatch -f "$Key\$valDisplayName",
                $ValueType, (Convert-ArrayToString -Value $ValueData))

            return $false
        }

        <#
            IF THE CONTROL REACHED HERE, ALL TESTS HAVE PASSED FOR THE SPECIFIED REGISTRY VALUE AND
            IT COMPLETELY MATCHES, REPORT SUCCESS
        #>

        Write-Verbose ($localizedData.RegValueExists -f "$Key\$valDisplayName", $valData.ValueType,
            (Convert-ArrayToString -Value $valData.Data))

        return $true
    }

    <#
        ---------------
        ENSURE = ABSENT
    #>
    elseif ($Ensure -ieq 'Absent')
    {
        # If key doesn't exist, test is successful
        if ($keyInfo.Ensure -ieq 'Absent')
        {
            Write-Log ($localizedData.RegKeyDoesNotExist -f "$Key")

            return $true
        }

        # IF CONTROL REACHED HERE, THE SPECIFIED KEY EXISTS

        <#
            If $ValueName, $ValueType and $ValueData are not specified, the simple existence of
            the Regkey fails the test
        #>
        if (!$valueNameSpecified -and !$valueDataSpecified -and !$ValueTypeSpecified)
        {
            Write-Verbose ($localizedData.RegKeyExists -f $Key)

            return $false
        }

        # IF THE CONTROL REACHED HERE, THE KEY EXISTS AND A REGVALUE ATTRIBUTE HAS BEEN SPECIFIED

        <#
            Get the appropriate display name for the specified ValueName
            (to handle the Default RegValue case)
        #>
        $valDisplayName = Get-ValueDisplayName -ValueName $ValueName

        # Now query the specified RegValue
        $valData = Get-TargetResourceInternal -Key $Key -ValueName $ValueName -Verbose:$false

        # If the Value doesn't exist, the test has passed
        if ($valData.Ensure -ieq 'Absent')
        {
            Write-Verbose ($localizedData.RegValueDoesNotExist -f "$Key\$valDisplayName")

            return $true
        }

        <#
            IF THE CONTROL REACHED HERE, THE KEY EXISTS AND THE SPECIFIED (or Default) VALUE EXISTS,
            THUS REPORT FAILURE
        #>

        Write-Verbose ($localizedData.RegValueExists -f "$Key\$valDisplayName", $valData.ValueType,
            (Convert-ArrayToString -Value $valData.Data))

        return $false
    }

    Write-Verbose ($localizedData.TestTargetResourceEndMessage -f $Key)
}

<#
    .SYNOPSIS
        Helper function to open a registry key

    .PARAMETER Path
        Indicates the path to the Registry key to be opened. This path must include the hive.

#>
function Get-RegistryKeyInternal
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.String] $Path
    )

    <#
        By the time we get here, the Invoke-RegistryProviderSetup function has already
        set up our path to start with a PSDrive,and validated that it exists, is a Registry drive,
        has a valid root.

        We're using this method instead of Get-Item so there is no ambiguity between
        forward slashes being treated as a path separator vs a literal character in a key name
        (which is legal in the registry.)
    #>

    $driveName = $Path -replace ':.*'
    $subKey = $Path -replace '^[^:]+:\\*'

    $drive = Get-Item -literalPath "${driveName}:\"
    return $drive.OpenSubKey($subKey, $true)
}

<#
    .SYNOPSIS
        Helper function to create an arbitrary registry key

    .PARAMETER Key
        Indicates the path to the Registry key to be created. This path must include the hive.
#>
function New-RegistryKeyInternal
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Key
    )

    # Trim any "\" back-slash(es) at the end of the specified RegKey
    $Key = ([System.String] $Key).TrimEnd('\')

    # Extract the parent-key
    $slashIndex = $Key.LastIndexOf('\')
    $parentKey = $Key.Substring(0, $slashIndex)
    $childKey = $Key.Substring($slashIndex + 1)

    # Check if the parent-key exists, if not first create that (recurse).
    if ((Get-TargetResourceInternal -Key $parentKey -Verbose:$false).Ensure -eq 'Absent')
    {
        New-RegistryKeyInternal -Key $parentKey | Out-Null
    }

    $parentKeyObject = Get-RegistryKeyInternal -Path $parentKey

    # Create the Regkey
    try
    {
        if ($PSCmdlet.ShouldProcess($childKey, 'Create'))
        {
            $null = $parentKeyObject.CreateSubKey($childKey)
        }
    }
    catch
    {
        throw
    }

    # If the control reaches here, the key was created successfully
    return (Get-TargetResourceInternal -Key $Key -Verbose:$false)
}

<#
    .SYNOPSIS
        Assert if the PSDrive specified in Registry Key is valid.

    .PARAMETER Key
        Indicates the path to the Registry key to be validated. This path must include the hive.
#>
function Assert-PSDriveValid
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Key
    )

    # Extract the PSDriveName from the specified Key
    $psDriveName = $Key.Substring(0, $Key.IndexOf(':'))

    # Query the specified PSDrive
    $psDrive = Get-PSDrive $psDriveName -ErrorAction SilentlyContinue

    # Validate that the specified psdrive is a valid
    if (($null -eq $psDrive) -or ($null -eq $psDrive.Provider) -or
        ($psDrive.Provider.Name -ine 'Registry') -or
        !(Test-IsValidRegistryRoot -PSDriveRoot $psDrive.Root))
    {
        $errorMessage = $localizedData.InvalidPSDriveSpecified -f $psDriveName, $Key
        $invokeThrowErrorHelperParams = @{
            ExceptionName = 'System.ArgumentException'
            ExceptionMessage = $errorMessage
            ExceptionObject = $Key
            ErrorId = 'InvalidPSDrive'
            ErrorCategory = 'InvalidArgument'
        }
        Invoke-ThrowErrorHelper @invokeThrowErrorHelperParams
    }
}

<#
    .SYNOPSIS
        Helper function to test if the PSDriveRoot is a valid registry root

    .PARAMETER PSDriveRoot
        Indicates the PSDriveRoot to be tested.
#>
function Test-IsValidRegistryRoot
{
    param
    (
        [System.String]
        $PSDriveRoot
    )

    # List of valid registry roots
    $validRegistryRoots = @('HKEY_CLASSES_ROOT', 'HKEY_CURRENT_USER', 'HKEY_LOCAL_MACHINE',
        'HKEY_USERS', 'HKEY_CURRENT_CONFIG')

    # Extract the base of the PSDrive root
    if ($PSDriveRoot.Contains('\'))
    {
        $PSDriveRoot = $PSDriveRoot.Substring(0, $PSDriveRoot.IndexOf('\'))
    }

    return ($validRegistryRoots -icontains $PSDriveRoot)
}

<#
    .SYNOPSIS
        Helper function to write WhatIf or Verbose logs

    .PARAMETER Message
        Specifies the message text to write.
#>
function Write-Log
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message
    )

    if ($PSCmdlet.ShouldProcess($Message, $null, $null))
    {
        Write-Verbose $Message
    }
}

<#
    .SYNOPSIS
        Helper function to throw an error/exception

    .PARAMETER ExceptionName
        Specifies the name of the exception class to be instantiated.

    .PARAMETER ExceptionMessage
        Specifies the message that describes the error.

    .PARAMETER ExceptionObject
        Specifies the object that was being operated on when the error occurred.

    .PARAMETER ErrorId
        Specifies a developer-defined identifier of the error.
        This identifier must be a non-localized string for a specific error type.

    .PARAMETER ErrorCategory
        Specifies the category of the error.
#>
function Invoke-ThrowErrorHelper
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionMessage,

         [System.Object]
        $ExceptionObject,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorCategory]
        $ErrorCategory
    )

    $exception = New-Object $ExceptionName $ExceptionMessage;
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $ErrorId,
        $ErrorCategory, $ExceptionObject
    throw $errorRecord
}

<#
    .SYNOPSIS
        Helper function to construct a strongly-typed object based on specified $Type

    .PARAMETER Type
        Specifies the type of the object to be constructed.

    .PARAMETER Data
        Specifies the data to be assigned to the constructed object.

    .PARAMETER Hex
        Specifies if the data is hexadecimal.

    .PARAMETER ReturnValue
        Returns a reference to the constructed object.
#>
function Get-TypedObject
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Type,

        [System.String[]]
        $Data,

        [ValidateNotNull()]
        [Boolean]
        $Hex,

        [ref]
        $ReturnValue
    )

    $ArgumentExceptionScriptBlock =
    {
        Param($ErrorId)

        $errorMessage = $localizedData.ParameterValueInvalid -f 'ValueData',
            (Convert-ArrayToString -Value $Data), $Type
        Write-Verbose $errorMessage
        $invokeThrowErrorHelperParams = @{
            ExceptionName = 'System.ArgumentException'
            ExceptionMessage = $errorMessage
            ExceptionObject = $Data
            ErrorId = $ErrorId
            ErrorCategory = 'InvalidArgument'
        }
        Invoke-ThrowErrorHelper @invokeThrowErrorHelperParams
    }

    <#
        The the $Type specified is not a multistring then we always expect a non-array $Data.
        If this is not the case, throw an error and let the user know.
    #>
    if (($Type -ine 'Multistring') -and ($null -ne $Data) -and ($Data.Count -gt 1))
    {
        $invokeCommandParams = @{
            ScriptBlock = $ArgumentExceptionScriptBlock
            ArgumentList = 'ArrayNotExpectedForType{0}' -f $Type
        }
        Invoke-Command @invokeCommandParams
    }

    Switch($Type)
    {
        # Case: String
        'String'
        {
            if (($null -eq $Data) -or ($Data.Length -eq 0))
            {
                $ReturnValue.Value = [System.String]::Empty

                return
            }

            $ReturnValue.Value = [System.String] $Data[0]
        }

        # Case: ExpandString
        'ExpandString'
        {
            if (($null -eq $Data) -or ($Data.Length -eq 0))
            {
                $ReturnValue.Value = [System.String]::Empty

                return
            }

            $ReturnValue.Value = [System.String] $Data[0]
        }

        # Case: MultiString
        'MultiString'
        {
            if (($null -eq $Data) -or ($Data.Length -eq 0))
            {
                $ReturnValue.Value = [System.String[]] @()

                return
            }

            $ReturnValue.Value = [System.String[]] $Data
        }

        # Case: DWord
        'DWord'
        {
            if (($null -eq $Data) -or ($Data.Length -eq 0))
            {
                $ReturnValue.Value = [System.Int32] 0
            }
            elseif ($Hex)
            {
                $retVal = $null
                $val = $Data[0].TrimStart('0x')

                $currentCultureInfo = [System.Globalization.CultureInfo]::CurrentCulture
                if ([System.Int32]::TryParse($val, 'HexNumber', $currentCultureInfo, [ref] $retVal))
                {
                    $ReturnValue.Value = $retVal
                }
                else
                {
                    $invokeCommandParams = @{
                        ScriptBlock = $ArgumentExceptionScriptBlock
                        ArgumentList = 'ValueDataNotInHexFormat'
                    }
                    Invoke-Command @invokeCommandParams
                }
            }
            else
            {
                $ReturnValue.Value = [System.Int32]::Parse($Data[0])
            }
        }

        # Case: QWord
        'QWord'
        {
            if (($null -eq $Data) -or ($Data.Length -eq 0))
            {
                $ReturnValue.Value = [System.Int64] 0
            }
            elseif ($Hex)
            {
                $retVal = $null
                $val = $Data[0].TrimStart('0x')

                $currentCultureInfo = [System.Globalization.CultureInfo]::CurrentCulture
                if ([System.Int64]::TryParse($val, 'HexNumber', $currentCultureInfo, [ref] $retVal))
                {
                    $ReturnValue.Value = $retVal
                }
                else
                {
                    $invokeCommandParams = @{
                        ScriptBlock = $ArgumentExceptionScriptBlock
                        ArgumentList = 'ValueDataNotInHexFormat'
                    }
                    Invoke-Command @invokeCommandParams
                }
            }
            else
            {
                $ReturnValue.Value = [System.Int64]::Parse($Data[0])
            }
        }

        # Case: Binary
        'Binary'
        {
            if (($null -eq $Data) -or ($Data.Length -eq 0))
            {
                $ReturnValue.Value = [System.Byte[]] @()

                return
            }

            $val = $Data[0].TrimStart('0x')
            if ($val.Length % 2 -ne 0)
            {
                $val = $val.PadLeft($val.Length+1, '0')
            }

            try
            {
                $byteArray = [System.Byte[]] @()

                for ($i = 0 ; $i -lt ($val.Length-1) ; $i = $i+2)
                {
                    $byteArray += [System.Byte]::Parse($val.Substring($i, 2), 'HexNumber')
                }

                $ReturnValue.Value = [System.Byte[]] $byteArray
            }
            catch [System.Exception]
            {
                $invokeCommandParams = @{
                    ScriptBlock = $ArgumentExceptionScriptBlock
                    ArgumentList = 'ValueDataNotInHexFormat'
                }
                Invoke-Command @invokeCommandParams
            }
        }
    }
}

<#
    .SYNOPSIS
        Helper function to convert an array to a string representation

    .PARAMETER Value
        Specifies the array to be converted.
#>
function Convert-ArrayToString
{
    param
    (
        [Parameter(Mandatory = $true)]
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

    [System.Text.StringBuilder] $retString = '('

    $Value | ForEach-Object {$retString = ($retString.ToString() + $_.ToString() + ', ')}

    $retString = $retString.ToString().TrimEnd(', ') + ')'

    return $retString.ToString()
}

<#
    .SYNOPSIS
        Helper function to convert a byte array to its hex string representation

    .PARAMETER Data
        Specifies the byte array to be converted.
#>
function Convert-ByteArrayToHexString
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Object]
        $Data
    )

    $retString = ''
    $Data | ForEach-Object { $retString += ('{0:x2}' -f $_) }

    return $retString
}

<#
    .SYNOPSIS
        Helper function to retrieve the display name for the (Default) RegValue

    .PARAMETER ValueName
        Specifies the name of the value to be retrieved.
#>
function Get-ValueDisplayName
{
    param
    (
        [System.String]
        $ValueName
    )

    if ([System.String]::IsNullOrEmpty($ValueName))
    {
        return $localizedData.DefaultValueDisplayName
    }

    return $ValueName
}

<#
    .SYNOPSIS
        Helper function to mount the optional Registry hives as PSDrives

    .PARAMETER KeyName
        Specifies the Registry hive to be mounted.
#>
function Mount-RequiredRegistryHive
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $KeyName
    )

    $psDriveNames = (Get-PSDrive).Name.ToUpperInvariant()

    $newPSDriveParams = @{
        PSProvider = 'Registry'
        Scope = 'Script'
        WhatIf = $false
    }
    if ($KeyName.StartsWith('HKCR','OrdinalIgnoreCase') -and !$psDriveNames.Contains('HKCR'))
    {
        $null = New-PSDrive @newPSDriveParams -Name HKCR -Root HKEY_CLASSES_ROOT
    }
    elseif ($KeyName.StartsWith('HKUS','OrdinalIgnoreCase') -and !$psDriveNames.Contains('HKUS'))
    {
        $null = New-PSDrive @newPSDriveParams -Name HKUS -Root HKEY_USERS
    }
    elseif ($KeyName.StartsWith('HKCC','OrdinalIgnoreCase') -and !$psDriveNames.Contains('HKCC'))
    {
        $null = New-PSDrive @newPSDriveParams -Name HKCC -Root HKEY_CURRENT_CONFIG
    }
    elseif ($KeyName.StartsWith('HKCU','OrdinalIgnoreCase') -and !$psDriveNames.Contains('HKCU'))
    {
        $null = New-PSDrive @newPSDriveParams -Name HKCU -Root HKEY_CURRENT_USER
    }
    elseif ($KeyName.StartsWith('HKLM','OrdinalIgnoreCase') -and !$psDriveNames.Contains('HKLM'))
    {
        $null = New-PSDrive @newPSDriveParams -Name HKLM -Root HKEY_LOCAL_MACHINE
    }
}

<#
    .SYNOPSIS
        Helper function to mount the optional Registry hives as PSDrives

    .PARAMETER KeyName
        Returns the name of the PSDrive that has been mounted.
#>
function Invoke-RegistryProviderSetup
{
    param
    (
        [ValidateNotNull()]
        [ref]
        $KeyName
    )

    # Fix $KeyName if required
    if (!$KeyName.Value.ToString().Contains(':'))
    {
        if ($KeyName.Value.ToString().StartsWith('hkey_users','OrdinalIgnoreCase'))
        {
            $KeyName.Value =  $KeyName.Value.ToString() -replace 'hkey_users', 'HKUS:'
        }
        elseif ($KeyName.Value.ToString().StartsWith('hkey_current_config','OrdinalIgnoreCase'))
        {
            $KeyName.Value =  $KeyName.Value.ToString() -replace 'hkey_current_config', 'HKCC:'
        }
        elseif ($KeyName.Value.ToString().StartsWith('hkey_classes_root','OrdinalIgnoreCase'))
        {
            $KeyName.Value =  $KeyName.Value.ToString() -replace 'hkey_classes_root', 'HKCR:'
        }
        elseif ($KeyName.Value.ToString().StartsWith('hkey_local_machine','OrdinalIgnoreCase'))
        {
            $KeyName.Value =  $KeyName.Value.ToString() -replace 'hkey_local_machine', 'HKLM:'
        }
        elseif ($KeyName.Value.ToString().StartsWith('hkey_current_user','OrdinalIgnoreCase'))
        {
            $KeyName.Value =  $KeyName.Value.ToString() -replace 'hkey_current_user', 'HKCU:'
        }
        else
        {
            $errorMessage = $localizedData.InvalidRegistryHiveSpecified -f $Key

            $invokeThrowErrorHelperParams = @{
                ExceptionName = 'System.ArgumentException'
                ExceptionMessage = $errorMessage
                ExceptionObject = $KeyName
                ErrorId = 'InvalidRegistryHive'
                ErrorCategory = InvalidArgument
            }
            Invoke-ThrowErrorHelper @invokeThrowErrorHelperParams
        }
    }

    # Mount any required registry hives
    Mount-RequiredRegistryHive -KeyName $KeyName.Value.ToString()

    # Check the target PSDrive to be a valid Registry Hive root
    Assert-PSDriveValid -Key $KeyName.Value.ToString()
}

<#
    .SYNOPSIS
        Refactored helper function to test if the ValueData specified
        matches the ValueData retrieved

    .PARAMETER RetrievedValue
        Specifies the retrieved value data.

    .PARAMETER ValueTye
        Specifies the type of the value data.

    .PARAMETER ValueData
        Specifies the value data.

#>
function Compare-ValueData
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Object]
        $RetrievedValue,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ValueType,

        [System.String[]]
        $ValueData
    )

    # Convert the specified $ValueData into strongly-typed data for correct comparsion
    $specifiedData = $null
    $retrievedData = $RetrievedValue.Data

    Get-TypedObject -Type $ValueType -Data $ValueData -Hex $Hex -ReturnValue ([ref] $specifiedData)

    # Special case for binary comparison (do hex-string comparison)
    if ($ValueType -ieq 'Binary')
    {
        $specifiedData = $ValueData[0].PadLeft($retrievedData.Length, '0')
    }

    # If the ValueType is not multistring, do a simple comparison
    if ($ValueType -ine 'Multistring')
    {
        return ($specifiedData -ieq $retrievedData)
    }

    <#
        IF THE CONTROL REACHES HERE, THE ValueType IS A "MultiString" and we need a size-based and
        element-by-element comparsion for it
    #>

    #  Array-size comparison
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

Export-ModuleMember -Function *-TargetResource
