# escape=`
FROM microsoft/nanoserver:nanoservertest
COPY * C:/Git/xDesiredStateConfiguration/
RUN powershell.exe -executionpolicy bypass -Command "Get-ComputerInfo" -Verbose