Configuration SingleServerConfig {
    param (
        [Parameter()]
        [ValidateNotNull()]
        [pscredential]
        $LocalInstallCredential = (Get-Credential -UserName $ConfigurationData.AllNodes.Where({$true}).LocalInstallUser.UserName -Message "Credentials for Local Install User"),

        [Parameter()]
        [ValidateNotNull()]
        [pscredential]
        $DomainInstallCredential = (Get-Credential -UserName $ConfigurationData.AllNodes.Where({$true}).DomainInstallUser.UserName -Message "Credentials for Domain Install User"),

        [Parameter()]
        [ValidateNotNull()]
        [pscredential]
        $RunAsAccountCredential = (Get-Credential -UserName $ConfigurationData.AllNodes.Where({$true}).RunAsAccount.UserName -Message "Credentials for Service Bus Service Account"),

        [Parameter()]
        [ValidateNotNull()]
        [pscredential]
        $AdminApiCredential = (Get-Credential -UserName $ConfigurationData.AllNodes.Where({$true}).AdminApiUser.UserName -Message "Credentials for Admin Api User"),

        [Parameter()]
        [ValidateNotNull()]
        [pscredential]
        $TenantApiCredential = (Get-Credential -UserName $ConfigurationData.AllNodes.Where({$true}).TenantApiUser.UserName -Message "Credentials for Tenant Api User"),

        [Parameter()]
        [ValidateNotNull()]
        [pscredential]
        $CertificateImportPassphraseCredential = (Get-Credential -UserName "SslCert" -Message "Certificate Import Passphrase")
    )

    Import-DscResource -Module xCertificate, PSDesiredStateConfiguration, ServiceBusForWindowsServerDsc

    Node $AllNodes.NodeName {

        # Utilize xCertificate module to install example's sample certs, or certs of your own.
        xCertificateImport RootCertificateImport {
            Thumbprint = $ConfigurationData.NonNodeData.Certificates.Root.Thumbprint
            Path = $ConfigurationData.NonNodeData.Certificates.Root.Path
            Location = 'LocalMachine'
            Store = 'Root'
            Ensure = 'Present'
        }

        # Only necessary if you need to import an intermediate because of lack of OCSP.
        <#
        xCertificateImport IntermediateCertificateImport {
            Thumbprint = $ConfigurationData.NonNodeData.Certificates.Intermediate.Thumbprint
            Path = $ConfigurationData.NonNodeData.Certificates.Intermediate.Path
            Location = 'LocalMachine'
            Store = 'Root'
            Ensure = 'Present'
        }
        #>

        xPfxImport PfxImport {
            Thumbprint = $ConfigurationData.NonNodeData.Certificates.Pfx.Thumbprint
            Path = $ConfigurationData.NonNodeData.Certificates.Pfx.Path
            Location = 'LocalMachine'
            Store = 'My'
            Exportable = $false
            Credential = $CertificateImportPassphraseCredential
            Ensure = 'Present'
        }

        User LocalSBInstallUser {
            UserName = $LocalInstallCredential.UserName
            Description = $ConfigurationData.AllNodes.LocalInstallUser.Description
            Ensure = 'Present'
            FullName = $ConfigurationData.AllNodes.LocalInstallUser.FullName
            Password = $LocalInstallCredential
            PasswordChangeNotAllowed = $true
            PasswordNeverExpires = $true
        }

        Group AddDomainCredToAdministrators {
            DependsOn = '[User]LocalSBInstallUser'
            Credential = $DomainInstallCredential
            GroupName = 'Administrators'
            Ensure = 'Present'
            MembersToInclude = $LocalInstallCredential.UserName,$DomainInstallCredential.UserName
        }

        File LocalWebpiServiceBusInstallBits {
            PsDscRunAsCredential = $DomainInstallCredential
            CheckSum = 'ModifiedDate'
            DestinationPath = $ConfigurationData.NonNodeData.WebpiServiceBusInstallBits.DestinationPath
            Ensure = 'Present'
            Force = $true
            SourcePath = $ConfigurationData.NonNodeData.WebpiServiceBusInstallBits.Path
            Recurse = $true
            Type = 'Directory'
        }

        Package ServiceBus1_1_CU1Installation {
            PsDscRunAsCredential = $LocalInstallCredential
            DependsOn = '[User]LocalSBInstallUser'
            Ensure = 'Present'
            Arguments = "/Install /Products:ServiceBus_1_1_CU1 /AcceptEULA /xml:$($ConfigurationData.NonNodeData.WebpiServiceBusInstallBits.DestinationPath)\feeds\latest\webproductlist.xml"
            Name = "Service Bus 1.1"
            Path = "$($ConfigurationData.NonNodeData.WebpiServiceBusInstallBits.DestinationPath)\bin\WebpiCmd-x64.exe"
            ProductId = "F438C511-5A64-433E-97EC-5E5343DA670A"
            ReturnCode = 0
        }

        SBFarm ContosoSBFarm {
            DependsOn = '[xPfxImport]PfxImport'
            PsDscRunAsCredential = $DomainInstallCredential
            AdminApiCredentials = $AdminApiCredential
            EncryptionCertificateThumbprint = $ConfigurationData.NonNodeData.Certificates.Pfx.Thumbprint
            FarmCertificateThumbprint = $ConfigurationData.NonNodeData.Certificates.Pfx.Thumbprint
            FarmDNS = $ConfigurationData.NonNodeData.ServiceBus.SBFarm.FarmDNS
            RunAsAccount = $RunAsAccountCredential.UserName
            SBFarmDBConnectionStringDataSource = $ConfigurationData.NonNodeData.SQLServer.DataSource
            TenantApiCredentials = $TenantApiCredential
        }

        SBHost ContosoSBHost {
            DependsOn = '[SBFarm]ContosoSBFarm'
            PsDscRunAsCredential = $DomainInstallCredential
            EnableFirewallRules = $true
            Ensure = 'Present'
            RunAsPassword = $RunAsAccountCredential
            SBFarmDBConnectionStringDataSource = $ConfigurationData.NonNodeData.SQLServer.DataSource
        }

        SBNamespace ContosoNamespace {
            DependsOn = '[SBFarm]ContosoSBFarm'
            PsDscRunAsCredential = $DomainInstallCredential
            Ensure = 'Present'
            Name = $ConfigurationData.NonNodeData.ServiceBus.SBNameSpaces.ContosoNamespace
            ManageUsers = $DomainInstallCredential.UserName
        }

        SBMessageContainer SBMessageContainer01 {
            DependsOn = '[SBHost]ContosoSBHost'
            PsDscRunAsCredential = $DomainInstallCredential
            ContainerDBConnectionStringDataSource = $ConfigurationData.NonNodeData.SQLServer.DataSource
            ContainerDBConnectionStringInitialCatalog = $ConfigurationData.NonNodeData.ServiceBus.SBMessageContainers.1
            Ensure = 'Present'
        }

        SBMessageContainer SBMessageContainer02 {
            DependsOn = '[SBHost]ContosoSBHost'
            PsDscRunAsCredential = $DomainInstallCredential
            ContainerDBConnectionStringDataSource = $ConfigurationData.NonNodeData.SQLServer.DataSource
            ContainerDBConnectionStringInitialCatalog = $ConfigurationData.NonNodeData.ServiceBus.SBMessageContainers.2
            Ensure = 'Present'
        }

        SBMessageContainer SBMessageContainer03 {
            DependsOn = '[SBHost]ContosoSBHost'
            PsDscRunAsCredential = $DomainInstallCredential
            ContainerDBConnectionStringDataSource = $ConfigurationData.NonNodeData.SQLServer.DataSource
            ContainerDBConnectionStringInitialCatalog = $ConfigurationData.NonNodeData.ServiceBus.SBMessageContainers.3
            Ensure = 'Present'
        }

        SBAuthorizationRule ContosoNamespaceRule {
            DependsOn = '[SBNamespace]ContosoNamespace'
            PsDscRunAsCredential = $DomainInstallCredential
            Name = $ConfigurationData.NonNodeData.ServiceBus.SBAuthorizationRules.ContosoNamespaceRule.Name
            NamespaceName = $ConfigurationData.NonNodeData.ServiceBus.SBAuthorizationRules.ContosoNamespaceRule.NamespaceName
            Rights = $ConfigurationData.NonNodeData.ServiceBus.SBAuthorizationRules.ContosoNamespaceRule.Rights
            Ensure = 'Present'
        }

        SBHostCEIP CEIP {
            DependsOn = '[SBHost]ContosoSBHost'
            PsDscRunAsCredential = $DomainInstallCredential
            Ensure = 'Present'
        }
    }
}
