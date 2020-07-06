[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param ()

$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

<#
    Cache the AppVeyor Administrator credential so that we do not reset the password multiple times
    if retrieved the credential is requested multiple times.
#>
$script:appVeyorAdministratorCredential = $null

<#
    This is the name of the magic file that will be written to the .git folder
    in DSCResource.Tests to determine the last time it was updated.
#>
$script:dscResourceTestsMagicFile = 'DSC_LAST_FETCH'

<#
    This is the number of minutes after which the DSCResource.Tests
    will be updated.
#>
$script:dscResourceTestsRefreshAfterMinutes = 120

<#
    String data for unit test names to be used with the generic test functions.
    Maps command names to the appropriate test names to insert when checking that
    the correct mocks are called.
    In the future we will move this data out of the commonTestHelper file and into the
    corresponding test file or its own file. For now, it is much easier to access this
    way rather than passing it around.
#>
data testStrings
{
    ConvertFrom-StringData -StringData @'
Assert-FileHashValid = assert that the file hash is valid
Assert-FileSignatureValid = assert that the file signature is valid
Assert-FileValid = assert that the file is valid
Assert-PathExtensionValid = assert that the specified path extension is valid
Close-Stream = close the stream
Convert-PathToUri = convert the path to a URI
Convert-ProductIdToIdentifyingNumber = convert the product ID to the identifying number
Copy-ResponseStreamToFileStream = copy the response to the outstream
Get-ItemProperty = retrieve {0}
Get-MsiProductCode = retrieve the MSI product code
Get-ProductEntry = retrieve the product entry
Get-ProductEntryInfo = retrieve the product entry info
Get-ProductEntryValue = retrieve the value of the product entry property
Get-ScriptBlock = retrieve the script block
Get-WebRequest = retrieve the WebRequest object
Get-WebRequestResponse = retrieve the web request response
Get-WebRequestResponseStream = retrieve the WebRequest response stream
Invoke-CimMethod = attempt to invoke a cim method to check if reboot is required
Invoke-PInvoke = attempt to {0} the MSI package under the user
Invoke-Process = attempt to {0} the MSI package under the process
New-Item = create a new {0}
New-LogFile = create a new log file
New-Object = create a new {0}
New-PSDrive = create a new PS Drive
Remove-Item = remove {0}
Remove-PSDrive = remove the PS drive
Start-MsiProcess = start the MSI process
Test-Path = test that the path {0} exists
'@
}

<#
    .SYNOPSIS
        Retrieves the name of the test for asserting that the given function is called.

    .PARAMETER IsCalled
        Indicates whether the function should be called or not.

    .PARAMETER Custom
        An optional string to include in the test name to make the name more descriptive.
        Can only be used by commands that have a variable in their string data name.
#>
function Get-TestName
{
    [OutputType([System.String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Command,

        [Parameter()]
        [System.Boolean]
        $IsCalled = $true,

        [Parameter()]
        [System.String]
        $Custom = ''
    )

    $testName = ''

    if (-not [System.String]::IsNullOrEmpty($Custom))
    {
        $testName = ($testStrings.$Command -f $Custom)
    }
    else
    {
        $testName = $testStrings.$Command
    }

    if ($IsCalled)
    {
        return 'Should ' + $testName
    }
    else
    {
        return 'Should not ' + $testName
    }
}

<#
    .SYNOPSIS
        Tests that each mock in MocksCalled is called the expected number of times.

    .PARAMETER MocksCalled
        An array of the mocked commands that should be called or not called.
        Each item in the array is a hashtable that contains the name of the command
        being mocked and the number of times it is called (can be 0).
#>
function Invoke-ExpectedMocksAreCalledTest
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.Collections.Hashtable[]]
        $MocksCalled
    )

    foreach ($mock in $MocksCalled)
    {
        $testName = Get-TestName -Command $mock.Command -IsCalled $mock.Times

        if ($mock.Keys -contains 'Custom')
        {
            $testName = Get-TestName -Command $mock.Command -IsCalled $mock.Times -Custom $mock.Custom
        }

        It $testName {
            Assert-MockCalled -CommandName $mock.Command -Exactly $mock.Times -Scope 'Context'
        }
    }
}

