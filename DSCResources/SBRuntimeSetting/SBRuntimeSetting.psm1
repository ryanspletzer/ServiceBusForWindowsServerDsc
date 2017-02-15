using module ..\SBBase

<#
    SBRuntimeSetting modifies a Service Bus for Windows Server runtime setting.
#>
[DscResource()]
class SBRuntimeSetting : SBBase
{

    <#
        The name of the Service Bus for Windows Server configuration parameter. The valid setting names that can be
        changed are:
        DefaultMaximumQueueSizeInMegabytes – Defines the default maximum queue size in megabytes. Default value is
        '8796093022207'. Min value is '1'. Max value is '8796093022207'.
        DefaultMaximumTopicSizeInMegabytes – Defines the default maximum topic size in megabytes. Default value is
        '8796093022207'. Min value is '1'. Max value is '8796093022207'.
        MaximumNumberOfConnectionsPerEntity – Defines the maximum number of connections per entity. Use this setting
        if you have concerns that a single application may abuse the service and cause a denial of service. Default
        value is '2147483647'. Min value is '1'. Max value is '2147483647'.
        MaximumNumberOfCorrelationFiltersPerTopic – Defines the maximum number of correlation filters per topic.
        Default value is '100000'. Min value is '1'. Max value is '2147483647'.
        MaximumNumberOfQueuesPerNamespace – Defines the maximum number of queues per service namespace. Default
        value is '2147483647'. Min value is '1'. Max value is '2147483647'.
        MaximumNumberOfSqlFiltersPerTopic – Defines the maximum number of SQL filters per topic. Default value is
        '2000'. Min value is '1'. Max value is '2147483647'.
        MaximumNumberOfSubscriptionsPerTopic – Defines the maximum number of subscriptions per topic. Default value
        is '2000'. Min value is '1'. Max value is '2147483647'.
        MaximumNumberOfTopicsPerNamespace - Defines the maximum number of topics per namespace. Default value is
        '2147483647'. Min value is '1'. Max value is '2147483647'.
        MaximumQueueSizeInMegabytes – Defines the maximum queue size choices in megabytes. Default value is
        '1024;2048;3072;4096;5120;6144;7168;8192;9216;10240;8796093022207'. Min value choice is '1'. Max value choice
        is '8796093022207'.
        MaximumTopicSizeInMegabytes – Defines the maximum topic size choices in megabytes. Default value is
        '1024;2048;3072;4096;5120;6144;7168;8192;9216;10240;8796093022207'. Min value choice is '1'. Max value choice
        is '8796093022207'.
        MessageCacheSizePerEntity – Defines the message cache size per entity. Default value is '1048576000'. Min
        value is '1'. Max value is '9223372036854775807'.
        IncludeExceptionDetails – Indicates whether to include exception details. Default value is 'false'.
        DebugMode - Indicates whether debug mode is enabled. Default value is 'False'.
    #>
    [DscProperty(Key)]
    [ValidateSet(
        'DefaultMaximumQueueSizeInMegabytes',
        'DefaultMaximumTopicSizeInMegabytes',
        'MaximumNumberOfConnectionsPerEntity',
        'MaximumNumberOfCorrelationFiltersPerTopic',
        'MaximumNumberOfQueuesPerNamespace',
        'MaximumNumberOfSqlFiltersPerTopic',
        'MaximumNumberOfSubscriptionsPerTopic',
        'MaximumNumberOfTopicsPerNamespace',
        'MaximumQueueSizeInMegabytes',
        'MaximumTopicSizeInMegabytes',
        'MessageCacheSizePerEntity',
        'IncludeExceptionDetails',
        'DebugMode'
    )]
    [string]
    $Name

