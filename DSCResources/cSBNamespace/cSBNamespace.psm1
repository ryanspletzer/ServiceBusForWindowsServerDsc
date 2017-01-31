using module ..\cSBBase


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
