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
            DataSource = 'localhost'
        }
        ServiceBus = @{
            Farm = @{
                FarmDNS = 'servicebus.contoso.com'
            }
        }
        Certificates = @{
            RootCert = @{
                Path = 'C:\Program Files\WindowsPowerShell\Modules\cServiceBusForWindowsServer\Examples\root.cer'
                Thumbprint = '2E5D900A6080DBA3127ABD125BC1D03E27FA9906'
            }
            <#
            Intermediate = @{
                Path = '<InsertPathToYourIntermediatePathHereIfNecessary>'
                Thumbprint = '<InsertPathToYourIntermediateThumbprintHereIfNecessary>'
            }
            #>
            Pfx = @{
                Path = 'C:\Program Files\WindowsPowerShell\Modules\cServiceBusForWindowsServer\Examples\servicebuc.contoso.com.pfx'
                Thumbprint = '62C99D4B5711E2482A5A1AECE6F8D05231D5678D'
            }
        }
    }
}
