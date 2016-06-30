[CmdletBinding()]
param(
    [string]
    $ServiceBusCmdletModule = (Join-Path -Path $PSScriptRoot -ChildPath "..\Stubs\ServiceBus\2.0.40512.2\Microsoft.ServiceBus.Commands.psm1" -Resolve)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path -Path $PSScriptRoot\..\..).Path
$Global:CurrentServiceBusStubModule = $ServiceBusCmdletModule

$ModuleName = "cServiceBusForWindowsServer"
Import-Module -Name (Join-Path -Path $RepoRoot -ChildPath "Modules\cServiceBusForWindowsServer\$ModuleName.psm1")

Describe 'cSBBase' {
    InModuleScope $ModuleName {
        # Arrange
        $testSBFarmCreation = [cSBFarmCreation]::new()
        $adminApiCredentialParams = @{
            TypeName     = pscredential
            ArgumentList = @(
                "adminUser",
                (ConvertTo-SecureString -String "password" -AsPlainText -Force)
            )
        }
        $testSBFarmCreation.AdminApiCredentials = New-Object @adminApiCredentialParams
        $testSBFarmCreation.EncryptionCertificateThumbprint = '62C99D4B5711E2482A5A1AECE6F8D05231D5678D'
        $testSBFarmCreation.FarmCertificateThumbprint = '62C99D4B5711E2482A5A1AECE6F8D05231D5678D'
        $testSBFarmCreation.FarmDNS = 'servicebus.contoso.com'
        $testSBFarmCreation.RunAsAccount = "servicebus@contoso"
        $testSBFarmCreation.SBFarmDBConnectionStringDataSource = 'SQLSERVER'
        $tenantApiCredentialParams = @{
            TypeName     = pscredential
            ArgumentList = @(
                "tenantUser",
                (ConvertTo-SecureString -String "password" -AsPlainText -Force)
            )
        }
        $testSBFarmCreation.TenantApiCredentials = New-Object @tenantApiCredentialParams

        Context 'Base methods' {
            It 'ToHashtable() returns class properties as a hashtable' {
                # Arrange
                $ht = $testSBFarmCreation.ToHashtable()
                $propertyCount = 0

                # Act
                Get-Member -InputObject $testSBFarmCreation |
                    Where-Object MemberType -eq 'Property' |
                    ForEach-Object {
                        # Assert
                        $ht[$_.Name] | Should BeExactly $testSBFarmCreation.($_.Name)
                        $propertyCount += 1
                    }

                # Assert
                $ht.Keys.Count | Should BeExactly $propertyCount
            }

            It 'GetProperty() returns property value' {
                # Act | Assert
                $testSBFarmCreation.GetProperty('RunAsAccount') | Should BeExactly 'servicebus@contoso.com'
            }

            It 'SetProperty() sets property value' {
                # Act
                $testSBFarmCreation.SetProperty('RunAsAccount','servicebus2@contoso.com')
                $value = [string]$testSBFarmCreation.RunAsAccount

                # Assert
                $value | Should BeExactly 'servicebus2@contoso.com'

                # Undo
                $testSBFarmCreation.RunAsAccount = 'servicebus@contoso.com'
            }

            It 'GetDscNotConfigurablePropertiesAsHashtable() returns not configurable properties as a hashtable' {
                # Act
                $ht = $testSBFarmCreation.GetDscNonConfigurablePropertiesAsHashtable()

                # Assert
                $ht.Count | Should BeExactly 9
            }

            It 'GetDscConfigurablePropertiesAsHashtable() returns configurable properties as a hashtable' {
                # Act
                $ht = $testSBFarmCreation.GetDscConfigurablePropertiesAsHashtble()

                # Assert
                $ht.Count | Should BeExactly 30
            }
        }
    }
}