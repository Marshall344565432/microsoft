# Microsoft Enterprise Infrastructure

**Windows Server & Microsoft Technologies** - Enterprise administration, security, automation, and infrastructure management.

---

## Overview

Comprehensive repository for Microsoft enterprise infrastructure including Windows Server, Active Directory, Group Policy, Certificate Authority, WSUS, and security configurations. Focused on CIS compliance, automation, and operational excellence.

---

## Repository Structure

```
microsoft/
├── wsus/                   # Windows Server Update Services (air-gapped patching)
├── gpos/                   # Group Policy Objects and security baselines
│   ├── security-baselines/ # CIS Level 1 GPO templates
│   └── scripts/            # Import/export automation
├── firewall/               # Windows Defender Firewall management
│   ├── rules/              # Firewall rule templates (JSON)
│   ├── profiles/           # Profile configurations
│   └── scripts/            # Deployment automation
├── modules/                # Enterprise PowerShell modules
│   ├── EnterpriseLogging/  # Centralized logging (SIEM integration)
│   └── EnterpriseReporting/# Professional HTML/Excel reports
├── audits/                 # Security audits, compliance scanning
├── ca-server/              # Certificate Authority management
└── docs/                   # Documentation, runbooks, guides
```

---

## Key Components

### 1. WSUS (Windows Server Update Services) ✅
**Location:** `/wsus/` | **Status:** Production-Ready

Complete air-gapped patch management solution for Windows infrastructure:
- **Export/Import** - Offline update transfer (v9.x Server 2022+, v8.x legacy)
- **Maintenance** - Surgical decline, automatic approvals, cleanup
- **Health Checks** - Infrastructure validation, ACL repair
- **Audit** - CIS compliance, patch compliance tracking
- **Setup** - Automated WSUS server initialization

**Production Scripts:**
- Export v9.1.0, Import v9.1.2 (Server 2022/2025)
- Export v8.2.0, Import v8.2.0 (Server 2016/2019)
- Health Check v3.9.2, Comprehensive Audit v2.0
- Maintenance v4.0.12, Initialize v2.9.0

### 2. Group Policy Objects (GPOs) ✅
**Location:** `/gpos/` | **Status:** Production-Ready

CIS-compliant GPO templates and automation:

**Security Baselines** (`/gpos/security-baselines/`):
- CIS Level 1 - Member Server template
  - Password policies (14 char min, 365 day max age)
  - User rights assignments (least privilege)
  - Security options (UAC, SMB signing, NTLM)
  - Advanced audit policies (CIS 17.x controls)
  - GptTmpl.inf, registry.pol, audit.csv

**Automation Scripts** (`/gpos/scripts/`):
- `Import-SecurityBaselineGPO.ps1` - Import with customization
- `Export-AllGPOs.ps1` - Backup all domain GPOs
- Features: WSUS server config, admin subnet updates, OU linking

### 3. Windows Defender Firewall ✅
**Location:** `/firewall/` | **Status:** Production-Ready

Complete CIS-compliant firewall management:

**Rule Templates** (`/firewall/rules/`):
- `CIS_Domain_Profile_Rules.json` - Core management (RDP, WinRM, ICMP)
- `DomainController_Rules.json` - 15 AD DS service rules
- `WebServer_Rules.json` - IIS/HTTPS configuration

**Profile Settings** (`/firewall/profiles/`):
- `CIS_Firewall_Profile_Settings.json` - Domain/Private/Public profiles
- CIS 9.1.x, 9.2.x, 9.3.x compliant settings
- Logging configuration (16MB+, allowed & blocked)

**Automation Scripts** (`/firewall/scripts/`):
- `Set-CISFirewallBaseline.ps1` - Automated deployment
- `Get-FirewallAuditBaseline.ps1` - CIS compliance audit
- `Export-FirewallRules.ps1` / `Import-FirewallRules.ps1` - Backup/restore

### 4. Enterprise PowerShell Modules ✅ (4 of 6)
**Location:** `/modules/` | **Status:** Active Development

