<############################################################################################ 
# File: DSC.Providers.Service.Helper.psm1
# This file contains helper methods that will be used by Service Provider Test Automation
# Copyright (c) Microsoft Corporation, 2013
############################################################################################>
 
# Import the Service Provider module
Import-Module $pshome\modules\PSDesiredStateConfiguration\DSCResources\MSFT_ServiceResource\MSFT_ServiceResource.psm1 -Force
Import-LocalizedData  serviceLocalizedData -BaseDirectory $pshome\modules\PSDesiredStateConfiguration\DSCResources\MSFT_ServiceResource -filename MSFT_ServiceResource.Strings.psd1
$global:serviceLocalizedData = $local:serviceLocalizedData

<############################################################################################ 
# Constants
############################################################################################>

# Test Service
$global:testServiceName = "DSCTestServiceName"
$global:testServiceDisplayName = "DSCTestService Display Name"
$global:testServiceDescription = "DSCTestService Description"
$global:testServiceDependsOn = "WinRM"

$global:testServiceProcessName = "DSCTestServiceName"
$global:testServiceExecutable = $global:testServiceProcessName + ".exe"
$global:testServiceCodeFile = "TestService.cs"
$global:testServiceBinaryFile = $global:testServiceProcessName + ".exe"

# Logging variables
$global:homePath = Split-Path -parent $MyInvocation.MyCommand.Path
$global:outputFileName = "TestLog"
$global:suffix = ""

$global:end2EndFolder = "E2EScripts"
$global:end2EndScriptPath = "$global:homePath\$global:end2EndFolder"

$global:whatIfFolder = "WhatIf"
$global:whatIfScriptPath = "$global:homePath\$global:whatIfFolder"

# Local Admin User credentials
$global:localAdminUserName = ""
$global:localAdminUserPassword = ""

[System.Management.Automation.PSCredential] $global:secureLocalAdminCredential

# Common Assert strings
$serviceIsNotPresentAsExpected = "Fail: Service is not present as expected"
$serviceIsNotAbsentAsExpected = "Fail: Service is not absent as expected"
$assertMessage = "Property: {0}"

<############################################################################################ 
# Common functions
#
#############################################################################################>

# Get normalized startup type
function GetNormalizedStartupType([System.String]$startupType)
{
    if ($startupType -ieq 'Auto') 
    {
        return "Automatic"
    }

    return $startupType
}

# Get Win32_Service object
function GetWin32_Service([System.String] $name)
{
    return New-Object management.managementobject "Win32_Service.Name = '$name'"
}

# Get-Service
function GetPowerShellService([System.String] $name)
{
    return Get-Service $name
}

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
        Remove-Service
    }

    $fileText = Get-Content $ServiceCodePath -Raw
    $fileText = $fileText.Replace("TestServiceReplacementName", $ServiceName)
    $fileText = $fileText.Replace("TestServiceReplacementDisplayName", $ServiceDisplayName)
    $fileText = $fileText.Replace("TestServiceReplacementDescription", $ServiceDescription)
    $fileText = $fileText.Replace("TestServiceReplacementDependsOn", $ServiceDependsOn)
    Add-Type $fileText -OutputAssembly $ServiceExecutablePath -OutputType WindowsApplication -ReferencedAssemblies "System.ServiceProcess", "System.Configuration.Install"
}

# Install a service on remote machine
function InstallServiceRemote
{
    param ([System.String]$exePath,
    $session)
    
    $scriptBlock = {
        param ([System.String]$exePath)
            
        # Get InstallUtil.exe path
        $frameworkName = if ($env:processor_Architecture -ieq 'amd64')
        {
            "Framework64"
        } 
        else 
        {
            "Framework"
        }
        
        $installUtility = Join-Path (Resolve-Path "$env:windir\Microsoft.Net\$frameworkName\v4*") "installUtil.exe"
        & $installUtility $exePath
    }
    
    Invoke-Command -Session $session -Scriptblock $scriptBlock -Verbose -ArgumentList $exePath
}  

# Install a service
function InstallService([System.String]$exePath = ".\$global:testServiceExecutable")
{
    $installUtility = GetInstallUtillPath
    & $installUtility $exePath
}

# Uninstall a service
function UninstallService([System.String]$exePath = ".\$global:testServiceExecutable")
{
    $installUtility = GetInstallUtillPath
    & $installUtility /u $exePath
}

