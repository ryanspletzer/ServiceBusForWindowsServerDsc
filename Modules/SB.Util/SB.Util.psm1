<#
    .SYNOPSIS
        Tests if a given object contains a property.

    .PARAMETER Object
        Object to test.

    .PARAMETER PropertyName
        The name of the property to check.

    .EXAMPLE
        $object = [pscustomobject] @{
            TestProperty = "TestValue"
        }
        Test-SBDscObjectHasProperty -Object $object -PropertyName 'TestProperty'
#>
function Test-SBDscObjectHasProperty
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true,Position=1)]
        [object]
        $Object,

        [parameter(Mandatory = $true,Position=2)]
        [string]
        $PropertyName
    )

    if (([bool]($Object.PSobject.Properties.name -contains $PropertyName)) -eq $true)
    {
        if ($null -ne $Object.$PropertyName)
        {
            return $true
        }
    }
    return $false
}

<#
    .SYNOPSIS
        Compares a set of current values with desired values based on named keys to check.

    .PARAMETER CurrentValues
        A hashtable of current values.

    .PARAMETER DesiredValues
        A hashtable of desired values or a CimInstance object.

    .PARAMETER ValuesToCheck
        An array of key names to check between the current and desired values.

    .EXAMPLE
        $params = @{
            CurrentValues = @{
                Key1 = "value1"
                Key2 = "value2"
            }
            DesiredValues = = @{
                Key1 = "value1"
                Key2 = "value3"
            }
            ValuesToCheck = @(
                "Key1"
            )
        }
        # returns true
        Test-SBParameterState @params

    .EXAMPLE
        $params = @{
            CurrentValues = @{
                Key1 = "value1"
                Key2 = "value2"
            }
            DesiredValues = = @{
                Key1 = "value1"
                Key2 = "value3"
            }
        }
        # returns false
        Test-SBParameterState @params

    .EXAMPLE
        $cimInstance = Get-CimInstance -ClassName WIN32_ComputerSystem
        $params = @{
            CurrentValues = @{
                Domain = "contoso.com"
            }
            DesiredValues = $cimInstance
        }
        # returns true if $cimInstance.Domain is 'contoso.com'
        Test-SBParameterState @params
