using Module ..\SBBase


<#
    SBAuthorizationRule adds, removes and updates settings for a Service Bus for Windows Server authorization rule.
#>
[DscResource()]
class SBAuthorizationRule : SBBase {

    <#
        The name of the authorization rule.
    #>
    [DscProperty(Key)]
    [string]
    $Name

    <#
        The namespace scope of the authorization rule.
    #>
    [DscProperty(Key)]
    [string]
    $NamespaceName

    <#
        The key that will be used by this authorization rule. If not provided, Service Bus generates a key. You can
        explicitly set this parameter if you want to reinstall a farm while keeping the client untouched.
    #>
    [DscProperty()]
    [string]
    $PrimaryKey

    <#
        The comma separated list of access rights enabled with this authorization rule. Access rights include
        manage, send and listen. If not specified, defaults to full rights (Listen, Send, and Manage).
    #>
    [DscProperty()]
    [ValidateSet('Listen','Send','Manage')]
    [string[]]
    $Rights

    <#
        The key which will be used by this authorization rule. If not provided, Service Bus generates a key. You can
        explicitly set this parameter if you want to reinstall a farm while keeping the client untouched.
    #>
    [DscProperty()]
    [string]
    $SecondaryKey

    <#
        Marks whether the authorization rule should be Present or Absent.
    #>
    [DscProperty(Key)]
    [Ensure]
    $Ensure

    <#
        Time at which the authorization rule was created.
    #>
    [DscProperty(NotConfigurable)]
    [datetime]
    $CreatedTime

    <#
        Time at which the authorization rule was last modified.
    #>
    [DscProperty(NotConfigurable)]
    [datetime]
    $ModifiedTime

    [SBAuthorizationRule] Get() {
        $result = [SBAuthorizationRule]::new()

        Write-Verbose -Message "Checking for SBAuthorizationRule $($this.Name) on namespace $($this.NamespaceName)."

        Write-Verbose -Message ("Trying to get SBAuthorizationRule $($this.Name) on namespace " +
                                "$($this.NamespaceName).")

        $sbAuthorizationRule = $null
        try {
            $sbAuthorizationRule = Get-SBAuthorizationRule -Name $this.Name -NamespaceName $this.NamespaceName
            Write-Verbose -Message ("Successfully retrieved SBAuthorizationRule $($this.Name) on namespace " +
                                    "$($this.NamespaceName).")
        } catch {
            Write-Verbose -Message ("Unable to detect SBAuthorizationRule $($this.Name) on namespace " +
                                    "$($this.NamespaceName).")
        }

        if ($null -eq $sbAuthorizationRule) {
            $result.Ensure = [Ensure]::Absent
            return $result
        }

        $result.CreatedTime = $sbAuthorizationRule.CreatedTime
        $result.Ensure = [Ensure]::Present
        $result.ModifiedTime = $sbAuthorizationRule.ModifiedTime
        $result.Name = $sbAuthorizationRule.KeyName
        $result.NamespaceName = $this.NamespaceName
        $result.PrimaryKey = $sbAuthorizationRule.PrimaryKey
        $result.Rights = [string[]]$sbAuthorizationRule.Rights.ForEach({$_})
        $result.SecondaryKey = $sbAuthorizationRule.SecondaryKey

        return $result
    }

    [bool] Test() {
        $currentValues = $this.Get()

        if ($this.SBAuthorizationRuleShouldBeCreated($currentValues)) {
            return $false
        }

        if ($this.SBAuthorizationRuleShouldBeRemoved($currentValues)) {
            return $false
        }

        if ($this.SBAuthorizationRuleShouldBeUpdated($currentValues)) {
            return $false
        }

        return $true
    }

    [bool] SBAuthorizationRuleShouldBeCreated([SBAuthorizationRule]$CurrentValues) {
        return (($this.Ensure -eq [Ensure]::Present) -and ($CurrentValues.Ensure -eq [Ensure]::Absent))
    }

    [bool] SBAuthorizationRuleShouldBeRemoved([SBAuthorizationRule]$CurrentValues) {
        return (($this.Ensure -eq [Ensure]::Absent) -and ($CurrentValues.Ensure -eq [Ensure]::Present))
    }

    [bool] SBAuthorizationRuleShouldBeUpdated([SBAuthorizationRule]$CurrentValues) {
        $currentRights = $CurrentValues.Rights
        $desiredRights = $this.Rights

        ForEach($desiredRight in $desiredRights) {
            if ($desiredRight -notin $currentRights) {
                # Too few rights assigned
                return $true
            }
        }

        ForEach($currentRight in $currentRights) {
            if ($currentRight -notin $desiredRights) {
                # Too many rights assigned
                return $true
            }
        }

        if ($null -ne $this.PrimaryKey) {
            $primaryKeyTestResult = $this.PrimaryKey -eq $CurrentValues.PrimaryKey
            if ($primaryKeyTestResult -eq $false) {
                return $true
            }
        }

        if ($null -ne $this.SecondaryKey) {
            $secondaryKeyTestResult = $this.SecondaryKey -eq $CurrentValues.SecondaryKey
            if ($secondaryKeyTestResult -eq $false) {
                return $true
            }
        }

        return $false
    }

