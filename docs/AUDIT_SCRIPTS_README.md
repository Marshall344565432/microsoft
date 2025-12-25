# Audit and Automation Scripts

Comprehensive audit baseline and automation scripts for Windows Server 2022 enterprise infrastructure.

## Overview

This collection provides production-ready PowerShell scripts for:
- **Security Auditing** - CIS compliance, GPO health, Firewall configuration
- **Infrastructure Monitoring** - AD health, Certificate expiration
- **Automation** - Automated certificate renewal

All scripts are:
- PowerShell 5.1+ compatible
- Windows Server 2022 tested
- Production-ready with comprehensive error handling
- HTML/CSV/JSON report generation
- Detailed logging

---

## Audit Scripts

### 1. CIS Benchmark Audit
**Location:** `/audits/cis-benchmarks/Get-CISAuditBaseline.ps1`

Performs comprehensive CIS Level 1 & 2 compliance audit:
- Password policies
- Account lockout policies
- User rights assignments
- Audit policies
- Windows Firewall settings
- Remote Desktop configuration
- Security options
- Service configurations

**Usage:**
```powershell
# Level 1 audit with HTML report
.\Get-CISAuditBaseline.ps1

# Level 2 audit with JSON output
.\Get-CISAuditBaseline.ps1 -Level 2 -ExportFormat JSON

# Custom output path
.\Get-CISAuditBaseline.ps1 -OutputPath "D:\Reports" -Level 1
```

**Output:**
- HTML report with compliance dashboard
- Pass/Fail status for each check
- Compliance percentage
- Detailed findings

---

### 2. GPO Health Audit
**Location:** `/gpos/deployment/Get-GPOAuditBaseline.ps1`

Comprehensive Group Policy health check:
- GPO replication status across all DCs
- Unlinked and orphaned GPOs
- Version mismatches (AD vs SYSVOL)
- GPO permissions and delegation
- WMI filter status
- Security filtering validation

**Usage:**
```powershell
# Basic GPO audit
.\Get-GPOAuditBaseline.ps1

# With replication check
.\Get-GPOAuditBaseline.ps1 -CheckReplication

# Domain-specific audit
.\Get-GPOAuditBaseline.ps1 -Domain "contoso.com" -ExportFormat JSON
```

**Output:**
- GPO health status dashboard
- Replication issues
- Unlinked GPOs list
- Version mismatch details
- Permission audit results

---

### 3. Firewall Audit
**Location:** `/firewall/scripts/Get-FirewallAuditBaseline.ps1`

Windows Defender Firewall with Advanced Security audit:
- Firewall profile status (Domain, Private, Public)
- Inbound/Outbound rule inventory
- Security risk analysis
- Default action policies
- IPSec configuration
- Logging configuration
- CIS compliance validation

**Usage:**
```powershell
# Basic firewall audit
.\Get-FirewallAuditBaseline.ps1

# With detailed rule inventory
.\Get-FirewallAuditBaseline.ps1 -IncludeRuleDetails

# Export to CSV
.\Get-FirewallAuditBaseline.ps1 -ExportFormat CSV
```

**Output:**
- Firewall profile compliance status
- Security risk analysis (High/Medium/Low)
- Overly permissive rule detection
- Logging configuration status
- CIS compliance metrics

---

### 4. Active Directory Health Audit
**Location:** `/active-directory/health-checks/Get-ADHealthAuditBaseline.ps1`

Comprehensive AD infrastructure health check:
- Domain Controller health and uptime
- AD replication status
- FSMO role validation
- DNS configuration
- Stale computer/user accounts
- Critical service status
- SYSVOL/NETLOGON share status

**Usage:**
```powershell
# Standard AD health check
.\Get-ADHealthAuditBaseline.ps1

# Custom stale account thresholds
.\Get-ADHealthAuditBaseline.ps1 -StaleComputerDays 60 -StaleUserDays 90

# Domain-specific with JSON output
.\Get-ADHealthAuditBaseline.ps1 -Domain "corp.contoso.com" -ExportFormat JSON
```

