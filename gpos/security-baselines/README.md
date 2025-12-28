# CIS Windows Server 2022 Security Baseline GPO Templates

This directory contains importable Group Policy Object (GPO) templates for deploying CIS Benchmark compliance across Windows Server 2022 infrastructure.

## Quick Start

```powershell
# Import a GPO template
.\scripts\Import-SecurityBaselineGPO.ps1 -TemplatePath ".\security-baselines\CIS-Level1-DomainController" -GPOName "CIS-DC-Baseline"

# Export current GPOs for backup
.\scripts\Export-AllGPOs.ps1 -BackupPath "C:\Backup\GPO"
```

## Available Templates

### CIS Level 1 Templates

| Template | Target | CIS Controls | Description |
|----------|--------|--------------|-------------|
| `CIS-Level1-DomainController/` | Domain Controllers | 9.1.x, 9.2.x, 9.3.x + DC-specific | Complete CIS Level 1 baseline for DCs |
| `CIS-Level1-MemberServer/` | Member Servers | 9.1.x, 9.2.x, 9.3.x + hardening | CIS Level 1 for general member servers |

### Functional Templates

| Template | Purpose | Key Settings |
|----------|---------|--------------|
| `WSUS-Configuration/` | Patch Management | WSUS server configuration, auto-update policies |
| `Windows-Firewall-Profiles/` | Firewall Hardening | Domain/Private/Public profile settings per CIS |

## Template Structure

Each GPO template follows the standard Windows GPO backup format:

```
TemplateName/
├── {BACKUP-GUID}/
│   ├── bkupInfo.xml                    # Backup metadata
│   ├── Backup.xml                       # GPO core settings
│   ├── gpreport.xml                     # Human-readable report
│   └── DomainSysvol/
│       └── GPO/
│           ├── Machine/
│           │   ├── registry.pol                           # Machine policies
│           │   ├── comment.cmtx                          # Comments
│           │   └── microsoft/
│           │       └── windows nt/
│           │           ├── SecEdit/
│           │           │   └── GptTmpl.inf              # Security template
│           │           └── Audit/
│           │               └── audit.csv                 # Advanced audit
│           └── User/
│               └── registry.pol                          # User policies
└── manifest.xml                         # Backup catalog
```

## Import Instructions

### Method 1: PowerShell (Recommended)

```powershell
# Verify RSAT-GPMC is installed
Get-WindowsFeature RSAT-GPMC

# Import GPO template
Import-GPO -BackupGpoName "CIS Level 1 - Domain Controller" `
    -TargetName "CIS-DC-Baseline" `
    -Path "C:\GPO-Templates\CIS-Level1-DomainController" `
    -CreateIfNeeded

# Link to appropriate OU
New-GPLink -Name "CIS-DC-Baseline" -Target "OU=Domain Controllers,DC=contoso,DC=com"
```

### Method 2: Group Policy Management Console (GUI)

1. Open **Group Policy Management** (gpmc.msc)
2. Right-click **Group Policy Objects** → **New**
3. Name the GPO (e.g., "CIS-DC-Baseline")
4. Right-click the new GPO → **Import Settings**
5. Browse to the template folder
6. Select the backup instance (GUID folder)
7. Complete the import wizard
8. Link to appropriate OU

### Method 3: LGPO.exe (Local Policy)

```cmd
REM Download LGPO.exe from Microsoft Security Compliance Toolkit
REM Apply GPO backup to local machine

LGPO.exe /g ".\CIS-Level1-MemberServer\{GUID}"
```

## Pre-Deployment Checklist

- [ ] **Test in Lab Environment** - Never deploy directly to production
- [ ] **Review Settings** - Ensure compatibility with your environment
- [ ] **Backup Current GPOs** - Run `Export-AllGPOs.ps1` first
- [ ] **Update Variables** - Modify template paths (admin subnet, WSUS server, etc.)
- [ ] **Check WMI Filters** - Not included in templates, create separately
- [ ] **Verify Permissions** - Ensure proper security filtering
- [ ] **Plan Rollback** - Document procedure to revert if needed
- [ ] **Communicate Changes** - Notify stakeholders of policy deployment

## Customization Guide

### Updating Admin Subnet in Templates

Many templates restrict RDP/WinRM to an admin subnet (default: `10.0.1.0/24`). Update before importing:

**Option 1: Find and Replace in registry.pol**
```powershell
# Not recommended - binary file format
```

**Option 2: Import then modify via GUI**
1. Import the template
2. Edit the GPO
3. Navigate to: Computer Configuration → Windows Settings → Security Settings → Windows Defender Firewall with Advanced Security → Inbound Rules
4. Modify Remote Desktop rule → Scope → Remote IP addresses
5. Change from `10.0.1.0/24` to your admin subnet

**Option 3: Use Import Script Parameters**
```powershell
.\Import-SecurityBaselineGPO.ps1 -TemplatePath ".\CIS-Level1-MemberServer" `
    -GPOName "CIS-Baseline" `
    -AdminSubnet "192.168.100.0/24"  # Automatically updates firewall rules
