$ConfigData = @{
     AllNodes   = @(
        @{
            NodeName                    = '*'
            PSDscAllowPlainTextPassword = $true #NOTE: Encrypt with certs when you do this for real!!!
            PSDscAllowDomainUser        = $true
        }
        @{
            NodeName = 'localhost'
        }
    )
    NonNodeData = @{
        LocalInstallAccount = @{
            UserName    = 'ServiceBusInstall'
            Description = 'Local user account used to install Service Bus bits from Web Platform Installer'
            FullName    = 'Service Bus Local Install Account'
        }
        DomainInstallAccount = @{
            UserName    = 'CORP\SBInstall'
            Description = 'Domain Install Credential for Service Bus For Windows Server'
            FullName    = 'Domain Install Credential'
        }
        RunAsAccount = @{
            UserName    = "CORP\SBService"
            Description = "Service account for Service Bus for Windows Server"
            FullName    = "Service Bus Service Account"
        }
        AdminApiAccount = @{
            UserName = "adminUser"
        }
        TenantApiAccount = @{
            UserName = "tenantUser"
        }
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
                Path       = 'C:\Program Files\WindowsPowerShell\Modules\ServiceBusForWindowsServerDsc\Examples\Certs\root.cer'
                Thumbprint = '2E5D900A6080DBA3127ABD125BC1D03E27FA9906'
            }
            <#
            Intermediate = @{
                Path       = '<InsertPathToYourIntermediatePathHereIfNecessary>'
                Thumbprint = '<InsertPathToYourIntermediateThumbprintHereIfNecessary>'
            }
            #>
            Pfx = @{
                Path       = 'C:\Program Files\WindowsPowerShell\Modules\ServiceBusForWindowsServerDsc\Examples\Certs\servicebus.contoso.com.pfx'
                Thumbprint = '62C99D4B5711E2482A5A1AECE6F8D05231D5678D'
            }
        }
        WebpiServiceBusInstallBits = @{
            Path            = '\\resourceserver.contoso.com\ServiceBus_1_1_CU1'
            DestinationPath = 'C:\ServiceBus_1_1_CU1'
        }
    }
}