Production-ready reusable PowerShell modules:

**EnterpriseLogging** (v1.0.0) - Centralized logging with SIEM integration
- Structured JSON file logging with correlation IDs
- Windows Event Log integration
- SIEM forwarding (Splunk, Elasticsearch, Azure Sentinel)
- Automatic log rotation and retention
- Session management for grouped operations

**EnterpriseReporting** (v1.0.0) - Professional multi-format reports
- HTML reports with responsive design and sortable tables
- CSV/JSON export for automation
- Excel export with formatting (requires ImportExcel)
- 4 professional templates (Default, Executive, Technical, Minimal)
- Chart visualizations (bar, pie, line)

**EnterpriseAD** (v1.0.0) - Active Directory management and health monitoring
- Account management (stale accounts, locked accounts, password expiring)
- Privileged access auditing with nested group expansion
- Group membership analysis with membership paths
- Computer and user inventory reports
- AD replication health monitoring
- Service account detection and filtering

**EnterpriseGPO** (v1.0.0) - Group Policy management and automation
- GPO backup and restore with compression and retention policies
- GPO comparison with HTML diff reports
- Enhanced reporting with links, permissions, and WMI filters
- Complete GPO linkage analysis across the domain
- Health monitoring (replication, sysvol, empty GPOs, unlinked GPOs)
- Metadata preservation for disaster recovery

**Planned Modules:**
- EnterpriseCertificate - PKI management
- EnterpriseNotifications - Teams/Slack/Email

[📖 Full Modules Documentation](./modules/README.md)

### 5. Security Audits
**Location:** `/audits/` | **Status:** In Development

Security compliance and auditing:
- **CIS Benchmarks** - Windows Server compliance scanning
- **Security Baselines** - Microsoft Security Compliance Toolkit
- **Audit Policies** - Advanced audit policy configuration
- **Log Analysis** - Security event monitoring
- **Compliance Reports** - Automated reporting, dashboards

### 6. Certificate Authority (CA)
**Location:** `/ca-server/` | **Status:** In Development

Enterprise PKI and Certificate Authority management:
- **CA Setup** - Standalone/Enterprise CA deployment
- **Certificate Templates** - Custom template design
- **Issuance & Revocation** - Certificate lifecycle management
- **CRL/OCSP** - Certificate validation infrastructure
- **Backup/Recovery** - CA database backup automation
- **Monitoring** - CA health checks, expiration tracking

---

## Technologies Covered

- **Windows Server** - 2019, 2022, 2025
- **WSUS** - Windows Server Update Services
- **Active Directory** - Domain Services, Group Policy
- **Certificate Services** - Enterprise PKI
- **PowerShell** - 5.1, 7.x automation
- **Windows Defender** - Firewall with Advanced Security
- **Security Baselines** - CIS Benchmark, Microsoft SCT

---

## Quick Start

### WSUS Offline Patching

```powershell
# Export updates from internet-connected WSUS
.\wsus\scripts\Export-WSUSUpdates-v9.ps1 -ExportPath "\\share\updates" -MonthsBack 3

# Import to air-gapped WSUS
.\wsus\scripts\Import-WSUSUpdates-v9.ps1 -ImportPath "E:\updates" -ApproveUpdates
```

### GPO Deployment

```powershell
# Import CIS Level 1 baseline
.\gpos\scripts\Import-SecurityBaselineGPO.ps1 `
    -TemplatePath ".\gpos\security-baselines\CIS-Level1-MemberServer" `
    -GPOName "CIS-Baseline-Servers" `
    -LinkToOU "OU=Servers,DC=contoso,DC=com" `
    -CreateIfNeeded
```

### Firewall Deployment

```powershell
# Deploy CIS-compliant firewall baseline
.\firewall\scripts\Set-CISFirewallBaseline.ps1 `
    -ServerRole DomainController `
    -AdminSubnet "192.168.1.0/24"

# Audit compliance
.\firewall\scripts\Get-FirewallAuditBaseline.ps1 -Verbose
```

