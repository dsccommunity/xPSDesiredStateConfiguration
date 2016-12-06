$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

# Import CommonResourceHelper for Get-LocalizedData
$script:dscResourcesFolderFilePath = Split-Path $PSScriptRoot -Parent
$script:commonResourceHelperFilePath = Join-Path -Path $script:dscResourcesFolderFilePath -ChildPath 'CommonResourceHelper.psm1'
Import-Module -Name $script:commonResourceHelperFilePath

# Localized messages for verbose and error statements in this resource
$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_xRegistryResource'

$script:registryRootAbbreviations = @{
    'HKEY_CLASSES_ROOT' = 'HKCR'
    'HKEY_USERS' = 'HKUS'
    'HKEY_CURRENT_CONFIG' = 'HKCC'
    'HKEY_CURRENT_USER' = 'HKCU'
    'HKEY_LOCAL_MACHINE' = 'HKLM' 
}

<#
    .SYNOPSIS
        Retrieves the current state of the Registry resource with the given Key.

    .PARAMETER Key
        The path of the registry key to retrieve the state of.
        This path must include the registry hive.

    .PARAMETER ValueName
        The name of the registry value to retrieve the state of.

    .PARAMETER ValueData
        Used only as a boolean flag (along with ValueType) to determine if the target entity is the
        Default Value or the key itself.

    .PARAMETER ValueType
        Used only as a boolean flag (along with ValueData) to determine if the target entity is the
        Default Value or the key itself.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Key,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [AllowEmptyString()]
        [String]
        $ValueName,

        [String[]]
        $ValueData,

        [ValidateSet('String', 'Binary', 'DWord', 'QWord', 'MultiString', 'ExpandString')]
        [String]
        $ValueType
    )

    Write-Verbose -Message ($script:localizedData.GetTargetResourceStartMessage -f $Key)

    $Key = Convert-PathRegistryRootToAbbreviation -RegistryKeyPath $Key
    Mount-RegistryDrive -RegistryKeyPath $Key

    $registryKey = Get-RegistryKey -RegistryKeyPath $Key

    if ($null -eq $registryKey)
    {
        Write-Verbose -Message ($script:localizedData.RegistryKeyDoesNotExist -f $Key)

        $registryResource = @{
            Key = $Key
            Ensure = 'Absent'
        }
    }
    else
    {
        Write-Verbose -Message ($script:localizedData.RegistryKeyExists -f $Key)

        $valueNameSpecified = $ValueName -eq '' -and -not $PSBoundParameters.ContainsKey('ValueType') -and -not $PSBoundParameters.ContainsKey('ValueData')

        if ($valueNameSpecified)
        {
            $valueDisplayName = Get-ValueDisplayName -ValueName $ValueName

            $registryValueOptions = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
            $registryKeyValue = $registryKey.GetValue($ValueName, $null, $registryValueOptions)

            if ($null -eq $registryKeyValue)
            {
                Write-Verbose -Message ($script:localizedData.RegistryKeyValueDoesNotExist -f $Key, $valueDisplayName)

                $registryResource = @{
                    Key = $Key
                    Ensure = 'Absent'
                    ValueName = $valueDisplayName
                }
            }
            else
            {
                $actualValueType = $registryKey.GetValueKind($ValueName)

                # For Binary type data, convert the received bytes back to a readable hex-string
                if ($actualValueType -ieq 'Binary')
                {
                    $registryKeyValue = Convert-ByteArrayToHexString -ByteArray $registryKeyValue
                }

                if ($actualValueType -ine 'MultiString')
                {
                    $registryKeyValue = [String[]]@() + $registryKeyValue
                }

                $registryValueString = Convert-RegistryKeyValueToString -RegistryKeyValue $registryKeyValue

                Write-Verbose -Message ($script:localizedData.RegValueExists -f $Key, $valueDisplayName, $actualValueType, $registryValueString)

                $registryResource = @{
                    Key = $Key
                    Ensure = 'Present'
                    ValueName = $valueDisplayName
                    ValueType = $actualValueType
                    ValueData = $registryKeyValue
                }
            }
        }
        else
        {
            $registryResource = @{
                Key = $Key
                Ensure = 'Present'
                ValueData = [String[]]@() + $registryKey
            }
        }
    }

    Write-Verbose -Message ($script:localizedData.GetTargetResourceEndMessage -f $Key)

    return $registryResource
}

