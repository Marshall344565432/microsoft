# EnterpriseGPO PowerShell Module

Enterprise Group Policy management module for backup, comparison, reporting, and health monitoring.

## Features

- **GPO Backup & Restore** - Comprehensive backup with compression and retention policies
- **GPO Comparison** - Detailed comparison with HTML diff reports
- **Enhanced Reporting** - HTML/XML reports with links, permissions, and WMI filters
- **Linkage Analysis** - Complete GPO link analysis across the domain
- **Health Monitoring** - Replication, sysvol, empty GPO, and unlinked GPO detection
- **Metadata Management** - Links, permissions, and WMI filter preservation

## Installation

```powershell
# Import the module
Import-Module "..\EnterpriseGPO\EnterpriseGPO.psd1"

# Verify installation
Get-Command -Module EnterpriseGPO
```

## Prerequisites

- PowerShell 5.1 or higher
- GroupPolicy PowerShell module (RSAT-GP-PowerShell)
- ActiveDirectory module
- Domain administrator or GPO management permissions

## Quick Start

```powershell
# Import module
Import-Module EnterpriseGPO

# Backup all GPOs with compression
Backup-EnterpriseGPO -BackupPath "C:\GPOBackups" -Compress -IncludeMetadata

# Test GPO health
Test-GPOHealth -CheckReplication -CheckSysvol -CheckEmpty -CheckUnlinked

# Get GPO linkage
Get-GPOLinkage -GPOName "Default Domain Policy"

# Compare two GPOs
Compare-EnterpriseGPO -ReferenceGPO "Baseline Policy" -DifferenceGPO "Current Policy" -OutputPath "C:\Reports\Comparison.html"
```

## Functions Reference

### Backup-EnterpriseGPO

Backs up Group Policy Objects with comprehensive metadata.

```powershell
# Backup single GPO
Backup-EnterpriseGPO -GPOName "Default Domain Policy" -BackupPath "C:\GPOBackups"

# Backup all GPOs with compression and metadata
Backup-EnterpriseGPO -BackupPath "C:\GPOBackups" -Compress -IncludeMetadata

# Backup with retention policy (30 days)
Backup-EnterpriseGPO -BackupPath "C:\GPOBackups" -RetentionDays 30 -Comment "Monthly backup"

# Backup with all options
Backup-EnterpriseGPO -BackupPath "C:\GPOBackups" `
    -Compress `
    -IncludeMetadata `
    -RetentionDays 30 `
    -Comment "Quarterly backup before changes"
```

**Parameters:**
- `GPOName` - Specific GPO to backup (optional, defaults to all)
- `BackupPath` - Directory for backups (required)
- `Compress` - Create ZIP archive
- `IncludeMetadata` - Include links, permissions, WMI filters
- `RetentionDays` - Delete backups older than X days
- `Comment` - Backup description

**Features:**
- Automatic backup folder creation with timestamp
- Backup manifest with GPO list and metadata
- ZIP compression for space savings
- Automatic old backup cleanup
- Metadata includes: links, permissions, WMI filters, versions

### Restore-EnterpriseGPO

Restores GPOs from backup with options for new GPO creation or overwrite.

```powershell
# Restore GPO from backup
Restore-EnterpriseGPO -BackupId "{12345678-1234-1234-1234-123456789012}" -BackupPath "C:\GPOBackups\GPO_Backup_20250127"

# Restore to new GPO
Restore-EnterpriseGPO -BackupId "{GUID}" -BackupPath "C:\GPOBackups\GPO_Backup_20250127" `
    -CreateNew `
    -TargetName "Restored_Policy"

# Restore with links and permissions
Restore-EnterpriseGPO -BackupId "{GUID}" -BackupPath "C:\GPOBackups\GPO_Backup_20250127" `
    -RestoreLinks

# Full restore with everything
Restore-EnterpriseGPO -BackupId "{GUID}" -BackupPath "C:\GPOBackups\GPO_Backup_20250127" `
    -CreateNew `
    -TargetName "Test_Environment_Policy" `
    -RestoreLinks
```

**Parameters:**
- `BackupId` - GUID of backup to restore (required)
- `BackupPath` - Backup directory path (required)
- `TargetName` - Name for restored GPO (optional)
- `CreateNew` - Create new GPO instead of overwriting
- `RestoreLinks` - Restore OU links and permissions from metadata

**Features:**
- Restore to original or new GPO
- Optional link and permission restoration
- Automatic GPO creation if original doesn't exist
- Metadata-driven link restoration
- Permission restoration with error handling

### Compare-EnterpriseGPO

Compares two GPOs or a GPO against a backup with detailed HTML diff report.

