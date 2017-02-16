#region HEADER

# Unit Test Template Version: 1.2.0
$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

# Deviating from test template to accomodate copying DSC class resources for tests
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResources'))) )
{
    Copy-Item -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCClassResources')`
        -Destination (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResources') -Container -Recurse
}

Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath (Join-Path -Path 'DSCResource.Tests' -ChildPath 'TestHelper.psm1')) -Force

# Deviating from test template to accomodate copying DSC class resources for tests
Remove-Module -Name 'SBHostCEIP' -Force -ErrorAction SilentlyContinue
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'ServiceBusForWindowsServerDsc' `
    -DSCResourceName 'SBHostCEIP' `
    -TestType Unit

#endregion HEADER

function Invoke-TestSetup {
    $serviceBusCmdletModule = Join-Path -Path $PSScriptRoot -ChildPath "Stubs\ServiceBus\2.0.40512.2\Microsoft.ServiceBus.Commands.psm1" -Resolve
    Import-Module -Name $serviceBusCmdletModule -Scope 'Global' -Force
}

function Invoke-TestCleanup {
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
}

# Begin Testing
try
{
    Invoke-TestSetup

    InModuleScope 'SBHostCEIP' {
        # Arrange
        $testSBHostCEIP = [SBHostCEIP]::new()

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

        Describe 'SBHostCEIP' {
            Context "Customer Experience Improvement Program telemetry is disabled and should be enabled" {
                # Arrange
                Mock Get-SBHostCEIP {
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
}
finally
{
    Invoke-TestCleanup
}