<#
    .SYNOPSIS
        Performs generic tests for the given function, including checking that the
        function does not throw and checking that all mocks are called the expected
        number of times.

    .PARAMETER Function
        The function to be called. Must be in format:
        { Param($hashTableOfParamsToPass) Function-Name @hashTableOfParamsToPass }
        For example:
        { Param($testLogPath) New-LogFile $script:testPath }
        or
        { Param($startMsiProcessParameters) Start-MsiProcess @startMsiProcessParameters }

    .PARAMETER FunctionParameters
        The parameters that should be passed to the function for this test. Should match
        what is passed in the Function parameter.

    .PARAMETER MocksCalled
        An array of the mocked commands that should be called for this test.
        Each item in the array is a hashtable that contains the name of the command
        being mocked, the number of times it is called (can be 0) and, optionally,
        an extra custom string to make the test name more descriptive. The custom
        string will only work if the command has a corresponding variable in the
        string data name.

    .PARAMETER ShouldThrow
        Indicates whether the function should throw or not. If this is set to True
        then ErrorMessage and ErrorTestName should also be passed.

    .PARAMETER ErrorMessage
        The error message that should be thrown if the function is supposed to throw.

    .PARAMETER ErrorTestName
        The string that should be used to create the name of the test that checks for
        the correct error being thrown.
#>
function Invoke-GenericUnitTest
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ScriptBlock]
        $Function,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $FunctionParameters,

        [Parameter()]
        [System.Collections.Hashtable[]]
        $MocksCalled,

        [Parameter()]
        [System.Boolean]
        $ShouldThrow = $false,

        [Parameter()]
        [System.String]
        $ErrorMessage = '',

        [Parameter()]
        [System.String]
        $ErrorTestName = ''
    )

    if ($ShouldThrow)
    {
        It "Should throw an error for $ErrorTestName" {
            { $null = $($Function.Invoke($FunctionParameters)) } | Should -Throw -ExpectedMessage $ErrorMessage
        }
    }
    else
    {
        It 'Should not throw' {
            { $null = $($Function.Invoke($FunctionParameters)) } | Should -Not -Throw
        }
    }

    Invoke-ExpectedMocksAreCalledTest -MocksCalled $MocksCalled
}

<#
    .SYNOPSIS
        Performs generic tests for Get-TargetResource, including checking that the
        function does not throw, checking that all mocks are called the expected
        number of times, and checking that the correct result is returned. If the function
        is expected to throw, then this function should not be used.

    .PARAMETER GetTargetResourceParameters
        The parameters that should be passed to Get-TargetResource for this test.

    .PARAMETER MocksCalled
        An array of the mocked commands that should be called for this test.
        Each item in the array is a hashtable that contains the name of the command
        being mocked, the number of times it is called (can be 0) and, optionally,
        an extra custom string to make the test name more descriptive. The custom
        string will only work if the command has a corresponding variable in the
        string data name.

    .PARAMETER ExpectedReturnValue
        The expected hashtable that Get-TargetResource should return for this test.
#>
function Invoke-GetTargetResourceUnitTest
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $GetTargetResourceParameters,

        [Parameter()]
        [System.Collections.Hashtable[]]
        $MocksCalled,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $ExpectedReturnValue
    )

    It 'Should not throw' {
        { $null = Get-TargetResource @GetTargetResourceParameters } | Should -Not -Throw
    }

    Invoke-ExpectedMocksAreCalledTest -MocksCalled $MocksCalled

    $getTargetResourceResult = Get-TargetResource @GetTargetResourceParameters

    It 'Should return a Hashtable' {
        $getTargetResourceResult -is [System.Collections.Hashtable] | Should -BeTrue
    }

    It "Should return a Hashtable with $($ExpectedReturnValue.Keys.Count) properties" {
        $getTargetResourceResult.Keys.Count | Should -Be $ExpectedReturnValue.Keys.Count
    }

    foreach ($key in $ExpectedReturnValue.Keys)
    {
        It "Should return a Hashtable with the $key property as $($ExpectedReturnValue.$key)" {
           $getTargetResourceResult.$key | Should -Be $ExpectedReturnValue.$key
        }
    }
}

<#
    .SYNOPSIS
        Performs generic tests for Set-TargetResource, including checking that the
        function does not throw and checking that all mocks are called the expected
        number of times.

    .PARAMETER SetTargetResourceParameters
        The parameters that should be passed to Set-TargetResource for this test.

    .PARAMETER MocksCalled
        An array of the mocked commands that should be called for this test.
        Each item in the array is a hashtable that contains the name of the command
        being mocked, the number of times it is called (can be 0) and, optionally,
        an extra custom string to make the test name more descriptive. The custom
        string will only work if the command has a corresponding variable in the
        string data name.

    .PARAMETER ShouldThrow
        Indicates whether Set-TargetResource should throw or not. If this is set to True
        then ErrorMessage and ErrorTestName should also be passed.

    .PARAMETER ErrorMessage
        The error message that should be thrown if Set-TargetResource is supposed to throw.

    .PARAMETER ErrorTestName
        The string that should be used to create the name of the test that checks for
        the correct error being thrown.
