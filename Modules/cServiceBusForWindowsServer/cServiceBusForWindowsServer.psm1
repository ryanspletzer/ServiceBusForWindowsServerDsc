enum Ensure {
    Absent
    Present
}


enum IntegratedSecurity {
    True
    False
    SSPI
}


<#
    This is the base Service Bus for Windows Server resource class that provides commonly used methods.
#>
class cSBBase {
    <#
        Returns the property names and values of the class object as a hashtable.
    #>
    [hashtable] ToHashtable() {
        $hashtable = @{}
        Get-Member -InputObject $this |
            Where-Object MemberType -eq "Property" |
            ForEach-Object { $hashtable.Add($_.Name, $this.($_.Name)) }
        return $hashtable
    }

    <#
        Allows for getting properties on the class object by name.
    #>
    [object] GetProperty([System.Object]$name) {
        $type = $this.GetType()
        $propertyInfo = $type.GetProperty($name)
        return $propertyInfo.GetValue($this)
    }

    <#
        Allows for setting properties on the class object by name.
    #>
    [void] SetProperty([System.Object]$name, [System.Object]$value) {
        $type = $this.GetType()
        $propertyInfo = $type.GetProperty($name)
        $propertyInfo.SetValue($this, $value)
    }

    <#
        Gets the NotConfigurable DscProperty names and values of the class object as a hashtable.
    #>
    [hashtable] GetDscNotConfigurablePropertiesAsHashtable() {
        $hashtable = @{}
        $props = $this.GetType().GetProperties() |
            Where-Object CustomAttributes -ne $null
        ForEach ($prop in $props) {
            $dscPropertyAttributesWithNamedArguments = $prop.CustomAttributes |
                Where-Object {
                    $_.AttributeType.Name -eq "DscPropertyAttribute" -and $_.NamedArguments -ne $null
                }
            $notConfigurables = $dscPropertyAttributesWithNamedArguments |
                ForEach-Object {
                    $_.NamedArguments |
                        Where-Object MemberName -eq "NotConfigurable"
                }
            if ($notConfigurables.Count -gt 0) {
                $hashtable.Add($prop.Name, $this.($prop.Name))
            }
        }
        return $hashtable
    }

    <#
        Gets the configurable DscProperty names and values of the class object as a hashtable.
    #>
    [hashtable] GetDscConfigurablePropertiesAsHashtable() {
        $hashtable = @{}
        $props = $this.GetType().GetProperties() |
            Where-Object CustomAttributes -ne $null
        ForEach ($prop in $props) {
            $dscPropertyAttributesWithNamedArguments = $prop.CustomAttributes |
                Where-Object {
                    $_.AttributeType.Name -eq "DscPropertyAttribute"
                }
            $notConfigurables = $dscPropertyAttributesWithNamedArguments |
                ForEach-Object {
                    $_.NamedArguments |
                        Where-Object MemberName -eq "NotConfigurable"
                }
            if ($notConfigurables.Count -gt 0) {
                continue
            } else {
                $hashtable.Add($prop.Name, $this.($prop.Name))
            }
        }
        return $hashtable
    }
}


<#
    This resource manages install bits for Service Bus for Windows Server.

    Note: Web Platform installer requires .NET Framework 3.5 (NET-Framework-Features).

    Requires the use of PsDscRunAsCredential to install.

    TODO: Just replace this with the built-in Package resource?

    http://www.codeisahighway.com/install-web-platform-installer-and-azure-sdk-using-powershell-dsc/
#>
# [DscResource()]
# class cSBBitsInstall : cSBBase {
#     <#
#         File path to the Web Platform installer Cmd line executable (regular or -x64 versions are both fine).
#         If you've extracted installers for offline mode, this executable is typically located in the /bin folder.
#     #>
#     [DscProperty(Mandatory)]
#     [string]
#     $WebpiCmdPath

#     <#
#         Specifies whether WebpiCmd.exe will install in online mode (from the internet) or offline mode.
#     #>
#     [DscProperty(Mandatory)]
#     [boolean]
#     $OnlineMode

#     <#
#         If not in online mode, the offline location for the WebpiCmd.exe command must be specified.
#     #>
#     [DscProperty()]
#     [string]
#     $WebpiXmlFeedPath

#     <#
#         Indicates absence or presence of the resource. Uninstalling the Service Bus bits is not supported by this
#         resource, so Absent is not a supported value here. If you wish to uninstall Service Bus bits, please do
#         so manually.
#     #>
#     [DscProperty(Key)]
#     [Ensure]
#     $Ensure

#     [DscProperty(NotConfigurable)]
#     [bool]
#     $NETFramework45Features

#     <#
#         NotConfigurable property used to specify if Microsoft Visual C++ 2012 Redistributable Package is installed.
#     #>
#     [DscProperty(NotConfigurable)]
#     [bool]
#     $VC11Redist_x64

#     <#
#         NotConfigurable property used to specify if Windows Imaging Component is installed.
#     #>
#     [DscProperty(NotConfigurable)]
#     [bool]
#     $WindowsImagingComponent

#     <#
#         NotConfigurable property used to specify if Windows Installer 3.1 is installed.
#     #>
#     [DscProperty(NotConfigurable)]
#     [bool]
#     $WindowsInstaller31

#     <#
#         NotConfigurable property used to specify if Windows Fabric is installed.
#     #>
#     [DscProperty(NotConfigurable)]
#     [bool]
#     $WindowsFabric

#     <#
#         NotConfigurable property used to specify if Service Bus 1.1 with CU1 is installed.
#     #>
#     [DscProperty(NotConfigurable)]
#     [bool]
#     $ServiceBus

#     [void] Set() {
#         if ($this.Ensure -eq [Ensure]::Absent) {
#             throw [Exception] ("cServiceBusForWindowsServer does not support uninstalling Service Bus or its " +
#                                "prerequisites. Please remove this manually.")
#         }

