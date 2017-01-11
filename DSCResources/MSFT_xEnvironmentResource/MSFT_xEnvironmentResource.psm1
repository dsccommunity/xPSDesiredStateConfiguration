$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

Import-Module -Name (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) `
                               -ChildPath 'CommonResourceHelper.psm1')
$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_xEnvironmentResource'

$script:envVarRegPathMachine = 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment'
$script:envVarRegPathUser = 'HKCU:\Environment'

$script:environmentVariableTarget = @{ 
    Process = 0
    User = 1
    Machine = 2 
}

$script:maxSystemEnvVariableLength = 1024
$script:maxUserEnvVariableLength = 255

<#
    .SYNOPSIS
        Retrieves the state of the environment variable.

    .PARAMETER Name
        The name of the environment variable to retrieve.
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
        $Name       
    )
        
    $envVar = Get-ItemPropertyExpanded -Name $Name -ErrorAction 'SilentlyContinue'
    
    $environmentResource = @{
      Ensure = 'Absent'
      Name = $Name
      Value = $envVar
    }
    
    if ($null -eq $envVar)
    {        
        Write-Verbose -Message ($script:localizedData.EnvVarNotFound -f $Name)
    }    
    else
    {
        Write-Verbose -Message ($script:localizedData.EnvVarFound -f $Name, $envVar)
        $environmentResource.Ensure = 'Present'
    }

    return $environmentResource
}

<#
    .SYNOPSIS
        
    .PARAMETER Name

    .PARAMETER Value

    .PARAMETER Ensure

    .PARAMETER Path

    .PARAMETER Target    
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (       
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,
        
        [ValidateNotNull()]
        [String]
        $Value = [String]::Empty,
        
        [ValidateSet('Present', 'Absent')]
        [String]
        $Ensure = 'Present',
        
        [Boolean]
        $Path = $false,

        [ValidateSet('Process', 'Machine')]
        [String[]]
        $Target = ('Process', 'Machine')
    )
    
    $valueSpecified = $PSBoundParameters.ContainsKey('Value')
    $currentValueFromMachine = $null
    $currentValueFromProcess = $null

    $checkMachineTarget = ($Target -contains 'Machine')
    $checkProcessTarget = ($Target -contains 'Process')

    if ($checkMachineTarget)
    {
        if ($Path)
        {
            $currentValueFromMachine = Get-EnvironmentVariable -Name $Name -Target $script:environmentVariableTarget.Machine
        } 
        else
        {
            $currentValueFromMachine = Get-ItemPropertyExpanded -Name $Name -ErrorAction 'SilentlyContinue'
        }
    }

    if ($checkProcessTarget)
    {
        $currentValueFromProcess = Get-EnvironmentVariable -Name $Name -Target $script:environmentVariableTarget.Process
    }

    # A different value of the environment variable needs to be displayed depending on the Target
    $currentValueToDisplay = ''
    if ($checkMachineTarget -and $checkProcessTarget)
    {
        $currentValueToDisplay = "Machine: $currentValueFromMachine, Process: $currentValueFromProcess"
    }
    elseif ($checkMachineTarget)
    {
        $currentValueToDisplay = $currentValueFromMachine
    }
    else
    {
        $currentValueToDisplay = $currentValueFromProcess
    }

    if ($Ensure -eq 'Present')
    {
        $setMachineVariable = ((-not $checkMachineTarget) -or ($null -eq $currentValueFromMachine) -or ($currentValueFromMachine -eq [String]::Empty))
        $setProcessVariable = ((-not $checkProcessTarget) -or ($null -eq $currentValueFromProcess) -or ($currentValueFromProcess -eq [String]::Empty))

        if ($setMachineVariable -and $setProcessVariable)
        {
            <#
                Given the specified $Name environment variable hasn't been created or set
                simply create one with the specified value and return. If $Value is not 
                specified the variable will be set to an empty string '' (per spec).
                Both path and non-path cases are covered by this.
            #>

            Set-EnvironmentVariable -Name $Name -Value $Value -Target $Target
            
            Write-Verbose -Message ($script:localizedData.EnvVarCreated -f $Name, $Value)
            return
        }

        if (-not $valueSpecified)
        {
            <#
                Given no $Value was specified to be set and the variable exists, 
                we'll leave the existing variable as is.
                This covers both path and non-path variables.
            #>

            Write-Verbose -Message ($script:localizedData.EnvVarUnchanged -f $Name, $currentValueToDisplay)
            return
        }

        # Check if an empty, whitespace or semi-colon only string has been specified. If yes, return unchanged.
        $trimmedValue = $Value.Trim(';',' ')

        if ([String]::IsNullOrEmpty($trimmedValue))
        {
            Write-Verbose -Message ($script:localizedData.EnvVarPathUnchanged -f $Name, $currentValueToDisplay)
            return        
        }

        if (-not $Path)
        {
            # For non-path variables, simply set the specified $Value as the new value of the specified 
            # variable $Name for the given $Target

            if (($checkMachineTarget -and ($Value -cne $currentValueFromMachine)) -or `
                ($checkProcessTarget -and ($Value -cne $currentValueFromProcess)))
            {
                Set-EnvironmentVariable -Name $Name -Value $Value -Target $Target
                Write-Verbose -Message ($script:localizedData.EnvVarUpdated -f $Name, $currentValueToDisplay, $Value)
            }
            else
            {
                Write-Verbose -Message ($script:localizedData.EnvVarUnchanged -f $Name, $currentValueToDisplay)
            }

            return
        }

        # If the control reaches here, the specified variable exists, it is a path variable, and a $Value has been specified to be set.

        if ($checkMachineTarget)
        {
            <#
                If this function returns $null, than all of the paths specified to be added are
                already listed in the current value so it does not need to be updated, otherwise
                this function will return the updated value of the variable after any new paths
                have been added.
            #>
            $updatedValue = Get-PathValueWithAddedPaths -CurrentValue $currentValueFromMachine -NewValue $trimmedValue

            if ($updatedValue)
            {
                Set-EnvironmentVariable -Name $Name -Value $updatedValue -Target @('Machine')
                Write-Verbose -Message ($script:localizedData.EnvVarPathUpdated -f $Name, $currentValueFromMachine, $updatedValue)
            }
            else
            {
                Write-Verbose -Message ($script:localizedData.EnvVarPathUnchanged -f $Name, $currentValueFromMachine)
            }
        }

        if ($checkProcessTarget)
        {
            <#
                If this function returns $null, than all of the paths specified to be added are
                already listed in the current value so it does not need to be updated, otherwise
                this function will return the updated value of the variable after any new paths
                have been added.
            #>
            $updatedValue = Get-PathValueWithAddedPaths -CurrentValue $currentValueFromProcess -NewValue $trimmedValue

            if ($updatedValue)
            {
                Set-EnvironmentVariable -Name $Name -Value $updatedValue -Target @('Process')
                Write-Verbose -Message ($script:localizedData.EnvVarPathUpdated -f $Name, $currentValueFromProcess, $updatedValue)
            }
            else
            {
                Write-Verbose -Message ($script:localizedData.EnvVarPathUnchanged -f $Name, $currentValueFromProcess)
            }
        }
    }

    # Ensure = 'Absent'
    else
    {
        $machineVariableRemoved = ((-not $checkMachineTarget) -or ($null -eq $currentValueFromMachine))
        $processVariableRemoved = ((-not $checkProcessTarget) -or ($null -eq $currentValueFromProcess))

        if ($machineVariableRemoved -and $processVariableRemoved)
        {
            # Variable not found, condition is satisfied and there is nothing to set/remove, return
            Write-Verbose -Message ($script:localizedData.EnvVarNotFound -f $Name)        
            return
        }
        
        if ((-not $ValueSpecified) -or (-not $Path))
        {
            <#
                If $Value is not specified or if $Value is a non-path variable,
                simply remove the environment variable.
            #>

            Remove-EnvironmentVariable -Name $Name -Target $Target

            Write-Verbose -Message ($script:localizedData.EnvVarRemoved -f $Name)
            return
        }

        # Check if an empty string or semi-colon only string has been specified as $Value. If yes, return unchanged as we don't need to remove anything.
        $trimmedValue = $Value.Trim(';')

        if ([String]::IsNullOrEmpty($trimmedValue))
        {
            Write-Verbose -Message ($script:localizedData.EnvVarPathUnchanged -f $Name, $currentValueToDisplay)
            return
        }

        # If the control reaches here: target variable is an existing environment path-variable and a specified $Value needs be removed from it

        if ($checkMachineTarget)
        {
            <#
                If this value returns $null or an empty string, than the entire path should be removed.
                If it returns the same value as the path that was passed in, than nothing needs to be
                updated, otherwise, only the specified paths were removed but there are still others
                that need to be left in, so the path variable is updated to remove only the specified paths.
            #>
            $finalPath = Get-PathValueWithRemovedPaths -CurrentValue $currentValueFromMachine -PathsToRemove $trimmedValue

            if ([String]::IsNullOrEmpty($finalPath))
            {
                Remove-EnvironmentVariable -Name $Name -Target @('Machine')
                Write-Verbose -Message ($script:localizedData.EnvVarRemoved -f $Name)
            }
            elseif ($finalPath -ceq $currentValueFromMachine)
            {
                Write-Verbose -Message ($script:localizedData.EnvVarPathUnchanged -f $Name, $currentValueFromMachine)
            }
            else
            {
                Set-EnvironmentVariable -Name $Name -Value $finalPath -Target @('Machine')
                Write-Verbose -Message ($script:localizedData.EnvVarPathUpdated -f $Name, $currentValueFromMachine, $finalPath)
            }       
        }

        if ($checkProcessTarget)
        {
            <#
                If this value returns $null or an empty string, than the entire path should be removed.
                If it returns the same value as the path that was passed in, than nothing needs to be
                updated, otherwise, only the specified paths were removed but there are still others
                that need to be left in, so the path variable is updated to remove only the specified paths.
            #>
            $finalPath = Get-PathValueWithRemovedPaths -CurrentValue $currentValueFromProcess -PathsToRemove $trimmedValue

            if ([String]::IsNullOrEmpty($finalPath))
            {
                Remove-EnvironmentVariable -Name $Name -Target @('Process')
                Write-Verbose -Message ($script:localizedData.EnvVarRemoved -f $Name)
            }
            elseif ($finalPath -ceq $currentValueFromProcess)
            {
                Write-Verbose -Message ($script:localizedData.EnvVarPathUnchanged -f $Name, $currentValueFromProcess)
            }
            else
            {
                Set-EnvironmentVariable -Name $Name -Value $finalPath -Target @('Process')
                Write-Verbose -Message ($script:localizedData.EnvVarPathUpdated -f $Name, $currentValueFromProcess, $finalPath)
            }       
        }
    }
}

