<#
    .SYNOPSIS
    Creates a service binary file.

    .PARAMETER ServiceName
    The name of the service to create the binary file for.

    .PARAMETER ServiceCodePath
    The path to the code for the service to create the binary file for.

    .PARAMETER ServiceDisplayName
    The display name of the service to create the binary file for.

    .PARAMETER ServiceDescription
    The description of the service to create the binary file for.

    .PARAMETER ServiceDependsOn
    Dependencies of the service to create the binary file for.

    .PARAMETER ServiceExecutablePath
    The path to write the service executable to.
#>
function New-ServiceBinary
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $ServiceName,

        [Parameter(Mandatory = $true)]
        [String]
        $ServiceCodePath,

        [Parameter(Mandatory = $true)]
        [String]
        $ServiceDisplayName,

        [Parameter(Mandatory = $true)]
        [String]
        $ServiceDescription,

        [Parameter(Mandatory = $true)]
        [String]
        $ServiceDependsOn,

        [Parameter(Mandatory = $true)]
        [String]
        $ServiceExecutablePath
    )

    if (Get-Service $ServiceName -ErrorAction Ignore)
    {
        Stop-Service $ServiceName -ErrorAction SilentlyContinue
        Remove-TestService -ServiceName $ServiceName -ServiceExecutablePath $ServiceExecutablePath
    }

    $fileText = Get-Content $ServiceCodePath -Raw
    $fileText = $fileText.Replace("TestServiceReplacementName", $ServiceName)
    $fileText = $fileText.Replace("TestServiceReplacementDisplayName", $ServiceDisplayName)
    $fileText = $fileText.Replace("TestServiceReplacementDescription", $ServiceDescription)
    $fileText = $fileText.Replace("TestServiceReplacementDependsOn", $ServiceDependsOn)
    Add-Type $fileText -OutputAssembly $ServiceExecutablePath -OutputType WindowsApplication -ReferencedAssemblies "System.ServiceProcess", "System.Configuration.Install"
}

<#
    .SYNOPSIS
    Retrieves the path to the install utility.
#>
function Get-InstallUtilPath
{
    [CmdletBinding()]
    param ()

    if ($env:Processor_Architecture -ieq 'amd64')
    {
        $frameworkName = "Framework64"
    }
    else
    {
        $frameworkName = "Framework"
    }

    return Join-Path (Resolve-Path "$env:WinDir\Microsoft.Net\$frameworkName\v4*") "installUtil.exe"
}

<#
    .SYNOPSIS
    Removes a service.

    .PARAMETER ServiceName
    The name of the service to remove.

    .PARAMETER ServiceExecutablePath
    The path to the executable of the service to remove.
#>
function Remove-TestService
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $ServiceName,

        [Parameter(Mandatory = $true)]
        [String]
        $ServiceExecutablePath
    )

    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)
    {
        $installUtility = Get-InstallUtilPath
        & $installUtility /u $ServiceExecutablePath
    }

    Remove-Item $ServiceExecutablePath -Force -ErrorAction SilentlyContinue
    Remove-Item *.InstallLog -Force -ErrorAction SilentlyContinue
    Remove-Item $ServiceName -Force -Recurse -ErrorAction SilentlyContinue
}

Export-ModuleMember -Function `
    New-ServiceBinary, `
    Remove-TestService
