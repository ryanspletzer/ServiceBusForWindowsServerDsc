[CmdletBinding()]
param(
    [string]
    $ServiceBusCmdletModule = (Join-Path -Path $PSScriptRoot -ChildPath "Stubs\ServiceBus\2.0.40512.2\Microsoft.ServiceBus.Commands.psm1" -Resolve)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path -Path $PSScriptRoot\..\..).Path
$Global:CurrentServiceBusStubModule = $ServiceBusCmdletModule

$DscResourceName = "SBMessageContainer"
Import-Module -Name (Join-Path -Path $RepoRoot -ChildPath "DSCClassResources\$DscResourceName\$DscResourceName.psm1") -Scope Global -Force
Import-Module -Name (Join-Path -Path $RepoRoot -ChildPath "Modules\SB.Util\SB.Util.psm1") -Scope Global -Force

Describe $DscResourceName {
    InModuleScope -Module $DscResourceName {
        # Arrange
        $testSBMessageContainer = [SBMessageContainer]::new()
        $testSBMessageContainer.ContainerDBConnectionStringDataSource = "SQLSERVER.contoso.com"
        $testSBMessageContainer.ContainerDBConnectionStringInitialCatalog = "SBMessageContainer02"
        $testSBMessageContainer.Ensure = 'Present'

        Remove-Module -Name "Microsoft.ServiceBus.Commands" -Force -ErrorAction SilentlyContinue
        Import-Module $Global:CurrentServiceBusStubModule -WarningAction SilentlyContinue

        Mock New-SBMessageContainer {}
        Mock Remove-SBMessageContainer {}

        Context "No container exists for a given database name" {
            # Arrange
            Mock Get-SBMessageContainer {
                return $null
            }

            It "returns object with Ensure = Absent from the Get method" {
                # Act
                $currentValues = $testSBMessageContainer.Get()

                # Arrange
                $currentValues.Ensure | Should BeExactly 'Absent'
            }

            It "returns false from the Test method" {
                # Act | Assert
                $testSBMessageContainer.Test() | Should Be $false
            }

            It "calls the New-SBMessageContainer cmdlet in the Set method" {
                # Act
                $testSBMessageContainer.Set()

                # Assert
                Assert-MockCalled -CommandName New-SBMessageContainer
            }
        }

        Context "Container exists for a given database name and should be removed" {
            # Arrange
            Mock Get-SBMessageContainer {
                return @(
                    @{
                        Id = 1
                        Status = 'Active'
                        Host = 'servicebus01.contoso.com'
                        DatabaseServer = 'SQLSERVER.contoso.com'
                        DatabaseName = 'SBMessageContainer01'
                        ConnectionString = 'Data Source=SQLSERVER.contoso.com;Initial Catalog=SBMessageContainer01;Integrated Security=True;Encrypt=False'
                        EntitiesCount = 0
                        DatabaseSizeInMB = 6.25
                    },
                    @{
                        Id = 2
                        Status = 'Active'
                        Host = 'servicebus02.contoso.com'
                        DatabaseServer = 'SQLSERVER.contoso.com'
                        DatabaseName = 'SBMessageContainer02'
                        ConnectionString = 'Data Source=SQLSERVER.contoso.com;Initial Catalog=SBMessageContainer02;Integrated Security=True;Encrypt=False'
                        EntitiesCount = 0
                        DatabaseSizeInMB = 6.25
                    },
                    @{
                        Id = 3
                        Status = 'Active'
                        Host = 'servicebus03.contoso.com'
                        DatabaseServer = 'SQLSERVER.contoso.com'
                        DatabaseName = 'SBMessageContainer03'
                        ConnectionString = 'Data Source=SQLSERVER.contoso.com;Initial Catalog=SBMessageContainer03;Integrated Security=True;Encrypt=False'
                        EntitiesCount = 0
                        DatabaseSizeInMB = 6.25
                    }
                )
            }

            $testSBMessageContainer.Ensure = 'Absent'

            It "returns object with Ensure = Present from the Get method" {
                # Act
                $currentValues = $testSBMessageContainer.Get()

                # Assert
                $currentValues.Ensure | Should Be 'Present'
            }

            It "returns false from the Test method" {
                # Act | Assert
                $testSBMessageContainer.Test() | Should Be $false
            }

            It "calls Get-SBMessageContainer cmdlet in the Set method to retreive Id" {
                # Act
                $testSBMessageContainer.Set()

                # Assert
                Assert-MockCalled -CommandName Get-SBMessageContainer
            }

            It "calls the Remove-SBMessageContainer cmdlet in the Set method" {
                # Act
                $testSBMessageContainer.Set()

                # Assert
                Assert-MockCalled -CommandName Remove-SBMessageContainer
            }

            # Cleanup
            $testSBMessageContainer.Ensure = 'Present'
        }
    }
}