#         if ($null -eq (Get-WindowsFeature -Name NET-Framework-45-Features)) {
#             Write-Verbose -Message "Installing NET-Framework-45-Features"
#             Install-WindowsFeature -Name NET-Framework-45-Features
#         }

#         $installArgsFormat = "/Install /Products:{0} /AcceptEULA"

#         if ($this.OnlineMode -eq $false) {
#             if ([String]::IsNullOrEmpty($this.WebpiXmlFeedPath)) {
#                 throw [Exception] "If not in online mode parameter WebpiXmlFeedPath is required."
#             }
#             Write-Verbose -Message ("Not in OnlineMode, specifying WebpiXmlFeedPath $($this.WebpiXmlFeedPath) in " +
#                                     "install args")
#             $installArgsFormat += " /xml:$($this.WebpiXmlFeedPath)"
#         }

#         $installArgs = $installArgsFormat -f "ServiceBus_1_1_CU1"
#         Write-Verbose -Message "Getting new WebpiCmd.exe console executable process with $installArgs"
#         $process = New-cServiceBusForWindowsServerWebpiCmdProcess -Arguments $installArgs -FilePath $this.WebpiCmdPath
#         Write-Verbose -Message "Starting WebpiCmd.exe console executable process with $installArgs"
#         $process.Start()
#         Write-Verbose -Message "Waiting for exit from WebpiCmd.exe console executable process with $installArgs"
#         $process.WaitForExit()

#         switch ($process.ExitCode) {
#             0 {
#                 Write-Verbose -Message $process.StandardOutput.ReadToEnd()
#                 $process.Dispose()
#                 Write-Verbose -Message ("Web Platform Installer completed Service Bus 1.1 with CU1 install " +
#                                         "successfully.")
#             }
#             -1 {
#                 Write-Verbose -Message $process.StandardOutput.ReadToEnd()
#                 $process.Dispose()
#                 throw ("Web Platform Installer encountered an error for Service Bus 1.1 with CU1 with exit code " +
#                        "$($process.ExitCode)")
#             }
#             default {
#                 Write-Verbose -Message $process.StandardOutput.ReadToEnd()
#                 $process.Dispose()
#                 throw ("Web platform installer encountered an error for Service Bus 1.1 with CU1 with the following " +
#                        "unknown exit code  $($process.ExitCode)")
#             }
#         }
#     }

#     [bool] Test() {
#         if ($this.Ensure -eq "Absent") {
#             throw [Exception] ("cServiceBusForWindowsServer does not support uninstalling Service Bus or its " +
#                                "prerequisites. Please remove this manually.")
#         }

#         Write-Verbose -Message "Getting Current Values"
#         $CurrentValues = $this.Get()

#         Write-Verbose -Message "Testing installation of Service Bus for Windows Server 1.1 with CU1 prerequisites."
#         $params = @{
#             CurrentValues = $CurrentValues.ToHashtable()
#             DesiredValues = $this.ToHashtable()
#             ValuesToCheck = @("Ensure")
#         }
#         return Test-cServiceBusForWindowsServerSpecificParameters @params
#     }

#     [cSBBitsInstall] Get() {
#         $resultObject = [cSBBitsInstall]::new()

#         Write-Verbose -Message "Getting NET-Framework-45-Features Windows Feature"
#         $windowsFeature = Get-WindowsFeature -Name NET-Framework-45-Features
#         $resultObject.NETFramework45Features = $windowsFeature.Installed
#         Write-Verbose -Message ".NET Framework 4.5 installed: $($windowsFeature.Installed)"

#         Write-Verbose -Message "Checking Windows packages"
#         $installedItems = Get-CimInstance -ClassName Win32_Product

#         Write-Verbose -Message "Checking for Visual C++ 2012 Redistributable Package"
#         if (($installedItems |
#                 Where-Object {
#                     $_.Name -eq "Microsoft Visual C++ 2012 x64 Additional Runtime - 11.0.51106"
#                 }) -ne $null -and
#             ($installedItems |
#                 Where-Object {
#                     $_.Name -eq "Microsoft Visual C++ 2012 x64 Minimum Runtime - 11.0.51106"
#                 }) -ne $null) {
#             $resultObject.VC11Redist_x64 = $true
#         } else {
#             $resultObject.VC11Redist_x64 = $false
#         }
#         Write-Verbose -Message "Visual C++ 2012 Redistributable Package installed: $($resultObject.VC11Redist_x64)"

#         Write-Verbose -Message "Checking for Windows Imaging Component"
#         if ((Test-Path -Path "$env:SystemRoot\System32\WindowsCodecs.dll") -and
#             (Test-Path -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WIC)) {
#             $resultObject.WindowsImagingComponent = $true
#         } else {
#             $resultObject.WindowsImagingComponent = $false
#         }
#         Write-Verbose -Message "Windows Imaging Component installed: $($resultObject.WindowsImagingComponent)"

#         Write-Verbose -Message "Checking for Windows Installer 3.1"
#         $msiDll = (Get-Item -Path "$env:SystemRoot\System32\msi.dll")
#         if ($msiDll -ne $null -and $msiDll.VersionInfo.FileVersion -gt 3.1) {
#             $resultObject.WindowsInstaller31 = $true
#         } else {
#             $resultObject.WindowsInstaller31 = $false
#         }
#         Write-Verbose -Message "Windows Installer 3.1 installed: $($resultObject.WindowsInstaller31)"

#         Write-Verbose -Message "Checking for Windows Fabric 1.0.976.0"
#         if (($installedItems |
#                 Where-Object {
#                     $_.Name -eq "Windows Fabric"
#                     -and
#                     $_.Version -ge "1.0.976.0"
#                 }) -ne $null) {
#             $resultObject.WindowsFabric = $true
#         } else {
#             $resultObject.WindowsFabric = $false
#         }
#         Write-Verbose -Message "Windows Fabric installed: $($resultObject.WindowsFabric)"