#>
function Invoke-SetTargetResourceUnitTest
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $SetTargetResourceParameters,

        [Parameter()]
        [System.Collections.Hashtable[]]
        $MocksCalled,

        [Parameter()]
        [System.Boolean]
        $ShouldThrow = $false,

        [Parameter()]
        [System.String]
        $ErrorMessage = '',

        [Parameter()]
        [System.String]
        $ErrorTestName = ''
    )

    if ($ShouldThrow)
    {
        It "Should throw an error for $ErrorTestName" {
            { $null = Set-TargetResource @SetTargetResourceParameters } | Should -Throw -ExpectedMessage $ErrorMessage
        }
    }
    else
    {
        It 'Should not throw' {
            { $null = Set-TargetResource @SetTargetResourceParameters } | Should -Not -Throw
        }
    }

    Invoke-ExpectedMocksAreCalledTest -MocksCalled $MocksCalled
}

<#
    .SYNOPSIS
        Performs generic tests for Test-TargetResource, including checking that the
        function does not throw, checking that all mocks are called the expected
        number of times, and checking that the correct result is returned. If the function
        is expected to throw, then this function should not be used.

    .PARAMETER TestTargetResourceParameters
        The parameters that should be passed to Test-TargetResource for this test.

    .PARAMETER MocksCalled
        An array of the mocked commands that should be called for this test.
        Each item in the array is a hashtable that contains the name of the command
        being mocked, the number of times it is called (can be 0) and, optionally,
        an extra custom string to make the test name more descriptive. The custom
        string will only work if the command has a corresponding variable in the
        string data name.

    .PARAMETER ExpectedReturnValue
        The expected boolean value that should be returned
#>
function Invoke-TestTargetResourceUnitTest
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $TestTargetResourceParameters,

        [Parameter()]
        [System.Collections.Hashtable[]]
        $MocksCalled,

        [Parameter(Mandatory = $true)]
        [System.Boolean]
        $ExpectedReturnValue
    )

    It 'Should not throw' {
        { $null = Test-TargetResource @TestTargetResourceParameters } | Should -Not -Throw
    }

    Invoke-ExpectedMocksAreCalledTest -MocksCalled $MocksCalled

    $testTargetResourceResult = Test-TargetResource @TestTargetResourceParameters

    It "Should return $ExpectedReturnValue" {
        $testTargetResourceResult | Should -Be $ExpectedReturnValue
    }
}



<#
    .SYNOPSIS
        Tests that the Get-TargetResource method of a DSC Resource is not null, can be converted to a hashtable, and has the correct properties.
        Uses Pester.

    .PARAMETER GetTargetResourceResult
        The result of the Get-TargetResource method.

    .PARAMETER GetTargetResourceResultProperties
        The properties that the result of Get-TargetResource should have.
#>
function Test-GetTargetResourceResult
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Collections.Hashtable]
        $GetTargetResourceResult,

        [Parameter()]
        [System.String[]]
        $GetTargetResourceResultProperties
    )

    foreach ($property in $GetTargetResourceResultProperties)
    {
        $GetTargetResourceResult[$property] | Should -Not -Be $null
    }
}

<#
    .SYNOPSIS
        Tests if a scope represents the current machine.

    .PARAMETER Scope
        The scope to test.
#>
function Test-IsLocalMachine
{
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Scope
    )

    if ($scope -eq '.')
    {
        return $true
    }

    if ($scope -eq $env:COMPUTERNAME)
    {
        return $true
    }

    if ($scope -eq 'localhost')
    {
        return $true
    }

    if ($scope.Contains('.'))
    {
        if ($scope -eq '127.0.0.1')
        {
            return $true
        }

        <#
            Determine if we have an ip address that matches an ip address on one of the network adapters.
            NOTE: This is likely overkill; consider removing it.
        #>
        $networkAdapters = @(Get-CimInstance Win32_NetworkAdapterConfiguration)
        foreach ($networkAdapter in $networkAdapters)
        {
            if ($null -ne $networkAdapter.IPAddress)
            {
                foreach ($address in $networkAdapter.IPAddress)
                {
                    if ($address -eq $scope)
                    {
                        return $true
                    }
                }
            }
        }
    }

    return $false
}

<#
    .SYNOPSIS
        Waits a certain amount of time for a script block to return true.
        Return $true if completed successfully in the given amount of time, $false otherwise.

    .PARAMETER ScriptBlock
        The ScriptBlock to wait for.

    .PARAMETER TimeoutSeconds
        The number of seconds to wait for the ScriptBlock to return $true.
        Default value is 5.
