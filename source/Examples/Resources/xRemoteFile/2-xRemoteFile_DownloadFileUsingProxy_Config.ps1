<#PSScriptInfo
.VERSION 1.0.1
.GUID f57b22a3-b2bd-4fb5-9fa0-3997055d4577
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
        Configuration that downloads a file using proxy.

    .PARAMETER DestinationPath
        The path where the remote file should be downloaded

    .PARAMETER Uri
        The URI of the file which should be downloaded. It must be a HTTP, HTTPS
        or FILE resource.

    .PARAMETER UserAgent
        The user agent string for the web request.

    .PARAMETER Headers
        The headers of the web request.

    .PARAMETER Proxy
        The proxy server for the request, rather than connecting directly to the
        Internet resource. Should be the URI of a network proxy server (e.g
        'http://10.20.30.1').

    .EXAMPLE
        xRemoteFile_DownloadFileUsingProxy_Config -DestinationPath "$env:SystemDrive\fileName.jpg" -Uri 'http://www.contoso.com/image.jpg' -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer -Headers @{'Accept-Language' = 'en-US'} -Proxy 'http://10.22.93.1'

        Compiles a configuration that downloads the file 'http://www.contoso.com/image.jpg',
        using proxy 'http://10.22.93.1', to the local file "$env:SystemDrive\fileName.jpg".

    .EXAMPLE
        $configurationParameters = @{
            DestinationPath = "$env:SystemDrive\fileName.jpg"
            Uri = 'http://www.contoso.com/image.jpg'
            UserAgent = [Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer
            Headers = @{
                'Accept-Language' = 'en-US'
            }
            Proxy = 'http://10.22.93.1'
        }
        Start-AzureRmAutomationDscCompilationJob -ResourceGroupName '<resource-group>' -AutomationAccountName '<automation-account>' -ConfigurationName 'xRemoteFile_DownloadFileUsingProxyConfig' -Parameters $configurationParameters

        Compiles a configuration in Azure Automation that downloads the file
        'http://www.contoso.com/image.jpg', using proxy 'http://10.22.93.1', to
        the local file "$env:SystemDrive\fileName.jpg".

        Replace the <resource-group> and <automation-account> with correct values.
#>
configuration xRemoteFile_DownloadFileUsingProxy_Config
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

        [Parameter(Mandatory = $true)]
        [System.String]
        $Proxy
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xRemoteFile DownloadFileUsingProxy
        {
            DestinationPath = $DestinationPath
            Uri             = $Uri
            UserAgent       = $UserAgent
            Headers         = $Headers
            Proxy           = $Proxy
        }
    }
}
