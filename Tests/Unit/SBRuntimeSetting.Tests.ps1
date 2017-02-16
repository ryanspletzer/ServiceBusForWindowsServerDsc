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
Get-Module -All | Where-Object{$_.Name -eq 'SBRuntimeSetting'} | Remove-Module -Force -ErrorAction SilentlyContinue
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'ServiceBusForWindowsServerDsc' `
    -DSCResourceName 'SBRuntimeSetting' `
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

    InModuleScope 'SBRuntimeSetting' {
        # Arrange
        $testSBRuntimeSetting = [SBRuntimeSetting]::new()

        Mock Set-SBRuntimeSetting {}
        Mock Stop-SBFarm {}
        Mock Start-SBFarm {}

        Describe 'SBRuntimeSetting' {
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
}
finally
{
    Invoke-TestCleanup
}