#>
function Wait-ScriptBlockReturnTrue
{
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.ScriptBlock]
        $ScriptBlock,

        [Parameter()]
        [System.Int32]
        $TimeoutSeconds = 5
    )

    $startTime = [System.DateTime]::Now

    $invokeScriptBlockResult = $false
    while (-not $invokeScriptBlockResult -and (([System.DateTime]::Now - $startTime).TotalSeconds -lt $TimeoutSeconds))
    {
        $invokeScriptBlockResult = $ScriptBlock.Invoke()
        Start-Sleep -Seconds 1
    }

    return $invokeScriptBlockResult
}

<#
    .SYNOPSIS
        Tests if a file is currently locked.

    .PARAMETER Path
        The path to the file to test.
#>
function Test-IsFileLocked
{
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path
    )

    if (-not (Test-Path $Path))
    {
        return $false
    }

    try
    {
        Get-Content -Path $Path | Out-Null
        return $false
    }
    catch
    {
        return $true
    }
}

<#
    .SYNOPSIS
        Tests that calling the Set-TargetResource cmdlet with the WhatIf parameter specified
        produces output that contains all the given expected output.
        Uses Pester.

    .PARAMETER Parameters
        The parameters to pass to Set-TargetResource.
        These parameters do not need to contain the WhatIf parameter, but if they do, this function
        will run Set-TargetResource with WhatIf = $true no matter what is in the Parameters Hashtable.

    .PARAMETER ExpectedOutput
        The output expected to be in the output from running WhatIf with the Set-TargetResource cmdlet.
        If this parameter is empty or null, this cmdlet will check that there was no output from
        Set-TargetResource with WhatIf specified.
