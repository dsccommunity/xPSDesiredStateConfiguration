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
        Tests that calling the Set-TargetResource cmdlet with the WhatIf parameter specified produces output that contains all the given expected output.
        If empty or null expected output is specified, this cmdlet will check that there was no output from Set-TargetResource with WhatIf specified.
        Uses Pester.

    .PARAMETER Parameters
        The parameters to pass to Set-TargetResource.
        These parameters do not need to contain that WhatIf parameter, but if they do, 
        this function will run Set-TargetResource with WhatIf = $true no matter what is in the Parameters Hashtable.

    .PARAMETER ExpectedOutput
        The output expected to be in the output from running WhatIf with the Set-TargetResource cmdlet.
        If this parameter is empty or null, this cmdlet will check that there was no output from Set-TargetResource with WhatIf specified.    
#>
function Test-SetTargetResourceWithWhatIf
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [Hashtable]
        $Parameters,
     
        [String[]]
        $ExpectedOutput
    )

    $transcriptPath = Join-Path -Path (Get-Location) -ChildPath 'WhatIfTestTranscript.txt'
    if (Test-Path -Path $transcriptPath)
    {
        Wait-ScriptBlockReturnTrue -ScriptBlock {-not (Test-IsFileLocked -Path $transcriptPath)} -TimeoutSeconds 10
        Remove-Item -Path $transcriptPath -Force
    }

    $Parameters['WhatIf'] = $true

    try
    {
        Wait-ScriptBlockReturnTrue -ScriptBlock {-not (Test-IsFileLocked -Path $transcriptPath)}

        Start-Transcript -Path $transcriptPath
        Set-TargetResource @Parameters
        Stop-Transcript

        Wait-ScriptBlockReturnTrue -ScriptBlock {-not (Test-IsFileLocked -Path $transcriptPath)}

        $transcriptContent = Get-Content -Path $transcriptPath -Raw
        $transcriptContent | Should Not Be $null

        $regexString = '\*+[^\*]*\*+'

        # Removing transcript diagnostic logging at top and bottom of file
        $selectedString = Select-String -InputObject $transcriptContent -Pattern $regexString -AllMatches

        foreach ($match in $selectedString.Matches)
        {
            $transcriptContent = $transcriptContent.Replace($match.Captures, '')
        }

        $transcriptContent = $transcriptContent.Replace("`r`n", "").Replace("`n", "")

        if ($null -eq $ExpectedOutput -or $ExpectedOutput.Count -eq 0)
        {
            [String]::IsNullOrEmpty($transcriptContent) | Should Be $true
        }
        else
        {
            foreach ($expectedOutputPiece in $ExpectedOutput)
            {
                $transcriptContent.Contains($expectedOutputPiece) | Should Be $true
            }
        }
    }
    finally
    {
        if (Test-Path -Path $transcriptPath)
        {
            Wait-ScriptBlockReturnTrue -ScriptBlock {-not (Test-IsFileLocked -Path $transcriptPath)} -TimeoutSeconds 10
            Remove-Item -Path $transcriptPath -Force
        }
    }
}

<#
    .SYNOPSIS
        Enters a DSC Resource test environment.

    .PARAMETER DscResourceModuleName
        The name of the module that contains the DSC Resource to test.

    .PARAMETER DscResourceName
        The name of the DSC resource to test.

    .PARAMETER TestType
        Specifies whether the test environment will run a Unit test or an Integration test.
#>
function Enter-DscResourceTestEnvironment
{
    [OutputType([PSObject])]
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
        $gitInstalled = $null -ne (Get-Command -Name 'git' -ErrorAction 'SilentlyContinue')

        if ($gitInstalled)
        {
            Push-Location "$PSScriptRoot\..\DSCResource.Tests"
            git pull origin master --quiet
            Pop-Location
        }
        else
        {
            Write-Verbose -Message "Git not installed. Leaving current DSCResource.Tests as is."
        }
    }

    Import-Module "$PSScriptRoot\..\DSCResource.Tests\TestHelper.psm1"

    return Initialize-TestEnvironment `
        -DSCModuleName $DscResourceModuleName `
        -DSCResourceName $DscResourceName `
        -TestType $TestType
}

<#
    .SYNOPSIS
        Exits the specified DSC Resource test environment.

    .PARAMETER TestEnvironment
        The test environment to exit.
#>
function Exit-DscResourceTestEnvironment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$TestEnvironment
    )

    Import-Module "$PSScriptRoot\..\DSCResource.Tests\TestHelper.psm1"

    Restore-TestEnvironment -TestEnvironment $TestEnvironment
}

Export-ModuleMember -Function `
    Test-GetTargetResourceResult, `
    New-User, `
    Remove-User, `
    Test-User, `
    Wait-ScriptBlockReturnTrue, `
    Test-IsFileLocked, `
    Test-SetTargetResourceWithWhatIf, `
    Enter-DscResourceTestEnvironment, `
    Exit-DscResourceTestEnvironment