Configuration Example {
    param (
        [Parameter()]
        [ValidateNotNull()]
        [pscredential]
        $LocalInstallAccount = (Get-Credential -UserName $ConfigData.NonNodeData.LocalInstallAccount.UserName -Message "Credentials for Local Install Account"),

        [Parameter()]
        [ValidateNotNull()]
        [pscredential]
        $DomainInstallAccount = (Get-Credential -UserName $ConfigData.NonNodeData.DomainInstallAccount.UserName -Message "Credentials for Domain Install Account"),

        [Parameter()]
        [ValidateNotNull()]
        [pscredential]
        $RunAsAccount = (Get-Credential -UserName $ConfigData.NonNodeData.RunAsAccount.UserName -Message "Credentials for Service Bus Service Account"),

        [Parameter()]
        [ValidateNotNull()]
        [pscredential]
        $AdminApiAccount = (Get-Credential -UserName $ConfigData.NonNodeData.AdminApiAccount.UserName -Message "Credentials for Admin Api Account"),

        [Parameter()]
        [ValidateNotNull()]
        [pscredential]
        $TenantApiAccount = (Get-Credential -UserName $ConfigData.NonNodeData.TenantApiAccount.UserName -Message "Credentials for Tenant Api Account"),

        [Parameter()]
        [ValidateNotNull()]
        [pscredential]
        $Passphrase = (Get-Credential -UserName "PfxImportPasshrase" -Message "Pfx Certificate Import Passphrase")
    )

    Import-DscResource -Module PSDesiredStateConfiguration
    Import-DscResource -Module xCertificate
    Import-DscResource -Module ServiceBusForWindowsServerDsc

    Node 'localhost' {

        # Utilize xCertificate module to install example's sample certs, or certs of your own.
        xCertificateImport RootCertificateImport {
            Thumbprint = $ConfigData.NonNodeData.Certificates.Root.Thumbprint
            Path       = $ConfigData.NonNodeData.Certificates.Root.Path
            Location   = 'LocalMachine'
            Store      = 'Root'
            Ensure     = 'Present'
        }

        # Only necessary if you need to import an intermediate because of lack of OCSP.
        <#
        xCertificateImport IntermediateCertificateImport {
            Thumbprint = $ConfigurationData.NonNodeData.Certificates.Intermediate.Thumbprint
            Path       = $ConfigurationData.NonNodeData.Certificates.Intermediate.Path
            Location   = 'LocalMachine'
            Store      = 'Root'
            Ensure     = 'Present'
        }
        #>

        xPfxImport PfxImport {
            Thumbprint = $ConfigData.NonNodeData.Certificates.Pfx.Thumbprint
            Path       = $ConfigData.NonNodeData.Certificates.Pfx.Path
            Location   = 'LocalMachine'
            Store      = 'My'
            Exportable = $false
            Credential = $Passphrase
            Ensure     = 'Present'
        }

        User LocalSBInstallUser {
            UserName                 = $LocalInstallAccount.UserName
            Description              = $ConfigData.NonNodeData.LocalInstallAccount.Description
            Ensure                   = 'Present'
            FullName                 = $ConfigData.NonNodeData.LocalInstallAccount.FullName
            Password                 = $LocalInstallAccount
            PasswordChangeNotAllowed = $true
            PasswordNeverExpires     = $true
        }

        Group AddDomainCredToAdministrators {
            DependsOn        = '[User]LocalSBInstallUser'
            Credential       = $DomainInstallAccount
            GroupName        = 'Administrators'
            Ensure           = 'Present'
            MembersToInclude = $LocalInstallAccount.UserName,$DomainInstallAccount.UserName
        }

        File LocalWebpiServiceBusInstallBits {
            PsDscRunAsCredential = $DomainInstallAccount
            CheckSum             = 'ModifiedDate'
            DestinationPath      = $ConfigData.NonNodeData.WebpiServiceBusInstallBits.DestinationPath
            Ensure               = 'Present'
            Force                = $true
            SourcePath           = $ConfigData.NonNodeData.WebpiServiceBusInstallBits.Path
            Recurse              = $true
            Type                 = 'Directory'
        }

        Package ServiceBus1_1_CU1Installation {
            PsDscRunAsCredential = $LocalInstallAccount
            DependsOn            = '[User]LocalSBInstallUser'
            Ensure               = 'Present'
            Arguments            = "/Install /Products:ServiceBus_1_1_CU1 /AcceptEULA /xml:$($ConfigData.NonNodeData.WebpiServiceBusInstallBits.DestinationPath)\feeds\latest\webproductlist.xml"
            Name                 = "Service Bus 1.1"
            Path                 = "$($ConfigData.NonNodeData.WebpiServiceBusInstallBits.DestinationPath)\bin\WebpiCmd-x64.exe"
            ProductId            = "F438C511-5A64-433E-97EC-5E5343DA670A"
            ReturnCode           = 0
        }

        SBFarm ContosoSBFarm {
            DependsOn                          = '[xPfxImport]PfxImport'
            PsDscRunAsCredential               = $DomainInstallAccount
            AdminApiCredentials                = $AdminApiAccount
            EncryptionCertificateThumbprint    = $ConfigData.NonNodeData.Certificates.Pfx.Thumbprint
            FarmCertificateThumbprint          = $ConfigData.NonNodeData.Certificates.Pfx.Thumbprint
            FarmDNS                            = $ConfigData.NonNodeData.ServiceBus.SBFarm.FarmDNS
            RunAsAccount                       = $RunAsAccount.UserName
            SBFarmDBConnectionStringDataSource = $ConfigData.NonNodeData.SQLServer.DataSource
            TenantApiCredentials               = $TenantApiAccount
        }

        SBHost ContosoSBHost {
            DependsOn                          = '[SBFarm]ContosoSBFarm'
            PsDscRunAsCredential               = $DomainInstallAccount
            EnableFirewallRules                = $true
            Ensure                             = 'Present'
            RunAsPassword                      = $RunAsAccount
            SBFarmDBConnectionStringDataSource = $ConfigData.NonNodeData.SQLServer.DataSource
        }

        SBNamespace ContosoNamespace {
            DependsOn            = '[SBFarm]ContosoSBFarm'
            PsDscRunAsCredential = $DomainInstallAccount
            Ensure               = 'Present'
            Name                 = $ConfigData.NonNodeData.ServiceBus.SBNameSpaces.ContosoNamespace
            ManageUsers          = $DomainInstallAccount.UserName
        }

        SBMessageContainer SBMessageContainer01 {
            DependsOn                                 = '[SBHost]ContosoSBHost'
            PsDscRunAsCredential                      = $DomainInstallAccount
            ContainerDBConnectionStringDataSource     = $ConfigData.NonNodeData.SQLServer.DataSource
            ContainerDBConnectionStringInitialCatalog = $ConfigData.NonNodeData.ServiceBus.SBMessageContainers.1
            Ensure                                    = 'Present'
        }

        SBMessageContainer SBMessageContainer02 {
            DependsOn                                 = '[SBHost]ContosoSBHost'
            PsDscRunAsCredential                      = $DomainInstallAccount
            ContainerDBConnectionStringDataSource     = $ConfigData.NonNodeData.SQLServer.DataSource
            ContainerDBConnectionStringInitialCatalog = $ConfigData.NonNodeData.ServiceBus.SBMessageContainers.2
            Ensure = 'Present'
        }

        SBMessageContainer SBMessageContainer03 {
            DependsOn                                 = '[SBHost]ContosoSBHost'
            PsDscRunAsCredential                      = $DomainInstallAccount
            ContainerDBConnectionStringDataSource     = $ConfigData.NonNodeData.SQLServer.DataSource
            ContainerDBConnectionStringInitialCatalog = $ConfigData.NonNodeData.ServiceBus.SBMessageContainers.3
            Ensure = 'Present'
        }

        SBAuthorizationRule ContosoNamespaceRule {
            DependsOn            = '[SBNamespace]ContosoNamespace'
            PsDscRunAsCredential = $DomainInstallAccount
            Name                 = $ConfigData.NonNodeData.ServiceBus.SBAuthorizationRules.ContosoNamespaceRule.Name
            NamespaceName        = $ConfigData.NonNodeData.ServiceBus.SBAuthorizationRules.ContosoNamespaceRule.NamespaceName
            Rights               = $ConfigData.NonNodeData.ServiceBus.SBAuthorizationRules.ContosoNamespaceRule.Rights
            Ensure               = 'Present'
        }

        SBHostCEIP CEIP {
            DependsOn            = '[SBHost]ContosoSBHost'
            PsDscRunAsCredential = $DomainInstallAccount
            Ensure               = 'Present'
        }

        SBRuntimeSetting DefaultMaximumQueueSizeInMegabytes {
            DependsOn            = '[SBHost]ContosoSBHost'
            PsDscRunAsCredential = $DomainInstallAccount
            Name                 = $ConfigData.NonNodeData.ServiceBus.SBRuntimeSetting.DefaultMaximumQueueSizeInMegabytes.Name
            Value                = $ConfigData.NonNodeData.ServiceBus.SBRuntimeSetting.DefaultMaximumQueueSizeInMegabytes.Value
        }
    }
}