#>
function Test-SetTargetResourceWithWhatIf
{
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $Parameters,

        [Parameter()]
        [System.String[]]
        $ExpectedOutput
    )

    $transcriptPath = Join-Path -Path (Get-Location) -ChildPath 'WhatIfTestTranscript.txt'
    if (Test-Path -Path $transcriptPath)
    {
        Wait-ScriptBlockReturnTrue -ScriptBlock {-not (Test-IsFileLocked -Path $transcriptPath)} -TimeoutSeconds 10
        Remove-Item -Path $transcriptPath -Force
    }

    $Parameters['WhatIf'] = $true

    try
    {
        Wait-ScriptBlockReturnTrue -ScriptBlock {-not (Test-IsFileLocked -Path $transcriptPath)}

        Start-Transcript -Path $transcriptPath
        Set-TargetResource @Parameters
        Stop-Transcript

        Wait-ScriptBlockReturnTrue -ScriptBlock {-not (Test-IsFileLocked -Path $transcriptPath)}

        $transcriptContent = Get-Content -Path $transcriptPath -Raw
        $transcriptContent | Should -Not -Be $null

        $regexString = '\*+[^\*]*\*+'

        # Removing transcript diagnostic logging at top and bottom of file
        $selectedString = Select-String -InputObject $transcriptContent `
                                        -Pattern $regexString `
                                        -AllMatches

        foreach ($match in $selectedString.Matches)
        {
            $transcriptContent = $transcriptContent.Replace($match.Captures, '')
        }

        $transcriptContent = $transcriptContent.Replace("`r`n", '').Replace("`n", '')

        if ($null -eq $ExpectedOutput -or $ExpectedOutput.Count -eq 0)
        {
            [System.String]::IsNullOrEmpty($transcriptContent) | Should -BeTrue
        }
        else
        {
            foreach ($expectedOutputPiece in $ExpectedOutput)
            {
                $transcriptContent.Contains($expectedOutputPiece) | Should -BeTrue
            }
        }
    }
    finally
    {
        if (Test-Path -Path $transcriptPath)
        {
            Wait-ScriptBlockReturnTrue -ScriptBlock {-not (Test-IsFileLocked -Path $transcriptPath)} `
                                       -TimeoutSeconds 10
            Remove-Item -Path $transcriptPath -Force
        }
    }
}

<#
    .SYNOPSIS
        Tests to see if DSCResource.Tests needs to be downloaded
        or updated.

    .DESCRIPTION
        This function returns true if the DSCResource.Tests
        content needs to be downloaded or updated.

        A magic file in the .Git folder of DSCResource.Tests
        is used to determine if the repository needs to be
        updated.

        If the last write time of the magic file is over a
        specified number of minutes old then this will cause
        the function to return true.

    .PARAMETER RefreshAfterMinutes
        The number of minutes old the magic file should be
        before requiring an update. Defaults to the value
        defined in $script:dscResourceTestsRefreshAfterMinutes
#>
function Test-DscResourceTestsNeedsInstallOrUpdate
{
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.Int32]
        $RefreshAfterMinutes = $script:dscResourceTestsRefreshAfterMinutes
    )

    $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
    $dscResourceTestsPath = Join-Path -Path $moduleRootPath -ChildPath 'DSCResource.Tests'

    if (Test-Path -Path $dscResourceTestsPath)
    {
        $magicFilePath = Get-DscResourceTestsMagicFilePath -DscResourceTestsPath $DscResourceTestsPath

        if (Test-Path -Path $magicFilePath)
        {
            $magicFileLastWriteTime = (Get-Item -Path $magicFilePath).LastWriteTime
            $magicFileAge = New-TimeSpan -End (Get-Date) -Start $magicFileLastWriteTime

            if ($magicFileAge.Minutes -lt $RefreshAfterMinutes)
            {
                Write-Debug -Message ('DSCResource.Tests was last updated {0} minutes ago. Update not required.' -f $magicFileAge.Minutes)
                return $false
            }
            else
            {
                Write-Verbose -Message ('DSCResource.Tests was last updated {0} minutes ago. Update required.' -f $magicFileAge.Minutes) -Verbose
            }
        }
    }

    return $true
}

<#
    .SYNOPSIS
        Installs the DSCResource.Tests content.

    .DESCRIPTION
        This function uses Git to install or update the
        DSCResource.Tests repository.

        It will then create or update the magic file in
        the .git folder in the DSCResource.Tests folder.

        If Git is not installed and the DSCResource.Tests
        folder is not available then an exception will
        be thrown.

        If the DSCResource.Tests folder does exist but
        Git is not installed then a warning will be
        displayed and the repository will not be pulled.
#>
function Install-DscResourceTestsModule
{
    [CmdletBinding()]
    param
    (
    )

    $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
    $dscResourceTestsPath = Join-Path -Path $moduleRootPath -ChildPath 'DSCResource.Tests'
    $gitInstalled = $null -ne (Get-Command -Name 'git' -ErrorAction 'SilentlyContinue')
    $writeMagicFile = $false

    if (Test-Path -Path $dscResourceTestsPath)
    {
        if ($gitInstalled)
        {
            Push-Location -Path $dscResourceTestsPath
            Write-Verbose -Message 'Updating DSCResource.Tests.' -Verbose
            & git @('pull','origin','dev','--quiet')
            $writeMagicFile = $true
            Pop-Location
        }
        else
        {
            Write-Warning -Message 'Git not installed. DSCResource.Tests will not be updated.'
        }
    }
    else
    {
        if (-not $gitInstalled)
        {
            throw 'Git not installed. Can not pull DSCResource.Tests.'
        }

        Push-Location -Path $moduleRootPath
        Write-Verbose -Message 'Cloning DSCResource.Tests.' -Verbose
        & git @('clone','https://github.com/PowerShell/DscResource.Tests','--quiet')
        $writeMagicFile = $true
        Pop-Location
    }

    if ($writeMagicFile)
    {
        # Write the magic file
        $magicFilePath = Get-DscResourceTestsMagicFilePath -DscResourceTestsPath $DscResourceTestsPath
        $null = Set-Content -Path $magicFilePath -Value (Get-Date) -Force
    }
}

<#
    .SYNOPSIS
        Gets the full path of the magic file used to
        determine the last date/time the DSCResource.Tests
        folder was updated.

    .PARAMETER DscResourceTestsPath
        The path to the folder that contains DSCResource.Tests.
#>
function Get-DscResourceTestsMagicFilePath
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $DscResourceTestsPath
    )

    return $DscResourceTestsPath | Join-Path -ChildPath '.git' | Join-Path -ChildPath $script:dscResourceTestsMagicFile
}

<#
    .SYNOPSIS
        Verifies that the specified Windows Feature exists and is installed
        on the local machine.

    .PARAMETER Name
        The name of the Windows Feature to verify installation of.
#>
function Install-WindowsFeatureAndVerify
{
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    )

    $featureInstalled = $true

    $targetFeature = Get-WindowsFeature -Name $Name -ErrorAction SilentlyContinue

    if ($null -eq $targetFeature)
    {
        Write-Warning -Message "Unable to find Windows Feature '$Name'."
        $featureInstalled = $false
    }
    elseif (!$targetFeature.Installed)
    {
        $installResult = Install-WindowsFeature -Name $Name

        if (!$installResult.Success)
        {
            Write-Error -Message "Failed to install Windows Feature '$Name'."
            $featureInstalled = $false
        }
    }

    return $featureInstalled
}

<#
    .SYNOPSIS
        Retrieves a PSCredential object representing a test Administrator
        account.
#>
function Get-TestAdministratorAccountCredential
{
    [OutputType([System.Management.Automation.PSCredential])]
    [CmdletBinding()]
    param()

    if (-not (Test-Path -Path Variable:Script:xPSDesiredStateConfigurationTestAdminCreds) -or `
        $null -eq $script:xPSDesiredStateConfigurationTestAdminCreds)
    {
        Initialize-TestAdministratorAccount
    }

    return $script:xPSDesiredStateConfigurationTestAdminCreds
}

