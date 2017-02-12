#
# xServiceBusForWindowsServer.Util.psm1
#
# Credit to xSharePoint DSC Resource module for test harness approach in this file:
#
# https://github.com/PowerShell/xSharePoint/blob/dev/Tests/xSharePoint.TestHarness.psm1
#

function Invoke-ServiceBusForWindowsServerDscTests() {
    param (
        [Parameter(Mandatory=$false)]
        [string]
        $testResultsFile
    )

    $repoDir = Join-Path -Path $PSScriptRoot -ChildPath "..\" -Resolve

    $testCoverageFiles = @()
    Get-ChildItem -Path "$repoDir\Modules\ServiceBusForWindowsServerDsc\**\*.psm1" -Recurse | ForEach-Object {
        $testCoverageFiles += $_.FullName
    }

    $testResultSettings = @{}
    if ([string]::IsNullOrEmpty($testResultsFile) -eq $false) {
        $testResultSettings.Add("OutputFormat", "NUnitXml")
        $testResultSettings.Add("OutputFile", $testResultsFile)
    }
    Import-Module -Name "$repoDir\Modules\ServiceBusForWindowsServerDsc\ServiceBusForWindowsServerDsc.psd1"

    $results = Invoke-Pester -Script @(
        @{
            "Path"       = "$repoDir\Tests"
            "Parameters" = @{
                "ServiceBusCmdletModule" = (Join-Path -Path $repoDir -ChildPath "\Tests\Stubs\ServiceBus\2.0.0.0\Microsoft.ServiceBus.Commands.psm1")
            }
        }
    ) -CodeCoverage $testCoverageFiles -PassThru @testResultSettings

    return $results
}
