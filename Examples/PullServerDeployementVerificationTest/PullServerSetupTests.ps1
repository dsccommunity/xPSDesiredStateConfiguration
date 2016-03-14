
<#
 *
 * Once you setup your pullserver(V2), run the following set of tests on the pullserver machine to verify if the pullserver is setup properly and ready to go.
 * This test assumes default values are used during deployment  for the location of web.config and pull server URL.
 * If default values are not used during deployment , please update these values in the 'BeforeAll' block accordingly.
 *
 #>


Describe PullServerInstallationTests{

BeforeAll{
 
 # UPDATE THE PULLSERVER URL, If it is different from the default value.
 $pullserverURL = "http://$(hostname):8080/PSDSCPullServer/PSDSCPullserver.svc"

 # UPDATE THE LOCATION OF WEB.CONFIG, if it is differnet from the default path.
 $script:defaultPullServerConfigFile = "$($env:SystemDrive)\inetpub\wwwroot\psdscpullserver\web.config"

 $skip = $false
 if (-not (Test-Path $defaultPullServerConfigFile))
 {
    $skip = $true
    Write-Error "No pullserver web.config found." -ErrorAction Stop
 }
 $script:webConfigXml = [xml](cat $script:defaultPullServerConfigFile)

 # RegKey info.
 $regFileName = "RegistrationKeys.txt"
 $regKeyElement = $webConfigXml.SelectNodes("//appSettings/add[@key = 'RegistrationKeyPath']")
 $fullRegKeyPath = Join-Path $regKeyElement.value  $regFileName
 $regKeyContent = cat $fullRegKeyPath

 # Configuration repository info.
 $configurationPathElement  = $webConfigXml.SelectNodes("//appSettings/add[@key = 'ConfigurationPath']")
 $script:configurationRepository =  $configurationPathElement.value
 
}

It "Verify RegistrationKeyFile exist" -skip:$skip{

    $regKey = $webConfigXml.SelectNodes("//appSettings/add[@key = 'RegistrationKeyPath']")
    
    if (Test-path (Join-Path $regKey.value $regFileName)){
        Write-Verbose "Registration key file found."
    }
    else
    {   
        throw "RegistrationKeyFile NOT found. Make sure registration key file is placed on the location specified on the web.config of the pullserver."
    }
 }

<#
 # Verify module and configuration repository referenced on the web.config file exist.
 #>
 It "Verify configuration and module repository folders exist" -skip:$skip{
 
    $modulePathElement = $webConfigXml.SelectNodes("//appSettings/add[@key = 'ModulePath']")
    Test-Path ($modulePathElement.value) | Should Be $true "Module repository path referenced on web.config does not exist on the disk"
    Test-Path $script:configurationRepository | Should Be $true "Module repository path referenced on web.config does not exist on the disk"
}

<#
#
# Verify the server URL is up and running.
#>
 It "Verify server is up and running" -skip:$skip{
    $response = Invoke-WebRequest -Uri $pullserverURL -UseBasicParsing
    $response.StatusCode | Should Be 200 "Server response should be ok"
 }

 <#
 # Verify pull works on the current evironement by pulling a (No-OP) configuration from the pullserver.
 #
 #>
 It "Verify pull end to end works" -skip:$skip{
 
# Sample test meta-configuration
$configName = "PullServerSetUpTest"
[DscLocalConfigurationManager()]
Configuration PullServerSetUpTestMetaConfig
{
        Settings
        {
            RefreshMode = "PULL"             

        }
        ConfigurationRepositoryWeb ConfigurationManager
        {
            ServerURL =  $pullserverURL
            AllowUnsecureConnection = $true     # Remove this if you are using https
            RegistrationKey = $regKeyContent     
            ConfigurationNames = @($configName)
        }

}

PullServerSetUpTestMetaConfig -OutputPath .\PullServerSetUpTestMetaConfig
slcm -path .\PullServerSetUpTestMetaConfig -Verbose -force


$name = glcm |% ConfigurationDownloadManagers|% ConfigurationNames
$name | Should Be $configName


# Sample test configuration 
Configuration NoOpConfig
{
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
    Node ($configName)
    {
        Script script
        {
            GetScript = "@{}"
            SetScript = "{}"            
            TestScript =  ‘if ($false) { return $true } else {return $false}‘
        }
    }
}

# Create a mof file copy it to 
NoOpConfig -OutputPath $configurationRepository -Verbose

# Create checksum 
New-DscChecksum $configurationRepository -Verbose -Force

# pull configuration from the server.
Update-DscConfiguration -Wait -Verbose 

$confignameSet = Get-DscConfiguration | % ConfigurationName
$confignameSet | Should Be "NoOpConfig" "Configuration is not set properly"
 }

}