#         Write-Verbose -Message "Checking for Service Bus 1.1 with CU1"
#         if (($installedItems |
#                 Where-Object {
#                     $_.Name -eq "Service Bus 1.1"
#                     -and
#                     $_.Version -ge "2.0.30904.0"
#                 }) -ne $null) {
#             $resultObject.ServiceBus = $true
#         } else {
#             $resultObject.ServiceBus = $false
#         }
#         Write-Verbose -Message "Service Bus for Windows Server 1.1 with CU1 installed: $($resultObject.ServiceBus)"

#         Write-Verbose -Message "Checking for false values to set Ensure to Absent/Present"
#         if (($resultObject.GetDscNotConfigurablePropertiesAsHashtable().Values |
#                 Where-Object { $_.GetType().Name -eq "Boolean" -and $_ -eq $false }).Count -gt 0) {
#             $resultObject.Ensure = 'Absent'
#         } else {
#             $resultObject.Ensure = 'Present'
#         }
#         Write-Verbose -Message "Ensure: $($resultObject.Ensure)"

#         Write-Verbose -Message "Getting WebpiCmdPath"
#         $resultObject.WebpiCmdPath = $this.WebpiCmdPath
#         Write-Verbose -Message "WebpiCmdPath: $($resultObject.WebpiCmdPath)"

#         Write-Verbose -Message "Getting OnlineMode"
#         $resultObject.OnlineMode = $this.OnlineMode
#         Write-Verbose -Message "OnlineMode: $($resultObject.OnlineMode)"

#         Write-Verbose -Message "Getting WebpiXmlFeedPath"
#         $resultObject.WebpiXmlFeedPath = $this.WebpiXmlFeedPath
#         Write-Verbose -Message "WebpiXmlFeedPath: $($resultObject.WebpiXmlFeedPath)"

#         return $resultObject
#     }
# }


<#
   This resource creates a Service Bus for Windows Server farm.
#>
[DscResource()]
class cSBFarmCreation : cSBBase {

    <#
        Sets the resource provider credentials. The resource provider is a component that exposes the management API
        to the portal. There are two Service Bus management portals; the Admin portal (which provides a set of
        resource provider APIs for farm administration), and the Tenant portal (which is the Windows Azure Management
        Portal). Use these credentials when you manually install the server farm and connect to the Admin portal.
    #>
    [DscProperty()]
    [pscredential]
    $AdminApiCredentials

    <#
        Respresents the admin group. If not specified the default value will be BUILTIN\Administrators.
    #>
    [DscProperty()]
    [string]
    $AdminGroup

    <#
        This optional parameter sets the AMQP port. The default 5672.
    #>
    [DscProperty()]
    [ValidateRange(1024,65535)]
    [int32]
    $AmqpPort = 5672

    <#
        This optional parameter sets the AMQP SSL port. The default is 5671.
    #>
    [DscProperty()]
    [ValidateRange(1024,65535)]
    [int32]
    $AmqpsPort = 5671

    <#
        This passphrase is required for certificate auto generation. This parameter is mandatory if you want
        certificates to be auto generated.
    #>
    [DscProperty()]
    [pscredential]
    $CertificateAutoGenerationKey

    <#
        This certificate is used for securing the SQL connection strings. If not provided, it will take the value of
        the SslCertificate. Represents the encryption certificate.
    #>
    [DscProperty()]
    [ValidateLength(30,100)]
    [string]
    $EncryptionCertificateThumbprint

    <#
        Represents the certificate that is used for securing the certificate. Do not provide this certificate if you
        are providing CertificateAutoGenerationKey for auto generation of certificates.
    #>
    [DscProperty()]
    [ValidateLength(30,100)]
    [string]
    $FarmCertificateThumbprint

    <#
        The DNS prefix that is mapped to all server farm nodes. This cmdlet is used when an administrator registers a
        server farm. The server farm node value is returned when you call the Get-SBClientConfiguration cmdlet to
        request a connection string.
    #>
    [DscProperty()]
    [string]
    $FarmDNS

    <#
        The credential for connecting to the database. Not required if integrated authentication will be used.
        The default value for this will be the same as that specified for farm management database credentials.
    #>
    [DscProperty()]
    [pscredential]
    $GatewayDBConnectionStringCredential

    <#
        The database server used for the gateway database. This is used in the GatewayDBConnectionString when
        creating the farm. This can optionally used named instance and port info if those are being used. The
        default value for this will be the same as that specified for farm management database server.
    #>
    [DscProperty()]
    [string]
    $GatewayDBConnectionStringDataSource

    <#
        Represents whether the database server housing the gateway database will use SSL or not. The default value
        for this will be the same as that specified for farm management database server.
    #>
    [DscProperty()]
    [bool]
    $GatewayDBConnectionStringEncrypt = $this.SBFarmDBConnectionStringEncrypt

    <#
        The name of the gateway database. The default is 'SBGatewayDatabase'.
    #>
    [DscProperty()]
    [string]
    $GatewayDBConnectionStringInitialCatalog = 'SBGatewayDatabase'

    <#
        Represents whether authentication to the farm management database will use integrated Windows authentication
        or SSPI (Security Support Provider Interface) which supports Kerberos or regular SQL authentication. The
        default value for this will be the same as that specified for farm management database security.
    #>
    [DscProperty()]
    [IntegratedSecurity]
    $GatewayDBConnectionStringIntegratedSecurity = $this.SBFarmDBConnectionStringIntegratedSecurity

    <#
        Represents the port that the Service Bus for Windows Server uses for HTTPS communication. The default is
        9355.
    #>
    [DscProperty()]
    [ValidateRange(1024,65535)]
    [int32]
    $HttpsPort = 9355

