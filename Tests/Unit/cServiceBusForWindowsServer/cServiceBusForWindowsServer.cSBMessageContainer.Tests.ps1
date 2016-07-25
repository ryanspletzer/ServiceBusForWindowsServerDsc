[CmdletBinding()]
param(
    [string]
    $ServiceBusCmdletModule = (Join-Path -Path $PSScriptRoot -ChildPath "..\Stubs\ServiceBus\2.0.40512.2\Microsoft.ServiceBus.Commands.psm1" -Resolve)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path -Path $PSScriptRoot\..\..\..).Path
$Global:CurrentServiceBusStubModule = $ServiceBusCmdletModule

$ModuleName = "cServiceBusForWindowsServer"
Import-Module -Name (Join-Path -Path $RepoRoot -ChildPath "Modules\cServiceBusForWindowsServer\$ModuleName.psm1")
Import-Module -Name (Join-Path -Path $RepoRoot -ChildPath "Modules\cServiceBusForWindowsServer\Modules\cServiceBusForWindowsServer.Util\cServiceBusForWindowsServer.Util.psm1")

Describe "cSBMessageContainer" {
    InModuleScope $ModuleName {
        # Arrange
        $testSBMessageContainer = [cSBMessageContainer]::new()

        $testSBNamespace = [cSBNamespace]::new()
        $testSBNamespace.AddressingScheme = 'Path'
        $testSBNamespace.DNSEntry = "servicebusnamespace.contoso.com"
        $testSBNamespace.IssuerName = "ContosoNamespace"
        $testSBNamespace.IssuerUri = "ContosoNamespace"
        $testSBNamespace.ManageUsers = "BUILTIN\Administrators",'ServiceBusAdmins@contoso.com'
        $testSBNamespace.Name = "ContosoNamespace"
        $testSBNamespace.PrimarySymmetricKey = "hG8ShCxVH2TdeasdfZaeULV+kxRLyah6xxYnRE/QDsM="
        $testSBNamespace.SecondarySymmetricKey = "RvxwTxTctasdf6KzKNfjQzjaV7oc53yUDl08ZUXQrFU="
        $testSBNamespace.SubscriptionId = "00000000000000000000000000000000"

        Import-Module (Join-Path ((Resolve-Path $PSScriptRoot\..\..\..).Path) "Modules\cServiceBusForWindowsServer")

        Remove-Module -Name "Microsoft.ServiceBus.Commands" -Force -ErrorAction SilentlyContinue
        Import-Module $Global:CurrentServiceBusStubModule -WarningAction SilentlyContinue

        Mock New-SBNamespace {}
        Mock Set-SBNamespace {}
        Mock Remove-SBNamespace {}

        Context "No container exists for a given database name" {
            # Arrange
            Mock Get-SBMessageContainer {
                return $null
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
                    ManageUsers = 'BUILTIN\Administrators','ServiceBusAdmins@contoso.com'
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
                    ManageUsers = 'BUILTIN\Administrators','oldServiceBusAdmins@contoso.com'
                    Name = "ContosoNamespace"
                    PrimarySymmetricKey = "RvxwTxTctasdf6KzKNfjQzjaV7oc53yUDl08ZUXQrFU="
                    SecondarySymmetricKey = "hG8ShCxVH2TdeasdfZaeULV+kxRLyah6xxYnRE/QDsM="
                    State = "Active"
                    SubscriptionId = "00000000000000000000000000000001"
                }
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