```

### Updating WSUS Server Configuration

```powershell
# After importing WSUS-Configuration template, update registry policies:
Set-GPRegistryValue -Name "WSUS-Configuration" `
    -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "WUServer" `
    -Type String `
    -Value "http://wsus.yourdomain.local:8530"

Set-GPRegistryValue -Name "WSUS-Configuration" `
    -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "WUStatusServer" `
    -Type String `
    -Value "http://wsus.yourdomain.local:8530"
```

## CIS Benchmark Mapping

### CIS Controls Implemented

| Section | Description | Template Coverage |
|---------|-------------|-------------------|
| 9.1.x | Windows Defender Firewall - Domain Profile | ✅ Windows-Firewall-Profiles |
| 9.2.x | Windows Defender Firewall - Private Profile | ✅ Windows-Firewall-Profiles |
| 9.3.x | Windows Defender Firewall - Public Profile | ✅ Windows-Firewall-Profiles |
| 18.x | Administrative Templates | ✅ CIS-Level1-* templates |
| 2.2.x | User Rights Assignment | ✅ GptTmpl.inf in all templates |
| 2.3.x | Security Options | ✅ GptTmpl.inf in all templates |
| 17.x | Advanced Audit Policy | ✅ audit.csv in all templates |

## Validation and Compliance Checking

After deploying templates, validate compliance:

```powershell
# Force GPO update
gpupdate /force

# Verify GPO application
gpresult /r
gpresult /h GPReport.html

# Check firewall settings
Get-NetFirewallProfile -PolicyStore ActiveStore | Format-Table Name, Enabled, DefaultInboundAction, DefaultOutboundAction

# Check audit policies
auditpol /get /category:*

# Run CIS compliance check
# Use CIS-CAT or custom audit script
.\audits\scripts\Invoke-CISAudit.ps1
```

## Troubleshooting

### GPO Not Applying

```powershell
# Check GPO replication
Get-GPO -Name "CIS-DC-Baseline" | Select-Object DisplayName, DomainName, ModificationTime

# Check DC replication
repadmin /showrepl

# Check event logs
Get-WinEvent -LogName "Microsoft-Windows-GroupPolicy/Operational" -MaxEvents 50

# Force replication
repadmin /syncall /AdeP
```

### Security Filtering Issues

```powershell
# Check GPO permissions
Get-GPPermission -Name "CIS-DC-Baseline" -All

# Grant "Domain Controllers" read/apply permissions
Set-GPPermission -Name "CIS-DC-Baseline" `
    -TargetName "Domain Controllers" `
    -TargetType Group `
    -PermissionLevel GpoApply
```

### Settings Not Taking Effect

- Check **GPO precedence** (last applied wins)
- Verify **WMI filter** isn't blocking application
- Check **security filtering** includes target computers
- Ensure **OU linking** is correct and enabled
- Review **enforced** and **block inheritance** settings

## Best Practices

1. **Never Modify Default Domain Policy** - Use custom GPOs
2. **Use Descriptive Names** - Include version and date (e.g., "CIS-DC-v1.0-2025")
3. **Document Changes** - Use GPO comments and separate documentation
4. **Test Before Production** - Always test in isolated environment
5. **Monitor Application** - Use event logs and reporting
6. **Version Control** - Export GPOs regularly for change tracking
7. **Least Privilege** - Apply only necessary settings to each OU
8. **Layered Approach** - Use multiple GPOs instead of monolithic policies
9. **Security Filtering** - Limit scope to appropriate security groups
10. **Regular Audits** - Quarterly compliance validation

## Migration Checklist

Migrating templates to a new domain:

- [ ] Update domain references in migration table
- [ ] Create migration table XML file
- [ ] Update security principal mappings
- [ ] Verify domain SID differences
- [ ] Test import with migration table
- [ ] Validate all settings post-import
- [ ] Update links to new OUs

```powershell
# Create migration table
$migrationTable = New-GPOMigrationTable -BackupPath ".\CIS-Level1-DomainController"

# Import with migration
Import-GPO -BackupGpoName "CIS Level 1 - Domain Controller" `
    -TargetName "CIS-DC-Baseline" `
    -Path ".\CIS-Level1-DomainController" `
    -MigrationTable $migrationTable `
    -CreateIfNeeded
```

## Additional Resources

- [CIS Benchmark - Windows Server 2022](https://www.cisecurity.org/benchmark/microsoft_windows_server)
- [Microsoft Security Compliance Toolkit](https://www.microsoft.com/en-us/download/details.aspx?id=55319)
- [Group Policy Management Documentation](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/hh831791(v=ws.11))
- [LGPO.exe Documentation](https://techcommunity.microsoft.com/blog/microsoft-security-baselines/lgpo-exe---local-group-policy-object-utility-v1-0/701045)

## License

Enterprise use only. Review your organization's policies before deployment.
