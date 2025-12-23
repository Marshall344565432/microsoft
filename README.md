# Microsoft Enterprise Infrastructure

**Windows Server & Microsoft Technologies** - Enterprise administration, security, automation, and infrastructure management.

---

## Overview

Comprehensive repository for Microsoft enterprise infrastructure including Windows Server, Active Directory, Group Policy, Certificate Authority, WSUS, and security configurations. Focused on CIS compliance, automation, and operational excellence.

---

## Repository Structure

```
microsoft/
├── wsus/             # Windows Server Update Services (air-gapped patching)
├── gpos/             # Group Policy Objects (security, configuration)
├── firewall/         # Windows Firewall policies and automation
├── audits/           # Security audits, compliance scanning
├── ca-server/        # Certificate Authority management
├── active-directory/ # AD administration scripts (future)
├── powershell/       # PowerShell modules and automation
└── docs/             # Documentation, runbooks, guides
```

---

## Key Components

### 1. WSUS (Windows Server Update Services)
**Location:** `/wsus/`

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

### 2. Group Policy Objects (GPOs)
**Location:** `/gpos/`

Enterprise Group Policy configurations:
- **Security Baselines** - CIS, DISA STIG policies
- **User Policies** - Desktop configuration, restrictions
- **Computer Policies** - System hardening, firewall rules
- **Audit Policies** - Logging, compliance tracking
- **Deployment** - GPO backup/restore, migration scripts

### 3. Windows Firewall
**Location:** `/firewall/`

Windows Defender Firewall management:
- **Zone Configurations** - Domain, private, public profiles
- **Rule Management** - Inbound/outbound rules, automation
- **IPsec Policies** - Connection security rules
- **Logging & Monitoring** - Firewall log analysis
- **PowerShell Automation** - Bulk rule deployment

### 4. Security Audits
**Location:** `/audits/`

Security compliance and auditing:
- **CIS Benchmarks** - Windows Server compliance scanning
- **Security Baselines** - Microsoft Security Compliance Toolkit
- **Audit Policies** - Advanced audit policy configuration
- **Log Analysis** - Security event monitoring
- **Compliance Reports** - Automated reporting, dashboards

### 5. Certificate Authority (CA)
**Location:** `/ca-server/`

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
- **Windows Defender** - Firewall, antivirus
- **Security Baselines** - CIS, DISA STIG

---

## Prerequisites

- Windows Server 2019+ (2022+ recommended)
- PowerShell 5.1+ (7.x for cross-platform)
- Administrator privileges
- Active Directory domain (for some features)

---

## Getting Started

1. **WSUS:** Review `/wsus/docs/WSUS_PACK_AUDIT_REPORT.md`
2. **GPOs:** Check security baselines in `/gpos/`
3. **Firewall:** Review rule templates in `/firewall/`
4. **Audits:** Run baseline compliance scans
5. **CA Server:** Review PKI design documentation

---

## Best Practices

- **Test in lab first** - Validate all changes before production
- **Version control GPOs** - Track all policy changes
- **Backup CA regularly** - Critical PKI infrastructure
- **Monitor WSUS health** - Run weekly health checks
- **Document exceptions** - Track CIS/STIG deviations
- **PowerShell signing** - Use code signing for scripts

---

## Security Considerations

- **Least Privilege** - Use minimal required permissions
- **CIS Hardening** - Apply benchmarks incrementally
- **Audit Logging** - Enable comprehensive logging
- **WSUS SSL** - Use HTTPS for WSUS (recommended)
- **CA Security** - Hardware Security Module (HSM) for root CA
- **GPO Testing** - Use WMI filters, security filtering

---

## Status

**Repository Status:**
- ✅ WSUS: Production-ready (v9.1.2, v8.2.0)
- 🔄 GPOs: Content development in progress
- 🔄 Firewall: Content development in progress
- 🔄 Audits: Content development in progress
- 🔄 CA Server: Content development in progress

**Last Updated:** 2025-12-22