    <#
        Represents the start of the port range that the Service Bus for Windows Server uses for internal
        communication purposes. The default is 9000.
    #>
    [DscProperty()]
    [ValidateRange(1024,65535)]
    [int32]
    $InternalPortRangeStart = 9000

    <#
        Represents the port that the Service Bus for Windows Server uses for MessageBroker communication. The
        default is 9356.
    #>
    [DscProperty()]
    [ValidateRange(1024,65535)]
    [int32]
    $MessageBrokerPort = 9356

    <#
        The credential for connecting to the message container database. Not required if integrated authentication
        will be used. The default value for this will be the same as that specified for farm management database
        credentials.
    #>
    [DscProperty()]
    [pscredential]
    $MessageContainerDBConnectionStringCredential

    <#
        The database server used for the message container database. This is used in the
        MessageContainerDBConnectionString when creating the farm. This can optionally used named instance and port
        info if those are being used. The default value for this will be the same as that specified for farm
        management database server.
    #>
    [DscProperty()]
    [string]
    $MessageContainerDBConnectionStringDataSource

    <#
        Represents whether the database server housing the message container database will use SSL or not. The
        default value for this will be the same as that specified for farm management database server.
    #>
    [DscProperty()]
    [bool]
    $MessageContainerDBConnectionStringEncrypt = $false

    <#
        The name of the initial message container database.
    #>
    [DscProperty()]
    [string]
    $MessageContainerDBConnectionStringInitialCatalog = 'SBMessageContainer01'

    <#
        Represents whether authentication to the message container database will use integrated Windows
        authentication or SSPI (Security Support Provider Interface) which supports Kerberos or regular SQL
        authentication. The default value for this will be the same as that specified for farm management database
        security.
    #>
    [DscProperty()]
    [IntegratedSecurity]
    $MessageContainerDBConnectionStringIntegratedSecurity = $this.SBFarmDBConnectionStringIntegratedSecurity

    <#
        This optional parameter specifies the Resource Provider port setting. This port is used by the portal to
        access the Service Bus farm. The default is 9359.
    #>
    [DscProperty()]
    [ValidateRange(1024,65535)]
    [int32]
    $RPHttpsPort = 9359

    <#
        Represents the account under which the service runs. This account must be a domain account.
    #>
    [DscProperty(Mandatory)]
    [string]
    $RunAsAccount

    <#
        The credential for connecting to the database. Not required if integrated authentication will be used.
    #>
    [DscProperty()]
    [pscredential]
    $SBFarmDBConnectionStringCredential

    <#
        Represents the database server used for the farm management database. This is used in the
        SBFarmDBConnectionString when creating the farm. This can optionally use named instance and port info if
        those are being used.
    #>
    [DscProperty(Key)]
    [string]
    $SBFarmDBConnectionStringDataSource

    <#
        Represents whether the connection to the database server housing the farm management database will use SSL
        or not.
    #>
    [DscProperty()]
    [bool]
    $SBFarmDBConnectionStringEncrypt = $false

    <#
        The name of the farm management database. The default is 'SBManagementDB'.
    #>
    [DscProperty()]
    [string]
    $SBFarmDBConnectionStringInitialCatalog = 'SBManagementDB'

    <#
        Represents whether authentication to the farm management database will use integrated Windows authentication
        or SSPI (Security Support Provider Interface) which supports Kerberos or regular SQL authentication. The
        default value is False (i.e. a password must be specified).
    #>
    [DscProperty()]
    [IntegratedSecurity]
    $SBFarmDBConnectionStringIntegratedSecurity = [IntegratedSecurity]::SSPI

    <#
        Represents the port that the Service Bus for Windows Server uses for TCP. The default is 9354.
    #>
    [DscProperty()]
    [ValidateRange(1024,65535)]
    [int32]
    $TcpPort = 9354

    <#
        Sets the resource provider credentials for the tenant portal. The resource provider is a component that
        exposes the management API to the portal. There are two Service Bus management portals; the Admin portal
        (which provides a set of resource provider APIs for farm administration), and the Tenant portal (which is the
        Windows Azure Management Portal). Use these credentials when you manually install the server farm and connect
        to the tenant portal.
    #>
    [DscProperty()]
    [pscredential]
    $TenantApiCredentials

    <#
        The type of the farm.
    #>
    [DscProperty(NotConfigurable)]
    [string]
    $FarmType

    <#
        The Cluster Connection Endpoint Port for the service bus farm.
    #>
    [DscProperty(NotConfigurable)]
    [int32]
    $ClusterConnectionEndpointPort

    <#
        The Client Connection Endpoint Port for the service bus farm.
    #>
    [DscProperty(NotConfigurable)]
    [int32]
    $ClientConnectionEndpointPort

    <#
        The Lease Driver Endpoint Port for the service bus farm.
    #>
    [DscProperty(NotConfigurable)]
    [int32]
    $LeaseDriverEndpointPort

    <#
        The resource provider credential user name. The resource provider is a component that exposes the management API
        to the portal. There are two Service Bus management portals; the Admin portal (which provides a set of
        resource provider APIs for farm administration), and the Tenant portal (which is the Windows Azure Management
        Portal).
    #>
    [DscProperty(NotConfigurable)]
    [string]
    $AdminApiUserName

    <#
        The resource provider credential user name for the tenant portal. The resource provider is a component that
        exposes the management API to the portal. There are two Service Bus management portals; the Admin portal
        (which provides a set of resource provider APIs for farm administration), and the Tenant portal (which is the
        Windows Azure Management Portal).
    #>
    [DscProperty(NotConfigurable)]
    [string]
    $TenantApiUserName

    <#
        Not sure what this is, it's generally blank.
    #>
    # [DscProperty(NotConfigurable)]
    # [System.Collections.Generic.Dictionary[string,uri]]
    # $BrokerExternalUrls