<#
    .SYNOPSIS
        Sets the Registry resource with the given Key to the specified state.

    .PARAMETER Key
        The path of the registry key to set the state of.
        This path must include the registry hive.

    .PARAMETER ValueName
        The name of the registry value to set.

    .PARAMETER Ensure
        Specifies whether or not the registry key with the given path and the registry key value with the given name should exist.
        
        To ensure that the registry key and value exists, set this property to Present.
        To ensure that the registry key and value do not exist, set this property to Absent.
        
        The default value is Present.

    .PARAMETER ValueData
        The data to set as the registry key value.

    .PARAMETER ValueType
        The type of the value to set.
        
        The supported types are:
            String (REG_SZ)
            Binary (REG-BINARY)
            Dword 32-bit (REG_DWORD)
            Qword 64-bit (REG_QWORD)
            Multi-string (REG_MULTI_SZ)
            Expandable string (REG_EXPAND_SZ)

    .PARAMETER Hex
        Specifies whether or not the value data should be expressed in hexadecimal format.

        If specified, DWORD/QWORD value data is presented in hexadecimal format.
        Not valid for other value types.
        
        The default value is $false.

    .PARAMETER Force
        Specifies whether or not to overwrite the registry key with the given path with the new
        value if it is already present.

    .NOTES
        If an empty string ValueName has been specified and no ValueType and no ValueData
        has been specified, treat this case as if ValueName was not specified and target
        the Key itself. This is to cater the limitation that both Key and ValueName
        are mandatory now and we must special-case like this to target the Key only.