<#
    .SYNOPSIS
        Creates a test administrator user account if it doesn't exist. Adds
        the account to the local built-in Administrators group. Resets the
        password on the account with a randomly generated password.
#>
function Initialize-TestAdministratorAccount
{
    [CmdletBinding()]
    param()

    # Get local Administrators group name
    $adminGroupName = Get-WellKnownGroupName `
                        -WellKnownSidType ([System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid)

    # Get local Remote Management Users groups name
    $remoteManagementGroupName = Get-WellKnownGroupName `
                        -Sid 'S-1-5-32-580'

    $testAdminUserName = 'xPSDSCTestAdmin'

    $testAdminPassword = Get-TestPassword
    $securePassword = ConvertTo-SecureString `
                        -String $testAdminPassword `
                        -AsPlainText `
                        -Force

    $adminGroup = Get-LocalGroupDirectoryEntry -GroupName $adminGroupName
    $remoteManagementGroup = Get-LocalGroupDirectoryEntry -GroupName $remoteManagementGroupName

    $testAdminUser = New-LocalUserUsingDirectoryEntry -UserName $testAdminUserName

    Set-UserPasswordUsingDirectoryEntry `
        -UserDE $testAdminUser `
        -Password $testAdminPassword

    Add-LocalGroupMemberUsingDirectoryEntry `
        -UserDE $testAdminUser `
        -GroupDE $adminGroup

    Add-LocalGroupMemberUsingDirectoryEntry `
        -UserDE $testAdminUser `
        -GroupDE $remoteManagementGroup

    $script:xPSDesiredStateConfigurationTestAdminCreds = `
        Get-PSCredentialObject `
            -UserName "$($env:ComputerName)\$testAdminUserName" `
            -Password $securePassword
}

<#
    .SYNOPSIS
        Returns a PSCredential object representing the specified user name and
        password.
#>
function Get-PSCredentialObject
{
    [OutputType([System.Management.Automation.PSCredential])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $UserName,

        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]
        $Password
    )

    $credentials = New-Object `
                        -TypeName 'System.Management.Automation.PSCredential' `
                        -ArgumentList @( $UserName, $Password )

    return $credentials
}

<#
    .SYNOPSIS
        Generates a random string which is intended to be used as an account
        password.
#>
function Get-TestPassword
{
    [OutputType([System.String])]
    [CmdletBinding()]
    param()

    $password = ''

    $randomGenerator = New-Object -TypeName 'System.Random'

    $passwordLength = Get-Random -Minimum 15 -Maximum 126

    while ($password.Length -lt $passwordLength)
    {
        $password = $password + [System.Char] $randomGenerator.Next(45, 126)
    }

    return $password
}

<#
    .SYNOPSIS
        Checks whether the specified user is a member of the specified group,
        and adds them to the group if they are not a member.
#>
function Add-LocalGroupMemberUsingDirectoryEntry
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript({$_.SchemaClassName -eq 'User'})]
        [System.DirectoryServices.DirectoryEntry]
        $UserDE,

        [Parameter(Mandatory = $true)]
        [ValidateScript({$_.SchemaClassName -eq 'Group'})]
        [System.DirectoryServices.DirectoryEntry]
        $GroupDE
    )

    try
    {
        $groupMembers = $GroupDE.Invoke('Members')
    }
    catch
    {
        Write-Error -Message "Failed to look up members of group at path '$($GroupDE.Path)'"
        return
    }

    $foundMember = $false

    foreach ($member in $groupMembers)
    {
        $memberName = $member.GetType().InvokeMember('Name', 'GetProperty', $null, $member, $null)

        if ($userDE.Name -like $memberName)
        {
            Write-Verbose -Message "Account '$($userDE.Name)' is already a member of group at path '$($GroupDE.Path)'"

            $foundMember = $true
            break
        }
    }

    # If the user is not a member of the group, make it a member
    if (!$foundMember)
    {
        Write-Verbose -Message "Adding account '$($userDE.Name)' to group at path '$($GroupDE.Path)'" -Verbose

        $null = $GroupDE.Add($UserDE.Path)
    }
}

