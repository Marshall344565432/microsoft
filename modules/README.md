# Enterprise PowerShell Modules

Production-ready PowerShell modules for Windows Server 2022 enterprise infrastructure management.

## Available Modules

### ✅ EnterpriseLogging (v1.0.0)

Enterprise-grade centralized logging with file, Event Log, and SIEM integration.

**Features:**
- Structured JSON file logging
- Windows Event Log integration
- SIEM forwarding (Splunk, Elasticsearch, Azure Sentinel)
- Correlation ID tracking for distributed operations
- Automatic log rotation with retention policies
- Session management
- Exception handling with stack traces

**Functions:** `Write-EnterpriseLog`, `Start-LogSession`, `Stop-LogSession`, `Set-LogConfiguration`, `Send-LogToSIEM`, `Write-EventLogEntry`

[📖 Full Documentation](./EnterpriseLogging/README.md)

### ✅ EnterpriseReporting (v1.0.0)

Professional reporting module with HTML, CSV, JSON, and Excel export capabilities.

**Features:**
- HTML reports with responsive design
- Sortable tables with JavaScript
- 4 professional templates (Default, Executive, Technical, Minimal)
- CSV/JSON export for automation
- Excel export with formatting
- Chart visualizations (bar, pie, line)
- Company branding support

**Functions:** `New-EnterpriseReport`, `Add-ReportSection`, `Add-ReportTable`, `Add-ReportChart`, `Export-ReportToHTML`, `Export-ReportToCSV`, `Export-ReportToJSON`, `Export-ReportToExcel`

[📖 Full Documentation](./EnterpriseReporting/README.md)

## Quick Start

```powershell
# Import modules
Import-Module ".\modules\EnterpriseLogging\EnterpriseLogging.psd1"
Import-Module ".\modules\EnterpriseReporting\EnterpriseReporting.psd1"

# Example: Log and report
Write-EnterpriseLog -Message "Generating user report" -Level Information

$report = New-EnterpriseReport -Title "AD User Report"
$users = Get-ADUser -Filter * -Properties Department
$report | Add-ReportTable -Name "Active Directory Users" -Data $users
$report | Export-ReportToHTML -Path "C:\Reports\ADUsers.html" -Open

Write-EnterpriseLog -Message "Report generated successfully" -Level Information
```

## Installation

### Manual Installation

```powershell
# Copy modules to PowerShell modules directory
$modulesPath = "$env:ProgramFiles\WindowsPowerShell\Modules"

Copy-Item -Path ".\modules\EnterpriseLogging" -Destination "$modulesPath\EnterpriseLogging" -Recurse
Copy-Item -Path ".\modules\EnterpriseReporting" -Destination "$modulesPath\EnterpriseReporting" -Recurse

# Import modules
Import-Module EnterpriseLogging
Import-Module EnterpriseReporting
```

### Direct Import

```powershell
# Import from repository location
Import-Module "C:\Path\To\Repo\modules\EnterpriseLogging\EnterpriseLogging.psd1"
Import-Module "C:\Path\To\Repo\modules\EnterpriseReporting\EnterpriseReporting.psd1"
```

## Module Integration Examples

### Example 1: AD Health Report with Logging