#>
function Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Key,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [AllowEmptyString()]
        [String]
        $ValueName,

        [ValidateSet('Present', 'Absent')]
        [String]
        $Ensure = 'Present',

        [ValidateNotNull()]
        [String[]]
        $ValueData = @(),

        [ValidateSet('String', 'Binary', 'DWord', 'QWord', 'MultiString', 'ExpandString')]
        [String]
        $ValueType = 'String',

        [Boolean]
        $Hex = $false,

        [Boolean]
        $Force = $false
    )

    Write-Verbose -Message ($script:localizedData.SetTargetResourceStartMessage -f $Key)

    $Key = Convert-PathRegistryRootToAbbreviation -RegistryKeyPath $Key
    Mount-RegistryDrive -RegistryKeyPath $Key

    $valueNameSpecified = $PSBoundParameters.ContainsKey('ValueName')
    $valueTypeSpecified = $PSBoundParameters.ContainsKey('ValueType')
    $valueDataSpecified = $PSBoundParameters.ContainsKey('ValueData')
    $keyCreated = $false

    if ($ValueName -eq '' -and !$valueTypeSpecified -and !$valueDataSpecified)
    {
        $valueNameSpecified = $false
    }

    $registryResource = Get-TargetResource -Key $Key

    if ($Ensure -ieq 'Present')
    {
        # If key doesn't exist, attempt to create it
        if ($keyInfo.Ensure -ieq 'Absent')
        {
            if ($PSCmdlet.ShouldProcess(($script:localizedData.SetRegKeySucceeded -f "$Key"), $null, $null))
            {
                try
                {
                    $keyInfo = New-RegistryKeyInternal -Key $Key
                    $keyCreated = $true
                }
                catch [System.Exception]
                {
                    Write-Verbose ($script:localizedData.SetRegKeyFailed -f "$Key")

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
                Write-Log ($script:localizedData.SetRegKeyUnchanged -f "$Key")
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
                Write-Log ($script:localizedData.SetRegValueUnchanged -f "$Key\$ValueName",
                    (Convert-ArrayToString -Value $valData))

                return
            }
        }

        # Create a strongly-typed object (in accordance with the specified $ValueType)
        $setVal = $null
        Get-TypedObject -Type $ValueType -Data $ValueData -Hex $Hex -ReturnValue ([ref] $setVal)

        # Finally set the $ValueName here
        $keyName = $keyInfo.Data.Name
        [Microsoft.Win32.Registry]::SetValue($keyName, $ValueName, $setVal, $ValueType)
    }
    elseif ($Ensure -ieq 'Absent')
    {
        # If key doesn't exist, no action is required
        if ($keyInfo.Ensure -ieq 'Absent')
        {
            Write-Log ($script:localizedData.RegKeyDoesNotExist -f "$Key")

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
                $errorMessage = $script:localizedData.RemoveRegKeyTreeFailed -f "$Key"

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
            $null = Remove-Item -Path $Key -Recurse -Force

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
            Write-Log ($script:localizedData.RegValueDoesNotExist -f "$Key\$valDisplayName")

            return
        }

        # If the control reaches here, the specified Value has been found and should be removed.

        $null = Remove-ItemProperty -Path $Key -Name $ValueName -Force
    }

    $Key = Convert-PathRegistryRootToAbbreviation -RegistryKeyPath $Key
    Mount-RegistryDrive -RegistryKeyPath $Key

    $valueNameSpecified = $PSBoundParameters.ContainsKey('ValueName')
    $valueTypeSpecified = $PSBoundParameters.ContainsKey('ValueType')
    $valueDataSpecified = $PSBoundParameters.ContainsKey('ValueData')
    $keyCreated = $false

    if ($ValueName -eq '' -and !$valueTypeSpecified -and !$valueDataSpecified)
    {
        $valueNameSpecified = $false
    }

    $registryResource = Get-TargetResource -Key $Key -ValueName ''

    $registryResourceInDesiredState = $false

    if ($registryResource.Ensure -eq 'Absent')
    {
        Write-Verbose -Message ($script:localizedData.RegistryKeyDoesNotExist -f $Key)

        if ($Ensure -eq 'Present')
        {
            $registryResource = New-RegistryKey -RegistryKeyPath $Key
        }
    }

    if ($registryResource.Ensure -eq 'Present')
    {
        Write-Verbose -Message ($script:localizedData.RegistryKeyExists -f $Key)

        if ($Ensure -eq 'Present')
        {
            if ($valueNameSpecified)
            {
                # Add the value if it does not exist
                $registryKey = Get-RegistryKey -RegistryKeyPath $Key
                $registryKeyValue = $registryKey.Data.GetValue($ValueName)

                # Throw error if registry key value is already set and Force not specified
                if ($null -ne $registryKeyValue -and -not $Force)
                {
                    New-InvalidOperationException -Message ($script:localizedData.CannotRemoveExistingRegistryKeyValueWithoutForce -f $Key, $ValueName)
                }

                # Set new registry key value
                
                # Create a strongly-typed object (in accordance with the specified $ValueType)
                $setVal = $null
                Get-TypedObject -Type $ValueType -Data $ValueData -Hex $Hex -ReturnValue ([ref] $setVal)

                # Finally set the $ValueName here
                $keyName = $keyInfo.Data.Name
                [Microsoft.Win32.Registry]::SetValue($keyName, $ValueName, $setVal, $ValueType)
            }
        }
        else
        {
            if ($valueNameSpecified)
            {
                # Throw error if registry key value exists and Force not specified

                # Remove the registry key value
                $null = Remove-ItemProperty -Path $Key -Name $ValueName -Force
            }
            else
            {
                # Throw error if registry key has subkeys and Force not specified

                # Remove the registry key
                $null = Remove-Item -Path $Key -Recurse -Force
            }
        }
    }

     Write-Verbose -Message ($script:localizedData.SetTargetResourceEndMessage -f $Key)
}