<#
    .SYNOPSIS
        
    .PARAMETER Name

    .PARAMETER Value

    .PARAMETER Ensure

    .PARAMETER Path
    
    .PARAMETER Target   
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
        $Name,
        
        [ValidateNotNull()]
        [String]
        $Value,

        [ValidateSet('Present', 'Absent')]
        [String]
        $Ensure = 'Present',
        
        [Boolean]
        $Path = $false,

        [ValidateSet('Process', 'Machine')]
        [String[]]
        $Target = ('Process', 'Machine')
    )
    
    $valueSpecified = $PSBoundParameters.ContainsKey('Value')
    $currentValueFromMachine = $null
    $currentValueFromProcess = $null

    $checkMachineTarget = ($Target -contains 'Machine')
    $checkProcessTarget = ($Target -contains 'Process')

    if ($checkMachineTarget)
    {
        if ($Path)
        {
            $currentValueFromMachine = Get-EnvironmentVariable -Name $Name -Target $script:environmentVariableTarget.Machine
        } 
        else
        {
            $currentValueFromMachine = Get-ItemPropertyExpanded -Name $Name -ErrorAction 'SilentlyContinue'
        }
    }

    if ($checkProcessTarget)
    {
        $currentValueFromProcess = Get-EnvironmentVariable -Name $Name -Target $script:environmentVariableTarget.Process
    }

    # A different value of the environment variable needs to be displayed depending on the Target
    $currentValueToDisplay = ''
    if ($checkMachineTarget -and $checkProcessTarget)
    {
        $currentValueToDisplay = "Machine: $currentValueFromMachine, Process: $currentValueFromProcess"
    }
    elseif ($checkMachineTarget)
    {
        $currentValueToDisplay = $currentValueFromMachine
    }
    else
    {
        $currentValueToDisplay = $currentValueFromProcess
    }

    if ($Ensure -eq 'Present')
    {        
        if (($checkMachineTarget -and ($null -eq $currentValueFromMachine)) -or ($checkProcessTarget -and ($null -eq $currentValueFromProcess)))
        {
            # Variable not found, return failure
            Write-Verbose ($script:localizedData.EnvVarNotFound -f $Name)
            return $false
        }

        if (-not $valueSpecified)
        {
            # No value has been specified for test, so the existence of the variable means success
            Write-Verbose ($script:localizedData.EnvVarFound -f $Name, $currentValueToDisplay)
            return $true
        }
        
        if (-not $Path)
        {
            # For this non-path variable, make sure that the specified $Value matches the current value.
            # Success if it matches, failure otherwise

            if (($checkMachineTarget -and ($Value -cne $currentValueFromMachine)) -or `
               ($checkProcessTarget -and ($Value -cne $currentValueFromProcess)))
            {
                Write-Verbose ($script:localizedData.EnvVarFoundWithMisMatchingValue -f $Name, $currentValueToDisplay, $Value)
                return $false                
            }
            else
            {
                Write-Verbose ($script:localizedData.EnvVarFound -f $Name, $currentValueToDisplay)
                return $true
            }
        }             
                       
        # If the control reaches here, the expected environment variable exists, it is a path variable and a $Value is specified to test against
        if ($checkMachineTarget)
        {        
            if (-not (Test-PathInPathListWithCriteria -ExistingPaths $currentValueFromMachine -QueryPaths $Value -FindCriteria 'All'))
            {
                # If the control reached here some part of the specified path ($Value) was not found in the existing variable, return failure       
                Write-Verbose ($script:localizedData.EnvVarFoundWithMisMatchingValue -f $Name, $currentValueToDisplay, $Value)
                return $false
            }
        }

        if ($checkProcessTarget)
        {
            if (-not (Test-PathInPathListWithCriteria -ExistingPaths $currentValueFromProcess -QueryPaths $Value -FindCriteria 'All'))
            {
                # If the control reached here some part of the specified path ($Value) was not found in the existing variable, return failure       
                Write-Verbose ($script:localizedData.EnvVarFoundWithMisMatchingValue -f $Name, $currentValueToDisplay, $Value)
                return $false
            }
        }

        # The specified path was completely present in the existing environment variable, return success
        Write-Verbose ($script:localizedData.EnvVarFound -f $Name, $currentValueToDisplay)
        return $true
    }

    # Ensure = 'Absent'
    else
    {
        if (((-not $checkMachineTarget) -or ($null -eq $currentValueFromMachine)) -and `
            ((-not $checkProcessTarget) -or ($null -eq $currentValueFromProcess)))
        {
            # Variable not found (path/non-path and $Value both do not matter then), return success
            return $true
        }

        if (-not $valueSpecified)
        {
            # Given no value has been specified for test, the mere existence of the variable fails the test
            Write-Verbose ($script:localizedData.EnvVarFound -f $Name, $currentValueToDisplay)
            return $false
        }

        # If the control reaches here: the variable exists and a value has been specified
                
        if (-not $Path)
        {            
            # For this non-path variable, make sure that the specified value doesn't match the current value
            # Success if it doesn't match, failure otherwise
            
            if (((-not $checkMachineTarget) -or ($Value -cne $currentValueFromMachine)) -and `
               ((-not $checkProcessTarget) -or ($Value -cne $currentValueFromProcess)))
            {
                Write-Verbose ($script:localizedData.EnvVarFoundWithMisMatchingValue -f $Name, $currentValueToDisplay, $Value)                
                return $true                
            }
            else
            {
                Write-Verbose ($script:localizedData.EnvVarFound -f $Name, $currentValueToDisplay)
                return $false
            }
        }
                    
        # If the control reaches here: the variable exists, it is a path variable, and a value has been specified to test against it                               
        if ($checkMachineTarget)
        {
            if (Test-PathInPathListWithCriteria -ExistingPaths $currentValueFromMachine -QueryPaths $Value -FindCriteria 'Any')
            {
                # One of the specified paths in $Value exists in the environment variable path, thus the test fails
                Write-Verbose ($script:localizedData.EnvVarFound -f $Name, $currentValueFromMachine)
                return $false
            }
        }

        if ($checkProcessTarget)
        {
            if (Test-PathInPathListWithCriteria -ExistingPaths $currentValueFromProcess -QueryPaths $Value -FindCriteria 'Any')
            {
                # One of the specified paths in $Value exists in the environment variable path, thus the test fails
                Write-Verbose ($script:localizedData.EnvVarFound -f $Name, $currentValueFromProcess)
                return $false
            }
        }
                    
        # If the control reached here, none of the specified paths were found in the existing path-variable, return success
        Write-Verbose ($script:localizedData.EnvVarFoundWithMisMatchingValue -f $Name, $currentValueToDisplay, $Value)
        return $true
    }    
}

<#
    .SYNOPSIS
        
    .PARAMETER Name

    .PARAMETER Target       
#>
function Get-EnvironmentVariable
{
    [CmdletBinding()]
    [OutputType([String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [Parameter(Mandatory = $true)]
        [Int]
        $Target
    )

    $valueToReturn = $null

    if ($Target -eq $script:environmentVariableTarget.Process) 
    {
        $valueToReturn = Get-ProcessEnvironmentVariable -Name $Name
    }
    elseif ($Target -eq $script:environmentVariableTarget.Machine)
    {
        $retrievedProperty = Get-ItemProperty -Path $script:envVarRegPathMachine -Name $Name -ErrorAction 'SilentlyContinue'

        if ($null -ne $retrievedProperty)
        {
            $valueToReturn = $retrievedProperty.$Name
        }
    }
    elseif ($Target -eq $script:environmentVariableTarget.User)
    {
        $retrievedProperty = Get-ItemProperty -Path $script:envVarRegPathUser -Name $Name -ErrorAction 'SilentlyContinue'

        if ($null -ne $retrievedProperty)
        {
            $valueToReturn = $retrievedProperty.$Name
        }
    }
    else
    {
        New-InvalidArgumentException -Message $script:localizedData.InvalidTarget -ArgumentName $Target
    }

    return $valueToReturn
}

<#
    .SYNOPSIS
        Wrapper function to retrieve an environment variable from the current process.
        
    .PARAMETER Name
        The name of the variable to retrieve
      
#>
function Get-ProcessEnvironmentVariable
{
    [CmdletBinding()]
    [OutputType([String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name
    )

    return [System.Environment]::GetEnvironmentVariable($Name)
}

<#
    .SYNOPSIS
        If there are any paths in NewPaths that aren't in CurrentValue it will add the new
        paths to the current paths and return the new value with all new paths added in.
        Otherwise, it will return $null.
        
    .PARAMETER CurrentValue

    .PARAMETER NewPaths      
#>
function Get-PathValueWithAddedPaths
{
    [CmdletBinding()]
    [OutputType([String])]
    param
    (       
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $CurrentValue,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $NewValue
    )

    $finalValue = $CurrentValue + ';'
    $currentPaths = $CurrentValue -split ';'
    $newPaths = $NewValue -split ';'
    $varUpdated = $false

    foreach ($path in $newPaths)            
    {            
        if (-not (Test-PathInPathList -QueryPath $path -PathList $currentPaths))
        {
            # If the control reached here, we didn't find this $specifiedPath in the $currentPaths, add it
            # and mark the environment variable as updated.

            $varUpdated = $true
            $finalValue += ($path + ';')
        }                            
    }  
       
    if ($varUpdated)
    {
        # Remove any extraneous ';' at the end (and potentially start - as a side-effect) of the value to be set
        return $finalValue.Trim(';')
    }
    else
    {
        return $null
    }
}

<#
    .SYNOPSIS
        If there are any paths in PathsToRemove that aren't in CurrentValue it will remove the
        specified paths and return either the new value if there are still paths that remain or
        an empty string if all paths were removed. If none of the paths in PathsToRemove are in
        CurrentValue than this function will return CurrentValue since nothing needs to be changed.
        
    .PARAMETER CurrentValue

    .PARAMETER PathsToRemove      
#>
function Get-PathValueWithRemovedPaths
{
    [OutputType([String])]
    [CmdletBinding()]
    param
    (       
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $CurrentValue,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PathsToRemove
    )

    $finalPath = ''
    $specifiedPaths = $PathsToRemove -split ';'
    $currentPaths = $CurrentValue -split ';'
    $varAltered = $false

    foreach ($subpath in $currentPaths)
    {
        if (Test-PathInPathList -QueryPath $subpath -PathList $specifiedPaths)
        {
            <#
                Found this $subpath as one of the $specifiedPaths, skip adding this to the final
                value/path of this variable and mark the variable as altered.
            #>
            $varAltered = $true
        }
        else
        {
            # the current $subpath was not part of the $specifiedPaths (to be removed) so keep this $subpath in the finalPath
            $finalPath += $subpath + ';'
        }                            
    }                          
    
    # Remove any extraneous ';' at the end (and potentially start - as a side-effect) of the $finalPath        
    $finalPath = $finalPath.Trim(';')                
        
    if ($varAltered)
    {
        return $finalPath
    }
    else
    {
        return $CurrentValue
    }
}

<#
    .SYNOPSIS
        
    .PARAMETER Name

    .PARAMETER Value
    
    .PARAMETER Target       
#>
function Set-EnvironmentVariable
{
    [CmdletBinding()]
    param
    (       
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [String]
        $Value = [String]::Empty,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Process', 'Machine')]
        [String[]]
        $Target
    )

    try
    {
        if ($Target -contains 'Process')
        {
            Set-ProcessEnvironmentVariable -Name $Name -Value $Value
        }

        if ($Target -contains 'Machine')
        {
            if ($Name.Length -ge $script:maxSystemEnvVariableLength)
            {
                New-InvalidArgumentException -Message $script:localizedData.ArgumentTooLong -ArgumentName $Name
            }

            $path = $script:envVarRegPathMachine
        
            $environmentKey = Get-ItemProperty -Path $path -Name $Name -ErrorAction 'SilentlyContinue'

            if ($environmentKey) 
            {
                if ($null -ne $Value -and $Value -ne [String]::Empty) 
                {
                    Set-ItemProperty -Path $path -Name $Name -Value $Value 
                }
                else 
                {
                    Remove-ItemProperty $path -Name $Name
                }
            }
            else
            {
                $message = ($script:localizedData.GetItemPropertyFailure -f $Name, $path)
                New-InvalidArgumentException -Message $message -ArgumentName $Name
            }
        }

        # The User feature of this resource is not yet implemented.
        if ($Target -contains 'User')
        {
            if ($Name.Length -ge $script:maxUserEnvVariableLength)
            {
                New-InvalidArgumentException -Message $script:localizedData.ArgumentTooLong -ArgumentName $Name
            }

            $path = $script:envVarRegPathUser

            $environmentKey = Get-ItemProperty -Path $path -Name $Name -ErrorAction 'SilentlyContinue'

            if ($environmentKey) 
            {
                if ($PSBoundParameters.ContainsKey('Value')) 
                {
                    Set-ItemProperty -Path $path -Name $Name -Value $Value
                }
                else 
                {
                    Remove-ItemProperty $path -Name $Name
                }
            }
            else
            {
                $message = ($script:localizedData.GetItemPropertyFailure -f $Name, $path)
                New-InvalidArgumentException -Message $message -ArgumentName $Name
            }
        }
    }
    catch 
    {
        Write-Verbose ($script:localizedData.EnvVarSetError -f $Name, $Value)
        throw $_
    }

}

<#
    .SYNOPSIS
        Wrapper function to set an environment variable for the current process.
        
    .PARAMETER Name
        The name of the environment variable to set.

    .PARAMETER Value
        The value to set the environment variable to.
         
#>
function Set-ProcessEnvironmentVariable
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [String]
        $Value = [String]::Empty
    )

    [System.Environment]::SetEnvironmentVariable($Name, $Value)
}

<#
    .SYNOPSIS
        
    .PARAMETER Name        
#>
function Remove-EnvironmentVariable
{
    [CmdletBinding()]
    param
    (       
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Process', 'Machine')]
        [String[]]
        $Target
    )
        
    try
    {
        Set-EnvironmentVariable -Name $Name -Value $null -Target $Target
    }
    catch 
    {
        Write-Verbose -Message ($script:localizedData.EnvVarRemoveError -f $Name)
        throw $_
    }
}

<#
    .SYNOPSIS
        Utility to match environment paths.
          
    .PARAMETER ExistingPaths

    .PARAMETER QueryPaths

    .PARAMETER FindCriteria    
#>
function Test-PathInPathListWithCriteria
{
    [OutputType([Boolean])]  
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]               
        [String]
        $ExistingPaths,
        
        [Parameter(Mandatory = $true)]
        [String]
        $QueryPaths,

        [Parameter(Mandatory = $true)]      
        [ValidateSet('Any', 'All')]
        [String]
        $FindCriteria
    )

    $existingPathList = $ExistingPaths -split ';'
    $queryPathList = $QueryPaths -split ';'

    switch ($FindCriteria)
    {
        'Any'
        {
            foreach ($queryPath in $queryPathList)
            {            
                if (Test-PathInPathList -QueryPath $queryPath -PathList $existingPathList)
                {
                    # Found this $queryPath in the existing paths, return $true
                    return $true
                }                             
            }

            # If the control reached here, none of the $QueryPaths were found as part of the $ExistingPaths, return $false
            return $false   
        }

        'All'
        {
            foreach ($queryPath in $queryPathList)
            {
                if ($queryPath) 
                {
                    if (-not (Test-PathInPathList -QueryPath $queryPath -PathList $existingPathList))
                    {
                        # The current $queryPath wasn't found in any of the $existingPathList, return false                    
                        return $false
                    }
                }                
            }

            # If the control reached here, all of the $QueryPaths were found as part of the $ExistingPaths, return $true
            return $true
        }    
    }
}

<#
    .SYNOPSIS
          
    .PARAMETER QueryPath

    .PARAMETER PathList   
#>
function Test-PathInPathList
{
    [OutputType([Boolean])]
    [CmdletBinding()]    
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $QueryPath,
        
        [Parameter(Mandatory = $true)]       
        [String[]]
        $PathList
    )
    
    foreach ($path in $PathList)
    {
        if ($QueryPath -eq $path)
        {
            # If the query path matches any of the paths in $PathList, return $true
            return $true
        }                
    }     
    
    return $false        
}

<#
    .SYNOPSIS
          
    .PARAMETER Name    
#>
function Get-ItemPropertyExpanded
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [String]
        $Name
    )

    $path = $script:envVarRegPathMachine
    $pathTokens = $path.Split('\',[System.StringSplitOptions]::RemoveEmptyEntries)
    $entry = $pathTokens[1..($pathTokens.Count - 1)] -join '\'
    
    # Since the target registry path coming to this function is hardcoded for local machine
    $hive = [Microsoft.Win32.Registry]::LocalMachine

    $noteProperties = @{}

    try
    {
        $key = $hive.OpenSubKey($entry)
        
        $valueNames = $key.GetValueNames()

        if ($valueNames -inotcontains $Name)
        {
            return $null
        }
        
        [String] $value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $noteProperties.Add($Name, $value)
    }
    finally
    {
        if ($key)
        {
            $key.Close()
        }
    }

    [System.Management.Automation.PSObject] $propertyResults = New-Object -TypeName 'System.Management.Automation.PSObject' -Property $noteProperties
    return $propertyResults.$Name    
}

Export-ModuleMember -Function *-TargetResource
