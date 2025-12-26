# Windows Firewall Management

CIS-compliant Windows Defender Firewall with Advanced Security configurations and automation for Windows Server 2022.

## Quick Start

1. **Review the Deployment Guide**: [FIREWALL_DEPLOYMENT_GUIDE.md](FIREWALL_DEPLOYMENT_GUIDE.md)
2. **Choose your server role**: Review rule templates in `/rules/`
3. **Deploy baseline**: Run `Set-CISFirewallBaseline.ps1` with appropriate role
4. **Validate**: Run `Get-FirewallAuditBaseline.ps1` (in `/scripts/`)

## Structure

```
firewall/
├── FIREWALL_DEPLOYMENT_GUIDE.md         # Complete deployment documentation
├── rules/                                # Firewall rule templates (JSON)
│   ├── CIS_Domain_Profile_Rules.json    # Core management rules for all servers
│   ├── DomainController_Rules.json      # Domain Controller specific rules
│   └── WebServer_Rules.json             # Web Server specific rules
├── profiles/                             # Profile configuration templates
│   └── CIS_Firewall_Profile_Settings.json   # CIS-compliant profile settings
└── scripts/                              # PowerShell automation scripts
    ├── Get-FirewallAuditBaseline.ps1    # CIS compliance audit script
    ├── Set-CISFirewallBaseline.ps1      # Automated deployment script
    ├── Export-FirewallRules.ps1         # Export rules to JSON/CSV/WFW
    └── Import-FirewallRules.ps1         # Import rules from backup/template
```

## Documentation

### Main Guide
- **[FIREWALL_DEPLOYMENT_GUIDE.md](FIREWALL_DEPLOYMENT_GUIDE.md)** - Complete deployment guide including:
  - CIS Benchmark requirements (9.1.x, 9.2.x, 9.3.x)
  - Profile configuration strategies
  - Role-specific rule templates (DC, File, Web, SQL, CA, WSUS)
  - PowerShell automation examples
  - Testing and validation procedures
  - Troubleshooting guide

## Rule Templates

### Core Rules (All Servers)
- **CIS_Domain_Profile_Rules.json** - Base rules for all domain-joined servers
  - Remote Desktop (RDP) - restricted to admin subnet
  - WinRM (PowerShell Remoting)
  - ICMP (Ping)
  - Server Manager Remote Management

### Role-Specific Rules
- **DomainController_Rules.json** - Complete AD DS firewall rules
  - DNS, Kerberos, LDAP/LDAPS, Global Catalog
  - SMB, RPC, NTP, DFS-R
  - 15+ rules covering all DC services

- **WebServer_Rules.json** - IIS Web Server rules
  - HTTP/HTTPS
  - FTP/FTPS (disabled by default)
  - Web Management Service
  - Security recommendations included

### Additional Templates Available
Create additional role templates following the same JSON structure:
- File Server
- SQL Server
- Certificate Authority
- WSUS Server

## Scripts

### Set-CISFirewallBaseline.ps1
Deploy CIS-compliant firewall configuration with role-specific rules.

```powershell
# Deploy Domain Controller firewall baseline
.\Set-CISFirewallBaseline.ps1 -ServerRole DomainController -AdminSubnet 192.168.1.0/24

# Deploy Web Server firewall baseline
.\Set-CISFirewallBaseline.ps1 -ServerRole WebServer -ApplyOnly
```

**Parameters:**
- `ServerRole`: DomainController, FileServer, WebServer, SQLServer, CA, WSUS, Generic
- `AdminSubnet`: Admin subnet for RDP/WinRM (default: 10.0.1.0/24)
- `LogPath`: Firewall log location
- `LogMaxSize`: Log file size in KB (default: 16384)
- `ApplyOnly`: Skip confirmation prompts

### Export-FirewallRules.ps1
Export current firewall configuration for backup or migration.

```powershell
# Export all rules to JSON
.\Export-FirewallRules.ps1 -ExportPath C:\Backup -Format JSON

# Export Domain profile rules to all formats
.\Export-FirewallRules.ps1 -Profile Domain -Format All

# Export specific group to CSV
.\Export-FirewallRules.ps1 -RuleGroup "Remote Management" -Format CSV
```

**Exports:**
- JSON (detailed rule information + metadata)
- CSV (spreadsheet-compatible)
- WFW (native Windows Firewall format)
- Profile settings (separate JSON file)

### Import-FirewallRules.ps1
Import firewall rules from JSON or WFW backup.

```powershell
# Merge rules from JSON (keeps existing)
.\Import-FirewallRules.ps1 -ImportPath C:\Backup\FirewallRules.json -Mode Merge

# Replace all rules from WFW file (creates backup first)
.\Import-FirewallRules.ps1 -ImportPath C:\Backup\FirewallConfig.wfw -Mode Replace -Backup

# Preview import without applying
.\Import-FirewallRules.ps1 -ImportPath .\rules.json -WhatIf
```

**Features:**
- Automatic backup before import
- Merge or Replace modes
- WhatIf support for testing
- Error handling and rollback guidance

### Get-FirewallAuditBaseline.ps1
Comprehensive CIS compliance audit for Windows Defender Firewall.

```powershell
# Run full audit
.\Get-FirewallAuditBaseline.ps1 -Verbose

# Export audit results
.\Get-FirewallAuditBaseline.ps1 -ExportPath C:\Audits
```

**Checks:**
- Profile settings (Enabled, Default Actions, Logging)
- CIS Benchmark compliance (9.1.x, 9.2.x, 9.3.x)
- Rule inventory and analysis
- Security risks and recommendations

