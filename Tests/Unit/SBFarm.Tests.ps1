#region HEADER

# Unit Test Template Version: 1.2.0
$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

# Deviating from test template to accomodate copying DSC class resources for tests
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResources'))) )
{
    Copy-Item -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCClassResources')`
        -Destination (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResources') -Container -Recurse
}

Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath (Join-Path -Path 'DSCResource.Tests' -ChildPath 'TestHelper.psm1')) -Force

$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'ServiceBusForWindowsServerDsc' `
    -DSCResourceName 'SBFarm' `
    -TestType Unit

#endregion HEADER

function Invoke-TestSetup {
    $serviceBusCmdletModule = Join-Path -Path $PSScriptRoot -ChildPath "Stubs\ServiceBus\2.0.40512.2\Microsoft.ServiceBus.Commands.psm1" -Resolve
    Import-Module -Name $serviceBusCmdletModule -Scope 'Global' -Force
    Import-Module -Name (Join-Path -Path $moduleRoot -ChildPath "Modules\SB.Util\SB.Util.psm1") -Scope 'Global' -Force
}

function Invoke-TestCleanup {
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
}

# Begin Testing
try
{
    Invoke-TestSetup

    InModuleScope 'SBFarm' {
        # Arrange
        $testSBFarm = [SBFarm]::new()
        $adminApiCredentialParams = @{
            TypeName     = 'System.Management.Automation.PSCredential'
            ArgumentList = @( "adminUser", (ConvertTo-SecureString -String "password" -AsPlainText -Force) )
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
            ArgumentList = @( "tenantUser", (ConvertTo-SecureString -String "password" -AsPlainText -Force) )
        }
        $testSBFarm.TenantApiCredentials = New-Object @tenantApiCredentialParams

        Mock New-SBFarm {}
        Mock Set-SBFarm {}
        Mock Stop-SBFarm {}

        Describe 'SBFarm' {
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
}
finally
{
    Invoke-TestCleanup
}
