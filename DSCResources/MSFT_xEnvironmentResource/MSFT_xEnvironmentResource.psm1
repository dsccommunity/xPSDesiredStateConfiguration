# This PS module contains functions for Desired State Configuration (DSC) "xEnvironment" resource

# Fallback message strings in en-US
DATA localizedData
{
    # culture = "en-US"
    ConvertFrom-StringData @'        
        EnvVarCreated = (CREATE) Environment variable '{0}' with value '{1}'        
        EnvVarSetError = (ERROR) Failed to set environment variable '{0}' to value '{1}'
        EnvVarPathSetError = (ERROR) Failed to add path '{0}' to environment variable '{1}' holding value '{2}'
        EnvVarRemoveError = (ERROR) Failed to remove environment variable '{0}' holding value '{1}'
        EnvVarPathRemoveError = (ERROR) Failed to remove path '{0}' from variable '{1}' holding value '{2}'
        EnvVarUnchanged = (UNCHANGED) Environment variable '{0}' with value '{1}'
        EnvVarUpdated = (UPDATE) Environment variable '{0}' from value '{1}' to value '{2}'
        EnvVarPathUnchanged = (UNCHANGED) Path environment variable '{0}' with value '{1}'
        EnvVarPathUpdated = (UPDATE) Environment variable '{0}' from value '{1}' to value '{2}'        
        EnvVarNotFound = (NOT FOUND) Environment variable '{0}'
        EnvVarFound = (FOUND) Environment variable '{0}' with value '{1}'
        EnvVarFoundWithMisMatchingValue = (FOUND MISMATCH) Environment variable '{0}' with value '{1}' mismatched the specified value '{2}'        
        EnvVarRemoved = (REMOVE) Environment variable '{0}'
'@
}
# Commented-out until more languages are supported
# Import-LocalizedData  LocalizedData -filename MSFT_xEnvironmentResource.strings.psd1

 
#-------------------------------------
# Script-level Constants and Variables
#-------------------------------------
$EnvVarRegPathMachine = "HKLM:\\System\\CurrentControlSet\\Control\\Session Manager\\Environment"
$EnvVarRegPathUser = "HKCU:\\Environment"

$EnvironmentVariableTarget = @{ Process = 0; User = 1; Machine = 2 }
$MaxSystemEnvVariableLength = 1024
$MaxUserEnvVariableLength = 255

Function Throw-InvalidArgumentException
{
    param(
        [string] $Message,
        [string] $ParamName
    )
    
    $exception = new-object System.ArgumentException $Message,$ParamName
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception,$ParamName,"InvalidArgument",$null
    throw $errorRecord
}

function GetEnvironmentVariable
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $Name, 

        [parameter(Mandatory = $true)]
        [int] $Target
    )

    if ($Target -eq $EnvironmentVariableTarget.Process) 
    {
        return [System.Environment]::GetEnvironmentVariable($Name);
    }

    if ($Target -eq $EnvironmentVariableTarget.Machine)
    {
        $retVal = Get-ItemProperty $EnvVarRegPathMachine -Name $Name -ErrorAction SilentlyContinue
        return $retVal.$Name
    }

    if ($Target -eq $EnvironmentVariableTarget.User)
    {
        $retVal = Get-ItemProperty $EnvVarRegPathUser -Name $Name -ErrorAction SilentlyContinue
        return $retVal.$Name
    }
}

function SetEnvironmentVariable
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $Name, 

        [String] $Value,

        [parameter(Mandatory = $true)]
        [int] $Target
    )

    if ($Target -eq $EnvironmentVariableTarget.Process) 
    {
        [System.Environment]::SetEnvironmentVariable($Name, $Value);
    }

    if ($Target -eq $EnvironmentVariableTarget.Machine) 
    {
        if ($Name.Length -ge $MaxSystemEnvVariableLength) {
            Throw-InvalidArgumentException -Message "Argument is too long." -ParamName $Name
        }
        $Path = $EnvVarRegPathMachine
    }
    elseif ($Target -eq $EnvironmentVariableTarget.User) 
    {
        if ($Name.Length -ge $MaxUserEnvVariableLength) {
            Throw-InvalidArgumentException -Message "Argument is too long." -ParamName $Name
        }
        $Path = $EnvVarRegPathUser
    }

    $environmentKey = Get-ItemProperty $Path -Name $Name -ErrorAction SilentlyContinue
    if ($environmentKey) 
    {
        if (!$Value) 
        {
            Remove-ItemProperty $Path -Name $Name -ErrorAction SilentlyContinue
        }
        else 
        {
            Set-ItemProperty $Path -Name $Name -Value $Value -ErrorAction SilentlyContinue
        }
    }
}


