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
        $TenantApiCredential
    )

    Import-DscResource -Module xPendingReboot, PSDesiredStateConfiguration, cServiceBusForWindowsServer
    #Import-DscResource -Module xCredSSP

    Node $AllNodes.NodeName {

        # Utilize CredSSP if your SQL server is on a remote machine for single server scenario.
        <#
        xCredSSP CredSSP {
            Ensure = 'Present'
            Role = 'Client'
            DelegateComputers = $ConfigurationData.NonNodeData.SQLServer.DataSource
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
            DependsOn = '[xPendingReboot]Reboot_After_WebPI_Install'
            PsDscRunAsCredential = $DomainInstallCredential
            AdminApiCredentials = $AdminApiCredential
            EncryptionCertificateThumbprint = $ConfigurationData.NonNodeData.ServiceBus.Farm.EncryptionCertificateThumbprint
            FarmCertificateThumbprint = $ConfigurationData.NonNodeData.ServiceBus.Farm.FarmCertificateThumbprint
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
        }
    }
}

$localInstallCred = (Get-Credential -UserName 'ServiceBusInstall' -Message 'Local Install Credential')
$domainInstallCred = (Get-Credential -Message 'Domain Install Credential')
$runAsAccountCred = (Get-Credential -Message 'RunAsAccount Credential in the form samaccountname@DOMAIN without the suffix (e.g. servicebus@CONTOSO)')
$adminApiCred = (Get-Credential -UserName 'adminUser' -Message 'Admin API Credential')
$tenantApiCred = (Get-Credential -UserName 'tenantUser' -Message 'Tenant API Credential')

$SingleServerConfigParams = @{
    OutputPath              = 'C:\Program Files\WindowsPowerShell\Configuration\Schema'
    ConfigurationData       = ('C:\Program Files\WindowsPowerShell\Modules\cServiceBusForWindowsServer\Examples\' +
                               'SingleServerConfig.psd1')
    LocalInstallCredential  = $localInstallCred
    DomainInstallCredential = $domainInstallCred
    RunAsAccountCredential  = $runAsAccountCred
    AdminApiCredential      = $adminApiCred
    TenantApiCredential     = $tenantApiCred
}
SingleServerConfig @SingleServerConfigParams
Start-DscConfiguration -Path 'C:\Program Files\WindowsPowerShell\Configuration\Schema' -Wait -Verbose -Force
