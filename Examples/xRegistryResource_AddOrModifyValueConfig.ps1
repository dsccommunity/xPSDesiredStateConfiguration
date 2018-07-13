<#PSScriptInfo
.VERSION 1.0.1
.GUID ae26837c-a553-4d19-86d9-cea511b73c74
.AUTHOR Microsoft Corporation
.COMPANYNAME Microsoft Corporation
.COPYRIGHT
.TAGS DSCConfiguration
.LICENSEURI https://github.com/PowerShell/xPSDesiredStateConfiguration/blob/master/LICENSE
.PROJECTURI https://github.com/PowerShell/xPSDesiredStateConfiguration
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES First version.
.PRIVATEDATA 2016-Datacenter,2016-Datacenter-Server-Core
#>

#Requires -module @{ModuleName = 'xPSDesiredStateConfiguration';ModuleVersion = '8.2.0.0'}

<#
    .SYNOPSIS
        Configuration that creates a new registry key with a value.

    .DESCRIPTION
        Configuration that creates a new registry key with a value.

    .PARAMETER Path
        The path to the key in the registry that should be created or modified.

    .PARAMETER ValueName
        The name of the registry value to set. To modify or remove the default
        value of a registry key, specify this property as an empty string while
        also specifying ValueType or ValueData.

    .PARAMETER ValueData
        The data to set as the registry key value.

    .PARAMETER ValueType
        The type of the value to set. Defaults to 'String'.
        { String | Binary | DWord | QWord | MultiString | ExpandString }

    .PARAMETER Hex
        Specifies whether or not the value data should be expressed in hexadecimal format.
        If specified, DWORD/QWORD value data is presented in hexadecimal format.
        Not valid for other value types.
        The default value is $false.

    .PARAMETER OverwriteExisting
         Specifies whether or not to overwrite the with the new value if the
         registry key is already present.
         The default value is $false.

    .EXAMPLE
        xRegistryResource_AddOrModifyValueConfig -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -ValueName 'MyValue' -ValueType 'Binary' -ValueData @('0x00') -OverwriteExisting $true

        Compiles a configuration that creates a new registry value called MyValue under
        the parent key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'.

        If the registry key value MyValue under the key
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
        does not exist, then the key value is created with the Binary value 0, and
        will then make sure that the value always exist and have the correct
        value (make sure it is in desired state).

    .EXAMPLE
        $configurationParameters = @{
            Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
            ValueName = 'MyValue'
            ValueType = 'Binary'
            ValueData = @('0x00')
            OverwriteExisting = $true
        }
        Start-AzureRmAutomationDscCompilationJob -ResourceGroupName '<resource-group>' -AutomationAccountName '<automation-account>' -ConfigurationName 'xRegistryResource_AddOrModifyValueConfig' -Parameters $configurationParameters

        Compiles a configuration in Azure Automation that that creates a new
        registry value called MyValue under the parent key
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'.

        Replace the <resource-group> and <automation-account> with correct values.
#>
Configuration xRegistryResource_AddOrModifyValueConfig
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [System.String]
        $ValueName,

        [Parameter()]
        [System.String[]]
        $ValueData,

        [Parameter()]
        [ValidateSet('String', 'Binary', 'DWord', 'QWord', 'MultiString', 'ExpandString')]
        [System.String]
        $ValueType = 'String',

        [Parameter()]
        [System.Boolean]
        $HexValue,

        [Parameter()]
        [System.Boolean]
        $OverwriteExisting
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xRegistry 'AddOrModifyValue'
        {
            Key       = $Path
            Ensure    = 'Present'
            ValueName = $ValueName
            ValueType = $ValueType
            ValueData = $ValueData
            Force     = $OverwriteExisting
        }
    }
}
