# EnterpriseLogging PowerShell Module

Enterprise-grade centralized logging module for Windows Server environments with support for file logging, Windows Event Log, and SIEM integration.

## Features

- **Structured JSON Logging** - Machine-readable logs with full context
- **Windows Event Log Integration** - Native OS logging support
- **SIEM Forwarding** - Splunk, Elasticsearch, Azure Sentinel
- **Correlation ID Tracking** - Trace distributed operations
- **Automatic Log Rotation** - Size-based rotation with retention policy
- **Multiple Log Levels** - Debug, Information, Warning, Error, Critical
- **Caller Context** - Automatic function/script/line tracking
- **Exception Handling** - Full exception details with stack traces
- **Session Management** - Group related operations with shared correlation IDs

## Installation

### Option 1: Manual Installation

```powershell
# Copy module to PowerShell modules directory
$modulePath = "$env:ProgramFiles\WindowsPowerShell\Modules\EnterpriseLogging"
Copy-Item -Path ".\EnterpriseLogging" -Destination $modulePath -Recurse

# Import module
Import-Module EnterpriseLogging
```

### Option 2: Import Directly

```powershell
# Import from current location
Import-Module ".\EnterpriseLogging\EnterpriseLogging.psd1"
```

## Quick Start

```powershell
# Import the module
Import-Module EnterpriseLogging

# Simple logging
Write-EnterpriseLog -Message "Application started" -Level Information

# Logging with additional data
Write-EnterpriseLog -Message "User created successfully" -Level Information -AdditionalData @{
    Username = "jsmith"
    Department = "IT"
    CreatedBy = $env:USERNAME
}

# Error logging with exception
try {
    Get-ADUser "NonExistentUser"
}
catch {
    Write-EnterpriseLog -Message "Failed to retrieve user" -Level Error -Exception $_.Exception
}

# Session-based logging (shared correlation ID)
Start-LogSession -SessionName "UserProvisioning"
Write-EnterpriseLog -Message "Creating user account"
Write-EnterpriseLog -Message "Setting permissions"
Write-EnterpriseLog -Message "Sending welcome email"
Stop-LogSession
```

## Configuration

### File Logging

```powershell
# Configure log path and rotation
Set-LogConfiguration -LogPath "D:\Logs\Enterprise" `
    -MaxLogSizeMB 100 `
    -MaxLogFiles 30
```

### Log Levels

```powershell
# Set minimum log level (filters out lower levels)
Set-LogConfiguration -LogLevel Warning  # Only Warning, Error, Critical logged
```

### SIEM Integration

#### Splunk HTTP Event Collector (HEC)

```powershell
$splunkToken = "your-hec-token-here"

Set-LogConfiguration `
    -EnableSIEM $true `
    -SIEMEndpoint "https://splunk.company.com:8088/services/collector" `
    -SIEMToken $splunkToken `
    -SIEMType Splunk

# All logs will now forward to Splunk
Write-EnterpriseLog -Message "Test message to Splunk"
```

#### Azure Sentinel (Log Analytics)

```powershell
Set-LogConfiguration `
    -EnableSIEM $true `
    -SIEMEndpoint "https://<workspace-id>.ods.opinsights.azure.com/api/logs?api-version=2016-04-01" `
    -SIEMToken $workspaceKey `
    -SIEMType AzureSentinel
```

#### Elasticsearch

```powershell
Set-LogConfiguration `
    -EnableSIEM $true `
    -SIEMEndpoint "https://elasticsearch.company.com:9200/logs/_doc" `
    -SIEMType Elasticsearch
```

### Windows Event Log

```powershell
# Enable/disable Event Log integration
Set-LogConfiguration -EnableEventLog $true

# Write direct Event Log entry
Write-EventLogEntry -Message "Service started" -EventId 1001 -EntryType Information
```

## Advanced Usage

### Correlation ID Tracking

```powershell
# Generate correlation ID for distributed operation
$correlationId = [guid]::NewGuid().ToString()

# Server 1
Write-EnterpriseLog -Message "Processing request" -CorrelationId $correlationId

# Server 2 (same correlation ID)
Write-EnterpriseLog -Message "Database query executed" -CorrelationId $correlationId

# Server 3 (same correlation ID)
Write-EnterpriseLog -Message "Response sent" -CorrelationId $correlationId

# Query logs by correlation ID to trace entire operation
```

### Session Management

```powershell
# Start session (auto-generates correlation ID for all subsequent logs)
$session = Start-LogSession -SessionName "DailyBackup"

Write-EnterpriseLog -Message "Backup started"
# ... backup operations ...
Write-EnterpriseLog -Message "Backup completed"