<#
    .SYNOPSIS
        Tests if the Registry resource with the given key is in the specified state.

    .PARAMETER Key
        The path of the registry key to test the state of.
        This path must include the registry hive.

    .PARAMETER ValueName
        The name of the registry value to check for.
        Specify this property as an empty string ('') to check the default value of the registry key.

    .PARAMETER Ensure
        Specifies whether or not the registry key and value should exist.
        
        To test that they exist, set this property to "Present".
        To test that they do not exist, set the property to "Absent".
        The default value is "Present".

    .PARAMETER ValueData
        The data the registry key value should have.

    .PARAMETER ValueType
        The type of the value.
        
        The supported types are:
            String (REG_SZ)
            Binary (REG-BINARY)
            Dword 32-bit (REG_DWORD)
            Qword 64-bit (REG_QWORD)
            Multi-string (REG_MULTI_SZ)
            Expandable string (REG_EXPAND_SZ)

    .PARAMETER Hex
        Not used in Test-TargetResource.

    .PARAMETER Force
        Not used in Test-TargetResource.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Key,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [ValidateNotNull()]
        [String]
        $ValueName,

        [ValidateSet('Present', 'Absent')]
        [String]
        $Ensure = 'Present',

        [ValidateNotNull()]
        [String[]]
        $ValueData = @(),

        [ValidateSet('String', 'Binary', 'DWord', 'QWord', 'MultiString', 'ExpandString')]
        [String]
        $ValueType = 'String',

        [Boolean]
        $Hex = $false,

        [Boolean]
        $Force = $false
    )

    Write-Verbose -Message ($script:localizedData.TestTargetResourceStartMessage -f $Key)

    $Key = Convert-PathRegistryRootToAbbreviation -RegistryKeyPath $Key
    Mount-RegistryDrive -RegistryKeyPath $Key

    $valueNameSpecified = $PSBoundParameters.ContainsKey('ValueName')
    $valueTypeSpecified = $PSBoundParameters.ContainsKey('ValueType')
    $valueDataSpecified = $PSBoundParameters.ContainsKey('ValueData')
    $keyCreated = $false

    if ($ValueName -eq '' -and !$valueTypeSpecified -and !$valueDataSpecified)
    {
        $valueNameSpecified = $false
    }

    $registryResource = Get-TargetResource -Key $Key -ValueName ''

    $registryResourceInDesiredState = $false

    if ($registryResource.Ensure -eq 'Absent')
    {
        Write-Verbose -Message ($script:localizedData.RegistryKeyDoesNotExist -f $Key)

        $registryResourceInDesiredState = $Ensure -eq 'Absent'
    }
    else
    {
        Write-Verbose -Message ($script:localizedData.RegistryKeyExists -f $Key)

        if (-not $valueNameSpecified -and -not $valueDataSpecified -and -not $valueTypeSpecified)
        {
            $registryResourceInDesiredState = $Ensure -eq 'Present'
        }
        else
        {
            $valueDisplayName = Get-ValueDisplayName -ValueName $ValueName

            # The ValueData and ValueType parameter values don't matter. All that matters is that they are not null.
            $registryResourceWithValue = Get-TargetResource -Key $Key -ValueName $ValueName -ValueData 'CheckValue' -ValueType 'String'

            if ($registryResourceWithValue.Ensure -eq 'Absent')
            {
                Write-Verbose -Message ($script:localizedData.RegistryKeyValueDoesNotExist -f $Key, $valueDisplayName)

                $registryResourceInDesiredState = $Ensure -eq 'Absent'
            }
            else
            {
                Write-Verbose -Message ($script:localizedData.RegistryKeyValueExists -f $Key, $valueDisplayName)

                if ($Ensure -eq 'Absent')
                {
                    $registryResourceInDesiredState = $false
                }
                elseif ($valueTypeSpecified -and $ValueType -ne $registryResourceWithValue.ValueType)
                {
                    Write-Verbose -Message ($script:localizedData.RegistryKeyValueTypeDoesNotMatch -f $Key, $valueDisplayName, $ValueType, $registryResourceWithValue.ValueType)

                    $registryResourceInDesiredState = $false
                }
                elseif ($valueDataSpecified -and -not (Test-ValueDataMatches -ExpectedValue $ValueData -ExpectedValueType $ValueType -ActualValue $registryResourceWithValue.ValueData))
                {
                    Write-Verbose -Message ($script:localizedData.RegistryKeyValueDoesNotMatch -f $Key, $valueDisplayName, $ValueData, $registryResourceWithValue.ValueData)

                    $registryResourceInDesiredState = $false
                }
                else
                {
                    $registryValueAsString = Convert-RegistryKeyValueToString -RegistryKeyValue $registryResourceWithValue.ValueData

                    Write-Verbose -Message ($script:localizedData.RegistryKeyValueExists -f $Key, $valueDisplayName, $registryResourceWithValue.ValueType, $registryValueAsString)
                     
                    $registryResourceInDesiredState = $true
                }
            }
        }
    }

    Write-Verbose -Message ($script:localizedData.TestTargetResourceEndMessage -f $Key)

    return $registryResourceInDesiredState
}