    [void] Set() {
        Write-Verbose -Message ("Retrieving current SBAuthorizationRule values for $($this.Name) on namespace " +
                                "$($this.NamespaceName).")
        $currentValues = $this.Get()

        Write-Verbose -Message ("Checking if SBAuthorizationRule $($this.Name) on namespace " +
                                "$($this.NamespaceName) should be created.")
        if ($this.SBAuthorizationRuleShouldBeCreated($currentValues)) {
            Write-Verbose -Message ("Creating SBAuthorizationRule with Name $($this.Name) on namespace " +
                                    "$($this.NamespaceName)")
            $this.NewSBAuthorizationRule()
            return
        }

        Write-Verbose -Message ("Checking if SBAuthorizationRule $($this.Name) on namespace " +
                                "$($this.NamespaceName) should be removed.")
        if ($this.SBAuthorizationRuleShouldBeRemoved($currentValues)) {
            Write-Verbose -Message ("Removing SBAuthorizationRule with Name $($this.Name) on namespace " +
                                    "$($this.NamespaceName).")
            $this.RemoveSBAuthorizationRule()
            return
        }

        Write-Verbose -Message ("Checking if SBAuthorizationRule $($this.Name) on namespace " +
                                "$($this.NamespaceName) should be updated.")
        if ($this.SBAuthorizationRuleShouldBeUpdated($currentValues)) {
            Write-Verbose -Message ("Updating SBAuthorizationRule with Name $($this.Name) on namespace " +
                                    "$($this.NamespaceName).")
            $this.SetSBAuthorizationRule()
            return
        }
    }

    [void] NewSBAuthorizationRule() {
        Write-Verbose -Message "Getting configurable properties as hashtable for New-SBAuthorizationRule params"
        $newSBAuthorizationRuleParams = $this.GetDscConfigurablePropertiesAsHashtable()

        Write-Verbose -Message "Checking for PrimaryKey"
        if ($null -eq $this.PrimaryKey) {
            Write-Verbose -Message "PrimaryKey is absent, removing from New-SBAuthorizationRule params"
            $newSBAuthorizationRuleParams.Remove("PrimaryKey")
        }

        Write-Verbose -Message "Checking for Rights"
        if ($null -eq $this.Rights) {
            Write-Verbose -Message "Rights is absent, removing from New-SBAuthorizationRule params"
            $newSBAuthorizationRuleParams.Remove("Rights")
        }

        Write-Verbose -Message "Checking for SecondaryKey"
        if ($null -eq $this.SecondaryKey) {
            Write-Verbose -Message "SecondaryKey is absent, removing from New-SBAuthorizationRule params"
            $newSBAuthorizationRuleParams.Remove("SecondaryKey")
        }

        Write-Verbose -Message "Removing unnecessary parameters from New-SBAuthorizationRule params"
        $newSBAuthorizationRuleParams.Remove("Ensure")

        Write-Verbose -Message "Invoking New-SBAuthorizationRule with configurable params"
        New-SBAuthorizationRule @newSBAuthorizationRuleParams
    }

    [void] RemoveSBAuthorizationRule() {
        Write-Verbose -Message "Invoking Remove-SBAuthorizationRule with configurable params"
        Remove-SBAuthorizationRule -Name $this.Name -NamespaceName $this.NamespaceName
    }

    [void] SetSBAuthorizationRule() {
        Write-Verbose -Message "Getting configurable properties as hashtable for Set-SBAuthorizationRule params"
        $setSBAuthorizationRuleParams = $this.GetDscConfigurablePropertiesAsHashtable()

        Write-Verbose -Message "Checking for PrimaryKey"
        if ($null -eq $this.PrimaryKey) {
            Write-Verbose -Message "PrimaryKey is absent, removing from Set-SBAuthorizationRule params"
            $setSBAuthorizationRuleParams.Remove("PrimaryKey")
        }

        Write-Verbose -Message "Checking for Rights"
        if ($null -eq $this.Rights) {
            Write-Verbose -Message "Rights is absent, removing from Set-SBAuthorizationRule params"
            $setSBAuthorizationRuleParams.Remove("Rights")
        }

        Write-Verbose -Message "Checking for SecondaryKey"
        if ($null -eq $this.SecondaryKey) {
            Write-Verbose -Message "SecondaryKey is absent, removing from Set-SBAuthorizationRule params"
            $setSBAuthorizationRuleParams.Remove("SecondaryKey")
        }

        Write-Verbose -Message "Removing unnecessary parameters from Set-SBAuthorizationRule params"
        $setSBAuthorizationRuleParams.Remove("Ensure")

        Write-Verbose -Message "Invoking Set-SBAuthorizationRule with configurable params"
        Set-SBAuthorizationRule @setSBAuthorizationRuleParams
    }
}
