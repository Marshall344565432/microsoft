function Send-LogToSIEM {
    <#
    .SYNOPSIS
        Sends log entries to a SIEM system via HTTP/HTTPS.

    .DESCRIPTION
        Supports common SIEM integrations including Splunk HEC,
        Elasticsearch, Azure Sentinel (Log Analytics), and generic syslog-over-HTTP.

    .PARAMETER LogEntry
        The structured log entry hashtable to send.

    .EXAMPLE
        $logEntry = @{ Message = "Test"; Level = "Information" }
        Send-LogToSIEM -LogEntry $logEntry
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$LogEntry
    )

    try {
        $endpoint = $script:LogConfiguration.SIEMEndpoint
        $siemType = $script:LogConfiguration.SIEMType

        if (-not $endpoint) {
            Write-Verbose "SIEM endpoint not configured"
            return
        }

        $headers = @{
            'Content-Type' = 'application/json'
        }

        # Handle authentication and payload based on SIEM type
        switch ($siemType) {
            'Splunk' {
                if ($script:LogConfiguration.SIEMToken) {
                    $headers['Authorization'] = "Splunk $($script:LogConfiguration.SIEMToken)"
                }

                $body = @{
                    event      = $LogEntry
                    time       = [DateTimeOffset]::Parse($LogEntry.Timestamp).ToUnixTimeSeconds()
                    host       = $env:COMPUTERNAME
                    source     = 'EnterpriseLogging'
                    sourcetype = 'json'
                } | ConvertTo-Json -Depth 10
            }

            'Elasticsearch' {
                # Elasticsearch expects one JSON object per line
                $body = $LogEntry | ConvertTo-Json -Depth 10 -Compress
            }

            'AzureSentinel' {
                # Azure Log Analytics expects an array
                $body = @($LogEntry) | ConvertTo-Json -Depth 10
            }

            default {
                $body = $LogEntry | ConvertTo-Json -Depth 10
            }
        }

        # Send with retry logic
        $maxRetries = 3
        $retryCount = 0
        $success = $false

        while (-not $success -and $retryCount -lt $maxRetries) {
            try {
                $response = Invoke-RestMethod -Uri $endpoint `
                    -Method Post `
                    -Headers $headers `
                    -Body $body `
                    -TimeoutSec 30 `
                    -ErrorAction Stop

                $success = $true
                Write-Verbose "Successfully sent log to SIEM ($siemType)"
            }
            catch {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    $delay = 2 * [math]::Pow(2, $retryCount - 1)  # Exponential backoff
                    Write-Verbose "SIEM send failed (attempt $retryCount/$maxRetries), retrying in $delay seconds..."
                    Start-Sleep -Seconds $delay
                }
                else {
                    throw
                }
            }
        }
    }
    catch {
        # Queue for later retry or write to fallback
        try {
            $queuePath = Join-Path $script:LogConfiguration.LogPath 'SIEMQueue'
            if (-not (Test-Path $queuePath)) {
                New-Item -Path $queuePath -ItemType Directory -Force | Out-Null
            }

            $queueFile = Join-Path $queuePath "$(Get-Date -Format 'yyyyMMddHHmmss')_$([guid]::NewGuid().ToString('N').Substring(0,8)).json"
            $LogEntry | ConvertTo-Json -Depth 10 | Out-File -FilePath $queueFile -Encoding UTF8

            Write-Verbose "Queued log entry for later SIEM transmission: $queueFile"
        }
        catch {
            Write-Verbose "Failed to queue log for SIEM: $($_.Exception.Message)"
        }
    }
}