**Output:**
- DC health dashboard
- Replication status matrix
- FSMO role holder status
- Stale account reports
- DNS health validation
- Overall infrastructure health score

---

### 5. Certificate Expiration Monitor
**Location:** `/ca-server/monitoring/Get-CertificateExpirationMonitor.ps1`

Certificate lifecycle monitoring:
- Local computer certificate stores
- ADCS issued certificates
- Certificate template tracking
- Expiration alerts
- Email notifications

**Usage:**
```powershell
# Monitor certificates expiring in 30 days
.\Get-CertificateExpirationMonitor.ps1

# Custom threshold with email alerts
.\Get-CertificateExpirationMonitor.ps1 -DaysToExpire 60 -SendEmail -SMTPServer "smtp.domain.com" -EmailTo "admin@domain.com" -EmailFrom "certs@domain.com"

# Specific CA server
.\Get-CertificateExpirationMonitor.ps1 -CAServerName "CA01.domain.com"
```

**Output:**
- Certificate expiration dashboard
- Expired certificates (CRITICAL)
- Certificates expiring soon (WARNING)
- Valid certificates count
- Email alerts for action items

---

## Automation Scripts

### 6. Automated Certificate Renewal
**Location:** `/ca-server/scripts/Invoke-AutomatedCertificateRenewal.ps1`

Automated certificate renewal via auto-enrollment:
- Triggers auto-enrollment policy
- Identifies certificates for renewal
- Manual renewal fallback
- Service restart automation
- Email notifications

**Usage:**
```powershell
# Renew certificates expiring within 30 days
.\Invoke-AutomatedCertificateRenewal.ps1

# Force renewal with service restart
.\Invoke-AutomatedCertificateRenewal.ps1 -DaysBeforeExpiration 60 -Force -RestartServices

# Test mode (dry run)
.\Invoke-AutomatedCertificateRenewal.ps1 -TestMode

# Specific template with notifications
.\Invoke-AutomatedCertificateRenewal.ps1 -TemplateName "WebServer" -SendNotification -SMTPServer "smtp.domain.com" -EmailTo "admin@domain.com" -EmailFrom "certs@domain.com"

# Production automation with all features
.\Invoke-AutomatedCertificateRenewal.ps1 -DaysBeforeExpiration 30 -RestartServices -SendNotification -SMTPServer "smtp.domain.com" -EmailTo "admin@domain.com" -EmailFrom "certs@domain.com"
```

**Features:**
- Auto-enrollment trigger via `certutil -pulse`
- GPO refresh before renewal
- Automatic verification of renewal success
- Manual renewal fallback if auto-enrollment fails
- Service restart (IIS, WinRM, etc.) after renewal
- Comprehensive logging
- Email notifications

**Output:**
- Renewal success/failure status
- Renewed certificate details
- Failed renewal diagnostics
- Restarted services list
- Email notification summary

---

## Scheduling Automation

### Recommended Schedule (Task Scheduler)

#### Daily Audits
```powershell
# Certificate Monitoring (Daily at 7:00 AM)
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\Get-CertificateExpirationMonitor.ps1 -SendEmail -SMTPServer smtp.domain.com -EmailTo admin@domain.com -EmailFrom certs@domain.com"
$Trigger = New-ScheduledTaskTrigger -Daily -At 7:00AM
$Principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "Daily Certificate Monitoring" -Action $Action -Trigger $Trigger -Principal $Principal
```

#### Weekly Audits
```powershell
# AD Health Check (Weekly on Monday at 6:00 AM)
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\Get-ADHealthAuditBaseline.ps1"
$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 6:00AM
$Principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "Weekly AD Health Audit" -Action $Action -Trigger $Trigger -Principal $Principal

# GPO Audit (Weekly on Tuesday at 6:00 AM)
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\Get-GPOAuditBaseline.ps1 -CheckReplication"
$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Tuesday -At 6:00AM
$Principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "Weekly GPO Health Audit" -Action $Action -Trigger $Trigger -Principal $Principal

# Firewall Audit (Weekly on Wednesday at 6:00 AM)
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\Get-FirewallAuditBaseline.ps1"
$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Wednesday -At 6:00AM
$Principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "Weekly Firewall Audit" -Action $Action -Trigger $Trigger -Principal $Principal
```