<#
    .SYNOPSIS
        Adds the desired permissions to the given file system path.
#>
function Add-PathPermission
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $IdentityReference,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $Path,

        [ValidateSet('Allow', 'Deny')]
        [System.String]
        $AccessControlType = 'Allow',

        [ValidateSet({[System.Security.AccessControl.FileSystemRights].GetEnumNames()})]
        [System.String]
        $FileSystemRight = 'FullControl',

        [System.Security.AccessControl.InheritanceFlags[]]
        $InheritanceFlags = @(
            [System.Security.AccessControl.InheritanceFlags]::ContainerInherit
            [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
        ),

        [System.Security.AccessControl.PropagationFlags[]]
        $PropagationFlags = [System.Security.AccessControl.PropagationFlags]::None
    )

    $acl = Get-Acl -Path $Path

    $rule = New-Object `
                -TypeName System.Security.AccessControl.FileSystemAccessRule `
                -ArgumentList @(
                    $IdentityReference,
                    $FileSystemRight,
                    $InheritanceFlags,
                    $PropagationFlags,
                    $AccessControlType
                )

    $null = $acl.SetAccessRule($rule)

    Set-ACL -Path $Path -AclObject $acl
}

<#
    .SYNOPSIS
        Retrieves the group name corresponding to the specified Sid or
        WellKnownSidType.
#>
function Get-WellKnownGroupName
{
    [CmdletBinding()]
    param
    (
        [Parameter(ParameterSetName = 'UsingSid')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Sid,

        [Parameter(ParameterSetName = 'UsingSidType')]
        [System.Security.Principal.WellKnownSidType]
        $WellKnownSidType
    )

    switch ($PSCmdlet.ParameterSetName) {
        'UsingSid'
        {
            $groupSID = New-Object `
                            -TypeName System.Security.Principal.SecurityIdentifier `
                            -ArgumentList @( $Sid )
        }

        'UsingSidType'
        {
            $groupSID = New-Object `
                            -TypeName System.Security.Principal.SecurityIdentifier `
                            -ArgumentList @( $WellKnownSidType, $null )
        }

        default
        {
            throw 'ParameterSet not implemented in Get-WellKnownGroupName'
        }
    }

    $groupName = $groupSID.Translate([System.Security.Principal.NTAccount]).Value.Split('\')[1]

    return $groupName
}

<#
    .SYNOPSIS
        Creates a DirectoryEntry object representing the local directory of the
        test computer.
#>
function Get-LocalDirectory
{
    [OutputType([System.DirectoryServices.DirectoryEntry])]
    [CmdletBinding()]
    param()

    Write-Verbose -Message 'Getting Local Directory Entry'

    $localDirectoryString = "WinNT://$($env:COMPUTERNAME)"
    $localDirectory = [System.DirectoryServices.DirectoryEntry] $localDirectoryString

    return $localDirectory
}

<#
    .SYNOPSIS
        Creates a DirectoryEntry object representing the specified local group.
#>
function Get-LocalGroupDirectoryEntry
{
    [OutputType([System.DirectoryServices.DirectoryEntry])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $GroupName
    )

    Write-Verbose -Message "Getting Local Group '$GroupName' Directory Entry"

    $groupAddress = (((Get-LocalDirectory).Path) + '/' + $GroupName + ',group')
    $groupDE = [System.DirectoryServices.DirectoryEntry] $groupAddress

    return $groupDE
}

<#
    .SYNOPSIS
        Creates a DirectoryEntry object representing the specified local user.
        Creates the user if it does not exist.
#>
function New-LocalUserUsingDirectoryEntry
{
    [OutputType([System.DirectoryServices.DirectoryEntry])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $UserName
    )

    Write-Verbose -Message "Getting Local User '$UserName' Directory Entry"

    $localDirectory = Get-LocalDirectory

    $userAddress = ($localDirectory.Path) + '/' + $UserName + ',user'
    $userDE = [System.DirectoryServices.DirectoryEntry] $userAddress

    if ($null -eq $userDE.distinguishedName)
    {
        Write-Verbose -Message "Creating account '$UserName'" -Verbose

        $userDE = $localDirectory.Create('User', $UserName)
    }

    return $userDE
}

<#
    .SYNOPSIS
        Sets a password on the specified user object.
#>
function Set-UserPasswordUsingDirectoryEntry
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUserNameAndPassWordParams', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript({$_.SchemaClassName -eq 'User'})]
        [System.DirectoryServices.DirectoryEntry]
        $UserDE,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Password
    )

    Write-Verbose -Message "Setting password on account at path '$($UserDE.Path)'" -Verbose

    $null = $UserDE.SetPassword($Password)
    $null = $UserDE.SetInfo()
}

