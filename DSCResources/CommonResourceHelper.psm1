<#
    .SYNOPSIS
    Tests if the current machine is a Nano server.
#>
function Test-IsNanoServer
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param ()

    return $PSVersionTable.PSEdition -ieq 'Core'
}

<#
    .SYNOPSIS
        Creates and throws an invalid argument exception

    .PARAMETER Message
        The message explaining why this error is being thrown

    .PARAMETER ArgumentName
        The name of the invalid argument that is causing this error to be thrown
#>
function New-InvalidArgumentException
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Message,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ArgumentName
    )

    $argumentException = New-Object -TypeName 'ArgumentException' -ArgumentList @( $Message, $ArgumentName )
    $errorRecord = New-Object -TypeName 'System.Management.Automation.ErrorRecord' -ArgumentList @( $argumentException, $ArgumentName, 'InvalidArgument', $null)

    throw $errorRecord
}

<#
    .SYNOPSIS
        Creates and throws an invalid operation exception

    .PARAMETER Message
        The message explaining why this error is being thrown

    .PARAMETER ErrorRecord
        The error record containing the exception that is causing this terminating error
#>
function New-InvalidOperationException
{
    [CmdletBinding()]
    param
    (
        [ValidateNotNullOrEmpty()]
        [String]
        $Message,

        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    if ($null -eq $Message)
    {
        $invalidOperationException = New-Object -TypeName 'InvalidOperationException'
    }
    elseif ($null -eq $ErrorRecord)
    {
        $invalidOperationException = New-Object -TypeName 'InvalidOperationException' -ArgumentList @( $Message )
    }
    else
    {
        $invalidOperationException = New-Object -TypeName 'InvalidOperationException' -ArgumentList @( $Message, $ErrorRecord.Exception)
    }

    $errorRecordToThrow = New-Object -TypeName 'System.Management.Automation.ErrorRecord' -ArgumentList @( $invalidOperationException.ToString(), 'MachineStateIncorrect', 'InvalidOperation' ,$null)
    throw $errorRecordToThrow
}

<#
# The goal of this function is to get domain and username from PSCredential 
# without calling GetNetworkCredential() method. 
# Call to GetNetworkCredential() expose password as a plain text in memory.
#>
function Get-DomainAndUserName([PSCredential]$Credential)
{
    #
    # Supported formats: DOMAIN\username, username@domain
    #
    $wrongFormat = $false
    if ($Credential.UserName.Contains('\')) 
    {
        $segments = $Credential.UserName.Split('\')
        if ($segments.Length -gt 2)
        {
            # i.e. domain\user\foo
            $wrongFormat = $true
        } else {
            $Domain = $segments[0]
            $UserName = $segments[1]
        }
    } 
    elseif ($Credential.UserName.Contains('@')) 
    {
        $segments = $Credential.UserName.Split('@')
        if ($segments.Length -gt 2)
        {
            # i.e. user@domain@foo
            $wrongFormat = $true
        } else {
            $UserName = $segments[0]
            $Domain = $segments[1]
        }
    }
    else 
    {
        # support for default domain (localhost)
        return @( $env:COMPUTERNAME, $Credential.UserName )
    }

    if ($wrongFormat) 
    {
        $message = $LocalizedData.ErrorInvalidUserName -f $Credential.UserName
        Write-Verbose $message
        $exception = New-Object System.ArgumentException $message
        throw New-Object System.Management.Automation.ErrorRecord $exception, "InvalidUserName", InvalidArgument, $null  
    }

    return @( $Domain, $UserName )
}

Export-ModuleMember -Function `
    Test-IsNanoServer, `
    New-InvalidArgumentException, `
    New-InvalidOperationException
