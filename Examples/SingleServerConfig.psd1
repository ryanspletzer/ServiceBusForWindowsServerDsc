@{
     AllNodes = @(
        @{
            NodeName                    = '*'
            PSDscAllowPlainTextPassword = $true #NOTE: Encrypt with certs when you do this for real!!!
            PSDscAllowDomainUser = $true
            LocalInstallUser = @{
                UserName = 'ServiceBusInstall'
                Description = 'Local user account used to install Service Bus bits from Web Platform Installer'
                FullName = 'Service Bus Local Install Account'
            }
        }
        @{
            NodeName     = 'localhost'
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
            SBNamespaces = @{
                ContosoNamespace = 'ContosoNamespace'
            }
            SBMessageContainers = @{
                1 = 'SBMessageContainer01'
                2 = 'SBMessageContainer02'
                3 = 'SBMessageContainer03'
            }
        }
        Certificates = @{
            Root = @{
                Path = 'C:\Program Files\WindowsPowerShell\Modules\ServiceBusForWindowsServerDsc\Examples\root.cer'
                Thumbprint = '2E5D900A6080DBA3127ABD125BC1D03E27FA9906'
            }
            <#
            Intermediate = @{
                Path = '<InsertPathToYourIntermediatePathHereIfNecessary>'
                Thumbprint = '<InsertPathToYourIntermediateThumbprintHereIfNecessary>'
            }
            #>
            Pfx = @{
                Path = 'C:\Program Files\WindowsPowerShell\Modules\ServiceBusForWindowsServerDsc\Examples\servicebus.contoso.com.pfx'
                Thumbprint = '62C99D4B5711E2482A5A1AECE6F8D05231D5678D'
            }
        }
        WebpiServiceBusInstallBits = @{
            Path = '\\resourceserver.contoso.com\ServiceBus_1_1_CU1'
        }
    }
}