<#
    .SYNOPSIS
        Finds an unused TCP port in the specified port range. By default,
        searches within ports 38473 - 38799, which at the time of writing, show
        as unassigned in:
        https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml

    .PARAMETER LowestPortNumber
        The TCP port number at which to begin the unused port search. Must be
        greater than 0.

    .PARAMETER HighestPortNumber
        The highest TCP port number to search for unused ports within. Must be
        greater than 0, and greater than LowestPortNumber.

    .PARAMETER ExcludePorts
        TCP ports to exclude from the search, even if they fall within the
        LowestPortNumber and HighestPortNumber range.
#>
function Get-UnusedTcpPort
{
    [OutputType([System.UInt16])]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateScript({$_ -gt 0})]
        [System.UInt16]
        $LowestPortNumber = 38473,

        [Parameter()]
        [ValidateScript({$_ -gt $0})]
        [System.UInt16]
        $HighestPortNumber = 38799,

        [Parameter()]
        [System.UInt16[]]
        $ExcludePorts = @()
    )

    if ($HighestPortNumber -lt $LowestPortNumber)
    {
        throw 'HighestPortNumber must be greater than or equal to LowestPortNumber'
    }

    [System.UInt16] $unusedPort = 0

    [System.Collections.ArrayList] $usedAndExcludedPorts = (Get-NetTCPConnection).LocalPort | Where-Object -FilterScript {
        $_ -ge $LowestPortNumber -and $_ -le $HighestPortNumber
    }

    if (!(Test-Path -Path variable:usedAndExcludedPorts) -or ($null -eq $usedAndExcludedPorts))
    {
        [System.Collections.ArrayList] $usedAndExcludedPorts = @()
    }

    if (!(Test-Path -Path variable:ExcludePorts) -or ($null -eq $ExcludePorts))
    {
        $ExcludePorts = @()
    }

    $null = $usedAndExcludedPorts.Add($ExcludePorts)

    foreach ($port in $LowestPortNumber..$HighestPortNumber)
    {
        if (!($usedAndExcludedPorts.Contains($port)))
        {
            $unusedPort = $port
            break
        }
    }

    if ($unusedPort -eq 0)
    {
        throw "Failed to find unused TCP port between ports $LowestPortNumber and $HighestPortNumber."
    }

    return $unusedPort
}

<#
    .SYNOPSIS
        Resets the DSC LCM by performing the following functions:
        1. Cancel any currently executing DSC LCM operations
        2. Remove any DSC configurations that:
            - are currently applied
            - are pending application
            - have been previously applied
        The purpose of this function is to ensure the DSC LCM is in a known
        and idle state before an integration test is performed that will
        apply a configuration.
        This is to prevent an integration test from being performed but failing
        because the DSC LCM is applying a previous configuration.
        This function should be called after each Describe block in an integration
        test to ensure the DSC LCM is reset before another test DSC configuration
        is applied.
    .EXAMPLE
        PS C:\> Reset-DscLcm
        This command will reset the DSC LCM and clear out any DSC configurations.
#>
function Reset-DscLcm
{
    [CmdletBinding()]
    param ()

    Write-Verbose -Message 'Resetting DSC LCM.'

    Stop-DscConfiguration -Force -ErrorAction SilentlyContinue
    Remove-DscConfigurationDocument -Stage Current -Force
    Remove-DscConfigurationDocument -Stage Pending -Force
    Remove-DscConfigurationDocument -Stage Previous -Force
}

Export-ModuleMember -Function @(
    'Add-PathPermission',
    'Get-TestAdministratorAccountCredential',
    'Install-WindowsFeatureAndVerify',
    'Invoke-ExpectedMocksAreCalledTest',
    'Invoke-GenericUnitTest',
    'Invoke-GetTargetResourceUnitTest',
    'Invoke-SetTargetResourceUnitTest',
    'Invoke-TestTargetResourceUnitTest',
    'Test-GetTargetResourceResult',
    'Test-IsFileLocked',
    'Test-SetTargetResourceWithWhatIf',
    'Wait-ScriptBlockReturnTrue', `
    'Get-UnusedTcpPort', `
    'Reset-DscLcm'
)
