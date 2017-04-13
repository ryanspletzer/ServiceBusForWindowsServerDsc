using module ..\SBBase
Using module ..\..\Modules\SB.Util\SB.Util.psd1

<#
   SBFarm creates a new farm and sets certain settings for a Service Bus for Windows Server farm.
#>
[DscResource()]
class SBFarm : SBBase
{

    <#
        Sets the resource provider credentials. The resource provider is a component that exposes the management API
        to the (Azure Pack) portal. There are two Service Bus management portals; the Admin portal (which provides a
        set of resource provider APIs for farm administration), and the Tenant portal (which is the Windows Azure
        Management Portal). Use these credentials when you manually install the server farm and connect to the Admin
        portal.
    #>
    [DscProperty()]
    [pscredential]
    $AdminApiCredentials

    <#
        Respresents the admin group of the farm. If not specified the default value will be BUILTIN\Administrators.
    #>
    [DscProperty()]
    [string]
    $AdminGroup = 'BUILTIN\Administrators'

    <#
        This optional parameter sets the AMQP port. The default 5672. This setting cannot be changed after the farm
        has been provisioned.
    #>
    [DscProperty()]
    [ValidateRange(1024,65535)]
    [int32]
    $AmqpPort = 5672

    <#
        This optional parameter sets the AMQP SSL port. The default is 5671. This setting cannot be changed after
        the farm has been provisioned.
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
        Represents the subject certificate that is used for securing the certificate. Do not provide this certificate if you
        are providing CertificateAutoGenerationKey for auto generation of certificates.
    #>
    [DscProperty()]
    [string]
    $FarmCertificateSubject

    <#
        The DNS prefix (alias) that is mapped to all server farm nodes. This cmdlet is used when an administrator
        registers a server farm. The server farm node value is returned when you call the Get-SBClientConfiguration
        cmdlet to request a connection string.
    #>
    [DscProperty()]
    [string]
    $FarmDNS

    <#
        The credential for connecting to the Gateway database. Not required if integrated authentication will be
        used. The default value for this will be the same as that specified for farm management database
        credentials.
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
        Represents whether the database server housing the gateway database will use SSL/TLS or not. The default
        value for this will be the same as that specified for farm management database server.
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
        9355. This setting cannot be changed after the farm has been provisioned.
    #>
    [DscProperty()]
    [ValidateRange(1024,65535)]
    [int32]
    $HttpsPort = 9355

    <#
        Represents the start of the port range that the Service Bus for Windows Server uses for internal
        communication purposes. The default is 9000. This setting cannot be changed after the farm has been
        provisioned.
    #>
    [DscProperty()]
    [ValidateRange(1024,65535)]
    [int32]
    $InternalPortRangeStart = 9000

    <#
        Represents the port that the Service Bus for Windows Server uses for MessageBroker communication. The
        default is 9356. This setting cannot be changed after the farm has been provisioned.
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
        The name of the initial message container database. Default value is 'SBMessageContainer01'.
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
        access the Service Bus farm. The default is 9359. This setting cannot be changed after the farm has been
        provisioned.
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
        or not. Default value is false.
    #>
    [DscProperty()]
    [bool]
    $SBFarmDBConnectionStringEncrypt = $false

    <#
        The name of the farm management database. Default value is 'SBManagementDB'.
    #>
    [DscProperty()]
    [string]
    $SBFarmDBConnectionStringInitialCatalog = 'SBManagementDB'

    <#
        Represents whether authentication to the farm management database will use integrated Windows authentication
        or SSPI (Security Support Provider Interface) which supports Kerberos, Windows or basic SQL authentication.
        (i.e. it will fall back to first available auth method from Kerberos -> Windows -> SQL Auth). Valid values
        include True, False and SSPI. The default value is SSPI.
    #>
    [DscProperty()]
    [IntegratedSecurity]
    $SBFarmDBConnectionStringIntegratedSecurity = [IntegratedSecurity]::SSPI

    <#
        Represents the port that the Service Bus for Windows Server uses for TCP. The default is 9354. This setting
        cannot be changed after the farm has been provisioned.
    #>
    [DscProperty()]
    [ValidateRange(1024,65535)]
    [int32]
    $TcpPort = 9354