```powershell
# Compare two live GPOs
Compare-EnterpriseGPO -ReferenceGPO "Baseline Policy" -DifferenceGPO "Current Policy"

# Compare with HTML report
Compare-EnterpriseGPO -ReferenceGPO "Baseline Policy" `
    -DifferenceGPO "Current Policy" `
    -OutputPath "C:\Reports\GPO_Comparison.html"

# Compare live GPO against backup
Compare-EnterpriseGPO -ReferenceGPO "Default Domain Policy" `
    -BackupPath "C:\GPOBackups\GPO_Backup_20250101" `
    -BackupId "{GUID}" `
    -OutputPath "C:\Reports\Backup_Comparison.html"
```

**Parameters:**
- `ReferenceGPO` - Name of reference GPO (required)
- `DifferenceGPO` - Name of GPO to compare (optional)
- `BackupPath` - Path to backup for comparison (optional)
- `BackupId` - GUID of backup to compare (optional)
- `OutputPath` - Path for HTML diff report (optional)

**Features:**
- Live GPO to live GPO comparison
- Live GPO to backup comparison
- HTML diff report with color coding
- Added/Removed/Modified change detection
- Computer and User configuration comparison
- Extension-level difference detection

### Get-GPOReport

Generates comprehensive GPO reports with enhanced formatting and metadata.

```powershell
# Generate HTML report for single GPO
Get-GPOReport -GPOName "Default Domain Policy" -OutputPath "C:\Reports\DDP.html"

# Generate report for all GPOs with metadata
Get-GPOReport -OutputPath "C:\Reports\AllGPOs.html" `
    -IncludeLinks `
    -IncludePermissions

# Generate XML report
Get-GPOReport -GPOName "Security Policy" `
    -ReportType XML `
    -OutputPath "C:\Reports\SecurityPolicy.xml"

# Executive template report
Get-GPOReport -OutputPath "C:\Reports\GPO_Executive_Report.html" `
    -Template Executive `
    -IncludeLinks `
    -IncludePermissions
```

**Parameters:**
- `GPOName` - Specific GPO to report (optional, defaults to all)
- `ReportType` - HTML or XML (default: HTML)
- `OutputPath` - Report file path (optional)
- `IncludeLinks` - Include OU links in report
- `IncludePermissions` - Include GPO permissions
- `Template` - Standard, Executive, or Technical

**Features:**
- Multi-GPO combined reports
- Links and permissions in metadata
- WMI filter information
- Version history tracking
- Professional HTML formatting
- XML for automation

### Get-GPOLinkage

Retrieves comprehensive GPO linkage information across the domain.

```powershell
# Get all OUs where a GPO is linked
Get-GPOLinkage -GPOName "Default Domain Policy"

# Get all GPOs linked to specific OU
Get-GPOLinkage -OU "OU=Servers,DC=contoso,DC=com"

# Include inherited links from parent OUs
Get-GPOLinkage -OU "OU=WebServers,OU=Servers,DC=contoso,DC=com" -IncludeInherited

# Get all GPO links in entire domain
Get-GPOLinkage
```

**Parameters:**
- `GPOName` - Specific GPO to check linkage for
- `OU` - Specific OU to check for linked GPOs
- `IncludeInherited` - Include inherited GPO links from parent OUs

**Features:**
- Link order tracking
- Enabled/disabled status
- Enforcement status
- Inherited link detection
- Complete domain scanning
- OU-to-GPO and GPO-to-OU queries

### Test-GPOHealth

Performs comprehensive health checks on GPOs.

```powershell
# Basic health check
Test-GPOHealth

# Comprehensive health check on all GPOs
Test-GPOHealth -CheckReplication -CheckSysvol -CheckEmpty -CheckUnlinked

# Check specific GPO
Test-GPOHealth -GPOName "Default Domain Policy" -CheckReplication

# Check replication only
Test-GPOHealth -CheckReplication

# Find empty and unlinked GPOs
Test-GPOHealth -CheckEmpty -CheckUnlinked
```

**Parameters:**
- `GPOName` - Specific GPO to check (optional)
- `CheckReplication` - Verify replication across DCs
- `CheckSysvol` - Verify Sysvol folder exists
- `CheckEmpty` - Identify GPOs with no settings
- `CheckUnlinked` - Identify GPOs not linked to any OU

**Health Checks:**
1. **Replication Status**: Version consistency across domain controllers
2. **Sysvol Consistency**: Verifies Sysvol folder existence
3. **Empty GPOs**: Identifies GPOs with no configured settings
4. **Unlinked GPOs**: Finds GPOs not applied to any OU
5. **Version Tracking**: User and Computer version numbers

## Real-World Examples

### Weekly GPO Backup with Retention