    <#
        The value to change for the given setting. Depending on the setting type, the value should be of the same
        type. For example, if the setting is an integer type then the value is expected to be a string that
        represents an integer range from 1 to long.MaxValue (inclusive) although this varies by setting (see Name
        above for details).
    #>
    [DscProperty(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Value

    [SBRuntimeSetting] Get()
    {
        $result = [SBRuntimeSetting]::new()

        Write-Verbose -Message "Checking for SBRuntimeSetting $($this.Name)."

        $sbRuntimeSetting = $null
        try
        {
            $sbRuntimeSetting = Get-SBRuntimeSetting -Name $this.Name
            Write-Verbose "Successfully retrieved SBRuntimeSetting $($this.Name)"
        }
        catch
        {
            Write-Verbose "Unable to retrieve SBRuntimeSetting $($this.Name)"
        }

        if ($null -eq $sbRuntimeSetting)
        {
            return $result
        }

        $result.Name = $this.Name
        $result.Value = $sbRuntimeSetting.Value

        return $result
    }

    [bool] Test()
    {
        $current = $this.Get()

        if ($null -eq $current)
        {
            return $false
        }

        if ($this.SBRuntimeSettingShouldBeUpdated($current))
        {
            return $false
        }

        return $true
    }

    [bool] SBRuntimeSettingShouldBeUpdated([SBRuntimeSetting] $Current)
    {
        return ($Current.Value -ne $this.Value)
    }

    [void] Set()
    {
        Write-Verbose -Message "Validating SBRuntimeSetting $($this.Name) for value $($this.Value)."

        if ($this.Name -in @( 'IncludeExceptionDetails', 'DebugMode' ))
        {
            $result = $null
            if (![Boolean]::TryParse($this.Value, [ref] $result))
            {
                throw "String setting for $($this.Name) is not a boolean value."
                return
            }
        }

        $int64Result = $null
        if ($this.Name -in @(
                'DefaultMaximumQueueSizeInMegabytes',
                'DefaultMaximumTopicSizeInMegabytes',
                'MessageCacheSizePerEntity'
            ))
        {
            if (![Int64]::TryParse($this.Value, [ref] $int64Result))
            {
                throw "String setting for $($this.Name) is not an Int64 value."
                return
            }

            if ($this.Name -in @( 'DefaultMaximumQueueSizeInMegabytes', 'DefaultMaximumTopicSizeInMegabytes'))
            {
                if (($int64Result -lt 1) -or
                    ($int64Result -gt 8796093022207))
                {
                    throw "String setting for $($this.Name) not between 1 and 8796093022207."
                    return
                }
            }

            if ($this.Name -in @( 'MessageCacheSizePerEntity' ))
            {
                if ($int64Result -lt 1)
                {
                    throw "String setting for $($this.Name) not between 1 and 9223372036854775807."
                    return
                }
            }
        }

        if ($this.Name -in @( 'MaximumQueueSizeInMegabytes', 'MaximumTopicSizeInMegabytes' ))
        {
            $stringArray = $this.Value.Split(';')
            ForEach ($string in $stringArray)
            {
                $int64Result = $null
                if (![Int64]::TryParse($this.Value, [ref] $int64Result))
                {
                    throw ("String setting for $($this.Name) must be an enumerable set of Int64 values separated " +
                           "by semicolon characters. $($this.Value) is an invalid value.")
                    return
                }

                if (($int64Result -lt 1) -or
                    ($int64Result -gt 8796093022207))
                {
                    throw ("Int64 value $int64Result in $($this.Value) for $($this.Name) is not between 1 and " +
                           "8796093022207.")
                    return
                }
            }
        }

        $int32Result = $null
        if ($this.Name -in @(
                'MaximumNumberOfConnectionsPerEntity',
                'MaximumNumberOfCorrelationFiltersPerTopic',
                'MaximumNumberOfQueuesPerNamespace',
                'MaximumNumberOfSqlFiltersPerTopic',
                'MaximumNumberOfSubscriptionsPerTopic',
                'MaximumNumberOfTopicsPerNamespace'
            ))
        {
            if (![Int32]::TryParse($this.Value, $int32Result))
            {
                throw "String setting for $($this.Name) is not an Int32 value."
                return
            }

            if ($int32Result -lt 1)
            {
                throw "String setting for $($this.Name) not between 1 and 2147483647."
                return
            }
        }

        Write-Verbose -Message "Setting SBRuntimeSetting $($this.Name) to value $($this.Value)."
        Set-SBRuntimeSetting -Name $this.Name -Value $this.Value
        Write-Verbose -Message "Restarting SBFarm services for SBRuntimeSetting to take effect."
        Stop-SBFarm
        Start-SBFarm
    }
}