#>
function Test-SBParameterState()
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [parameter(Mandatory = $true, Position=1)]
        [hashtable]
        $CurrentValues,

        [parameter(Mandatory = $true, Position=2)]
        [object]
        $DesiredValues,

        [parameter(Mandatory = $false, Position=3)]
        [array]
        $ValuesToCheck
    )

    $returnValue = $true

    if (($DesiredValues.GetType().Name -ne "HashTable") `
        -and ($DesiredValues.GetType().Name -ne "CimInstance") `
        -and ($DesiredValues.GetType().Name -ne "PSBoundParametersDictionary"))
    {
        throw ("Property 'DesiredValues' in Test-SBParameterState must be either a " + `
               "Hashtable or CimInstance. Type detected was $($DesiredValues.GetType().Name)")
    }

    if (($DesiredValues.GetType().Name -eq "CimInstance") -and ($null -eq $ValuesToCheck))
    {
        throw ("If 'DesiredValues' is a Hashtable then property 'ValuesToCheck' must contain " + `
               "a value")
    }

    if (($null -eq $ValuesToCheck) -or ($ValuesToCheck.Count -lt 1))
    {
        $KeyList = $DesiredValues.Keys
    }
    else
    {
        $KeyList = $ValuesToCheck
    }

    $KeyList | ForEach-Object -Process {
        if ($_ -ne "Verbose")
        {
            if (($CurrentValues.ContainsKey($_) -eq $false) `
            -or ($CurrentValues.$_ -ne $DesiredValues.$_) `
            -or (($DesiredValues.ContainsKey($_) -eq $true) -and ($DesiredValues.$_.GetType().IsArray)))
            {
                if ($DesiredValues.GetType().Name -eq "HashTable" -or `
                    $DesiredValues.GetType().Name -eq "PSBoundParametersDictionary")
                {

                    $CheckDesiredValue = $DesiredValues.ContainsKey($_)
                }
                else
                {
                    $CheckDesiredValue = Test-SBDscObjectHasProperty $DesiredValues $_
                }

                if ($CheckDesiredValue)
                {
                    $desiredType = $DesiredValues.$_.GetType()
                    $fieldName = $_
                    if ($desiredType.IsArray -eq $true)
                    {
                        if (($CurrentValues.ContainsKey($fieldName) -eq $false) `
                        -or ($null -eq $CurrentValues.$fieldName))
                        {
                            Write-Verbose -Message ("Expected to find an array value for " + `
                                                    "property $fieldName in the current " + `
                                                    "values, but it was either not present or " + `
                                                    "was null. This has caused the test method " + `
                                                    "to return false.")
                            $returnValue = $false
                        }
                        else
                        {
                            $arrayCompare = Compare-Object -ReferenceObject $CurrentValues.$fieldName `
                                                           -DifferenceObject $DesiredValues.$fieldName
                            if ($null -ne $arrayCompare)
                            {
                                Write-Verbose -Message ("Found an array for property $fieldName " + `
                                                        "in the current values, but this array " + `
                                                        "does not match the desired state. " + `
                                                        "Details of the changes are below.")
                                $arrayCompare | ForEach-Object -Process {
                                    Write-Verbose -Message "$($_.InputObject) - $($_.SideIndicator)"
                                }
                                $returnValue = $false
                            }
                        }
                    }
                    else
                    {
                        switch ($desiredType.Name)
                        {
                            "String" {
                                if ([string]::IsNullOrEmpty($CurrentValues.$fieldName) `
                                -and [string]::IsNullOrEmpty($DesiredValues.$fieldName))
                                {}
                                else
                                {
                                    Write-Verbose -Message ("String value for property " + `
                                                            "$fieldName does not match. " + `
                                                            "Current state is " + `
                                                            "'$($CurrentValues.$fieldName)' " + `
                                                            "and desired state is " + `
                                                            "'$($DesiredValues.$fieldName)'")
                                    $returnValue = $false
                                }
                            }
                            "Int32" {
                                if (($DesiredValues.$fieldName -eq 0) `
                                -and ($null -eq $CurrentValues.$fieldName))
                                {}
                                else
                                {
                                    Write-Verbose -Message ("Int32 value for property " + `
                                                            "$fieldName does not match. " + `
                                                            "Current state is " + `
                                                            "'$($CurrentValues.$fieldName)' " + `
                                                            "and desired state is " + `
                                                            "'$($DesiredValues.$fieldName)'")
                                    $returnValue = $false
                                }
                            }
                            "Int16" {
                                if (($DesiredValues.$fieldName -eq 0) `
                                -and ($null -eq $CurrentValues.$fieldName))
                                {}
                                else
                                {
                                    Write-Verbose -Message ("Int16 value for property " + `
                                                            "$fieldName does not match. " + `
                                                            "Current state is " + `
                                                            "'$($CurrentValues.$fieldName)' " + `
                                                            "and desired state is " + `
                                                            "'$($DesiredValues.$fieldName)'")
                                    $returnValue = $false
                                }
                            }
                            default {
                                Write-Verbose -Message ("Unable to compare property $fieldName " + `
                                                        "as the type ($($desiredType.Name)) is " + `
                                                        "not handled by the " + `
                                                        "Test-SBParameterState cmdlet")
                                $returnValue = $false
                            }
                        }
                    }
                }
            }
        }
    }
    return $returnValue
}

<#
    .SYNOPSIS
        Converts a secure string to plaintext.

    .PARAMETER SecureString
        SecureString object

    .EXAMPLE
        $secureString = ConvertTo-SecureString -String "string" -AsPlainText -Force
        ConvertTo-PlainText -SecureString $secureString
#>
function ConvertTo-PlainText
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $true)]
        [securestring]
        $SecureString
    )
    process
    {
        $BTSR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BTSR)
    }
}

<#
    .SYNOPSIS
        Creates a new SQL connection string from the inputs.

    .PARAMETER DataSource
        The SQL server / instance name.

    .PARAMETER InitialCatalog
        The SQL database name.

    .PARAMETER IntegratedSecurity
        Type of security for the SQL connection string.

    .PARAMETER Credential
        Username and password for the connection string. Not needed if IntegratedSecurity is True or SSPI.

    .PARAMETER Encrypt
        Indicates whether the connection string will be set up to use SSL/TLS.

    .EXAMPLE
        $params = @{
            DataSource         = 'SQL01.contoso.com'
            InitialCatalog     = 'MyDatabase'
            IntegratedSecurity = 'SSPI'
        }
        # returns 'Data Source=SQL01.contoso.com;Intial Catalog=MyDatabase;IntegratedSecurity=SSPI'
        New-SqlConnectionString @params

    .EXAMPLE
        $credential = Get-Credential
        $params = @{
            DataSource         = 'SQL01.contoso.com'
            InitialCatalog     = 'MyDatabase'
            IntegratedSecurity = 'False'
            Credential         = $credential
            Encrypt            = $true
        }
        # returns 'Data Source=SQL01.contoso.com;Intial Catalog=MyDatabase;IntegratedSecurity=SSPI;`" +`
        #         'User Name=<username>;Password=<password>'
        New-SqlConnectionString @params
#>
function New-SqlConnectionString
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $DataSource,

        [Parameter(Mandatory = $true)]
        [string]
        $InitialCatalog,

        [Parameter(Mandatory = $true)]
        [ValidateSet('True','False','SSPI')]
        $IntegratedSecurity,

        [Parameter()]
        [pscredential]
        $Credential,

        [Parameter()]
        [switch]
        $Encrypt
    )
    process
    {
        $sqlConnectionStringBuilder = New-Object -TypeName System.Data.Common.DbConnectionStringBuilder
        $sqlConnectionStringBuilder["Data Source"] = $DataSource
        $sqlConnectionStringBuilder["Initial Catalog"] = $InitialCatalog
        $sqlConnectionStringBuilder["Integrated Security"] = 'False'
        switch ($IntegratedSecurity)
        {
            'True' { $sqlConnectionStringBuilder["Integrated Security"] = 'True' }
            'False' { $sqlConnectionStringBuilder["Integrated Security"] = 'False' }
            'SSPI' { $sqlConnectionStringBuilder['Integrated Security'] = 'SSPI' }
        }
        if ($Credential)
        {
            $sqlConnectionStringBuilder.UserID = $Credential.UserName
            $sqlConnectionStringBuilder.Password = (ConvertTo-PlainText -SecureString $Credential.Password)
        }
        $sqlConnectionStringBuilder.Encrypt = $false
        if ($Encrypt.IsPresent)
        {
            $sqlConnectionStringBuilder.Encrypt = $true
        }
        $connectionString = $sqlConnectionStringBuilder.ConnectionString
        if ($IntegratedSecurity -eq 'SSPI')
        {
            $connectionString = $connectionString.Replace('Integrated Security=True','Integrated Security=SSPI')
        }
        return $sqlConnectionStringBuilder.ConnectionString.Replace("UserID","User Id")
    }
}

