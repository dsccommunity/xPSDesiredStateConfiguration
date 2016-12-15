$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

Import-Module -Name (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) `
                               -ChildPath 'CommonResourceHelper.psm1')
$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_xEnvironmentResource'

$script:envVarRegPathMachine = 'HKLM:\\System\\CurrentControlSet\\Control\\Session Manager\\Environment'
$script:envVarRegPathUser = 'HKCU:\\Environment'

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
        
    $envVar = Get-ItemPropertyExpanded -Name $Name -ErrorAction SilentlyContinue
    
    if ($envVar -eq $null)
    {        
        Write-Verbose -Message ($script:localizedData.EnvVarNotFound -f $Name)
        
        return @{
            Ensure = 'Absent'
            Name = $Name
        }      
    }    

    Write-Verbose -Message ($script:localizedData.EnvVarFound -f $Name, $envVar.$Name)

    return @{
        Ensure = 'Present'
        Name = $Name
        Value = $envVar.$Name
    }
}

<#
    .SYNOPSIS
        
    .PARAMETER Name

    .PARAMETER Value

    .PARAMETER Ensure

    .PARAMETER Path
        
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
        $Path = $false
    )
    
    $valueSpecified = $PSBoundParameters.ContainsKey('Value')
    $curVarProperties = System.Management.Automation.PSObject

    if ($Path)
    {
        $curVarProperties = Get-ItemProperty -Path $script:envVarRegPathMachine -Name $Name -ErrorAction SilentlyContinue
    } 
    else
    {
        $curVarProperties = Get-ItemPropertyExpanded -Name $Name -ErrorAction SilentlyContinue
    }

    $currentValueFromEnv = Get-EnvironmentVariable -Name $name -Target $script:environmentVariableTarget.Process

    if ($Ensure -ieq 'Present')
    {
        # The specified variable doesn't exist       
        if (($curVarProperties -eq $null) -or (($currentValueFromEnv -eq $null) -and ($curVarProperties.$Name -ne [String]::Empty)))
        {
            # Given the specified $Name environment variable doesn't exist yet,
            # simply create one with the specified value and return. If no $Value is 
            # specified, the default value is set to empty string '' (per spec).
            # Both path and non-path cases are covered by this.
            
            $successMessage = $script:localizedData.EnvVarCreated -f $Name, $Value
            Write-Verbose -Message $successMessage

            Set-MachineAndProcessEnvironmentVariables -Name $Name -Value $Value          
                        
            return
        }

        if (-not $valueSpecified)
        {
            # Given no $Value was specified to be set and the variable exists, 
            # we'll leave the existing variable as is.
            # This covers both path and non-path variables.

            Write-Verbose -Message ($script:localizedData.EnvVarUnchanged -f $Name, $curVarProperties.$Name)

            return
        }

        if (-not $Path)
        {
            # For non-path variables, simply set the specified $Value as the new value of the specified 
            # variable $Name, then return.

            if ($Value -ceq $curVarProperties.$Name)
            {
                Write-Verbose -Message $script:localizedData.EnvVarUnchanged -f $Name, $curVarProperties.$Name
                return
            }
            
            Write-Verbose -Message $script:localizedData.EnvVarUpdated -f $Name, $curVarProperties.$Name, $Value

            Set-MachineAndProcessEnvironmentVariables -Name $Name -Value $Value            
            return
        }
        
        # If the control reaches here: the specified variable exists already, it is a path variable and a $Value has been specified to be set.                               
            
        # Check if an empty, whitespace or semi-colon only string has been specified. If yes, return unchanged.
        $trimmedValue = $Value.Trim(';',' ')

        if ([String]::IsNullOrEmpty($trimmedValue))
        {
            Write-Verbose -Message ($script:localizedData.EnvVarPathUnchanged -f $Name, $curVarProperties.$Name)
            return        
        }

        $setValue = $curVarProperties.$Name + ';'
        $specifiedPaths = $trimmedValue -split ';'
        $currentPaths = $curVarProperties.$Name -split ';'                                
        $varUpdated = $false

        foreach ($specifiedPath in $specifiedPaths)            
        {            
            if (-not (Test-PathInPathList -QueryPath $specifiedPath -PathList $currentPaths))
            {
                # If the control reached here, we didn't find this $specifiedPath in the $currentPaths, add it
                # and mark the environment variable as updated.

                $varUpdated = $true
                $setValue += $specifiedPath + ';'
            }                            
        }  

        # Remove any extraneous ';' at the end (and potentially start - as a side-effect) of the value to be set
        $setValue = $setValue.Trim(';')        
                  
        if ($varUpdated)
        {
            # update the existing environment path variable
            Write-Verbose -Message $script:localizedData.EnvVarPathUpdated -f $Name, $curVarProperties.$Name, $setValue        
            Set-MachineAndProcessEnvironmentVariables -Name $Name -Value $setValue
        }
        else
        {
            Write-Verbose -Message $script:localizedData.EnvVarPathUnchanged -f $Name, $curVarProperties.$Name
        }
    }

    # Ensure = 'Absent'
    else
    {
        if (($curVarProperties -eq $null) -and ($currentValueFromEnv -eq $null))
        {
            # Variable not found, condition is satisfied and there is nothing to set/remove, return
            Write-Verbose -Message ($script:localizedData.EnvVarNotFound -f $Name)
                        
            return
        }
        
        if (!$ValueSpecified -or !$Path)
        {
            # If no $Value specified to be removed, simply remove the environment variable (holds true for both path and non-path variables)
            # OR
            # Regardless of $Value, if the target variable is a non-path variable, simply remove it to meet the absent condition

            Write-Verbose -Message $script:localizedData.EnvVarRemoved -f $Name

            Remove-EnvironmentVariable -Name $Name        

            return
        }
                
        # If the control reaches here: target variable is an existing environment path-variable and a specified $Value needs be removed from it

        # Check if an empty string or semi-colon only string has been specified as $Value. If yes, return unchanged as we don't need to remove anything.
        $trimmedValue = $Value.Trim(';')

        if ([String]::IsNullOrEmpty($trimmedValue))
        {
            Write-Verbose -Message ($script:localizedData.EnvVarPathUnchanged -f $Name, $curVarProperties.$Name)

            return        
        }
                
        $finalPath = ''
        $specifiedPaths = $trimmedValue -split ';'
        $currentPaths = $curVarProperties.$Name -split ';'                                
        $varAltered = $false

        foreach ($subpath in $currentPaths)            
        {
            if (Test-PathInPathList -QueryPath $subpath -PathList $specifiedPaths)
            {
                # Found this $subpath as one of the $specifiedPaths, skip adding this to the final value/path of this variable
                # and mark the variable as altered.

                $varAltered = $true
                continue
            }

            # If the control reaches here, the current $subpath was not part of the $specifiedPaths (to be removed), 
            # so keep this $subpath in the finalPath
            
            $finalPath += $subpath + ';'                            
        }                          
        
        # Remove any extraneous ';' at the end (and potentially start - as a side-effect) of the $finalPath        
        $finalPath = $finalPath.Trim(';')                
            
        # Set the expected success message
        $successMessage = $script:localizedData.EnvVarPathUnchanged -f $Name, $curVarProperties.$Name

        if ($varAltered)
        {
            $successMessage = $script:localizedData.EnvVarPathUpdated -f $Name, $curVarProperties.$Name, $finalPath
            
            if ([String]::IsNullOrEmpty($finalPath))
            {
                $successMessage = $script:localizedData.EnvVarRemoved -f $Name
            }            
        }
        
        # Update resource as appropriate                
        Write-Verbose -Message $successMessage

        if ([String]::IsNullOrEmpty($finalPath))
        {
            Remove-EnvironmentVariable -Name $Name
        }
        else
        {
            Set-MachineAndProcessEnvironmentVariables -Name $Name -Value $finalPath
        }
    }
}

<#
    .SYNOPSIS
        
    .PARAMETER Name

    .PARAMETER Value

    .PARAMETER Ensure

    .PARAMETER Path
        
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
        $Path = $false
    )
    
    $ValueSpecified = $PSBoundParameters.ContainsKey('Value')
    $curVarProperties = System.Management.Automation.PSObject

    if ($Path)
    {
        $curVarProperties = Get-ItemProperty -Path $script:envVarRegPathMachine -Name $Name -ErrorAction SilentlyContinue
    } 
    else
    {
        $curVarProperties = Get-ItemPropertyExpanded -Name $Name -ErrorAction SilentlyContinue
    }

    $currentValueFromEnv = Get-EnvironmentVariable -Name $name -Target $script:environmentVariableTarget.Process

    if ($Ensure -ieq 'Present')
    {        
        if (($curVarProperties -eq $null) -or (($currentValueFromEnv -eq $null) -and ($curVarProperties.$Name -ne [String]::Empty)) )
        {
            # Variable not found, return failure

            Write-Verbose ($script:localizedData.EnvVarNotFound -f $Name)

            return $false
        }

        if (-not $ValueSpecified)
        {
            # No value has been specified for test, so the existence of the variable means success

            Write-Verbose ($script:localizedData.EnvVarFound -f $Name, $curVarProperties.$Name)

            return $true
        }
        
        if (!$Path)
        {
            # For this non-path variable, make sure that the specified $Value matches the current value.
            # Success if it matches, failure otherwise

            if ($Value -ceq $curVarProperties.$Name)
            {
                Write-Verbose ($script:localizedData.EnvVarFound -f $Name, $curVarProperties.$Name)
                
                return $true                
            }
            else
            {
                Write-Verbose ($script:localizedData.EnvVarFoundWithMisMatchingValue -f $Name, $curVarProperties.$Name, $Value)

                return $false
            }
        }             
                       
        # If the control reaches here, the expected environment variable exists, it is a path variable and a $Value is specified to test against
                
        if (Test-PathInPathListWithCriteria -ExistingPaths $curVarProperties.$Name -QueryPaths $Value -FindCriteria 'All')
        {
            # The specified path was completely present in the existing environment variable, return success

            Write-Verbose ($script:localizedData.EnvVarFound -f $Name, $curVarProperties.$Name)

            return $true
        }   
                    
        # If the control reached here some part of the specified path ($Value) was not found in the existing variable, return failure
                
        Write-Verbose ($script:localizedData.EnvVarFoundWithMisMatchingValue -f $Name, $curVarProperties.$Name, $Value)

        return $false 
    }

    # Ensure = 'Absent'
    else
    {
        if(($curVarProperties -eq $null) -and ($currentValueFromEnv -eq $null))
        {
            # Variable not found (path/non-path and $Value both do not matter then), return success

            Write-Verbose ($script:localizedData.EnvVarNotFound -f $Name)

            return $true
        }

        if (!$ValueSpecified)
        {
            # Given no value has been specified for test, the mere existence of the variable fails the test

            Write-Verbose ($script:localizedData.EnvVarFound -f $Name, $curVarProperties.$Name)

            return $false
        }

        # If the control reaches here: the variable exists and a value has been specified to test against it
                
        if (-not $Path)
        {            
            # For this non-path variable, make sure that the specified value doesn't match the current value
            # Success if it doesn't match, failure otherwise
            
            if ($Value -cne $curVarProperties.$Name)
            {
                Write-Verbose ($script:localizedData.EnvVarFoundWithMisMatchingValue -f $Name, $curVarProperties.$Name, $Value)                
                
                return $true                
            }
            else
            {
                Write-Verbose ($script:localizedData.EnvVarFound -f $Name, $curVarProperties.$Name)

                return $false
            }
        }
                    
        # If the control reaches here: the variable exists, it is a path variable, and a value has been specified to test against it                               
        
        if (Test-PathInPathListWithCriteria -ExistingPaths $curVarProperties.$Name -QueryPaths $Value -FindCriteria 'Any')
        {
            # One of the specified paths in $Value exists in the environment variable path, thus the test fails

            Write-Verbose ($script:localizedData.EnvVarFound -f $Name, $curVarProperties.$Name)

            return $false
        }
                    
        # If the control reached here, none of the specified paths were found in the existing path-variable, return success                                               

        Write-Verbose ($script:localizedData.EnvVarFoundWithMisMatchingValue -f $Name, $curVarProperties.$Name, $Value)                

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

    if ($Target -eq $script:environmentVariableTarget.Process) 
    {
        return [System.Environment]::GetEnvironmentVariable($Name)
    }
    elseif ($Target -eq $script:environmentVariableTarget.Machine)
    {
        $retVal = Get-ItemProperty -Path $script:envVarRegPathMachine -Name $Name -ErrorAction SilentlyContinue
        return $retVal.$Name
    }
    elseif ($Target -eq $script:environmentVariableTarget.User)
    {
        $retVal = Get-ItemProperty -Path $script:envVarRegPathUser -Name $Name -ErrorAction SilentlyContinue
        return $retVal.$Name
    }
    else
    {
        New-InvalidArgumentException -Message $script:localizedData.InvalidTarget -ArgumentName $Target
    }
}

<#
    .SYNOPSIS
        
    .PARAMETER Name

    .PARAMETER Value        
#>
function Set-MachineAndProcessEnvironmentVariables
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
        $Value = [String]::Empty
    )

    try
    {
        Set-ItemProperty -Path $script:envVarRegPathMachine -Name $Name -Value $Value

        if ($Value)
        {
            Set-EnvironmentVariable -Name $Name -Value $Value -Target $script:environmentVariableTarget.Machine
            Set-EnvironmentVariable -Name $Name -Value $Value -Target $script:environmentVariableTarget.Process
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
        $Value,

        [Parameter(Mandatory = $true)]
        [Int]
        $Target
    )

    if ($Target -eq $script:environmentVariableTarget.Process) 
    {
        [System.Environment]::SetEnvironmentVariable($Name, $Value)
    }
    elseif ($Target -eq $script:environmentVariableTarget.Machine) 
    {
        if ($Name.Length -ge $script:maxSystemEnvVariableLength)
        {
            New-InvalidArgumentException -Message $script:localizedData.ArgumentTooLong -ArgumentName $Name
        }

        $Path = $script:envVarRegPathMachine
    }
    elseif ($Target -eq $script:environmentVariableTarget.User) 
    {
        if ($Name.Length -ge $script:maxUserEnvVariableLength)
        {
            New-InvalidArgumentException -Message $script:localizedData.ArgumentTooLong -ArgumentName $Name
        }

        $Path = $script:envVarRegPathUser
    }
    else
    {
        New-InvalidArgumentException -Message $script:localizedData.InvalidTarget -ArgumentName $Target
    }

    $environmentKey = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue

    if ($environmentKey) 
    {
        if (!$Value) 
        {
            Remove-ItemProperty $Path -Name $Name -ErrorAction SilentlyContinue
        }
        else 
        {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -ErrorAction SilentlyContinue
        }
    }
    else
    {
        $message = ($script:localizedData.GetItemPropertyFailure -f $Name, $Path)
        New-InvalidArgumentException -Message $message -ArgumentName $Name
    }
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
        $Name
    )

    $curVarProperties = Get-ItemProperty -Path $script:envVarRegPathMachine -Name $Name -ErrorAction SilentlyContinue
    $currentValueFromEnv = Get-EnvironmentVariable -Name $name -Target $script:environmentVariableTarget.Process
        
    try
    {
        if ($curVarProperties -ne $null)
        {
            Remove-ItemProperty $script:envVarRegPathMachine -Name $Name
        }

        if ($currentValueFromEnv -ne $null)
        {
            Set-EnvironmentVariable -Name $Name -Value $null -Target $script:environmentVariableTarget.Machine
            Set-EnvironmentVariable -Name $Name -Value $null -Target $script:environmentVariableTarget.Process
        }
    }
    catch 
    {
        Write-Verbose -Message($script:localizedData.EnvVarRemoveError -f $Name, $Value)

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
        if ($QueryPath -ieq $path)
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

    return $propertyResults    
}

Export-ModuleMember -Function *-TargetResource
