Configuration SingleServerConfig {
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
        $TenantApiCredential<#,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $CertificateImportPassphraseCredential#>
    )

    Import-DscResource -Module xPendingReboot, PSDesiredStateConfiguration, cServiceBusForWindowsServer
    #Import-DscResource -Module xCredSSP
    #Import-DscResource -Module xCertificate

    Node $AllNodes.NodeName {

        # Utilize xCredSSP module if your SQL server is on a remote machine for single server scenario.
        <#
        xCredSSP CredSSP {
            Ensure = 'Present'
            Role = 'Client'
            DelegateComputers = $ConfigurationData.NonNodeData.SQLServer.DataSource
        }
        #>

        # Utilize xCertificate module to install example's sample certs, or certs of your own.
        <#
        xCertificateImport RootCertificateImport {
            Thumbprint = $ConfigurationData.NonNodeData.Certificates.Root.Thumbprint
            Path = $ConfigurationData.NonNodeData.Certificates.Root.Path
            Location = 'LocalMachine'
            Store = 'Root'
            Ensure = 'Present'
        }

        # Only necessary if you need to import an intermediate
        xCertificateImport IntermediateCertificateImport {
            Thumbprint = $ConfigurationData.NonNodeData.Certificates.Intermediate.Thumbprint
            Path = $ConfigurationData.NonNodeData.Certificates.Intermediate.Path
            Location = 'LocalMachine'
            Store = 'Root'
            Ensure = 'Present'
        }

        xPfxImport PfxImport {
            Thumbprint = $ConfigurationData.NonNodeData.Certificates.Pfx.Thumbprint
            Path = $ConfigurationData.NonNodeData.Certificates.Pfx.Path
            Location = 'LocalMachine'
            Store = 'My'
            Exportable = $false
            Credential = $CertificateImportPassphraseCredential
            Ensure = 'Present'
        }
        #>

        User LocalSBInstallUser {
            UserName = $LocalInstallCredential.UserName
            Description = "Local user account used to install Service Bus bits from Web Platform Installer"
            Ensure = 'Present'
            FullName = "Service Bus Local Install Account"
            Password = $LocalInstallCredential
            PasswordChangeNotAllowed = $true
            PasswordNeverExpires = $true
        }

        Group Administrators {
            DependsOn = '[User]LocalSBInstallUser'
            Credential = $DomainInstallCredential
            GroupName = 'Administrators'
            Ensure = 'Present'
            MembersToInclude = 'ServiceBusInstall',$DomainInstallCredential.UserName
        }

        xPendingReboot Reboot_Before_WebPI_Install {
            Name = "Reboot_Before_WebPI_Install"
        }

        Package ServiceBus_1_1_CU1_Installation {
            Ensure = 'Present'
            Name = "Service Bus 1.1"
            Path = "C:\Temp\bin\WebpiCmd.exe"
            ProductId = "F438C511-5A64-433E-97EC-5E5343DA670A"
            Arguments = "/Install /Products:ServiceBus_1_1_CU1 /AcceptEULA /xml:C:\Temp\feeds\latest\webproductlist.xml"
            PsDscRunAsCredential = $LocalInstallCredential
            ReturnCode = 0
            DependsOn = '[xPendingReboot]Reboot_Before_WebPI_Install','[User]LocalSBInstallUser'
        }

        xPendingReboot Reboot_After_WebPI_Install {
            Name = "Reboot_After_WebPI_Install"
            DependsOn = '[Package]ServiceBus_1_1_CU1_Installation'
        }

        cSBFarm SBFarm {
            DependsOn = '[xPendingReboot]Reboot_After_WebPI_Install'<#,'[xPfxImport]PfxImport'#>
            PsDscRunAsCredential = $DomainInstallCredential
            AdminApiCredentials = $AdminApiCredential
            EncryptionCertificateThumbprint = $ConfigurationData.NonNodeData.Certificates.Pfx.Thumbprint
            FarmCertificateThumbprint = $ConfigurationData.NonNodeData.Certificates.Pfx.Thumbprint
            FarmDNS = $ConfigurationData.NonNodeData.ServiceBus.Farm.FarmDNS
            RunAsAccount = $RunAsAccountCredential.UserName
            SBFarmDBConnectionStringDataSource = $ConfigurationData.NonNodeData.SQLServer.DataSource
            TenantApiCredentials = $TenantApiCredential
        }

        cSBHost SBHost {
            DependsOn = '[cSBFarm]SBFarm'
            PsDscRunAsCredential = $DomainInstallCredential
            EnableFirewallRules = $true
            RunAsPassword = $RunAsAccountCredential
            SBFarmDBConnectionStringDataSource = $ConfigurationData.NonNodeData.SQLServer.DataSource
        }

        cSBNamespace {
            DependsOn = '[cSBFarm]SBFarm'
            PsDscRunAsCredentials = $DomainInstallCredential
            Name = 'ContosoNamespace'
            ManageUsers = 'BUILTIN\Administrators','ServiceBusAdmins@CONTOSO'
        }
    }
}

$localInstallCred = (Get-Credential -UserName 'ServiceBusInstall' -Message 'Local Install Credential')
$domainInstallCred = (Get-Credential -Message 'Domain Install Credential') # Make sure this account has access to your SQL Instance!
$runAsAccountCred = (Get-Credential -Message 'RunAsAccount Credential in the form samaccountname@DOMAIN without the suffix (e.g. servicebus@CONTOSO)')
$adminApiCred = (Get-Credential -UserName 'adminUser' -Message 'Admin API Credential')
$tenantApiCred = (Get-Credential -UserName 'tenantUser' -Message 'Tenant API Credential')
#$certificateImportPassphraseCredential = (Get-Credential -UserName 'SSLCert' -Message 'SSL Cert Import Passphrase')

$SingleServerConfigParams = @{
    OutputPath              = 'C:\Program Files\WindowsPowerShell\Configuration\Schema'
    ConfigurationData       = ('C:\Program Files\WindowsPowerShell\Modules\cServiceBusForWindowsServer\Examples\' +
                               'SingleServerConfig.psd1')
    LocalInstallCredential  = $localInstallCred
    DomainInstallCredential = $domainInstallCred
    RunAsAccountCredential  = $runAsAccountCred
    AdminApiCredential      = $adminApiCred
    TenantApiCredential     = $tenantApiCred
    #CertificateImportPassphraseCredential = $certificateImportPassphraseCredential
}
SingleServerConfig @SingleServerConfigParams
Start-DscConfiguration -Path 'C:\Program Files\WindowsPowerShell\Configuration\Schema' -Wait -Verbose -Force
