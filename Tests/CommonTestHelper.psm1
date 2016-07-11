Import-Module "$PSScriptRoot\..\DSCResources\CommonResourceHelper.psm1" -Force

<#
    .SYNOPSIS
    Tests that the Get-TargetResource method of a DSC Resource is not null, can be converted to a hashtable, and has the correct properties.
    Uses Pester.

    .PARAMETER GetTargetResourceResult
    The result of the Get-TargetResource method.

    .PARAMETER GetTargetResourceResultProperties
    The properties that the result of Get-TargetResource should have.
#>
function Test-GetTargetResourceResult
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Hashtable] $GetTargetResourceResult,

        [String[]] $GetTargetResourceResultProperties
    )

    foreach ($property in $GetTargetResourceResultProperties)
    {
        $GetTargetResourceResult[$property] | Should Not Be $null
    }
}

<#
    .SYNOPSIS
    Tests if a scope represents the current machine.

    .PARAMETER Scope
    The scope to test.
#>
function Test-IsLocalMachine
{
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Scope
    )

    Set-StrictMode -Version latest

    if ($scope -eq ".")
    {
        return $true
    }

    if ($scope -eq $env:COMPUTERNAME)
    {
        return $true
    }

    if ($scope -eq "localhost")
    {
        return $true
    }

    if ($scope.Contains("."))
    {
        if ($scope -eq "127.0.0.1")
        {
            return $true
        }

        # Determine if we have an ip address that matches an ip address on one of the network adapters.
        # NOTE: This is likely overkill; consider removing it.
        $networkAdapters = @(Get-CimInstance Win32_NetworkAdapterConfiguration)
        foreach ($networkAdapter in $networkAdapters)
        {
            if ($null -ne $networkAdapter.IPAddress)
            {
                foreach ($address in $networkAdapter.IPAddress)
                {
                    if ($address -eq $scope)
                    {
                        return $true
                    }
                }
            }
        }
    }

    return $false
}

<#
    .SYNOPSIS
    Creates a user account.

    .DESCRIPTION
    This function creates a user on the local or remote machine.

    .PARAMETER Credential
    The credential containing the username and password to use to create the account.

    .PARAMETER Description
    The optional description to set on the user account.

    .PARAMETER ComputerName
    The optional name of the computer to update. Omit to create a user on the local machine.

    .NOTES
    For remote machines, the currently logged on user must have rights to create a user.
#>
function New-User
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Credential,

        [string]
        $Description,

        [string]
        $ComputerName = $env:COMPUTERNAME
    )

    if (Test-IsNanoServer)
    {
        New-UserOnNanoServer @PSBoundParameters
    }
    else
    {
        New-UserOnFullSKU @PSBoundParameters
    }
}

<#
    .SYNOPSIS
    Creates a user account on a full server.

    .DESCRIPTION
    This function creates a user on the local or remote machine running a full server.

    .PARAMETER Credential
    The credential containing the username and password to use to create the account.

    .PARAMETER Description
    The optional description to set on the user account.

    .PARAMETER ComputerName
    The optional name of the computer to update. Omit to create a user on the local machine.

    .NOTES
    For remote machines, the currently logged on user must have rights to create a user.
#>
function New-UserOnFullSKU
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Credential,

        [string]
        $Description,

        [string]
        $ComputerName = $env:COMPUTERNAME
    )

    Set-StrictMode -Version Latest

    $userName = $Credential.UserName
    $password = $Credential.GetNetworkCredential().Password

    # Remove user if it already exists.
    Remove-User $userName $ComputerName

    $adComputerEntry = [ADSI] "WinNT://$ComputerName"
    $adUserEntry = $adComputerEntry.Create("User", $userName)
    $null = $adUserEntry.SetPassword($password)

    if ($PSBoundParameters.ContainsKey("Description"))
    {
        $null = $adUserEntry.Put("Description", $Description)
    }

    $null = $adUserEntry.SetInfo()
}

<#
    .SYNOPSIS
    Creates a user account on a Nano server.

    .DESCRIPTION
    This function creates a user on the local machine running a Nano server.

    .PARAMETER Credential
    The credential containing the username and password to use to create the account.

    .PARAMETER Description
    The optional description to set on the user account.

    .PARAMETER ComputerName
    This parameter should not be used on NanoServer.