<#
    .SYNOPSIS
        Opens a registry sub key.
        This is a wrapper function for unit testing.

    .PARAMETER ParentKey
        The parent registry key which contains the sub key to open.

    .PARAMETER SubKey
        The sub key to open.

    .PARAMETER WriteAccessAllowed
        Specifies whether or not write access to open the sub key with write access.
#>
function Open-RegistrySubKey
{
    [OutputType([Microsoft.Win32.RegistryKey])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryKey]
        $ParentKey,

        [Parameter(Mandatory = $true)]
        [String]
        $SubKey,

        [Parameter()]
        [Switch]
        $WriteAccessAllowed
    )

    return $ParentKey.OpenSubKey($SubKey, $WriteAccessAllowed)
}

<#
    .SYNOPSIS
        Helper function to open a registry key

    .PARAMETER Path
        Indicates the path to the Registry key to be opened. This path must include the hive.

    .NOTES
        By the time we get here, the Invoke-RegistryProviderSetup function has already
        set up our path to start with a PSDrive,and validated that it exists, is a Registry drive,
        has a valid root.

        We're using this method instead of Get-Item so there is no ambiguity between
        forward slashes being treated as a path separator vs a literal character in a key name
        (which is legal in the registry.)

#>
function Get-RegistryKey
{
    [OutputType([Microsoft.Win32.RegistryKey])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $RegistryKeyPath
    )

    $registryRoot = Get-PathRoot -Path $RegistryKeyPath

    $registryKeyPathWithoutRoot = $RegistryKeyPath -replace $registryRoot
    
    $registryRootKey = Get-Item -LiteralPath $registryRoot

    $registryKey = Open-RegistrySubKey -ParentKey $registryRootKey -SubKey $registryKeyPathWithoutRoot -WriteAccessAllowed -ErrorAction 'SilentlyContinue'

    return $registryKey
}

<#
    .SYNOPSIS
        Creates a new subkey of the given registry key.

    .PARAMETER ParentRegistryKey
        The parent registry key to create the new sub key under.

    .PARAMETER SubKeyName
        The name of the new subkey to create.
#>
function New-RegistrySubKey
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryKey]
        $ParentRegistryKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $SubKeyName
    )

    $null = $ParentRegistryKey.CreateSubKey($SubKeyName)
}

<#
    .SYNOPSIS
        Creates a registry key at the given registry key path.

    .PARAMETER RegistryKeyPath
        The path at which to create the registry key.
        This path must include the registry hive.
#>
function New-RegistryKey
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $RegistryKeyPath
    )

    $parentRegistryKeyPath = Split-Path -Path $RegistryKeyPath -Parent
    $leafRegistryKeyPath = Split-Path -Path $RegistryKeyPath -Leaf

    if ($null -eq $parentRegistryKeyPath)
    {
        New-InvalidArgumentException -ArgumentName 'Key' -Message ($script:localizedData.RegistryRootInvalid -f $RegistryKeyPath)
    }

    $parentRegistryResource = Get-TargetResource -Key $parentRegistryKeyPath -ValueName ''

    # Check if the parent registry key path exists. If not, create it (recurse).
    if ($parentRegistryResource.Ensure -eq 'Absent')
    {
        $null = New-RegistryKey -RegistryKeyPath $parentRegistryKeyPath
    }

    $parentRegistryKey = Get-RegistryKey -RegistryKeyPath $parentRegistryKeyPath

    New-RegistrySubKey -ParentRegistryKey $parentRegistryKey -SubKeyName $leafRegistryKeyPath

    $newRegistryResource = Get-TargetResourceInternal -Key $RegistryKeyPath -ValueName ''

    return $newRegistryResource
}

<#
    .SYNOPSIS
        Tests if the given registry root is valid.

    .PARAMETER RegistryRoot
        The registry root to be tested.