    <#
        This is the connection string for the farm management database.
    #>
    [DscProperty(NotConfigurable)]
    [string]
    $SBFarmDBConnectionString

    <#
        Represents a connection string of the gateway database.
    #>
    [DscProperty(NotConfigurable)]
    [string]
    $GatewayDBConnectionString

    <#
        Represents a connection string of the message container.
    #>
    [DscProperty(NotConfigurable)]
    [string]
    $MessageContainerDBConnectionString

    <#
        This method is equivalent of the Set-TargetResource script function.
        It sets the resource to the desired state.
    #>
    [void] Set() {
        if ($null -eq $this.Get()) {
            $this.NewSBFarm()
        } else {
            $this.SetSBFarm()
        }
    }

    [void] NewSBFarm() {
        Write-Verbose -Message "Getting configurable properties as hashtable for New-SBFarm params"
        $newSBFarmParams = $this.GetDscConfigurablePropertiesAsHashtable()

        Write-Verbose -Message "Checking for CertificateAutoGenerationKey"
        if ($null -eq $this.CertificateAutoGenerationKey) {
            Write-Verbose -Message "CertificateAutoGenerationKey is absent, removing from New-SBFarm params"
            $newSBFarmParams.Remove("CertificateAutoGenerationKey")
        } else {
            Write-Verbose -Message "CertificateAutoGenerationKey is present, swapping pscredential for securestring"
            $newSBFarmParams.Remove("CertificateAutoGenerationKey")
            $newSBFarmParams.CertificateAutoGenerationKey = $this.CertificateAutoGenerationKey.Password
        }

        Write-Verbose -Message "Creating params for GatewayDBConnectionString"
        $gatewayConnectionStringParams = @{
            DataSource         = $this.GatewayDBConnectionStringDataSource
            InitialCatalog     = $this.GatewayDBConnectionStringInitialCatalog
            IntegratedSecurity = $this.GatewayDBConnectionStringIntegratedSecurity.ToString()
            Credential         = $this.GatewayDBConnectionStringCredential
            Encrypt            = $this.GatewayDBConnectionStringEncrypt
        }
        if ($null -eq $this.GatewayDBConnectionStringDataSource -or
            [string]::IsNullOrEmpty($this.GatewayDBConnectionStringDataSource)) {
            Write-Verbose -Message ("GatewayDBConnectionStringDataSource not specified, " +
                                    "using SBFarmDBConnectionStringDataSource")
            $gatewayConnectionStringParams.DataSource = $this.SBFarmDBConnectionStringDataSource
        }
        if ($null -eq $this.GatewayDBConnectionStringCredential) {
            Write-Verbose -Message ("GatewayDBConnectionStringCredential not specified, " +
                                    "using SBFarmDBConnectionStringCredential")
            $gatewayConnectionStringParams.Credential = $this.SBFarmDBConnectionStringCredential
        }
        Write-Verbose -Message "Creating GatewayDBConnectionString"
        $gatewayDBCxnString = New-SqlConnectionString @gatewayConnectionStringParams
        Write-Verbose -Message "Setting GatewayDBConnectionString in New-SBFarm params"
        $newSBFarmParams.GatewayDBConnectionString = $gatewayDBCxnString

        Write-Verbose -Message "Creating params for MessageContainerDBConnectionString"
        $messageContainerConnectionStringParams = @{
            DataSource         = $this.MessageContainerDBConnectionStringDataSource
            InitialCatalog     = $this.MessageContainerDBConnectionStringInitialCatalog
            IntegratedSecurity = $this.MessageContainerDBConnectionStringIntegratedSecurity.ToString()
            Credential         = $this.MessageContainerDBConnectionStringCredential
            Encrypt            = $this.MessageContainerDBConnectionStringEncrypt
        }
        if ($null -eq $this.MessageContainerDBConnectionStringDataSource -or
            [string]::IsNullOrEmpty($this.MessageContainerDBConnectionStringDataSource)) {
            Write-Verbose -Message ("MessageContainerDBConnectionStringDataSource not specified, " +
                                    "using SBFarmDBConnectionStringDataSource")
            $messageContainerConnectionStringParams.DataSource = $this.SBFarmDBConnectionStringDataSource
        }
        if ($null -eq $this.MessageContainerDBConnectionStringCredential) {
            Write-Verbose -Message ("MessageContainerDBConnectionStringCredential not specified, " +
                                    "using SBFarmDBConnectionStringCredential")
            $messageContainerConnectionStringParams.Credential = $this.SBFarmDBConnectionStringCredential
        }
        Write-Verbose -Message "Creating MessageContainerDBConnectionString"
        $messageContainerDBCxnString = New-SqlConnectionString @messageContainerConnectionStringParams
        Write-Verbose -Message "Setting MessageContainerDBConnectionString in New-SBFarm params"
        $newSBFarmParams.MessageContainerDBConnectionString = $messageContainerDBCxnString

        Write-Verbose -Message "Creating params for SBFarmDBConnectionString"
        $sbFarmConnectionStringParams = @{
            DataSource         = $this.SBFarmDBConnectionStringDataSource
            InitialCatalog     = $this.SBFarmDBConnectionStringInitialCatalog
            IntegratedSecurity = $this.SBFarmDBConnectionStringIntegratedSecurity.ToString()
            Credential         = $this.SBFarmDBConnectionStringCredential
            Encrypt            = $this.SBFarmDBConnectionStringEncrypt
        }
        Write-Verbose -Message "Creating SBFarmDBConnectionString"
        $sbFarmDBCxnString = New-SqlConnectionString @sbFarmConnectionStringParams
        Write-Verbose -Message "Setting SBFarmDBConnectionString in New-SBFarm params"
        $newSBFarmParams.SBFarmDBConnectionString = $sbFarmDBCxnString

        Write-Verbose -Message "Removing components of DB connection strings from New-SBFarm params"
        $newSBFarmParams.Remove("GatewayDBConnectionStringDataSource")
        $newSBFarmParams.Remove("GatewayDBConnectionStringInitialCatalog")
        $newSBFarmParams.Remove("GatewayDBConnectionStringIntegratedSecurity")
        $newSBFarmParams.Remove("GatewayDBConnectionStringCredential")
        $newSBFarmParams.Remove("GatewayDBConnectionStringEncrypt")
        $newSBFarmParams.Remove("MessageContainerDBConnectionStringDataSource")
        $newSBFarmParams.Remove("MessageContainerDBConnectionStringInitialCatalog")
        $newSBFarmParams.Remove("MessageContainerDBConnectionStringIntegratedSecurity")
        $newSBFarmParams.Remove("MessageContainerDBConnectionStringCredential")
        $newSBFarmParams.Remove("MessageContainerDBConnectionStringEncrypt")
        $newSBFarmParams.Remove("SBFarmDBConnectionStringDataSource")
        $newSBFarmParams.Remove("SBFarmDBConnectionStringInitialCatalog")
        $newSBFarmParams.Remove("SBFarmDBConnectionStringIntegratedSecurity")
        $newSBFarmParams.Remove("SBFarmDBConnectionStringCredential")
        $newSBFarmParams.Remove("SBFarmDBConnectionStringEncrypt")

        Write-Verbose -Message "Invoking New-SBFarm with configurable params"
        New-SBFarm @newSBFarmParams
    }

