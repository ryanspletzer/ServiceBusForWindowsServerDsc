@{
     AllNodes   = @(
        @{
            NodeName                    = '*'
            PSDscAllowPlainTextPassword = $true #NOTE: Encrypt with certs when you do this for real!!!
            PSDscAllowDomainUser        = $true
            LocalInstallUser = @{
                UserName    = 'ServiceBusInstall'
                Description = 'Local user account used to install Service Bus bits from Web Platform Installer'
                FullName    = 'Service Bus Local Install Account'
            }
            DomainInstallUser = @{
                UserName    = 'CORP\SBInstall'
                Description = 'Domain Install Credential for Service Bus For Windows Server'
                FullName    = 'Domain Install Credential'
            }
            RunAsAccount = @{
                UserName    = "CORP\SBService"
                Description = "Service account for Service Bus for Windows Server"
                FullName    = "Service Bus Service Account"
            }
            AdminApiUser = @{
                UserName = "adminUser"
            }
            TenantApiUser = @{
                UserName = "tenantUser"
            }
        }
        @{
            NodeName = 'localhost'
        }
    )
    NonNodeData = @{
        SQLServer = @{
            DataSource = 'SQL1'
        }
        ServiceBus = @{
            SBFarm = @{
                FarmDNS = 'servicebus.contoso.com'
            }
            SBRuntimeSetting = @{
                DefaultMaximumQueueSizeInMegabytes = @{
                    Name  = 'DefaultMaximumQueueSizeInMegabytes'
                    Value = '10240'
                }
            }
            SBNamespaces = @{
                ContosoNamespace = 'ContosoNamespace'
            }
            SBMessageContainers = @{
                1 = 'SBMessageContainer01'
                2 = 'SBMessageContainer02'
                3 = 'SBMessageContainer03'
            }
            SBAuthorizationRules = @{
                ContosoNamespaceRule = @{
                    Name          = 'ContosoNamespaceRule'
                    NamespaceName = 'ContosoNamespace'
                    Rights        = 'Send','Listen'
                }
            }
        }
        Certificates = @{
            Root = @{
                Path       = 'C:\Program Files\WindowsPowerShell\Modules\ServiceBusForWindowsServerDsc\Examples\Resources\root.cer'
                Thumbprint = '2E5D900A6080DBA3127ABD125BC1D03E27FA9906'
            }
            <#
            Intermediate = @{
                Path       = '<InsertPathToYourIntermediatePathHereIfNecessary>'
                Thumbprint = '<InsertPathToYourIntermediateThumbprintHereIfNecessary>'
            }
            #>
            Pfx = @{
                Path       = 'C:\Program Files\WindowsPowerShell\Modules\ServiceBusForWindowsServerDsc\Examples\Resources\servicebus.contoso.com.pfx'
                Thumbprint = '62C99D4B5711E2482A5A1AECE6F8D05231D5678D'
            }
        }
        WebpiServiceBusInstallBits = @{
            Path            = '\\resourceserver.contoso.com\ServiceBus_1_1_CU1'
            DestinationPath = 'C:\ServiceBus_1_1_CU1'
        }
    }
}
