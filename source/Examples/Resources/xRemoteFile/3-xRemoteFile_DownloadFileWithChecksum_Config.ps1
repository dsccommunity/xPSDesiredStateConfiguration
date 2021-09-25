<#PSScriptInfo
.VERSION 1.0.1
.GUID 21b028d8-f319-4430-9b35-ae1bf1b7075a
.AUTHOR Microsoft Corporation
.COMPANYNAME Microsoft Corporation
.COPYRIGHT
.TAGS DSCConfiguration
.LICENSEURI https://github.com/dsccommunity/xPSDesiredStateConfiguration/blob/main/LICENSE
.PROJECTURI https://github.com/dsccommunity/xPSDesiredStateConfiguration
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES First version.
.PRIVATEDATA 2016-Datacenter,2016-Datacenter-Server-Core
#>

#Requires -Module xPSDesiredStateConfiguration

<#
    .DESCRIPTION
        Configuration that downloads a file.

    .PARAMETER DestinationPath
        The path where the remote file should be downloaded

    .PARAMETER Uri
        The URI of the file which should be downloaded. It must be a HTTP, HTTPS
        or FILE resource.

    .PARAMETER UserAgent
        The user agent string for the web request.

    .PARAMETER Headers
        The headers of the web request.

    .PARAMETER Checksum
        Specifies the expected checksum value of downloaded file.

    .PARAMETER ChecksumType
        The algorithm used to calculate the checksum of the file.

    .EXAMPLE
        xRemoteFile_DownloadFileWithChecksum_Config -DestinationPath "$env:SystemDrive\fileName.jpg" -Uri 'http://www.contoso.com/image.jpg' -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer -Headers @{'Accept-Language' = 'en-US'} -ChecksumType MD5 -Checksum '31C1D431BBEB65E66113A8EBB06630DC'

        Compiles a configuration that downloads the file 'http://www.contoso.com/image.jpg'
        to the local file "$env:SystemDrive\fileName.jpg" and verifies the file against specified checksum.

    .EXAMPLE
        $configurationParameters = @{
            DestinationPath = "$env:SystemDrive\fileName.jpg"
            Uri = 'http://www.contoso.com/image.jpg'
            UserAgent = [Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer
            Headers = @{
                'Accept-Language' = 'en-US'
            }
            ChecksumType = 'MD5'
            Checksum = '31C1D431BBEB65E66113A8EBB06630DC'
        }
        Start-AzureRmAutomationDscCompilationJob -ResourceGroupName '<resource-group>' -AutomationAccountName '<automation-account>' -ConfigurationName 'xRemoteFile_DownloadFileWithChecksumConfig' -Parameters $configurationParameters

        Compiles a configuration in Azure Automation that downloads the file
        'http://www.contoso.com/image.jpg' to the local file
        "$env:SystemDrive\fileName.jpg" and verifies the file against specified checksum..

        Replace the <resource-group> and <automation-account> with correct values.
#>
Configuration xRemoteFile_DownloadFileWithChecksum_Config
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Uri,

        [Parameter()]
        [System.String]
        $UserAgent,

        [Parameter()]
        [System.Collections.Hashtable]
        $Headers,

        [Parameter()]
        [System.String]
        [ValidateSet('None', 'SHA1', 'SHA256', 'SHA384', 'SHA512', 'MACTripleDES', 'MD5', 'RIPEMD160')]
        $ChecksumType = 'None',

        [Parameter()]
        [System.String]
        $Checksum
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xRemoteFile DownloadFileWithChecksum
        {
            DestinationPath = $DestinationPath
            Uri             = $Uri
            UserAgent       = $UserAgent
            Headers         = $Headers
            ChecksumType    = $ChecksumType
            Checksum        = $checksum
        }
    }
}
