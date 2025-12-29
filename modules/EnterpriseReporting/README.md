# EnterpriseReporting PowerShell Module

Professional reporting module for Windows Server environments with HTML, CSV, JSON, and Excel export capabilities.

## Features

- **Multiple Export Formats** - HTML, CSV, JSON, Excel
- **Professional HTML Reports** - Responsive design, sortable tables
- **Template System** - Default, Executive, Technical, Minimal styles
- **Charts and Visualizations** - Bar, pie, line charts
- **Report Sections** - Organized, multi-section reports
- **Company Branding** - Logo and company name support
- **Excel Integration** - Formatted workbooks with ImportExcel module

## Installation

```powershell
# Import the module
Import-Module ".\EnterpriseReporting\EnterpriseReporting.psd1"

# Optional: Install ImportExcel for Excel export
Install-Module -Name ImportExcel -Scope CurrentUser
```

## Quick Start

```powershell
# Create a new report
$report = New-EnterpriseReport -Title "AD Health Report" -Description "Weekly Active Directory health check"

# Add data sections
$users = Get-ADUser -Filter {Enabled -eq $true} -Properties Department, LastLogonDate
$report | Add-ReportSection -Name "Active Users" -Data $users

# Add a summary table
$summary = [PSCustomObject]@{
    TotalUsers    = 1500
    EnabledUsers  = 1450
    DisabledUsers = 50
    LockedOut     = 5
}
$report | Add-ReportTable -Name "Summary Statistics" -Data $summary

# Export to HTML
$report | Export-ReportToHTML -Path "C:\Reports\ADHealth.html" -Open

# Export to CSV
$report | Export-ReportToCSV -Path "C:\Reports\ADHealth"

# Export to JSON
$report | Export-ReportToJSON -Path "C:\Reports\ADHealth.json"
```

## Advanced Usage

### Using Templates

```powershell
# Executive template (professional styling for management)
$report = New-EnterpriseReport -Title "Quarterly Report" -Template Executive -CompanyName "Contoso Corp"

# Technical template (detailed styling for technical teams)
$report = New-EnterpriseReport -Title "System Health" -Template Technical

# Minimal template (clean, simple styling)
$report = New-EnterpriseReport -Title "Daily Summary" -Template Minimal
```

### Adding Company Logo

```powershell
$report = New-EnterpriseReport -Title "Monthly Report" `
    -CompanyName "Contoso Corporation" `
    -LogoPath "C:\Images\logo.png"
```

### Creating Charts

```powershell
# Bar chart
$osData = @{
    Labels = @('Windows Server 2022', 'Windows Server 2019', 'Windows Server 2016')
    Values = @(150, 200, 50)
}
$report | Add-ReportChart -Name "Server OS Distribution" -ChartData $osData -Type Bar

# Pie chart
$deptData = @{
    Labels = @('IT', 'Sales', 'Marketing', 'HR')
    Values = @(50, 150, 75, 25)
}
$report | Add-ReportChart -Name "Users by Department" -ChartData $deptData -Type Pie
```

### Filtering Table Columns

```powershell
# Only show specific columns
$servers = Get-ADComputer -Filter * -Properties OperatingSystem, LastLogonDate
$report | Add-ReportTable -Name "Servers" -Data $servers -Columns @('Name', 'OperatingSystem', 'Enabled')
```

### Excel Export with Formatting

```powershell
$report | Export-ReportToExcel -Path "C:\Reports\Report.xlsx" `
    -AutoSize `
    -FreezeTopRow `
    -TableStyle "Medium6"
```

## Real-World Examples

### AD User Report

```powershell
$report = New-EnterpriseReport -Title "Active Directory User Report" -Author "IT Admin"

# Get stale users
$staleUsers = Get-ADUser -Filter {Enabled -eq $true} -Properties LastLogonDate |
    Where-Object { $_.LastLogonDate -lt (Get-Date).AddDays(-90) }

$report | Add-ReportSection -Name "Stale User Accounts (90+ days)" -Data $staleUsers

# Get locked accounts
$lockedUsers = Search-ADAccount -LockedOut
$report | Add-ReportSection -Name "Locked User Accounts" -Data $lockedUsers

# Summary
$summary = [PSCustomObject]@{
    TotalUsers   = (Get-ADUser -Filter *).Count
    EnabledUsers = (Get-ADUser -Filter {Enabled -eq $true}).Count
    StaleUsers   = $staleUsers.Count
    LockedUsers  = $lockedUsers.Count
}
$report | Add-ReportTable -Name "Summary" -Data $summary

# Export
$report | Export-ReportToHTML -Path "C:\Reports\ADUserReport.html" -Open
$report | Export-ReportToExcel -Path "C:\Reports\ADUserReport.xlsx" -AutoSize
```

### Server Inventory Report

```powershell
$report = New-EnterpriseReport -Title "Server Inventory" -Template Technical

