# ServiceBusForWindowsServerDsc

[![Build status](https://ci.appveyor.com/api/projects/status/vbumg651tfp6o7os/branch/dev?svg=true)](https://ci.appveyor.com/project/ryanspletzer/servicebusforwindowsserverdsc/branch/dev)

The ServiceBusForWindowServerDsc PowerShell module provides class-based DSC resources that run on WMF 5.0 RTM or
greater, that can be used to deploy and manage a Service Bus for Windows Server farm.
This module's examples leverage the built-in Package resource in the PSDesiredStateConfiguration module in WMF 5.0
to install the Service Bus for Windows Server  Web Platform Installer package.

This project has adopted the
[Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact
[opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Contributing
If you would like to contribute to this repository, please read the DSC Resource Kit
[contributing guidelines](https://github.com/PowerShell/DscResource.Kit/blob/master/CONTRIBUTING.md).

## Resources

* [**SBFarm**](#sbfarm) creates a new farm and sets certain settings for a Service Bus for Windows Server farm.
* [**SBHost**](#sbhost) adds, removes a Service Bus for a Windows Server host, and starts, stops and updates
settings for a Service Bus for a Windows Server host.
* [**SBMessageContainer**](#sbmessagecontainer) adds and removes a Service Bus for Windows Server message container.
* [**SBNamespace**](#sbnamespace) adds, removes and updates settings for a Service Bus for Windows Server namespace.
* [**SBAuthorizationRule**](#sbauthorizationrule) adds, removes and updates settings for a Service Bus for Windows
Server authorization rule.
* [**SBHostCEIP**](#sbhostceip) enables or disables Customer Experience Improvement Program telemetry.

### SBFarm

**SBFarm** creates a new Service Bus for Windows Server farm and sets certain settings farm level settings. Note:
Due to the nature of the product, some settings are not modifiable after a farm is created.

* **AdminApiCredentials**: Sets the resource provider credentials. The resource provider is a component that
exposes the management API to the (Azure Pack) portal. There are two Service Bus management portals; the Admin
portal (which provides a set of resource provider APIs for farm administration), and the Tenant portal (which
is the Windows Azure Management Portal). Use these credentials when you manually install the server farm and
connect to the Admin portal.
* **AdminGroup**: Respresents the admin group of the farm. If not specified the default value will be the
BUILTIN\Administrators of the machine where the resource is running from. Recommend using an Active Directory group
for any multi-server scenarios.
* **AmqpPort**: This optional parameter sets the AMQP port. The default 5672. This setting cannot be changed after
the farm has been provisioned.
* **AmqpsPort**: This optional parameter sets the AMQP SSL port. The default is 5671. This setting cannot be changed
after the farm has been provisioned.
* **CertificateAutoGenerationKey**: This passphrase is required for certificate auto generation. This parameter is
mandatory if you want certificates to be auto generated.
* **EncryptionCertificateThumbprint**: This certificate is used for securing the SQL connection strings. If not
provided, it will take the value of the FarmCertificateThumbprint (TLS cert). Represents the encryption certificate.
* **$FarmCertificateThumbprint**: Represents the certificate that is used for securing TLS connections. Do not
provide this certificate if you are providing CertificateAutoGenerationKey for auto generation of certificates.
* **FarmDNS**: The DNS prefix (alias) that is mapped to all server farm nodes. This cmdlet is used when an
administrator registers a server farm. The server farm node value is returned when you call the
Get-SBClientConfiguration cmdlet to request a connection string.
* **GatewayDBConnectionStringCredential**: The credential for connecting to the database. Not required if integrated
authentication will be used. The default value for this will be the same as that specified for farm management
database credentials.
* **GatewayDBConnectionStringDataSource**: The database server used for the gateway database. This is used in the
GatewayDBConnectionString when creating the farm. This can optionally used named instance and port info if those are
being used. The default value for this will be the same as that specified for farm management database server.
* **$GatewayDBConnectionStringEncrypt**: Represents whether the database server housing the gateway database will
use SSL/TLS or not. The default value for this will be the same as that specified for farm management database
server.
* **GatewayDBConnectionStringInitialCatalog**: The name of the gateway database. The default is 'SBGatewayDatabase'.
* **GatewayDBConnectionStringIntegratedSecurity**: Represents whether authentication to the farm management database
will use integrated Windows authentication or SSPI (Security Support Provider Interface) which supports Kerberos or
regular SQL authentication. The default value for this will be the same as that specified for farm management
database security.
* **HttpsPort**: Represents the port that the Service Bus for Windows Server uses for HTTPS communication. The
default is 9355. This setting cannot be changed after the farm has been provisioned.
* **InternalPortRangeStart**: Represents the start of the port range that the Service Bus for Windows Server uses
for internal communication purposes. The default is 9000. This setting cannot be changed after the farm has been
provisioned.
* **MessageBrokerPort**: Represents the port that the Service Bus for Windows Server uses for MessageBroker
communication. The default is 9356. This setting cannot be changed after the farm has been provisioned.
* **MessageContainerDBConnectionStringCredential**: The credential for connecting to the message container database.
Not required if integrated authentication will be used. The default value for this will be the same as that
specified for farm management database credentials.
* **MessageContainerDBConnectionStringDataSource**: The database server used for the message container database.
This is used in the MessageContainerDBConnectionString when creating the farm. This can optionally used named
instance and port info if those are being used. The default value for this will be the same as that specified for
farm management database server.
* **MessageContainerDBConnectionStringEncrypt**: Represents whether the database server housing the message
container database will use SSL/TLS or not. The default value for this will be the same as that specified for farm
management database server.
* **MessageContainerDBConnectionStringInitialCatalog**: The name of the initial message container database. Default
value is 'SBMessageContainer01'.
* **MessageContainerDBConnectionStringIntegratedSecurity**: Represents whether authentication to the message
container database will use integrated Windows authentication or SSPI (Security Support Provider Interface) which
supports Kerberos or regular SQL authentication. The default value for this will be the same as that specified for
farm management database security.
* **RPHttpsPort**: This optional parameter specifies the Resource Provider port setting. This port is used by the
portal to access the Service Bus farm. The default is 9359. This setting cannot be changed after the farm has been
provisioned.
* **RunAsAccount**: Represents the account under which the service runs. This account must be a domain account.
* **SBFarmDBConnectionStringCredential**: The credential for connecting to the database. Not required if integrated
authentication will be used.
* **SBFarmDBConnectionStringDataSource**: Represents the database server used for the farm management database. This
is used in the SBFarmDBConnectionString when creating the farm. This can optionally use named instance and port info
if those are being used.
* **SBFarmDBConnectionStringEncrypt**: Represents whether the connection to the database server housing the farm
management database will use SSL/TLS or not. Default value is false.
* **SBFarmDBConnectionStringInitialCatalog**: The name of the farm management database. Default value is
'SBManagementDB'.
* **SBFarmDBConnectionStringIntegratedSecurity**: Represents whether authentication to the farm management
database will use integrated Windows authentication or SSPI (Security Support Provider Interface) which supports
Kerberos, Windows or basic SQL authentication. (i.e. it will fall back to first available auth method from Kerberos
-> Windows -> SQL Auth). Valid values include True, False and SSPI. The default value is SSPI.
* **TcpPort**: Represents the port that the Service Bus for Windows Server uses for TCP. The default is 9354. This
setting cannot be changed after the farm has been provisioned.
* **TenantApiCredentials**: Sets the resource provider credentials for the tenant portal. The resource provider is a
component that exposes the management API to the (Azure Pack) portal. There are two Service Bus management portals;
the Admin portal (which provides a set of resource provider APIs for farm administration), and the Tenant portal
(which is the Windows Azure Management Portal). Use these credentials when you manually install the server farm and
connect to the tenant portal.

### SBHost

**SBHost** adds and removes a host from a farm, and starts, stops and updates settings for a Service Bus for Windows
Server host.

* **CertificateAutoGenerationKey**: This passphrase is required for certificate auto generation. This parameter is
mandatory if you want certificates to be auto generated.
* **EnableFirewallRules**: Enables or disables your firewall rules.
* **ExternalBrokerPort**: Represents the port that the Service Bus for Windows Server uses for ExternalBroker
communication.
* **ExternalBrokerUrl**: Specifies a case-sensitive ExternalBroker URI.
* **RunAsPassword**: Specifies the password for the user account under which services are running on the farm. If
all the machines in a farm share the same service account and the security policy requires the service account
password to be changed at regular intervals, you must perform specific actions on each machine in the farm to be
able to continue adding and removing nodes in the farm. See the section titled [Managing Farm Password Changes Using
Cmdlets](https://msdn.microsoft.com/en-us/library/dn441427.aspx) for this procedure.
* **SBFarmDBConnectionStringCredential**: The credential for connecting to the database. Not required if integrated
authentication will be used.
* **SBFarmDBConnectionStringDataSource**: Represents the database server used for the farm management database. This
is used in the SBFarmDBConnectionString when creating the farm. This can optionally use named instance and port info
if those are being used.
* **SBFarmDBConnectionStringEncrypt**: Represents whether the connection to the database server housing the farm
management database will use SSL/TLS or not. Default value is false.
* **SBFarmDBConnectionStringInitialCatalog**: The name of the farm management database. The default is
'SBManagementDB'.
* **SBFarmDBConnectionStringIntegratedSecurity**: Represents whether authentication to the farm management database'
will use integrated Windows authentication or SSPI (Security Support Provider Interface) which supports Kerberos,
Windows or basic SQL authentication. (i.e. it will fall back to first available auth method from Kerberos -> Windows
-> SQL Auth). Valid values include True, False and SSPI. The default value is SSPI.
* **Started**: Indicates whether host should be in started or stopped state. Default is true / started.
* **Ensure**: Marks whether the host should be Present or Absent.

### SBMessageContainer

**SBMessageContainer** adds and removes a Service Bus for Windows Server message container.

* **ContainerDBConnectionStringCredential**: The credential for connecting to the container database. Not required
if integrated authentication will be used.
* **ContainerDBConnectionStringDataSource**: Represents the database server used for the farm management database.
This is used in the ContainerDBConnectionString when creating the farm. This can optionally use named instance and
port info if those are being used.
* **ContainerDBConnectionStringEncrypt**: Represents whether the connection to the database server housing the
container database will use SSL\TLS or not. Default value is false.
* **ContainerDBConnectionStringInitialCatalog**: The name of the container database.
* **ContainerDBConnectionStringIntegratedSecurity**: Represents whether authentication to the container database
will use integrated Windows authentication or SSPI (Security Support Provider Interface) which supports Kerberos,
Windows or basic SQL authentication. (i.e. it will fall back to first available auth method from Kerberos -> Windows
-> SQL Auth). Valid values include True, False and SSPI.The default value is SSPI.
* **SBFarmDBConnectionStringCredential**: The credential for connecting to the farm management database. Not
required if integrated authentication will be used.
* **SBFarmDBConnectionStringDataSource**: Represents the database server used for the farm management database. This
is used in the SBFarmDBConnectionString when creating the farm. This can optionally use named instance and port info
if those are being used.
* **SBFarmDBConnectionStringEncrypt**: Represents whether the connection to the database server housing the farm
management database will use SSL\TLS or not. Default value is false.
* **SBFarmDBConnectionStringInitialCatalog**: The name of the farm management database. The default is
'SBManagementDB'.
* **SBFarmDBConnectionStringIntegratedSecurity**: Represents whether authentication to the farm management database
will use integrated Windows authentication or SSPI (Security Support Provider Interface) which supports Kerberos,
Windows or basic SQL authentication. (i.e. it will fall back to first available auth method from Kerberos -> Windows
-> SQL Auth). Valid values include True, False and SSPI.The default value is SSPI.
* **Ensure**: Marks whether the container should be Present or Absent.

### SBNamespace

**SBNamespace** adds, removes and updates settings for a Service Bus for Windows Server namespace.

* **AddressingScheme**: Specifies the addressing scheme used in the service namespace. The possible values for this
parameter are Path (default value), DNSRegistered, Cloud, and PathWithServiceId. Default value is Path.
* **DNSEntry**: Specifies the DNS Entry if DNSRegistered is chosen for AddressingScheme.
* **IssuerName**: Specifies the name of the trusted security issuer.
* **IssuerUri**: Specifies a case-sensitive issuer URI.
* **ManageUsers**: Specifies user or group name(s) that will be managers of the service namespace.
* **Name**: Specifies the name for the new Service Bus for Windows Server service namespace.
* **PrimarySymmetricKey**: Specifies the primary key to be used in this service namespace.
* **SecondarySymmetricKey**: Specifies the secondary key to be used in this service namespace.
* **SubscriptionId**: An optional parameter that associates a namespace with a subscription. For example, this
parameter is useful if an administrator creates a namespace on behalf of a user.
* **Ensure**: Marks whether the namespace should be Present or Absent.
* **ForceRemoval**: If Ensure is Absent and the namespace is present, setting this property to true will add the
-Force to Remove-SBNamespace call. Default value is false.

### SBAuthorizationRule

**SBAuthorizationRule** adds, removes and updates settings for a Service Bus for Windows Server authorization rule.

* **Name**: The name of the authorization rule.
* **NamespaceName**: The namespace scope of the authorization rule.
* **PrimaryKey**: The key that will be used by this authorization rule. If not provided, Service Bus generates a
key. You can explicitly set this parameter if you want to reinstall a farm while keeping the client untouched.
* **Rights**: The comma separated list of access rights enabled with this authorization rule. Access rights include
Manage, Send and Listen. If not specified, defaults to full rights (Listen, Send, and Manage).
* **SecondaryKey**: The key which will be used by this authorization rule. If not provided, Service Bus generates a
key. You can explicitly set this parameter if you want to reinstall a farm while keeping the client untouched.
* **Name**: Specifies the name for the new Service Bus for Windows Server service namespace.
* **PrimarySymmetricKey**: Specifies the primary key to be used in this service namespace.
* **SecondarySymmetricKey**: Specifies the secondary key to be used in this service namespace.
* **Ensure**: Marks whether the authorization rule should be Present or Absent.

### SBHostCEIP

**SBHostCEIP** enables or disables Customer Experience Improvement Program telemetry.

* **Ensure**: Marks whether the Customer Experience Improvement Program telemetry should be Present (enabled) or
Absent (disabled).

### SBRuntimeSetting

WIP

## Versions

### Unreleased

* SBRuntimeSetting resource (WIP)

### 0.8.0

* Added SBHostCEIP resource

### 0.7.0

* Added SBAuthorizationRule resource

### 0.6.0

* Reorg and rename of module to ServiceBusForWindowsServerDsc

### 0.5.0

* Initial release of cServiceBusForWindowsServer
