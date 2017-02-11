[CmdletBinding()]
param(
    [string]
    $ServiceBusCmdletModule = (Join-Path -Path $PSScriptRoot -ChildPath "Stubs\ServiceBus\2.0.40512.2\Microsoft.ServiceBus.Commands.psm1" -Resolve)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path -Path $PSScriptRoot\..\..).Path
$Global:CurrentServiceBusStubModule = $ServiceBusCmdletModule

$DscResourceName = "SBHostCEIP"
Remove-Module -Name $DscResourceName -Force -ErrorAction SilentlyContinue
Import-Module -Name (
    Join-Path -Path $RepoRoot -ChildPath "DSCClassResources\$DscResourceName\$DscResourceName.psm1") -Scope Global -Force

Describe $DscResourceName {
    InModuleScope -Module $DscResourceName {
        # Arrange
        $testSBHostCEIP = [SBHostCEIP]::new()

        Remove-Module -Name "Microsoft.ServiceBus.Commands" -Force -ErrorAction SilentlyContinue
        Import-Module $Global:CurrentServiceBusStubModule -WarningAction SilentlyContinue

        $getSBHostCEIPDisabled1 = "You have declined to participate in the Customer Experience Improvement Program."
        $getSBHostCEIPEnabled1 = "You have chosen to participate in the Customer Experience Improvement Program."
        $getSBHostCEIP2 = @(
            "For more information, please visit http://go.microsoft.com/fwlink/?linkid=52095.",
            "For Windows privacy information, http://go.microsoft.com/fwlink/?linkID=104288"
        )
        $getSBHostCEIP3 = @(
            ("Help improve Service Bus. Join the Customer Experience Improvement Program and help improve the " +
             "quality, reliability, and performance"),
            "of Microsoft software and services. If you choose to participate:",
            "Microsoft will",
            "    Collect information about your software and hardware configurations.",
            ("    Collect information on how you use our software and services to identity trends and usage " +
             "patterns."),
            "Microsoft will not",
            "    Collect your name, address, or any other personally identifiable information.",
            "    Collect your source code.",
            "    Ask you to take surveys, nor will you be contacted by a sales representative.",
            "    Prompt you with additional messages that might interrupt your work."
        )

        Mock Enable-SBHostCEIP {}
        Mock Disable-SBHostCEIP {}

        Context "Customer Experience Improvement Program telemetry is disabled and should be enabled" {
            # Arrange
            Mock Get-SBAuthorizationRule {
                Write-Output -InputObject $getSBHostCEIPDisabled1
                Write-Output -InputObject $getSBHostCEIP2
                Write-Output -InputObject $getSBHostCEIP3
            }

            $testSBHostCEIP.Ensure = 'Present'

            It "returns object with Ensure = Absent from the Get method" {
                # Act
                $currentValues = $testSBHostCEIP.Get()

                # Assert
                $currentValues.Ensure | Should BeExactly 'Absent'
            }

            It "returns false from the Test method" {
                # Act | Assert
                $testSBHostCEIP.Test() | Should Be $false
            }

            It "calls the Enable-SBHostCEIP cmdlet in the Set method" {
                # Act
                $testSBHostCEIP.Set()

                # Assert
                Assert-MockCalled -CommandName Enable-SBHostCEIP
            }
        }

        Context "Customer Experience Improvement Program telemetry is enabled and should be disabled" {
            # Arrange
            Mock Get-SBHostCEIP {
                Write-Output -InputObject $getSBHostCEIPEnabled1
                Write-Output -InputObject $getSBHostCEIP2
                Write-Output -InputObject $getSBHostCEIP3
            }

            $testSBHostCEIP.Ensure = 'Absent'

            It "returns object with Ensure = Present from the Get method" {
                # Act
                $currentValues = $testSBHostCEIP.Get()

                # Assert
                $currentValues.Ensure | Should Be 'Present'
            }

            It "returns false from the Test method" {
                # Act | Assert
                $testSBHostCEIP.Test() | Should Be $false
            }

            It "calls the Disable-SBHostCEIP cmdlet in the Set method" {
                # Act
                $testSBHostCEIP.Set()

                # Assert
                Assert-MockCalled -CommandName Disable-SBHostCEIP
            }
        }
    }
}
