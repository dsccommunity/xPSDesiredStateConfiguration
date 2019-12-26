$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

$modulePath = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'Modules'

# Import the Networking Resource Helper Module
Import-Module -Name (Join-Path -Path $modulePath `
    -ChildPath (Join-Path -Path 'xPSDesiredStateConfiguration.Common' `
        -ChildPath 'xPSDesiredStateConfiguration.Common.psm1'))

# Import Localization Strings
$script:localizedData = Get-LocalizedData -ResourceName 'DSC_xDSCWebService'

<#
    .SYNOPSIS
        Get the state of the DSC Web Service.

    .PARAMETER EndpointName
        Prefix of the WCF SVC file.

    .PARAMETER ApplicationPoolName
        The IIS ApplicationPool to use for the Pull Server. If not specified a
        pool with name 'PSWS' will be created.

    .PARAMETER CertificateSubject
        The subject of the Certificate in CERT:\LocalMachine\MY\ for Pull Server.

    .PARAMETER CertificateTemplateName
        The certificate Template Name of the Certificate in CERT:\LocalMachine\MY\
        for Pull Server.

    .PARAMETER CertificateThumbPrint
        The thumbprint of the Certificate in CERT:\LocalMachine\MY\ for Pull Server.

    .PARAMETER ConfigureFirewall
        Enable incomming firewall exceptions for the configured DSC Pull Server
        port. Defaults to true.

    .PARAMETER DisableSecurityBestPractices
        A list of exceptions to the security best practices to apply.

    .PARAMETER Enable32BitAppOnWin64
        Enable the DSC Pull Server to run in a 32-bit process on a 64-bit operating
        system.

    .PARAMETER UseSecurityBestPractices
        Ensure that the DSC Pull Server is created using security best practices.