# Get all servers
$servers = Get-ADComputer -Filter {OperatingSystem -like "*Server*"} -Properties *

# Group by OS
$osByVersion = $servers | Group-Object OperatingSystem | Select-Object Name, Count
$report | Add-ReportTable -Name "Servers by Operating System" -Data $osByVersion

# Chart
$chartData = @{
    Labels = $osByVersion.Name
    Values = $osByVersion.Count
}
$report | Add-ReportChart -Name "OS Distribution" -ChartData $chartData -Type Bar

# Detailed server list
$report | Add-ReportTable -Name "All Servers" -Data $servers `
    -Columns @('Name', 'OperatingSystem', 'IPv4Address', 'LastLogonDate', 'Enabled')

# Export
$report | Export-ReportToHTML -Path "C:\Reports\ServerInventory.html"
$report | Export-ReportToCSV -Path "C:\Reports\ServerInventory"
```

### Security Audit Report

```powershell
$report = New-EnterpriseReport -Title "Security Audit Report" -Template Executive

# Privileged users
$adminUsers = Get-ADGroupMember "Domain Admins" -Recursive
$report | Add-ReportSection -Name "Domain Administrators" -Data $adminUsers

# Password never expires
$neverExpire = Get-ADUser -Filter {PasswordNeverExpires -eq $true -and Enabled -eq $true}
$report | Add-ReportSection -Name "Passwords Set to Never Expire" -Data $neverExpire

# Summary statistics
$summary = [PSCustomObject]@{
    DomainAdmins      = $adminUsers.Count
    PasswordNeverExpires = $neverExpire.Count
    ReportDate        = Get-Date -Format "yyyy-MM-dd HH:mm"
    GeneratedBy       = $env:USERNAME
}
$report | Add-ReportTable -Name "Audit Summary" -Data $summary

# Export with company branding
$report | Export-ReportToHTML -Path "C:\Reports\SecurityAudit.html"
```

## Export Format Details

### HTML Export
- Responsive design (mobile-friendly)
- Sortable tables (click column headers)
- Print-optimized CSS
- Template-based styling
- Embedded images support

### CSV Export
- Creates separate CSV file for each section/table
- Includes summary text file
- Excel-compatible encoding
- Preserves data types

### JSON Export
- Complete report structure
- API-friendly format
- Configurable depth
- Optional compression

### Excel Export
- Multiple worksheets (one per section/table)
- Formatted tables with headers
- Auto-sized columns (optional)
- Frozen headers (optional)
- Professional table styles

## Functions Reference

| Function | Description |
|----------|-------------|
| `New-EnterpriseReport` | Create new report object |
| `Add-ReportSection` | Add data section to report |
| `Add-ReportTable` | Add formatted table to report |
| `Add-ReportChart` | Add chart/visualization to report |
| `Export-ReportToHTML` | Export to HTML with styling |
| `Export-ReportToCSV` | Export to CSV files |
| `Export-ReportToJSON` | Export to JSON format |
| `Export-ReportToExcel` | Export to Excel workbook |

## Requirements

- PowerShell 5.1 or higher
- Windows Server 2016+ or Windows 10+
- ImportExcel module (optional, for Excel export)

## Best Practices

1. **Use Descriptive Titles** - Clear report titles improve usability
2. **Add Descriptions** - Section descriptions provide context
3. **Select Relevant Columns** - Don't overwhelm with too many columns
4. **Use Appropriate Templates** - Match template to audience
5. **Include Summary Data** - Add summary sections for quick insights
6. **Export Multiple Formats** - Provide both HTML (viewing) and Excel (analysis)
7. **Brand Your Reports** - Add company logo and name
8. **Automate Report Generation** - Schedule reports with Task Scheduler

## Integration with EnterpriseLogging

```powershell
Import-Module EnterpriseLogging

# Log report generation
Write-EnterpriseLog -Message "Generating AD health report" -Level Information

$report = New-EnterpriseReport -Title "AD Health"
# ... add sections ...

$result = $report | Export-ReportToHTML -Path "C:\Reports\ADHealth.html"

Write-EnterpriseLog -Message "Report generated successfully" -Level Information -AdditionalData @{
    ReportTitle = $report.Title
    OutputPath  = $result.Path
    FileSize    = $result.Size
}
```

## Troubleshooting

### ImportExcel Module Not Found

```powershell
Install-Module -Name ImportExcel -Scope CurrentUser
```

### HTML Tables Not Sorting

Ensure JavaScript is enabled in browser and file is opened locally (not via network share with restricted permissions).

### Large Reports Performance

For reports with 10,000+ rows, consider:
- Filtering data before adding to report
- Using CSV export instead of HTML
- Splitting into multiple reports
- Using Excel export with data on separate sheets

## License

Enterprise use only. Review your organization's policies before deployment.