#>
function Test-IsValidRegistryRoot
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $RegistryRoot
    )

    # Extract the base of the PSDrive root
    if ($RegistryRoot.Contains('\'))
    {
        $RegistryRoot = $RegistryRoot.Substring(0, $RegistryRoot.IndexOf('\'))
    }

    return ($script:registryRootAbbreviations.Keys -icontains $RegistryRoot)
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
    [CmdletBinding()]
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

function ConvertTo-StandardString
{
    [OutputType([String])]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [AllowNull()]
        [String[]]
        [AllowEmptyCollection()]
        $RegistryKeyValue
    )

    if (($null -ne $RegistryKeyValue) -and ($RegistryKeyValue.Count -gt 1))
    {
        New-InvalidArgumentException -ArgumentName 'ValueData' -Message ($script:localizedData.ArrayNotAllowedForExpectedType -f $RegistryKeyValue, 'String')
    }

    if (($null -eq $Data) -or ($Data.Length -eq 0))
    {
        $ReturnValue.Value = [System.String]::Empty

        return
    }

    $ReturnValue.Value = [System.String] $Data[0]
}

function ConvertTo-ExpandString
{
    [OutputType([String])]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [AllowNull()]
        [String[]]
        [AllowEmptyCollection()]
        $RegistryKeyValue
    )

    if (($null -ne $RegistryKeyValue) -and ($RegistryKeyValue.Count -gt 1))
    {
        New-InvalidArgumentException -ArgumentName 'ValueData' -Message ($script:localizedData.ArrayNotAllowedForExpectedType -f $RegistryKeyValue, 'ExpandString')
    }

    $expandString

    if (($null -eq $Data) -or ($Data.Length -eq 0))
    {
        $ReturnValue.Value = [String]::Empty

        return
    }

    $ReturnValue.Value = [String] $Data[0]
}

function ConvertTo-MultiString
{
    [OutputType([String[]])]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [AllowNull()]
        [String[]]
        [AllowEmptyCollection()]
        $RegistryKeyValue
    )

    $multiStringRegistryKeyValue = [String[]] @()

    if (($null -ne $RegistryKeyValue) -and ($RegistryKeyValue.Length -gt 0))
    {
        $multiStringRegistryKeyValue = [String[]] $Data
    }

    return $multiStringRegistryKeyValue
}

function ConvertTo-Dword
{
    [OutputType([System.Int32])]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [AllowNull()]
        [String[]]
        [AllowEmptyCollection()]
        $RegistryKeyValue,

        [Parameter()]
        [Boolean]
        $Hex = $false
    )

    if (($null -ne $RegistryKeyValue) -and ($RegistryKeyValue.Count -gt 1))
    {
        New-InvalidArgumentException -ArgumentName 'ValueData' -Message ($script:localizedData.ArrayNotAllowedForExpectedType -f $RegistryKeyValue, 'Dword')
    }

    $dwordRegistryKeyValue = [System.Int32] 0

    if ($RegistryKeyValue.Count -eq 1)
    {
        $singleRegistryKeyValue = $RegistryKeyValue[0]

        if ($Hex)
        {
            $singleRegistryKeyValue = $singleRegistryKeyValue[0].TrimStart('0x')

            $currentCultureInfo = [System.Globalization.CultureInfo]::CurrentCulture
            $referenceValue = $null

            if ([System.Int32]::TryParse($singleRegistryKeyValue, 'HexNumber', $currentCultureInfo, [Ref] $referenceValue))
            {
                $dwordRegistryKeyValue = $referenceValue
            }
            else
            {
                New-InvalidArgumentException -ArgumentName 'ValueData' -Message ($script:localizedData.DwordDataNotInHexFormat -f $singleRegistryKeyValue)
            }
        }
        else
        {
            $dwordRegistryKeyValue = [System.Int32]::Parse($singleRegistryKeyValue)
        }
    }

    return $dwordRegistryKeyValue
}

