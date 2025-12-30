# EnterpriseAD PowerShell Module

Enterprise Active Directory management module for user, computer, and group operations with health monitoring.

## Features

- **Account Management** - Find stale accounts, locked accounts, and expiring passwords
- **Privileged Access Auditing** - Identify users with elevated permissions
- **Group Membership Analysis** - Recursive group expansion with membership paths
- **Inventory Reports** - Comprehensive user and computer inventory
- **Replication Health** - Monitor AD replication status across domain controllers
- **Service Account Detection** - Automatically identify and filter service accounts

## Installation

```powershell
# Import the module
Import-Module "..\EnterpriseAD\EnterpriseAD.psd1"

# Verify installation
Get-Command -Module EnterpriseAD
```

## Prerequisites

- PowerShell 5.1 or higher
- Active Directory PowerShell module (RSAT-AD-PowerShell)
- Domain user account (some functions require elevated privileges)
- Network access to domain controllers

## Quick Start

```powershell
# Import module
Import-Module EnterpriseAD

# Find stale user accounts (90+ days inactive)
Get-ADStaleAccounts -DaysInactive 90 -AccountType User

# Get all privileged users
Get-ADPrivilegedUsers -ShowMembershipPath

# Check AD replication health
Test-ADReplicationHealth -ShowPartners

# Find users with expiring passwords (14 days)
Get-ADPasswordExpiring -DaysAhead 14

# Get computer inventory for servers
Get-ADComputerInventory -OperatingSystem "*Server*"
```

## Functions Reference

### Get-ADStaleAccounts

Finds user and computer accounts that haven't been used within a specified timeframe.

```powershell
# Find all stale accounts (90+ days)
Get-ADStaleAccounts -DaysInactive 90

# Find stale user accounts only
Get-ADStaleAccounts -AccountType User -DaysInactive 180

# Include disabled accounts
Get-ADStaleAccounts -DaysInactive 90 -IncludeDisabled

# Search specific OU
Get-ADStaleAccounts -SearchBase "OU=Users,DC=contoso,DC=com" -DaysInactive 60

# Don't exclude service accounts
Get-ADStaleAccounts -ExcludeServiceAccounts:$false
```

**Parameters:**
- `DaysInactive` - Number of days of inactivity (default: 90)
- `AccountType` - User, Computer, or Both (default: Both)
- `IncludeDisabled` - Include disabled accounts
- `ExcludeServiceAccounts` - Exclude detected service accounts (default: $true)
- `SearchBase` - OU DN to limit search scope

### Get-ADPrivilegedUsers

Retrieves all users with privileged access through group membership.

```powershell
# Get all privileged users
Get-ADPrivilegedUsers

# Show full membership paths
Get-ADPrivilegedUsers -ShowMembershipPath

# Include custom privileged groups
Get-ADPrivilegedUsers -IncludeGroups @('SQL Admins', 'Application Admins')

# Exclude specific groups
Get-ADPrivilegedUsers -ExcludeGroups @('Print Operators')
```

**Default Privileged Groups:**
- Domain Admins
- Enterprise Admins
- Schema Admins
- Administrators
- Account Operators
- Backup Operators
- Server Operators
- Print Operators
- DNSAdmins
- Group Policy Creator Owners

**Parameters:**
- `IncludeGroups` - Additional groups to consider privileged
- `ExcludeGroups` - Groups to exclude from scan
- `ShowMembershipPath` - Show how users gained privilege (nested groups)

### Get-ADPasswordExpiring

Finds user accounts with passwords expiring within a specified timeframe.

```powershell
# Find passwords expiring within 14 days
Get-ADPasswordExpiring -DaysAhead 14

# Find passwords expiring within 30 days
Get-ADPasswordExpiring -DaysAhead 30

# Include accounts with passwords set to never expire
Get-ADPasswordExpiring -IncludeNeverExpire

# Search specific OU
Get-ADPasswordExpiring -SearchBase "OU=Users,DC=contoso,DC=com" -DaysAhead 7
```

**Parameters:**
- `DaysAhead` - Number of days ahead to check (default: 14)
- `IncludeNeverExpire` - Include accounts with PasswordNeverExpires
- `IncludeDisabled` - Include disabled accounts
- `SearchBase` - OU DN to limit search scope

