# cServiceBusForWindowsServer

The cServiceBusForWindowServer PowerShell module provides class-based DSC resources that run on WFM 5.0 RTM or greater, that can be used to deploy and manage a Service Bus for Windows Server farm.

This module is provided AS IS, and is no supported through any standard support program or service.
The "c" in cServiceBusForWindowsServer stands for community, which means that these resources will be fix forward and monitored by the module owner(s).

## Installation

To install the cServiceBusForWindowsServer module:

Unzip the content under $env:ProgramFiles\WindowsPowerShell\Modules folder.

To confirm installation:

Run Get-DSCResource to see that cServiceBusForWindowsServer is among the DSC Resources listed.

## Requirements

This module requires the latest version of WMF / PowerShell (v5.0, which ships in Windows 10 or Windows Server 2016 and is available standalone for Windows 7 SP1 / Windows Server 2008 R2+). To easily use PowerShell 5.0 on older operating systems, install WMF 5.0 RTM or later. Please read the installation instructions that are present on both the download page and the release notes for WMF 5.0.

At the time of development, Service Bus 1.1 with Cumulative Update 1 was the most current version of Service Bus; thus the minimum recommended installable version with this DSC Resource module is Service Bus 1.1 with CU1.

This module's examples leverage the built-in Package resource in the PSDesiredStateConfiguration module in WMF 5.0. The Package resource is used to install Service Bus and its dependencies via the Web Platform Installer WebpiCmd.exe command line tool.

This module's examples also leverage

## DSC Resources

## Tests

## Preview Status

Currently the cServiceBusForWindowsServer module is a work in progress that is not yet feature complete. The team is working towards a feature complete version 1.0.

## Examples

Review the "examples" directory in the cServiceBusForWindowsServer module for some general examples of how the overall module can be used.

## Version History

### 0.5.0

* Initial release of cServiceBusForWindowsServer