#>
function New-UserOnNanoServer
{

    param (
        [Parameter(Mandatory = $true)]
        [PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Credential,

        [string]
        $Description,

        [string]
        $ComputerName = $env:COMPUTERNAME
    )

    Set-StrictMode -Version Latest

    if ($PSBoundParameters.ContainsKey("ComputerName"))
    {
        if (-not (Test-IsLocalMachine -Scope $ComputerName))
        {
            throw "Do not specify the ComputerName arguments when running on NanoServer unless it is local machine."
        }
    }

    $userName = $Credential.UserName
    $securePassword = $Credential.GetNetworkCredential().SecurePassword

    # Remove user if it already exists.
    Remove-LocalUser -Name $userName -ErrorAction SilentlyContinue

    New-LocalUser -Name $userName -Password $securePassword

    if ($PSBoundParameters.ContainsKey("Description"))
    {
        Set-LocalUser -Name $userName -Description $Description
    }
}

<#
    .SYNOPSIS
    Removes a user account.

    .DESCRIPTION
    This function removes a local user from the local or remote machine.

    .PARAMETER UserName
    The name of the user to remove.

    .PARAMETER ComputerName
    The optional name of the computer to update. Omit to remove the user on the local machine.

    .NOTES
    For remote machines, the currently logged on user must have rights to remove a user.
#>
function Remove-User
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $UserName,

        [string]
        $ComputerName = $env:COMPUTERNAME
    )

    if (Test-IsNanoServer)
    {
        Remove-UserOnNanoServer @PSBoundParameters
    }
    else
    {
        Remove-UserOnFullSKU @PSBoundParameters
    }
}

<#
    .SYNOPSIS
    Removes a user account on a full server.

    .DESCRIPTION
    This function removes a local user from the local or remote machine running a full server.

    .PARAMETER UserName
    The name of the user to remove.

    .PARAMETER ComputerName
    The optional name of the computer to update. Omit to remove the user on the local machine.

    .NOTES
    For remote machines, the currently logged on user must have rights to remove a user.
#>
function Remove-UserOnFullSKU
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $UserName,

        [string]
        $ComputerName = $env:COMPUTERNAME
    )

    Set-StrictMode -Version Latest

    $adComputerEntry = [ADSI] "WinNT://$ComputerName"

    if ($adComputerEntry.Children | Where-Object Path -like "WinNT://*$ComputerName/$UserName")
    {
        $null = $adComputerEntry.Delete('user', $UserName)
    }
}

<#
    .SYNOPSIS
    Removes a local user account on a Nano server.

    .DESCRIPTION
    This function removes a local user from the local machine running a Nano Server.

    .PARAMETER UserName
    The name of the user to remove.

    .PARAMETER ComputerName
    This parameter should not be used on NanoServer.
#>
function Remove-UserOnNanoServer
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $UserName,

        [string]
        $ComputerName = $env:COMPUTERNAME
    )

    Set-StrictMode -Version Latest

    if ($PSBoundParameters.ContainsKey("ComputerName"))
    {
        if (-not (Test-IsLocalMachine -Scope $ComputerName))
        {
            throw "Do not specify the ComputerName arguments when running on NanoServer unless it is local machine."
        }
    }

    Remove-LocalUser -Name $UserName
}

<#
    .SYNOPSIS
    Determines if a user exists..

    .DESCRIPTION
    This function determines if a user exists on a local or remote machine running.

    .PARAMETER UserName
    The name of the user to test.

    .PARAMETER ComputerName
    The optional name of the computer to update.
#>
function Test-User
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $UserName,

        [string]
        $ComputerName = $env:COMPUTERNAME
    )

    if (Test-IsNanoServer)
    {
        Test-UserOnNanoServer @PSBoundParameters
    }
    else
    {
        Test-UserOnFullSKU @PSBoundParameters
    }
}

<#
    .SYNOPSIS
    Determines if a user exists on a full server.

    .DESCRIPTION
    This function determines if a user exists on a local or remote machine running a full server.

    .PARAMETER UserName
    The name of the user to test.

    .PARAMETER ComputerName
    The optional name of the computer to update.