### Get-ADLockedAccounts

Retrieves all currently locked user accounts.

```powershell
# Get all locked accounts
Get-ADLockedAccounts

# Include unlock time calculation
Get-ADLockedAccounts -IncludeUnlockTime

# Search specific OU
Get-ADLockedAccounts -SearchBase "OU=Users,DC=contoso,DC=com"
```

**Parameters:**
- `SearchBase` - OU DN to limit search scope
- `IncludeUnlockTime` - Calculate when account will automatically unlock

### Get-ADGroupMembershipReport

Generates detailed group membership report with recursive expansion.

```powershell
# Get all members of a group
Get-ADGroupMembershipReport -GroupName "Domain Admins"

# Recursively expand nested groups
Get-ADGroupMembershipReport -GroupName "IT Department" -Recursive

# Show membership paths
Get-ADGroupMembershipReport -GroupName "Administrators" -Recursive -ShowMembershipPath

# Filter for specific user
Get-ADGroupMembershipReport -GroupName "IT Department" -UserName "jsmith" -Recursive
```

**Parameters:**
- `GroupName` - Name of the group to analyze (required)
- `UserName` - Filter results for specific user
- `Recursive` - Recursively expand nested groups
- `ShowMembershipPath` - Include full membership path

### Test-ADReplicationHealth

Tests Active Directory replication health across domain controllers.

```powershell
# Check all domain controllers
Test-ADReplicationHealth

# Check specific DC
Test-ADReplicationHealth -DomainController "DC01"

# Show detailed partner information
Test-ADReplicationHealth -ShowPartners

# Check specific DC with partner details
Test-ADReplicationHealth -DomainController "DC01" -ShowPartners
```

**Parameters:**
- `DomainController` - Specific DC to check (optional)
- `ShowPartners` - Include replication partner details

### Get-ADComputerInventory

Generates comprehensive computer inventory from Active Directory.

```powershell
# Get all enabled computers
Get-ADComputerInventory

# Filter by operating system
Get-ADComputerInventory -OperatingSystem "*Server 2022*"

# Include disabled computers
Get-ADComputerInventory -IncludeDisabled

# Only computers active in last 90 days
Get-ADComputerInventory -DaysInactive 90

# Search specific OU
Get-ADComputerInventory -SearchBase "OU=Servers,DC=contoso,DC=com"
```

**Parameters:**
- `OperatingSystem` - Filter by OS (supports wildcards)
- `IncludeDisabled` - Include disabled accounts
- `SearchBase` - OU DN to limit search scope
- `DaysInactive` - Only show computers active within X days

### Get-ADUserInventory

Generates comprehensive user inventory from Active Directory.

```powershell
# Get all enabled users
Get-ADUserInventory

# Filter by department
Get-ADUserInventory -Department "IT*"

# Include disabled users
Get-ADUserInventory -IncludeDisabled

# Only users active in last 90 days
Get-ADUserInventory -DaysInactive 90

# Search specific OU
Get-ADUserInventory -SearchBase "OU=Users,DC=contoso,DC=com"
```

**Parameters:**
- `Department` - Filter by department (supports wildcards)
- `IncludeDisabled` - Include disabled accounts
- `SearchBase` - OU DN to limit search scope
- `DaysInactive` - Only show users active within X days

## Real-World Examples

### Security Audit Report

```powershell
Import-Module EnterpriseAD
Import-Module EnterpriseReporting

# Create security audit report
$report = New-EnterpriseReport -Title "Active Directory Security Audit" -Template Executive

# Privileged users
$privileged = Get-ADPrivilegedUsers -ShowMembershipPath
$report | Add-ReportTable -Name "Privileged Users" -Data $privileged `
    -Columns @('Name', 'SamAccountName', 'Enabled', 'LastLogonDate', 'PrivilegedGroups')

