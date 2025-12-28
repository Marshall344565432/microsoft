function Write-EnterpriseLog {
    <#
    .SYNOPSIS
        Writes a structured log entry to configured destinations.

    .DESCRIPTION
        Enterprise logging function that writes to file, Windows Event Log,
        and optionally SIEM systems. Supports structured logging with
        correlation IDs for tracing distributed operations.

    .PARAMETER Message
        The log message to write.

    .PARAMETER Level
        Log level: Debug, Information, Warning, Error, Critical.

    .PARAMETER CorrelationId
        Optional correlation ID for tracing related operations across systems.

    .PARAMETER Exception
        Optional exception object for error logging.

    .PARAMETER AdditionalData
        Optional hashtable of additional structured data.

    .EXAMPLE
        Write-EnterpriseLog -Message "Operation started" -Level Information

    .EXAMPLE
        Write-EnterpriseLog -Message "Failed to connect to database" -Level Error -Exception $_.Exception

    .EXAMPLE
        $correlationId = [guid]::NewGuid().ToString()
        Write-EnterpriseLog -Message "User created" -Level Information -CorrelationId $correlationId -AdditionalData @{
            Username = "jsmith"
            Department = "IT"
            Action = "UserCreation"
        }

    .EXAMPLE
        try {
            Get-ADUser "NonExistentUser"
        }
        catch {
            Write-EnterpriseLog -Message "AD user lookup failed" -Level Error -Exception $_.Exception -AdditionalData @{
                Username = "NonExistentUser"
                Operation = "Get-ADUser"
            }
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Debug', 'Information', 'Warning', 'Error', 'Critical')]
        [string]$Level = 'Information',

        [Parameter(Mandatory = $false)]
        [ValidatePattern('^[a-fA-F0-9]{8}-([a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}$')]
        [string]$CorrelationId,

        [Parameter(Mandatory = $false)]
        [System.Exception]$Exception,

        [Parameter(Mandatory = $false)]
        [hashtable]$AdditionalData
    )

    begin {
        # Get configured log level priority
        $levelPriority = @{
            'Debug'       = 0
            'Information' = 1
            'Warning'     = 2
            'Error'       = 3
            'Critical'    = 4
        }

        $configuredLevel = $script:LogConfiguration.LogLevel
        if ($levelPriority[$Level] -lt $levelPriority[$configuredLevel]) {
            return
        }
    }

    process {
        try {
            # Build structured log entry
            $logEntry = [ordered]@{
                Timestamp     = [DateTime]::UtcNow.ToString('o')
                Level         = $Level
                Message       = $Message
                MachineName   = $env:COMPUTERNAME
                ProcessId     = $PID
                ProcessName   = (Get-Process -Id $PID).ProcessName
                Username      = "$env:USERDOMAIN\$env:USERNAME"
                CorrelationId = if ($CorrelationId) { $CorrelationId } elseif ($script:LogConfiguration.SessionId) { $script:LogConfiguration.SessionId } else { [guid]::NewGuid().ToString() }
            }

            # Add caller information
            $callerInfo = Get-CallerInfo
            $logEntry.CallerFunction = $callerInfo.FunctionName
            $logEntry.CallerScript = $callerInfo.ScriptName
            $logEntry.CallerLine = $callerInfo.LineNumber

            # Add exception details if present
            if ($Exception) {
                $logEntry.ExceptionType = $Exception.GetType().FullName
                $logEntry.ExceptionMessage = $Exception.Message
                $logEntry.StackTrace = $Exception.StackTrace
                $logEntry.HResult = $Exception.HResult

                # Add inner exceptions
                if ($Exception.InnerException) {
                    $logEntry.InnerException = $Exception.InnerException.Message
                }
            }

            # Add custom data
            if ($AdditionalData) {
                $logEntry.AdditionalData = $AdditionalData
            }

            # Write to file
            if ($script:LogConfiguration.EnableFileLog) {
                try {
                    $logPath = $script:LogConfiguration.LogPath
                    $logFile = Join-Path $logPath "EnterpriseLog_$(Get-Date -Format 'yyyyMMdd').json"

                    # Check for log rotation
                    Rotate-LogFile -LogFile $logFile

                    $jsonEntry = $logEntry | ConvertTo-Json -Compress -Depth 5
                    Add-Content -Path $logFile -Value $jsonEntry -Encoding UTF8 -ErrorAction Stop
                }
                catch {
                    Write-Warning "Failed to write to log file: $($_.Exception.Message)"
                }
            }

            # Write to Event Log
            if ($script:LogConfiguration.EnableEventLog) {
                try {
                    $eventType = switch ($Level) {
                        'Debug'       { 'Information' }
                        'Information' { 'Information' }
                        'Warning'     { 'Warning' }
                        'Error'       { 'Error' }
                        'Critical'    { 'Error' }
                    }

                    $eventId = switch ($Level) {
                        'Debug'       { 1000 }
                        'Information' { 1001 }
                        'Warning'     { 2000 }
                        'Error'       { 3000 }
                        'Critical'    { 3001 }
                    }

                    $eventMessage = Format-LogMessage -LogEntry $logEntry

                    Write-EventLog -LogName 'Application' `
                        -Source $script:LogConfiguration.EventLogSource `
                        -EventId $eventId `
                        -EntryType $eventType `
                        -Message $eventMessage `
                        -ErrorAction Stop
                }
                catch {
                    Write-Verbose "Failed to write to Event Log: $($_.Exception.Message)"
                }
            }

            # Send to SIEM
            if ($script:LogConfiguration.EnableSIEM -and $script:LogConfiguration.SIEMEndpoint) {
                try {
                    Send-LogToSIEM -LogEntry $logEntry
                }
                catch {
                    Write-Verbose "Failed to send to SIEM: $($_.Exception.Message)"
                }
            }

            # Console output for interactive sessions
            if ($Host.Name -eq 'ConsoleHost' -or $Host.Name -eq 'Visual Studio Code Host') {
                $color = switch ($Level) {
                    'Debug'       { 'Gray' }
                    'Information' { 'White' }
                    'Warning'     { 'Yellow' }
                    'Error'       { 'Red' }
                    'Critical'    { 'DarkRed' }
                }

                $timestamp = [DateTime]::Parse($logEntry.Timestamp).ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss')
                $consoleMessage = "[$timestamp] [$Level] $Message"

                if ($Exception) {
                    $consoleMessage += " | Exception: $($Exception.Message)"
                }

                Write-Host $consoleMessage -ForegroundColor $color
            }
        }
        catch {
            # Fallback logging to prevent log failures from breaking operations
            $fallbackPath = "$env:TEMP\EnterpriseLog_Fallback.log"
            $fallbackEntry = "$(Get-Date -Format 'o') | ERROR | Logging failed: $($_.Exception.Message) | Original: $Message"

            try {
                Add-Content -Path $fallbackPath -Value $fallbackEntry -ErrorAction SilentlyContinue
            }
            catch {
                # Silent fail - we've done our best
            }
        }
    }
}
