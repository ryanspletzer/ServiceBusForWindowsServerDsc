enum Ensure {
    Absent
    Present
}


enum IntegratedSecurity {
    True
    False
    SSPI
}


enum State {
    Started
    Stopped
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
   This resource creates a Service Bus for Windows Server farm.
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
        or SSPI (Security Support Provider Interface) which supports Kerberos or regular SQL authentication. or basic
        SQL authentication. The default value is SSPI (i.e. it will fall back to first available auth method from
        Kerberos -> Windows -> SQL Auth).
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
                                "cSBFarm resource only able to detect/set certain changess once a farm has been " +
                                "provisioned, including: AdminApiCredentials.UserName, AdminGroup, FarmDNS, " +
                                "RunAsAccount, TenantApiCredentials.UserName")
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


[DscResource()]
class cSBHost :cSBBase {

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
    [DscProperty()]
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
    [uri]
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
        or SSPI (Security Support Provider Interface) which supports Kerberos or regular SQL authentication. or basic
        SQL authentication. The default value is SSPI (i.e. it will fall back to first available auth method from
        Kerberos -> Windows -> SQL Auth).
    #>
    [DscProperty()]
    [IntegratedSecurity]
    $SBFarmDBConnectionStringIntegratedSecurity = [IntegratedSecurity]::SSPI

    <#
        Indicates whether host should be started or stopped.
    #>
    [DscProperty()]
    [State]
    $State = [State]::Started

    <#
        Marks whether the host should be present or absent. Default is present.
    #>
    [DscProperty()]
    [Ensure]
    $Ensure = [Ensure]::Present

    [void] Set() {

    }

    [void] AddSBHost() {

    }

    [void] UpdateSBHost() {

    }

    [void] RemoveSBHost() {

    }

    [bool] Test() {
        return $true
    }

    [cSBHost] Get() {
        $result = [cSBHost]::new()

        return $result
    }
}
