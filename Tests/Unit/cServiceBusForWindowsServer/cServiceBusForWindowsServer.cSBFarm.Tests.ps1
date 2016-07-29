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
Import-Module -Name (Join-Path -Path $RepoRoot -ChildPath "Modules\cServiceBusForWindowsServer\Modules\cServiceBusForWindowsServer.Util\cServiceBusForWindowsServer.Util.psm1")

Describe "cSBFarm" {
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
        $testSBFarm.AdminGroup = 'BUILTIN\Administrators'
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

        Import-Module (Join-Path ((Resolve-Path $PSScriptRoot\..\..\..).Path) "Modules\cServiceBusForWindowsServer")

        Remove-Module -Name "Microsoft.ServiceBus.Commands" -Force -ErrorAction SilentlyContinue
        Import-Module $Global:CurrentServiceBusStubModule -WarningAction SilentlyContinue

        Mock New-SBFarm {}
        Mock Set-SBFarm {}
        Mock Stop-SBFarm {}

        Context "No farm is found or configured" {
            #Arrange
            Mock Get-SBFarm {
                throw ("Cannot validate argument parameter 'SBFarmDBConnectionString'. The " +
                       "database (SBManagementDB) located at SQL Server (SQLSERVER.contoso.com) " +
                       "couldn't be found or is not configured.")
            }
            Mock Get-SBMessageContainer {
                throw ("This host is not joined to any Service Bus farm. to join a " +
                       "farm run Add-SBHost cmdlet.")
            }

            It "returns null from the Get method" {
                # Act | Assert
                $testSBFarm.Get() | Should BeNullOrEmpty
            }

            It "returns false from the Test method" {
                # Act | Assert
                $testSBFarm.Test() | Should Be $false
            }

            It "calls the New-SBFarm cmdlet in the Set method" {
                # Act
                $testSBFarm.Set()

                # Assert
                Assert-MockCalled -CommandName New-SBFarm
            }
        }

        Context "A farm exists and is in valid state" {
            #Arrange
            Mock Get-SBFarm {
                return @{
                    FarmType                      = 'SB'
                    SBFarmDBConnectionString      = 'Data Source=SQLSERVER.contoso.com;Initial Catalog=SBManagementDB;Integrated Security=True;Encrypt=False'
                    ClusterConnectionEndpointPort = 9000
                    ClientConnectionEndpointPort  = 9001
                    LeaseDriverEndpointPort       = 9002
                    ServiceConnectionEndpointPort = 9003
                    RunAsAccount                  = 'servicebus@contoso'
                    AdminGroup                    = 'BUILTIN\Administrators'
                    GatewayDBConnectionString     = 'Data Source=SQLSERVER.contoso.com;Initial Catalog=SBGatewayDB;Integrated Security=True;Encrypt=False'
                    HttpsPort                     = 9355
                    TcpPort                       = 9354
                    MessageBrokerPort             = 9356
                    AmqpsPort                     = 5671
                    AmqpPort                      = 5672
                    FarmCertificate               = @{
                        Thumbprint  = '62C99D4B5711E2482A5A1AECE6F8D05231D5678D'
                        IsGenerated = 'False'
                    }
                    EncryptionCertificate         = @{
                        Thumbprint  = '62C99D4B5711E2482A5A1AECE6F8D05231D5678D'
                        IsGenerated = 'False'
                    }
                    Hosts                         = @(
                        @{
                            Name               = 'servicebus01.contoso.com'
                            ConfigurationState = 'HostConfigurationCompleted'
                        },
                        @{
                            Name               = 'servicebus02.contoso.com'
                            ConfigurationState = 'HostConfigurationCompleted'
                        },
                        @{
                            Name               = 'servicebus03.contoso.com'
                            ConfigurationState = 'HostConfigurationCompleted'
                        }
                    )
                    RPHttpsPort                   = 9359
                    RPHttpsUrl                    = 'https://servicebus.contoso.com:9359/'
                    FarmDNS                       = 'servicebus.contoso.com'
                    AdminApiUserName              = 'adminUser'
                    TenantApiUserName             = 'tenantUser'
                    BrokerExternalUrls            = $null
                }
            }
            Mock Get-SBMessageContainer {
                return @{
                    Id               = 1
                    Status           = 'Active'
                    Host             = 'servicebus01.contoso.com'
                    DatabaseServer   = 'SQLSERVER.contoso.com'
                    DatabaseName     = 'SBMessageContainer01'
                    ConnectionString = 'Data Source=SQLSERVER.contoso.com;Initial Catalog=SBMessageContainer01;Integrated Security=True;Encrypt=False'
                    EntitiesCount    = 1
                    DatabaseSizeInMB = 0
                }
            }

            It "returns current values from the Get method" {
                # Act | Assert
                $testSBFarm.Get() | Should Not BeNullOrEmpty
            }

            It "returns true from the Test method" {
                # Act | Assert
                $testSBFarm.Test() | Should Be $true
            }
        }

        Context "A farm exists and is in invalid state" {
            #Arrange
            Mock Get-SBFarm {
                return @{
                    FarmType                      = 'SB'
                    SBFarmDBConnectionString      = 'Data Source=SQLSERVER.contoso.com;Initial Catalog=SBManagementDB;Integrated Security=True;Encrypt=True'
                    ClusterConnectionEndpointPort = 9000
                    ClientConnectionEndpointPort  = 9001
                    LeaseDriverEndpointPort       = 9002
                    ServiceConnectionEndpointPort = 9003
                    RunAsAccount                  = 'oldservicebus@contoso'
                    AdminGroup                    = 'BUILTIN\Administrators'
                    GatewayDBConnectionString     = 'Data Source=SQLSERVER.contoso.com;Initial Catalog=SBGatewayDB;Integrated Security=True;Encrypt=False'
                    HttpsPort                     = 9355
                    TcpPort                       = 9354
                    MessageBrokerPort             = 9356
                    AmqpsPort                     = 5671
                    AmqpPort                      = 5672
                    FarmCertificate               = @{
                        Thumbprint  = '62C99D4B5711E2482A5A1AECE6F8D05231D5678D'
                        IsGenerated = 'False'
                    }
                    EncryptionCertificate         = @{
                        Thumbprint  = '62C99D4B5711E2482A5A1AECE6F8D05231D5678D'
                        IsGenerated = 'False'
                    }
                    Hosts                         = @(
                        @{
                            Name               = 'servicebus01.contoso.com'
                            ConfigurationState = 'HostConfigurationCompleted'
                        },
                        @{
                            Name               = 'servicebus02.contoso.com'
                            ConfigurationState = 'HostConfigurationCompleted'
                        },
                        @{
                            Name               = 'servicebus03.contoso.com'
                            ConfigurationState = 'HostConfigurationCompleted'
                        }
                    )
                    RPHttpsPort                   = 9359
                    RPHttpsUrl                    = 'https://oldservicebus.contoso.com:9359/'
                    FarmDNS                       = 'oldservicebus.contoso.com'
                    AdminApiUserName              = 'oldAdminUser'
                    TenantApiUserName             = 'oldTenantUser'
                    BrokerExternalUrls            = $null
                }
            }
            Mock Get-SBMessageContainer {
                return @{
                    Id               = 1
                    Status           = 'Active'
                    Host             = 'servicebus01.contoso.com'
                    DatabaseServer   = 'SQLSERVER.contoso.com'
                    DatabaseName     = 'SBMessageContainer01'
                    ConnectionString = 'Data Source=SQLSERVER.contoso.com;Initial Catalog=SBMessageContainer01;Integrated Security=True;Encrypt=False'
                    EntitiesCount    = 1
                    DatabaseSizeInMB = 0
                }
            }

            It "returns current values from the Get method" {
                # Act | Assert
                $testSBFarm.Get() | Should Not BeNullOrEmpty
            }

            It "returns false from the Test method" {
                # Act | Assert
                $testSBFarm.Test() | Should Be $false
            }

            It "calls the Stop-SBFarm cmdlet in the Set method" {
                # Act
                $testSBFarm.Set()

                # Assert
                Assert-MockCalled -CommandName Stop-SBFarm
            }

            It "calls the Set-SBFarm cmdlet in the Set method" {
                # Act
                $testSBFarm.Set()

                # Assert
                Assert-MockCalled -CommandName Set-SBFarm
            }
        }
    }
}
