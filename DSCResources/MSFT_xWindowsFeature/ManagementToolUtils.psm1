
<#
    .SYNOPSIS
        Generates an ciminstance of MSFT_ServerManagerRequestGuid for use with cim Class MSFT_ServerManagerDeploymentTasks static methods
    
    .NOTES
        The code for this function has been sourced and translated from the Add-WindowsFeature cmdlet code.
        
        For more information about MSFT_ServerManagerRequestGuid please see:
            https://msdn.microsoft.com/en-us/library/hh872467(v=vs.85).aspx

    .PROPERTY Guid
        The guid to translate into MSFT_ServerManagerRequestGuid
#>
function New-MSFTServerManagerRequestGuid
{
    [CmdletBinding(SupportsShouldProcess = $false)]

    param(
        [Parameter()]
        [guid]
        $Guid
    )

    if ( -not $Guid )
    {
        $Guid = [guid]::NewGuid()
    }

    [byte[]] $byteArray = $Guid.ToByteArray()
    [uint64] $num1 = 0
    [uint64] $num2 = 0
    for ($index = $byteArray.Length / 2 - 1; $index -ge 0; --$index)
    {
        if ($index -lt 7)
        {
            $num1 = $num1 -shl 8
            $num2 = $num2 -shl 8
        }
        if( -not $num1 )
        {
            $num1 = [uint64] $byteArray[$index]
        }
        if( -not $num2 )
        {
            $num2 = [uint64] $byteArray[$index + 8]
        }
    }

    $ciminst = [ciminstance]::new("MSFT_ServerManagerRequestGuid", "root\Microsoft\Windows\ServerManager")
    $highHalfProp = [Microsoft.Management.Infrastructure.CimProperty]::Create("HighHalf", $num1, 0)
    $lowHalfProp = [Microsoft.Management.Infrastructure.CimProperty]::Create("LowHalf", $num2, 0)
    $ciminst.CimInstanceProperties.Add($highHalfProp)
    $ciminst.CimInstanceProperties.Add($lowHalfProp)

    return $ciminst
}

<#
    .SYNOPSIS
        Returns a list of Server Components and information relating to them.

    .NOTES
        A Server Component can be one of the following types:
            * 0 - Role
            * 1 - RoleService
            * 2 - Feature

        For more information on MSFT_ServerManagerServerComponent please see:
            https://msdn.microsoft.com/en-us/library/hh872469(v=vs.85).aspx

    .OUTPUTS
        root/Microsoft/Windows/ServerManager/MSFT_ServerManagerServerComponent[]
#>
function Get-ServerComponents
{
    [CmdletBinding(SupportsShouldProcess = $false)]
    param ()

    $cimParam = @{
        Namespace = "root\Microsoft\Windows\ServerManager"
        ClassName = "MSFT_ServerManagerDeploymentTasks"
        MethodName = "GetServerComponentsAsync"
        Arguments = @{
            RequestGuid = (New-MSFTServerManagerRequestGuid -guid ([guid]::NewGuid()))
        }
    }

    return (Invoke-CimMethod @cimParam).ItemValue
}

<#
    .SYNOPSIS
        Returns a list of WindowsFeature Management Tools

    .PROPERTY Name
        The name of the Windows Feature.

    .OUTPUTS
        string[]

    .EXAMPLE
        Get-WindowsFeatureManagementTool -Name 'AD-Domain-Services'
        
        Result:
            GPMC
            RSAT-AD-AdminCenter
            RSAT-ADDS-Tools
            
#>
function Get-WindowsFeatureManagementTool
{
    [CmdletBinding(SupportsShouldProcess = $false)]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    $serverComponents = Get-ServerComponents
    $optionalCompanions = $serverComponents.Where{$_.UniqueName -eq $Name}.OptionalCompanions
    return $serverComponents.Where{ $optionalCompanions.CompanionComponentName -contains $_.UniqueName }.UniqueName
}

Export-ModuleMember -Function 'Get-WindowsFeatureManagementTool'