$outputPath = 'C:\Program Files\WindowsPowerShell\Configuration\Schema'
. 'C:\Program Files\WindowsPowerShell\Modules\ServiceBusForWindowsServerDsc\Examples\PushMetaConfig.ps1'
PushMetaConfig -OutputPath $outputPath
Set-DscLocalConfigurationManager -Path $outputPath -Force -Verbose

. 'C:\Program Files\WindowsPowerShell\Modules\ServiceBusForWindowsServerDsc\Examples\SingleServerconfig.ps1'
$configurationData = 'C:\Program Files\WindowsPowerShell\Modules\ServiceBusForWindowsServerDsc\Examples\SingleServerConfig.psd1'
Example -OutputPath $outputPath -ConfigurationData $configurationData
Start-DscConfiguration -Wait -Force -Path $outputPath -Verbose