#------------------------------
# The Get-TargetResource cmdlet
#------------------------------
FUNCTION Get-TargetResource
{    
    [OutputType([Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name       
    )
        
    $retVal = GetItemProperty $EnvVarRegPathMachine -Name $Name -Expand:$false -ErrorAction SilentlyContinue
    
    if($retVal -eq $null)
    {        
        Write-Verbose ($localizedData.EnvVarNotFound -f $Name)
        
        return @{Ensure='Absent'; Name=$Name}      
    }    

    Write-Verbose ($localizedData.EnvVarFound -f $Name, $retVal.$Name)

    return @{Ensure='Present'; Name=$Name; Value=$retVal.$Name}
}

function Set-EnvVar
{
    param
    (       
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,
        
        [ValidateNotNull()]
        [System.String]
        $Value = [String]::Empty
    )

    $err = Set-ItemProperty $EnvVarRegPathMachine -Name $Name -Value $Value 2>&1

    if($err)
    {
        Write-Verbose ($localizedData.EnvVarSetError -f $Name, $Value)

        throw $err
    }                

    try
    {
        if($value)
        {
            SetEnvironmentVariable -Name $Name -Value $Value -Target $EnvironmentVariableTarget.Machine
            SetEnvironmentVariable -Name $Name -Value $Value -Target $EnvironmentVariableTarget.Process
        }
    }
    catch 
    {
        Write-Verbose ($localizedData.EnvVarSetError -f $Name, $Value)

        throw $_
    }

}
function Remove-EnvVar
{
    param
    (       
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    )

    $curVarProperties = Get-ItemProperty $EnvVarRegPathMachine -Name $Name -ErrorAction SilentlyContinue
    $currentValueFromEnv = GetEnvironmentVariable -Name $name -Target $EnvironmentVariableTarget.Process

    if($curVarProperties -ne $null)
    {
        $err = Remove-ItemProperty $EnvVarRegPathMachine -Name $Name 2>&1

        if($err)
        {
            Write-Log -Message ($localizedData.EnvVarRemoveError -f $Name, $Value)

            throw $err
        }
    }

    if($currentValueFromEnv -ne $null)
    {
        try
        {
            SetEnvironmentVariable -Name $Name -Value $null -Target $EnvironmentVariableTarget.Machine
            SetEnvironmentVariable -Name $Name -Value $null -Target $EnvironmentVariableTarget.Process
        }
        catch 
        {
            Write-Verbose ($localizedData.EnvVarRemoveError -f $Name, $Value)

            throw $_
        }
    }
}


#------------------------------
# The Set-TargetResource cmdlet
#------------------------------
FUNCTION Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (       
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,
        
        [ValidateNotNull()]
        [System.String]
        $Value = [String]::Empty,
        
        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = "Present",
        
        [System.Boolean]
        $Path = $false
    )
    
    $ValueSpecified = $PSBoundParameters.ContainsKey("Value")    
    
    $curVarProperties = GetItemProperty $EnvVarRegPathMachine -Name $Name -Expand:(-not $Path) -ErrorAction SilentlyContinue
    $currentValueFromEnv = GetEnvironmentVariable -Name $name -Target $EnvironmentVariableTarget.Process

    # ----------------
    # ENSURE = PRESENT
    if ($Ensure -ieq "Present")
    {        
        if (($curVarProperties -eq $null) -or (($currentValueFromEnv -eq $null) -and ($curVarProperties.$Name -ne [string]::Empty)))  # The specified variable doesn't exist already
        {
            # Given the specified $Name environment variable doesn't exist already,
            # simply create one with the specified value and return. If no $Value is 
            # specified, the default value is set to empty string "" (per spec).
            # Both path and non-path cases are covered by this.
            
            $successMessage = $localizedData.EnvVarCreated -f $Name, $Value

            if ($PSCmdlet.ShouldProcess($successMessage, $null, $null))
            {    
                Set-EnvVar -Name $Name -Value $Value
            }            
                        
            return
        }
        
        # If the control reaches here, the specified variable exists already

        if (!$ValueSpecified)
        {
            # Given no $Value was specified to be set and the variable exists, 
            # we'll leave the existing variable as is.
            # This covers both path and non-path variables.

            Write-Log -Message ($localizedData.EnvVarUnchanged -f $Name, $curVarProperties.$Name)

            return
        }

        # If the control reaches here: the specified variable exists already and a $Value has been specified to be set.

        if (!$Path)
        {
            # For non-path variables, simply set the specified $Value as the new value of the specified 
            # variable $Name, then return.

            $successMessage = $localizedData.EnvVarUpdated -f $Name, $curVarProperties.$Name, $Value
            if ($Value -ceq $curVarProperties.$Name)
            {
                $successMessage = $localizedData.EnvVarUnchanged -f $Name, $curVarProperties.$Name
            }

            if ($PSCmdlet.ShouldProcess($successMessage, $null, $null) -and ($Value -cne $curVarProperties.$Name))
            {    
                Set-EnvVar -Name $Name -Value $Value
            }             

            return
        }
        
        # If the control reaches here: the specified variable exists already, it is a path variable and a $Value has been specified to be set.                               
            
        # Check if an empty, whitespace or semi-colon only string has been specified. If yes, return unchanged.
        $trimmedValue = $Value.Trim(";"," ")
        if ([String]::IsNullOrEmpty($trimmedValue))
        {
            Write-Log -Message ($localizedData.EnvVarPathUnchanged -f $Name, $curVarProperties.$Name)

            return        
        }


        $setValue = $curVarProperties.$Name + ";"
        $specifiedPaths = $trimmedValue -split ";"
        $currentPaths = $curVarProperties.$Name -split ";"                                
        $varUpdated = $false

        foreach ($specifiedPath in $specifiedPaths)            
        {            
            if (FindSubPath -QueryPath $specifiedPath -PathList $currentPaths)
            {
                # Found this $specifiedPath as one of the $currentPaths, no need to add this again, skip/continue to the next $specifiedPath
                
                continue
            }

            # If the control reached here, we didn't find this $specifiedPath in the $currentPaths, add it
            # and mark the environment variable as updated.

            $varUpdated = $true
            $setValue += $specifiedPath + ";"                            
        }  

        # Remove any extraneous ";" at the end (and potentially start - as a side-effect) of the value to be set
        $setValue = $setValue.Trim(";")        
                                           
        # Set the expected success message
        $successMessage = $localizedData.EnvVarPathUnchanged -f $Name, $curVarProperties.$Name                   
        if ($varUpdated)
        {
            $successMessage = $localizedData.EnvVarPathUpdated -f $Name, $curVarProperties.$Name, $setValue
        }
                
        if ($PSCmdlet.ShouldProcess($successMessage, $null, $null))
        {    
            # Finally update the existing environment path variable        

            Set-EnvVar -Name $Name -Value $setValue
        }        
    }

    # ---------------
    # ENSURE = ABSENT
    elseif ($Ensure -ieq "Absent")
    {
        if(($curVarProperties -eq $null) -and ($currentValueFromEnv -eq $null))
        {
            # Variable not found, condition is satisfied and there is nothing to set/remove, return

            Write-Log -Message ($localizedData.EnvVarNotFound -f $Name)
                        
            return
        }
        
        if(!$ValueSpecified -or !$Path)
        {
            # If no $Value specified to be removed, simply remove the environment variable (holds true for both path and non-path variables
            # OR
            # Regardless of $Value, if the target variable is a non-path variable, simply remove it to meet the absent condition

            $successMessage = $localizedData.EnvVarRemoved -f $Name

            if ($PSCmdlet.ShouldProcess($successMessage, $null, $null))
            {    
                Remove-EnvVar -Name $Name
            }             

            return
        }
                
        # If the control reaches here: target variable is an existing environment path-variable and a specified $Value needs be removed from it

        # Check if an empty string or semi-colon only string has been specified as $Value. If yes, return unchanged as we don't need to remove anything.
        $trimmedValue = $Value.Trim(";")
        if ([String]::IsNullOrEmpty($trimmedValue))
        {
            Write-Log -Message ($localizedData.EnvVarPathUnchanged -f $Name, $curVarProperties.$Name)

            return        
        }
                
        $finalPath = ""
        $specifiedPaths = $trimmedValue -split ";"
        $currentPaths = $curVarProperties.$Name -split ";"                                
        $varAltered = $false

        foreach ($subpath in $currentPaths)            
        {
            if (FindSubPath -QueryPath $subpath -PathList $specifiedPaths)
            {
                # Found this $subpath as one of the $specifiedPaths, skip adding this to the final value/path of this variable
                # and mark the variable as altered.

                $varAltered = $true
                continue
            }

            # If the control reaches here, the current $subpath was not part of the $specifiedPaths (to be removed), 
            # so keep this $subpath in the finalPath
            
            $finalPath += $subpath + ";"                            
        }                          
        
        # Remove any extraneous ";" at the end (and potentially start - as a side-effect) of the $finalPath        
        $finalPath = $finalPath.Trim(";")
                          
            
        # Set the expected success message
        $successMessage = $localizedData.EnvVarPathUnchanged -f $Name, $curVarProperties.$Name
        if ($varAltered)
        {
            $successMessage = $localizedData.EnvVarPathUpdated -f $Name, $curVarProperties.$Name, $finalPath
            
            if ([String]::IsNullOrEmpty($finalPath))
            {
                $successMessage = $localizedData.EnvVarRemoved -f $Name
            }            
        }
        
        # Handle WhatIf case and update resource as appropriate                
        if ($PSCmdlet.ShouldProcess($successMessage, $null, $null))
        {    
            # Finally, update the environment path-variable

            if ([String]::IsNullOrEmpty($finalPath))
            {
                Remove-EnvVar -Name $Name
            }
            else
            {
                Set-EnvVar -Name $Name -Value $finalPath
            }

            if($err)
            {
                Write-Log -Message ($localizedData.EnvVarPathRemoveError -f $Value, $Name, $curVarProperties.$Name)

                throw $err
            }
        } 
    }
}


#-------------------------------
# The Test-TargetResource cmdlet
#-------------------------------
FUNCTION Test-TargetResource
{
    [OutputType([System.Boolean])]
    param
    (       
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,
        
        [ValidateNotNull()]
        [System.String]
        $Value,

        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = "Present",
        
        [System.Boolean]
        $Path = $false
    )
    
    $ValueSpecified = $PSBoundParameters.ContainsKey("Value")
    $curVarProperties = GetItemProperty $EnvVarRegPathMachine -Name $Name -Expand:(-not $Path) -ErrorAction SilentlyContinue
    $currentValueFromEnv = GetEnvironmentVariable -Name $name -Target $EnvironmentVariableTarget.Process

    # ----------------
    # ENSURE = PRESENT
    if ($Ensure -ieq "Present")
    {        
        if (($curVarProperties -eq $null) -or (($currentValueFromEnv -eq $null) -and ($curVarProperties.$Name -ne [string]::Empty)) )
        {
            # Variable not found, return failure

            Write-Verbose ($localizedData.EnvVarNotFound -f $Name)

            return $false
        }

        if (!$ValueSpecified)
        {
            # No value has been specified for test, so the existence of the variable means success

            Write-Verbose ($localizedData.EnvVarFound -f $Name, $curVarProperties.$Name)

            return $true
        }
        
        if (!$Path)
        {
            # For this non-path variable, make sure that the specified $Value matches the current value.
            # Success if it matches, failure otherwise

            if ($Value -ceq $curVarProperties.$Name)
            {
                Write-Verbose ($localizedData.EnvVarFound -f $Name, $curVarProperties.$Name)
                
                return $true                
            }
            else
            {
                Write-Verbose ($localizedData.EnvVarFoundWithMisMatchingValue -f $Name, $curVarProperties.$Name, $Value)

                return $false
            }
        }             
                       
        # If the control reaches here, the expected environment variable exists, it is a path variable and a $Value is specified to test against
                
        if (FindPath -ExistingPaths $curVarProperties.$Name -QueryPaths $Value -FindCriteria All)
        {
            # The specified path was completely present in the existing environment variable, return success

            Write-Verbose ($localizedData.EnvVarFound -f $Name, $curVarProperties.$Name)

            return $true
        }   
                    
        # If the control reached here some part of the specified path ($Value) was not found in the existing variable, return failure
                
        Write-Verbose ($localizedData.EnvVarFoundWithMisMatchingValue -f $Name, $curVarProperties.$Name, $Value)

        return $false 
    }

    # ---------------
    # ENSURE = ABSENT
    elseif ($Ensure -eq "Absent")
    {
        if(($curVarProperties -eq $null) -and ($currentValueFromEnv -eq $null))
        {
            # Variable not found (path/non-path and $Value both do not matter then), return success

            Write-Verbose ($localizedData.EnvVarNotFound -f $Name)

            return $true
        }

        if (!$ValueSpecified)
        {
            # Given no value has been specified for test, the mere existence of the variable fails the test

            Write-Verbose ($localizedData.EnvVarFound -f $Name, $curVarProperties.$Name)

            return $false
        }

        # If the control reaches here: the variable exists and a value has been specified to test against it
                
        if (!$Path)
        {            
            # For this non-path variable, make sure that the specified value doesn't match the current value
            # Success if it doesn't match, failure otherwise
            
            if ($Value -cne $curVarProperties.$Name)
            {
                Write-Verbose ($localizedData.EnvVarFoundWithMisMatchingValue -f $Name, $curVarProperties.$Name, $Value)                
                
                return $true                
            }
            else
            {
                Write-Verbose ($localizedData.EnvVarFound -f $Name, $curVarProperties.$Name)

                return $false
            }
        }
                    
        # If the control reaches here: the variable exists, it is a path variable, and a value has been specified to test against it                               
        
        if (FindPath -ExistingPaths $curVarProperties.$Name -QueryPaths $Value -FindCriteria Any)
        {
            # One of the specified paths in $Value exists in the environment variable path, thus the test fails

            Write-Verbose ($localizedData.EnvVarFound -f $Name, $curVarProperties.$Name)

            return $false
        }
                    
        # If the control reached here, none of the specified paths were found in the existing path-variable, return success                                               

        Write-Verbose ($localizedData.EnvVarFoundWithMisMatchingValue -f $Name, $curVarProperties.$Name, $Value)                

        return $true        
    }    
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


#-----------------------------------
# Utility to match environment paths
#-----------------------------------
FUNCTION FindPath
{    
    param
    (               
        [System.String]
        $ExistingPaths,
        
        [System.String]
        $QueryPaths,

        [parameter(Mandatory = $true)]      
        [ValidateSet("Any", "All")]
        [System.String]
        $FindCriteria
    )

    $existingPathList = $ExistingPaths -split ";"
    $queryPathList = $QueryPaths -split ";"

    switch ($FindCriteria)
    {
        "Any"
        {
            foreach ($queryPath in $queryPathList)
            {            
                if (FindSubPath -QueryPath $queryPath -PathList $existingPathList)
                {
                    # Found this $queryPath in the existing paths, return $true
                    return $true
                }                             
            }

            # If the control reached here, none of the $QueryPaths were found as part of the $ExistingPaths, return $false
            return $false   
        }

        "All"
        {
            foreach ($queryPath in $queryPathList)
            {
                $found = $false
                if($queryPath) 
                {
                    if (!(FindSubPath -QueryPath $queryPath -PathList $existingPathList))
                    {
                        # The current $queryPath wasn't found in any of the $existingPathList, return failure                    
                        return $false
                    }
                }                
            }

            # If the control reached here, all of the $QueryPaths were found as part of the $ExistingPaths, return $true
            return $true
        }    
    }
}


#---------------------------------------
# Utility to search a path in a pathlist
#---------------------------------------
FUNCTION FindSubPath
{    
    param
    (
        [System.String]
        $QueryPath,
                
        [String[]]
        $PathList
    )
    
    foreach ($path in $PathList)
    {
        if($QueryPath -ieq $path)
        {
            # If the query path matches any of the paths in $PathList, return $true
            return $true
        }                
    }     
    
    return $false        
}

#---------------------------------------------------------------
# Utility to get item property without expanding it if necessary
#---------------------------------------------------------------
FUNCTION GetItemProperty
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,
        
        [ValidateNotNull()]
        [System.String]
        $Name,
        
        [switch]
        $Expand = $false
    )

    if ($Expand)
    {
        return (Get-ItemProperty $EnvVarRegPathMachine -Name $Name -ErrorAction SilentlyContinue)
    }
    else
    {
        if (!(Test-Path -Path $Path))
        {
            return $null;
        }

        $PathTokens = $Path.Split('\',[System.StringSplitOptions]::RemoveEmptyEntries)
        $Division = $PathTokens[0].Replace(':', '')
        $Entry = $PathTokens[1..($PathTokens.Count-1)] -join '\'
        
        # Since the target registry path coming to this function is hardcoded for local machine
        $Hive = [Microsoft.Win32.Registry]::LocalMachine

        $NoteProperties = @{}
        try
        {
            $Key = $Hive.OpenSubKey($Entry)
            
            $ValueNames = $Key.GetValueNames()
            if ($ValueNames -inotcontains $Name)
            {
                return $null
            }
            
            [string] $Value = $Key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $NoteProperties.Add($Name, $Value)
        }
        finally
        {
            if ($key)
            {
                $key.Close()
            }
        }

        [System.Management.Automation.PSObject] $PropertyResults = New-Object -TypeName System.Management.Automation.PSObject -Property $NoteProperties

        return $PropertyResults
    }
}

Export-ModuleMember -function Get-TargetResource, Set-TargetResource, Test-TargetResource