<#
    .SYNOPSIS
        Retrieves a given property value from a SQL connection string.

    .PARAMETER SqlConnectionString
        A SQL connection string.

    .PARAMETER PropertyName
        The property name whose value to retrieve.

    .EXAMPLE
        $connectionString = "Data Source=SQL1;Initial Catalog=MyDatabase;Integrated Security=SSPI"
        # returns SQL1
        Get-SqlConnectionStringPropertyValue -SqlConnectionString $connectionString -PropertyName "Data Source"
#>
function Get-SqlConnectionStringPropertyValue
{
    [CmdletBinding()]
    [OutputType([object])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $SqlConnectionString,

        [Parameter(Mandatory = $true)]
        [string]
        $PropertyName
    )
    process
    {
        $params = @{
            TypeName     = 'System.Data.SqlClient.SqlConnectionStringBuilder'
            ArgumentList = $SqlConnectionString
        }
        $sqlConnectionStringBuilder = New-Object @params
        if ($PropertyName -eq 'Integrated Security' -and
            $SqlConnectionString.Contains('Integrated Security=SSPI'))
        {
            return 'SSPI'
        }
        return $sqlConnectionStringBuilder[$PropertyName]
    }
}

<#
    .SYNOPSIS
        Compares two secure strings, returns true if they are the same, false otherwise.

    .PARAMETER ReferenceSecureString
        The first secure string.

    .PARAMETER DifferenceSecureString
        The second secure string to compare to.

    .EXAMPLE
        $secureString1 = ConvertTo-SecureString -String "string1" -AsPlainText -Force
        $secureString2 = ConvertTo-SecureString -String "string2" -AsPlainText -Force
        # returns false
        Compare-SecureString -ReferenceSecureString $secureString1 -DifferenceSecureString $secureString2