# Uninstall a service by name
function Uninstall-ServiceByName([System.String]$serviceName = $global:testServiceName)
{
    $scUtility = Get-ScUtillPath
    & $scUtility delete $serviceName
}

# Get path to sc.exe
function Get-ScUtillPath
{
    return "$env:windir\system32\sc.exe"
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

    $installUtility = Get-InstallUtilPath
    & $installUtility /u $ServiceExecutablePath

    Remove-Item $ServiceExecutablePath -Force -ErrorAction SilentlyContinue
    Remove-Item *.InstallLog -Force -ErrorAction SilentlyContinue
    Remove-Item $ServiceName -Force -Recurse -ErrorAction SilentlyContinue
}

<#
.Synopsis
Starts a service with given arguments if it is not already started logging the result
#>
function StartTestService
{
    param ([parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $name)

    $testService = Get-Service -Name $name

    if ($testService.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running)
    {
        Write-Verbose ($global:serviceLocalizedData.ServiceAlreadyStarted -f $testService.Name)
        return
    }

    try
    {
        $testService.Start()
        $twoSeconds = New-Object timespan 20000000
        $testService.WaitForStatus("Running", $twoSeconds) 
    }
    catch
    {
        Write-Verbose ($global:serviceLocalizedData.ErrorStartingService -f $testService.Name, $_.Exception.Message)
        throw
    }

    Write-Verbose ($global:serviceLocalizedData.ServiceStarted -f $testService.Name)
}

function ServiceExistMessage
{

    param (
        [ValidateNotNullOrEmpty()]
        [System.String] $name, 


        [ValidateNotNullOrEmpty()]
        [System.String] $path)

    if($path -ne $null -and $path -ne '')
    {
        return $global:serviceLocalizedData.ServiceExistsSamePath -f $name,$path
    }
    return $global:serviceLocalizedData.ServiceAlreadyExists -f $name
}

function ServiceDontExistMessage
{

    param (
        [ValidateNotNullOrEmpty()]
        [System.String] $name)

    return $global:serviceLocalizedData.ServiceNotExists -f $name
}

#Set Service state
function SetServiceState
{
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $name, 

        [System.String]
        [ValidateSet("Stopped", "Paused", "Running")]
        $status)

    switch ($status)
    {
        "Stopped"
        {
            Stop-Service -Name $name -Force -Verbose
        }

        "Paused"
        {
            Set-Service -Name $name -Status Paused -Verbose 
        }

        "Running"
        {
            Start-Service -Name $name -verbose
        }
    }

    TryForAWhile {(Get-Service -Name $name | Select -exp Status) -eq $status} -seconds 10
}

# Set the Service startType
function SetServiceStartType
{
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $name,

        [System.String]
        [ValidateSet("Automatic", "Disabled", "Manual")]
        $startType)

    Stop-Service -Name $name -Force -Verbose
    TryForAWhile {(Get-Service -Name $name | Select -exp Status) -eq "Stopped"} -seconds 10

    Set-Service -Name $name -StartupType $startType 
    if (($startType -ieq "Automatic") -or ($startType -ieq "Automatic"))
    {
        Start-Service -Name $name -Verbose
    }
}

<# Set credentials on a service
# For LocalSystem set userPassword = ""
# For "NT AUTHORITY\NetworkService" set userPassword = "" 
#>
function SetServiceCredentialBuiltIn 
{
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$name,
        [System.String]$userName,
        [System.String]$userPassword,
        [System.String] $targetComputer = "localhost")

    $service = (Get-CimInstance -ComputerName $targetComputer -Class win32_service | where {$_.Name -eq $name})

    if ($service -ne $null)
    {
        $changeArguments =  @{
            StartName = $userName ;
            StartPassword = $userPassword ;
        }
        Invoke-CimMethod -InputObject $service -MethodName Change -Arguments $changeArguments
        
        if ($service.StartMode -ne "Disabled")
        {
            Restart-Service -Name $name
        }
    }
    else
    {
        Write-Host "Service doesn't exist"
    }
}