    <#
        Sets the resource provider credentials for the tenant portal. The resource provider is a component that
        exposes the management API to the (Azure Pack) portal. There are two Service Bus management portals; the
        Admin portal (which provides a set of resource provider APIs for farm administration), and the Tenant portal
        (which is the Windows Azure Management Portal). Use these credentials when you manually install the server
        farm and connect to the tenant portal.
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
        The resource provider credential user name. The resource provider is a component that exposes the management
        API to the portal. There are two Service Bus management portals; the Admin portal (which provides a set of
        resource provider APIs for farm administration), and the Tenant portal (which is the Windows Azure
        Management Portal).
    #>
    [DscProperty(NotConfigurable)]
    [string]
    $AdminApiUserName

    <#
        The resource provider credential user name for the tenant portal. The resource provider is a component that
        exposes the management API to the portal. There are two Service Bus management portals; the Admin portal
        (which provides a set of resource provider APIs for farm administration), and the Tenant portal (which is
        the Windows Azure Management Portal).
    #>
    [DscProperty(NotConfigurable)]
    [string]
    $TenantApiUserName

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
        This method is equivalent of the Get-TargetResource script function.
        The implementation should use the keys to find appropriate resources.
        This method returns an instance of this class with the updated key
        properties.
    #>
    [SBFarm] Get()
    {
        $result = [SBFarm]::new()

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
        try
        {
            $sbFarm = Get-SBFarm -SBFarmDBConnectionString $connectionString
            Write-Verbose -Message "Successfully retrieved SBFarm."
        }
        catch
        {
            Write-Verbose -Message "Unable to detect SBFarm."
        }

        if ($null -eq $sbFarm)
        {
            return $null
        }

        Write-Verbose -Message "Trying to get default SBMessageContainer."
        $sbMessageContainer = $null
        try
        {
            $sbMessageContainer = Get-SBMessageContainer -Id 1
            Write-Verbose -Message "Successfully retrieved default SBMessageContainer."
        }
        catch
        {
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

        if([string]::IsNullOrEmpty($sbFarm.GatewayDBConnectionString) -eq $false)
        {
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
        }

        $result.HttpsPort = $sbFarm.HttpsPort
        $result.InternalPortRangeStart = $sbFarm.ClusterConnectionEndpointPort
        $result.LeaseDriverEndpointPort = $sbFarm.LeaseDriverEndpointPort
        $result.MessageBrokerPort = $sbFarm.MessageBrokerPort

        $result.MessageContainerDBConnectionStringCredential = $this.MessageContainerDatabaseCredential
        if ($null -ne $sbMessageContainer)
        {
            $params = @{
                SqlConnectionString = $sbMessageContainer.ConnectionString
            }
            $params.PropertyName = "Data Source"
            $result.MessageContainerDBConnectionStringDataSource = [string](
                Get-SqlConnectionStringPropertyValue @params
            )
            $params.PropertyName = "Encrypt"
            $result.MessageContainerDBConnectionStringEncrypt = [bool](Get-SqlConnectionStringPropertyValue @params)
            $params.PropertyName = "Initial Catalog"
            $result.MessageContainerDBConnectionStringInitialCatalog = [string](
                Get-SqlConnectionStringPropertyValue @params
            )
            $params.PropertyName = "Integrated Security"
            $result.MessageContainerDBConnectionStringIntegratedSecurity = [string](
                Get-SqlConnectionStringPropertyValue @params
            )
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
    [bool] Test()
    {
        $currentValues = $this.Get()

        if ($null -eq $currentValues)
        {
            return $false
        }

        $currentValuesHt = $currentValues.ToHashtable()

        $desiredValuesHt = $this.ToHashtable()

        if([string]::IsNullOrEmpty($desiredValuesHt.FarmDNS))
        {
            $desiredValuesHt.FarmDNS = ""
        }

        if([string]::IsNullOrEmpty($desiredValuesHt.AdminApiCredentials.UserName))
        {
            $desiredValuesHt.AdminApiUserName = ""
        }
        else
        {
            $desiredValuesHt.AdminApiUserName = $desiredValuesHt.AdminApiCredentials.UserName
        }

        if([string]::IsNullOrEmpty($desiredValuesHt.TenantApiCredentials.UserName))
        {
            $desiredValuesHt.TenantApiUserName = ""
        }
        else
        {
            $desiredValuesHt.TenantApiUserName = $desiredValuesHt.TenantApiCredentials.UserName
        }

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
        return Test-SBParameterState @params
    }

    <#
        This method is equivalent of the Set-TargetResource script function.
        It sets the resource to the desired state.
    #>
    [void] Set()
    {
        Write-Verbose -Message "Checking whether to make new SBFarm or set existing SBFarm"
        if ($null -eq $this.Get())
        {
            Write-Verbose -Message "No farm detected, new SBFarm will be created"
            $this.NewSBFarm()
        }
        else
        {
            Write-Verbose -Message "Farm detected, settable SBFarm settings will be set"
            $this.SetSBFarm()
        }
    }

    [void] NewSBFarm()
    {
        Write-Verbose -Message "Getting configurable properties as hashtable for New-SBFarm params"
        $newSBFarmParams = $this.GetDscConfigurablePropertiesAsHashtable()

        Write-Verbose -Message "Checking for CertificateAutoGenerationKey"
        if ($null -eq $this.CertificateAutoGenerationKey)
        {
            Write-Verbose -Message "CertificateAutoGenerationKey is absent, removing from New-SBFarm params"
            $newSBFarmParams.Remove("CertificateAutoGenerationKey")

            Write-Verbose -Message "Checking Certificate subject."
            if ($null -ne $this.FarmCertificateSubject)
            {
                if ($this.FarmCertificateSubject.ToLower().Substring(0,3) -ne 'cn=')
                {
                    $CertSubject = "cn=" + $this.FarmCertificateSubject.ToLower()
                }
                else
                {
                    $CertSubject = $this.FarmCertificateSubject.ToLower()
                }

                $CertificateThumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My\ | Where-Object {$_.Subject.ToLower() -eq $CertSubject}).Thumbprint
                if ($null -ne $CertificateThumbprint)
                {
                    $newSBFarmParams.FarmCertificateThumbprint = $CertificateThumbprint

                    if ($null -eq $this.EncryptionCertificateThumbprint)
                    {
                        $newSBFarmParams.EncryptionCertificateThumbprint = $CertificateThumbprint
                    }
                }
            }

        }
        else
        {
            Write-Verbose -Message "CertificateAutoGenerationKey is present, swapping pscredential for securestring"
            $newSBFarmParams.Remove("CertificateAutoGenerationKey")
            $newSBFarmParams.Remove("FarmCertificateThumbprint")
            $newSBFarmParams.Remove("EncryptionCertificateThumbprint")
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
            [String]::IsNullOrEmpty($this.GatewayDBConnectionStringDataSource))
        {
            Write-Verbose -Message ("GatewayDBConnectionStringDataSource not specified, " +
                                    "using SBFarmDBConnectionStringDataSource")
            $gatewayDBConnectionStringParams.DataSource = $this.SBFarmDBConnectionStringDataSource
        }
        if ($null -eq $this.GatewayDBConnectionStringCredential)
        {
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
            [String]::IsNullOrEmpty($this.MessageContainerDBConnectionStringDataSource))
        {
            Write-Verbose -Message ("MessageContainerDBConnectionStringDataSource not specified, " +
                                    "using SBFarmDBConnectionStringDataSource")
            $messageContainerDBConnectionStringParams.DataSource = $this.SBFarmDBConnectionStringDataSource
        }
        if ($null -eq $this.MessageContainerDBConnectionStringCredential)
        {
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

        Write-Verbose -Message "Removing FarmCertificateSubject regardless of if it was used"
        $newSBFarmParams.Remove("FarmCertificateSubject")

        Write-Verbose -Message "Invoking New-SBFarm with configurable params"
        New-SBFarm @newSBFarmParams
    }

    [void] SetSBFarm()
    {
        Write-Verbose -Message ("The current Service Bus Farm exists, however settings have changed. The " +
                                "SBFarm resource only able to detect/set certain changes once a farm has been " +
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
        $setSBFarmParams.Remove("FarmCertificateSubject")

        Write-Verbose -Message ("Invoking Stop-SBFarm prior to calling Set-SBFarm. " +
                                "SBHost resource should re-start hosts individually.")
        Stop-SBFarm

        Write-Verbose -Message "Invoking Set-SBFarm with configurable params"
        Set-SBFarm @setSBFarmParams
    }
}