# Stale accounts
$stale = Get-ADStaleAccounts -DaysInactive 90
$report | Add-ReportTable -Name "Stale Accounts (90+ days)" -Data $stale `
    -Columns @('AccountType', 'Name', 'Enabled', 'DaysInactive', 'LastLogonDate')

# Passwords expiring soon
$expiring = Get-ADPasswordExpiring -DaysAhead 14
$report | Add-ReportTable -Name "Passwords Expiring (14 days)" -Data $expiring `
    -Columns @('Name', 'EmailAddress', 'DaysUntilExpiration', 'PasswordExpiresOn')

# Locked accounts
$locked = Get-ADLockedAccounts
$report | Add-ReportTable -Name "Locked Accounts" -Data $locked `
    -Columns @('Name', 'EmailAddress', 'LockoutTime', 'BadPwdCount')

# Export report
$report | Export-ReportToHTML -Path "C:\Reports\AD_SecurityAudit.html" -Open
$report | Export-ReportToExcel -Path "C:\Reports\AD_SecurityAudit.xlsx" -AutoSize
```

### Weekly AD Health Check

```powershell
Import-Module EnterpriseAD
Import-Module EnterpriseLogging

# Start logging session
Start-LogSession -SessionName "AD_HealthCheck"

try {
    Write-EnterpriseLog -Message "Starting AD health check"

    # Check replication health
    $replHealth = Test-ADReplicationHealth -ShowPartners
    $unhealthy = $replHealth | Where-Object { $_.HealthStatus -ne 'Healthy' }

    if ($unhealthy) {
        Write-EnterpriseLog -Message "Replication issues detected" -Level Warning -AdditionalData @{
            UnhealthyDCs = $unhealthy.Count
            DCs = ($unhealthy.DomainController -join ', ')
        }
    }
    else {
        Write-EnterpriseLog -Message "All DCs healthy" -Level Information
    }

    # Check for locked accounts
    $locked = Get-ADLockedAccounts
    if ($locked.Count -gt 0) {
        Write-EnterpriseLog -Message "Locked accounts detected" -Level Warning -AdditionalData @{
            Count = $locked.Count
            Accounts = ($locked.SamAccountName -join ', ')
        }
    }

    # Check for stale accounts
    $stale = Get-ADStaleAccounts -DaysInactive 180
    Write-EnterpriseLog -Message "Stale account scan complete" -Level Information -AdditionalData @{
        StaleUsers = ($stale | Where-Object { $_.AccountType -eq 'User' }).Count
        StaleComputers = ($stale | Where-Object { $_.AccountType -eq 'Computer' }).Count
    }

    Write-EnterpriseLog -Message "AD health check completed successfully"
}
catch {
    Write-EnterpriseLog -Message "AD health check failed" -Level Error -Exception $_.Exception
    throw
}
finally {
    Stop-LogSession
}
```

### Privileged Access Review

```powershell
# Get all privileged users with membership paths
$privileged = Get-ADPrivilegedUsers -ShowMembershipPath

# Filter for unusual cases
$suspiciousPrivileged = $privileged | Where-Object {
    # Users in multiple high-privilege groups
    $_.PrivilegedGroups.Count -gt 2 -or
    # Disabled privileged accounts
    -not $_.Enabled -or
    # Privileged accounts that haven't logged on in 90 days
    ($_.LastLogonDate -and $_.LastLogonDate -lt (Get-Date).AddDays(-90))
}

# Export for review
$suspiciousPrivileged | Export-Csv -Path "C:\Reports\Privileged_Review.csv" -NoTypeInformation

# Create detailed report
$report = New-EnterpriseReport -Title "Privileged Access Review"
$report | Add-ReportTable -Name "Privileged Users Requiring Review" -Data $suspiciousPrivileged
$report | Export-ReportToHTML -Path "C:\Reports\Privileged_Review.html" -Open
```

### User Inventory with Department Analysis

