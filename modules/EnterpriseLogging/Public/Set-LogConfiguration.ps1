function Set-LogConfiguration {
    <#
    .SYNOPSIS
        Configures logging behavior for the EnterpriseLogging module.

    .DESCRIPTION
        Updates module-level logging configuration including log path,
        log levels, SIEM integration, and Event Log settings.

    .PARAMETER LogPath
        Directory path for log files.

    .PARAMETER LogLevel
        Minimum log level to capture: Debug, Information, Warning, Error, Critical.

    .PARAMETER MaxLogSizeMB
        Maximum size of individual log files in megabytes before rotation.

    .PARAMETER MaxLogFiles
        Maximum number of rotated log files to retain.

    .PARAMETER EnableEventLog
        Enable or disable Windows Event Log integration.

    .PARAMETER EnableFileLog
        Enable or disable file-based logging.

    .PARAMETER EnableSIEM
        Enable or disable SIEM forwarding.

    .PARAMETER SIEMEndpoint
        SIEM endpoint URL for log forwarding.

    .PARAMETER SIEMToken
        Authentication token for SIEM endpoint.

    .PARAMETER SIEMType
        Type of SIEM: Splunk, Elasticsearch, AzureSentinel, Generic.

    .EXAMPLE
        Set-LogConfiguration -LogPath "D:\Logs\Enterprise" -LogLevel Warning

    .EXAMPLE
        Set-LogConfiguration -EnableSIEM $true -SIEMEndpoint "https://splunk.company.com:8088/services/collector" -SIEMToken $token -SIEMType Splunk

    .EXAMPLE
        Set-LogConfiguration -MaxLogSizeMB 100 -MaxLogFiles 30
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateScript({
            if (Test-Path $_ -PathType Container) { $true }
            else { throw "Log path does not exist: $_" }
        })]
        [string]$LogPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Debug', 'Information', 'Warning', 'Error', 'Critical')]
        [string]$LogLevel,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1024)]
        [int]$MaxLogSizeMB,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100)]
        [int]$MaxLogFiles,

        [Parameter(Mandatory = $false)]
        [bool]$EnableEventLog,

        [Parameter(Mandatory = $false)]
        [bool]$EnableFileLog,

        [Parameter(Mandatory = $false)]
        [bool]$EnableSIEM,

        [Parameter(Mandatory = $false)]
        [ValidatePattern('^https?://')]
        [string]$SIEMEndpoint,

        [Parameter(Mandatory = $false)]
        [string]$SIEMToken,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Splunk', 'Elasticsearch', 'AzureSentinel', 'Generic')]
        [string]$SIEMType
    )

    process {
        $changes = @()

        if ($PSBoundParameters.ContainsKey('LogPath')) {
            $script:LogConfiguration.LogPath = $LogPath
            $changes += "LogPath = $LogPath"
        }

        if ($PSBoundParameters.ContainsKey('LogLevel')) {
            $script:LogConfiguration.LogLevel = $LogLevel
            $changes += "LogLevel = $LogLevel"
        }

        if ($PSBoundParameters.ContainsKey('MaxLogSizeMB')) {
            $script:LogConfiguration.MaxLogSizeMB = $MaxLogSizeMB
            $changes += "MaxLogSizeMB = $MaxLogSizeMB"
        }

        if ($PSBoundParameters.ContainsKey('MaxLogFiles')) {
            $script:LogConfiguration.MaxLogFiles = $MaxLogFiles
            $changes += "MaxLogFiles = $MaxLogFiles"
        }

        if ($PSBoundParameters.ContainsKey('EnableEventLog')) {
            $script:LogConfiguration.EnableEventLog = $EnableEventLog
            $changes += "EnableEventLog = $EnableEventLog"
        }

        if ($PSBoundParameters.ContainsKey('EnableFileLog')) {
            $script:LogConfiguration.EnableFileLog = $EnableFileLog
            $changes += "EnableFileLog = $EnableFileLog"
        }

        if ($PSBoundParameters.ContainsKey('EnableSIEM')) {
            $script:LogConfiguration.EnableSIEM = $EnableSIEM
            $changes += "EnableSIEM = $EnableSIEM"
        }

        if ($PSBoundParameters.ContainsKey('SIEMEndpoint')) {
            $script:LogConfiguration.SIEMEndpoint = $SIEMEndpoint
            $changes += "SIEMEndpoint = $SIEMEndpoint"
        }

        if ($PSBoundParameters.ContainsKey('SIEMToken')) {
            $script:LogConfiguration.SIEMToken = $SIEMToken
            $changes += "SIEMToken = [REDACTED]"
        }

        if ($PSBoundParameters.ContainsKey('SIEMType')) {
            $script:LogConfiguration.SIEMType = $SIEMType
            $changes += "SIEMType = $SIEMType"
        }

        if ($changes.Count -gt 0) {
            Write-Verbose "Log configuration updated: $($changes -join ', ')"
        }

        # Return current configuration
        return [PSCustomObject]@{
            LogPath          = $script:LogConfiguration.LogPath
            LogLevel         = $script:LogConfiguration.LogLevel
            MaxLogSizeMB     = $script:LogConfiguration.MaxLogSizeMB
            MaxLogFiles      = $script:LogConfiguration.MaxLogFiles
            EnableEventLog   = $script:LogConfiguration.EnableEventLog
            EnableFileLog    = $script:LogConfiguration.EnableFileLog
            EnableSIEM       = $script:LogConfiguration.EnableSIEM
            SIEMEndpoint     = $script:LogConfiguration.SIEMEndpoint
            SIEMType         = $script:LogConfiguration.SIEMType
        }
    }
}