#>
function Get-TargetResource
{
    [CmdletBinding(DefaultParameterSetName = 'CertificateThumbPrint')]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $EndpointName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ApplicationPoolName = $DscWebServiceDefaultAppPoolName,

        [Parameter(ParameterSetName = 'CertificateSubject')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CertificateSubject,

        [Parameter(ParameterSetName = 'CertificateSubject')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CertificateTemplateName = 'WebServer',

        [Parameter(ParameterSetName = 'CertificateThumbPrint')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CertificateThumbPrint,

        [Parameter()]
        [System.Boolean]
        $ConfigureFirewall = $true,

        [Parameter()]
        [ValidateSet('SecureTLSProtocols')]
        [System.String[]]
        $DisableSecurityBestPractices,

        [Parameter()]
        [System.Boolean]
        $Enable32BitAppOnWin64 = $false,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Boolean]
        $UseSecurityBestPractices
    )

    <#
        If Certificate Subject is not specified then a value for
        CertificateThumbprint must be explicitly set instead. The
        Mof schema doesn't allow for a mandatory parameter in a parameter set.
    #>
    if ($PScmdlet.ParameterSetName -eq 'CertificateThumbPrint' `
        -and $PSBoundParameters.ContainsKey('CertificateThumbPrint') -ne $true)
    {
        throw $script:localizedData.ThrowCertificateThumbprint
    }

    $webSite = Get-Website -Name $EndpointName

    if ($webSite)
    {
        Write-Verbose -Message "PullServer is deployed at '$EndpointName'."

        $Ensure = 'Present'
        $acceptSelfSignedCertificates = $false

        # Get Full Path for Web.config file
        $webConfigFullPath = Join-Path -Path $website.physicalPath -ChildPath 'web.config'

        # Get module and configuration path
        $modulePath = Get-WebConfigAppSetting -WebConfigFullPath $webConfigFullPath -AppSettingName 'ModulePath'
        $configurationPath = Get-WebConfigAppSetting -WebConfigFullPath $webConfigFullPath -AppSettingName 'ConfigurationPath'
        $registrationKeyPath = Get-WebConfigAppSetting -WebConfigFullPath $webConfigFullPath -AppSettingName 'RegistrationKeyPath'

        # Get database path
        switch ((Get-WebConfigAppSetting -WebConfigFullPath $webConfigFullPath -AppSettingName 'dbprovider'))
        {
            'ESENT'
            {
                $databasePath = Get-WebConfigAppSetting -WebConfigFullPath $webConfigFullPath -AppSettingName 'dbconnectionstr' | Split-Path -Parent
            }

            'System.Data.OleDb'
            {
                $connectionString = Get-WebConfigAppSetting -WebConfigFullPath $webConfigFullPath -AppSettingName 'dbconnectionstr'
                if ($connectionString -match 'Data Source=(.*)\\Devices\.mdb')
                {
                    $databasePath = $Matches[0]
                }
                else
                {
                    $databasePath = $connectionString
                }
            }
        }

        $urlPrefix = $website.bindings.Collection[0].protocol + '://'

        $ipProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()

        if ($ipProperties.DomainName)
        {
            $fqdn = '{0}.{1}' -f $ipProperties.HostName, $ipProperties.DomainName
        }
        else
        {
            $fqdn = $ipProperties.HostName
        }

        $iisPort = $website.bindings.Collection[0].bindingInformation.Split(':')[1]

        $svcFileName = (Get-ChildItem -Path $website.physicalPath -Filter '*.svc').Name

        $serverUrl = $urlPrefix + $fqdn + ':' + $iisPort + '/' + $svcFileName

        $webBinding = Get-WebBinding -Name $EndpointName

        if ((Test-IISSelfSignedModuleEnabled -EndpointName $EndpointName))
        {
            $acceptSelfSignedCertificates = $true
        }

        $ConfigureFirewall = Test-PullServerFirewallConfiguration -Port $iisPort
        $ApplicationPoolName = $webSite.applicationPool
    }
    else
    {
        Write-Verbose -Message "No website found with name '$EndpointName'."
        $Ensure = 'Absent'
    }

    $output = @{
        EndpointName                 = $EndpointName
        ApplicationPoolName          = $ApplicationPoolName
        Port                         = $iisPort
        PhysicalPath                 = $website.physicalPath
        State                        = $webSite.state
        DatabasePath                 = $databasePath
        ModulePath                   = $modulePath
        ConfigurationPath            = $configurationPath
        DSCServerUrl                 = $serverUrl
        Ensure                       = $Ensure
        RegistrationKeyPath          = $registrationKeyPath
        AcceptSelfSignedCertificates = $acceptSelfSignedCertificates
        UseSecurityBestPractices     = $UseSecurityBestPractices
        DisableSecurityBestPractices = $DisableSecurityBestPractices
        Enable32BitAppOnWin64        = $Enable32BitAppOnWin64
        ConfigureFirewall            = $ConfigureFirewall
    }

    if ($CertificateThumbPrint -eq 'AllowUnencryptedTraffic')
    {
        Write-Verbose -Message 'Current PullServer configuration allows unencrypted traffic.'
        $output.Add('CertificateThumbPrint', $certificateThumbPrint)
    }
    else
    {
        $certificate = ([System.Array] (Get-ChildItem -Path 'Cert:\LocalMachine\My\')) |
            Where-Object -FilterScript {
                $_.Thumbprint -eq $webBinding.CertificateHash
            }

        # Try to parse the Certificate Template Name. The property is not available on all Certificates.
        $actualCertificateTemplateName = ''
        $certificateTemplateProperty = $certificate.Extensions | Where-Object -FilterScript {
            $_.Oid.FriendlyName -eq 'Certificate Template Name'
        }

        if ($null -ne $certificateTemplateProperty)
        {
            $actualCertificateTemplateName = $certificateTemplateProperty.Format($false)
        }

        $output.Add('CertificateThumbPrint', $webBinding.CertificateHash)
        $output.Add('CertificateSubject', $certificate.Subject)
        $output.Add('CertificateTemplateName', $actualCertificateTemplateName)
    }

    return $output
}

<#
    .SYNOPSIS
        Set the state of the DSC Web Service.

    .PARAMETER EndpointName
        Prefix of the WCF SVC file.

    .PARAMETER AcceptSelfSignedCertificates
        Specifies is self-signed certs will be accepted for client authentication.

    .PARAMETER ApplicationPoolName
        The IIS ApplicationPool to use for the Pull Server. If not specified a
        pool with name 'PSWS' will be created.

    .PARAMETER CertificateSubject
        The subject of the Certificate in CERT:\LocalMachine\MY\ for Pull Server.

    .PARAMETER CertificateTemplateName
        The certificate Template Name of the Certificate in CERT:\LocalMachine\MY\
        for Pull Server.

    .PARAMETER CertificateThumbPrint
        The thumbprint of the Certificate in CERT:\LocalMachine\MY\ for Pull Server.

    .PARAMETER ConfigurationPath
        The location on the disk where the Configuration is stored.

    .PARAMETER ConfigureFirewall
        Enable incomming firewall exceptions for the configured DSC Pull Server
        port. Defaults to true.

    .PARAMETER DatabasePath
        The location on the disk where the database is stored.

    .PARAMETER DisableSecurityBestPractices
        A list of exceptions to the security best practices to apply.

    .PARAMETER Enable32BitAppOnWin64
        Enable the DSC Pull Server to run in a 32-bit process on a 64-bit operating
        system.

    .PARAMETER Ensure
        Specifies if the DSC Web Service should be installed.

    .PARAMETER PhysicalPath
        The physical path for the IIS Endpoint on the machine (usually under inetpub).

    .PARAMETER Port
        The port number of the DSC Pull Server IIS Endpoint.

    .PARAMETER ModulePath
        The location on the disk where the Modules are stored.

    .PARAMETER RegistrationKeyPath
        The location on the disk where the RegistrationKeys file is stored.

    .PARAMETER SqlConnectionString
        The connection string to use to connect to the SQL server backend database.
        Required if SqlProvider is true.

    .PARAMETER SqlProvider
        Enable DSC Pull Server to use SQL server as the backend database.

    .PARAMETER State
        Specifies the state of the DSC Web Service.

    .PARAMETER UseSecurityBestPractices
        Ensure that the DSC Pull Server is created using security best practices.
#>
function Set-TargetResource
{
    [CmdletBinding(DefaultParameterSetName = 'CertificateThumbPrint')]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $EndpointName,

        [Parameter()]
        [System.Boolean]
        $AcceptSelfSignedCertificates = $true,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ApplicationPoolName = $DscWebServiceDefaultAppPoolName,

        [Parameter(ParameterSetName = 'CertificateSubject')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CertificateSubject,

        [Parameter(ParameterSetName = 'CertificateSubject')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CertificateTemplateName = 'WebServer',

        [Parameter(ParameterSetName = 'CertificateThumbPrint')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CertificateThumbPrint,

        [Parameter()]
        [System.String]
        $ConfigurationPath = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration",

        [Parameter()]
        [System.Boolean]
        $ConfigureFirewall = $true,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DatabasePath = "$env:PROGRAMFILES\WindowsPowerShell\DscService",

        [Parameter()]
        [ValidateSet('SecureTLSProtocols')]
        [System.String[]]
        $DisableSecurityBestPractices,

        [Parameter()]
        [System.Boolean]
        $Enable32BitAppOnWin64 = $false,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.String]
        $ModulePath = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules",

        [Parameter()]
        [System.String]
        $PhysicalPath = "$env:SystemDrive\inetpub\$EndpointName",

        [Parameter()]
        [ValidateRange(1, 65535)]
        [System.UInt32]
        $Port = 8080,

        [Parameter()]
        [System.String]
        $RegistrationKeyPath = "$env:PROGRAMFILES\WindowsPowerShell\DscService",

        [Parameter()]
        [System.String]
        $SqlConnectionString,

        [Parameter()]
        [System.Boolean]
        $SqlProvider = $false,

        [Parameter()]
        [ValidateSet('Started', 'Stopped')]
        [System.String]
        $State = 'Started',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Boolean]
        $UseSecurityBestPractices
    )

    <#
        If Certificate Subject is not specified then a value for CertificateThumbprint
        must be explicitly set instead. The Mof schema doesn't allow for a mandatory parameter
        in a parameter set.
    #>
    if ($PScmdlet.ParameterSetName -eq 'CertificateThumbPrint' -and $PSBoundParameters.ContainsKey('CertificateThumbPrint') -ne $true)
    {
        throw $script:localizedData.ThrowCertificateThumbprint
    }

    # Find a certificate that matches the Subject and Template Name
    if ($PSCmdlet.ParameterSetName -eq 'CertificateSubject')
    {
        $certificateThumbPrint = Find-CertificateThumbprintWithSubjectAndTemplateName -Subject $CertificateSubject -TemplateName $CertificateTemplateName
    }

    # Check parameter values
    if ($UseSecurityBestPractices -and ($CertificateThumbPrint -eq 'AllowUnencryptedTraffic'))
    {
        throw $script:localizedData.ThrowUseSecurityBestPractice
    }

    if ($ConfigureFirewall)
    {
        Write-Warning -Message $script:localizedData.ConfigFirewallDeprecated
    }

    <#
        If the Pull Server Site should be bound to the non default AppPool
        ensure that the AppPool already exists
    #>
    if ('Present' -eq $Ensure `
            -and $ApplicationPoolName -ne $DscWebServiceDefaultAppPoolName `
            -and (-not (Test-Path -Path "IIS:\AppPools\$ApplicationPoolName")))
    {
        throw ($script:localizedData.ThrowApplicationPoolNotFound -f $ApplicationPoolName)
    }

    # Initialize with default values
    $pathPullServer = "$pshome\modules\PSDesiredStateConfiguration\PullServer"
    $jet4provider = 'System.Data.OleDb'
    $jet4database = 'Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$DatabasePath\Devices.mdb;'
    $eseprovider = 'ESENT'
    $esedatabase = "$DatabasePath\Devices.edb"

    $cultureInfo = Get-Culture
    $languagePath = $cultureInfo.IetfLanguageTag
    $language = $cultureInfo.TwoLetterISOLanguageName

    # The two letter iso languagename is not actually implemented in the source path, it's always 'en'
    if (-not (Test-Path -Path "$pathPullServer\$languagePath\Microsoft.Powershell.DesiredStateConfiguration.Service.Resources.dll"))
    {
        $languagePath = 'en'
    }

    $os = Get-OSVersion

    $isBlue = $false

    if ($os.Major -eq 6 -and $os.Minor -eq 3)
    {
        $isBlue = $true
    }

    $isDownlevelOfBlue = $false

    if ($os.Major -eq 6 -and $os.Minor -lt 3)
    {
        $isDownlevelOfBlue = $true
    }

    # Use Pull Server values for defaults
    $webConfigFileName = "$pathPullServer\PSDSCPullServer.config"
    $svcFileName = "$pathPullServer\PSDSCPullServer.svc"
    $pswsMofFileName = "$pathPullServer\PSDSCPullServer.mof"
    $pswsDispatchFileName = "$pathPullServer\PSDSCPullServer.xml"

    if (($Ensure -eq 'Absent'))
    {
        if (Test-Path -LiteralPath "IIS:\Sites\$EndpointName")
        {
            # Get the port number for the Firewall rule
            Write-Verbose -Message "Processing bindings for '$EndpointName'."
            $portList = Get-WebBinding -Name $EndpointName | ForEach-Object -Process {
                [System.Text.RegularExpressions.Regex]::Match($_.bindingInformation, ':(\d+):').Groups[1].Value
            }

            # There is a web site, but there shouldn't be one
            Write-Verbose -Message "Removing web site '$EndpointName'."
            Remove-PSWSEndpoint -SiteName $EndpointName

            $portList | ForEach-Object -Process { Remove-PullServerFirewallConfiguration -Port $_ }
        }

        # We are done here, all stuff below is for 'Present'
        return
    }

    Write-Verbose -Message 'Create the IIS endpoint'
    New-PSWSEndpoint `
        -site $EndpointName `
        -Path $PhysicalPath `
        -cfgfile $webConfigFileName `
        -port $Port `
        -appPool $ApplicationPoolName `
        -applicationPoolIdentityType LocalSystem `
        -app $EndpointName `
        -svc $svcFileName `
        -mof $pswsMofFileName `
        -dispatch $pswsDispatchFileName `
        -asax "$pathPullServer\Global.asax" `
        -dependentBinaries  "$pathPullServer\Microsoft.Powershell.DesiredStateConfiguration.Service.dll" `
        -language $language `
        -dependentMUIFiles  "$pathPullServer\$languagePath\Microsoft.Powershell.DesiredStateConfiguration.Service.Resources.dll" `
        -certificateThumbPrint $certificateThumbPrint `
        -Enable32BitAppOnWin64 $Enable32BitAppOnWin64 `

    switch ($Ensure)
    {
        'Present'
        {
            if ($ConfigureFirewall)
            {
                Write-Verbose -Message "Enabling firewall exception for port $port."
                Add-PullServerFirewallConfiguration -Port $port
            }
        }

        'Absent'
        {
            Write-Verbose -Message "Disabling firewall exception for port $port."
            Remove-PullServerFirewallConfiguration -Port $port
        }
    }

    Update-LocationTagInApplicationHostConfigForAuthentication -WebSite $EndpointName -Authentication 'anonymous'
    Update-LocationTagInApplicationHostConfigForAuthentication -WebSite $EndpointName -Authentication 'basic'
    Update-LocationTagInApplicationHostConfigForAuthentication -WebSite $EndpointName -Authentication 'windows'

    if ($SqlProvider)
    {
        Write-Verbose -Message 'Set values into the web.config that define the SQL Connection'
        Set-AppSettingsInWebconfig -Path $PhysicalPath -Key 'dbprovider' -Value $jet4provider
        Set-AppSettingsInWebconfig -Path $PhysicalPath -Key 'dbconnectionstr' -Value $SqlConnectionString

        if ($isBlue)
        {
            Set-BindingRedirectSettingInWebConfig -Path $PhysicalPath
        }
    }
    elseif ($isBlue)
    {
        Write-Verbose -Message 'Set values into the web.config that define the repository for BLUE OS'
        Set-AppSettingsInWebconfig -Path $PhysicalPath -Key 'dbprovider' -Value $eseprovider
        Set-AppSettingsInWebconfig -Path $PhysicalPath -Key 'dbconnectionstr' -Value $esedatabase

        Set-BindingRedirectSettingInWebConfig -Path $PhysicalPath
    }
    else
    {
        if ($isDownlevelOfBlue)
        {
            Write-Verbose -Message 'Set values into the web.config that define the repository for non-BLUE Downlevel OS'
            $repository = Join-Path -Path $DatabasePath -ChildPath 'Devices.mdb'
            Copy-Item -Path "$pathPullServer\Devices.mdb" -Destination $repository -Force

            Set-AppSettingsInWebconfig -Path $PhysicalPath -Key 'dbprovider' -Value $jet4provider
            Set-AppSettingsInWebconfig -Path $PhysicalPath -Key 'dbconnectionstr' -Value $jet4database
        }
        else
        {
            Write-Verbose -Message 'Set values into the web.config that define the repository later than BLUE OS'
            Write-Verbose -Message 'Only ESENT is supported on Windows Server 2016'

            Set-AppSettingsInWebconfig -Path $PhysicalPath -Key 'dbprovider' -Value $eseprovider
            Set-AppSettingsInWebconfig -Path $PhysicalPath -Key 'dbconnectionstr' -Value $esedatabase
        }
    }

    Write-Verbose -Message 'Pull Server: Set values into the web.config that indicate the location of repository, configuration, modules'

    # Create the application data directory calculated above
    $null = New-Item -Path $DatabasePath -ItemType 'directory' -Force
    $null = New-Item -Path $ConfigurationPath -ItemType 'directory' -Force

    Set-AppSettingsInWebconfig -Path $PhysicalPath -Key 'ConfigurationPath' -Value $configurationPath

    $null = New-Item -Path $ModulePath -ItemType 'directory' -Force

    Set-AppSettingsInWebconfig -Path $PhysicalPath -Key 'ModulePath' -Value $ModulePath

    $null = New-Item -Path $RegistrationKeyPath -ItemType 'directory' -Force

    Set-AppSettingsInWebconfig -Path $PhysicalPath -Key 'RegistrationKeyPath' -Value $registrationKeyPath

    if ($AcceptSelfSignedCertificates)
    {
        Write-Verbose -Message 'Accepting self signed certificates from incoming hosts'
        Enable-IISSelfSignedModule -EndpointName $EndpointName -Enable32BitAppOnWin64:$Enable32BitAppOnWin64
    }
    else
    {
        Disable-IISSelfSignedModule -EndpointName $EndpointName
    }

    if ($UseSecurityBestPractices)
    {
        UseSecurityBestPractices\Set-UseSecurityBestPractice -DisableSecurityBestPractices $DisableSecurityBestPractices
    }
}

<#
    .SYNOPSIS
        Test the state of the DSC Web Service.

    .PARAMETER EndpointName
        Prefix of the WCF SVC file.

    .PARAMETER AcceptSelfSignedCertificates
        Specifies is self-signed certs will be accepted for client authentication.

    .PARAMETER ApplicationPoolName
        The IIS ApplicationPool to use for the Pull Server. If not specified a
        pool with name 'PSWS' will be created.

    .PARAMETER CertificateSubject
        The subject of the Certificate in CERT:\LocalMachine\MY\ for Pull Server.

    .PARAMETER CertificateTemplateName
        The certificate Template Name of the Certificate in CERT:\LocalMachine\MY\
        for Pull Server.

    .PARAMETER CertificateThumbPrint
        The thumbprint of the Certificate in CERT:\LocalMachine\MY\ for Pull Server.

    .PARAMETER ConfigurationPath
        The location on the disk where the Configuration is stored.

    .PARAMETER ConfigureFirewall
        Enable incomming firewall exceptions for the configured DSC Pull Server
        port. Defaults to true.

    .PARAMETER DatabasePath
        The location on the disk where the database is stored.

    .PARAMETER DisableSecurityBestPractices
        A list of exceptions to the security best practices to apply.

    .PARAMETER Enable32BitAppOnWin64
        Enable the DSC Pull Server to run in a 32-bit process on a 64-bit operating
        system.

    .PARAMETER Ensure
        Specifies if the DSC Web Service should be installed.

    .PARAMETER PhysicalPath
        The physical path for the IIS Endpoint on the machine (usually under inetpub).

    .PARAMETER Port
        The port number of the DSC Pull Server IIS Endpoint.

    .PARAMETER ModulePath
        The location on the disk where the Modules are stored.

    .PARAMETER RegistrationKeyPath
        The location on the disk where the RegistrationKeys file is stored.

    .PARAMETER SqlConnectionString
        The connection string to use to connect to the SQL server backend database.
        Required if SqlProvider is true.

    .PARAMETER SqlProvider
        Enable DSC Pull Server to use SQL server as the backend database.

    .PARAMETER State
        Specifies the state of the DSC Web Service.

    .PARAMETER UseSecurityBestPractices
        Ensure that the DSC Pull Server is created using security best practices.
#>
function Test-TargetResource
{
    [CmdletBinding(DefaultParameterSetName = 'CertificateThumbPrint')]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $EndpointName,

        [Parameter()]
        [System.Boolean]
        $AcceptSelfSignedCertificates,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ApplicationPoolName = $DscWebServiceDefaultAppPoolName,

        [Parameter(ParameterSetName = 'CertificateSubject')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CertificateSubject,

        [Parameter(ParameterSetName = 'CertificateSubject')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CertificateTemplateName = 'WebServer',

        [Parameter(ParameterSetName = 'CertificateThumbPrint')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CertificateThumbPrint,

        [Parameter()]
        [System.String]
        $ConfigurationPath = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration",

        [Parameter()]
        [System.Boolean]
        $ConfigureFirewall = $true,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DatabasePath = "$env:PROGRAMFILES\WindowsPowerShell\DscService",

        [Parameter()]
        [ValidateSet('SecureTLSProtocols')]
        [System.String[]]
        $DisableSecurityBestPractices,

        [Parameter()]
        [System.Boolean]
        $Enable32BitAppOnWin64 = $false,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.String]
        $ModulePath = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules",

        [Parameter()]
        [System.String]
        $PhysicalPath = "$env:SystemDrive\inetpub\$EndpointName",

        [Parameter()]
        [ValidateRange(1, 65535)]
        [System.UInt32]
        $Port = 8080,

        [Parameter()]
        [System.String]
        $RegistrationKeyPath,

        [Parameter()]
        [System.String]
        $SqlConnectionString,

        [Parameter()]
        [System.Boolean]
        $SqlProvider = $false,

        [Parameter()]
        [ValidateSet('Started', 'Stopped')]
        [System.String]
        $State = 'Started',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Boolean]
        $UseSecurityBestPractices
    )

    <#
        If Certificate Subject is not specified then a value for CertificateThumbprint
        must be explicitly set instead. The Mof schema doesn't allow for a mandatory
        parameter in a parameter set.
    #>
    if ($PScmdlet.ParameterSetName -eq 'CertificateThumbPrint' -and $PSBoundParameters.ContainsKey('CertificateThumbPrint') -ne $true)
    {
        throw $script:localizedData.ThrowCertificateThumbprint
    }

    $desiredConfigurationMatch = $true

    $website = Get-Website -Name $EndpointName
    $stop = $true

    :WebSiteTests do
    {
        Write-Verbose -Message 'Check Ensure.'

        if (($Ensure -eq 'Present' -and $null -eq $website))
        {
            $desiredConfigurationMatch = $false
            Write-Verbose -Message "The Website '$EndpointName' is not present."
            break
        }

        if (($Ensure -eq 'Absent' -and $null -ne $website))
        {
            $desiredConfigurationMatch = $false
            Write-Verbose -Message "The Website '$EndpointName' is present but should not be."
            break
        }

        if (($Ensure -eq 'Absent' -and $null -eq $website))
        {
            $desiredConfigurationMatch = $true
            Write-Verbose -Message "The Website '$EndpointName' is not present as requested."
            break
        }

        # The other case is: Ensure and exist, we continue with more checks
        Write-Verbose -Message 'Check Port.'
        $actualPort = $website.bindings.Collection[0].bindingInformation.Split(':')[1]

        if ($Port -ne $actualPort)
        {
            $desiredConfigurationMatch = $false
            Write-Verbose -Message "Port for the Website '$EndpointName' does not match the desired state."
            break
        }

        Write-Verbose -Message 'Check Application Pool.'

        if ($ApplicationPoolName -ne $website.applicationPool)
        {
            $desiredConfigurationMatch = $false
            Write-Verbose -Message "Currently bound application pool '$($website.applicationPool)' does not match the desired state '$ApplicationPoolName'."
            break
        }

        Write-Verbose -Message 'Check Binding.'
        $actualCertificateHash = $website.bindings.Collection[0].certificateHash
        $websiteProtocol = $website.bindings.collection[0].Protocol

        Write-Verbose -Message 'Checking firewall rule settings.'
        $ruleExists = Test-PullServerFirewallConfiguration -Port $Port

        if ($ruleExists -and -not $ConfigureFirewall)
        {
            $desiredConfigurationMatch = $false
            Write-Verbose -Message "Firewall rule exists for $Port and should not. Configuration does not match the desired state."
            break
        }
        elseif (-not $ruleExists -and $ConfigureFirewall)
        {
            $desiredConfigurationMatch = $false
            Write-Verbose -Message "Firewall rule does not exist for $Port and should. Configuration does not match the desired state."
            break
        }

        switch ($PSCmdlet.ParameterSetName)
        {
            'CertificateThumbprint'
            {
                if ($CertificateThumbPrint -eq 'AllowUnencryptedTraffic' -and $websiteProtocol -ne 'http')
                {
                    $desiredConfigurationMatch = $false
                    Write-Verbose -Message "Website '$EndpointName' is not configured for http and does not match the desired state."
                    break WebSiteTests
                }

                if ($CertificateThumbPrint -ne 'AllowUnencryptedTraffic' -and $websiteProtocol -ne 'https')
                {
                    $desiredConfigurationMatch = $false
                    Write-Verbose -Message "Website '$EndpointName' is not configured for https and does not match the desired state."
                    break WebSiteTests
                }
            }

            'CertificateSubject'
            {
                $certificateThumbPrint = Find-CertificateThumbprintWithSubjectAndTemplateName -Subject $CertificateSubject -TemplateName $CertificateTemplateName

                if ($CertificateThumbPrint -ne $actualCertificateHash)
                {
                    $desiredConfigurationMatch = $false
                    Write-Verbose -Message "Certificate Hash for the Website '$EndpointName' does not match the desired state."
                    break WebSiteTests
                }
            }
        }

        Write-Verbose -Message 'Check Physical Path property.'

        if (Test-WebsitePath -EndpointName $EndpointName -PhysicalPath $PhysicalPath)
        {
            $desiredConfigurationMatch = $false
            Write-Verbose -Message "Physical Path of Website '$EndpointName' does not match the desired state."
            break
        }

        Write-Verbose -Message 'Check State.'

        if ($website.state -ne $State -and $null -ne $State)
        {
            $desiredConfigurationMatch = $false
            Write-Verbose -Message "The state of Website '$EndpointName' does not match the desired state."
            break
        }

        Write-Verbose -Message 'Get Full Path for Web.config file.'
        $webConfigFullPath = Join-Path -Path $website.physicalPath -ChildPath 'web.config'

        # Changed from -eq $false to -ne $true as $IsComplianceServer is never set. This section was always being skipped
        if ($IsComplianceServer -ne $true)
        {
            Write-Verbose -Message 'Check DatabasePath.'

            switch ((Get-WebConfigAppSetting -WebConfigFullPath $webConfigFullPath -AppSettingName 'dbprovider'))
            {
                'ESENT'
                {
                    $expectedConnectionString = "$DatabasePath\Devices.edb"
                }

                'System.Data.OleDb'
                {
                    $expectedConnectionString = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$DatabasePath\Devices.mdb;"
                }

                default
                {
                    $expectedConnectionString = [System.String]::Empty
                }
            }

            if ($SqlProvider)
            {
                $expectedConnectionString = $SqlConnectionString
            }

            if (([System.String]::IsNullOrEmpty($expectedConnectionString)))
            {
                $desiredConfigurationMatch = $false
                Write-Verbose -Message "The DB provider does not have a valid value: 'ESENT' or 'System.Data.OleDb'."
                break
            }

            if (-not (Test-WebConfigAppSetting `
                -WebConfigFullPath $webConfigFullPath `
                -AppSettingName 'dbconnectionstr' `
                -ExpectedAppSettingValue $expectedConnectionString))
            {
                $desiredConfigurationMatch = $false
                break
            }

            Write-Verbose -Message 'Check ModulePath.'

            if ($ModulePath)
            {
                if (-not (Test-WebConfigAppSetting `
                    -WebConfigFullPath $webConfigFullPath `
                    -AppSettingName 'ModulePath' `
                    -ExpectedAppSettingValue $ModulePath))
                {
                    $desiredConfigurationMatch = $false
                    break
                }
            }

            Write-Verbose -Message 'Check ConfigurationPath.'

            if ($ConfigurationPath)
            {
                if (-not (Test-WebConfigAppSetting `
                    -WebConfigFullPath $webConfigFullPath `
                    -AppSettingName 'ConfigurationPath' `
                    -ExpectedAppSettingValue $configurationPath))
                {
                    $desiredConfigurationMatch = $false
                    break
                }
            }

            Write-Verbose -Message 'Check RegistrationKeyPath.'

            if ($RegistrationKeyPath)
            {
                if (-not (Test-WebConfigAppSetting `
                    -WebConfigFullPath $webConfigFullPath `
                    -AppSettingName 'RegistrationKeyPath' `
                    -ExpectedAppSettingValue $registrationKeyPath))
                {
                    $desiredConfigurationMatch = $false
                    break
                }
            }

            Write-Verbose -Message 'Check AcceptSelfSignedCertificates.'

            if ($AcceptSelfSignedCertificates)
            {
                Write-Verbose -Message "AcceptSelfSignedCertificates is enabled. Checking if module Selfsigned IIS module is configured for web site at '$webConfigFullPath'."

                if (Test-IISSelfSignedModuleInstalled)
                {
                    if (-not (Test-IISSelfSignedModuleEnabled -EndpointName $EndpointName))
                    {
                        Write-Verbose -Message 'Module not enabled in web site. Current configuration does not match the desired state.'
                        $desiredConfigurationMatch = $false
                        break
                    }
                    else
                    {
                        Write-Verbose -Message 'Module present in web site. Current configuration match the desired state.'
                    }
                }
                else
                {
                    Write-Verbose -Message 'Selfsigned module not installed in IIS. Current configuration does not match the desired state.'
                    $desiredConfigurationMatch = $false
                }
            }
            else
            {
                Write-Verbose -Message "AcceptSelfSignedCertificates is disabled. Checking if module Selfsigned IIS module is NOT configured for web site at '$webConfigFullPath'."

                if (Test-IISSelfSignedModuleInstalled)
                {
                    if (-not (Test-IISSelfSignedModuleEnabled -EndpointName $EndpointName))
                    {
                        Write-Verbose -Message 'Module not enabled in web site. Current configuration does match the desired state.'
                    }
                    else
                    {
                        Write-Verbose -Message 'Module present in web site. Current configuration does not match the desired state.'
                        $desiredConfigurationMatch = $false
                        break
                    }
                }
                else
                {
                    Write-Verbose -Message 'Selfsigned module not installed in IIS. Current configuration does match the desired state.'
                }
            }
        }

        Write-Verbose -Message 'Check UseSecurityBestPractices.'

        if ($UseSecurityBestPractices)
        {
            if (-not (UseSecurityBestPractices\Test-UseSecurityBestPractice -DisableSecurityBestPractices $DisableSecurityBestPractices))
            {
                $desiredConfigurationMatch = $false
                Write-Verbose -Message 'The state of security settings does not match the desired state.'
                break
            }
        }

        $stop = $false
    }
    while ($stop)

    return $desiredConfigurationMatch
}

<#
    .SYNOPSIS
        The function returns the OS version string detected by .NET.

    .DESCRIPTION
        The function returns the OS version which ahs been detected
        by .NET. The function is added so that the dectection of the OS
        is mockable in Pester tests.

    .OUTPUTS
        System.String. The operating system version.
#>
function Get-OSVersion
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param ()

    # Moved to a function to allow for the behaviour to be mocked.
    return [System.Environment]::OSVersion.Version
}