### PowerShell Modules

```powershell
# Import modules
Import-Module ".\modules\EnterpriseLogging\EnterpriseLogging.psd1"
Import-Module ".\modules\EnterpriseReporting\EnterpriseReporting.psd1"
Import-Module ".\modules\EnterpriseAD\EnterpriseAD.psd1"

# Example: AD security audit with logging and reporting
Start-LogSession -SessionName "ADSecurityAudit"
Write-EnterpriseLog -Message "Starting AD security audit"

$report = New-EnterpriseReport -Title "AD Security Audit" -Template Executive

# Get privileged users
$privileged = Get-ADPrivilegedUsers -ShowMembershipPath
$report | Add-ReportTable -Name "Privileged Users" -Data $privileged

# Get stale accounts
$stale = Get-ADStaleAccounts -DaysInactive 90
$report | Add-ReportTable -Name "Stale Accounts" -Data $stale

# Export report
$report | Export-ReportToHTML -Path "C:\Reports\AD_SecurityAudit.html" -Open

Write-EnterpriseLog -Message "Security audit completed successfully"
Stop-LogSession
```

---

## Prerequisites

- Windows Server 2019+ (2022+ recommended)
- PowerShell 5.1+ (7.x for cross-platform)
- Administrator privileges
- Active Directory domain (for GPO/AD features)
- RSAT tools (Group Policy Management, AD DS)

---

## Best Practices

- **Test in lab first** - Validate all changes before production
- **Use correlation IDs** - Track multi-step operations with logging
- **Backup before changes** - Export GPOs/firewall rules before modifications
- **Version control** - Track all configuration changes
- **Monitor WSUS health** - Run weekly health checks
- **Document exceptions** - Track CIS/STIG deviations
- **SIEM integration** - Forward logs for centralized monitoring
- **Regular audits** - Monthly compliance validation

---

## Security Considerations

- **Least Privilege** - Use minimal required permissions
- **CIS Hardening** - Apply benchmarks incrementally
- **Audit Logging** - Enable comprehensive logging (CIS 17.x)
- **WSUS SSL** - Use HTTPS for WSUS (recommended)
- **CA Security** - Hardware Security Module (HSM) for root CA
- **GPO Testing** - Use WMI filters, security filtering
- **Firewall Logging** - 16MB+ log size, log allowed & blocked
- **Code Signing** - Sign all PowerShell scripts in production

---

## Repository Status

| Component | Status | Version | Description |
|-----------|--------|---------|-------------|
| **WSUS** | ✅ Production | v9.1.2 / v8.2.0 | Complete offline patching solution |
| **GPOs** | ✅ Production | v1.0 | CIS Level 1 templates + automation |
| **Firewall** | ✅ Production | v1.0 | CIS-compliant rules + profiles |
| **PowerShell Modules** | ✅ Partial | v1.0 | 4 of 6 modules complete |
| **Audits** | 🔄 In Progress | - | Security compliance scanning |
| **CA Server** | 🔄 In Progress | - | PKI management tools |

---

## Contributing

These tools are maintained by the Enterprise IT team. For issues, feature requests, or contributions, contact your IT department.

---

## License

Enterprise use only. Review your organization's policies before deployment.

---

## Recent Updates

**2025-12-27:**
- ✅ Added EnterpriseGPO PowerShell module (v1.0.0)
- ✅ Added EnterpriseAD PowerShell module (v1.0.0)
- ✅ Added EnterpriseLogging PowerShell module (v1.0.0)
- ✅ Added EnterpriseReporting PowerShell module (v1.0.0)
- ✅ Added CIS Level 1 GPO templates with import/export scripts
- ✅ Added CIS-compliant firewall rules and deployment automation
- ✅ Complete documentation for all new components

**2025-12-22:**
- ✅ WSUS Export/Import scripts v9.1.0+
- ✅ Health Check and Audit scripts
- ✅ Complete WSUS documentation

---

**Last Updated:** 2025-12-27