    [void] SetSBFarm() {
        Write-Warning -Message ("The current Service Bus Farm exists, however settings have changed. The " +
                                "cSBFarmSettings resource can only set certain settings once a farm has been " +
                                "provisioned.")
        $setSBFarmParams = $this.GetDscConfigurablePropertiesAsHashtable()

        Write-Verbose -Message "Creating params for SBFarmDBConnectionString"
        $sbFarmConnectionStringParams = @{
            DataSource         = $this.SBFarmDBConnectionStringDataSource
            InitialCatalog     = $this.SBFarmDBConnectionStringInitialCatalog
            IntegratedSecurity = $this.SBFarmDBConnectionStringIntegratedSecurity.ToString()
            Credential         = $this.SBFarmDBConnectionStringCredential
            Encrypt            = $this.SBFarmDBConnectionStringEncrypt
        }
        Write-Verbose -Message "Creating SBFarmDBConnectionString"
        $sbFarmDBCxnString = New-SqlConnectionString @sbFarmConnectionStringParams
        Write-Verbose -Message "Setting SBFarmDBConnectionString in Set-SBFarm params"
        $setSBFarmParams.Add('SBFarmDBConnectionString', $sbFarmDBCxnString)

        Write-Verbose -Message "Removing unnecessary parameters from Set-SBFarm params"
        $setSBFarmParams.Remove("AmqpPort")
        $setSBFarmParams.Remove("AmqpsPort")
        $setSBFarmParams.Remove("CertificateAutoGenerationKey")
        $setSBFarmParams.Remove("EncryptionCertificateThumbprint")
        $setSBFarmParams.Remove("FarmCertificateThumbprint")
        $setSBFarmParams.Remove("GatewayDBConnectionStringDataSource")
        $setSBFarmParams.Remove("GatewayDBConnectionStringInitialCatalog")
        $setSBFarmParams.Remove("GatewayDBConnectionStringIntegratedSecurity")
        $setSBFarmParams.Remove("GatewayDBConnectionStringCredential")
        $setSBFarmParams.Remove("GatewayDBConnectionStringEncrypt")
        $setSBFarmParams.Remove("HttpsPort")
        $setSBFarmParams.Remove("InternalPortRangeStart")
        $setSBFarmParams.Remove("MessageBrokerPort")
        $setSBFarmParams.Remove("MessageContainerDBConnectionStringDataSource")
        $setSBFarmParams.Remove("MessageContainerDBConnectionStringInitialCatalog")
        $setSBFarmParams.Remove("MessageContainerDBConnectionStringIntegratedSecurity")
        $setSBFarmParams.Remove("MessageContainerDBConnectionStringCredential")
        $setSBFarmParams.Remove("MessageContainerDBConnectionStringEncrypt")
        $setSBFarmParams.Remove("RPHttpsPort")
        $setSBFarmParams.Remove("SBFarmDBConnectionStringDataSource")
        $setSBFarmParams.Remove("SBFarmDBConnectionStringInitialCatalog")
        $setSBFarmParams.Remove("SBFarmDBConnectionStringIntegratedSecurity")
        $setSBFarmParams.Remove("SBFarmDBConnectionStringCredential")
        $setSBFarmParams.Remove("SBFarmDBConnectionStringEncrypt")
        $setSBFarmParams.Remove("TcpPort")

        Set-SBFarm @setSBFarmParams
    }

    <#
        This method is equivalent of the Set-TargetResource script function.
        It sets the resource to the desired state.
    #>
    [bool] Test() {
        $CurrentValues = $this.Get()

        if ($null -eq $CurrentValues) {
            return $false
        }

        $desiredValues = $this.ToHashtable()
        $desiredValues.AdminApiUserName = $desiredValues.AdminApiCredentials.UserName
        $desiredValues.TenantApiUserName = $desiredValues.TenantApiCredentials.UserName

        $params = @{
            CurrentValues = $CurrentValues.ToHashtable()
            DesiredValues = $desiredValues
            ValuesToCheck = @(
                "AdminApiUserName"
                "AdminGroup",
                "FarmDNS",
                "RunAsAccount",
                "SBFarmDBConnectionStringDataSource",
                "SBFarmDBConnectionStringInitialCatalog",
                "TenantApiUserName"
            )
        }
        return Test-cServiceBusForWindowsServerSpecificParameters @params
    }

