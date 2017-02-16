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
Remove-Module -Name 'SBAuthorizationRule' -Force -ErrorAction SilentlyContinue
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'ServiceBusForWindowsServerDsc' `
    -DSCResourceName 'SBAuthorizationRule' `
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

    InModuleScope 'SBAuthorizationRule' {
        # Arrange
        $testSBAuthorizationRule = [SBAuthorizationRule]::new()
        $testSBAuthorizationRule.Name = "Test"
        $testSBAuthorizationRule.NamespaceName = "TestNamespace"
        $testSBAuthorizationRule.Ensure = 'Present'

        Mock New-SBAuthorizationRule {}
        Mock Remove-SBAuthorizationRule {}
        Mock Set-SBAuthorizationRule {}

        Describe 'SBAuthorizationRule' {
            Context "No authorization rule exists for a given name and namespace and should be created" {
                # Arrange
                Mock Get-SBAuthorizationRule {
                    throw ("Authorization rule $($this.Name) does not exist in namespace $($this.NamespaceName).")
                }

                It "returns object with Ensure = Absent from the Get method" {
                    # Act
                    $currentValues = $testSBAuthorizationRule.Get()

                    # Assert
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
                        KeyName          = "Test"
                        PrimaryKey       = "hG8ShCxVH2TdeasdfZaeULV+kxRLyah6xxYnRE/QDsM="
                        SecondaryKey     = "RvxwTxTctasdf6KzKNfjQzjaV7oc53yUDl08ZUXQrFU="
                        Rights           = 'Listen','Send','Manage'
                        CreatedTime      = $createdTime
                        ModifiedTime     = $createdTime
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
                        KeyName          = "Test"
                        PrimaryKey       = "hG8ShCxVH2TdeasdfZaeULV+kxRLyah6xxYnRE/QDsM="
                        SecondaryKey     = "RvxwTxTctasdf6KzKNfjQzjaV7oc53yUDl08ZUXQrFU="
                        Rights           = 'Listen','Send'
                        CreatedTime      = $createdTime
                        ModifiedTime     = $createdTime
                        ConnectionString = ("Endpoint=sb://servicebus.contoso.com/TestNamespace;" +
                                            "StsEndpoint=https://servicebus.contoso.com:9355/TestNamespace;" +
                                            "RuntimePort=9354;ManagementPort=9355;SharedAccessKeyName=Test;" +
                                            "SharedAccessKey=RvxwTxTctasdf6KzKNfjQzjaV7oc53yUDl08ZUXQrFU=")
                    }
                }

                $testSBAuthorizationRule.Rights = [string[]]('Listen','Send','Manage')

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
}
finally
{
    Invoke-TestCleanup
}
