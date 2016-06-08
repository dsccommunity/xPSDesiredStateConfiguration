Initialize-TestEnvironment `
    -DSCModuleName 'xPSDesiredStateConfiguration' `
    -DSCResourceName 'MSFT_xWindowsFeature' `
    -TestType Unit `
    | Out-Null

InModuleScope 'MSFT_xWindowsFeature' {
    Describe 'xWindowsFeature Unit Tests' {
        BeforeAll {
            Import-Module $PSScriptRoot\MSFT_xWindowsFeature.TestHelper.psm1 -Force
            Import-Module $PSScriptRoot\MockServerManager -Force

            $script:isWin8orAbove = Get-IsWin8orAbove
            $script:runOnServerSkuOnly = Get-IsServerSKU
            $script:runOnClientSkuOnly = Get-IsClientSKU
            $script:isWMFServerCore = Get-IsWMFServerCore
            $script:isWMFServerNotCore = Get-IsWMFServerNotCore
        }

        AfterAll {
            Remove-Module MockServerManager
        }

        It 'Get-TargetResource Without Credentials' -Skip:(-not $script:runOnServerSkuOnly) {
            try
            {  
                # Telnet Client is avaliable on only DSC supported SKU's. 
                GetTargetResourceExecutionHelper "Subtest1"
            }
            catch
            {
                Log -Error "Failed to execute Get-TargetResource with credentials.   Actual Error is: $($($_.Exception).Message)" -Exception $_
            }
        }

        It 'Get-TargetResource With Credentials' -Skip:(-not ($script:runOnServerSkuOnly -and $script:isWin8orAbove)) {
            try
            {  
                $credential = LocalAdminCredentialGenerator
                # Telnet Client is avaliable on only DSC supported SKU's.
                GetTargetResourceExecutionHelper "Test1" $credential
            }
            catch
            {
                # If the remote process cannot be created then AccessDenied is thrown. This issue does not repro when tried manually.
                if ($null -eq $_ -or $null -eq $_.FullyQualifiedErrorId -or $_.FullyQualifiedErrorId.Contains("AccessDenied") -eq $false)
                {
                    Log -Error "Failed to execute Get-TargetResource with credentials.   Actual Error is: $($($_.Exception).Message)" -Exception $_
                }
            }
        }

        It 'Get-TargetResource All SubFeatures Installed' -Skip:(-not $script:runOnServerSkuOnly) {
            $windowsFeatureName = "Test1"
            Remove-WindowsFeature $windowsFeatureName -ErrorAction Ignore
            Add-WindowsFeature -Name $windowsFeatureName -IncludeAllSubFeature

            $getResultAsHasTable = GetTargetResourceExecutionHelper $windowsFeatureName
            if ($true -ne $getResultAsHasTable["IncludeAllSubFeature"])
            {
                Log -Error "Failed to detect all subfeatures being installed."
            }
        }

        It 'Set-TargetResource Without Credentials Ensure Present' -Skip:(-not $script:runOnServerSkuOnly) {
            try
            {  
                $windowsFeatureName = "Test1"
                Remove-WindowsFeature $windowsFeatureName -ErrorAction Ignore
         
                $ensureValue = "Present"

                Set-TargetResource -Name $windowsFeatureName -Ensure $ensureValue

                $windowsFeature = Get-WindowsFeature -Name $windowsFeatureName

                if (-not $windowsFeature.Installed)
                {
                    throw "Failed to execute Set-TargetResource without credentials. I.e, failed to install role through Set-TargetResource"
                }
            }
            catch
            {
                Log -Error "Failed to execute Set-TargetResource without credentials.  Actual Error is: $($($_.Exception).Message)" -Exception $_
            }
        }

        It 'Set-TargetResource With Default Ensure Value' -Skip:(-not $script:runOnServerSkuOnly) {
            try
            {  
                $Name = "Test1"
                Remove-WindowsFeature $Name -ErrorAction Ignore
         
                Set-TargetResource -Name $Name

                $feature = Get-WindowsFeature -Name $Name

                if ($feature.Installed -eq $false)
                {
                    throw "Failed to execute Set-TargetResource without credentials. I.e, failed to install role through Set-TargetResource"
                }
            }
            catch
            {
                Log -Error "Failed to execute Set-TargetResource without credentials.   Actual Error is: $($($_.Exception).Message)" -Exception $_
            }
        }

    It TestSetTargetResourceCmdletWithOutCredentialsEnsureAbsent -Skip:(-not $runOnServerSkuOnly) {
            try
            {  
                $Name = "Test1"
                Remove-WindowsFeature $Name -ErrorAction Ignore
         
                $Ensure = "Absent"

                MSFT_RoleResource\Set-TargetResource -Name $Name -Ensure $Ensure

                $feature = Get-WindowsFeature -Name $Name

                if($feature.Installed -eq $true)
                {
                    throw "Failed to execute Set-TargetResource without credentials. I.e, failed to install role through Set-TargetResource"
                }
            }
            catch
            {
                Log -Error "Failed to execute Set-TargetResource without credentials.  Actual Error : $($($_.Exception).Message)" -Exception $_
            }
    }

    It TestSetTargetResourceCmdletWithCredentialsEnsurePresent -Skip:(-not ($runOnServerSkuOnly -and $isWin8orAbove)) {
            try
            {  
                $Name = "Test1"

                $Ensure = "Present"
                $credential = LocalAdminCredentialGenerator ;
                MSFT_RoleResource\Set-TargetResource -Name $Name -Ensure $Ensure -Credential $credential
         
                $feature = Get-WindowsFeature -Name $Name

                if($feature.Installed -eq $false)
                {
                    throw "Failed to execute Set-TargetResource with credentials. I.e, failed to install role through Set-TargetResource"
                }
            }
            catch
            {
                # If the remote process cannot be created then AccessDenied is thrown. This issue does not repro when tried manually.
                if($null -eq $_ -or $null -eq $_.FullyQualifiedErrorId -or $_.FullyQualifiedErrorId.Contains("AccessDenied") -eq $false)
                {
                    $msg=$_.Exception.Message
                    Log -Error "Failed to execute Set-TargetResource with credentials. Error is : $msg "  -Exception $_
                }
            }
    }    

    It TestSetTargetResourceCmdletWithCredentialsEnsureAbsent -Skip:(-not ($runOnServerSkuOnly -and $isWin8orAbove)) {
            try
            {  
                # Telnet Client is avaliable on only DSC supported SKU's. 
                $Name = "Test1"

                $Ensure = "Absent"

                $credential = LocalAdminCredentialGenerator ;
                MSFT_RoleResource\Set-TargetResource -Name $Name -Ensure $Ensure -IncludeAllSubFeature -Credential $credential

                $feature = Get-WindowsFeature -Name $Name

                if($feature.Installed -eq $true)
                {
                    throw "Failed to execute Set-TargetResource with credentials. I.e, failed to install role through Set-TargetResource"
                }
            }
            catch
            {
                $msg=$_.Exception.Message
                Log -Error "Failed to execute Set-TargetResource with credentials. Error is : $msg "  -Exception $_
            }
    }

    It TestTestTargetResourceWhenFeatureAndItsSubFeaturesAreInstalledAndEnSureISPresent -Skip:(-not $runOnServerSkuOnly) {
            $featureName = "Test1"

            Remove-WindowsFeature $featureName -ErrorAction Ignore
         
            Add-WindowsFeature $featureName -IncludeAllSubFeature
            $testResult = MSFT_RoleResource\Test-TargetResource $featureName "Present" -IncludeAllSubFeature ;
            if($testResult -eq $false)
            {
                Log -Error "Failed to detect the feaure and its subfeatures being installed successfully"
            }
    }

    It TestTestTargetResourceWhenFeatureWithOutAnySubFeaturesIsInstalledAndEnSureISPresent -Skip:(-not $runOnServerSkuOnly) {
            $featureName = "Test1"
            Remove-WindowsFeature $featureName -ErrorAction Ignore
         
            Add-WindowsFeature $featureName -IncludeAllSubFeature
            $testResult = MSFT_RoleResource\Test-TargetResource $featureName "Present" -IncludeAllSubFeature ;
            if($testResult -eq $false)
            {
                Log -Error "Failed to detect the feaure and its subfeatures being installed successfully"
            }
    }

    It TestTestTargetResourceWhenIsInstalledAndEnSureIsAbsent -Skip:(-not $runOnServerSkuOnly) {
            $featureName = "Test1"
            Remove-WindowsFeature $featureName -ErrorAction Ignore
         
            MSFT_RoleResource\Set-TargetResource -Name $featureName -Ensure "Present" ;

            $getWindowsFeatureResult = Get-WindowsFeature $featureName

            if($getWindowsFeatureResult -eq $null)
            {
                Log -Error "Failed to install featue: Web-Server using Role resource."
            }

            $testResult = MSFT_RoleResource\Test-TargetResource -Name $featureName -Ensure "Present" ;

            if($testResult -eq $false)
            {
                Log -Error "Failed to detect that Web-Server is installed by Test-TargetResource."
            }
    }

    It DRTWindowsFeatureClientSKU -Skip:(-not $runOnClientSkuOnly) {
            Log -message "Dummy test case for Integration and Feature WFs till bug#221259 is fixed."
    }

    It TestGetTargetResourceCmdletForVerbose -Skip:(-not ($runOnServerSkuOnly -and $isWin8orAbove)) {
            try
            {  
                $Name = "Test1"

                $ExpectedVerboseCount = 0

         
                # Capture the verbose messages using PowerShell APIs. Check for the count
                $ps = [PowerShell]::Create()
                $ps.AddCommand("import-module").AddParameter("Name",$Script:ProviderPath).Invoke()
                $ps.AddCommand("import-module").AddParameter("Name","servermanager").Invoke()
                $ps.Commands.Clear()
                $null = $ps.AddCommand("Get-TargetResource").Addparameter("Name",$Name).AddParameter("Verbose").Invoke()
                $verboseCount = $ps.Streams.Verbose.Count

                if($verboseCount -ne $ExpectedVerboseCount) { throw "Actaul verbose message count $VerboseCount does not match expected verbose message $ExpectedVerboseCount"}
            }
            catch
            {
                $msg=$_.Exception.Message
                Log -Error $msg  -Exception $_
            }
            Finally
            {
                $ps.Dispose()
            }
    }

    It TestTestTargetResourceCmdletForVerboseEnsurePresent -Skip:(-not ($runOnServerSkuOnly -and -not $isWMFServerCore)) {
            try
            {  
                $Name = "Test1"
                $Ensure = "Present"
                            
                $ExpectedVerboseCount = 0

                # Remove the feature incase it is present and then test
                Remove-WindowsFeature -Name $Name -ErrorAction SilentlyContinue

                # Capture the verbose messages using PowerShell APIs. Check for the count
                $ps = [PowerShell]::Create()
                $ps.AddCommand("import-module").AddParameter("Name",$Script:ProviderPath).Invoke()
                $ps.Commands.Clear()
                $null = $ps.AddCommand("Test-TargetResource").Addparameter("Name",$Name).AddParameter("Ensure",$Ensure).AddParameter("Verbose").Invoke()
                $verboseCount = $ps.Streams.Verbose.Count

                if($verboseCount -ne $ExpectedVerboseCount) { throw "Actaul verbose message count $VerboseCount does not match expected verbose message $ExpectedVerboseCount"}
            }
            catch
            {
                $msg=$_.Exception.Message
                    Log -Error $msg  -Exception $_
            }
            Finally
            {
                $ps.Dispose()
            }
    }

    It TestTestTargetResourceCmdletForVerboseEnsureAbsent -Skip:(-not ($runOnServerSkuOnly -and -not $isWMFServerCore)) {
            try
            {  
                $Name = "Test1"
                $Ensure = "Absent"

                $ExpectedVerboseCount = 0

                # Add the feature and then test
                Add-WindowsFeature -Name $Name -ErrorAction SilentlyContinue

                # Capture the verbose messages using PowerShell APIs. Check for the count
                $ps = [PowerShell]::Create()
                $ps.AddCommand("import-module").AddParameter("Name",$Script:ProviderPath).Invoke()
                $ps.Commands.Clear()
                $null = $ps.AddCommand("Test-TargetResource").Addparameter("Name",$Name).AddParameter("Ensure",$Ensure).AddParameter("Verbose").Invoke()
                $verboseCount = $ps.Streams.Verbose.Count

                if($verboseCount -ne $ExpectedVerboseCount) { throw "Actaul verbose message count $VerboseCount does not match expected verbose message $ExpectedVerboseCount"}
            }
            catch
            {
                $msg=$_.Exception.Message    
                Log -Error $msg  -Exception $_
            }
            Finally
            {
                $ps.Dispose()
                # Since the test added the feature, it should remove it as well
                Remove-WindowsFeature -Name $Name -ErrorAction SilentlyContinue
            }
    }

    It TestSetTargetResourceCmdletForVerboseEnsurePresent -Skip:(-not $runOnServerSkuOnly) {
            try
            {  
                $Name = "SubTest1"
                $Ensure = "Present"

                $ExpectedVerboseCount = 7

                $isR2Sp1 = IsWinServer2008R2SP1;
                if($isR2Sp1)
                {
                $ExpectedVerboseCount = 6
                }
                else
                {
                    $isR2Sp1ServerCore = IsWinServer2008R2SP1ServerCore;
                    if($isR2Sp1ServerCore)
                    {
                        $ExpectedVerboseCount = 7
                    }
                }

                # Remove the feature
                Remove-WindowsFeature -Name $Name -ErrorAction SilentlyContinue

                # Capture the verbose messages using PowerShell APIs. Check for the count
                $ps = [PowerShell]::Create()
                $ps.AddCommand("import-module").AddParameter("Name",$Script:ProviderPath).Invoke()
                $ps.Commands.Clear()
                $null = $ps.AddCommand("Set-TargetResource").Addparameter("Name","SubTest1").AddParameter("Ensure",$Ensure).AddParameter("Verbose").Invoke()
                $verboseCount = $ps.Streams.Verbose.Count

            # If the Machine is in a Reboot pending state, we get an additional verbose message indicating that the machine needs to be restarted.
            # the number of verbose messages could vary between 4 - 7 depending on the scenario.
            if($VerboseCount -gt $ExpectedVerboseCount) 
            { 
                throw "Actaul verbose message count $VerboseCount does not match expected verbose message $ExpectedVerboseCount"
            }
            }
            catch
            {
                $msg=$_.Exception.Message
                Log -Error $msg  -Exception $_
            }
            Finally
            {
                $ps.Dispose()
                # Since the test is adding the feature, remove it as well
                Remove-WindowsFeature -Name $Name -ErrorAction SilentlyContinue
            }
    }

    It TestSetTargetResourceCmdletForVerboseEnsureAbsent -Skip:(-not $runOnServerSkuOnly) {
            try
            {  
                $Name = "SubTest1"
                $Ensure = "Absent"

                $ExpectedVerboseCount = 7

                $isR2Sp1 = IsWinServer2008R2SP1;
                if($isR2Sp1)
                {
                $ExpectedVerboseCount = 6
                }
                else
                {
                    $isR2Sp1ServerCore = IsWinServer2008R2SP1ServerCore;
                    if($isR2Sp1ServerCore)
                    {
                        $ExpectedVerboseCount = 7
                    }
                }

                Add-WindowsFeature -Name $Name -ErrorAction SilentlyContinue

                # Capture the verbose messages using PowerShell APIs. Check for the count
                $ps = [PowerShell]::Create()
                $ps.AddCommand("import-module").AddParameter("Name",$Script:ProviderPath).Invoke()
                $ps.Commands.Clear()
                $null = $ps.AddCommand("Set-TargetResource").Addparameter("Name",$Name).AddParameter("Ensure",$Ensure).AddParameter("Verbose").Invoke()
                $verboseCount = $ps.Streams.Verbose.Count

                # If the Machine is in a Reboot pending state, we get an additional verbose message indicating that the machine needs to be restarted.
                # the number of verbose messages could vary between 4 - 7 depending on the scenario.
                if($VerboseCount -gt $ExpectedVerboseCount) 
                { 
                    throw "Actaul verbose message count $VerboseCount does not match expected verbose message $ExpectedVerboseCount"
                }
            }
            catch
            {
                $msg=$_.Exception.Message
                Log -Error $msg -Exception $_
            }
            Finally
            {
                $ps.Dispose()
            }
    }

   It TestSetTargetResourceCmdletWithOutCredentialsEnsurePresentAndSubFeaturesAreAdded -Skip:(-not ($runOnServerSkuOnly -and -not $isWMFServer -and -not($isWMFServerCore))) {
            try
            {  
                $Name = "Test1"

                $Ensure = "Present"

                MSFT_RoleResource\Set-TargetResource -Name $Name -Ensure $Ensure -IncludeAllSubFeature
         
                $feature = Get-WindowsFeature -Name $Name

                if($feature.Installed -eq $false)
                {
                    throw "Failed to execute Set-TargetResource without credentials. I.e, failed to install role through Set-TargetResource"
                }

                foreach($currentSubFeature in $feature.SubFeatures)
                {
                    $feature = Get-WindowsFeature -Name $currentSubFeature

                    if($feature.Installed -eq $false)
                    {
                        throw "Failed to execute Set-TargetResource without credentials. I.e, failed to install subfeatures of a role through Set-TargetResource"
                    }
                }
            }
            catch
            {
                Log -Error "Failed to execute Set-TargetResource without credentials.  Actual Error is: $($($_.Exception).Message)" -Exception $_
            }
    }

    It TestSetTargetResourceCmdletWithOutCredentialsEnsureAbsentAndSubFeaturesAreRemoved -Skip:(-not ($runOnServerSkuOnly -and -not $isWMFServer -and -not($isWMFServerCore))) {
            try
            {  
                $Name = "Test1"

                $Ensure = "Absent"

                MSFT_RoleResource\Set-TargetResource -Name $Name -Ensure $Ensure -IncludeAllSubFeature
         
                $feature = Get-WindowsFeature -Name $Name

                if($feature.Installed -eq $true)
                {
                    throw "Failed to execute Set-TargetResource without credentials. I.e, failed to install role through Set-TargetResource"
                }

                foreach($currentSubFeature in $feature[0].SubFeatures)
                {
                    $feature = Get-WindowsFeature -Name $currentSubFeature

                    if($feature.Installed -eq $true)
                    {
                        throw "Failed to execute Set-TargetResource without credentials. I.e, failed to install subfeatures of a role through Set-TargetResource"
                    }
                }
            }
            catch
            {
                Log -Error "Failed to execute Set-TargetResource without credentials. Actual Error is: $($($_.Exception).Message)" -Exception $_
            }
    }

    It TestGetTargetResourceCmdletWhenNotAllSubFeaturesAreInstalled -Skip:(-not ($runOnServerSkuOnly -and -not $isWMFServer -and -not($isWMFServerCore))) {
            $featureName = "Test1"

            Remove-WindowsFeature $featureName -ErrorAction Ignore
            Add-WindowsFeature -Name $featureName

            # SNMP-Servicehas one subfeatures (i.e.,SNMP-WMI-Provider).
            # In this scenario, we are not installing any subfeatures.
            # Hence we expect Get-TargetResource to report IncludeAllSubFeature to be $false.
            $getResultAsHasTable = GetTargetResourceExecutionHelper $featureName  ;
            if($true -eq $getResultAsHasTable["IncludeAllSubFeature"])
            {
                Log -Error "Failed to detect that not all subfeatures are being installed."
            }
    }
    
    It TestSetTargetResourceCmdletWithCredentialsEnsurePresentSubFeaturesAreAdded -Skip:(-not ($runOnServerSkuOnly -and -not $isWMFServer -and -not($isWMFServerCore))) {
            try
            {  
                $Name = "Test1"


                $Ensure = "Present"
                $credential = LocalAdminCredentialGenerator ;

                MSFT_RoleResource\Set-TargetResource -Name $Name -Ensure $Ensure -IncludeAllSubFeature -Credential $credential
         
                $feature = Get-WindowsFeature -Name $Name

                if($feature.Installed -eq $false)
                {
                    throw "Failed to execute Set-TargetResource without credentials. I.e, failed to install role through Set-TargetResource"
                }

                foreach($currentSubFeature in $feature[0].SubFeatures)
                {
                    $feature = Get-WindowsFeature -Name $currentSubFeature

                    if($feature.Installed -eq $false)
                    {
                        throw "Failed to execute Set-TargetResource without credentials. I.e, failed to install subfeatures of a role through Set-TargetResource"
                    }
                }
            }
            catch
            {
                Log -Error "Failed to execute Set-TargetResource without credentials.  Actual Error is: $($($_.Exception).Message)" -Exception $_
            }
    }

    It TestSetTargetResourceCmdletWithCredentialsEnsureAbsentAndSubFeaturesAreRemoved -Skip:(-not ($runOnServerSkuOnly -and -not $isWMFServer -and -not($isWMFServerCore))) {
            try
            {  
                $Name = "Test1"

                $Ensure = "Absent"
                $credential = LocalAdminCredentialGenerator ;

                MSFT_RoleResource\Set-TargetResource -Name $Name -Ensure $Ensure -IncludeAllSubFeature -Credential $credential
         
                $feature = Get-WindowsFeature -Name $Name

                if($feature.Installed -eq $true)
                {
                    throw "Failed to execute Set-TargetResource without credentials. I.e, failed to install role through Set-TargetResource"
                }

                foreach($currentSubFeature in $feature[0].SubFeatures)
                {
                    $feature = Get-WindowsFeature -Name $currentSubFeature

                    if($feature.Installed -eq $true)
                    {
                        throw "Failed to execute Set-TargetResource without credentials. I.e, failed to install subfeatures of a role through Set-TargetResource"
                    }
                }
            }
            catch
            {
                Log -Error "Failed to execute Set-TargetResource without credentials.  Actual Error is: $($($_.Exception).Message)" -Exception $_
            }
    }
}
}