```powershell
Import-Module EnterpriseGPO
Import-Module EnterpriseLogging

# Start logging
Start-LogSession -SessionName "GPO_Backup"

try {
    Write-EnterpriseLog -Message "Starting weekly GPO backup"

    # Backup all GPOs with 30-day retention
    $backupResult = Backup-EnterpriseGPO -BackupPath "\\FileServer\GPOBackups" `
        -Compress `
        -IncludeMetadata `
        -RetentionDays 30 `
        -Comment "Automated weekly backup"

    if ($backupResult.Success) {
        Write-EnterpriseLog -Message "GPO backup completed successfully" -AdditionalData @{
            GPOCount   = $backupResult.GPOCount
            BackupPath = $backupResult.BackupPath
            SizeKB     = $backupResult.TotalSizeKB
        }
    }
    else {
        Write-EnterpriseLog -Message "GPO backup failed" -Level Error -AdditionalData @{
            Error = $backupResult.Error
        }
    }
}
catch {
    Write-EnterpriseLog -Message "GPO backup script failed" -Level Error -Exception $_.Exception
    throw
}
finally {
    Stop-LogSession
}
```

### Monthly GPO Health Report

```powershell
Import-Module EnterpriseGPO
Import-Module EnterpriseReporting

# Perform comprehensive health check
$healthResults = Test-GPOHealth -CheckReplication -CheckSysvol -CheckEmpty -CheckUnlinked

# Create report
$report = New-EnterpriseReport -Title "Group Policy Health Report" -Template Executive

# Unhealthy GPOs
$unhealthy = $healthResults | Where-Object { $_.HealthStatus -eq 'Unhealthy' }
$report | Add-ReportSection -Name "Unhealthy GPOs Requiring Attention" -Data $unhealthy

# Empty GPOs
$empty = $healthResults | Where-Object { $_.Issues -match 'Empty GPO' }
if ($empty.Count -gt 0) {
    $report | Add-ReportSection -Name "Empty GPOs (Candidates for Deletion)" -Data $empty
}

# Unlinked GPOs
$unlinked = $healthResults | Where-Object { $_.Issues -match 'Unlinked GPO' }
if ($unlinked.Count -gt 0) {
    $report | Add-ReportSection -Name "Unlinked GPOs (Not Applied Anywhere)" -Data $unlinked
}

# Summary
$summary = [PSCustomObject]@{
    TotalGPOs     = $healthResults.Count
    HealthyGPOs   = ($healthResults | Where-Object { $_.HealthStatus -eq 'Healthy' }).Count
    UnhealthyGPOs = $unhealthy.Count
    EmptyGPOs     = $empty.Count
    UnlinkedGPOs  = $unlinked.Count
    CheckDate     = Get-Date -Format "yyyy-MM-dd HH:mm"
}
$report | Add-ReportTable -Name "Health Summary" -Data $summary

# Export report
$report | Export-ReportToHTML -Path "C:\Reports\GPO_Health_Report.html" -Open
$report | Export-ReportToExcel -Path "C:\Reports\GPO_Health_Report.xlsx" -AutoSize
```

### Pre-Change GPO Comparison

```powershell
# Before making changes, backup and compare
$gpoName = "Default Domain Policy"

# Create backup
$backup = Backup-EnterpriseGPO -GPOName $gpoName -BackupPath "C:\GPOBackups" -IncludeMetadata

Write-Host "Backup created: $($backup.BackupPath)"
Write-Host "Make your changes to the GPO now, then press Enter to compare..."
Read-Host

# Compare current state with backup
$backupId = (Get-ChildItem $backup.BackupPath -Filter "bkupInfo.xml" -Recurse).Directory.Name

Compare-EnterpriseGPO -ReferenceGPO $gpoName `
    -BackupPath $backup.BackupPath `
    -BackupId $backupId `
    -OutputPath "C:\Reports\GPO_Changes_Comparison.html"

Write-Host "Comparison report generated: C:\Reports\GPO_Changes_Comparison.html"
Start-Process "C:\Reports\GPO_Changes_Comparison.html"
```

### GPO Linkage Audit

```powershell
Import-Module EnterpriseGPO
Import-Module EnterpriseReporting

# Get all GPO links
$allLinks = Get-GPOLinkage

# Group by GPO
$linksByGPO = $allLinks | Group-Object GPOName | ForEach-Object {
    [PSCustomObject]@{
        GPOName      = $_.Name
        LinkCount    = $_.Count
        EnabledLinks = ($_.Group | Where-Object { $_.Enabled }).Count
        EnforcedLinks = ($_.Group | Where-Object { $_.Enforced }).Count
        LinkedOUs    = ($_.Group.LinkedTo -join '; ')
    }
} | Sort-Object LinkCount -Descending

# Create report
$report = New-EnterpriseReport -Title "GPO Linkage Audit" -Template Technical