    <#
        This method is equivalent of the Get-TargetResource script function.
        The implementation should use the keys to find appropriate resources.
        This method returns an instance of this class with the updated key
        properties.
    #>
    [cSBFarmCreation] Get() {
        $result = [cSBFarmCreation]::new()

        Write-Verbose -Message "Checking for SBFarm."

        $connectionStringParams = @{
            DataSource         = $this.SBFarmDBConnectionStringDataSource
            InitialCatalog     = $this.SBFarmDBConnectionStringInitialCatalog
            IntegratedSecurity = $this.SBFarmDBConnectionStringIntegratedSecurity.ToString()
            Credential         = $this.SBFarmDBConnectionStringCredential
            Encrypt            = $this.SBFarmDBConnectionStringEncrypt
        }
        Write-Verbose -Message "Building connection string."
        $connectionString = New-SqlConnectionString @connectionStringParams
        Write-Verbose -Message "Trying to get SBFarm."
        $sbFarm = $null
        try {
            $sbFarm = Get-SBFarm -SBFarmDBConnectionString $connectionString
            Write-Verbose -Message "Successfully retrieved SBFarm."
        } catch {
            Write-Verbose -Message "Unable to detect SBFarm."
        }

        if ($null -eq $sbFarm) {
            Write-Verbose -Message "Unable to detect SBFarm."
            return $null
        }

        Write-Verbose -Message "Trying to get default SBMessageContainer."
        $sbMessageContainer = $null
        try {
            $sbMessageContainer = Get-SBMessageContainer -Id 1
            Write-Verbose -Message "Successfully retrieved default SBMessageContainer."
        } catch {
            Write-Verbose -Message "Unable to detect initial SBMessageContainer."
        }

        $result.AdminApiCredentials = $this.AdminApiCredentials
        $result.AdminApiUserName = $sbFarm.AdminApiUserName
        $result.AdminGroup = $sbFarm.AdminGroup
        $result.AmqpPort = $sbFarm.AmqpPort
        $result.AmqpsPort = $sbFarm.AmqpsPort
        #$result.BrokerExternalUrls = $sbFarm.BrokerExternalUrls
        $result.CertificateAutoGenerationKey = $this.CertificateAutoGenerationKey
        $result.ClientConnectionEndpointPort = $sbFarm.ClientConnectionEndpointPort
        $result.ClusterConnectionEndpointPort = $sbFarm.ClusterConnectionEndpointPort
        $result.EncryptionCertificateThumbprint = $sbFarm.EncryptionCertificate.Thumbprint
        $result.FarmCertificateThumbprint = $sbFarm.FarmCertificate.Thumbprint
        $result.FarmDNS = $sbFarm.FarmDNS
        $result.FarmType = $sbFarm.FarmType
        $result.GatewayDBConnectionString = $sbFarm.GatewayDBConnectionString
        $result.GatewayDBConnectionStringCredential = $this.GatewayDBConnectionStringCredential
        $params = @{
            SqlConnectionString = $sbFarm.GatewayDBConnectionString
        }
        $params.PropertyName = "Data Source"
        $result.GatewayDBConnectionStringDataSource = [System.String](Get-SqlConnectionStringPropertyValue @params)
        $params.PropertyName = "Encrypt"
        $result.GatewayDBConnectionStringEncrypt = [System.Boolean](Get-SqlConnectionStringPropertyValue @params)
        $params.PropertyName = "Initial Catalog"
        $result.GatewayDBConnectionStringInitialCatalog = [System.String](Get-SqlConnectionStringPropertyValue @params)
        $params.PropertyName = "Integrated Security"
        $result.GatewayDBConnectionStringIntegratedSecurity = [System.String](Get-SqlConnectionStringPropertyValue @params)
        $result.HttpsPort = $sbFarm.HttpsPort
        $result.InternalPortRangeStart = $sbFarm.ClusterConnectionEndpointPort
        $result.LeaseDriverEndpointPort = $sbFarm.LeaseDriverEndpointPort
        $result.MessageBrokerPort = $sbFarm.MessageBrokerPort
        $result.MessageContainerDBConnectionStringCredential = $this.MessageContainerDatabaseCredential
        if ($null -ne $sbMessageContainer) {
            $params = @{
                SqlConnectionString = $sbMessageContainer.ConnectionString
            }
            $params.PropertyName = "Data Source"
            $result.MessageContainerDBConnectionStringDataSource = [System.String](Get-SqlConnectionStringPropertyValue @params)
            $params.PropertyName = "Encrypt"
            $result.MessageContainerDBConnectionStringEncrypt = [System.Boolean](Get-SqlConnectionStringPropertyValue @params)
            $params.PropertyName = "Initial Catalog"
            $result.MessageContainerDBConnectionStringInitialCatalog = [System.String](Get-SqlConnectionStringPropertyValue @params)
            $params.PropertyName = "Integrated Security"
            $result.MessageContainerDBConnectionStringIntegratedSecurity = [System.String](Get-SqlConnectionStringPropertyValue @params)
            $result.MessageContainerDBConnectionString = $sbMessageContainer.ConnectionString
        }
        $result.RPHttpsPort = $sbFarm.RPHttpsPort
        $result.RunAsAccount = $sbFarm.RunAsAccount
        $result.SBFarmDBConnectionString = $sbFarm.SBFarmDBConnectionString
        $result.SBFarmDBConnectionStringCredential = $this.SBFarmDBConnectionStringCredential
        $params = @{
            SqlConnectionString = $sbFarm.SBFarmDBConnectionString
        }
        $params.PropertyName = "Data Source"
        $result.SBFarmDBConnectionStringDataSource = [System.String](Get-SqlConnectionStringPropertyValue @params)
        $params.PropertyName = "Encrypt"
        $result.SBFarmDBConnectionStringEncrypt = [System.Boolean](Get-SqlConnectionStringPropertyValue @params)
        $params.PropertyName = "Initial Catalog"
        $result.SBFarmDBConnectionStringInitialCatalog = [System.String](Get-SqlConnectionStringPropertyValue @params)
        $params.PropertyName = "Integrated Security"
        $result.SBFarmDBConnectionStringIntegratedSecurity = [System.String](Get-SqlConnectionStringPropertyValue @params)
        $result.TcpPort = $sbFarm.TcpPort
        $result.TenantApiCredentials = $this.TenantApiCredentials
        $result.TenantApiUserName = $sbFarm.TenantApiUserName

        return $result
    }
}


