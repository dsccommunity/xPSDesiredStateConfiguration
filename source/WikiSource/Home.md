# Welcome to the xPSDesiredStateConfiguration wiki

<sup>*xPSDesiredStateConfiguration v#.#.#*</sup>

Here you will find all the information you need to make use of the xPSDesiredStateConfiguration
DSC resources, including details of the resources that are available, current
capabilities and known issues, and information to help plan a DSC based
implementation of xPSDesiredStateConfiguration.

Please leave comments, feature requests, and bug reports in then
[issues section](https://github.com/dsccommunity/xPSDesiredStateConfiguration/issues) for this module.

## Getting started

To get started download xPSDesiredStateConfiguration from the [PowerShell Gallery](http://www.powershellgallery.com/packages/xPSDesiredStateConfiguration/)
and then unzip it to one of your PowerShell modules folders
(such as $env:ProgramFiles\WindowsPowerShell\Modules).

To install from the PowerShell gallery using PowerShellGet (in PowerShell 5.0)
run the following command:

```powershell
Find-Module -Name xPSDesiredStateConfiguration -Repository PSGallery | Install-Module
```

To confirm installation, run the below command and ensure you see the xPSDesiredStateConfiguration
DSC resources available:

```powershell
Get-DscResource -Module xPSDesiredStateConfiguration
```

## Change Log

A full list of changes in each version can be found in the [change log](https://github.com/dsccommunity/xPSDesiredStateConfiguration/blob/main/CHANGELOG.md).