function ConvertTo-Qword
{
    [OutputType([System.Int64])]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [AllowNull()]
        [String[]]
        [AllowEmptyCollection()]
        $RegistryKeyValue,

        [Parameter()]
        [Boolean]
        $Hex = $false
    )

    if (($null -ne $RegistryKeyValue) -and ($RegistryKeyValue.Count -gt 1))
    {
        New-InvalidArgumentException -ArgumentName 'ValueData' -Message ($script:localizedData.ArrayNotAllowedForExpectedType -f $RegistryKeyValue, 'Qword')
    }

    $qwordRegistryKeyValue = [System.Int64] 0

    if ($RegistryKeyValue.Count -eq 1)
    {
        $singleRegistryKeyValue = $RegistryKeyValue[0]

        if ($Hex)
        {
            $singleRegistryKeyValue = $singleRegistryKeyValue[0].TrimStart('0x')

            $currentCultureInfo = [System.Globalization.CultureInfo]::CurrentCulture
            $referenceValue = $null

            if ([System.Int64]::TryParse($singleRegistryKeyValue, 'HexNumber', $currentCultureInfo, [Ref] $referenceValue))
            {
                $qwordRegistryKeyValue = $referenceValue
            }
            else
            {
                New-InvalidArgumentException -ArgumentName 'ValueData' -Message ($script:localizedData.QwordDataNotInHexFormat -f $singleRegistryKeyValue)
            }
        }
        else
        {
            $qwordRegistryKeyValue = [System.Int64]::Parse($singleRegistryKeyValue)
        }
    }

    return $qwordRegistryKeyValue
}

function ConvertTo-Binary
{
    [OutputType([System.Byte[]])]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [AllowNull()]
        [String[]]
        [AllowEmptyCollection()]
        $RegistryKeyValue
    )

    if (($null -ne $RegistryKeyValue) -and ($RegistryKeyValue.Count -gt 1))
    {
        New-InvalidArgumentException -ArgumentName 'ValueData' -Message ($script:localizedData.ArrayNotAllowedForExpectedType -f $RegistryKeyValue, 'Binary')
    }

    $binaryRegistryKeyValue = [System.Byte[]] @()

    if ($RegistryKeyValue.Count -eq 1)
    {
        $singleRegistryKeyValue = $RegistryKeyValue[0].TrimStart('0x')

        if (($singleRegistryKeyValue.Length % 2) -ne 0)
        {
            $singleRegistryKeyValue = $singleRegistryKeyValue.PadLeft($singleRegistryKeyValue.Length + 1, '0')
        }

        try
        {
            for ($singleRegistryKeyValueIndex = 0 ; $singleRegistryKeyValueIndex -lt ($singleRegistryKeyValue.Length - 1) ; $singleRegistryKeyValueIndex = $singleRegistryKeyValueIndex + 2)
            {
                $binaryRegistryKeyValue += [System.Byte]::Parse($singleRegistryKeyValue.Substring($singleRegistryKeyValueIndex, 2), 'HexNumber')
            }
        }
        catch [System.Exception]
        {
            New-InvalidArgumentException -ArgumentName 'ValueData' -Message ($script:localizedData.BinaryDataNotInHexFormat -f $singleRegistryKeyValue)
        }
    }

    return $binaryRegistryKeyValue
}

<#
    .SYNOPSIS
        Converts a registry key value to its string representation.

    .PARAMETER RegistryKeyValue
        The registry key value to be converted.
#>
function Convert-RegistryKeyValueToString
{
    [OutputType([String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Object[]]
        $RegistryKeyValue
    )

    if ($RegistryKeyValue.Count -eq 1)
    {
        $registryKeyValueAsString = $RegistryKeyValue[0].ToString()
    }
    elseif ($RegistryKeyValue.Count -gt 1)
    {
        $registryKeyValueAsString = "($($RegistryKeyValue -join ', '))"
    }
    else
    {
        $registryKeyValueAsString = $RegistryKeyValue.ToString()
    }

    return $registryKeyValueAsString
}

<#
    .SYNOPSIS
        Converts a byte array to its hex string representation.

    .PARAMETER ByteArray
        The byte array to convert.
#>
function Convert-ByteArrayToHexString
{
    [OutputType([String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Object[]]
        $ByteArray
    )

    $hexString = ''

    foreach ($byte in $ByteArray)
    {
        $hexString += ('{0:x2}' -f $_)
    }

    return $hexString
}

<#
    .SYNOPSIS
        Retrieves the display name of the (Default) registry value if needed.

    .PARAMETER ValueName
        The name of the value to be retrieved.
#>
function Get-ValueDisplayName
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [String]
        $ValueName
    )

    $valueDisplayName = $ValueName

    if ([String]::IsNullOrEmpty($ValueName))
    {
        $valueDisplayName = $script:localizedData.DefaultValueDisplayName
    }

    return $valueDisplayName
}

