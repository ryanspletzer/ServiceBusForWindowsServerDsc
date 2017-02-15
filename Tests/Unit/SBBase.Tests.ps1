using module ..\..\DSCResources\SBFarm

#region HEADER

# Unit Test Template Version: 1.2.0
$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath (Join-Path -Path 'DSCResource.Tests' -ChildPath 'TestHelper.psm1')) -Force

$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'ServiceBusForWindowsServerDsc' `
    -DSCResourceName 'SBBase' `
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

    InModuleScope 'SBBase' {
        # Arrange
        $testSBFarm = [SBFarm]::new()
        $adminApiCredentialParams = @{
            TypeName     = 'System.Management.Automation.PSCredential'
            ArgumentList = @( "adminUser", (ConvertTo-SecureString -String "password" -AsPlainText -Force) )
        }
        $testSBFarm.AdminApiCredentials = New-Object @adminApiCredentialParams
        $testSBFarm.EncryptionCertificateThumbprint = '62C99D4B5711E2482A5A1AECE6F8D05231D5678D'
        $testSBFarm.FarmCertificateThumbprint = '62C99D4B5711E2482A5A1AECE6F8D05231D5678D'
        $testSBFarm.FarmDNS = 'servicebus.contoso.com'
        $testSBFarm.RunAsAccount = "servicebus@contoso"
        $testSBFarm.SBFarmDBConnectionStringDataSource = 'SQLSERVER.contoso.com'
        $tenantApiCredentialParams = @{
            TypeName     = 'System.Management.Automation.PSCredential'
            ArgumentList = @( "tenantUser", (ConvertTo-SecureString -String "password" -AsPlainText -Force) )
        }
        $testSBFarm.TenantApiCredentials = New-Object @tenantApiCredentialParams

        Describe 'SBBase' {
            Context 'Base methods' {
                It 'ToHashtable() returns class properties as a hashtable' {
                    # Arrange
                    $hashtable = $testSBFarm.ToHashtable()

                    $propertyCount = 0

                    # Act
                    Get-Member -InputObject $testSBFarm |
                        Where-Object MemberType -eq 'Property' |
                        ForEach-Object{
                            # Assert
                            $hashtable[$_.Name] | Should BeExactly $testSBFarm.($_.Name)
                            $propertyCount += 1
                        }

                    # Assert
                    $hashtable.Keys.Count | Should BeExactly $propertyCount
                }

                It 'GetProperty() returns property value' {
                    # Act | Assert
                    $testSBFarm.GetProperty('RunAsAccount') | Should BeExactly 'servicebus@contoso'
                }

                It 'SetProperty() sets property value' {
                    # Act
                    $testSBFarm.SetProperty('RunAsAccount','servicebus2@contoso.com')
                    $value = [string]$testSBFarm.RunAsAccount

                    # Assert
                    $value | Should BeExactly 'servicebus2@contoso.com'

                    # Cleanup
                    $testSBFarm.RunAsAccount = 'servicebus@contoso.com'
                }

                It 'GetDscNotConfigurablePropertiesAsHashtable() returns not configurable properties as a hashtable' {
                    # Act
                    $hashtable = $testSBFarm.GetDscNotConfigurablePropertiesAsHashtable()

                    # Assert
                    $hashtable.Count | Should BeExactly 9
                }

                It 'GetDscConfigurablePropertiesAsHashtable() returns configurable properties as a hashtable' {
                    # Act
                    $hashtable = $testSBFarm.GetDscConfigurablePropertiesAsHashtable()

                    # Assert
                    $hashtable.Count | Should BeExactly 30
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}