#region IIS Utils

<#
    .SYNOPSIS
        Returns the configuration value for a module settings from
        web.config.

    .PARAMETER WebConfigFullPath
        The full path to the web.config.

    .PARAMETER ModuleName
        The name of the IIS module.

    .OUTPUTS
        System.String. The configured value.
#>
function Get-WebConfigModulesSetting
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $WebConfigFullPath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ModuleName
    )

    $moduleValue = ''

    if (Test-Path -Path $WebConfigFullPath)
    {
        $webConfigXml = [Xml] (Get-Content -Path $WebConfigFullPath)
        $root = $webConfigXml.get_DocumentElement()

        foreach ($item in $root.'system.webServer'.modules.add)
        {
            if ($item.name -eq $ModuleName)
            {
                $moduleValue = $item.name
                break
            }
        }
    }

    return $moduleValue
}

<#
    .SYNOPSIS
        Unlocks a specifc authentication configuration section for a IIS website.

    .PARAMETER WebSite
        The name of the website.

    .PARAMETER Authentication
        The authentication section which should be unlocked.

    .OUTPUTS
        System.String. The configured value.
#>
function Update-LocationTagInApplicationHostConfigForAuthentication
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $WebSite,

        [Parameter(Mandatory = $true)]
        [ValidateSet('anonymous', 'basic', 'windows')]
        [System.String]
        $Authentication
    )

    $webAdminSrvMgr = Get-IISServerManager
    $appHostConfig = $webAdminSrvMgr.GetApplicationHostConfiguration()

    $authenticationType = $Authentication + 'Authentication'
    $appHostConfigSection = $appHostConfig.GetSection("system.webServer/security/authentication/$authenticationType", $WebSite)
    $appHostConfigSection.OverrideMode = 'Allow'
    $webAdminSrvMgr.CommitChanges()
}

