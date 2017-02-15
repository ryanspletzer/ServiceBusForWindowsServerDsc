using module ..\SBBase

<#
    SBHostCEIP enables or disables Customer Experience Improvement Program telemetry.
#>
[DscResource()]
class SBHostCEIP : SBBase
{

    <#
        Marks whether the Customer Experience Improvement Program telemetry should be Present (enabled) or Absent
        (disabled).
    #>
    [DscProperty(Key)]
    [Ensure]
    $Ensure

    [SBHostCEIP] Get()
    {
        $result = [SBHostCEIP]::new()

        Write-Verbose -Message "Checking for SBHostCEIP status."

        $sbHostCEIP = $null
        try {
            $sbHostCEIP = Get-SBHostCEIP
            Write-Verbose "Successfully retrieved SBHostCEIP status."
        } catch {
            Write-Verbose "Unable to detect SBHostCEIP status."
        }

        if ($null -eq $sbHostCEIP) {
            $result.Ensure = [Ensure]::Absent
            return $result
        }

        if ($sbHostCEIP[0] -like "You have declined to participate in the Customer Experience Improvement Program.") {
            $result.Ensure = [Ensure]::Absent
        }

        if ($sbHostCEIP[0] -like "You have chosen to participate in the Customer Experience Improvement Program.") {
            $result.Ensure = [Ensure]::Present
        }

        return $result
    }

    [bool] Test()
    {
        $currentValues = $this.Get()

        if ($this.SBHostCEIPShouldBeEnabled($currentValues))
        {
            return $false
        }

        if ($this.SBHostCEIPShouldBeDisabled($currentValues))
        {
            return $false
        }

        return $true
    }

    [bool] SBHostCEIPShouldBeEnabled([SBHostCEIP] $CurrentValues)
    {
        return (($this.Ensure -eq [Ensure]::Present) -and ($CurrentValues.Ensure -eq [Ensure]::Absent))
    }

    [bool] SBHostCEIPShouldBeDisabled([SBHostCEIP] $CurrentValues)
    {
        return (($this.Ensure -eq [Ensure]::Absent) -and ($CurrentValues.Ensure -eq [Ensure]::Present))
    }

    [void] Set()
    {
        Write-Verbose -Message "Retrieving current SBHostCEIP status."
        $currentValues = $this.Get()

        Write-Verbose -Message "Checking if SBHostCEIP should be enabled."
        if ($this.SBHostCEIPShouldBeEnabled($currentValues)) {
            Write-Verbose "Enabling SBHostCEIP."
            Enable-SBHostCEIP
        }

        Write-Verbose -Message "Checking if SBHostCEIP should be disabled."
        if ($this.SBHostCEIPShouldBeDisabled($currentValues)) {
            Write-Verbose "Disabling SBHostCEIP."
            Disable-SBHostCEIP
        }
    }
}