<#
   This resource manages the settings for a Service Bus for Windows Server farm.

   The only reason to use this resource would be to change certain farm settings away from that which was set up
   initially with the cSBFarmCreation resource.

   When you change settings you should ***also change them on SBFarmCreationResource, e
#>
# class cSBFarmSettings : cSBBase {

#     <#
#         Sets the resource provider credentials. The resource provider is a component that exposes the management API
#         to the portal. There are two Service Bus management portals; the Admin portal (which provides a set of
#         resource provider APIs for farm administration), and the Tenant portal (which is the Windows Azure Management
#         Portal). Use these credentials when you manually install the server farm and connect to the Admin portal.
#     #>
#     [DscProperty()]
#     [pscredential]
#     $AdminApiCredentials

#     <#
#         Respresents the admin group. If not specified the default value will be BUILTIN\Administrators.
#     #>
#     [DscProperty()]
#     [string]
#     $AdminGroup

#     <#
#         The DNS prefix that is mapped to all server farm nodes. This cmdlet is used when an administrator registers a
#         server farm. The server farm node value is returned when you call the Get-SBClientConfiguration cmdlet to
#         request a connection string.
#     #>
#     [DscProperty()]
#     [string]
#     $FarmDNS

#     <#
#         Represents the account under which the service runs. This account must be a domain account.
#     #>
#     [DscProperty(Mandatory)]
#     [string]
#     $RunAsAccount

#     [void] Set() {
#         # else, ensure all set-able settings are correct
#         Write-Warning -Message ("The current Service Bus Farm exists, however settings have changed. The " +
#                                 "cSBFarmSettings resource can only set certain settings once a farm has been " +
#                                 "provisioned.")
#         $setSBFarmParams = @{}
#         $serviceRestartNeeded = $false

#         if ($null -ne $this.AdminApiCredentials) {
#             $setSBFarmParams.Add('AdminApiCredentials', $this.AdminApiCredentials)
#         }
#         if ($null -ne $this.AdminGroup) {
#             $setSBFarmParams.Add('AdminGroup', $this.AdminGroup)
#         }
#         if ($null -ne $this.FarmDNS) {
#             $setSBFarmParams.Add('FarmDNS', $this.FarmDNS)
#         }
#         if ($null -ne $this.RunAsAccount) {
#             $setSBFarmParams.Add('RunAsAccount', $this.RunAsAccount)
#         }
#         if ($null -ne $this.SBFarmDBConnectionString) {
#             $setSBFarmParams.Add('SBFarmDBConnectionString', $this.SBFarmDBConnectionString)
#             $serviceRestartNeeded = $true
#         }
#         if ($null -ne $this.TenantApiCredentials) {
#             $setSBFarmParams.Add('TenantApiCredentials', $this.SBFarmDBConnectionString)
#         }

#         $hostsExistInFarm = $false
#         try {
#             $sbFarmStatus = Get-SBFarmStatus
#             $hostsExistInFarm = $true
#         } catch [System.InvalidOperationException] {
#             # no hosts in farm
#         }

#         if ($serviceRestartNeeded -and $hostsExistInFarm) {
#             Stop-SBFarm
#         }

#         Set-SBFarm @setSBFarmParams

#         if ($serviceRestartNeeded -and $hostsExistInFarm) {
#             Start-SBFarm
#         }
#     }
#     [bool] Test() {
#         return $true
#     }

#     [cSBFarmSettings] Get() {
#         return $this
#     }
# }


# class cSBMessageContainer {
#     <#
#         The database server used for the message container database. This is used in the GatewayDBConnectionString
#         when creating the farm. This can optionally used named instance and port info if those are being used. The
#         default value for this will be the same as that specified for farm management database server.
#     #>
#     [DscProperty()]
#     [string]
#     $MessageContainerDBConnectionStringDataSource

#     <#
#         Represents whether the database server housing the message container database will use SSL or not. The
#         default value for this will be the same as that specified for farm management database server.
#     #>
#     [DscProperty()]
#     [bool]
#     $MessageContainerDBConnectionStringEncrypt = $false

#     <#
#         Represents whether authentication to the message container database will use integrated Windows
#         authentication or SSPI (Security Support Provider Interface) which supports Kerberos or regular SQL
#         authentication. The default value for this will be the same as that specified for farm management database
#         security.
#     #>
#     [DscProperty()]
#     [ValidateSet('True','False','SSPI')]
#     [string]
#     $MessageContainerDBConnectionStringIntegratedSecurity = 'False'

#     <#
#         The credential for connecting to the message container database. Not required if integrated authentication
#         will be used. The default value for this will be the same as that specified for farm management database
#         credentials.
#     #>
#     [DscProperty()]
#     [pscredential]
#     $MessageContainerDBConnectionStringCredential

#     <#
#         The name of the initial message container database.
#     #>
#     [DscProperty()]
#     [string]
#     $MessageContainerDBConnectionStringInitialCatalog

#     [void] Set() {

#     }
#     [bool] Test() {
#         return $true
#     }

#     [cSBFarmSettings] Get() {
#         return $this
#     }
# }