$report | Add-ReportTable -Name "GPO Linkage Summary" -Data $linksByGPO `
    -Columns @('GPOName', 'LinkCount', 'EnabledLinks', 'EnforcedLinks')

# Detailed links
$report | Add-ReportTable -Name "All GPO Links (Detailed)" -Data $allLinks

# Export
$report | Export-ReportToHTML -Path "C:\Reports\GPO_Linkage_Audit.html"
$report | Export-ReportToExcel -Path "C:\Reports\GPO_Linkage_Audit.xlsx" -AutoSize
```

### Disaster Recovery: Restore All GPOs

```powershell
Import-Module EnterpriseGPO
Import-Module EnterpriseLogging

$backupPath = "\\FileServer\GPOBackups\GPO_Backup_20250127"

# Read backup manifest
$manifest = Get-Content (Join-Path $backupPath "backup_manifest.json") | ConvertFrom-Json

Write-EnterpriseLog -Message "Starting GPO restore operation" -AdditionalData @{
    BackupDate = $manifest.BackupDate
    GPOCount   = $manifest.GPOCount
}

foreach ($gpo in $manifest.GPOs) {
    try {
        Write-Host "Restoring: $($gpo.Name)"

        $restoreResult = Restore-EnterpriseGPO -BackupId $gpo.GUID `
            -BackupPath $backupPath `
            -RestoreLinks

        if ($restoreResult.Success) {
            Write-EnterpriseLog -Message "GPO restored successfully" -AdditionalData @{
                GPOName = $gpo.Name
                GPOGUID = $gpo.GUID
            }
        }
    }
    catch {
        Write-EnterpriseLog -Message "Failed to restore GPO" -Level Error -Exception $_.Exception -AdditionalData @{
            GPOName = $gpo.Name
        }
    }
}

Write-EnterpriseLog -Message "GPO restore operation completed"
```

## Integration with Other Modules

### With EnterpriseLogging

```powershell
Import-Module EnterpriseLogging

# Log all GPO operations
Write-EnterpriseLog -Message "Starting GPO backup operation"
$backup = Backup-EnterpriseGPO -BackupPath "C:\GPOBackups" -Compress
Write-EnterpriseLog -Message "Backup completed" -AdditionalData @{
    BackupPath = $backup.BackupPath
    GPOCount   = $backup.GPOCount
}
```

### With EnterpriseReporting

```powershell
Import-Module EnterpriseReporting

# Create comprehensive GPO report
$report = New-EnterpriseReport -Title "GPO Management Report"

$healthResults = Test-GPOHealth -CheckEmpty -CheckUnlinked
$report | Add-ReportSection -Name "GPO Health Status" -Data $healthResults

$linkage = Get-GPOLinkage
$report | Add-ReportSection -Name "GPO Links" -Data $linkage

$report | Export-ReportToHTML -Path "C:\Reports\GPO_Report.html"
```

## Best Practices

1. **Regular Backups** - Schedule weekly automated backups with retention
2. **Pre-Change Backups** - Always backup before modifying GPOs
3. **Test Restores** - Periodically test restore procedures
4. **Health Monitoring** - Monthly health checks for proactive issues
5. **Comparison Audits** - Compare production vs. baseline regularly
6. **Metadata Preservation** - Always include metadata in backups
7. **Compression** - Use compression for space savings
8. **Retention Policies** - Implement 30-90 day retention
9. **Document Changes** - Use Comment parameter in backups

## Performance Considerations

- **Large Domains**: Backup operations may take time with many GPOs
- **Replication Checks**: Checking all DCs can be slow in multi-site environments
- **Compression**: ZIP creation adds time but saves significant space
- **Metadata**: Including metadata increases backup time slightly
- **Comparison**: Deep XML comparison can be resource-intensive

## Troubleshooting

### GroupPolicy Module Not Found

```powershell
# Install RSAT tools on Windows 10/11
Add-WindowsCapability -Online -Name Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0

# Install on Windows Server
Install-WindowsFeature RSAT-GP-PowerShell
```

### Access Denied Errors

Requires permissions:
- GPO management rights in domain
- Read/write access to backup location
- Domain administrator for full restore with links

### Backup Location Issues

```powershell
# Ensure backup path is accessible
Test-Path "\\FileServer\GPOBackups"

# Check permissions
Get-Acl "\\FileServer\GPOBackups"
```

### Replication Check Failures

```powershell
# Check DC connectivity
Test-ADReplicationHealth  # From EnterpriseAD module

# Check SYSVOL replication
repadmin /showrepl
```

## License

Enterprise use only. Review your organization's policies before deployment.

## Version History

### 1.0.0 (2025-12-27)
- Initial release
- 6 public functions for GPO management
- Backup with compression and retention
- Restore with link/permission restoration
- GPO comparison with HTML diff reports
- Enhanced reporting
- Linkage analysis
- Health monitoring
- Integration with EnterpriseLogging and EnterpriseReporting