```powershell
# Get full user inventory
$users = Get-ADUserInventory

# Group by department
$byDepartment = $users | Group-Object Department | ForEach-Object {
    [PSCustomObject]@{
        Department = if ($_.Name) { $_.Name } else { '(No Department)' }
        TotalUsers = $_.Count
        EnabledUsers = ($_.Group | Where-Object { $_.Enabled }).Count
        DisabledUsers = ($_.Group | Where-Object { -not $_.Enabled }).Count
        PasswordExpired = ($_.Group | Where-Object { $_.PasswordExpired }).Count
        LockedOut = ($_.Group | Where-Object { $_.LockedOut }).Count
    }
} | Sort-Object TotalUsers -Descending

# Create chart data
$chartData = @{
    Labels = $byDepartment.Department
    Values = $byDepartment.TotalUsers
}

# Generate report
$report = New-EnterpriseReport -Title "User Inventory by Department"
$report | Add-ReportTable -Name "Department Summary" -Data $byDepartment
$report | Add-ReportChart -Name "Users by Department" -ChartData $chartData -Type Bar
$report | Export-ReportToHTML -Path "C:\Reports\User_Inventory.html"
```

## Integration with Other Modules

### With EnterpriseLogging

```powershell
Import-Module EnterpriseLogging

# Configure SIEM
Set-LogConfiguration -EnableSIEM $true -SIEMType Splunk -SIEMEndpoint "https://splunk.local:8088"

# Log all AD operations
Write-EnterpriseLog -Message "Starting privileged user scan"
$privileged = Get-ADPrivilegedUsers
Write-EnterpriseLog -Message "Privileged user scan complete" -AdditionalData @{
    Count = $privileged.Count
}
```

### With EnterpriseReporting

```powershell
Import-Module EnterpriseReporting

# Create comprehensive AD report
$report = New-EnterpriseReport -Title "AD Monthly Report" -Template Executive

$stale = Get-ADStaleAccounts -DaysInactive 90
$report | Add-ReportSection -Name "Stale Accounts" -Data $stale

$privileged = Get-ADPrivilegedUsers
$report | Add-ReportSection -Name "Privileged Users" -Data $privileged

$report | Export-ReportToHTML -Path "C:\Reports\AD_Monthly.html"
```

## Service Account Detection

The module automatically detects service accounts using heuristics:

**Naming Patterns:**
- Contains: svc, service, sql, iis, app, web, db, backup, admin, test

**Description Keywords:**
- "service account", "service user", "application account", "app account"

**Account Properties:**
- PasswordNeverExpires flag

You can disable service account exclusion in functions that support it:

```powershell
Get-ADStaleAccounts -ExcludeServiceAccounts:$false
```

## Best Practices

1. **Use Filtering** - Always use SearchBase to limit scope when possible
2. **Schedule Regular Scans** - Run weekly health checks and monthly audits
3. **Review Privileged Access** - Quarterly privileged user audits
4. **Monitor Stale Accounts** - Disable or delete accounts inactive for 90+ days
5. **Password Expiration Notifications** - Send notifications 14 days before expiration
6. **Log All Operations** - Use EnterpriseLogging for audit trail
7. **Export Reports** - Generate both HTML (viewing) and Excel (analysis)
8. **Replication Monitoring** - Daily replication health checks

## Performance Considerations

- **Large Environments**: Use `-SearchBase` to limit scope
- **Recursive Group Expansion**: Can be slow for deeply nested groups
- **Computer Inventory**: Filter by OperatingSystem or DaysInactive
- **User Inventory**: Use Department or DaysInactive filters
- **Replication Health**: Checking all DCs can be slow in multi-site environments

## Troubleshooting

### Active Directory Module Not Found

```powershell
# Install RSAT tools on Windows 10/11
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0

# Install on Windows Server
Install-WindowsFeature RSAT-AD-PowerShell
```

### Access Denied Errors

Some functions require elevated privileges:
- Test-ADReplicationHealth - Requires replication monitoring rights
- Get-ADPrivilegedUsers - Requires read access to privileged groups

### Slow Performance

For large environments:
```powershell
# Use SearchBase to limit scope
Get-ADStaleAccounts -SearchBase "OU=Users,DC=contoso,DC=com"

# Filter early
Get-ADComputerInventory -DaysInactive 90 -OperatingSystem "*Server*"

# Avoid unnecessary recursion
Get-ADGroupMembershipReport -GroupName "Small Group" -Recursive:$false
```

## License

Enterprise use only. Review your organization's policies before deployment.

## Version History

### 1.0.0 (2025-12-27)
- Initial release
- 8 public functions for AD management
- Service account detection
- Recursive group expansion
- Replication health monitoring
- Integration with EnterpriseLogging and EnterpriseReporting