<#
    .SYNOPSIS
        Returns an instance of the Microsoft.Web.Administration.ServerManager.

    .OUTPUTS
        The server manager as Microsoft.Web.Administration.ServerManager.
#>
function Get-IISServerManager
{
    [CmdletBinding()]
    [OutputType([System.Object])]
    param ()

    $iisInstallPath = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\INetStp' -Name InstallPath).InstallPath

    if (-not $iisInstallPath)
    {
        throw ($script:localizedData.IISInstallationPathNotFound)
    }

    $assyPath = Join-Path -Path $iisInstallPath -ChildPath 'Microsoft.Web.Administration.dll' -Resolve -ErrorAction:SilentlyContinue

    if (-not $assyPath)
    {
        throw ($script:localizedData.IISWebAdministrationAssemblyNotFound)
    }

    $assy = [System.Reflection.Assembly]::LoadFrom($assyPath)
    return [System.Activator]::CreateInstance($assy.FullName, 'Microsoft.Web.Administration.ServerManager').Unwrap()
}

<#
    .SYNOPSIS
        Tests if a module installation status is equal to an expected status.

    .PARAMETER WebConfigFullPath
        The full path to the web.config.

    .PARAMETER ModuleName
        The name of the IIS module for which the state should be checked.

    .PARAMETER ExpectedInstallationStatus
        Test if the module is installed ($true) or absent ($false).

    .OUTPUTS
        Returns true if the current installation status is equal to the expected
        installation status.
#>
function Test-WebConfigModulesSetting
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $WebConfigFullPath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ModuleName,

        [Parameter(Mandatory = $true)]
        [Boolean]
        $ExpectedInstallationStatus
    )

    if (Test-Path -Path $WebConfigFullPath)
    {
        $webConfigXml = [Xml] (Get-Content -Path $WebConfigFullPath)
        $root = $webConfigXml.get_DocumentElement()

        foreach ($item in $root.'system.webServer'.modules.add)
        {
            if ( $item.name -eq $ModuleName )
            {
                return $ExpectedInstallationStatus -eq $true
            }
        }
    }
    else
    {
        Write-Warning -Message "Test-WebConfigModulesSetting: web.config file not found at '$WebConfigFullPath'"
    }

    return $ExpectedInstallationStatus -eq $false
}

<#
    .SYNOPSIS
        Tests if a the currently configured path for a website is equal to a given
        path.

    .PARAMETER EndpointName
        The endpoint name (website name) to test.

    .PARAMETER PhysicalPath
        The full physical path to check.

    .OUTPUTS
        Returns true if the current installation status is equal to the expected
        installation status.
#>
function Test-WebsitePath
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $EndpointName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PhysicalPath
    )

    $pathNeedsUpdating = $false

    if ((Get-ItemProperty -Path "IIS:\Sites\$EndpointName" -Name physicalPath) -ne $PhysicalPath)
    {
        $pathNeedsUpdating = $true
    }

    return $pathNeedsUpdating
}

<#
    .SYNOPSIS
        Test if a currently configured app setting is equal to a given value.

    .PARAMETER WebConfigFullPath
        The full path to the web.config.

    .PARAMETER AppSettingName
        The app setting name to check.

    .PARAMETER ExpectedAppSettingValue
        The expected value.

    .OUTPUTS
        Returns true if the current value is equal to the expected value.
#>
function Test-WebConfigAppSetting
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $WebConfigFullPath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $AppSettingName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ExpectedAppSettingValue
    )

    $returnValue = $true

    if (Test-Path -Path $WebConfigFullPath)
    {
        $webConfigXml = [System.Xml.XmlDocument] (Get-Content -Path $WebConfigFullPath)
        $root = $webConfigXml.get_DocumentElement()

        foreach ($item in $root.appSettings.add)
        {
            if ( $item.key -eq $AppSettingName )
            {
                break
            }
        }

        if ($item.value -ne $ExpectedAppSettingValue)
        {
            $returnValue = $false
            Write-Verbose -Message "The state of Web.Config AppSetting '$AppSettingName' does not match the desired state."
        }
    }

    return $returnValue
}

<#
    .SYNOPSIS
        Helper function to Get the specified Web.Config App Setting.

    .PARAMETER WebConfigFullPath
        The full path to the web.config.

    .PARAMETER AppSettingName
        The app settings name to get the value for.

    .OUTPUTS
        The current app settings value.
