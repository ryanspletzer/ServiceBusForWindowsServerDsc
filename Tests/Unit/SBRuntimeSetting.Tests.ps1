[CmdletBinding()]
param(
    [string]
    $ServiceBusCmdletModule = (Join-Path -Path $PSScriptRoot -ChildPath "Stubs\ServiceBus\2.0.40512.2\Microsoft.ServiceBus.Commands.psm1" -Resolve)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path -Path $PSScriptRoot\..\..).Path
$Global:CurrentServiceBusStubModule = $ServiceBusCmdletModule

$DscResourceName = "SBRuntimeSetting"
Remove-Module -Name $DscResourceName -Force -ErrorAction SilentlyContinue
Import-Module -Name (
    Join-Path -Path $RepoRoot -ChildPath "DSCResources\$DscResourceName\$DscResourceName.psm1"
) -Scope Global -Force

Describe $DscResourceName {
    InModuleScope -Module $DscResourceName {
        # Arrange
        $testSBRuntimeSetting = [SBRuntimeSetting]::new()

        Remove-Module -Name "Microsoft.ServiceBus.Commands" -Force -ErrorAction SilentlyContinue
        Import-Module $Global:CurrentServiceBusStubModule -WarningAction SilentlyContinue

        Mock Set-SBRuntimeSetting {}
        Mock Stop-SBFarm {}
        Mock Start-SBFarm {}

        Context "Runtime setting exists and needs to be updated" {
            # Arrange
            Mock Get-SBRuntimeSetting {
                return @{
                    Name  = 'DefaultMaximumQueueSizeInMegabytes'
                    Value = '8796093022207'
                }
            }

            $testSBRuntimeSetting.Name = 'DefaultMaximumQueueSizeInMegabytes'
            $testSBRuntimeSetting.Value = '10240'

            It "returns expected name and value from the Get method" {
                # Act
                $current = $testSBRuntimeSetting.Get()

                # Assert
                $current.Name | Should BeExactly 'DefaultMaximumQueueSizeInMegabytes'
                $current.Value | Should BeExactly '8796093022207'
            }

            It "returns false from the Test method" {
                # Act | Assert
                $testSBRuntimeSetting.Test() | Should Be $false
            }

            It "calls the Set-SBRuntimeSetting cmdlet in the Set method" {
                # Act
                $testSBRuntimeSetting.Set()

                # Assert
                Assert-MockCalled -CommandName Set-SBRuntimeSetting
            }

            It "calls the Stop-SBFarm cmdlet in the Set method" {
                # Act
                $testSBRuntimeSetting.Set()

                # Assert
                Assert-MockCalled -CommandName Stop-SBFarm
            }

            It "calls the Start-SBFarm cmdlet in the Set method" {
                # Act
                $testSBRuntimeSetting.Set()

                # Assert
                Assert-MockCalled -CommandName Start-SBFarm
            }
        }
    }
}