```powershell
Import-Module EnterpriseLogging
Import-Module EnterpriseReporting

# Start logging session
$session = Start-LogSession -SessionName "ADHealthReport"

try {
    Write-EnterpriseLog -Message "Starting AD health report generation"

    # Create report
    $report = New-EnterpriseReport -Title "Active Directory Health Report" `
        -Description "Weekly AD health check" `
        -Template Executive

    # Get stale users
    Write-EnterpriseLog -Message "Querying stale user accounts"
    $staleUsers = Get-ADUser -Filter {Enabled -eq $true} -Properties LastLogonDate |
        Where-Object { $_.LastLogonDate -lt (Get-Date).AddDays(-90) }

    $report | Add-ReportSection -Name "Stale Accounts (90+ days)" -Data $staleUsers

    # Get locked accounts
    Write-EnterpriseLog -Message "Querying locked accounts"
    $lockedUsers = Search-ADAccount -LockedOut
    $report | Add-ReportSection -Name "Locked Accounts" -Data $lockedUsers

    # Summary
    $summary = [PSCustomObject]@{
        TotalUsers   = (Get-ADUser -Filter *).Count
        StaleUsers   = $staleUsers.Count
        LockedUsers  = $lockedUsers.Count
        ReportDate   = Get-Date -Format "yyyy-MM-dd"
    }
    $report | Add-ReportTable -Name "Summary" -Data $summary

    # Export
    Write-EnterpriseLog -Message "Exporting report to HTML and Excel"
    $htmlResult = $report | Export-ReportToHTML -Path "C:\Reports\ADHealth.html"
    $excelResult = $report | Export-ReportToExcel -Path "C:\Reports\ADHealth.xlsx" -AutoSize

    Write-EnterpriseLog -Message "Report generation completed successfully" -AdditionalData @{
        HTMLPath  = $htmlResult.Path
        ExcelPath = $excelResult.Path
        StaleUsers = $staleUsers.Count
        LockedUsers = $lockedUsers.Count
    }
}
catch {
    Write-EnterpriseLog -Message "Report generation failed" -Level Error -Exception $_.Exception
    throw
}
finally {
    Stop-LogSession
}
```

### Example 2: Server Inventory with SIEM Integration

```powershell
# Configure SIEM forwarding
Set-LogConfiguration -EnableSIEM $true `
    -SIEMEndpoint "https://splunk.company.com:8088/services/collector" `
    -SIEMToken $splunkToken `
    -SIEMType Splunk

# Generate inventory
Write-EnterpriseLog -Message "Starting server inventory" -Level Information

$report = New-EnterpriseReport -Title "Server Inventory Report" -Template Technical

$servers = Get-ADComputer -Filter {OperatingSystem -like "*Server*"} -Properties *
$report | Add-ReportTable -Name "All Servers" -Data $servers

# Chart
$osByVersion = $servers | Group-Object OperatingSystem
$chartData = @{
    Labels = $osByVersion.Name
    Values = $osByVersion.Count
}
$report | Add-ReportChart -Name "OS Distribution" -ChartData $chartData -Type Bar

$result = $report | Export-ReportToHTML -Path "C:\Reports\Inventory.html"

# Log to SIEM
Write-EnterpriseLog -Message "Server inventory completed" -Level Information -AdditionalData @{
    TotalServers = $servers.Count
    ReportPath   = $result.Path
}
```

## Requirements

- PowerShell 5.1 or higher
- Windows Server 2016+ or Windows 10+
- Administrator rights for Event Log source creation (EnterpriseLogging)
- ImportExcel module (optional, for Excel export in EnterpriseReporting)

## Best Practices

1. **Use Correlation IDs** - Track multi-step operations across systems
2. **Configure SIEM** - Forward logs to centralized monitoring
3. **Use Templates** - Match report template to audience
4. **Error Handling** - Always wrap operations in try/catch with logging
5. **Session Management** - Use log sessions for related operations
6. **Export Multiple Formats** - Provide both HTML (viewing) and Excel (analysis)

## Module Development Standards

All modules in this collection follow these standards:

- **Explicit Exports** - Never use wildcards in `FunctionsToExport`
- **Public/Private Structure** - Clear separation of public API and helpers
- **Comment-Based Help** - Complete help with examples for all functions
- **Error Handling** - Proper exception handling with meaningful messages
- **PowerShell Editions** - Compatible with both Desktop and Core
- **Versioning** - Semantic versioning (MAJOR.MINOR.PATCH)
- **Documentation** - Comprehensive README with examples

## Planned Modules

Future modules planned for this collection:

- **EnterpriseAD** - Active Directory management (user/computer/group operations)
- **EnterpriseGPO** - Group Policy management (backup, comparison, reporting)
- **EnterpriseCertificate** - PKI management (template management, expiration tracking)
- **EnterpriseNotifications** - Multi-channel notifications (Teams, Slack, Email)

## License

Enterprise use only. Review your organization's policies before deployment.

## Contributing

These modules are maintained by the Enterprise IT team. For issues or feature requests, contact your IT department.

## Version History

### EnterpriseLogging

- **1.0.0** (2025-12-27) - Initial release

### EnterpriseReporting

- **1.0.0** (2025-12-27) - Initial release
