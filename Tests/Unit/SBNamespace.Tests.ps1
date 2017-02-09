[CmdletBinding()]
param(
    [string]
    $ServiceBusCmdletModule = (Join-Path -Path $PSScriptRoot -ChildPath "Stubs\ServiceBus\2.0.40512.2\Microsoft.ServiceBus.Commands.psm1" -Resolve)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path -Path $PSScriptRoot\..\..).Path
$Global:CurrentServiceBusStubModule = $ServiceBusCmdletModule

Remove-Module -Name "SB.Util" -Force -ErrorAction SilentlyContinue
Import-Module -Name (Join-Path -Path $RepoRoot -ChildPath "Modules\SB.Util\SB.Util.psm1") -Scope Global -Force

$DscResourceName = "SBNamespace"
Remove-Module -Name $DscResourceName -Force -ErrorAction SilentlyContinue
Import-Module -Name (Join-Path -Path $RepoRoot -ChildPath "DSCClassResources\$DscResourceName\$DscResourceName.psm1") -Scope Global -Force

Describe $DscResourceName {
    InModuleScope -Module $DscResourceName {
        # Arrange
        $testSBNamespace = [SBNamespace]::new()
        $testSBNamespace.AddressingScheme = 'Path'
        $testSBNamespace.DNSEntry = "servicebusnamespace.contoso.com"
        $testSBNamespace.Ensure = 'Present'
        $testSBNamespace.IssuerName = "ContosoNamespace"
        $testSBNamespace.IssuerUri = "ContosoNamespace"
        $testSBNamespace.ManageUsers = "CONTOSO\ServiceBusAdmins",'CONTOSO\ServiceBusBackupAdmins'
        $testSBNamespace.Name = "ContosoNamespace"
        $testSBNamespace.PrimarySymmetricKey = "hG8ShCxVH2TdeasdfZaeULV+kxRLyah6xxYnRE/QDsM="
        $testSBNamespace.SecondarySymmetricKey = "RvxwTxTctasdf6KzKNfjQzjaV7oc53yUDl08ZUXQrFU="
        $testSBNamespace.SubscriptionId = "00000000000000000000000000000000"

        Remove-Module -Name "Microsoft.ServiceBus.Commands" -Force -ErrorAction SilentlyContinue
        Import-Module $Global:CurrentServiceBusStubModule -WarningAction SilentlyContinue

        Mock New-SBNamespace {}
        Mock Set-SBNamespace {}
        Mock Remove-SBNamespace {}

        Context "No namespace exists for a given name and should be created" {
            # Arrange
            Mock Get-SBNamespace {
                throw ("Namespace $($this.Name) does not exist.")
            }

            It "returns object with Ensure = Absent from the Get method" {
                # Act
                $currentValues = $testSBNamespace.Get()

                # Arrange
                $currentValues.Ensure | Should BeExactly 'Absent'
            }

            It "returns false from the Test method" {
                # Act | Assert
                $testSBNamespace.Test() | Should Be $false
            }

            It "calls the New-SBNamespace cmdlet in the Set method" {
                # Act
                $testSBNamespace.Set()

                # Assert
                Assert-MockCalled -CommandName New-SBNamespace
            }
        }

        Context "Namespace exists for a given name and should be removed" {
            # Arrange
            $createdTime = [datetime]::Now
            Mock Get-SBNamespace {
                return @{
                    AddressingScheme = 'Path'
                    CreatedTime = [datetime]::Now
                    DNSEntry = 'servicebusnamespace.contoso.com'
                    IssuerName = 'ContosoNamespace'
                    IssuerUri = 'ContosoNamespace'
                    ManageUsers = 'servicebusadmins@contoso.com','servicebusbackupadmins@contoso.com'
                    Name = "ContosoNamespace"
                    PrimarySymmetricKey = "hG8ShCxVH2TdeasdfZaeULV+kxRLyah6xxYnRE/QDsM="
                    SecondarySymmetricKey = "RvxwTxTctasdf6KzKNfjQzjaV7oc53yUDl08ZUXQrFU="
                    State = "Active"
                    SubscriptionId = "00000000000000000000000000000000"
                }
            }

            $testSBNamespace.Ensure = 'Absent'

            It "returns object with Ensure = Present from the Get method" {
                # Act
                $currentValues = $testSBNamespace.Get()

                # Assert
                $currentValues.Ensure | Should Be 'Present'
            }

            It "returns false from the Test method" {
                # Act | Assert
                $testSBNamespace.Test() | Should Be $false
            }

            It "calls the Remove-SBNamespace cmdlet in the Set method" {
                # Act
                $testSBNamespace.Set()

                # Assert
                Assert-MockCalled -CommandName Remove-SBNamespace
            }

            # Cleanup
            $testSBNamespace.Ensure = 'Present'
        }

        Context "Namespace exists for a given name and should be updated" {
            # Arrange
            $createdTime = [datetime]::Now
            Mock Get-SBNamespace {
                return @{
                    AddressingScheme = 'Path'
                    CreatedTime = [datetime]::Now
                    DNSEntry = 'servicebusnamespace.contoso.com'
                    IssuerName = 'oldContosoNamespace'
                    IssuerUri = 'oldContosoNamespace'
                    ManageUsers = 'oldservicebusadmins@contoso.com','oldservicebusbackupadmins@contoso.com'
                    Name = "ContosoNamespace"
                    PrimarySymmetricKey = "RvxwTxTctasdf6KzKNfjQzjaV7oc53yUDl08ZUXQrFU="
                    SecondarySymmetricKey = "hG8ShCxVH2TdeasdfZaeULV+kxRLyah6xxYnRE/QDsM="
                    State = "Active"
                    SubscriptionId = "00000000000000000000000000000001"
                }
            }

            # Arrange
            Mock -ModuleName SB.Util Get-DistinguishedNameForDomain {
                return 'DC=contoso,DC=com'
            }

            Mock -ModuleName SB.Util Get-NetBIOSDomainName {
                return 'CONTOSO'
            }

            It "returns object with Ensure = Present from the Get method" {
                # Act
                $currentValues = $testSBNamespace.Get()

                # Assert
                $currentValues.Ensure | Should Be 'Present'
            }

            It "returns false from the Test method" {
                # Act | Assert
                $testSBNamespace.Test() | Should Be $false
            }

            It "calls the Set-SBNamespace cmdlet in the Set method" {
                # Act
                $testSBNamespace.Set()

                # Assert
                Assert-MockCalled -CommandName Set-SBNamespace
            }
        }
    }
}
