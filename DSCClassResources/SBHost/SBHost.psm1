using module ..\SBBase

<#
   SBHost adds and removes a host from a farm, and starts, stops and updates settings for a Service Bus for
   Windows Server host.
#>
[DscResource()]
class SBHost : SBBase
{

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
        or not. Default value is false.
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
        (i.e. it will fall back to first available auth method from Kerberos -> Windows -> SQL Auth). Valid values
        include True, False and SSPI. The default value is SSPI.
    #>
    [DscProperty()]
    [IntegratedSecurity]
    $SBFarmDBConnectionStringIntegratedSecurity = [IntegratedSecurity]::SSPI

    <#
        Indicates whether host should be in started or stopped state. Default is true / started.
    #>
    [DscProperty()]
    [bool]
    $Started = $true

    <#
        Marks whether the host should be Present or Absent.
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
    [SBHost] Get()
    {
        $result = [SBHost]::new()

        Write-Verbose -Message "Checking for SBHost."

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

        Write-Verbose -Message ("Checking SBFarm.Hosts for presence of $hostName")
        $existingHost = $sbFarm.Hosts |
                            Where-Object{
                                $_.Name -eq "$hostName"
                            }

        if ($null -eq $existingHost)
        {
            Write-Verbose -Message "Host is not present in SBFarm.Hosts."
            $result.Ensure = [Ensure]::Absent
            $result.Started = $false
            return $result
        }

        Write-Verbose -Message "Trying to get SBFarmStatus of current host."
        $sbFarmStatus = $null
        try
        {
            $sbFarmStatus = Get-SBFarmStatus |
                                Where-Object{
                                    $_.HostName -eq "$hostName"
                                }
            Write-Verbose -Message "Successfully retrieved SBFarmStatus."
        }
        catch
        {
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

        if ($null -ne $sbFarmStatus)
        {
            $sbFarmStatus |
                ForEach-Object{
                    if ($_.Status -ne "Running")
                    {
                        $result.Started = $false
                    }
                }
        }
        else
        {
            $result.Started = $false
        }

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

        if ($this.SBHostShouldBeAdded($currentValues))
        {
            return $false
        }

        if ($this.SBHostShouldBeRemoved($currentValues))
        {
            return $false
        }

        if ($this.SBHostShouldBeStarted($currentValues))
        {
            return $false
        }

        if ($this.SBHostShouldBeStopped($currentValues))
        {
            return $false
        }

        $params = @{
            CurrentValues = $currentValues.ToHashtable()
            DesiredValues = $this.ToHashtable()
            ValuesToCheck = @( "SBFarmDBConnectionStringDataSource" )
        }
        return Test-SBParameterState @params
    }

    [bool] SBHostShouldBeAdded([SBHost] $CurrentValues)
    {
        return (($this.Ensure -eq [Ensure]::Present) -and ($CurrentValues.Ensure -eq [Ensure]::Absent))
    }

    [bool] SBHostShouldBeRemoved([SBHost] $CurrentValues)
    {
        return (($this.Ensure -eq [Ensure]::Absent) -and ($CurrentValues.Ensure -eq [Ensure]::Present))
    }

    [bool] SBHostShouldBeStarted([SBHost] $CurrentValues)
    {
        return (($this.Started -eq $true) -and ($CurrentValues.Started -eq $false))
    }

    [bool] SBHostShouldBeStopped([SBHost] $CurrentValues)
    {
        return (($this.Started -eq $false) -and ($CurrentValues.Started -eq $true))
    }

    <#
        This method is equivalent of the Set-TargetResource script function.
        It sets the resource to the desired state.
    #>
    [void] Set()
    {
        Write-Verbose -Message "Retrieving current SBHost values"
        $currentValues = $this.Get()

        Write-Verbose -Message "Checking if SBHost should be added to the farm"
        if ($this.SBHostShouldBeAdded($currentValues))
        {
            Write-Verbose -Message "SBHost will be added to the farm"
            $this.AddSBHost()
            Write-Verbose -Message "Checking if SBHost should be started"
            if ($this.Started -eq $true)
            {
                Write-Verbose -Message "Starting SBHost"
                Start-SBHost
            }
            return
        }

        Write-Verbose -Message "Checking if SBHost should be removed from the farm"
        if ($this.SBHostShouldBeRemoved($currentValues))
        {
            Write-Verbose -Message "SBHost will be removed from the farm"
            Write-Verbose -Message "Checking if SBHost should be stopped prior to removing"
            if ($currentValues.Started -eq $true)
            {
                Write-Verbose -Message "Stopping SBHost"
                Stop-SBHost
            }
            $this.RemoveSBHost()
            Write-Verbose -Message "Ending SBHost.Set() after removal"
            return
        }

        Write-Verbose -Message "Checking if SBHost should be started"
        if ($this.SBHostShouldBeStarted($currentValues))
        {
            Write-Verbose -Message "SBHost will be started"
            Write-Verbose -Message "Updating SBHost prior to starting"
            $this.UpdateSBHost()
            Write-Verbose -Message "Starting SBHost"
            Start-SBHost
            return
        }

        Write-Verbose -Message ("SBHost can only detect certain changes live -- to change certain settings on a " +
                                "host, push a configuration with the host stopped, then push a new config with " +
                                "the host push a configuration with the host stopped, then push a new config " +
                                "with the host started and it will explicitly re-update the settings. Or, simply" +
                                "stop the host services and push the started DSC config.")
        Write-Verbose -Message "Checking if SBHost should be stopped"
        if ($this.SBHostShouldBeStopped($currentValues))
        {
            Write-Verbose -Message "Stopping SBHost"
            Stop-SBHost
            return
        }
    }

    [void] AddSBHost() {
        Write-Verbose -Message "Getting configurable properties as hashtable for Add-SBHost params"
        $addSBHostParams = $this.GetDscConfigurablePropertiesAsHashtable()

        Write-Verbose -Message "Checking for CertificateAutoGenerationKey"
        if ($null -eq $this.CertificateAutoGenerationKey)
        {
            Write-Verbose -Message "CertificateAutoGenerationKey is absent, removing from Add-SBHost params"
            $addSBHostParams.Remove("CertificateAutoGenerationKey")
        }
        else
        {
            Write-Verbose -Message "CertificateAutoGenerationKey is present, swapping pscredential for securestring"
            $addSBHostParams.Remove("CertificateAutoGenerationKey")
            $addSBHostParams.CertificateAutoGenerationKey = $this.CertificateAutoGenerationKey.Password
        }

        Write-Verbose -Message "Checking for ExternalBrokerPort"
        if (0 -eq $addSBHostParams.ExternalBrokerPort)
        {
            Write-Verbose -Message "ExternalBrokerPort is absent, removing from Add-SBHost params"
            $addSBHostParams.Remove("ExternalBrokerPort")
        }
        Write-Verbose -Message "Checking for ExternalBrokerUrl"
        if ($null -eq $addSBHostParams.ExternalBrokerUrl)
        {
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

    [void] RemoveSBHost()
    {
        Write-Verbose -Message "Getting configurable properties as hashtable for Remove-SBHost params"
        $removeSBHostParams = $this.GetDscConfigurablePropertiesAsHashtable()

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

    [void] UpdateSBHost()
    {
        Write-Verbose -Message "Getting configurable properties as hashtable for Update-SBHost params"
        $updateSBHostParams = $this.GetDscConfigurablePropertiesAsHashtable()

        Write-Verbose -Message "Checking for CertificateAutoGenerationKey"
        if ($null -eq $this.CertificateAutoGenerationKey)
        {
            Write-Verbose -Message "CertificateAutoGenerationKey is absent, removing from Update-SBHost params"
            $updateSBHostParams.Remove("CertificateAutoGenerationKey")
        }
        else
        {
            Write-Verbose -Message "CertificateAutoGenerationKey is present, swapping pscredential for securestring"
            $updateSBHostParams.Remove("CertificateAutoGenerationKey")
            $updateSBHostParams.CertificateAutoGenerationKey = $this.CertificateAutoGenerationKey.Password
        }

        Write-Verbose -Message "Checking for ExternalBrokerPort"
        if (0 -eq $updateSBHostParams.ExternalBrokerPort)
        {
            Write-Verbose -Message "ExternalBrokerPort is absent, removing from Update-SBHost params"
            $updateSBHostParams.Remove("ExternalBrokerPort")
        }
        Write-Verbose -Message "Checking for ExternalBrokerUrl"
        if ($null -eq $updateSBHostParams.ExternalBrokerUrl)
        {
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
