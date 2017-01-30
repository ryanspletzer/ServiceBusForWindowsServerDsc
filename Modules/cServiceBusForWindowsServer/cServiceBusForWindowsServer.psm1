enum Ensure {
    Absent
    Present
}


enum IntegratedSecurity {
    True
    False
    SSPI
}


enum AddressingScheme {
    Cloud
    DNSRegistered
    Path
    PathWithServiceId
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
    [object] GetProperty([object]$name) {
        $type = $this.GetType()
        $propertyInfo = $type.GetProperty($name)
        return $propertyInfo.GetValue($this)
    }

    <#
        Allows for setting properties on the class object by name.
    #>
    [void] SetProperty([object]$name, [object]$value) {
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
                    ($_.AttributeType.Name -eq "DscPropertyAttribute") -and ($null -ne $_.NamedArguments)
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
   This resource creates and sets certain settings for a Service Bus for Windows Server farm.
#>
[DscResource()]
class cSBFarm : cSBBase {

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
    $AdminGroup = 'BUILTIN\Administrators'

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
        or SSPI (Security Support Provider Interface) which supports Kerberos, Windows or basic SQL authentication.
        (i.e. it will fall back to first available auth method from Kerberos -> Windows -> SQL Auth). The default
        value is SSPI.
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
        Hosts in the farm.
    #>
    # [DscProperty(NotConfigurable)]
    # [pscustomobject[]]
    # $Hosts

    <#
        This method is equivalent of the Get-TargetResource script function.
        The implementation should use the keys to find appropriate resources.
        This method returns an instance of this class with the updated key
        properties.
    #>
    [cSBFarm] Get() {
        $result = [cSBFarm]::new()

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
        $result.GatewayDBConnectionStringDataSource = [string](Get-SqlConnectionStringPropertyValue @params)
        $params.PropertyName = "Encrypt"
        $result.GatewayDBConnectionStringEncrypt = [bool](Get-SqlConnectionStringPropertyValue @params)
        $params.PropertyName = "Initial Catalog"
        $result.GatewayDBConnectionStringInitialCatalog = [string](Get-SqlConnectionStringPropertyValue @params)
        $params.PropertyName = "Integrated Security"
        $result.GatewayDBConnectionStringIntegratedSecurity = [string](Get-SqlConnectionStringPropertyValue @params)
        # $result.Hosts = $sbFarm.Hosts | ForEach-Object {
        #     [pscustomobject] @{
        #         Name               = $_.Name
        #         ConfigurationState = $_.ConfigurationState
        #     }
        # }

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
            $result.MessageContainerDBConnectionStringDataSource = [string](Get-SqlConnectionStringPropertyValue @params)
            $params.PropertyName = "Encrypt"
            $result.MessageContainerDBConnectionStringEncrypt = [bool](Get-SqlConnectionStringPropertyValue @params)
            $params.PropertyName = "Initial Catalog"
            $result.MessageContainerDBConnectionStringInitialCatalog = [string](Get-SqlConnectionStringPropertyValue @params)
            $params.PropertyName = "Integrated Security"
            $result.MessageContainerDBConnectionStringIntegratedSecurity = [string](Get-SqlConnectionStringPropertyValue @params)
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
        $result.SBFarmDBConnectionStringDataSource = [string](Get-SqlConnectionStringPropertyValue @params)
        $params.PropertyName = "Encrypt"
        $result.SBFarmDBConnectionStringEncrypt = [bool](Get-SqlConnectionStringPropertyValue @params)
        $params.PropertyName = "Initial Catalog"
        $result.SBFarmDBConnectionStringInitialCatalog = [string](Get-SqlConnectionStringPropertyValue @params)
        $params.PropertyName = "Integrated Security"
        $result.SBFarmDBConnectionStringIntegratedSecurity = [string](Get-SqlConnectionStringPropertyValue @params)

        $result.TcpPort = $sbFarm.TcpPort
        $result.TenantApiCredentials = $this.TenantApiCredentials
        $result.TenantApiUserName = $sbFarm.TenantApiUserName

        return $result
    }

    <#
        This method is equivalent of the Test-TargetResource script function.
        It should return True or False, showing whether the resource
        is in a desired state.
    #>
    [bool] Test() {
        $currentValues = $this.Get()

        if ($null -eq $currentValues) {
            return $false
        }

        $currentValuesHt = $currentValues.ToHashtable()

        $desiredValuesHt = $this.ToHashtable()
        $desiredValuesHt.AdminApiUserName = $desiredValuesHt.AdminApiCredentials.UserName
        $desiredValuesHt.TenantApiUserName = $desiredValuesHt.TenantApiCredentials.UserName

        $params = @{
            CurrentValues = $currentValuesHt
            DesiredValues = $desiredValuesHt
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
        return Test-cSBWSParameterState @params
    }

    <#
        This method is equivalent of the Set-TargetResource script function.
        It sets the resource to the desired state.
    #>
    [void] Set() {
        Write-Verbose -Message "Checking whether to make new SBFarm or set existing SBFarm"
        if ($null -eq $this.Get()) {
            Write-Verbose -Message "No farm detected, new SBFarm will be created"
            $this.NewSBFarm()
        } else {
            Write-Verbose -Message "Farm detected, settable SBFarm settings will be set"
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
        $gatewayDBConnectionStringParams = @{
            DataSource         = $this.GatewayDBConnectionStringDataSource
            InitialCatalog     = $this.GatewayDBConnectionStringInitialCatalog
            IntegratedSecurity = $this.GatewayDBConnectionStringIntegratedSecurity.ToString()
            Credential         = $this.GatewayDBConnectionStringCredential
            Encrypt            = $this.GatewayDBConnectionStringEncrypt
        }
        if ($null -eq $this.GatewayDBConnectionStringDataSource -or
            [String]::IsNullOrEmpty($this.GatewayDBConnectionStringDataSource)) {
            Write-Verbose -Message ("GatewayDBConnectionStringDataSource not specified, " +
                                    "using SBFarmDBConnectionStringDataSource")
            $gatewayDBConnectionStringParams.DataSource = $this.SBFarmDBConnectionStringDataSource
        }
        if ($null -eq $this.GatewayDBConnectionStringCredential) {
            Write-Verbose -Message ("GatewayDBConnectionStringCredential not specified, " +
                                    "using SBFarmDBConnectionStringCredential")
            $gatewayDBConnectionStringParams.Credential = $this.SBFarmDBConnectionStringCredential
        }
        Write-Verbose -Message "Creating GatewayDBConnectionString"
        $gatewayDBCxnString = New-SqlConnectionString @gatewayDBConnectionStringParams
        Write-Verbose -Message "Setting GatewayDBConnectionString in New-SBFarm params"
        $newSBFarmParams.GatewayDBConnectionString = $gatewayDBCxnString

        Write-Verbose -Message "Creating params for MessageContainerDBConnectionString"
        $messageContainerDBConnectionStringParams = @{
            DataSource         = $this.MessageContainerDBConnectionStringDataSource
            InitialCatalog     = $this.MessageContainerDBConnectionStringInitialCatalog
            IntegratedSecurity = $this.MessageContainerDBConnectionStringIntegratedSecurity.ToString()
            Credential         = $this.MessageContainerDBConnectionStringCredential
            Encrypt            = $this.MessageContainerDBConnectionStringEncrypt
        }
        if ($null -eq $this.MessageContainerDBConnectionStringDataSource -or
            [String]::IsNullOrEmpty($this.MessageContainerDBConnectionStringDataSource)) {
            Write-Verbose -Message ("MessageContainerDBConnectionStringDataSource not specified, " +
                                    "using SBFarmDBConnectionStringDataSource")
            $messageContainerDBConnectionStringParams.DataSource = $this.SBFarmDBConnectionStringDataSource
        }
        if ($null -eq $this.MessageContainerDBConnectionStringCredential) {
            Write-Verbose -Message ("MessageContainerDBConnectionStringCredential not specified, " +
                                    "using SBFarmDBConnectionStringCredential")
            $messageContainerDBConnectionStringParams.Credential = $this.SBFarmDBConnectionStringCredential
        }
        Write-Verbose -Message "Creating MessageContainerDBConnectionString"
        $messageContainerDBCxnString = New-SqlConnectionString @messageContainerDBConnectionStringParams
        Write-Verbose -Message "Setting MessageContainerDBConnectionString in New-SBFarm params"
        $newSBFarmParams.MessageContainerDBConnectionString = $messageContainerDBCxnString

        Write-Verbose -Message "Creating params for SBFarmDBConnectionString"
        $sbFarmDBConnectionStringParams = @{
            DataSource         = $this.SBFarmDBConnectionStringDataSource
            InitialCatalog     = $this.SBFarmDBConnectionStringInitialCatalog
            IntegratedSecurity = $this.SBFarmDBConnectionStringIntegratedSecurity.ToString()
            Credential         = $this.SBFarmDBConnectionStringCredential
            Encrypt            = $this.SBFarmDBConnectionStringEncrypt
        }
        Write-Verbose -Message "Creating SBFarmDBConnectionString"
        $sbFarmDBCxnString = New-SqlConnectionString @sbFarmDBConnectionStringParams
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
        # TODO: If certain settings are being changed / Set, do a Stop-SBFarm / Start-SBFarm - ???
        Write-Verbose -Message ("The current Service Bus Farm exists, however settings have changed. The " +
                                "cSBFarm resource only able to detect/set certain changess once a farm has been " +
                                "provisioned, including: AdminApiCredentials.UserName, AdminGroup, FarmDNS, " +
                                "RunAsAccount, TenantApiCredentials.UserName")
        Write-Verbose -Message "Getting configurable properties as hashtable for Set-SBFarm params"
        $setSBFarmParams = $this.GetDscConfigurablePropertiesAsHashtable()

        Write-Verbose -Message "Creating params for SBFarmDBConnectionString"
        $sbFarmDBConnectionStringParams = @{
            DataSource         = $this.SBFarmDBConnectionStringDataSource
            InitialCatalog     = $this.SBFarmDBConnectionStringInitialCatalog
            IntegratedSecurity = $this.SBFarmDBConnectionStringIntegratedSecurity.ToString()
            Credential         = $this.SBFarmDBConnectionStringCredential
            Encrypt            = $this.SBFarmDBConnectionStringEncrypt
        }
        Write-Verbose -Message "Creating SBFarmDBConnectionString"
        $sbFarmDBCxnString = New-SqlConnectionString @sbFarmDBConnectionStringParams
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

        Write-Verbose -Message ("Invoking Stop-SBFarm prior to calling Set-SBFarm. " +
                                "cSBHost resource should re-start hosts individually.")
        Stop-SBFarm

        Write-Verbose -Message "Invoking Set-SBFarm with configurable params"
        Set-SBFarm @setSBFarmParams
    }
}


<#
   This resource adds, removes, starts, stops and updates settings for Service Bus for a Windows Server host.
#>
[DscResource()]
class cSBHost : cSBBase {

    <#
        This passphrase is required for certificate auto generation. This parameter is mandatory if you want
        certificates to be auto generated.
    #>
    [DscProperty()]
    [pscredential]
    $CertificateAutoGenerationKey

    <#
        Enables or disables your firewall rules.
    #>
    [DscProperty(Mandatory)]
    [bool]
    $EnableFirewallRules

    <#
        Represents the port that the Service Bus for Windows Server uses for ExternalBroker communication.
    #>
    [DscProperty()]
    [int32]
    $ExternalBrokerPort

    <#
        Specifies a case-sensitive ExternalBroker URI.
    #>
    [DscProperty()]
    [string]
    $ExternalBrokerUrl

    <#
        Specifies the password for the user account under which services are running on the farm.

        If all the machines in a farm share the same service account and the security policy requires the service
        account password to be changed at regular intervals, you must perform specific actions on each machine in
        the farm to be able to continue adding and removing nodes in the farm. See the section titled
        "Managing Farm Password Changes Using Cmdlets" for this procedure.

        https://msdn.microsoft.com/en-us/library/dn441427.aspx
    #>
    [DscProperty(Mandatory)]
    [pscredential]
    $RunAsPassword

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
        or SSPI (Security Support Provider Interface) which supports Kerberos, Windows or basic SQL authentication.
        (i.e. it will fall back to first available auth method from Kerberos -> Windows -> SQL Auth). The default
        value is SSPI.
    #>
    [DscProperty()]
    [IntegratedSecurity]
    $SBFarmDBConnectionStringIntegratedSecurity = [IntegratedSecurity]::SSPI

    <#
        Indicates whether host should be started or stopped. Default is true / started.
    #>
    [DscProperty()]
    [bool]
    $Started = $true

    <#
        Marks whether the host should be present or absent.
    #>
    [DscProperty(Key)]
    [Ensure]
    $Ensure

    <#
        This method is equivalent of the Get-TargetResource script function.
        The implementation should use the keys to find appropriate resources.
        This method returns an instance of this class with the updated key
        properties.
    #>
    [cSBHost] Get() {
        $result = [cSBHost]::new()

        Write-Verbose -Message "Checking for SBHost."

        # TODO: fix for non-domain joined machine
        $hostName = "$env:COMPUTERNAME.$((Get-CimInstance -ClassName WIN32_ComputerSystem).Domain)"

        $connectionStringParams = @{
            DataSource         = $this.SBFarmDBConnectionStringDataSource
            InitialCatalog     = $this.SBFarmDBConnectionStringInitialCatalog
            IntegratedSecurity = $this.SBFarmDBConnectionStringIntegratedSecurity.ToString()
            Credential         = $this.SBFarmDBConnectionStringCredential
            Encrypt            = $this.SBFarmDBConnectionStringEncrypt
        }
        Write-Verbose -Message "Building connection string."
        $connectionString = New-SqlConnectionString @connectionStringParams
        Write-Verbose -Message "Trying to get SBFarm to check hosts list."
        $sbFarm = $null
        try {
            $sbFarm = Get-SBFarm -SBFarmDBConnectionString $connectionString
            Write-Verbose -Message "Successfully retrieved SBFarm."
        } catch {
            Write-Verbose -Message "Unable to detect SBFarm."
        }

        if ($null -eq $sbFarm) {
            return $null
        }

        Write-Verbose -Message ("Checking SBFarm.Hosts for presence of $hostName")
        $existingHost = $sbFarm.Hosts |
                            Where-Object {
                                $_.Name -eq "$hostName"
                            }

        if ($null -eq $existingHost) {
            Write-Verbose -Message "Host is not present in SBFarm.Hosts."
            $result.Ensure = [Ensure]::Absent
            $result.Started = $false
            return $result
        }

        Write-Verbose -Message "Trying to get SBFarmStatus of current host."
        $sbFarmStatus = $null
        try {
            $sbFarmStatus = Get-SBFarmStatus |
                                Where-Object {
                                    $_.HostName -eq "$hostName"
                                }
            Write-Verbose -Message "Successfully retrieved SBFarmStatus."
        } catch {
            Write-Verbose -Message "Unable to retrieve SBFarmStatus."
        }

        $result.CertificateAutoGenerationKey = $this.CertificateAutoGenerationKey
        $result.EnableFirewallRules = $this.EnableFirewallRules
        $result.Ensure = [Ensure]::Present
        $result.ExternalBrokerPort = $this.ExternalBrokerPort
        $result.ExternalBrokerUrl = $this.ExternalBrokerUrl
        $result.RunAsPassword = $this.RunAsPassword

        $result.SBFarmDBConnectionStringCredential = $this.SBFarmDBConnectionStringCredential
        $params = @{
            SqlConnectionString = $sbFarm.SBFarmDBConnectionString
        }
        $params.PropertyName = "Data Source"
        $result.SBFarmDBConnectionStringDataSource = [string](Get-SqlConnectionStringPropertyValue @params)
        $params.PropertyName = "Encrypt"
        $result.SBFarmDBConnectionStringEncrypt = [bool](Get-SqlConnectionStringPropertyValue @params)
        $params.PropertyName = "Initial Catalog"
        $result.SBFarmDBConnectionStringInitialCatalog = [string](Get-SqlConnectionStringPropertyValue @params)
        $params.PropertyName = "Integrated Security"
        $result.SBFarmDBConnectionStringIntegratedSecurity = [string](Get-SqlConnectionStringPropertyValue @params)

        if ($null -ne $sbFarmStatus) {
            $sbFarmStatus |
                ForEach-Object {
                    if ($_.Status -ne "Running") {
                        $result.Started = $false
                    }
                }
        } else {
            $result.Started = $false
        }

        return $result
    }

    <#
        This method is equivalent of the Test-TargetResource script function.
        It should return True or False, showing whether the resource
        is in a desired state.
    #>
    [bool] Test() {
        $currentValues = $this.Get()

        if ($null -eq $currentValues) {
            return $false
        }

        if ($this.SBHostShouldBeAdded($currentValues)) {
            return $false
        }

        if ($this.SBHostShouldBeRemoved($currentValues)) {
            return $false
        }

        if ($this.SBHostShouldBeStarted($currentValues)) {
            return $false
        }

        if ($this.SBHostShouldBeStopped($currentValues)) {
            return $false
        }

        $params = @{
            CurrentValues = $currentValues.ToHashtable()
            DesiredValues = $this.ToHashtable()
            ValuesToCheck = @(
                "SBFarmDBConnectionStringDataSource"
            )
        }
        return Test-cSBWSParameterState @params
    }

    [bool] SBHostShouldBeAdded([cSBHost]$CurrentValues) {
        return (($this.Ensure -eq [Ensure]::Present) -and ($CurrentValues.Ensure -eq [Ensure]::Absent))
    }

    [bool] SBHostShouldBeRemoved([cSBHost]$CurrentValues) {
        return (($this.Ensure -eq [Ensure]::Absent) -and ($CurrentValues.Ensure -eq [Ensure]::Present))
    }

    [bool] SBHostShouldBeStarted([cSBHost]$CurrentValues) {
        return (($this.Started -eq $true) -and ($CurrentValues.Started -eq $false))
    }

    [bool] SBHostShouldBeStopped([cSBHost]$CurrentValues) {
        return (($this.Started -eq $false) -and ($CurrentValues.Started -eq $true))
    }

    <#
        This method is equivalent of the Set-TargetResource script function.
        It sets the resource to the desired state.
    #>
    [void] Set() {
        Write-Verbose -Message "Retrieving current SBHost values"
        $currentValues = $this.Get()

        Write-Verbose -Message "Checking if SBHost should be added to the farm"
        if ($this.SBHostShouldBeAdded($currentValues)) {
            Write-Verbose -Message "SBHost will be added to the farm"
            $this.AddSBHost()
            Write-Verbose -Message "Checking if SBHost should be started"
            if ($this.Started -eq $true) {
                Write-Verbose -Message "Starting SBHost"
                Start-SBHost
            }
            return
        }

        Write-Verbose -Message "Checking if SBHost should be removed from the farm"
        if ($this.SBHostShouldBeRemoved($currentValues)) {
            Write-Verbose -Message "SBHost will be removed from the farm"
            Write-Verbose -Message "Checking if SBHost should be stopped prior to removing"
            if ($currentValues.Started -eq $true) {
                Write-Verbose -Message "Stopping SBHost"
                Stop-SBHost
            }
            $this.RemoveSBHost()
            Write-Verbose -Message "Ending cSBHost.Set() after removal"
            return
        }

        Write-Verbose -Message "Checking if SBHost should be started"
        if ($this.SBHostShouldBeStarted($currentValues)) {
            Write-Verbose -Message "SBHost will be started"
            Write-Verbose -Message "Updating SBHost prior to starting"
            $this.UpdateSBHost()
            Write-Verbose -Message "Starting SBHost"
            Start-SBHost
            return
        }

        Write-Verbose -Message ("cSBHost can only detect certain changes -- to change certain settings on a host, " +
                                "push a configuration with the host stopped, then push a new config with the host " +
                                "started and it will explicitly re-update the settings.")
        Write-Verbose -Message "Checking if SBHost should be stopped"
        if ($this.SBHostShouldBeStopped($currentValues)) {
            Write-Verbose -Message "Stopping SBHost"
            Stop-SBHost
            return
        }
    }

    [void] AddSBHost() {
        Write-Verbose -Message "Getting configurable properties as hashtable for Add-SBHost params"
        $addSBHostParams = $this.GetDscConfigurablePropertiesAsHashtable()

        Write-Verbose -Message "Checking for CertificateAutoGenerationKey"
        if ($null -eq $this.CertificateAutoGenerationKey) {
            Write-Verbose -Message "CertificateAutoGenerationKey is absent, removing from Add-SBHost params"
            $addSBHostParams.Remove("CertificateAutoGenerationKey")
        } else {
            Write-Verbose -Message "CertificateAutoGenerationKey is present, swapping pscredential for securestring"
            $addSBHostParams.Remove("CertificateAutoGenerationKey")
            $addSBHostParams.CertificateAutoGenerationKey = $this.CertificateAutoGenerationKey.Password
        }

        Write-Verbose -Message "Checking for ExternalBrokerPort"
        if (0 -eq $addSBHostParams.ExternalBrokerPort) {
            Write-Verbose -Message "ExternalBrokerPort is absent, removing from Add-SBHost params"
            $addSBHostParams.Remove("ExternalBrokerPort")
        }
        Write-Verbose -Message "Checking for ExternalBrokerUrl"
        if ($null -eq $addSBHostParams.ExternalBrokerUrl) {
            Write-Verbose -Message "ExternalBrokerUrl is absent, removing from Add-SBHost params"
            $addSBHostParams.Remove("ExternalBrokerUrl")
        }

        Write-Verbose -Message "Swapping RunAsPassword pscredential for securestring"
        $addSBHostParams.Remove("RunAsPassword")
        $addSBHostParams.RunAsPassword = $this.RunAsPassword.Password

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
        Write-Verbose -Message "Setting SBFarmDBConnectionString in Add-SBHost params"
        $addSBHostParams.SBFarmDBConnectionString = $sbFarmDBCxnString

        Write-Verbose -Message "Removing unnecessary parameters from Add-SBHost params"
        $addSBHostParams.Remove("Ensure")
        $addSBHostParams.Remove("SBFarmDBConnectionStringCredential")
        $addSBHostParams.Remove("SBFarmDBConnectionStringDataSource")
        $addSBHostParams.Remove("SBFarmDBConnectionStringInitialCatalog")
        $addSBHostParams.Remove("SBFarmDBConnectionStringIntegratedSecurity")
        $addSBHostParams.Remove("SBFarmDBConnectionStringEncrypt")
        $addSBHostParams.Remove("Started")

        Write-Verbose -Message "Invoking Add-SBHost with configurable params"
        Add-SBHost @addSBHostParams
    }

    [void] RemoveSBHost() {
        Write-Verbose -Message "Getting configurable properties as hashtable for Remove-SBHost params"
        $removeSBHostParams = $this.GetDscConfigurablePropertiesAsHashtable()

        # TODO: fix for non-domain joined machine
        Write-Verbose -Message "Constructing hostname for Remove-SBHost params"
        $removeSBHostParams.HostName = "$env:COMPUTERNAME.$((Get-CimInstance -ClassName WIN32_ComputerSystem).Domain)"

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
        Write-Verbose -Message "Setting SBFarmDBConnectionString in Remove-SBHost params"
        $removeSBHostParams.SBFarmDBConnectionString = $sbFarmDBCxnString

        Write-Verbose -Message "Removing unnecessary parameters from Remove-SBHost params"
        $removeSBHostParams.Remove("CertificateAutoGenerationKey")
        $removeSBHostParams.Remove("Ensure")
        $removeSBHostParams.Remove("EnableFirewallRules")
        $removeSBHostParams.Remove("ExternalBrokerPort")
        $removeSBHostParams.Remove("ExternalBrokerUrl")
        $removeSBHostParams.Remove("RunAsPassword")
        $removeSBHostParams.Remove("SBFarmDBConnectionStringCredential")
        $removeSBHostParams.Remove("SBFarmDBConnectionStringDataSource")
        $removeSBHostParams.Remove("SBFarmDBConnectionStringInitialCatalog")
        $removeSBHostParams.Remove("SBFarmDBConnectionStringIntegratedSecurity")
        $removeSBHostParams.Remove("SBFarmDBConnectionStringEncrypt")
        $removeSBHostParams.Remove("Started")

        Write-Verbose -Message "Invoking Remove-SBHost with configurable params"
        Remove-SBHost @removeSBHostParams
    }

    [void] UpdateSBHost() {
        Write-Verbose -Message "Getting configurable properties as hashtable for Update-SBHost params"
        $updateSBHostParams = $this.GetDscConfigurablePropertiesAsHashtable()

        Write-Verbose -Message "Checking for CertificateAutoGenerationKey"
        if ($null -eq $this.CertificateAutoGenerationKey) {
            Write-Verbose -Message "CertificateAutoGenerationKey is absent, removing from Update-SBHost params"
            $updateSBHostParams.Remove("CertificateAutoGenerationKey")
        } else {
            Write-Verbose -Message "CertificateAutoGenerationKey is present, swapping pscredential for securestring"
            $updateSBHostParams.Remove("CertificateAutoGenerationKey")
            $updateSBHostParams.CertificateAutoGenerationKey = $this.CertificateAutoGenerationKey.Password
        }

        Write-Verbose -Message "Checking for ExternalBrokerPort"
        if (0 -eq $updateSBHostParams.ExternalBrokerPort) {
            Write-Verbose -Message "ExternalBrokerPort is absent, removing from Update-SBHost params"
            $updateSBHostParams.Remove("ExternalBrokerPort")
        }
        Write-Verbose -Message "Checking for ExternalBrokerUrl"
        if ($null -eq $updateSBHostParams.ExternalBrokerUrl) {
            Write-Verbose -Message "ExternalBrokerUrl is absent, removing from Update-SBHost params"
            $updateSBHostParams.Remove("ExternalBrokerUrl")
        }

        Write-Verbose -Message "Swapping RunAsPassword pscredential for securestring"
        $updateSBHostParams.Remove("RunAsPassword")
        $updateSBHostParams.RunAsPassword = $this.RunAsPassword.Password

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
        Write-Verbose -Message "Setting SBFarmDBConnectionString in Update-SBHost params"
        $updateSBHostParams.SBFarmDBConnectionString = $sbFarmDBCxnString

        Write-Verbose -Message "Removing unnecessary parameters from Update-SBHost params"
        $updateSBHostParams.Remove("Ensure")
        $updateSBHostParams.Remove("EnableFirewallRules")
        $updateSBHostParams.Remove("SBFarmDBConnectionStringCredential")
        $updateSBHostParams.Remove("SBFarmDBConnectionStringDataSource")
        $updateSBHostParams.Remove("SBFarmDBConnectionStringInitialCatalog")
        $updateSBHostParams.Remove("SBFarmDBConnectionStringIntegratedSecurity")
        $updateSBHostParams.Remove("SBFarmDBConnectionStringEncrypt")
        $updateSBHostParams.Remove("Started")

        Write-Verbose -Message "Invoking Update-SBHost with configurable params"
        Update-SBHost @updateSBHostParams
    }
}


<#
   This resource adds, removes, updates settings for a Service Bus for Windows Server namespace.
#>
[DscResource()]
class cSBNameSpace : cSBBase {

    <#
        Specifies the addressing scheme used in the service namespace. The possible values for this parameter are
        Path (default value), DNSRegistered, Cloud, and PathWithServiceId.
    #>
    [DscProperty()]
    [AddressingScheme]
    $AddressingScheme = [AddressingScheme]::Path

    <#
        Specifies the DNS Entry.
    #>
    [DscProperty()]
    [string]
    $DNSEntry

    <#
        Specifies the name of the trusted security issuer.
    #>
    [DscProperty()]
    [string]
    $IssuerName

    <#
        Specifies a case-sensitive issuer URI.
    #>
    [DscProperty()]
    [string]
    $IssuerUri

    <#
        Specifies user or group names that will be managers of the service namespace.
    #>
    [DscProperty(Mandatory)]
    [string[]]
    $ManageUsers

    <#
        Specifies the name for the new Service Bus for Windows Server service namespace.
    #>
    [DscProperty(Key)]
    [ValidateLength(6,50)]
    [string]
    $Name

    <#
        Specifies the primary key to be used in this service namespace.
    #>
    [DscProperty()]
    [string]
    $PrimarySymmetricKey

    <#
        Specifies the secondary key to be used in this service namespace.
    #>
    [DscProperty()]
    [string]
    $SecondarySymmetricKey

    <#
        An optional parameter that associates a namespace with a subscription. For example, this parameter is useful
        if an administrator creates a namespace on behalf of a user.
    #>
    [DscProperty()]
    [string]
    $SubscriptionId

    <#
        Marks whether the namespace should be present or absent.
    #>
    [DscProperty(Key)]
    [Ensure]
    $Ensure

    <#
        If Ensure is Absent and the namespace is present, setting this property to true will add the -Force
        to Remove-SBNamespace call. Default value is false.
    #>
    [DscProperty()]
    [bool]
    $ForceRemoval = $false

    <#
        Marks the creation time of the namepsace.
    #>
    [DscProperty(NotConfigurable)]
    [datetime]
    $CreatedTime

    <#
        Marks the state of the namespace.
    #>
    [DscProperty(NotConfigurable)]
    [string]
    $State

    <#
        This method is equivalent of the Get-TargetResource script function.
        The implementation should use the keys to find appropriate resources.
        This method returns an instance of this class with the updated key
        properties.
    #>
    [cSBNamespace] Get() {
        $result = [cSBNamespace]::new()

        Write-Verbose -Message "Checking for SBNamespace $($this.Name)."

        Write-Verbose -Message "Trying to get SBNamespace $($this.Name)."
        $sbNamespace = $null
        try {
            $sbNamespace = Get-SBNamespace -Name $this.Name
            Write-Verbose -Message "Successfully retrieved SBNamespace $($this.Name)."
        } catch {
            Write-Verbose -Message "Unable to detect SBNamespace $($this.Name)."
        }

        if ($null -eq $sbNamespace) {
            $result.Ensure = [Ensure]::Absent
            return $result
        }

        $result.AddressingScheme = $sbNamespace.AddressingScheme
        $result.CreatedTime = $sbNamespace.CreatedTime
        $result.DNSEntry = $sbNamespace.DNSEntry
        $result.Ensure = [Ensure]::Present
        $result.IssuerName = $sbNamespace.IssuerName
        $result.IssuerUri = $sbNamespace.IssuerUri
        $result.ManageUsers = $sbNamespace.ManageUsers
        $result.Name = $sbNamespace.Name
        $result.PrimarySymmetricKey = $sbNamespace.PrimarySymmetricKey
        $result.SecondarySymmetricKey = $sbNamespace.SecondarySymmetricKey
        $result.State = $sbNamespace.State.ToString()
        $result.SubscriptionId = $sbNamespace.SubscriptionId

        return $result
    }

    <#
        This method is equivalent of the Test-TargetResource script function.
        It should return True or False, showing whether the resource
        is in a desired state.
    #>
    [bool] Test() {
        $currentValues = $this.Get()

        if ($this.SBNamespaceShouldBeCreated($currentValues)) {
            return $false
        }

        if ($this.SBNamespaceShouldBeRemoved($currentValues)) {
            return $false
        }

        if ($this.SBNamespaceShouldBeUpdated($currentValues)) {
            return $false
        }

        return $true
    }

    [bool] SBNamespaceShouldBeCreated([cSBNameSpace]$CurrentValues) {
        return (($this.Ensure -eq [Ensure]::Present) -and ($CurrentValues.Ensure -eq [Ensure]::Absent))
    }

    [bool] SBNamespaceShouldBeRemoved([cSBNameSpace]$CurrentValues) {
        return (($this.Ensure -eq [Ensure]::Absent) -and ($CurrentValues.Ensure -eq [Ensure]::Present))
    }

    [bool] SBNamespaceShouldBeUpdated([cSBNameSpace]$CurrentValues) {
        $currentValuesHt = $CurrentValues.ToHashtable()

        $currentValuesHt.ManageUsers = $this.FormatManageUsers($currentValuesHt.ManageUsers)

        $desiredValuesHt = $this.ToHashtable()

        $desiredValuesHt.ManageUsers = $this.FormatManageUsers($desiredValuesHt.ManageUsers)

        $valuesToCheck = @()

        $valuesToCheck += 'ManageUsers'

        if ($null -ne $this.IssuerName) {
            $valuesToCheck += 'IssuerName'
        }

        if ($null -ne $this.IssuerUri) {
            $valuesToCheck += 'IssuerUri'
        }

        if ($null -ne $this.PrimarySymmetricKey) {
            $valuesToCheck += 'PrimarySymmetricKey'
        }

        if ($null -ne $this.SecondarySymmetricKey) {
            $valuesToCheck += 'SecondarySymmetricKey'
        }

        if ($null -ne $this.SubscriptionId) {
            $valuesToCheck += 'SubscriptionId'
        }

        $params = @{
            CurrentValues = $currentValuesHt
            DesiredValues = $desiredValuesHt
            ValuesToCheck = $valuesToCheck
        }
        return (-not (Test-cSBWSParameterState @params))
    }

    [string[]] FormatManageUsers([string[]] $ManageUsers) {
        $formattedManageUsers = @()

        $formattedManageUsers = $ManageUsers.ForEach{
            $formatAccountNameParams = @{
                FullAccountNameWithDomain = $_
                Format                    = 'UserLogonNamePreWindows2000'
            }
            (Format-AccountName @formatAccountNameParams).ToLower()
        }

        return $formattedManageUsers
    }


    <#
        This method is equivalent of the Set-TargetResource script function.
        It sets the resource to the desired state.
    #>
    [void] Set() {
        Write-Verbose -Message "Retrieving current SBNamespace values for namespace $($this.Name)"
        $currentValues = $this.Get()

        Write-Verbose -Message "Checking if SBNamespace $($this.Name) should be created"
        if ($this.SBNamespaceShouldBeCreated($currentValues)) {
            Write-Verbose -Message "Creating SBNamespace with Name $($this.Name)"
            $this.NewSBNamespace()
            return
        }

        Write-Verbose -Message "Checking if SBNamespace $($this.Name) should be removed"
        if ($this.SBNamespaceShouldBeRemoved($currentValues)) {
            Write-Verbose -Message "Removing SBNamespace with Name $($this.Name)"
            $this.RemoveSBNamespace()
            return
        }

        Write-Verbose -Message "Checking if SBNamespace $($this.Name) should be udpated"
        if ($this.SBNamespaceShouldBeUpdated($currentValues)) {
            Write-Verbose -Message "Updating SBNamespace with Name $($this.Name)"
            $this.SetSBNamespace()
            return
        }
    }

    [void] NewSBNamespace() {
        Write-Verbose -Message "Getting configurable properties as hashtable for New-SBNamespace params"
        $newSBNamespaceParams = $this.GetDscConfigurablePropertiesAsHashtable()

        Write-Verbose -Message "Throwing AddressingScheme param to string for New-SBNamespace params"
        Write-Verbose -Message "$($newSBNamespaceParams.AddressingScheme)"
        $newSBNamespaceParams.AddressingScheme = $newSBNamespaceParams.AddressingScheme.ToString()

        Write-Verbose -Message "Checking for DNSEntry"
        if ($null -eq $this.DNSEntry) {
            Write-Verbose -Message "DNSEntry is absent, removing from New-SBNamespace params"
            $newSBNamespaceParams.Remove("DNSEntry")
        }

        Write-Verbose -Message "Checking for IssuerName"
        if ($null -eq $this.IssuerName) {
            Write-Verbose -Message "IssuerName is absent, removing from New-SBNamespace params"
            $newSBNamespaceParams.Remove("IssuerName")
        }

        Write-Verbose -Message "Checking for IssuerUri"
        if ($null -eq $this.IssuerUri) {
            Write-Verbose -Message "IssuerUri is absent, removing from New-SBNamespace params"
            $newSBNamespaceParams.Remove("IssuerUri")
        }

        Write-Verbose -Message "Checking for PrimarySymmetricKey"
        if ($null -eq $this.PrimarySymmetricKey) {
            Write-Verbose -Message "PrimarySymmetricKey is absent, removing from New-SBNamespace params"
            $newSBNamespaceParams.Remove("PrimarySymmetricKey")
        }

        Write-Verbose -Message "Checking for SecondarySymmetricKey"
        if ($null -eq $this.SecondarySymmetricKey) {
            Write-Verbose -Message "SecondarySymmetricKey is absent, removing from New-SBNamespace params"
            $newSBNamespaceParams.Remove("SecondarySymmetricKey")
        }

        Write-Verbose -Message "Checking for SubscriptionId"
        if ($null -eq $this.SubscriptionId) {
            Write-Verbose -Message "SubscriptionId is absent, removing from New-SBNamespace params"
            $newSBNamespaceParams.Remove("SubscriptionId")
        }

        Write-Verbose -Message "Removing unnecessary parameters from New-SBNamespace params"
        $newSBNamespaceParams.Remove("Ensure")
        $newSBNamespaceParams.Remove("ForceRemoval")

        Write-Verbose -Message "Invoking New-SBNamespace with configurable params"
        New-SBNamespace @newSBNamespaceParams
    }

    [void] RemoveSBNamespace() {
        Write-Verbose -Message "Invoking Remove-SBNamespace with configurable params"
        if ($this.ForceRemoval -eq $true) {
            Write-Verbose -Message "ForceRemoval was specified, adding -Force parameter to Remove-SBNamespace"
            Remove-SBNamespace -Name $this.Name -Force
            return
        }
        Remove-SBNamespace -Name $this.Name
    }

    [void] SetSBNamespace() {
        Write-Verbose -Message "Getting configurable properties as hashtable for Set-SBNamespace params"
        $setSBNamespaceParams = $this.GetDscConfigurablePropertiesAsHashtable()

        Write-Verbose -Message "Checking for IssuerName"
        if ($null -eq $this.IssuerName) {
            Write-Verbose -Message "IssuerName is absent, removing from Set-SBNamespace params"
            $setSBNamespaceParams.Remove("IssuerName")
        }

        Write-Verbose -Message "Checking for IssuerUri"
        if ($null -eq $this.IssuerUri) {
            Write-Verbose -Message "IssuerUri is absent, removing from Set-SBNamespace params"
            $setSBNamespaceParams.Remove("IssuerUri")
        }

        Write-Verbose -Message "Checking for PrimarySymmetricKey"
        if ($null -eq $this.PrimarySymmetricKey) {
            Write-Verbose -Message "PrimarySymmetricKey is absent, removing from Set-SBNamespace params"
            $setSBNamespaceParams.Remove("PrimarySymmetricKey")
        }

        Write-Verbose -Message "Checking for SecondarySymmetricKey"
        if ($null -eq $this.SecondarySymmetricKey) {
            Write-Verbose -Message "SecondarySymmetricKey is absent, removing from Set-SBNamespace params"
            $setSBNamespaceParams.Remove("SecondarySymmetricKey")
        }

        Write-Verbose -Message "Checking for SubscriptionId"
        if ($null -eq $this.SubscriptionId) {
            Write-Verbose -Message "SubscriptionId is absent, removing from Set-SBNamespace params"
            $setSBNamespaceParams.Remove("SubscriptionId")
        }

        Write-Verbose -Message "Removing unnecessary parameters from Set-SBNamespace params"
        $setSBNamespaceParams.Remove("AddressingScheme")
        $setSBNamespaceParams.Remove("DNSEntry")
        $setSBNamespaceParams.Remove("Ensure")
        $setSBNamespaceParams.Remove("ForceRemoval")

        Write-Verbose -Message "Invoking Set-SBNamespace with configurable params"
        Set-SBNamespace @setSBNamespaceParams
    }
}

<#
   This resource adds and removes Service Bus for Windows Server message containers.
#>
[DscResource()]
class cSBMessageContainer : cSBBase {

    <#
        The credential for connecting to the container database. Not required if integrated authentication will be
        used.
    #>
    [DscProperty()]
    [pscredential]
    $ContainerDBConnectionStringCredential

    <#
        Represents the database server used for the farm management database. This is used in the
        ContainerDBConnectionString when creating the farm. This can optionally use named instance and port info if
        those are being used.
    #>
    [DscProperty(Key)]
    [string]
    $ContainerDBConnectionStringDataSource

    <#
        Represents whether the connection to the database server housing the container database will use SSL
        or not.
    #>
    [DscProperty()]
    [bool]
    $ContainerDBConnectionStringEncrypt = $false

    <#
        The name of the container database.
    #>
    [DscProperty(Key)]
    [string]
    $ContainerDBConnectionStringInitialCatalog

    <#
        Represents whether authentication to the container database will use integrated Windows authentication
        or SSPI (Security Support Provider Interface) which supports Kerberos, Windows or basic SQL authentication.
        (i.e. it will fall back to first available auth method from Kerberos -> Windows -> SQL Auth). The default
        value is SSPI.
    #>
    [DscProperty()]
    [IntegratedSecurity]
    $ContainerDBConnectionStringIntegratedSecurity = [IntegratedSecurity]::SSPI

    <#
        The credential for connecting to the farm management database. Not required if integrated authentication
        will be used.
    #>
    [DscProperty()]
    [pscredential]
    $SBFarmDBConnectionStringCredential

    <#
        Represents the database server used for the farm management database. This is used in the
        SBFarmDBConnectionString when creating the farm. This can optionally use named instance and port info if
        those are being used.
    #>
    [DscProperty()]
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
        or SSPI (Security Support Provider Interface) which supports Kerberos, Windows or basic SQL authentication.
        (i.e. it will fall back to first available auth method from Kerberos -> Windows -> SQL Auth). The default
        value is SSPI.
    #>
    [DscProperty()]
    [IntegratedSecurity]
    $SBFarmDBConnectionStringIntegratedSecurity = [IntegratedSecurity]::SSPI

    <#
        Marks whether the container should be present or absent.
    #>
    [DscProperty(Key)]
    [Ensure]
    $Ensure

    <#
        Id of the container.
    #>
    [DscProperty(NotConfigurable)]
    [int64]
    $Id

    <#
        Status of the container.
    #>
    [DscProperty(NotConfigurable)]
    [string]
    $Status

    <#
        Current service bus host associated to the container.
    #>
    [DscProperty(NotConfigurable)]
    [string]
    $Host

    <#
        The database connection string of the container.
    #>
    [DscProperty(NotConfigurable)]
    [string]
    $ContainerDBConnectionString

    <#
        Count of entities in the container.
    #>
    [DscProperty(NotConfigurable)]
    [int32]
    $EntitiesCount

    <#
        The size of the container database in megabytes.
    #>
    [DscProperty(NotConfigurable)]
    [double]
    $DatabaseSizeInMB

    <#
        This method is equivalent of the Get-TargetResource script function.
        The implementation should use the keys to find appropriate resources.
        This method returns an instance of this class with the updated key
        properties.
    #>
    [cSBMessageContainer] Get() {
        $result = [cSBMessageContainer]::new()

        Write-Verbose -Message "Checking for SBMessageContainer $($this.ContainerDBConnectionStringInitialCatalog)"

        Write-Verbose -Message "Trying to get SBMessageContainer $($this.ContainerDBConnectionStringInitialCatalog)"
        $sbMessageContainer = $null
        try {
            $sbMessageContainer = Get-SBMessageContainer |
                                      Where-Object {
                                          $_.DatabaseName -eq $this.ContainerDBConnectionStringInitialCatalog
                                      }
        } catch {
            Write-Verbose -Message "Unable to retrieve SBMessageContainer $($this.ContainerDBConnectionStringInitialCatalog)"
        }

        if ($null -eq $sbMessageContainer) {
            $result.Ensure = [Ensure]::Absent
            return $result
        }

        $params = @{
            SqlConnectionString = $sbMessageContainer.ConnectionString
        }
        $result.ContainerDBConnectionString = $sbMessageContainer.ConnectionString
        $result.ContainerDBConnectionStringCredential = $this.ContainerDBConnectionStringCredential
        $result.ContainerDBConnectionStringDataSource = $sbMessageContainer.DatabaseServer
        $params.PropertyName = "Encrypt"
        $result.ContainerDBConnectionStringEncrypt = [bool](Get-SqlConnectionStringPropertyValue @params)
        $result.ContainerDBConnectionStringInitialCatalog = $sbMessageContainer.DatabaseName
        $params.PropertyName = "Integrated Security"
        $result.ContainerDBConnectionStringIntegratedSecurity = [string](Get-SqlConnectionStringPropertyValue @params)

        $result.DatabaseSizeInMB = $sbMessageContainer.DatabaseSizeInMB
        $result.Ensure = [Ensure]::Present
        $result.EntitiesCount = $sbMessageContainer.EntitiesCount
        $result.Host = $sbMessageContainer.Host
        $result.Id = $sbMessageContainer.datetime
        $result.SBFarmDBConnectionStringCredential = $this.SBFarmDBConnectionStringCredential
        $result.SBFarmDBConnectionStringDataSource = $this.SBFarmDBConnectionStringDataSource
        $result.SBFarmDBConnectionStringEncrypt = $this.SBFarmDBConnectionStringEncrypt
        $result.SBFarmDBConnectionStringInitialCatalog = $this.SBFarmDBConnectionStringInitialCatalog
        $result.SBFarmDBConnectionStringIntegratedSecurity = $this.SBFarmDBConnectionStringIntegratedSecurity
        $result.Status = $sbMessageContainer.Status

        return $result
    }

    <#
        This method is equivalent of the Test-TargetResource script function.
        It should return True or False, showing whether the resource
        is in a desired state.
    #>
    [bool] Test() {
        $currentValues = $this.Get()

        if ($this.SBMessageContainerShouldBeCreated($currentValues)) {
            return $false
        }

        if ($this.SBMessageContainerShouldBeRemoved($currentValues)) {
            return $false
        }

        return $true
    }

    [bool] SBMessageContainerShouldBeCreated([cSBMessageContainer]$CurrentValues) {
        return (($this.Ensure -eq [Ensure]::Present) -and ($CurrentValues.Ensure -eq [Ensure]::Absent))
    }

    [bool] SBMessageContainerShouldBeRemoved([cSBMessageContainer]$CurrentValues) {
        return (($this.Ensure -eq [Ensure]::Absent) -and ($CurrentValues.Ensure -eq [Ensure]::Present))
    }

    <#
        This method is equivalent of the Set-TargetResource script function.
        It sets the resource to the desired state.
    #>
    [void] Set() {
        Write-Verbose -Message "Retrieving current SBMessageContainer values for container $($this.ContainerDBConnectionStringInitialCatalog)"
        $currentValues = $this.Get()

        Write-Verbose -Message "Checking if SBMessageContainer $($this.ContainerDBConnectionStringInitialCatalog) should be created"
        if ($this.SBMessageContainerShouldBeCreated($currentValues)) {
            $this.NewSBMessageContainer()
        }

        Write-Verbose -Message "Checking if SBMessageContainer $($this.ContainerDBConnectionStringInitialCatalog) should be removed"
        if ($this.SBMessageContainerShouldBeRemoved($currentValues)) {
            $this.RemoveSBMessageContainer()
        }
    }

    [void] NewSBMessageContainer() {
        Write-Verbose -Message "Getting configurable properties as hashtable for New-SBMessageContainer params"
        $newSBMessageContainerParams = $this.GetDscConfigurablePropertiesAsHashtable()

        Write-Verbose -Message "Checking for SBFarmDBConnectionString properties"
        if (($null -ne $this.SBFarmDBConnectionStringDataSource) -and
            ($null -ne $this.SBFarmDBConnectionStringInitialCatalog)) {
            Write-Verbose -Message "SBFarmDBConnectionString properties are present"
            Write-Verbose -Message "Creating params for SBFarmDBConnectionString"
            $sbFarmDBConnectionStringParams = @{
                DataSource         = $this.SBFarmDBConnectionStringDataSource
                InitialCatalog     = $this.SBFarmDBConnectionStringInitialCatalog
                IntegratedSecurity = $this.SBFarmDBConnectionStringIntegratedSecurity.ToString()
                Credential         = $this.SBFarmDBConnectionStringCredential
                Encrypt            = $this.SBFarmDBConnectionStringEncrypt
            }
            Write-Verbose -Message "Creating SBFarmDBConnectionString"
            $sbFarmDBCxnString = New-SqlConnectionString @sbFarmDBConnectionStringParams
            Write-Verbose -Message "Setting SBFarmDBConnectionString in New-SBMessageContainer params"
            $newSBMessageContainerParams.SBFarmDBConnectionString = $sbFarmDBCxnString
        }

        Write-Verbose -Message "Creating params for ContainerDBConnectionString"
        $containerDBConnectionStringParams = @{
            DataSource         = $this.ContainerDBConnectionStringDataSource
            InitialCatalog     = $this.ContainerDBConnectionStringInitialCatalog
            IntegratedSecurity = $this.ContainerDBConnectionStringIntegratedSecurity.ToString()
            Credential         = $this.ContainerDBConnectionStringCredential
            Encrypt            = $this.ContainerDBConnectionStringEncrypt
        }
        Write-Verbose -Message "Creating ConnectionDBConnectionString"
        $containerDBCxnString = New-SqlConnectionString @containerDBConnectionStringParams
        Write-Verbose -Message "Setting ConnectionDBConnectionString in New-SBMessageContainer params"
        $newSBMessageContainerParams.ContainerDBConnectionString = $containerDBCxnString

        Write-Verbose -Message "Removing unnecessary parameters from New-SBMessageContainer params"
        $newSBMessageContainerParams.Remove("ContainerDBConnectionStringCredential")
        $newSBMessageContainerParams.Remove("ContainerDBConnectionStringDataSource")
        $newSBMessageContainerParams.Remove("ContainerDBConnectionStringEncrypt")
        $newSBMessageContainerParams.Remove("ContainerDBConnectionStringInitialCatalog")
        $newSBMessageContainerParams.Remove("ContainerDBConnectionStringIntegratedSecurity")
        $newSBMessageContainerParams.Remove("Ensure")
        $newSBMessageContainerParams.Remove("SBFarmDBConnectionStringCredential")
        $newSBMessageContainerParams.Remove("SBFarmDBConnectionStringDataSource")
        $newSBMessageContainerParams.Remove("SBFarmDBConnectionStringEncrypt")
        $newSBMessageContainerParams.Remove("SBFarmDBConnectionStringInitialCatalog")
        $newSBMessageContainerParams.Remove("SBFarmDBConnectionStringIntegratedSecurity")

        Write-Verbose -Message "Invoking New-SBMessageContainer with configurable params"
        New-SBMessageContainer @newSBMessageContainerParams
    }

    [void] RemoveSBMessageContainer() {
        Write-Verbose -Message ("Retrieving SBMessageContainer by database name " +
                                "$($this.ContainerDBConnectionStringInitialCatalog) to get its Id.")
        $sbMessageContainer = Get-SBMessageContainer |
                                 Where-Object {
                                     $_.DatabaseName -eq $this.ContainerDBConnectionStringInitialCatalog
                                 }

        Write-Verbose -Message "Invoking Remove-SBMessageContainer with Id $($sbMessageContainer.Id)"
        Remove-SBMessageContainer -Id $sbMessageContainer.Id -Force
    }
}


# [DscResource()]
# class cSBAuthorizationRule {
#     [DscProperty(Key)]
#     [Ensure]
#     $Ensure

#     [void] Set() {

#     }

#     [bool] Test() {
#         return $true
#     }

#     [cSBAuthorizationRule] Get() {
#         return $this
#     }
# }


# [DscResource()]
# class cSBHostCEIP {
#     [DscProperty(Key)]
#     [Ensure]
#     $Ensure

#     [void] Set() {

#     }

#     [bool] Test() {
#         return $true
#     }

#     [cSBHostCEIP] Get() {
#         return $this
#     }
# }

# OR SETTINGS PLURAL???
# [DscResource()]
# class cSBRunTimeSetting {
#     [DscProperty(Key)]
#     [Ensure]
#     $Ensure

#     [void] Set() {

#     }

#     [bool] Test() {
#         return $true
#     }

#     [cSBRunTimeSetting] Get() {
#         return $this
#     }
# }
