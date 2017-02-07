﻿Configuration SingleServerConfig {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $LocalInstallCredential,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $DomainInstallCredential,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $RunAsAccountCredential,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $AdminApiCredential,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $TenantApiCredential,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $CertificateImportPassphraseCredential
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
            Description = "Local user account used to install Service Bus bits from Web Platform Installer"
            Ensure = 'Present'
            FullName = "Service Bus Local Install Account"
            Password = $LocalInstallCredential
            PasswordChangeNotAllowed = $true
            PasswordNeverExpires = $true
        }

        Group AddDomainCredToAdministrators {
            DependsOn = '[User]LocalSBInstallUser'
            Credential = $DomainInstallCredential
            GroupName = 'Administrators'
            Ensure = 'Present'
            MembersToInclude = 'ServiceBusInstall',$DomainInstallCredential.UserName
        }

        File LocalWebpiServiceBusInstallBits {
            PsDscRunAsCredential = $DomainInstallCredential
            CheckSum = 'ModifiedDate'
            DestinationPath = "C:\ServiceBus_1_1_CU1"
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
            Arguments = "/Install /Products:ServiceBus_1_1_CU1 /AcceptEULA /xml:C:\ServiceBus_1_1_CU1\feeds\latest\webproductlist.xml"
            Name = "Service Bus 1.1"
            Path = "C:\ServiceBus_1_1_CU1\bin\WebpiCmd-x64.exe"
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
    }
}

$localInstallCred = (Get-Credential -UserName 'ServiceBusInstall' -Message 'Local Install Credential')
$domainInstallCred = (Get-Credential -Message 'Domain Install Credential') # Make sure this account has access to your SQL Instance!
$runAsAccountCred = (Get-Credential -Message 'RunAsAccount Credential in the form DOMAIN\SAMACCOUNTNAME (e.g. CONTOSO\SERVICEBUS)')
$adminApiCred = (Get-Credential -UserName 'adminUser' -Message 'Admin API Credential')
$tenantApiCred = (Get-Credential -UserName 'tenantUser' -Message 'Tenant API Credential')
$certificateImportPassphraseCredential = (Get-Credential -UserName 'SSLCert' -Message 'SSL Cert Import Passphrase')

$SingleServerConfigParams = @{
    OutputPath              = 'C:\Program Files\WindowsPowerShell\Configuration\Schema'
    ConfigurationData       = ('C:\Program Files\WindowsPowerShell\Modules\ServiceBusForWindowsServerDsc\Examples\' +
                               'SingleServerConfig.psd1')
    LocalInstallCredential  = $localInstallCred
    DomainInstallCredential = $domainInstallCred
    RunAsAccountCredential  = $runAsAccountCred
    AdminApiCredential      = $adminApiCred
    TenantApiCredential     = $tenantApiCred
    CertificateImportPassphraseCredential = $certificateImportPassphraseCredential
}
SingleServerConfig @SingleServerConfigParams
Start-DscConfiguration -Path 'C:\Program Files\WindowsPowerShell\Configuration\Schema' -Wait -Verbose -Force
