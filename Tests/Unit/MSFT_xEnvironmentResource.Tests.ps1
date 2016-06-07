# These tests must be run with elevated access

$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'xPSDesiredStateConfiguration' `
    -DSCResourceName 'MSFT_xEnvironmentResource' `
    -TestType Unit

InModuleScope 'MSFT_xEnvironmentResource' {
    function Get-EnvironmentVariable
    {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true, Position = 0)]
            [string] 
            $Name,

            [string]
            $Target
        )
    
        switch ($Target) 
        { 
            "Machine" 
            {
                $regItem = get-item -Path "HKLM:\\System\\CurrentControlSet\\Control\\Session Manager\\Environment"
                $regItem.GetValue($Name)
                break
            } 

            "User"
            {
                $regItem = get-item -Path "HKCU:\\Environment"
                $regItem.GetValue($Name)
                break
            } 

            default 
            {
                [Environment]::GetEnvironmentVariable($Name) 
            }
        }
    }

    Describe 'xEnvironment Unit Tests' {
        <#
            .SYNOPSIS
                Retrieve an existing environment variable using Get-TargetResource     
           
            .DESCRIPTION
                - Query a well known machine-wide env variable and make sure it exists
                - Validate the retrieved value     
        #>
        It 'GetEnvVarExisting' {
            #------
            # SETUP
            $envVar = "Username"        
        
            #-----
            # TEST        
            $retrievedVar = Get-TargetResource -Name $envVar

            # Verify the environmnet variable $envVar is successfully retrieved
            $retrievedVar.Ensure | Should Be "Present"

            $matchVar = Get-EnvironmentVariable -Name $envVar -Target "Machine"
            $retrievedVarValue = $retrievedVar.Value

            # Verify the $retrievedVar environmnet variable value matches the value retrieved using [Environment] API
            $retrievedVarValue | Should Be $matchVar

            #--------
            # CLEANUP
        }

        <#
            .SYNOPSIS
                Try to retrieve a non-existing environment variable using Get-TargetResource (Negative Test)

            .DESCRIPTION
                - Query a non-existing env variable and make sure we receive Ensure=Absent    
        #>
        It 'GetEnvVarNonExisting' {
            #------
            # SETUP
            $envVar = "BlahVar"
            Set-TargetResource -Name $envVar -Ensure Absent
        
            #-----
            # TEST    
            $retrievedVar = Get-TargetResource -Name $envVar

            # Verify the environmnet variable $envVar is not found
            $retrievedVar.Ensure | Should Be "Absent"       
    
            #--------
            # CLEANUP
        }

        <#
            .SYNOPSIS
            Create a new environment variable with no Value specified
        #>
        It 'SetNewEnvVarNoValueSpecified' {
            #------
            # SETUP
            $envVar = "TestEnvVar"
            Set-TargetResource -Name $envVar -Ensure Absent
        
            #-----
            # TEST
            Set-TargetResource -Name $envVar
        
            # Now retrieve the created variable
            $retrievedVar = Get-TargetResource -Name $envVar

            # Verify the environmnet variable $envVar is successfully created
            $retrievedVar.Ensure | Should Be "Present"       

            # Verify the create environmnet variable's value is set to default value [String]::Empty
            $retrievedVar.Value | Should Be $([String]::Empty)

            #--------
            # CLEANUP        
            # Remove the created test variable
            Set-TargetResource -Name $envVar -Ensure Absent
        }

        <#
            .SYNOPSIS
            Create a new environment variable with Value specified
        #>
        It 'SetNewEnvVarValueSpecified' {
            #------
            # SETUP
            $envVar = "TestEnvVar"
            $val = "TestEnvVal"
            Set-TargetResource -Name $envVar -Ensure Absent
        
            #-----
            # TEST
            Set-TargetResource -Name $envVar -Value $val
        
            # Now retrieve the created variable
            $retrievedVar = Get-TargetResource -Name $envVar

            # Verify the environmnet variable $envVar is successfully created
            $retrievedVar.Ensure | Should Be "Present"       

            # Verify the create environmnet variable's value is set to default value [String]::Empty
            $retrievedVar.Value | Should Be $val

            #--------
            # CLEANUP        
            # Remove the created test variable
            Set-TargetResource -Name $envVar -Ensure Absent
        }

        <#
            .SYNOPSIS
            Update existing environment variable with new Value
        #>
        It 'SetEnvVarUpdateValue' {
            #------
            # SETUP
            $envVar = "TestEnvVar"
            $val = "TestEnvVal"
            Set-TargetResource -Name $envVar -Value $val
        
            #-----
            # TEST
            $newVal = "TestEnvNewVal"
            Set-TargetResource -Name $envVar -Value $newVal
        
            # Now retrieve the created variable
            $retrievedVar = Get-TargetResource -Name $envVar

            # Verify the environmnet variable $envVar is successfully updated
            $retrievedVar.Value | Should Not Be $val
            $retrievedVar.Value | Should Be $newVal

            #--------
            # CLEANUP        
            # Remove the created test variable
            Set-TargetResource -Name $envVar -Ensure Absent
        }

        <#
            .SYNOPSIS
            Remove an environment variable (Ensure=Absent)
        #>
        It 'SetEnvVarAbsent' {
            #------
            # SETUP
            $envVar = "TestEnvVar"
            $val = "TestEnvVal"
            Set-TargetResource -Name $envVar -Value $val
        
            #-----
            # TEST            
            Set-TargetResource -Name $envVar -Ensure Absent
        
            # Now try to retrieve the created variable
            $retrievedVar = Get-TargetResource -Name $envVar

            # Verify the environmnet variable no more exists
            $retrievedVar.Ensure | Should Be "Absent"

            #--------
            # CLEANUP
        }

        <#
            .SYNOPSIS
            Update a path environment variable
        #>
        It 'SetEnvPathVarUpdate' {
            #------
            # SETUP
            $envVar = "TestEnvVar"
            $val = "A;B;C"
            Set-TargetResource -Name $envVar -Value $val -Path $true
        
            #-----
            # TEST         
            $addPathVal = "D"   
            Set-TargetResource -Name $envVar -Value $addPathVal -Path $true
        
            $expectedFinalVal = $val + ";" + $addPathVal
            # Now try to retrieve the created variable
            $retrievedVar = Get-TargetResource -Name $envVar

            # Verify the environmnet variable no more exists
            $retrievedVar.Value | Should Be $expectedFinalVal

            #--------
            # CLEANUP  
            Set-TargetResource -Name $envVar -Ensure Absent
        }

        <#
            .SYNOPSIS
            Remove a sub-path from a path environment variable
        #>
        It 'SetEnvPathVarUpdateAbsent' {
            #------
            # SETUP
            $envVar = "TestEnvVar"
            $val = "A;B;C"
            Set-TargetResource -Name $envVar -Value $val -Path $true
        
            #-----
            # TEST         
            $removePathVal = "C"   
            Set-TargetResource -Name $envVar -Value $removePathVal -Path $true -Ensure Absent
        
            $expectedFinalVal = "A;B"
            # Now try to retrieve the created variable
            $retrievedVar = Get-TargetResource -Name $envVar

            # Verify the environmnet variable no more exists
            $retrievedVar.Value | Should Be $expectedFinalVal

            #--------
            # CLEANUP        
            Set-TargetResource -Name $envVar -Ensure Absent
        }

        <#
            .SYNOPSIS
            Remove a path environment variable by removing all its sub-path
        #>
        It 'SetEnvPathVarRemove' {
            #------
            # SETUP
            $envVar = "TestEnvVar"
            $val = "A;B;C"
            Set-TargetResource -Name $envVar -Value $val -Path $true
        
            #-----
            # TEST         
            $removePathVal = "C;B;A"   
            Set-TargetResource -Name $envVar -Value $removePathVal -Path $true -Ensure Absent
                    
            # Now try to retrieve the created variable
            $retrievedVar = Get-TargetResource -Name $envVar

            # Verify the environmnet variable no more exists
            $retrievedVar.Ensure | Should Be "Absent"

            #--------
            # CLEANUP        
            Set-TargetResource -Name $envVar -Ensure Absent
        }

        <#
            .SYNOPSIS 
            Test that a created environment variable is present
        #>
        It 'TestEnvVarPresentNoValue' {
            #------
            # SETUP
            $envVar = "BlahVar"                       
            Set-TargetResource -Name $envVar

            #-----
            # TEST                                                                             
            # Test the created environmnet variable
            Test-TargetResource -Name $envVar | Should Be $true

            #--------
            # CLEANUP        
            Set-TargetResource -Name $envVar -Ensure Absent
        }

        <#
            .SYNOPSIS
            Test that an environment environment with a specific value exists
        #>
        It 'TestEnvVarPresentWithValue' {
            #------
            # SETUP
            $envVar = "BlahVar"   
            $val = "BlahVal"                    
            Set-TargetResource -Name $envVar -Value $val

            #-----
            # TEST                                                                             
            # Verify the environmnet variable exists
            Test-TargetResource -Name $envVar -Value $val | Should Be $true

            #--------
            # CLEANUP        
            Set-TargetResource -Name $envVar -Ensure Absent
        }

        <#
            .SYNOPSIS
            Test that an environment environment is absent
        #>
        It 'TestEnvVarAbsent' {
            #------
            # SETUP
            $envVar = "BlahVar"               
            Set-TargetResource -Name $envVar -Ensure Absent

            #-----
            # TEST                                                                             
            # Verify the environmnet variable exists
            Test-TargetResource -Name $envVar -Ensure Absent | Should Be $true

            #--------
            # CLEANUP        
             Set-TargetResource -Name $envVar -Ensure Absent
        }

        <#
            .SYNOPSIS
            Test that a path exists in a path environment variable
        #>
        It 'TestEnvVarPathPresent' {
            #------
            # SETUP
            $envVar = "PathVar"                     
            $val = "A;B;C"  
            Set-TargetResource -Name $envVar -Value $val -Path $true

            #-----
            # TEST                                               
            $subpath = "B"
                                          
            # Test a sub-path exists in environment variable
            Test-TargetResource -Name $envVar -Value $subpath -Path $true | Should Be $true

            #--------
            # CLEANUP        
            Set-TargetResource -Name $envVar -Ensure Absent
        }

        <#
            .SYNOPSIS
            Test that a matching but shuffled path exists in a path environment variable
        #>
        It 'TestEnvVarCaseInsensitiveShuffledPathPresent' {
            #------
            # SETUP
            $envVar = "PathVar"                     
            $val = "A;B;C"  
            Set-TargetResource -Name $envVar -Value $val -Path $true

            #-----
            # TEST                                               
            $subpath = "B;a;c"
                                                      
            Test-TargetResource -Name $envVar -Value $subpath -Path $true | Should Be $true

            #--------
            # CLEANUP        
            Set-TargetResource -Name $envVar -Ensure Absent
        }

        <#
        .SYNOPSIS: Test that a path does not exist in a path environment variable 
        #>
        It 'TestEnvVarPathAbsent' {
            #------
            # SETUP
            $envVar = "PathVar"                     
            $val = "A;B;C"  
            Set-TargetResource -Name $envVar -Value $val -Path $true

            #-----
            # TEST                                               
            $subpath = "D;E"
                                                      
            Test-TargetResource -Name $envVar -Value $subpath -Path $true -Ensure Absent | Should Be $true

            #--------
            # CLEANUP        
             Set-TargetResource -Name $envVar -Ensure Absent
        }

        <#
            .SYNOPSIS
            Retrieve an existing environment variable using Get-TargetResource

            .DESCRIPTION
                - Use a machine-wide predefined env variable 'windir'
                - Validate the retrieved value
        #>
        It 'GetExpandedStringVar' {
            #------
            # SETUP
            $envVar = "windir"
        
            #-----
            # TEST        
            $retrievedVar = Get-TargetResource -Name $envVar

            # Verify the environmnet variable $envVar is successfully retrieved
            $retrievedVar.Ensure | Should Be "Present"

            $matchVar = "%SystemRoot%"
            $retrievedVarValue = $retrievedVar.Value

            # Verify the $retrievedVar environmnet variable value matches the value retrieved using [Environment] API
            $retrievedVarValue | Should Be $matchVar

            #--------
            # CLEANUP
        }
    }
}
