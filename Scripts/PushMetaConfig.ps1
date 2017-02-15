[DscLocalConfigurationManager()]
Configuration PushMetaConfig
{
    Node 'localhost'
    {
        Settings
        {
            ActionAfterReboot = 'StopConfiguration'
            ConfigurationModeFrequencyMins = 15
            RebootNodeIfNeeded = $True
            ConfigurationMode = 'ApplyAndMonitor'
            RefreshMode = 'Push'
            RefreshFrequencyMins = 30
            AllowModuleOverwrite = $False
            DebugMode = 'All'
            StatusRetentionTimeInDays = 10
        }
    }
}
