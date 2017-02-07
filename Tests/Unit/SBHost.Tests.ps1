[CmdletBinding()]
param(
    [string]
    $ServiceBusCmdletModule = (Join-Path -Path $PSScriptRoot -ChildPath "Stubs\ServiceBus\2.0.40512.2\Microsoft.ServiceBus.Commands.psm1" -Resolve)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path -Path $PSScriptRoot\..\..).Path
$Global:CurrentServiceBusStubModule = $ServiceBusCmdletModule

$DscResourceName = "SBHost"
Import-Module -Name (Join-Path -Path $RepoRoot -ChildPath "DSCClassResources\$DscResourceName\$DscResourceName.psm1") -Scope Global -Force
Import-Module -Name (Join-Path -Path $RepoRoot -ChildPath "Modules\SB.Util\SB.Util.psm1") -Scope Global -Force

Describe $DscResourceName {
    InModuleScope -Module $DscResourceName {
        # Arrange
        $testSBHost = [SBHost]::new()
        $testSBHost.EnableFirewallRules = $true
        $testSBHost.Ensure = [Ensure]::Present
        $testSBHost.ExternalBrokerPort = 1024
        $testSBHost.ExternalBrokerUrl = 'externalbroker.azurewebsites.net'
        $runAsPasswordCredentialParams = @{
            TypeName = 'System.Management.Automation.PSCredential'
            ArgumentList = @(
                "servicebus@contoso",
                (ConvertTo-SecureString -String "password" -AsPlainText -Force)
            )
        }
        $testSBHost.RunAsPassword = New-Object @runAsPasswordCredentialParams
        $testSBHost.SBFarmDBConnectionStringDataSource = "SQLSERVER.contoso.com"
        $testSBHost.Started = $true

        Remove-Module -Name "Microsoft.ServiceBus.Commands" -Force -ErrorAction SilentlyContinue
        Import-Module $Global:CurrentServiceBusStubModule -WarningAction SilentlyContinue

        $hostName = "$env:COMPUTERNAME.$((Get-CimInstance -ClassName WIN32_ComputerSystem).Domain)"

        Mock Add-SBHost {}
        Mock Remove-SBHost {}
        Mock Start-SBHost {}
        Mock Stop-SBHost {}
        Mock Update-SBHost {}

        Context "Current host is not joined to farm and should be joined and started" {
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
            Mock Get-SBFarmStatus {
                return @(
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "Service Bus Gateway"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "Service Bus Message Broker"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "Service Bus Resource Provider"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "Service Bus VSS"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "FabricHostSvc"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "Service Bus Gateway"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "Service Bus Message Broker"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "Service Bus Resource Provider"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "Service Bus VSS"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "FabricHostSvc"
                        Status      = "Running"
                    }
                )
            }

            It "returns result with Ensure value as Absent from the Get method" {
                # Act
                $currentValues = $testSBHost.Get()

                # Assert
                $currentValues.Ensure | Should BeExactly 'Absent'
            }

            It "returns false from the Test method" {
                # Act | Assert
                $testSBHost.Test() | Should Be $false
            }

            It "calls Add-SBHost cmdlet in the Set method" {
                # Act
                $testSBHost.Set()

                # Assert
                Assert-MockCalled -CommandName Add-SBHost
            }

            It "calls Start-SBHost cmdlet in the Set method" {
                # Act
                $testSBHost.Set()

                # Assert
                Assert-MockCalled -CommandName Start-SBHost
            }
        }

        Context "Current host is joined to the farm but should be removed" {
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
                            Name               = $hostName
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
            Mock Get-SBFarmStatus {
                return @(
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "Service Bus Gateway"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "Service Bus Message Broker"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "Service Bus Resource Provider"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "Service Bus VSS"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "FabricHostSvc"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "Service Bus Gateway"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "Service Bus Message Broker"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "Service Bus Resource Provider"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "Service Bus VSS"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "FabricHostSvc"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 3
                        HostName    = $hostName
                        ServiceName = "Service Bus Gateway"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 3
                        HostName    = $hostName
                        ServiceName = "Service Bus Message Broker"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 3
                        HostName    = $hostName
                        ServiceName = "Service Bus Resource Provider"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 3
                        HostName    = $hostName
                        ServiceName = "Service Bus VSS"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 3
                        HostName    = $hostName
                        ServiceName = "FabricHostSvc"
                        Status      = "Running"
                    }
                )
            }

            $testSBHost.Ensure = 'Absent'

            It "returns current values from the Get method" {
                # Act | Assert
                $testSBHost.Get() | Should Not BeNullOrEmpty
            }

            It "returns false from the Test method" {
                # Act | Assert
                $testSBHost.Test() | Should Be $false
            }

            It "calls Stop-SBHost in the Set method" {
                # Act
                $testSBHost.Set()

                # Assert
                Assert-MockCalled -CommandName Stop-SBHost
            }

            It "calls Remove-SBHost in the Set method" {
                # Act
                $testSBHost.Set()

                # Assert
                Assert-MockCalled -CommandName Remove-SBHost
            }

            # Cleanup
            $testSBHost.Ensure = 'Present'
        }

        Context "Current host is joined to farm but is stopped and should be started" {
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
                            Name               = $hostName
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
            Mock Get-SBFarmStatus {
                return @(
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "Service Bus Gateway"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "Service Bus Message Broker"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "Service Bus Resource Provider"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "Service Bus VSS"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "FabricHostSvc"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "Service Bus Gateway"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "Service Bus Message Broker"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "Service Bus Resource Provider"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "Service Bus VSS"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "FabricHostSvc"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 3
                        HostName    = $hostName
                        ServiceName = "Service Bus Gateway"
                        Status      = "Stopped"
                    },
                    @{
                        HostId      = 3
                        HostName    = $hostName
                        ServiceName = "Service Bus Message Broker"
                        Status      = "Stopped"
                    },
                    @{
                        HostId      = 3
                        HostName    = $hostName
                        ServiceName = "Service Bus Resource Provider"
                        Status      = "Stopped"
                    },
                    @{
                        HostId      = 3
                        HostName    = $hostName
                        ServiceName = "Service Bus VSS"
                        Status      = "Stopped"
                    },
                    @{
                        HostId      = 3
                        HostName    = $hostName
                        ServiceName = "FabricHostSvc"
                        Status      = "Stopped"
                    }
                )
            }

            It "returns current values from the Get method" {
                # Act | Assert
                $testSBHost.Get() | Should Not BeNullOrEmpty
            }

            It "returns false from the Test method" {
                # Act | Assert
                $testSBHost.Test() | Should Be $false
            }

            It "calls Update-SBHost in the Set method" {
                # Act
                $testSBHost.Set()

                # Assert
                Assert-MockCalled -CommandName Update-SBHost
            }

            It "calls Start-SBHost in the Set method" {
                # Act
                $testSBHost.Set()

                # Assert
                Assert-MockCalled -CommandName Start-SBHost
            }
        }

        Context "Current host is joined to farm but is started and should be stopped" {
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
                            Name               = $hostName
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
            Mock Get-SBFarmStatus {
                return @(
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "Service Bus Gateway"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "Service Bus Message Broker"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "Service Bus Resource Provider"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "Service Bus VSS"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 1
                        HostName    = 'servicebus01.contoso.com'
                        ServiceName = "FabricHostSvc"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "Service Bus Gateway"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "Service Bus Message Broker"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "Service Bus Resource Provider"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "Service Bus VSS"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 2
                        HostName    = 'servicebus02.contoso.com'
                        ServiceName = "FabricHostSvc"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 3
                        HostName    = $hostName
                        ServiceName = "Service Bus Gateway"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 3
                        HostName    = $hostName
                        ServiceName = "Service Bus Message Broker"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 3
                        HostName    = $hostName
                        ServiceName = "Service Bus Resource Provider"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 3
                        HostName    = $hostName
                        ServiceName = "Service Bus VSS"
                        Status      = "Running"
                    },
                    @{
                        HostId      = 3
                        HostName    = $hostName
                        ServiceName = "FabricHostSvc"
                        Status      = "Running"
                    }
                )
            }

            $testSBHost.Started = $false

            It "returns current values from the Get method" {
                # Act | Assert
                $testSBHost.Get() | Should Not BeNullOrEmpty
            }

            It "returns false from the Test method" {
                # Act | Assert
                $testSBHost.Test() | Should Be $false
            }

            It "calls Stop-SBHost in the Set method" {
                # Act
                $testSBHost.Set()

                # Assert
                Assert-MockCalled -CommandName Stop-SBHost
            }

            # Cleanup
            $testSBHost.Started = $true
        }
    }
}
