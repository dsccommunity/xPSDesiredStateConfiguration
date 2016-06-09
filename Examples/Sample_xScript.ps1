Configuration xScriptExample {
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    xScript ScriptExample
    {
        SetScript = { 
            $sw = New-Object System.IO.StreamWriter("C:\TempFolder\TestFile.txt")
            $sw.WriteLine("Some sample string")
            $sw.Close()
        }

        TestScript = { Test-Path "C:\TempFolder\TestFile.txt" }

        GetScript = { <# This must return a hash table #> 
            @{ 
                Path = "C:\TempFolder\TestFile.txt"
                LineToWrite = "Some sample string" 
            }
        }          
    }
}