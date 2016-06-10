<#
    .SYNOPSIS
    Tests if a local user group exists.

    .PARAMETER GroupName
    The name of the local user group to test for.
#>
function Test-LocalGroupExists
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $GroupName
    )

    if (Test-IsNanoServer)
    {
        # Try to find a group by its name.
        try
        {
            $null = Get-LocalGroup -Name $GroupName -ErrorAction Stop
            return $true
        }
        catch [System.Exception]
        {
            if ($_.CategoryInfo.ToString().Contains('GroupNotFoundException'))
            {
                # A group with the provided name does not exist.
                return $false
            }
            throw $_.Exception
        }
    }
    else
    {
        return [ADSI]::Exists("WinNT://$env:ComputerName/$GroupName,group")
    }
}

<#
    .SYNOPSIS
    Creates a new local user group.

    .PARAMETER GroupName
    The name of the local user group to create.

    .PARAMETER Description
    The description of the local user group to create.
#>
function New-LocalUserGroup
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $GroupName, 
        
        [String]
        $Description
    )

    if (Test-IsNanoServer)
    {
        New-LocalUserGroupOnNanoServer @PSBoundParameters
    }
    else
    {
        New-LocalUserGroupOnFullSKU @PSBoundParameters
    }
}

<#
    .SYNOPSIS
    Creates a new local user group on a full server.

    .PARAMETER GroupName
    The name of the local user group to create.

    .PARAMETER Description
    The description of the local user group to create.
#>
function New-LocalUserGroupOnFullSKU
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $GroupName, 
        
        [Parameter(Mandatory = $true)]
        [String]
        $Description
    )

    $computer = [ADSI]"WinNT://$env:ComputerName,Computer"
    
    if (-not (Test-LocalGroupExists $GroupName))
    {
        $group = $computer.Create("Group", $GroupName)
        $group.SetInfo()
        $group.Description = $Description
        $group.SetInfo()
    }
}

<#
    .SYNOPSIS
    Creates a new local user group on a Nano server.

    .PARAMETER GroupName
    The name of the local user group to create.

    .PARAMETER Description
    The description of the local user group to create.
#>
function New-LocalUserGroupOnNanoServer
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $GroupName, 
        
        [Parameter(Mandatory = $true)]
        [String]
        $Description
    )

    if (-not (Test-LocalGroupExists $GroupName))
    {
        New-LocalGroup -Name $GroupName -Description $Description
    }
}

<#
    .SYNOPSIS
    Deletes a local user group.

    .PARAMETER GroupName
    The name of the local user group to delete.
#>
function Remove-LocalUserGroup
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $GroupName
    )

    if (Test-IsNanoServer)
    {
        Remove-LocalUserGroupOnNanoServer @PSBoundParameters
    }
    else
    {
        Remove-LocalUserGroupOnFullSKU @PSBoundParameters
    }
}

<#
    .SYNOPSIS
    Deletes a local user group on a full server.

    .PARAMETER GroupName
    The name of the local user group to delete.
#>
function Remove-LocalUserGroupOnFullSKU
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $GroupName
    )

    $computer = [ADSI]"WinNT://$Env:COMPUTERNAME,Computer"
    
    if (Test-LocalGroupExists $GroupName)
    {
        $group = $computer.Delete("Group", $GroupName)
    }
}

<#
    .SYNOPSIS
    Deletes a local user group on a Nano server.

    .PARAMETER GroupName
    The name of the local user group to delete.
#>
function Remove-LocalUserGroupOnNanoServer
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $GroupName
    )

    if (Test-LocalGroupExists $GroupName)
    {
        Remove-LocalGroup -Name $GroupName
    }
}

Export-ModuleMember -Function `
    New-LocalUserGroup, `
    Remove-LocalUserGroup