#>
function Get-WebConfigAppSetting
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $WebConfigFullPath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $AppSettingName
    )

    $appSettingValue = ''

    if (Test-Path -Path $WebConfigFullPath)
    {
        $webConfigXml = [System.Xml.XmlDocument] (Get-Content -Path $WebConfigFullPath)
        $root = $webConfigXml.get_DocumentElement()

        foreach ($item in $root.appSettings.add)
        {
            if ($item.key -eq $AppSettingName)
            {
                $appSettingValue = $item.value
                break
            }
        }
    }

    return $appSettingValue
}

#endregion

#region IIS Selfsigned Certficate Module

New-Variable -Name iisSelfSignedModuleAssemblyName -Value 'IISSelfSignedCertModule.dll' -Option ReadOnly -Scope Script
New-Variable -Name iisSelfSignedModuleName -Value 'IISSelfSignedCertModule(32bit)' -Option ReadOnly -Scope Script

<#
    .SYNOPSIS
        Get a powershell command instance for appcmd.exe.

    .OUTPUTS
        The appcmd.exe as System.Management.Automation.CommandInfo.
#>
function Get-IISAppCmd
{
    [CmdletBinding()]
    [OutputType([System.Management.Automation.CommandInfo])]
    param ()

    Push-Location -Path "$env:windir\system32\inetsrv"
    $appCmd = Get-Command -Name '.\appcmd.exe' -CommandType 'Application' -ErrorAction:Stop
    Pop-Location
    $appCmd
}

<#
    .SYNOPSIS
        Tests if two files differ.

    .PARAMETER SourceFilePath
        Path to the source file.

    .PARAMETER DestinationFilePath
        Path to the destination file.

    .OUTPUTS
        Returns true if the two files differ.
#>
function Test-FilesDiffer
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript( { Test-Path -PathType Leaf -LiteralPath $_ })]
        [System.String]
        $SourceFilePath,

        [Parameter()]
        [System.String]
        $DestinationFilePath
    )

    Write-Verbose -Message "Testing for file difference between '$SourceFilePath' and '$DestinationFilePath'."

    if (Test-Path -LiteralPath $DestinationFilePath)
    {
        if (Test-Path -LiteralPath $DestinationFilePath -PathType Container)
        {
            throw "$DestinationFilePath is a container (Directory) not a leaf (File)"
        }

        Write-Verbose -Message "Destination file already exists at '$DestinationFilePath'."
        $md5Dest = Get-FileHash -LiteralPath $destinationFilePath -Algorithm MD5
        $md5Src = Get-FileHash -LiteralPath $sourceFilePath -Algorithm MD5
        return $md5Src.Hash -ne $md5Dest.Hash
    }
    else
    {
        Write-Verbose -Message "Destination file does not exist at '$DestinationFilePath'."
        return $true
    }
}

<#
    .SYNOPSIS
        Tests if the IISSelfSignedModule module is installed.

    .OUTPUTS
        Returns true if the module is installed.
#>
function Test-IISSelfSignedModuleInstalled
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param ()

    return ('' -ne ((& (Get-IISAppCmd) list config -section:system.webServer/globalModules) -like "*$iisSelfSignedModuleName*"))
}

<#
    .SYNOPSIS
        Install the IISSelfSignedModule module.

    .PARAMETER Enable32BitAppOnWin64
        If set install the module as 32bit module.
