[CmdletBinding()]
param(
    [string]
    $ServiceBusCmdletModule = (Join-Path -Path $PSScriptRoot -ChildPath "..\Stubs\ServiceBus\2.0.40512.2\Microsoft.ServiceBus.Commands.psm1" -Resolve)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path -Path $PSScriptRoot\..\..\..).Path
$Global:CurrentServiceBusStubModule = $ServiceBusCmdletModule

$ModuleName = "cServiceBusForWindowsServer"
Import-Module -Name (Join-Path -Path $RepoRoot -ChildPath "Modules\cServiceBusForWindowsServer\$ModuleName.psm1")

Describe 'cSBBase' {
    InModuleScope $ModuleName {
        # Arrange
        $testSBFarm = [cSBFarm]::new()
        $adminApiCredentialParams = @{
            TypeName     = 'System.Management.Automation.PSCredential'
            ArgumentList = @(
                "adminUser",
                (ConvertTo-SecureString -String "password" -AsPlainText -Force)
            )
        }
        $testSBFarm.AdminApiCredentials = New-Object @adminApiCredentialParams
        $testSBFarm.EncryptionCertificateThumbprint = '62C99D4B5711E2482A5A1AECE6F8D05231D5678D'
        $testSBFarm.FarmCertificateThumbprint = '62C99D4B5711E2482A5A1AECE6F8D05231D5678D'
        $testSBFarm.FarmDNS = 'servicebus.contoso.com'
        $testSBFarm.RunAsAccount = "servicebus@contoso"
        $testSBFarm.SBFarmDBConnectionStringDataSource = 'SQLSERVER.contoso.com'
        $tenantApiCredentialParams = @{
            TypeName     = 'System.Management.Automation.PSCredential'
            ArgumentList = @(
                "tenantUser",
                (ConvertTo-SecureString -String "password" -AsPlainText -Force)
            )
        }
        $testSBFarm.TenantApiCredentials = New-Object @tenantApiCredentialParams

        Context 'Base methods' {
            It 'ToHashtable() returns class properties as a hashtable' {
                # Arrange
                $ht = $testSBFarm.ToHashtable()

                $propertyCount = 0

                # Act
                Get-Member -InputObject $testSBFarm |
                    Where-Object MemberType -eq 'Property' |
                    ForEach-Object {
                        # Assert
                        $ht[$_.Name] | Should BeExactly $testSBFarm.($_.Name)
                        $propertyCount += 1
                    }

                # Assert
                $ht.Keys.Count | Should BeExactly $propertyCount
            }

            It 'GetProperty() returns property value' {
                # Act | Assert
                $testSBFarm.GetProperty('RunAsAccount') | Should BeExactly 'servicebus@contoso'
            }

            It 'SetProperty() sets property value' {
                # Act
                $testSBFarm.SetProperty('RunAsAccount','servicebus2@contoso.com')
                $value = [string]$testSBFarm.RunAsAccount

                # Assert
                $value | Should BeExactly 'servicebus2@contoso.com'

                # Cleanup
                $testSBFarm.RunAsAccount = 'servicebus@contoso.com'
            }

            It 'GetDscNotConfigurablePropertiesAsHashtable() returns not configurable properties as a hashtable' {
                # Act
                $ht = $testSBFarm.GetDscNotConfigurablePropertiesAsHashtable()

                # Assert
                $ht.Count | Should BeExactly 10
            }

            It 'GetDscConfigurablePropertiesAsHashtable() returns configurable properties as a hashtable' {
                # Act
                $ht = $testSBFarm.GetDscConfigurablePropertiesAsHashtable()

                # Assert
                $ht.Count | Should BeExactly 30
            }
        }
    }
}