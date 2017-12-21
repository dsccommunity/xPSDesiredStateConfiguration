# escape=`
FROM microsoft/nanoserver
COPY * C:/Git/xDesiredStateConfiguration/
RUN powershell.exe -executionpolicy bypass -Command "Get-ComputerInfo" -Verbose