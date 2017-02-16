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

$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'ServiceBusForWindowsServerDsc' `
    -DSCResourceName 'SBMessageContainer' `
    -TestType Unit

#endregion HEADER

function Invoke-TestSetup {
    $serviceBusCmdletModule = Join-Path -Path $PSScriptRoot -ChildPath "Stubs\ServiceBus\2.0.40512.2\Microsoft.ServiceBus.Commands.psm1" -Resolve
    Import-Module -Name $serviceBusCmdletModule -Scope 'Global' -Force
    Import-Module -Name (Join-Path -Path $moduleRoot -ChildPath "Modules\SB.Util\SB.Util.psm1") -Scope 'Global' -Force
}

function Invoke-TestCleanup {
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
}

# Begin Testing
try
{
    Invoke-TestSetup

    InModuleScope 'SBMessageContainer' {
        # Arrange
        $testSBMessageContainer = [SBMessageContainer]::new()
        $testSBMessageContainer.ContainerDBConnectionStringDataSource = "SQLSERVER.contoso.com"
        $testSBMessageContainer.ContainerDBConnectionStringInitialCatalog = "SBMessageContainer02"
        $testSBMessageContainer.Ensure = 'Present'

        Mock New-SBMessageContainer {}
        Mock Remove-SBMessageContainer {}

        Describe 'SBMessageContainer' {
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
}
finally
{
    Invoke-TestCleanup
}
