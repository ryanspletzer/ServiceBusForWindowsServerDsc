using module ..\SBBase


<#
    SBMessageContainer adds and removes a Service Bus for Windows Server message container.
#>
[DscResource()]
class SBMessageContainer : SBBase {

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
        or not. Default value is false.
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
        (i.e. it will fall back to first available auth method from Kerberos -> Windows -> SQL Auth). Valid values
        include True, False and SSPI.The default value is SSPI.
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
        (i.e. it will fall back to first available auth method from Kerberos -> Windows -> SQL Auth). Valid values
        include True, False and SSPI.The default value is SSPI.
    #>
    [DscProperty()]
    [IntegratedSecurity]
    $SBFarmDBConnectionStringIntegratedSecurity = [IntegratedSecurity]::SSPI

    <#
        Marks whether the container should be Present or Absent.
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
    [SBMessageContainer] Get() {
        $result = [SBMessageContainer]::new()

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

    [bool] SBMessageContainerShouldBeCreated([SBMessageContainer]$CurrentValues) {
        return (($this.Ensure -eq [Ensure]::Present) -and ($CurrentValues.Ensure -eq [Ensure]::Absent))
    }

    [bool] SBMessageContainerShouldBeRemoved([SBMessageContainer]$CurrentValues) {
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