#>
function Install-IISSelfSignedModule
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [Switch]
        $Enable32BitAppOnWin64
    )

    if ($Enable32BitAppOnWin64)
    {
        Write-Verbose -Message "Install-IISSelfSignedModule: Providing '$iisSelfSignedModuleAssemblyName' to run in a 32 bit process."

        $sourceFilePath = Join-Path -Path "$env:windir\SysWOW64\WindowsPowerShell\v1.0\Modules\PSDesiredStateConfiguration\PullServer" `
            -ChildPath $iisSelfSignedModuleAssemblyName
        $destinationFolderPath = "$env:windir\SysWOW64\inetsrv"

        Copy-Item -Path $sourceFilePath -Destination $destinationFolderPath -Force
    }

    if (Test-IISSelfSignedModuleInstalled)
    {
        Write-Verbose -Message "Install-IISSelfSignedModule: module '$iisSelfSignedModuleName' already installed."
    }
    else
    {
        Write-Verbose -Message "Install-IISSelfSignedModule: Installing module '$iisSelfSignedModuleName'."
        $sourceFilePath = Join-Path -Path "$env:windir\System32\WindowsPowerShell\v1.0\Modules\PSDesiredStateConfiguration\PullServer" `
            -ChildPath $iisSelfSignedModuleAssemblyName
        $destinationFolderPath = "$env:windir\System32\inetsrv"
        $destinationFilePath = Join-Path -Path $destinationFolderPath `
            -ChildPath $iisSelfSignedModuleAssemblyName

        if (Test-FilesDiffer -SourceFilePath $sourceFilePath -DestinationFilePath $destinationFilePath)
        {
            # Might fail if the DLL has already been loaded by the IIS from a former PullServer Deployment
            Copy-Item -Path $sourceFilePath -Destination $destinationFolderPath -Force
        }
        else
        {
            Write-Verbose -Message "Install-IISSelfSignedModule: module '$iisSelfSignedModuleName' already installed at '$destinationFilePath' with the correct version."
        }

        Write-Verbose -Message "Install-IISSelfSignedModule: globally activating module '$iisSelfSignedModuleName'."
        & (Get-IISAppCmd) install module /name:$iisSelfSignedModuleName /image:$destinationFilePath /add:false /lock:false
    }
}

<#
    .SYNOPSIS
        Enable the IISSelfSignedModule module for a specific website (endpoint).

    .PARAMETER EndpointName
        The endpoint (website) for which the module should be enabled.

    .PARAMETER Enable32BitAppOnWin64
        If set enable the module as a 32bit module.
#>
function Enable-IISSelfSignedModule
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $EndpointName,

        [Parameter()]
        [Switch]
        $Enable32BitAppOnWin64
    )

    Write-Verbose -Message "Enable-IISSelfSignedModule: EndpointName '$EndpointName' and Enable32BitAppOnWin64 '$Enable32BitAppOnWin64'"

    Install-IISSelfSignedModule -Enable32BitAppOnWin64:$Enable32BitAppOnWin64
    $preConditionBitnessArgumentFor32BitInstall = ''

    if ($Enable32BitAppOnWin64)
    {
        $preConditionBitnessArgumentFor32BitInstall = '/preCondition:bitness32'
    }

    & (Get-IISAppCmd) add module /name:$iisSelfSignedModuleName /app.name:"$EndpointName/" $preConditionBitnessArgumentFor32BitInstall
}

<#
    .SYNOPSIS
        Disable the IISSelfSignedModule module for a specific website (endpoint).

    .PARAMETER EndpointName
        The endpoint (website) for which the module should be disabled.
#>
function Disable-IISSelfSignedModule
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$EndpointName
    )

    Write-Verbose -Message "Disable-IISSelfSignedModule: EndpointName '$EndpointName'"

    & (Get-IISAppCmd) delete module /name:$iisSelfSignedModuleName  /app.name:"$EndpointName/"
}

<#
    .SYNOPSIS
        Tests if the IISSelfSignedModule module is enabled for a website (endpoint).

    .PARAMETER EndpointName
        The endpoint (website) for which the status should be checked.

    .OUTPUTS
        Returns true if the module is enabled.
#>
function Test-IISSelfSignedModuleEnabled
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $EndpointName
    )

    Write-Verbose -Message "Test-IISSelfSignedModuleEnabled: EndpointName '$EndpointName'"

    $webSite = Get-Website -Name $EndpointName

    if ($webSite)
    {
        $webConfigFullPath = Join-Path -Path $website.physicalPath -ChildPath 'web.config'
        Write-Verbose -Message "Test-IISSelfSignedModuleEnabled: web.confg path '$webConfigFullPath'"
        Test-WebConfigModulesSetting -WebConfigFullPath $webConfigFullPath -ModuleName $iisSelfSignedModuleName -ExpectedInstallationStatus $true
    }
    else
    {
        throw "Website '$EndpointName' not found"
    }
}

#endregion

#region Certificate Utils

<#
    .SYNOPSIS
        Returns a certificate thumbprint from a certificate with a matching subject.

    .DESCRIPTION
        Retreives a list of certificates from the a certificate store.
        From this list all certificates will be checked to see if they match the supplied Subject and Template.
        If one certificate is found the thumbrpint is returned. Otherwise an error is thrown.

    .PARAMETER Subject
        The subject of the certificate to find the thumbprint of.

    .PARAMETER TemplateName
        The template used to create the certificate to find the subject of.

    .PARAMETER Store
        The certificate store to retrieve certificates from.

    .NOTES
        Uses certificate Oid mapping:
        1.3.6.1.4.1.311.20.2 = Certificate Template Name
        1.3.6.1.4.1.311.21.7 = Certificate Template Information
#>
function Find-CertificateThumbprintWithSubjectAndTemplateName
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Subject,

        [Parameter(Mandatory = $true)]
        [System.String]
        $TemplateName,

        [Parameter()]
        [System.String]
        $Store = 'Cert:\LocalMachine\My'
    )

    $filteredCertificates = @()

    foreach ($oidFriendlyName in 'Certificate Template Name', 'Certificate Template Information')
    {
        # Only get certificates created from a template otherwise filtering by subject and template name will cause errors
        [System.Array] $certificatesFromTemplates = (Get-ChildItem -Path $Store).Where{
            $_.Extensions.Oid.FriendlyName -contains $oidFriendlyName
        }

        switch ($oidFriendlyName)
        {
            'Certificate Template Name'
            {
                $templateMatchString = $TemplateName
            }

            'Certificate Template Information'
            {
                $templateMatchString = '^Template={0}' -f $TemplateName
            }
        }

        $filteredCertificates += $certificatesFromTemplates.Where{
            $_.Subject -eq $Subject -and
            $_.Extensions.Where{
                $_.Oid.FriendlyName -eq $oidFriendlyName
            }.Format($false) -match $templateMatchString
        }
    }

    if ($filteredCertificates.Count -eq 1)
    {
        return $filteredCertificates.Thumbprint
    }
    elseif ($filteredCertificates.Count -gt 1)
    {
        throw ($script:localizedData.FindCertificateBySubjectMultiple -f $Subject, $TemplateName)
    }
    else
    {
        throw ($script:localizedData.FindCertificateBySubjectNotFound -f $Subject, $TemplateName)
    }
}

#endregion

#region Firewall Utils

# Name and description for the Firewall rules. Used in multiple locations
New-Variable -Name FireWallRuleDisplayName -Value 'DSCPullServer_IIS_Port' -Option ReadOnly -Scope Script -Force
New-Variable -Name netsh -Value "$env:windir\system32\netsh.exe" -Option ReadOnly -Scope Script -Force

<#
    .SYNOPSIS
        Create a firewall exception so that DSC clients are able to access the configured Pull Server

    .PARAMETER Port
        The TCP port used to create the firewall exception
#>
function Add-PullServerFirewallConfiguration
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateRange(1, 65535)]
        [System.UInt32]
        $Port
    )

    Write-Verbose -Message 'Disable Inbound Firewall Notification'
    $null = & $script:netsh advfirewall set currentprofile settings inboundusernotification disable

    $ruleName = $FireWallRuleDisplayName

    # Remove all existing rules with that displayName
    $null = & $script:netsh advfirewall firewall delete rule name=$ruleName protocol=tcp localport=$Port

    Write-Verbose -Message "Add Firewall Rule for port $Port"
    $null = & $script:netsh advfirewall firewall add rule name=$ruleName dir=in action=allow protocol=TCP localport=$Port
}

<#
    .SYNOPSIS
        Delete the Pull Server firewall exception

    .PARAMETER Port
        The TCP port for which the firewall exception should be deleted
#>
function Remove-PullServerFirewallConfiguration
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateRange(1, 65535)]
        [System.UInt32]
        $Port
    )

    if (Test-PullServerFirewallConfiguration -Port $Port)
    {
        # remove all existing rules with that displayName
        Write-Verbose -Message "Delete Firewall Rule for port $Port"
        $ruleName = $FireWallRuleDisplayName

        # backwards compatibility with old code
        if (Get-Command -Name Get-NetFirewallRule -CommandType Cmdlet -ErrorAction:SilentlyContinue)
        {
            # Remove all rules with that name
            Get-NetFirewallRule -DisplayName $ruleName | Remove-NetFirewallRule
        }
        else
        {
            $null = & $script:netsh advfirewall firewall delete rule name=$ruleName protocol=tcp localport=$Port
        }
    }
    else
    {
        Write-Verbose -Message "No DSC PullServer firewall rule found with port $Port. No cleanup required"
    }
}

<#
    .SYNOPSIS
        Tests if a Pull Server firewall exception exists for a specific port

    .PARAMETER Port
        The TCP port for which the firewall exception should be tested
#>
function Test-PullServerFirewallConfiguration
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter()]
        [ValidateRange(1, 65535)]
        [System.UInt32]
        $Port
    )

    # Remove all existing rules with that displayName
    Write-Verbose -Message "Testing Firewall Rule for port $Port"
    $ruleName = $FireWallRuleDisplayName
    $result = & $script:netsh advfirewall firewall show rule name=$ruleName | Select-String -Pattern "LocalPort:\s*$Port"
    return -not [string]::IsNullOrWhiteSpace($result)
}

#endregion

#region PSWS IIS Endpoint Utils
New-Variable -Name DscWebServiceDefaultAppPoolName  -Value 'PSWS' -Option ReadOnly -Force -Scope Script

<#
    .SYNOPSIS
        Validate supplied configuration to setup the PSWS Endpoint Function
        checks for the existence of PSWS Schema files, IIS config Also validate
        presence of IIS on the target machine
#>
function Initialize-Endpoint
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $appPool,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $site,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $path,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $cfgfile,

        [Parameter()]
        [System.Int32]
        $port,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $app,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $applicationPoolIdentityType,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $svc,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $mof,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $dispatch,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $asax,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $dependentBinaries,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $language,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $dependentMUIFiles,

        [Parameter()]
        [System.String[]]
        $psFiles,

        [Parameter()]
        [System.Boolean]
        $removeSiteFiles = $false,

        [Parameter()]
        [System.String]
        $certificateThumbPrint,

        [Parameter()]
        [System.Boolean]
        $enable32BitAppOnWin64
    )

    if ($certificateThumbPrint -ne 'AllowUnencryptedTraffic')
    {
        Write-Verbose -Message 'Verify that the certificate with the provided thumbprint exists in CERT:\LocalMachine\MY\'

        $certificate = Get-ChildItem -Path CERT:\LocalMachine\MY\ | Where-Object -FilterScript {
            $_.Thumbprint -eq $certificateThumbPrint
        }

        if (!$Certificate)
        {
             throw "ERROR: Certificate with thumbprint $certificateThumbPrint does not exist in CERT:\LocalMachine\MY\"
        }
    }

    Test-IISInstall

    # First remove the site so that the binding count on the application pool is reduced
    Update-Site -siteName $site -siteAction Remove

    Remove-AppPool -appPool $appPool

    # Check for existing binding, there should be no binding with the same port
    $allWebBindingsOnPort = Get-WebBinding | Where-Object -FilterScript {
        $_.BindingInformation -eq "*:$($port):"
    }

    if ($allWebBindingsOnPort.Count -gt 0)
    {
        throw "ERROR: Port $port is already used, please review existing sites and change the port to be used."
    }

    if ($removeSiteFiles)
    {
        if (Test-Path -Path $path)
        {
            Remove-Item -Path $path -Recurse -Force
        }
    }

    Copy-PSWSConfigurationToIISEndpointFolder -path $path `
        -cfgfile $cfgfile `
        -svc $svc `
        -mof $mof `
        -dispatch $dispatch `
        -asax $asax `
        -dependentBinaries $dependentBinaries `
        -language $language `
        -dependentMUIFiles $dependentMUIFiles `
        -psFiles $psFiles

    New-IISWebSite -site $site `
        -path $path `
        -port $port `
        -app $app `
        -apppool $appPool `
        -applicationPoolIdentityType $applicationPoolIdentityType `
        -certificateThumbPrint $certificateThumbPrint `
        -enable32BitAppOnWin64 $enable32BitAppOnWin64
}

<#
    .SYNOPSIS
        Validate if IIS and all required dependencies are installed on the
        target machine
#>
function Test-IISInstall
{
    [CmdletBinding()]
    param ()

    Write-Verbose -Message 'Checking IIS requirements'
    $iisVersion = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\InetStp -ErrorAction silentlycontinue).MajorVersion

    if ($iisVersion -lt 7)
    {
        throw "ERROR: IIS Version detected is $iisVersion , must be running higher than 7.0"
    }

    $wsRegKey = (Get-ItemProperty hklm:\SYSTEM\CurrentControlSet\Services\W3SVC -ErrorAction silentlycontinue).ImagePath
    if ($null -eq $wsRegKey)
    {
        throw 'ERROR: Cannot retrive W3SVC key. IIS Web Services may not be installed'
    }

    if ((Get-Service w3svc).Status -ne 'running')
    {
        throw 'ERROR: service W3SVC is not running'
    }
}

<#
    .SYNOPSIS
        Verify if a given IIS Site exists
#>
function Test-ForIISSite
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter()]
        [System.String]
        $siteName
    )

    if (Get-Website -Name $siteName)
    {
        return $true
    }

    return $false
}

<#
    .SYNOPSIS
        Perform an action (such as stop, start, delete) for a given IIS Site
#>
function Update-Site
{
    param
    (
        [Parameter(ParameterSetName = 'SiteName', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $siteName,

        [Parameter(ParameterSetName = 'Site', Mandatory = $true, Position = 0)]
        [System.Object]
        $site,

        [Parameter(ParameterSetName = 'SiteName', Mandatory = $true, Position = 1)]
        [Parameter(ParameterSetName = 'Site', Mandatory = $true, Position = 1)]
        [System.String]
        [ValidateSet('Start', 'Stop', 'Remove')]
        $siteAction
    )

    if ('SiteName' -eq  $PSCmdlet.ParameterSetName)
    {
        $site = Get-Website -Name $siteName
    }

    if ($site)
    {
        switch ($siteAction)
        {
            'Start'
            {
                Write-Verbose -Message "Starting IIS Website [$($site.name)]"
                Start-Website -Name $site.name
            }

            'Stop'
            {
                if ('Started' -eq $site.state)
                {
                    Write-Verbose -Message "Stopping WebSite $($site.name)"
                    $website = Stop-Website -Name $site.name -Passthru

                    if ('Started' -eq $website.state)
                    {
                        throw "Unable to stop WebSite $($site.name)"
                    }

                    <#
                      There may be running requests, wait a little
                      I had an issue where the files were still in use
                      when I tried to delete them
                    #>
                    Write-Verbose -Message 'Waiting for IIS to stop website'
                    Start-Sleep -Milliseconds 1000
                }
                else
                {
                    Write-Verbose -Message "IIS Website [$($site.name)] already stopped"
                }
            }

            'Remove'
            {
                Update-Site -site $site -siteAction Stop
                Write-Verbose -Message "Removing IIS Website [$($site.name)]"
                Remove-Website -Name $site.name
            }
        }
    }
    else
    {
        Write-Verbose -Message "IIS Website [$siteName] not found"
    }
}

<#
    .SYNOPSIS
        Returns the list of bound sites and applications for a given IIS Application pool

    .PARAMETER appPool
        The application pool name
#>
function Get-AppPoolBinding
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $AppPool
    )

    if (Test-Path -Path "IIS:\AppPools\$AppPool")
    {
        $sites = Get-WebConfigurationProperty `
            -Filter "/system.applicationHost/sites/site/application[@applicationPool=`'$AppPool`'and @path='/']/parent::*" `
            -PSPath 'machine/webroot/apphost' `
            -Name name
        $apps = Get-WebConfigurationProperty `
            -Filter "/system.applicationHost/sites/site/application[@applicationPool=`'$AppPool`'and @path!='/']" `
            -PSPath 'machine/webroot/apphost' `
            -Name path
        $sites, $apps | ForEach-Object {
            $_.Value
        }
    }
}

<#
    .SYNOPSIS
        Delete the given IIS Application Pool. This is required to cleanup any
        existing conflicting apppools before setting up the endpoint.
#>
function Remove-AppPool
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $AppPool
    )

    if ($DscWebServiceDefaultAppPoolName -eq $AppPool)
    {
        # Without this tests we may get a breaking error here, despite SilentlyContinue
        if (Test-Path -Path "IIS:\AppPools\$AppPool")
        {
            $bindingCount = (Get-AppPoolBinding -AppPool $AppPool | Measure-Object).Count

            if (0 -ge $bindingCount)
            {
                Remove-WebAppPool -Name $AppPool -ErrorAction SilentlyContinue
            }
            else
            {
                Write-Verbose -Message "Application pool [$AppPool] can't be deleted because it's still bound to a site or application"
            }
        }
    }
    else
    {
        Write-Verbose -Message "ApplicationPool can't be deleted because the name is different from built-in name [$DscWebServiceDefaultAppPoolName]."
    }
}

<#
    .SYNOPSIS
        Generate an IIS Site Id while setting up the endpoint. The Site Id will
        be the max available in IIS config + 1.
#>
function New-SiteID
{
    [CmdletBinding()]
    param ()

    return ((Get-Website | Foreach-Object -Process { $_.Id } | Measure-Object -Maximum).Maximum + 1)
}

<#
    .SYNOPSIS
        Copies the supplied PSWS config files to the IIS endpoint in inetpub
#>
function Copy-PSWSConfigurationToIISEndpointFolder
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.String]
        $path,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $cfgfile,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $svc,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $mof,

        [Parameter()]
        [System.String]
        $dispatch,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $asax,

        [Parameter()]
        [System.String[]]
        $dependentBinaries,

        [Parameter()]
        [System.String]
        $language,

        [Parameter()]
        [System.String[]]
        $dependentMUIFiles,

        [Parameter()]
        [System.String[]]
        $psFiles
    )

    if (!(Test-Path -Path $path))
    {
        $null = New-Item -ItemType container -Path $path
    }

    foreach ($dependentBinary in $dependentBinaries)
    {
        if (!(Test-Path -Path $dependentBinary))
        {
            throw "ERROR: $dependentBinary does not exist"
        }
    }

    Write-Verbose -Message 'Create the bin folder for deploying custom dependent binaries required by the endpoint'
    $binFolderPath = Join-Path -Path $path -ChildPath 'bin'
    $null = New-Item -Path $binFolderPath  -ItemType 'directory' -Force
    Copy-Item -Path $dependentBinaries -Destination $binFolderPath -Force

    foreach ($psFile in $psFiles)
    {
        if (!(Test-Path -Path $psFile))
        {
            throw "ERROR: $psFile does not exist"
        }

        Copy-Item -Path $psFile -Destination $path -Force
    }

    Copy-Item -Path $cfgfile (Join-Path -Path $path -ChildPath 'web.config') -Force
    Copy-Item -Path $svc -Destination $path -Force
    Copy-Item -Path $mof -Destination $path -Force

    if ($dispatch)
    {
        Copy-Item -Path $dispatch -Destination $path -Force
    }

    if ($asax)
    {
        Copy-Item -Path $asax -Destination $path -Force
    }
}

<#
    .SYNOPSIS
        Setup IIS Apppool, Site and Application
#>
function New-IISWebSite
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $site,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $path,

        [Parameter(Mandatory = $true)]
        [System.Int32]
        $port,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $app,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $appPool,

        [Parameter()]
        [System.String]
        $applicationPoolIdentityType,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $certificateThumbPrint,

        [Parameter()]
        [System.Boolean]
        $enable32BitAppOnWin64
    )

    $siteID = New-SiteID

    if (Test-Path IIS:\AppPools\$appPool)
    {
        Write-Verbose -Message "Application Pool [$appPool] already exists"
    }
    else
    {
        Write-Verbose -Message "Adding App Pool [$appPool]"
        $null = New-WebAppPool -Name $appPool

        Write-Verbose -Message 'Set App Pool Properties'
        $appPoolIdentity = 4

        if ($applicationPoolIdentityType)
        {
            # LocalSystem = 0, LocalService = 1, NetworkService = 2, SpecificUser = 3, ApplicationPoolIdentity = 4
            switch ($applicationPoolIdentityType)
            {
                'LocalSystem'
                {
                    $appPoolIdentity = 0
                }

                'LocalService'
                {
                    $appPoolIdentity = 1
                }

                'NetworkService'
                {
                    $appPoolIdentity = 2
                }

                'ApplicationPoolIdentity'
                {
                    $appPoolIdentity = 4
                }

                default {
                    throw "Invalid value [$applicationPoolIdentityType] for parameter -applicationPoolIdentityType"
                }
            }
        }

        $appPoolItem = Get-Item -Path IIS:\AppPools\$appPool
        $appPoolItem.managedRuntimeVersion = 'v4.0'
        $appPoolItem.enable32BitAppOnWin64 = $enable32BitAppOnWin64
        $appPoolItem.processModel.identityType = $appPoolIdentity
        $appPoolItem | Set-Item

    }

    Write-Verbose -Message 'Add and Set Site Properties'

    if ($certificateThumbPrint -eq 'AllowUnencryptedTraffic')
    {
        $null = New-WebSite -Name $site -Id $siteID -Port $port -IPAddress "*" -PhysicalPath $path -ApplicationPool $appPool
    }
    else
    {
        $null = New-WebSite -Name $site -Id $siteID -Port $port -IPAddress "*" -PhysicalPath $path -ApplicationPool $appPool -Ssl

        # Remove existing binding for $port
        Remove-Item IIS:\SSLBindings\0.0.0.0!$port -ErrorAction Ignore

        # Create a new binding using the supplied certificate
        $null = Get-Item CERT:\LocalMachine\MY\$certificateThumbPrint | New-Item IIS:\SSLBindings\0.0.0.0!$port
    }

    Update-Site -siteName $site -siteAction Start
}

<#
    .SYNOPSIS
        Enable & Clear PSWS Operational/Analytic/Debug ETW Channels.
#>
function Enable-PSWSETW
{
    # Disable Analytic Log
    $null = & $script:wevtutil sl Microsoft-Windows-ManagementOdataService/Analytic /e:false /q

    # Disable Debug Log
    $null = & $script:wevtutil sl Microsoft-Windows-ManagementOdataService/Debug /e:false /q

    # Clear Operational Log
    $null = & $script:wevtutil cl Microsoft-Windows-ManagementOdataService/Operational

    # Enable/Clear Analytic Log
    $null = & $script:wevtutil sl Microsoft-Windows-ManagementOdataService/Analytic /e:true /q

    # Enable/Clear Debug Log
    $null = & $script:wevtutil sl Microsoft-Windows-ManagementOdataService/Debug /e:true /q
}

<#
    .SYNOPSIS
        Create PowerShell WebServices IIS Endpoint

    .DESCRIPTION
        Creates a PSWS IIS Endpoint by consuming PSWS Schema and related
        dependent files

    .EXAMPLE
        New PSWS Endpoint [@ http://Server:39689/PSWS_Win32Process] by
        consuming PSWS Schema Files and any dependent scripts/binaries:

        New-PSWSEndpoint
            -site Win32Process
            -path $env:SystemDrive\inetpub\PSWS_Win32Process
            -cfgfile Win32Process.config
            -port 39689
            -app Win32Process
            -svc PSWS.svc
            -mof Win32Process.mof
            -dispatch Win32Process.xml
            -dependentBinaries ConfigureProcess.ps1, Rbac.dll
            -psFiles Win32Process.psm1
#>
function New-PSWSEndpoint
{
    [CmdletBinding()]
    param
    (
        # Unique Name of the IIS Site
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $site = 'PSWS',

        # Physical path for the IIS Endpoint on the machine (under inetpub)
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $path = "$env:SystemDrive\inetpub\PSWS",

        # Web.config file
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $cfgfile = 'web.config',

        # Port # for the IIS Endpoint
        [Parameter()]
        [System.Int32]
        $port = 8080,

        # IIS Application Name for the Site
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $app = 'PSWS',

        # IIS Application Name for the Site
        [Parameter()]
        [System.String]
        $appPool,

        # IIS App Pool Identity Type - must be one of LocalService, LocalSystem, NetworkService, ApplicationPoolIdentity
        [Parameter()]
        [ValidateSet('LocalService', 'LocalSystem', 'NetworkService', 'ApplicationPoolIdentity')]
        [System.String]
        $applicationPoolIdentityType,

        # WCF Service SVC file
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $svc = 'PSWS.svc',

        # PSWS Specific MOF Schema File
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $mof,

        # PSWS Specific Dispatch Mapping File [Optional]
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $dispatch,

        # Global.asax file [Optional]
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $asax,

        # Any dependent binaries that need to be deployed to the IIS endpoint, in the bin folder
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $dependentBinaries,

         # MUI Language [Optional]
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $language,

        # Any dependent binaries that need to be deployed to the IIS endpoint, in the bin\mui folder [Optional]
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $dependentMUIFiles,

        # Any dependent PowerShell Scipts/Modules that need to be deployed to the IIS endpoint application root
        [Parameter()]
        [System.String[]]
        $psFiles,

        # True to remove all files for the site at first, false otherwise
        [Parameter()]
        [System.Boolean]
        $removeSiteFiles = $false,

        # Enable and Clear PSWS ETW
        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $EnablePSWSETW,

        # Thumbprint of the Certificate in CERT:\LocalMachine\MY\ for Pull Server
        [Parameter()]
        [System.String]
        $certificateThumbPrint = 'AllowUnencryptedTraffic',

        # When this property is set to true, Pull Server will run on a 32 bit process on a 64 bit machine
        [Parameter()]
        [System.Boolean]
        $Enable32BitAppOnWin64 = $false
    )

    if (-not $appPool)
    {
        $appPool = $DscWebServiceDefaultAppPoolName
    }

    $script:wevtutil = "$env:windir\system32\Wevtutil.exe"

    $svcName = Split-Path $svc -Leaf
    $protocol = 'https:'

    if ($certificateThumbPrint -eq 'AllowUnencryptedTraffic')
    {
        $protocol = 'http:'
    }

    # Get Machine Name
    $cimInstance = Get-CimInstance -ClassName Win32_ComputerSystem -Verbose:$false

    Write-Verbose -Message "Setting up endpoint at - $protocol//$($cimInstance.Name):$port/$svcName"
    Initialize-Endpoint `
        -appPool $appPool `
        -site $site `
        -path $path `
        -cfgfile $cfgfile `
        -port $port `
        -app $app `
        -applicationPoolIdentityType $applicationPoolIdentityType `
        -svc $svc `
        -mof $mof `
        -dispatch $dispatch `
        -asax $asax `
        -dependentBinaries $dependentBinaries `
        -language $language `
        -dependentMUIFiles $dependentMUIFiles `
        -psFiles $psFiles `
        -removeSiteFiles $removeSiteFiles `
        -certificateThumbPrint $certificateThumbPrint `
        -enable32BitAppOnWin64 $Enable32BitAppOnWin64

    if ($EnablePSWSETW)
    {
        Enable-PSWSETW
    }
}

<#
    .SYNOPSIS
        Removes a DSC WebServices IIS Endpoint

    .DESCRIPTION
        Removes a PSWS IIS Endpoint

    .EXAMPLE
        Remove the endpoint with the specified name:

        Remove-PSWSEndpoint -siteName PSDSCPullServer
#>
function Remove-PSWSEndpoint
{
    [CmdletBinding()]
    param
    (
        # Unique Name of the IIS Site
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $siteName
    )

    # Get the site to remove
    $site = Get-Website -Name $siteName

    if ($site)
    {
        # And the pool it is using
        $pool = $site.applicationPool
        # Get the path so we can delete the files
        $filePath = $site.PhysicalPath

        # Remove the actual site.
        Update-Site -site $site -siteAction Remove

        # Remove the files for the site
        if (Test-Path -Path $filePath)
        {
            Get-ChildItem -Path $filePath -Recurse | Remove-Item -Recurse -Force
            Remove-Item -Path $filePath -Force
        }

        Remove-AppPool -appPool $pool
    }
    else
    {
        Write-Verbose -Message "Website with name [$siteName] does not exist"
    }
}

<#
    .SYNOPSIS
        Set the option into the web.config for an endpoint

    .DESCRIPTION
        Set the options into the web.config for an endpoint allowing
        customization.
#>
function Set-AppSettingsInWebconfig
{
    [CmdletBinding()]
    param
    (
        # Physical path for the IIS Endpoint on the machine (possibly under inetpub)
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        # Key to add/update
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Key,

        # Value
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Value
    )

    $webconfig = Join-Path -Path $Path -ChildPath 'web.config'
    [System.Boolean] $Found = $false

    if (Test-Path -Path $webconfig)
    {
        $xml = [System.Xml.XmlDocument] (Get-Content -Path $webconfig)
        $root = $xml.get_DocumentElement()

        foreach ($item in $root.appSettings.add)
        {
            if ($item.key -eq $Key)
            {
                $item.value = $Value;
                $Found = $true;
            }
        }

        if (-not $Found)
        {
            $newElement = $xml.CreateElement('add')
            $nameAtt1 = $xml.CreateAttribute('key')
            $nameAtt1.psbase.value = $Key;
            $null = $newElement.SetAttributeNode($nameAtt1)

            $nameAtt2 = $xml.CreateAttribute('value')
            $nameAtt2.psbase.value = $Value;
            $null = $newElement.SetAttributeNode($nameAtt2)

            $null = $xml.configuration['appSettings'].AppendChild($newElement)
        }
    }

    $xml.Save($webconfig)
}

<#
    .SYNOPSIS
        Set the binding redirect setting in the web.config to redirect 10.0.0.0
        version of microsoft.isam.esent.interop to 6.3.0.0.

    .DESCRIPTION
        This function creates the following section in the web.config:
        <runtime>
          <assemblyBinding xmlns='urn:schemas-microsoft-com:asm.v1'>
            <dependentAssembly>
              <assemblyIdentity name='microsoft.isam.esent.interop' publicKeyToken='31bf3856ad364e35' />
            <bindingRedirect oldVersion='10.0.0.0' newVersion='6.3.0.0' />
           </dependentAssembly>
          </assemblyBinding>
        </runtime>
#>
function Set-BindingRedirectSettingInWebConfig
{
    [CmdletBinding()]
    param
    (
        # Physical path for the IIS Endpoint on the machine (possibly under inetpub)
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $path,

        # old version of the assembly
        [Parameter()]
        [System.String]
        $oldVersion = '10.0.0.0',

        # new version to redirect to
        [Parameter()]
        [System.String]
        $newVersion = '6.3.0.0'
    )

    $webconfig = Join-Path $path 'web.config'

    if (Test-Path -Path $webconfig)
    {
        $xml = [System.Xml.XmlDocument] (Get-Content -Path $webconfig)

        if (-not($xml.get_DocumentElement().runtime))
        {
            # Create the <runtime> section
            $runtimeSetting = $xml.CreateElement('runtime')

            # Create the <assemblyBinding> section
            $assemblyBindingSetting = $xml.CreateElement('assemblyBinding')
            $xmlnsAttribute = $xml.CreateAttribute('xmlns')
            $xmlnsAttribute.Value = 'urn:schemas-microsoft-com:asm.v1'
            $assemblyBindingSetting.Attributes.Append($xmlnsAttribute)

            # The <assemblyBinding> section goes inside <runtime>
            $null = $runtimeSetting.AppendChild($assemblyBindingSetting)

            # Create the <dependentAssembly> section
            $dependentAssemblySetting = $xml.CreateElement('dependentAssembly')

            # The <dependentAssembly> section goes inside <assemblyBinding>
            $null = $assemblyBindingSetting.AppendChild($dependentAssemblySetting)

            # Create the <assemblyIdentity> section
            $assemblyIdentitySetting = $xml.CreateElement('assemblyIdentity')
            $nameAttribute = $xml.CreateAttribute('name')
            $nameAttribute.Value = 'microsoft.isam.esent.interop'
            $publicKeyTokenAttribute = $xml.CreateAttribute('publicKeyToken')
            $publicKeyTokenAttribute.Value = '31bf3856ad364e35'
            $null = $assemblyIdentitySetting.Attributes.Append($nameAttribute)
            $null = $assemblyIdentitySetting.Attributes.Append($publicKeyTokenAttribute)

            # <assemblyIdentity> section goes inside <dependentAssembly>
            $dependentAssemblySetting.AppendChild($assemblyIdentitySetting)

            # Create the <bindingRedirect> section
            $bindingRedirectSetting = $xml.CreateElement('bindingRedirect')
            $oldVersionAttribute = $xml.CreateAttribute('oldVersion')
            $newVersionAttribute = $xml.CreateAttribute('newVersion')
            $oldVersionAttribute.Value = $oldVersion
            $newVersionAttribute.Value = $newVersion
            $null = $bindingRedirectSetting.Attributes.Append($oldVersionAttribute)
            $null = $bindingRedirectSetting.Attributes.Append($newVersionAttribute)

            # The <bindingRedirect> section goes inside <dependentAssembly> section
            $dependentAssemblySetting.AppendChild($bindingRedirectSetting)

            # The <runtime> section goes inside <Configuration> section
            $xml.configuration.AppendChild($runtimeSetting)

            $xml.Save($webconfig)
        }
    }
}

#endregion

#region Secure TLS Protocols Utils

# Best Practice Security Settings Block
$insecureProtocols            = @("SSL 2.0", "SSL 3.0", "TLS 1.0", "PCT 1.0", "Multi-Protocol Unified Hello")
$secureProtocols              = @("TLS 1.1", "TLS 1.2")

<#
    .SYNOPSIS
        This function tests if the SChannel protocols are enabled.
#>
function Test-SChannelProtocol
{
    [CmdletBinding()]
    param ()

    foreach ($protocol in $insecureProtocols)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\Server"

        if ((Test-Path -Path $registryPath) `
            -and ($null -ne (Get-ItemProperty -Path $registryPath)) `
            -and ((Get-ItemProperty -Path $registryPath).Enabled -ne 0))
        {
            return $false
        }
    }

    foreach ($protocol in $secureProtocols)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\Server"

        if ((-not (Test-Path -Path $registryPath)) `
            -or ($null -eq (Get-ItemProperty -Path $registryPath)) `
            -or ((Get-ItemProperty -Path $registryPath).Enabled -eq 0))
        {
            return $false
        }
    }

    return $true
}

<#
    .SYNOPSIS
        This function enables the SChannel protocols.
#>
function Set-SChannelProtocol
{
    [CmdletBinding()]
    param ()

    foreach ($protocol in $insecureProtocols)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\Server"
        $null = New-Item -Path $registryPath -Force
        $null = New-ItemProperty -Path $registryPath -Name Enabled -Value 0 -PropertyType 'DWord' -Force
    }

    foreach ($protocol in $secureProtocols)
    {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\Server"
        $null = New-Item -Path $registryPath -Force
        $null = New-ItemProperty -Path $registryPath -Name Enabled -Value '0xffffffff' -PropertyType 'DWord' -Force
        $null = New-ItemProperty -Path $registryPath -Name DisabledByDefault -Value 0 -PropertyType 'DWord' -Force
    }
}

#endregion

#region Use Security Best Practices Utils

# This list corresponds to the ValueMap definition of DisableSecurityBestPractices parameter defined in MSFT_xDSCWebService.Schema.mof
$SecureTLSProtocols = 'SecureTLSProtocols'

<#
    .SYNOPSIS
        This function tests whether the node uses security best practices for non-disabled items
#>
function Test-UseSecurityBestPractice
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter()]
        [System.String[]]
        $DisableSecurityBestPractices
    )

    $usedProtocolsBestPractices = ($DisableSecurityBestPractices -icontains $SecureTLSProtocols) -or (Test-SChannelProtocol)

    return $usedProtocolsBestPractices
}

<#
    .SYNOPSIS
        This function sets the node to use security best practices for non-disabled items
#>
function Set-UseSecurityBestPractice
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.String[]]
        $DisableSecurityBestPractices
    )

    if (-not ($DisableSecurityBestPractices -icontains $SecureTLSProtocols))
    {
        Set-SChannelProtocol
    }
}

#endregion

Export-ModuleMember -Function *-TargetResource
