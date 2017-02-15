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
    SBBase is the base Service Bus for Windows Server resource class that provides commonly used methods.
#>
class SBBase {
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
