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
                EncryptionCertificateThumbprint = '62C99D4B5711E2482A5A1AECE6F8D05231D5678D'
                FarmCertificateThumbprint = '62C99D4B5711E2482A5A1AECE6F8D05231D5678D'
                FarmDNS = 'servicebus.contoso.com'
            }
        }
    }
}