#>
function Compare-SecureString
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory = $true)]
        [securestring]
        $ReferenceSecureString,

        [Parameter(Mandatory = $true)]
        [securestring]
        $DifferenceSecureString
    )
    process
    {
        return ((ConvertTo-PlainText -SecureString $ReferenceSecureString) -eq
                (ConvertTo-PlainText -SecureString $DifferenceSecureString))
    }
}

<#
    .SYNOPSIS
        Gets the account name without the domain prefix or suffix.

    .PARAMETER FullAccountNameWithDomain
        An account in the format CORP\account or account@contoso.com

    .EXAMPLE
        # returns 'account'
        Get-AccountName -FullAccountNameWithDomain 'CORP\account'
#>
function Get-AccountName
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $FullAccountNameWithDomain
    )
    process
    {
        if (($FullAccountNameWithDomain.IndexOf('\')) -gt 0)
        {
            $array = $FullAccountNameWithDomain.Split('\', [System.StringSplitOptions]::RemoveEmptyEntries)
            if ($null -ne $array -and $array.Length -gt 0)
            {
                return $array[1]
            }
        }
        else
        {
            $array = $FullAccountNameWithDomain.Split('@', [System.StringSplitOptions]::RemoveEmptyEntries)
            if ($null -ne $array -and $array.Length -gt 0)
            {
                return $array[0]
            }
        }
    }
}

<#
    .SYNOPSIS
        Retrieves the domain name from a full account name.

    .PARAMETER FullAccountWithDomain
        An account in the format CORP\account or account@contoso.com

    .EXAMPLE
        # returns 'CORP'
        Get-AccountDomainName -FullAccountNameWithDomain 'CORP\account'
#>
function Get-AccountDomainName
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $FullAccountNameWithDomain
    )
    process
    {
        if (($FullAccountNameWithDomain.IndexOf('\')) -gt 0)
        {
            $array = $FullAccountNameWithDomain.Split('\', [System.StringSplitOptions]::RemoveEmptyEntries)
            if ($null -ne $array -and $array.Length -gt 0)
            {
                if ($array.Length -eq 2)
                {
                    return $array[0]
                }
            }
        }
        else
        {
            $array = $FullAccountNameWithDomain.Split('@', [System.StringSplitOptions]::RemoveEmptyEntries)
            if ($null -ne $array -and $array.Length -gt 0)
            {
                if ($array.Length -eq 2)
                {
                    return $array[1]
                }
            }
        }
    }
}

<#
    .SYNOPSIS
        Gets the distinguished name for a domain.

    .PARAMETER DomainName
        A domain name like CONTOSO

    .EXAMPLE
        # returns ex. 'DC=contoso,DC=com'
        Get-DistinguishedNameForDomain -DomainName 'CONTOSO'
#>
function Get-DistinguishedNameForDomain
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $DomainName
    )
    process
    {
        return ([adsi]"LDAP://$domainName").distinguishedName
    }
}

<#
    .SYNOPSIS
        Fully qualifies a domain name

    .PARAMETER DomainName
        The domain name like CONTOSO

    .EXAMPLE
        # returns ex. contoso.com
        Get-FullyQualifiedDomainName -DomainName "CONTOSO"
#>
function Get-FullyQualifiedDomainName
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $DomainName
    )
    process
    {
        $distinguishedName = Get-DistinguishedNameForDomain -DomainName $DomainName
        $resultArray = @()
        $componentArray = $distinguishedName.Split(',',
                                                   [System.StringSplitOptions]::RemoveEmptyEntries)
        foreach ($component in $componentArray)
        {
            $componentKeyValuePairArray = $component.Split('=',
                                                           [System.StringSplitOptions]::RemoveEmptyEntries)
            if ($componentKeyValuePairArray.Length -eq 2 -and
                [string]::Equals($componentKeyValuePairArray[0],
                                 'DC',
                                 [System.StringComparison]::OrdinalIgnoreCase))
            {
                $resultArray += $componentKeyValuePairArray[1]
            }
        }
        return ($resultArray -join '.')
    }
}

<#
    .SYNOPSIS
        Gets the NetBIOS format of a domain name

    .PARAMETER DomainName
        The domain name like contoso.com

    .EXAMPLE
        # returns ex. 'CONTOSO'
        Get-NetBIOSDomainName -DomainName 'contoso.com'
#>
function Get-NetBIOSDomainName
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $DomainName
    )
    process
    {
        return ([adsi]"LDAP://$domainName").name.ToUpper()
    }
}

