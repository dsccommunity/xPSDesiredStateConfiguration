<#
    .SYNOPSIS
    Tests if the current machine is a Nano server.
#>
function Test-IsNanoServer {
    [OutputType([Boolean])]
    [CmdletBinding()]
    param ()

    return $PSVersionTable.PSEdition -ieq 'Core'
}

Export-ModuleMember -Function Test-IsNanoServer