#>
function Test-UserOnFullSKU
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $UserName,

        [string]
        $ComputerName = $env:COMPUTERNAME
    )

    Set-StrictMode -Version Latest

    $adComputerEntry = [ADSI] "WinNT://$ComputerName"
    if ($adComputerEntry.Children | Where-Object Path -like "WinNT://*$ComputerName/$UserName")
    {
        return $true
    }

    return $false
}

<#
    .SYNOPSIS
    Determines if a user exists on a Nano server.

    .DESCRIPTION
    This function determines if a user exists on a local or remote machine running a Nano server.

    .PARAMETER UserName
    The name of the user to test.

    .PARAMETER ComputerName
    This parameter should not be used on NanoServer.
#>
function Test-UserOnNanoServer
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $UserName,

        [string]
        $ComputerName = $env:COMPUTERNAME
    )

    if ($PSBoundParameters.ContainsKey("ComputerName"))
    {
        if (-not (Test-IsLocalMachine -Scope $ComputerName))
        {
            throw "Do not specify the ComputerName arguments when running on NanoServer unless it is local machine."
        }
    }

    # Try to find a group by its name.
    try
    {
        $null = Get-LocalUser -Name $UserName -ErrorAction Stop
        return $true
    }
    catch [System.Exception]
    {
        if ($_.CategoryInfo.ToString().Contains('UserNotFoundException'))
        {
            # A user with the provided name does not exist.
            return $false
        }
        throw $_.Exception
    }

    return $false

    Remove-LocalUser -Name $UserName
}

<#
    .SYNOPSIS
    Waits for a script block to return true.

    .PARAMETER ScriptBlock
    The ScriptBlock to wait. Should return a result of $true when complete.

    .PARAMETER TimeoutSeconds
    The number of seconds to wait for the ScriptBlock to return true.
#>
function Wait-ScriptBlockReturnTrue
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ScriptBlock]
        $ScriptBlock,

        [Int]
        $TimeoutSeconds = 5
    )

    $startTime = [DateTime]::Now

    $invokeScriptBlockResult = $false
    while (-not $invokeScriptBlockResult -and (([DateTime]::Now - $startTime).TotalSeconds -lt $TimeoutSeconds))
    {
        $invokeScriptBlockResult = $ScriptBlock.Invoke()
        Start-Sleep -Seconds 1
    }

    return $invokeScriptBlockResult
}

<#
    .SYNOPSIS
    Tests if a file is currently locked.

    .PARAMETER Path
    The path to the file to test.
#>
function Test-IsFileLocked
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $Path
    )

    if (-not (Test-Path $Path))
    {
        return $false
    }

    try
    {
        $content = Get-Content -Path $Path
        return $false
    }
    catch
    {
        return $true
    }
}

<#
    .SYNOPSIS
        Initializes a DSC Resource unit test.
#>
function Initialize-DscResourceUnitTest
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $DscResourceModuleName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $DscResourceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Unit', 'Integration')]
        [String]
        $TestType
    )

    if ((-not (Test-Path -Path "$PSScriptRoot\..\DSCResource.Tests")) -or (-not (Test-Path -Path "$PSScriptRoot\..\DSCResource.Tests\TestHelper.psm1")))
    {
        Push-Location "$PSScriptRoot\.."
        git clone https://github.com/PowerShell/DscResource.Tests.git --quiet
        Pop-Location
    }
    else
    {
        Push-Location "$PSScriptRoot\..\DSCResource.Tests"
        git pull origin master --quiet
        Pop-Location
    }

    Import-Module "$PSScriptRoot\..\DSCResource.Tests\TestHelper.psm1" -Force

    Initialize-TestEnvironment `
        -DSCModuleName $DscResourceModuleName `
        -DSCResourceName $DscResourceName `
        -TestType $TestType `
    | Out-Null
}

Export-ModuleMember -Function `
    Test-GetTargetResourceResult, `
    New-User, `
    Remove-User, `
    Test-User, `
    Wait-ScriptBlockReturnTrue, `
    Test-IsFileLocked, `
    Initialize-DscResourceUnitTest