#### Monthly Audits
```powershell
# CIS Compliance Audit (Monthly on 1st at 6:00 AM)
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\Get-CISAuditBaseline.ps1 -Level 2"
$Trigger = New-ScheduledTaskTrigger -Daily -At 6:00AM
$Trigger.DaysInterval = 30
$Principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "Monthly CIS Compliance Audit" -Action $Action -Trigger $Trigger -Principal $Principal
```

#### Certificate Renewal Automation
```powershell
# Certificate Renewal (Daily at 2:00 AM)
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\Invoke-AutomatedCertificateRenewal.ps1 -DaysBeforeExpiration 30 -RestartServices -SendNotification -SMTPServer smtp.domain.com -EmailTo admin@domain.com -EmailFrom certs@domain.com"
$Trigger = New-ScheduledTaskTrigger -Daily -At 2:00AM
$Principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "Automated Certificate Renewal" -Action $Action -Trigger $Trigger -Principal $Principal
```

---

## Output Directories

All scripts use standard output paths (can be customized):

```
C:\Audits\
├── CIS\              # CIS compliance reports
├── GPO\              # GPO health reports
├── Firewall\         # Firewall audit reports
├── AD\               # AD health reports
└── Certificates\     # Certificate monitoring reports

C:\Logs\
└── CertificateRenewal\  # Certificate renewal logs
```

---

## Prerequisites

### Required Modules
- **ActiveDirectory** (for AD and GPO scripts)
- **GroupPolicy** (for GPO scripts)
- **NetSecurity** (for Firewall scripts)

### Required Permissions
- **Local Administrator** (for CIS, Firewall, Certificate scripts)
- **Domain Admin or equivalent** (for AD, GPO scripts)
- **Certificate Authority access** (for certificate scripts)

### Required Roles/Features
- **Active Directory Domain Services** (for AD/GPO scripts)
- **Active Directory Certificate Services** (for certificate scripts)

---

## Best Practices

1. **Test in Lab First**
   - Always validate scripts in non-production environment
   - Review audit results before remediation

2. **Scheduled Execution**
   - Use Task Scheduler for automated audits
   - Stagger audit times to avoid resource contention

3. **Email Alerts**
   - Configure SMTP for critical alerts
   - Monitor certificate expiration alerts daily

4. **Report Retention**
   - Maintain audit history for compliance
   - Archive reports monthly

5. **Certificate Renewal**
   - Schedule renewal automation daily at off-peak hours
   - Monitor renewal logs for failures
   - Configure service restart during maintenance windows

6. **Review Cycle**
   - Weekly: Review AD health, GPO status, Firewall configuration
   - Monthly: Review CIS compliance reports
   - Quarterly: Audit stale accounts and certificate inventory

---

## Troubleshooting

### Common Issues

**Issue:** Script execution policy error
```powershell
# Solution: Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

**Issue:** Module not found
```powershell
# Solution: Install required modules
Import-Module ActiveDirectory
Import-Module GroupPolicy
Import-Module NetSecurity
```

**Issue:** Access denied
```powershell
# Solution: Run as Administrator with proper permissions
# Verify: whoami /priv
```

**Issue:** Certificate renewal fails
```powershell
# Solution: Verify auto-enrollment GPO
gpresult /h gpresult.html
# Check: Computer Configuration > Policies > Windows Settings > Security Settings > Public Key Policies > Certificate Services Client - Auto-Enrollment
```

---

## Support

For issues or questions:
1. Check script logs in output directories
2. Review error messages in script output
3. Verify prerequisites and permissions
4. Consult Windows Server 2022 documentation

---

**Version:** 1.0.0
**Last Updated:** 2025-12-25
**Compatibility:** Windows Server 2022, PowerShell 5.1+
