# ServiceBusForWindowsServerDsc

TODO: Setup Appveyor and Appveyor Badge

The ServiceBusForWindowServerDsc PowerShell module provides class-based DSC resources that run on WMF 5.0 RTM or 
greater, that can be used to deploy and manage a Service Bus for Windows Server farm.
This module's examples leverage the built-in Package resource in the PSDesiredStateConfiguration module in WMF 5.0 
to install the Service Bus for Windows Server  Web Platform Installer package.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Contributing
If you would like to contribute to this repository, please read the DSC Resource Kit [contributing guidelines](https://github.com/PowerShell/DscResource.Kit/blob/master/CONTRIBUTING.md).

## Resources

* **SBFarm** creates and sets certain settings for a Service Bus for Windows Server farm.
* **SBHost** adds, removes a Service Bus for a Windows Server host, and starts, stops and updates settings for a Service Bus for a Windows Server host.
* **SBMessageContainer** adds and removes a Service Bus for Windows Server message container.
* **SBNamespace** adds, removes and updates settings for a Service Bus for Windows Server namespace.

### SBFarm

{ Detailed description of resource 1 - Please include any requirements for running this resource (e.g. Must run on Windows Server OS, must have Exchange already installed) }

* {**Property1**: Description of resource 1 property 1}
* {**Property2**: Description of resource 1 property 2}
* ...

### SBHost

{ Detailed description of resource 2 - Please include any requirements for running this resource (e.g. Must run on Windows Server OS, must have Exchange already installed) }

* {**Property1**: Description of resource 2 property 1}
* {**Property2**: Description of resource 2 property 2}
* ...

### SBMessageContainer

{ Detailed description of resource 2 - Please include any requirements for running this resource (e.g. Must run on Windows Server OS, must have Exchange already installed) }

* {**Property1**: Description of resource 2 property 1}
* {**Property2**: Description of resource 2 property 2}
* ...

### SBNamespace

{ Detailed description of resource 2 - Please include any requirements for running this resource (e.g. Must run on Windows Server OS, must have Exchange already installed) }

* {**Property1**: Description of resource 2 property 1}
* {**Property2**: Description of resource 2 property 2}
* ...

## Versions

### Unreleased

* SBAuthorizationRule resource (WIP)
* SBHostCEIP resource (WIP)
* SBRuntimeSetting resource (WIP)

### 0.6.0

* Reorg and rename of module to ServiceBusForWindowsServerDsc

### 0.5.0

* Initial release of cServiceBusForWindowsServer