<#
    .SYNOPSIS
        Formats an account to a given format.

    .PARAMETER FullAccountNameWithDomain
        Full account with domain name e.g. CORP\account or account@contoso.com

    .PARAMETER Format
        The format to take the account to.

    .EXAMPLE
        # returns ex. account@contoso.com
        Format-AccountName -FullAccountNameWithDomain 'CONTOSO\account' -Format 'UserLogonName'
#>
function Format-AccountName
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $FullAccountNameWithDomain,

        [Parameter(Mandatory = $true)]
        [ValidateSet('UserLogonName',
                     'UserLogonNamePreWindows2000')]
        [string]
        $Format
    )
    process
    {
        if ($Format -eq 'UserLogonName')
        {
            $stringFormat = '{0}@{1}'
            $accountName = Get-AccountName -FullAccountNameWithDomain $FullAccountNameWithDomain
            $domainName = Get-AccountDomainName -FullAccountNameWithDomain $FullAccountNameWithDomain
            $fullyQualifiedDomainName = Get-FullyQualifiedDomainName -DomainName $domainName
            return ([string]::Format($stringFormat, $accountName, $fullyQualifiedDomainName))
        }
        if ($Format -eq 'UserLogonNamePreWindows2000')
        {
            $stringFormat = '{0}\{1}'
            $accountName = Get-AccountName -FullAccountNameWithDomain $FullAccountNameWithDomain
            $domainName = Get-AccountDomainName -FullAccountNameWithDomain $FullAccountNameWithDomain
            $netBIOSDomainName = Get-NetBIOSDomainName -DomainName $domainName
            return ([string]::Format($stringFormat, $netBIOSDomainName, $accountName))
        }
    }
}

<#
    .SYNOPSIS
        Compares two account names regardless of their formatting

    .PARAMETER ReferenceAccountNameWithDomain
        Reference account e.g. 'CONTOSO\account'

    .PARAMETER DifferenceAccountNameWithDomain
        Difference account e.g. 'account@contoso.com'

    .EXAMPLE
        # returns true
        Compare-AccountName -ReferenceAccountWithDomain 'CONTOSO\account'`
                            -DifferenceAccountWithDomain 'account@contoso.com
#>
function Compare-AccountName
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $ReferenceAccountNameWithDomain,

        [Parameter(Mandatory = $true)]
        [string]
        $DifferenceAccountNameWithDomain
    )
    process
    {
        $reference = (Format-AccountName -FullAccountNameWithDomain $ReferenceAccountNameWithDomain -Format UserLogonNamePreWindows2000).ToLower()
        $difference = (Format-AccountName -FullAccountNameWithDomain $DifferenceAccountNameWithDomain -Format UserLogonNamePreWindows2000).ToLower()
        return ($reference -eq $difference)
    }
}

Export-ModuleMember -Function *
