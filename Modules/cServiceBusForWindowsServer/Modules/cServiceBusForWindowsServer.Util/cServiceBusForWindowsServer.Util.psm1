#
# xServiceBusForWindowsServer.Util.psm1
#
# Credit to xSharePoint DSC Resource module for nested Util approach and ideas for helper cmdlets in this file:
#
# https://github.com/PowerShell/xSharePoint/blob/dev/Modules/xSharePoint/Modules/xSharePoint.Util/xSharePoint.Util.psm1
#


function Test-cServiceBusForWindowsServerSpecificParameters() {
    <#
    .SYNOPSIS
        Removes a user from local administrators.

    .DESCRIPTION
        Removes a user from local administrators.

    .PARAMETER CurrentValues
        A HashTable of actual values.

    .PARAMETER DesiredValues
        A HashTable of desired values.

    .PARAMETER ValuesToCheck
        An array of values to check.

    .INPUTS

    .OUTPUTS

    .EXAMPLE
        Example of how to run the script

    .LINK
        Links to further documentation

    .NOTES
        Detail on what the script does, if this is needed

    #>
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true,
                   Position=1)]
        [hashTable]
        $CurrentValues,

        [parameter(Mandatory=$true,
                   Position=2)]
        [hashTable]
        $DesiredValues,

        [parameter(Mandatory=$false,
                   Position=3)]
        [array]
        $ValuesToCheck
    )

    begin {
        $returnValue = $true

        $CurrentValues.Keys | %{Write-Debug -Message "Current $_ : $($CurrentValues.$_)"}

        $DesiredValues.Keys | %{Write-Debug -Message "Desired $_ : $($DesiredValues.$_)"}

        if (($ValuesToCheck -eq $null) -or ($ValuesToCheck.Count -lt 1)) {
            $KeyList = $DesiredValues.Keys
        } else {
            $KeyList = $ValuesToCheck
        }
    }

    process {
        $KeyList | ForEach-Object {
            if ($_ -ne "Verbose") {
                if (($CurrentValues.ContainsKey($_) -eq $false) -or
                    ($CurrentValues.$_ -ne $DesiredValues.$_)) {
                    if ($DesiredValues.ContainsKey($_)) {
                        $desiredType = $DesiredValues.$_.GetType()
                        $fieldName = $_
                        Write-Debug -Message "CurrentValues $fieldName : $($CurrentValues.$fieldName)"
                        Write-Debug -Message "DesiredValues $fieldName : $($DesiredValues.$fieldName)"
                        switch ($desiredType.Name) {
                            "String" {
                                if ([string]::IsNullOrEmpty($CurrentValues.$fieldName) -and
                                    [string]::IsNullOrEmpty($DesiredValues.$fieldName)) {
                                    } else {
                                    $returnValue = $false
                                }
                            }
                            "Int32" {
                                if (($DesiredValues.$fieldName -eq 0) -and
                                    ($CurrentValues.$fieldName -eq $null)) {
                                    } else {
                                    $returnValue = $false
                                }
                            }
                            default {
                                $returnValue = $false
                            }
                        }
                    }
                }
            }

        }
        Write-Debug -Message "Test ReturnValue = $returnValue"
        return $returnValue
    }
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
        $ComparisonSecureString
    )
    process {
        return ((ConvertTo-PlainText -SecureString $ReferenceSecureString) -eq
                (ConvertTo-PlainText -SecureString $ComparisonSecureString))
    }
}


Export-ModuleMember -Function *
