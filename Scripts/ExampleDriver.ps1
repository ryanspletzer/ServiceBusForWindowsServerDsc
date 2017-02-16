$outputPath = 'C:\Program Files\WindowsPowerShell\Configuration\Schema'
. 'C:\Program Files\WindowsPowerShell\Modules\ServiceBusForWindowsServerDsc\ExampleHelpers\PushMetaConfig.ps1'
PushMetaConfig -OutputPath $outputPath
Set-DscLocalConfigurationManager -Path $outputPath -Force -Verbose

. 'C:\Program Files\WindowsPowerShell\Modules\ServiceBusForWindowsServerDsc\Examples\Single Server\ServiceBusForWindowsServer.ps1'
Example -OutputPath $outputPath -ConfigurationData $ConfigurationData
Start-DscConfiguration -Wait -Force -Path $outputPath -Verbose
