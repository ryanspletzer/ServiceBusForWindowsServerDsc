#
# xServiceBusForWindowsServer.Util.psm1
#
# Credit to SharePointDsc Resource module for nested Util approach and ideas for helper cmdlets in this file:
#
# https://github.com/PowerShell/SharePointDsc/blob/dev/Modules/SharePointDsc/Modules/SharePointDsc.Util/SharePointDsc.Util.psm1
#


function Test-cSBWSObjectHasProperty() {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true,Position=1)]  [Object] $Object,
        [parameter(Mandatory = $true,Position=2)]  [String] $PropertyName
    )
    if (([bool]($Object.PSobject.Properties.name -contains $PropertyName)) -eq $true) {
        if ($null -ne $Object.$PropertyName) {
            return $true
        }
    }
    return $false
}


function Test-cSBWSParameterState() {
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true, Position=1)]
        [HashTable]
        $CurrentValues,

        [parameter(Mandatory = $true, Position=2)]
        [Object]
        $DesiredValues,

        [parameter(Mandatory = $false, Position=3)]
        [Array]
        $ValuesToCheck
    )

    $returnValue = $true

    if (($DesiredValues.GetType().Name -ne "HashTable") `
        -and ($DesiredValues.GetType().Name -ne "CimInstance") `
        -and ($DesiredValues.GetType().Name -ne "PSBoundParametersDictionary"))
    {
        throw ("Property 'DesiredValues' in Test-SPDscParameterState must be either a " + `
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
                    $CheckDesiredValue = Test-SPDSCObjectHasProperty $DesiredValues $_
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
                                                        "Test-SPDscParameterState cmdlet")
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


function ConvertTo-PlainText {
    <#
    .SYNOPSIS

    .DESCRIPTION

    .INPUTS

    .OUTPUTS

    .EXAMPLE

    .LINK

    .NOTES

    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [securestring]
        $SecureString
    )
    process {
        $BTSR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BTSR)
    }
}


function New-SqlConnectionString {
    <#
    .SYNOPSIS

    .DESCRIPTION

    .INPUTS

    .OUTPUTS

    .EXAMPLE

    .LINK

    .NOTES
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]
        $DataSource,

        [Parameter(Mandatory)]
        [string]
        $InitialCatalog,

        [Parameter(Mandatory)]
        [ValidateSet('True','False','SSPI')]
        $IntegratedSecurity,

        [Parameter()]
        [pscredential]
        $Credential,

        [Parameter()]
        [switch]
        $Encrypt
    )
    process {
        $sqlConnectionStringBuilder = New-Object -TypeName System.Data.Common.DbConnectionStringBuilder
        $sqlConnectionStringBuilder["Data Source"] = $DataSource
        $sqlConnectionStringBuilder["Initial Catalog"] = $InitialCatalog
        $sqlConnectionStringBuilder["Integrated Security"] = 'False'
        switch ($IntegratedSecurity) {
            'True' { $sqlConnectionStringBuilder["Integrated Security"] = 'True' }
            'False' { $sqlConnectionStringBuilder["Integrated Security"] = 'False' }
            'SSPI' { $sqlConnectionStringBuilder['Integrated Security'] = 'SSPI' }
        }
        if ($Credential) {
            $sqlConnectionStringBuilder.UserID = $Credential.UserName
            $sqlConnectionStringBuilder.Password = (ConvertTo-PlainText -SecureString $Credential.Password)
        }
        $sqlConnectionStringBuilder.Encrypt = $false
        if ($Encrypt.IsPresent) {
            $sqlConnectionStringBuilder.Encrypt = $true
        }
        $connectionString = $sqlConnectionStringBuilder.ConnectionString
        if ($IntegratedSecurity -eq 'SSPI') {
            $connectionString = $connectionString.Replace('Integrated Security=True','Integrated Security=SSPI')
        }
        return $sqlConnectionStringBuilder.ConnectionString.Replace("UserID","User Id")
    }
}


function Get-SqlConnectionStringPropertyValue {
    <#
    .SYNOPSIS

    .DESCRIPTION

    .INPUTS

    .OUTPUTS

    .EXAMPLE

    .LINK

    .NOTES
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory)]
        [string]
        $SqlConnectionString,

        [Parameter(Mandatory)]
        [string]
        $PropertyName
    )
    process {
        $params = @{
            TypeName     = 'System.Data.SqlClient.SqlConnectionStringBuilder'
            ArgumentList = $SqlConnectionString
        }
        $sqlConnectionStringBuilder = New-Object @params
        if ($PropertyName -eq 'Integrated Security' -and
            $SqlConnectionString.Contains('Integrated Security=SSPI')) {
            return 'SSPI'
        }
        return $sqlConnectionStringBuilder[$PropertyName]
    }
}


function Compare-SecureStrings {
    <#
    .SYNOPSIS

    .DESCRIPTION

    .INPUTS

    .OUTPUTS

    .EXAMPLE

    .LINK

    .NOTES

    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [securestring]
        $ReferenceSecureString,

        [Parameter(Mandatory)]
        [securestring]
        $DifferenceSecureString
    )
    process {
        return ((ConvertTo-PlainText -SecureString $ReferenceSecureString) -eq
                (ConvertTo-PlainText -SecureString $DifferenceSecureString))
    }
}


Export-ModuleMember -Function *
