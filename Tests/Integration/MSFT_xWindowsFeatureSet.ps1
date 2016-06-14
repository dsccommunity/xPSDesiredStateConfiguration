function DeployRoleInstallerSourcesFiles 
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String] 
        $Path
    )

	$setupScriptPath = Get-Location

	$testRootPath = (Resolve-Path $setupScriptPath\..\..).Path

	$testSxSPath = Join-Path -Path $testRootPath -ChildPath $Path

	$winSxSPath = Join-Path -Path $env:WinDir -ChildPath 'WinSxS'

	$winSxSReplacePath = $winSxSPath.Replace('\', '\\')

	if (Test-Path $testSxSPath) 
    {
        $null = Remove-Item $testSxSPath -Force -Recurse
    }

	$null = New-Item -Path $testSxSPath -ItemType Directory -Force
    $telnetFiles = Get-ChildItem $winSxSPath -Filter *telnet* -Recurse
    
    foreach ($telnetFile in $telnetFiles) 
    {
        $filePath = $telnetFile.FullName

	    if ($filePath -notlike '*server*') 
        {
            $destination = $filePath -Replace $winSxSReplacePath, $testSxSPath

	        if (Test-Path $filePath -PathType Leaf)
            {
                $null = New-Item -ItemType File -Path $filePath -Force
            }

	        Copy-Item $filePath $destination -Recurse -Force
        }
    }

	return $testSxSPath
}

$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'xPSDesiredStateConfiguration' `
    -DSCResourceName 'MSFT_xWindowsFeatureSet' `
    -TestType Integration

Describe "xWindowsFeatureSet Integration Tests" {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\Unit\MockServerManager\MockServerManager.psm1"
        
        #$script:source = DeployRoleInstallerSourcesFiles -path "TestSxS"
    }

    AfterAll {}

    It "Install a set of Windows features with their sub features" {
        $configurationName = "InstallWithSubFeatures"
        $configurationPath = Join-Path -Path (Get-Location) -ChildPath $configurationName
        $logPath = Join-Path -Path (Get-Location) -ChildPath "tellnet-client-install"
        $featureNames = @("Test1", "SubTest3")

        try
        {
            Configuration $configurationName
            {
                Import-DscResource -ModuleName xPSDesiredStateConfiguration

                xWindowsFeatureSet WindowsFeatureSet1
                {
                    Name = $featureNames
                    Ensure = "Present"
                    IncludeAllSubFeature = $true
                    LogPath = $logPath
                }
            }

            & $configurationName -OutputPath $configDir

            Start-DscConfiguration -Path $configDir -Wait -Force -Verbose

            # Validate if the Windows features were installed
            foreach ($featureName in $featureNames)
            {
                $windowsFeature = Get-WindowsFeature -Name $featureName
                $windowsFeature.Installed | Should Be $true

                # Validate sub features were installed correctly
                foreach ($subfeatureName in $windowsFeature.SubFeatures)
				{
					$subfeature = Get-WindowsFeature -Name $subfeatureName
					$subfeature.Installed | Should Be $true
				}
            }    
        }
        finally
        {
            if (Test-Path -Path $logPath)
            {
                Remove-Item -Path $logPath -Recurse -Force
            }

            if (Test-Path -Path $configurationPath)
            {
                Remove-Item -Path $configurationPath -Recurse -Force
            }
        }
    } 
}