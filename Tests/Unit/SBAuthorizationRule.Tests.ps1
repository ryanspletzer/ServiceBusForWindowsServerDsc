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

$DscResourceName = "SBAuthorizationRule"
Remove-Module -Name $DscResourceName -Force -ErrorAction SilentlyContinue
Import-Module -Name (Join-Path -Path $RepoRoot -ChildPath "DSCClassResources\$DscResourceName\$DscResourceName.psm1") -Scope Global -Force

Describe $DscResourceName {
    InModuleScope -Module $DscResourceName {
        # Arrange
        $testSBAuthorizationRule = [SBAuthorizationRule]::new()
        $testSBAuthorizationRule.Name = "Test"
        $testSBAuthorizationRule.NamespaceName = "TestNamespace"
        $testSBAuthorizationRule.Ensure = 'Present'

        Remove-Module -Name "Microsoft.ServiceBus.Commands" -Force -ErrorAction SilentlyContinue
        Import-Module $Global:CurrentServiceBusStubModule -WarningAction SilentlyContinue

        Mock New-SBAuthorizationRule {}
        Mock Remove-SBAuthorizationRule {}
        Mock Set-SBAuthorizationRule {}

        Context "No authorization rule exists for a given name and namespace and should be created" {
            # Arrange
            Mock Get-SBAuthorizationRule {
                throw ("Authorization rule $($this.Name) does not exist in namespace $($this.NamespaceName).")
            }

            It "returns object with Ensure = Absent from the Get method" {
                # Act
                $currentValues = $testSBAuthorizationRule.Get()

                # Arrange
                $currentValues.Ensure | Should BeExactly 'Absent'
            }

            It "returns false from the Test method" {
                # Act | Assert
                $testSBAuthorizationRule.Test() | Should Be $false
            }

            It "calls the New-SBAuthorizationRule cmdlet in the Set method" {
                # Act
                $testSBAuthorizationRule.Set()

                # Assert
                Assert-MockCalled -CommandName New-SBAuthorizationRule
            }
        }

        Context "Authorization rule exists for a given name and name and should be removed" {
            # Arrange
            $createdTime = [datetime]::Now
            Mock Get-SBAuthorizationRule {
                return @{
                    KeyName = "Test"
                    PrimaryKey = "hG8ShCxVH2TdeasdfZaeULV+kxRLyah6xxYnRE/QDsM="
                    SecondaryKey = "RvxwTxTctasdf6KzKNfjQzjaV7oc53yUDl08ZUXQrFU="
                    Rights = 'Listen','Send','Manage'
                    CreatedTime = $createdTime
                    ModifiedTime = $createdTime
                    ConnectionString = ("Endpoint=sb://servicebus.contoso.com/TestNamespace;" +
                                        "StsEndpoint=https://servicebus.contoso.com:9355/TestNamespace;" +
                                        "RuntimePort=9354;ManagementPort=9355;SharedAccessKeyName=Test;" +
                                        "SharedAccessKey=RvxwTxTctasdf6KzKNfjQzjaV7oc53yUDl08ZUXQrFU=")
                }
            }

            $testSBAuthorizationRule.Ensure = 'Absent'

            It "returns object with Ensure = Present from the Get method" {
                # Act
                $currentValues = $testSBAuthorizationRule.Get()

                # Assert
                $currentValues.Ensure | Should Be 'Present'
            }

            It "returns false from the Test method" {
                # Act | Assert
                $testSBAuthorizationRule.Test() | Should Be $false
            }

            It "calls the Remove-SBNamespace cmdlet in the Set method" {
                # Act
                $testSBAuthorizationRule.Set()

                # Assert
                Assert-MockCalled -CommandName Remove-SBAuthorizationRule
            }

            # Cleanup
            $testSBAuthorizationRule.Ensure = 'Present'
        }

        Context "Authorization rule exists for a given name and name and should be updated" {
            # Arrange
            $createdTime = [datetime]::Now
            Mock Get-SBAuthorizationRule {
                return @{
                    KeyName = "Test"
                    PrimaryKey = "hG8ShCxVH2TdeasdfZaeULV+kxRLyah6xxYnRE/QDsM="
                    SecondaryKey = "RvxwTxTctasdf6KzKNfjQzjaV7oc53yUDl08ZUXQrFU="
                    Rights = 'Listen','Send'
                    CreatedTime = $createdTime
                    ModifiedTime = $createdTime
                    ConnectionString = ("Endpoint=sb://servicebus.contoso.com/TestNamespace;" +
                                        "StsEndpoint=https://servicebus.contoso.com:9355/TestNamespace;" +
                                        "RuntimePort=9354;ManagementPort=9355;SharedAccessKeyName=Test;" +
                                        "SharedAccessKey=RvxwTxTctasdf6KzKNfjQzjaV7oc53yUDl08ZUXQrFU=")
                }
            }

            $testSBAuthorizationRule.Rights = [AccessRight[]]('Listen','Send','Manage')

            It "returns object with Ensure = Present from the Get method" {
                # Act
                $currentValues = $testSBAuthorizationRule.Get()

                # Assert
                $currentValues.Ensure | Should Be 'Present'
            }

            It "returns false from the Test method" {
                # Act | Assert
                $testSBAuthorizationRule.Test() | Should Be $false
            }

            It "calls the Set-SBNamespace cmdlet in the Set method" {
                # Act
                $testSBAuthorizationRule.Set()

                # Assert
                Assert-MockCalled -CommandName Set-SBAuthorizationRule
            }
        }
    }
}