## CIS Benchmark Compliance

This repository implements CIS Microsoft Windows Server 2022 Benchmark v2.0.0, Section 9:

### Level 1 Controls
- **9.1.1** - Domain firewall enabled ✓
- **9.1.2** - Default inbound block ✓
- **9.1.3** - Default outbound allow ✓
- **9.1.4** - Logging configured (16MB+) ✓
- **9.2.x** - Private profile settings ✓
- **9.3.x** - Public profile settings ✓

### Level 2 Controls
- Log allowed connections ✓
- Disable local firewall rules ✓
- Disable local IPsec rules ✓

See [FIREWALL_DEPLOYMENT_GUIDE.md](FIREWALL_DEPLOYMENT_GUIDE.md#cis-benchmark-requirements) for complete mapping.

## Deployment Workflow

### 1. Lab Testing
```powershell
# Deploy to test server
.\Set-CISFirewallBaseline.ps1 -ServerRole DomainController -AdminSubnet 10.0.1.0/24

# Validate configuration
.\Get-FirewallAuditBaseline.ps1 -Verbose

# Test connectivity
Test-NetConnection DC01 -Port 389  # LDAP
Test-NetConnection DC01 -Port 88   # Kerberos
```

### 2. Production Deployment
```powershell
# Export current config (backup)
.\Export-FirewallRules.ps1 -ExportPath C:\Backup\Before -Format All

# Deploy new baseline
.\Set-CISFirewallBaseline.ps1 -ServerRole WebServer -ApplyOnly

# Verify and test
.\Get-FirewallAuditBaseline.ps1
```

### 3. Continuous Compliance
```powershell
# Schedule monthly audits via Task Scheduler
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\Scripts\Get-FirewallAuditBaseline.ps1"
$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 3am
Register-ScheduledTask -TaskName "Firewall-Audit" -Action $Action -Trigger $Trigger
```

## Profile Settings Summary

| Setting | Domain | Private | Public |
|---------|--------|---------|--------|
| Enabled | ON | ON | ON |
| Inbound Default | BLOCK | BLOCK | BLOCK |
| Outbound Default | ALLOW | ALLOW | **BLOCK** |
| Local Rules | BLOCK | BLOCK | BLOCK |
| Log Blocked | YES | YES | YES |
| Log Allowed | YES | YES | YES |
| Log Size | 16 MB | 16 MB | 16 MB |

**Note:** Public profile blocks outbound by default - most restrictive for untrusted networks.

## Common Server Roles

### Domain Controller
- DNS (TCP/UDP 53)
- Kerberos (TCP/UDP 88)
- LDAP (TCP/UDP 389, TCP 636)
- Global Catalog (TCP 3268, 3269)
- RPC/SMB (TCP 135, 445, 49152-65535)
- NTP (UDP 123)

### Web Server
- HTTP (TCP 80) - disabled by default
- HTTPS (TCP 443) - enabled
- Web Management (TCP 8172) - admin subnet only

### File Server
- SMB (TCP 445)
- DFS (TCP 135, 5722)

See [FIREWALL_DEPLOYMENT_GUIDE.md](FIREWALL_DEPLOYMENT_GUIDE.md#rule-templates-by-server-role) for complete port reference.

## Requirements

- PowerShell 5.1+
- Windows Server 2022 (compatible with 2019/2016)
- Administrator privileges
- Domain environment (recommended for GPO deployment)

## Best Practices

1. **Always Test First** - Deploy to lab/pilot before production
2. **Backup Before Changes** - Use Export-FirewallRules.ps1
3. **Use GPO for Scale** - Import rules into GPO for centralized management
4. **Monitor Logs** - Review firewall logs regularly for blocked connections
5. **Least Privilege** - Restrict RDP/WinRM to admin subnet only
6. **Document Custom Rules** - Use Groups and Descriptions
7. **Regular Audits** - Run Get-FirewallAuditBaseline.ps1 monthly
8. **Disable HTTP** - Use HTTPS only for web servers
9. **Restrict Dynamic RPC** - Configure fixed RPC port range where possible
10. **Update Templates** - Review and update rule templates annually

## Troubleshooting

### Rules Not Applying
```powershell
# Check GPO status
gpupdate /force
gpresult /r

# Verify firewall service
Get-Service mpssvc
```

### Service Unreachable
```powershell
# Check firewall logs for blocks
Get-Content "$env:SystemRoot\System32\logfiles\firewall\pfirewall-domain.log" | Select-String "DROP"

# Test specific port
Test-NetConnection -ComputerName SERVER -Port 445
```

### Restore from Backup
```powershell
# Restore from WFW export
netsh advfirewall import "C:\Backup\FirewallConfig.wfw"

# Or use Import-FirewallRules.ps1
.\Import-FirewallRules.ps1 -ImportPath C:\Backup\FirewallRules.json -Mode Replace
```

See [FIREWALL_DEPLOYMENT_GUIDE.md](FIREWALL_DEPLOYMENT_GUIDE.md#troubleshooting) for detailed troubleshooting guide.

## Additional Resources

- [CIS Benchmark - Windows Server 2022](https://www.cisecurity.org/benchmark/microsoft_windows_server)
- [Microsoft Docs - Windows Defender Firewall](https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-firewall/)
- [NIST SP 800-41 Rev 1 - Firewall Guidelines](https://csrc.nist.gov/publications/detail/sp/800-41/rev-1/final)

## License

Enterprise use only. Review your organization's policies before deployment.