function Get-PathRoot {
    [OutputType([String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path
    )

    $pathParent = Split-Path -Path $Path -Parent

    while ($null -ne $pathParent)
    {
        $pathParent = Split-Path -Path $Path -Parent
    }

    $pathRoot = Split-Path -Path $Path -Leaf

    return $pathRoot
}

function ConvertTo-RegistryRootAbbreviation
{
    [OutputType([String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $RegistryRootName
    )

    $registryRootAbbreviation = $null

    if ($script:registryRootAbbreviations.ContainsKey($RegistryRootName))
    {
        $registryRootAbbreviation = $script:registryRootAbbreviations[$RegistryRootName]
    }

    return $registryRootAbbreviation
}

function ConvertTo-RegistryRootName
{
    [OutputType([String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $RegistryRootAbbreviation
    )

    $registryRootName = $null

    if ($script:registryRootAbbreviations.ContainsValue($RegistryRootAbbreviation))
    {
        foreach ($registryRootAbbreviationKey in $script:registryRootAbbreviations.Keys)
        {
            if ($script:registryRootAbbreviations[$registryRootAbbreviationKey] -ieq $RegistryRootAbbreviation)
            {
                $registryRootName = $registryRootAbbreviationKey
                break
            }
        }
    }

    return $registryRootName
}

<#
    .SYNOPSIS
        Mounts the registry drive for the given registry key path.

    .PARAMETER RegistryKeyName
        The registry key containing the registry drive to mount.
#>
function Mount-RegistryDrive
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $RegistryKeyPath
    )

    $registryRoot = Split-Path -Path $RegistryKeyPath -Qualifier
    $registryDriveAbbreviation = $registryRoot.TrimEnd(':').ToUpperInvariant()

    $registryDrive = Get-PSDrive -Name $registryDriveAbbreviation -ErrorAction 'SilentlyContinue'

    if ($null -eq $registryDrive)
    {
        $newPSDriveParameters = @{
            Name = $registryDriveAbbreviation
            Root = ConvertTo-RegistryRootName -RegistryRootAbbreviation $registryDriveAbbreviation
            PSProvider = 'Registry'
            Scope = 'Script'
        }

        $registryDrive = New-PSDrive @newPSDriveParameters
    }

    # Validate that the specified PSDrive is valid
    if (($null -eq $registryDrive) -or ($null -eq $registryDrive.Provider) -or ($registryDrive.Provider.Name -ine 'Registry') -or -not (Test-IsValidRegistryRoot -RegistryRoot $registryDrive.Root))
    {
        New-InvalidArgumentException -ArgumentName 'Key' -Message ($script:localizedData.InvalidRegistryKeyPathSpecified -f $registryDriveAbbreviation, $Key)
    }
}

<#
    .SYNOPSIS
        Converts the registry root in the given registry key path to its abbreviated form.

    .PARAMETER RegistryKeyPath
        The registry key path that contains the registry root to convert.
#>
function Convert-PathRegistryRootToAbbreviation
{
    [OutputType([String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $RegistryKeyPath
    )

    $registryKeyPathWithAbbreviation = $RegistryKeyPath

    $registryRootAbbreviations = @{
        'HKEY_CLASSES_ROOT' = 'HKCR:'
        'HKEY_USERS' = 'HKUS:'
        'HKEY_CURRENT_CONFIG' = 'HKCC:'
        'HKEY_CURRENT_USER' = 'HKCU:'
        'HKEY_LOCAL_MACHINE' = 'HKLM:' 
    }

    $registryRoot = Get-PathRoot -Path $RegistryKeyPath

    # If the registry root contains a colon, it should already be in its abbreviated form
    if (-not $registryRoot.Contains(':'))
    {
        if ($registryRootAbbreviations.ContainsKey($registryRoot))
        {
            $registryKeyPathWithAbbreviation = $RegistryKeyPath -replace $registryRoot, $registryRootAbbreviations[$registryRoot]:
        }
        else
        {
            New-InvalidArgumentException -ArgumentName 'Key' -Message ($script:localizedData.InvalidRegistryRoot -f $registryRoot)
        }
    }

    return $registryKeyPathWithAbbreviation
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