Stop-LogSession
```

### Exception Logging

```powershell
try {
    # Risky operation
    Invoke-RestMethod -Uri "https://api.service.com/data" -Method Post -Body $data
}
catch {
    Write-EnterpriseLog `
        -Message "API call failed" `
        -Level Error `
        -Exception $_.Exception `
        -AdditionalData @{
            Endpoint = "https://api.service.com/data"
            Method = "POST"
            StatusCode = $_.Exception.Response.StatusCode.value__
        }
}
```

### Structured Logging

```powershell
# Log with rich structured data
Write-EnterpriseLog -Message "Deployment completed" -Level Information -AdditionalData @{
    ApplicationName = "WebApp"
    Version = "2.1.0"
    Environment = "Production"
    DeploymentDuration = "5m 32s"
    ServerCount = 4
    SuccessRate = "100%"
}
```

## Log Output Formats

### JSON File Output

```json
{
  "Timestamp": "2025-12-27T12:34:56.789Z",
  "Level": "Information",
  "Message": "User created successfully",
  "MachineName": "SERVER01",
  "ProcessId": 1234,
  "ProcessName": "powershell",
  "Username": "DOMAIN\\admin",
  "CorrelationId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "CallerFunction": "New-ADUserAccount",
  "CallerScript": "C:\\Scripts\\UserProvisioning.ps1",
  "CallerLine": 45,
  "AdditionalData": {
    "Username": "jsmith",
    "Department": "IT",
    "CreatedBy": "admin"
  }
}
```

### Event Log Output

```
Message: User created successfully
Timestamp: 2025-12-27T12:34:56.789Z
Level: Information
Machine: SERVER01
User: DOMAIN\admin
CorrelationId: a1b2c3d4-e5f6-7890-abcd-ef1234567890
Caller: New-ADUserAccount
Script: C:\Scripts\UserProvisioning.ps1:45

Additional Data:
  Username = jsmith
  Department = IT
  CreatedBy = admin
```

## Querying Logs

### PowerShell

```powershell
# Read today's log file
$logPath = "C:\ProgramData\EnterpriseLogs\EnterpriseLog_20251227.json"
$logs = Get-Content $logPath | ConvertFrom-Json

# Filter by level
$errors = $logs | Where-Object Level -eq 'Error'

# Filter by correlation ID
$operation = $logs | Where-Object CorrelationId -eq 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

# Filter by additional data
$userCreations = $logs | Where-Object { $_.AdditionalData.Action -eq 'UserCreation' }
```

### Event Viewer

1. Open **Event Viewer** (eventvwr.msc)
2. Navigate to **Windows Logs → Application**
3. Filter by Source: **EnterpriseAutomation**

### Splunk

```spl
index=windows source="EnterpriseLogging"
| table _time Level Message MachineName Username CorrelationId

# Find errors
index=windows source="EnterpriseLogging" Level=Error

# Trace operation by correlation ID
index=windows source="EnterpriseLogging" CorrelationId="a1b2c3d4-e5f6-7890-abcd-ef1234567890"
| sort _time
```

## Best Practices

1. **Use Correlation IDs** - For multi-step operations across systems
2. **Include Context** - Use AdditionalData for relevant details
3. **Appropriate Levels** - Use correct severity levels
4. **Exception Logging** - Always include exception objects for errors
5. **Session Management** - Use sessions for related operations
6. **SIEM Integration** - Forward to SIEM for centralized monitoring
7. **Log Rotation** - Configure appropriate retention policies
8. **Structured Data** - Use hashtables for AdditionalData

## Performance Considerations

- Logs are written asynchronously to minimize impact
- File I/O is optimized with buffering
- SIEM failures are queued for retry (non-blocking)
- Fallback logging prevents pipeline failures

## Troubleshooting

### Event Log Source Not Created

```powershell
# Run as Administrator
[System.Diagnostics.EventLog]::CreateEventSource("EnterpriseAutomation", "Application")
```

### Logs Not Written

```powershell
# Check configuration
Set-LogConfiguration | Format-List

# Verify log path exists and is writable
Test-Path "C:\ProgramData\EnterpriseLogs"

# Check log level filtering
Set-LogConfiguration -LogLevel Debug  # Log everything
```

### SIEM Not Receiving Logs

```powershell
# Check queued logs
Get-ChildItem "C:\ProgramData\EnterpriseLogs\SIEMQueue"

# Test SIEM endpoint
Test-NetConnection -ComputerName "splunk.company.com" -Port 8088

# Enable verbose output
Write-EnterpriseLog -Message "Test" -Verbose
```

## Functions Reference

| Function | Description |
|----------|-------------|
| `Write-EnterpriseLog` | Main logging function with full features |
| `Start-LogSession` | Begin logging session with shared correlation ID |
| `Stop-LogSession` | End current logging session |
| `Set-LogConfiguration` | Configure module behavior |
| `Send-LogToSIEM` | Forward log to SIEM (called automatically) |
| `Write-EventLogEntry` | Direct Event Log write |

## Requirements

- PowerShell 5.1 or higher
- Windows Server 2016+ or Windows 10+
- Administrator rights for Event Log source creation
- Network access for SIEM forwarding (if enabled)

## License

Enterprise use only. Review your organization's policies before deployment.

## Support

For issues or questions, contact your Enterprise IT team.