# Set credentials on a service
function SetServiceCredentials
{
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$name,
        [System.String] $userDomainAndName,
        [System.String] $userPassword,
        [System.Management.Automation.PSCredential] $credential)

    if ($credential -eq $null)
    {
        $userCredential = $userDomainAndName.Split("\")
        $credential = CreateDomainCredential `
        -userDomainNetBIOS $userCredential[0] `
        -userName $userCredential[1] `
        -userPassword $userPassword
    }

    Set-TargetResource -Name $name -Credential $credential

    $global:serviceCredential = $credential

    # Verify service is using the specified credentials
    $testService = (Get-CimInstance -Class win32_service | where {$_.Name -eq $name})
    Assert ($testService.StartName -ieq $userDomainAndName) "Fail: Credential was not set to expected username"
}

# Wait for a specified state
function TryForAwhile ([ScriptBlock] $predicate, [Int]$seconds = 5)
{
    do 
    {
        $value = & $predicate
        Start-Sleep -s 1
    }  while (!$value -and $seconds-- -gt 0)

    return $value
}

# Extract and remap bound parameters
function ExtractArguments
{
    param ($functionBoundParameters,
        [System.String[]]$argumentNames,
        [System.String[]]$newArgumentNames)

    $returnValue = @{}
    for ($counter = 0; $counter -lt $argumentNames.Count; $counter ++)
    {
        $argumentName = $argumentNames[$counter]

        if ($newArgumentNames -eq $null)
        {
            $newArgumentName = $argumentName
        }
        else
        {
            $newArgumentName = $newArgumentNames[$counter]
        }

        if ($functionBoundParameters.ContainsKey($argumentName))
        {
            $null = $returnValue.Add($newArgumentName, $functionBoundParameters[$argumentName])
        }
    }

    return $returnValue
}

<############################################################################################ 
# Name:        CreateServiceInstanceMof
# Description: Configure instance .mof file
############################################################################################> 
function CreateServiceInstanceMof
{
    param (
        [System.String] $configurationName, 
        [System.String] $resourceId, 
        [System.String] $name,
        [System.String] $startupType,
        [System.String] $builtInAccount,
        [System.String] $userNameAndDomain,
        [System.String] $userPassword,
        [System.String] $state,
        [System.String] $targetComputer = "localhost")

    $outputScriptFullPath = "$global:end2EndScriptPath{0}$global:suffix{2}" -f ("\", "_", "_script.ps1")
    $configurationName = $configurationName.Replace(".", "_")

    # Ensure script path exists
    if (!(Test-Path $end2EndScriptPath))
    {
        New-Item -Path $end2EndScriptPath -type directory -Force
    }

    # Remove existing script file
    if (Test-Path $outputScriptFullPath)
    {
        Remove-Item -Path $outputScriptFullPath -Force
    }

    # Set userNameAndDomain parameter {3}
    if ($PSBoundParameters.ContainsKey("userNameAndDomain"))
    {
        $userNameAndDomainSpecified = $userNameAndDomain
    }
    else
    {
        $userNameAndDomainSpecified = ""
    }

    # Set userPassword parameter {4}
    if ($PSBoundParameters.ContainsKey("userPassword"))
    {
        $userPasswordSpecified = $userPassword
    }
    else
    {
        $userPasswordSpecified = ""
    }

    # Set startupType parameter {6}
    if ($PSBoundParameters.ContainsKey("startupType"))
    {
        $startupTypeSpecified = "StartupType = `"$startupType`""
    }
    else
    {
        $startupTypeSpecified = ""
    }

    # Set builtInAccount parameter {7}
    if ($PSBoundParameters.ContainsKey("builtInAccount"))
    {
        $builtInAccountSpecified = "BuiltInAccount = `"$builtInAccount`""
    }
    else
    {
        $builtInAccountSpecified = ""
    }

    $scriptText = @"
`$userName = `"`"

if (`"{4}`" -ne [String]::Empty)
{{
  `$userName = '{4}'
  `$securePassword = ConvertTo-SecureString -AsPlainText {3} -Force
  [System.Management.Automation.PSCredential] `$secureCredential = New-Object System.Management.Automation.PSCredential -ArgumentList `$userName, `$securePassword

    configuration {1}
    {{ 
        node `"{10}`"
        {{
            Service {2}
            {{
                Name = `"{5}`"
                State = `"{9}`"
                Credential = `$secureCredential
                {6}
                {7}
                {8}      
            }}
        }}
    }}

    `$Global:AllNodes=
@{{
    AllNodes = @(     
                    @{{  
                    NodeName = `"{10}`";
                    RecurseValue = `$true;
                                    PSDscAllowPlainTextPassword = `$true;
                    }};                                                                                     
                );    
}}
    {1} -output `"{0}\{2}`" -ConfigurationData `$Global:AllNodes
}}
else
{{
    configuration {1}
    {{ 
        node `"{10}`"
        {{
            Service {2}
            {{
                Name = `"{5}`"
                State = `"{9}`"
                {6}
                {7}
                {8}     
            }}
        }}
    }}

    {1} -output `"{0}\{2}`"
}}

"@ -f ($global:end2EndScriptPath, $configurationName, $resourceId, $userPasswordSpecified, $userNameAndDomainSpecified, $name, "", $startupTypeSpecified, $builtInAccountSpecified, $state, $targetComputer) 

    # Save the scriptText to a file
    $scriptText > $outputScriptFullPath
    
    $scriptBlock = [ScriptBlock]::Create($scriptText)
    Invoke-Command -ScriptBlock $scriptBlock -Verbose
}

<############################################################################################ 
# Test execution methods
#############################################################################################>

<############################################################################################ 
# 
# Name:        ExecuteStartDscConfiguration
# Description: Execute the DSC engine in synchronus mode.
#
############################################################################################>
function ExecuteStartDscConfiguration
{
    param (
        [System.String] $path,
        [System.String[]] $computerName)
    try
    {
        log "Running: Start-DSCConfiguration -Path $path -ComputerName $computerName -Verbose -Wait -ErrorAction Stop"
        $result = Start-DSCConfiguration -Path $path -ComputerName $computerName -Verbose -Wait -ErrorAction Stop -Force
    }
    catch
    {
        if ($throw)
        {
            throw
        }
            
        log -warning -message ($_.Exception)
        return $_.Exception
    }
}

<############################################################################################ 
# 
# Name:        ExecuteTestDscConfiguration
# Description: Execute Test DscConfiguration
#
############################################################################################>
function ExecuteTestDscConfigurationService
{
    param (
        [bool] $expectedRunningStateValue,
        [bool]  $expectedStoppedStateValue,
        [String] $state,
        [String] $targetMachine,
        [PSCredential]$credential = $null)

    try
    {
        if ($targetMachine)
        {
            #$session = CimSessionGeneratorEx -targetMachine $targetMachine -credential $credential
            $session = CimSessionGeneratorEx -targetMachine Get-TargetServerMachine -credential $credential
            $testResult = Test-DscConfiguration -CimSession $session -Verbose -ErrorAction Stop 
        }
        else
        {
            $testResult = Test-DscConfiguration -Verbose -ErrorAction Stop 
        }

        Log "testResult: $testResult"
        
        if ($state -ieq "Running")
        {
           Assert ($testResult -eq $expectedRunningStateValue) ("Fail| Test-DscConfiguration |Running|Actual value: " + $testResult)
        }
        else
        {
            Assert ($testResult -eq $expectedStoppedStateValue) ("Fail| Test-DscConfiguration |Stopped|Actual value: " + $testResult)
        }
    }
    catch
    {
        if ($throw)
        {
            throw
        }
            
        log -warning -message ($_.Exception)
    }
}

<############################################################################################ 
# 
# Name:        ExecuteGetDscConfigurationService
# Description: Execute Get-DscConfiguration
#
############################################################################################>
function ExecuteGetDscConfigurationService
{
    param ([System.String] $name,
        [System.String] $startupType,
        [System.String] $builtInAccount,
        [System.String] $state,
        [System.String] $path,
        [System.String] $displayName,
        [System.String] $description,
        [System.String[]] $dependencies,
        [System.String] $targetMachine,
        [PSCredential]$credential = $null)

    try
    {
        if ($targetMachine)
        {
            $session = CimSessionGeneratorEx -targetMachine $targetMachine -credential $credential
            $getResult = Get-DscConfiguration -CimSession $session -Verbose -ErrorAction Stop 
        }
        else
        {
            $getResult = Get-DscConfiguration -Verbose -ErrorAction Stop
        }

        Log "getResult: $getResult"
        Assert ($getResult.Name -ieq $name) ("Fail: getResult.Name - Actual value: " + $getResult.Name)
        Assert ($getResult.State -ieq $state) ("Fail: getResult.Ensure - Actual value: " + $getResult.State)


        if ($PSBoundParameters.ContainsKey("startupType"))
        {
            Assert ($getResult.StartupType -ieq $startupType) ("Fail: getResult.StartupType - Actual value: " + $getResult.StartupType)
        }

        if ($PSBoundParameters.ContainsKey("builtInAccount"))
        {
            Assert ($getResult.BuiltInAccount -ieq $builtInAccount) ("Fail: getResult.Path - Actual value: " + $getResult.BuiltInAccount)
        }

        if ($PSBoundParameters.ContainsKey("path"))
        {
            Assert ($getResult.Path -ieq $path) ("Fail: getResult.Path - Actual value: " + $getResult.Path)
        }

        if ($PSBoundParameters.ContainsKey("displayName"))
        {
            Assert ($getResult.DisplayName -ieq $displayName) ("Fail: getResult.Path - Actual value: " + $getResult.DisplayName)
        }

        if ($PSBoundParameters.ContainsKey("displayName"))
        {
            Assert ($getResult.Description -ieq $displayName) ("Fail: getResult.Path - Actual value: " + $getResult.Description)
        }

        if ($PSBoundParameters.ContainsKey("dependencies"))
        {
            Assert ($getResult.Dependencies -ieq $dependencies) ("Fail: getResult.Path - Actual value: " + $getResult.Dependencies)
        }
    }
    catch
    {
        if ($throw)
        {
            throw
        }
            
        log -warning -message ($_.Exception)
    }

}

<############################################################################################ 
# 
# Name:        ExecuteSetTargetResource
# Description: This is a wrapper method used to test Set functionality of Environment provider.
#
############################################################################################>
function ExecuteSetTargetResource
{
    param ([System.String] $name,
        [System.String] $startupType,
        [System.String] $builtInAccount,
        [System.Management.Automation.PSCredential] $credential,
        [System.String] $state, 
        [System.String] $path, 
        [System.String] $displayName,
        [System.String] $description, 
        [System.String] $dependencies,
        [System.String] $ensure)

    $measuredTime = Measure-Command {$result = MSFT_ServiceResource\Set-TargetResource @PSBoundParameters -Verbose}
    Write-Host $measuredTime.TotalMilliseconds
    $result
}

<############################################################################################ 
# 
# Name:        ExecuteGetTargetResource
# Description: This is a wrapper method used to test Get functionality of Environment provider.
#
############################################################################################>
function ExecuteGetTargetResource
{
    param ([System.String] $name)

    $measuredTime = Measure-Command {$result = MSFT_ServiceResource\Get-TargetResource @PSBoundParameters -Verbose}
    Write-Host $measuredTime.TotalMilliseconds
    $result
}
 
<############################################################################################ 
# 
# Name:        ExecuteTestTargetResource
# Description: This is a wrapper method used to test Test functionality of Environment provider.
#
############################################################################################>

# Execute test with transcript
function ExecuteTestTargetResourceWithSnapshot 
{
    param ([System.String] $name,
        [System.String] $startupType,
        [System.String] $builtInAccount,
        [System.Management.Automation.PSCredential] $credential,
        [System.String] $state,
        [System.String] $snapshotFilePath, 
        [System.String] $ensure)

    $inputParameters = ExtractArguments $PSBoundParameters ("name", "startupType", "builtInAccount", "credential", "state", "ensure")
    
    Start-Transcript -LiteralPath $snapshotFilePath
    $measuredTime = Measure-Command {$result = MSFT_ServiceResource\Test-TargetResource @inputParameters -Verbose}
    Stop-Transcript
    
    Write-Host $measuredTime.TotalMilliseconds
    $result  
}

# Execute Test with Measure-Command
function ExecuteTestTargetResource
{
    param ([System.String] $name,
        [System.String] $startupType,
        [System.String] $builtInAccount,
        [System.Management.Automation.PSCredential] $credential,
        [System.String] $state,
        [System.String] $snapshotFilePath, 
        [System.String] $ensure, 
        [System.String] $path)

    $inputParameters = ExtractArguments $PSBoundParameters ("name", "startupType", "builtInAccount", "credential", "state", "ensure", "path")
    $measuredTime = Measure-Command {$result = MSFT_ServiceResource\Test-TargetResource @inputParameters -Verbose}
    Write-Host $measuredTime.TotalMilliseconds
    $result
}
<############################################################################################ 
# 
# Name:        ExecuteServiceProviderWithLoggingCaptured
# Description: This is a wrapper method used to test logging functionality of Service provider.
#
############################################################################################>
function ExecuteServiceProviderWithLoggingCaptured
{
    param ([System.String] $name,
        [System.String] $startupType,
        [System.String] $builtInAccount,
        [System.String] $userNameAndDomain,
        [System.String] $userPassword,
        [System.String] $state,
        [System.String] $providerType,
        [System.Boolean] $whatIfFlag,
        [System.String] $fileSuffix)

    $outputFileFullPath = "$global:whatIfScriptPath{0}$global:suffix{2}" -f ("\", "_", "_out.txt")
    $outputScriptFullPath = "$global:whatIfScriptPath{0}$global:suffix{2}" -f ("\", "_", "_script.ps1")

    # Ensure script path exists
    if (!(Test-Path $global:whatIfScriptPath))
    {
        New-Item -Path $global:whatIfScriptPath -type directory -Force
    }

    # Remove existing output file
    if (Test-Path $outputFileFullPath)
    {
        Remove-Item $outputFileFullPath
    }

    # Remove existing script file
    if (Test-Path $outputScriptFullPath)
    {
        Remove-Item $outputScriptFullPath
    }

    # Set WhatIf or Verbose flags {9}
    if ($whatIfFlag)
    {
        $flag = "-WhatIf"
    }
    else
    {
        $flag = ""
    }

    # Set userNameAndDomain parameter {3}
    if ($PSBoundParameters.ContainsKey("userNameAndDomain"))
    {
        $userNameAndDomainSpecified = $userNameAndDomain
    }
    else
    {
        $userNameAndDomainSpecified = ""
    }

    # Set userPassword parameter {4}
    if ($PSBoundParameters.ContainsKey("userPassword"))
    {
        $userPasswordSpecified = $userPassword
    }
    else
    {
        $userPasswordSpecified = ""
    }

    # Set startupType parameter {6}
    if ($PSBoundParameters.ContainsKey("startupType"))
    {
        $startupTypeSpecified = "-startupType $startupType"
    }
    else
    {
        $startupTypeSpecified = ""
    }

    # Set builtInAccount parameter {7}
    if ($PSBoundParameters.ContainsKey("builtInAccount"))
    {
        $builtInAccountSpecified = "-builtInAccount $builtInAccount"
    }
    else
    {
        $builtInAccountSpecified = ""
    }

    # Ensure with Get {8}
    if ($providerType -eq "Get")
    {
        $stateSpecified = ""
    }
    else
    {
        $stateSpecified = "-State $state"
    }

    # Create script
    $scriptText = @"
Start-Transcript -LiteralPath {0}
Import-Module `$pshome\modules\PSDesiredStateConfiguration\DSCResources\MSFT_ServiceResource\MSFT_ServiceResource.psm1 -Force

`$userName = `"`"

if (`"{2}`" -ne [String]::Empty)
{{
  `$userName = '{2}'
  `$securePassword = ConvertTo-SecureString -AsPlainText {1} -Force
  [System.Management.Automation.PSCredential] `$secureCredential = New-Object System.Management.Automation.PSCredential -ArgumentList `$userName, `$securePassword
  {3}-TargetResource -Name '{4}' {5} {6} {7} {8} {9} -Credential `$secureCredential -Verbose
}}
else
{{
    
    {3}-TargetResource -Name '{4}' {5} {6} {7} {8} {9} -Verbose
}}

# Uncomment following lines for visual debugging. Subsequent tests may be blocked when uncommented.
#Write-Host 'Visual Debugging'
#Start-Sleep -Seconds 4

Stop-Transcript

"@ -f ($outputFileFullPath, $userPasswordSpecified, $userNameAndDomainSpecified, $providerType, $name, "", $startupTypeSpecified, $builtInAccountSpecified, $stateSpecified, $flag)

    $scriptText > $outputScriptFullPath

    # Execute script
    Start-Process "powershell.exe" -ArgumentList  "/c $outputScriptFullPath" -Wait
}

<############################################################################################ 
# Test verification methods
#############################################################################################>

<############################################################################################ 
# 
# Name:        VerifyGetTargetResource
# Description: This method is used to verify Get_TargetResource of the Environment provider.
#
############################################################################################>
function VerifyGetTargetResourceResults
{
    param (
        $getResults,
        [System.String] $state,
        [System.String] $name,
        [System.String] $expectedPath,
        [System.String] $expectedStatus, 
        [System.String] $expectedDisplayName,
        [System.String] $expectedDependencies,
        [System.String] $expectedStartMode,
        [System.String] $expectedStartName,
        [System.String] $expectedDescription)

    AssertEquals $getResults.Path $expectedPath ($assertMessage -f ("Path"))                                                                                                          
    AssertEquals $getResults.Dependencies $expectedDependencies ($assertMessage -f ("Dependencies"))                                                                                                                                                                                                                                                                                                                                          
    AssertEquals $getResults.DisplayName $expectedDisplayName($assertMessage -f ("DisplayName"))                                                                                                                                                                          
    AssertEquals $getResults.Description $expectedDescription ($assertMessage -f ("Description"))                                                                                                                                                       
    AssertEquals $getResults.Name $name ($assertMessage -f ("Name"))                                                                                                                                                               
    AssertEquals $getResults.StartupType $expectedStartMode ($assertMessage -f ("StartupType"))                                                                                                                                                                                                                                                                                                                                              
    AssertEquals $getResults.BuiltInAccount $expectedStartName ($assertMessage -f ("BuiltInAccount")) 

    AssertEquals $getResults.State $expectedStatus ($assertMessage -f ("Status")) 

    switch ($expectedStatus)
    {
        "Stopped"
        {
            AssertEquals $getResults.State "Stopped" ($assertMessage -f ("State")) 
        }

        "Paused"
        {
            AssertEquals $getResults.State "Paused" ($assertMessage -f ("State")) 
        }

        "Running"
        {
            AssertEquals $getResults.State "Running" ($assertMessage -f ("State")) 
        }
    }
}
   
<############################################################################################ 
# 
# Name:        VerifySetTargetResource
# Description: This method is used to verify Set_TargetResource of the Environment provider.
#
############################################################################################>
function VerifySetTargetResourceResults
{
    param ([System.String] $name,
        [System.String] $startupType,
        [System.String] $builtInAccount,
        [System.Management.Automation.PSCredential] $credential,
        [System.String] $state,
        [System.String] $expectedArguments,
        [System.String] $expectedStartupTypeAbsent,
        [System.String] $expectedStartupTypePresent,
        [System.String] $expectedBuiltInAccount,
        [System.String] $expectedCredentials,
        [System.String] $expectedName,
        [System.String] $testLogFile,
        [System.String] $targetComputer = "localhost")

    $inputParameters = ExtractArguments $PSBoundParameters ("name", "", "startupType", "builtInAccount", "credential", "state")

    # Get Service through CIM to verify all settings
    $testService = (Get-CimInstance -ComputerName $targetComputer -Class win32_service | where {$_.Name -eq $name})

    # Status "OK" "Error" "Degraded" "Unknown" "Pred Fail" "Starting" "Stopping" "Service"
    Write-Host $testService.Status

    # StartMode: "Boot" "System" "Auto" "Manual" "Disabled"

    # State "Stopped" "Start Pending" "Stop Pending" "Running" "Continue Pending" "Pause Pending" "Paused" "Unknown"
    if ($state -eq "Stopped")
    {
        AssertEquals $testService.StartMode $expectedStartupTypeAbsent "Fail: StartupType must not be 'Automatic' when State is 'Stopped'"
        AssertEquals $testService.State "Stopped" "Fail: State must be 'Stopped' when Ensure is 'Stopped'"
    }
    else
    {
        AssertEquals $testService.StartMode $expectedStartupTypePresent "Fail: StartupType must not be 'Disabled' when State is 'Running'"
        AssertEquals $testService.State "Running" "Fail: State must be 'Running' when State is 'Running'"

        if ($inputParameters.ContainsKey("BuiltInAccount"))
        {
            AssertEqualsCaseInsensitive $testService.StartName $expectedBuiltInAccount "Fail: BuiltInAccount did not match expected"
        }

        if ($inputParameters.ContainsKey("credential"))
        {
            AssertEqualsCaseInsensitive $testService.StartName $expectedCredentials "Fail: Credentials did not match expected"
        }
    }
}

<############################################################################################ 
# 
# Name:        VerifyTestTargetResourceResults
# Description: This method is used to verify Test_TargetResource of the Service provider.
#
############################################################################################>
function VerifyTestTargetResourceResults
{
    param ($testResult,
        [bool] $expectedResultWhenEnsurePresent,
        [bool] $expectedResultWhenEnsureAbsent,
        [System.String] $state)

    if ($state -eq "Stopped")
    {
        AssertEquals $testResult $expectedResultWhenEnsureAbsent $serviceIsNotAbsentAsExpected
    }
    else
    {
        AssertEquals $testResult $expectedResultWhenEnsurePresent $serviceIsNotPresentAsExpected
    }   
}

<############################################################################################ 
# 
# Name:        VerifyLoggingSetTargetResource
# Description: This method is used to verify logging in Set_TargetResource of the Service provider.
#
############################################################################################>
function VerifyLoggingSetTargetResourceResults
{
    param ([System.String] $name,
        [System.String] $value,
        [System.String] $state,
        [System.Boolean] $path,
        [System.Boolean] $whatIfFlag,
        [System.String] $fileSuffix,
        [System.String] $expectedEnsureAbsentMessage,
        [System.String] $expectedEnsureAbsentMessage2,
        [System.String] $expectedEnsurePresentMessage,
        [System.String] $expectedEnsurePresentMessage2)

    $outputFileFullPath = "$global:whatIfScriptPath{0}$global:suffix{2}" -f ("\", "_", "_out.txt")

    TryForAWhile {(Test-Path -LiteralPath $outputFileFullPath -ErrorAction SilentlyContinue) -eq $null} 

    if ($state -eq "Stopped")
    {
        $expectedMessage = $expectedEnsureAbsentMessage
        $expectedMessage2 = $expectedEnsureAbsentMessage2
    }
    else
    {
        $expectedMessage = $expectedEnsurePresentMessage
        $expectedMessage2 = $expectedEnsurePresentMessage2
    }

    Write-Host "ExpectedMessage: |$expectedMessage|"
    Write-Host "ExpectedMessage2: |$expectedMessage2|"

    $content = Get-Content $outputFileFullPath -Raw -ErrorAction SilentlyContinue
    if ($content -eq $null)
    {
        Assert $false "Fail: Content is null"
    }
    else
    {
        $content = $content.Replace("`r`n", "").Replace("`n", "") 
        $whatIfResult = $content.ToString().IndexOf($expectedMessage, [StringComparison]::OrdinalIgnoreCase) -ne -1
        Assert ($whatIfResult) "Fail: Expected message was not found"

        if ($expectedMessage2 -ne [String]::Empty)
        {
            $whatIfResult = $content.ToString().IndexOf($expectedMessage2, [StringComparison]::OrdinalIgnoreCase) -ne -1
            Assert ($whatIfResult) "Fail: Expected message2 was not found"
        }
    }
}

# Execute TestWhatIf (Unit tests)
function TestWhatif([String] $scriptToRun, [String]$stringToFind)
{
    $transcriptPath = "..\TestWhatif_transcript.txt"
    del $transcriptPath -ErrorAction SilentlyContinue
    $scriptPath = "..\TestWhatif.ps1"
    $scriptText = @"
    start-transcript {0}
    Import-Module $pshome\modules\PSDesiredStateConfiguration\DSCResources\MSFT_ServiceResource\MSFT_ServiceResource.psm1 -Force
    {1}
    stop-transcript

"@ -f ($transcriptPath, $scriptToRun)

    $scriptText > $scriptPath
    Start-Process "powershell.exe" -ArgumentList  "/c $scriptText" -Wait
        
    $predicate = @'
        $content = Get-Content "{0}" -Raw -ErrorAction SilentlyContinue
        if($content -eq $null)
        {{
            $false
        }}
        else
        {{
            $content = $content.Replace("`r`n", "").Replace("`n", "") 
            $content.ToString().IndexOf("{1}", [StringComparison]::OrdinalIgnoreCase) -ne -1
        }}
'@ -f ($transcriptPath, $stringToFind)

    if (!(TryForAWhile ([ScriptBlock]::create($predicate))))
    {
        throw "did not find message: $stringToFind in transcript $(Get-Content $transcriptPath -Raw)"
    }
}