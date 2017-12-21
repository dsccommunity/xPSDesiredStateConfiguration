# escape=`
FROM microsoft/nanoserver:nanotest
COPY * C:/Git/xDesiredStateConfiguration
RUN powershell.exe -executionpolicy bypass -Command "Get-ComputerInfo" -Verbose