# Windows Defender Firewall Deployment Guide

**Target Environment:** Windows Server 2022, CIS Benchmark Compliant
**Last Updated:** 2025-12-26
**Compatibility:** PowerShell 5.1+

---

## Table of Contents

1. [Overview](#overview)
2. [CIS Benchmark Requirements](#cis-benchmark-requirements)
3. [Firewall Profiles Explained](#firewall-profiles-explained)
4. [Baseline Configuration Strategy](#baseline-configuration-strategy)
5. [Rule Templates by Server Role](#rule-templates-by-server-role)
6. [Deployment Methods](#deployment-methods)
7. [PowerShell Automation](#powershell-automation)
8. [Testing and Validation](#testing-and-validation)
9. [Troubleshooting](#troubleshooting)

---

## Overview

This guide provides a complete framework for deploying CIS-compliant Windows Defender Firewall configurations across an enterprise environment using Group Policy and PowerShell automation.

### Design Principles

1. **Default Deny** - Block all inbound traffic by default
2. **Explicit Allow** - Only allow required services
3. **Least Privilege** - Minimal rule scope (specific IPs/ports)
4. **Role-Based** - Different rules per server role
5. **Centrally Managed** - Deploy via GPO, not local configuration
6. **Auditable** - All changes logged and documented

### CIS Benchmark Alignment

This guide implements the following CIS Benchmark controls:

- **9.1.1** - Ensure Windows Firewall is enabled (Domain, Private, Public)
- **9.1.2** - Ensure inbound connections are blocked by default
- **9.1.3** - Ensure outbound connections are allowed by default
- **9.1.4** - Ensure firewall logging is configured
- **9.2.x** - Profile-specific settings (Domain, Private, Public)
- **9.3.x** - Advanced firewall rules and IPsec settings

---

## CIS Benchmark Requirements

### Level 1 Requirements (All Profiles)

| Setting | Domain | Private | Public | CIS Control |
|---------|--------|---------|--------|-------------|
| Firewall State | ON | ON | ON | 9.1.1, 9.2.1, 9.3.1 |
| Inbound Default | BLOCK | BLOCK | BLOCK | 9.1.2, 9.2.2, 9.3.2 |
| Outbound Default | ALLOW | ALLOW | ALLOW | 9.1.3, 9.2.3, 9.3.3 |
| Local Rules | BLOCK | BLOCK | BLOCK | 9.2.4, 9.3.4 |
| Local IPsec Rules | BLOCK | BLOCK | BLOCK | 9.2.5, 9.3.5 |
| Logging Dropped | YES | YES | YES | 9.2.6, 9.3.6 |
| Logging Allowed | YES | YES | YES | 9.2.7, 9.3.7 |
| Log File Size | 16384 KB | 16384 KB | 16384 KB | 9.2.8, 9.3.8 |
| Log File Path | %SystemRoot%\System32\logfiles\firewall\pfirewall.log | | | 9.1.4 |

### Level 2 Additional Requirements

- **IPsec Configuration** - Require encryption for sensitive traffic
- **Connection Security Rules** - Domain isolation where applicable
- **Advanced Logging** - Extended logging for security monitoring
- **Notification Settings** - Suppress user notifications (servers)

---

## Firewall Profiles Explained

### Domain Profile
- **When Active:** Computer is connected to a domain controller
- **Typical Use:** Corporate network, domain-joined servers
- **Security Level:** Medium (trusted network)
- **Rule Philosophy:** Allow necessary domain services, block everything else

### Private Profile
- **When Active:** User designates network as "Private"
- **Typical Use:** Workgroup servers, standalone systems
- **Security Level:** Medium-High
- **Rule Philosophy:** More restrictive than Domain, similar baseline

### Public Profile
- **When Active:** Unknown/untrusted networks
- **Typical Use:** Servers in DMZ, internet-facing systems
- **Security Level:** Highest
- **Rule Philosophy:** Maximum restriction, minimal allowed services

---

## Baseline Configuration Strategy

### Phase 1: Global Baseline (All Servers)

**Applies to:** Every server regardless of role

#### Required Inbound Rules:
1. **Core Networking** (ICMP, ICMPv6)
   - Echo Request (Ping) - Domain/Private only
   - Destination Unreachable
   - Packet Too Big
   - Time Exceeded

2. **Remote Management**
   - Windows Remote Management (WinRM) - TCP 5985, 5986
   - Remote Desktop (RDP) - TCP 3389 (from admin subnets only)
   - Server Manager Remote Management - TCP 445

3. **Monitoring and Backup**
   - SNMP (if required) - UDP 161
   - Backup agents (vendor-specific ports)

4. **Active Directory (Domain-joined servers)**
   - Kerberos - TCP/UDP 88
   - DNS - TCP/UDP 53
   - LDAP - TCP/UDP 389, TCP 636 (LDAPS)
   - SMB - TCP 445
   - RPC - TCP 135, Dynamic RPC

#### Required Outbound Rules:
- Allow all by default (CIS recommendation)
- Optional: Explicit allow for known services, block all else (high security)

### Phase 2: Role-Specific Rules

Additional rules based on server function:

- **Domain Controllers** - AD replication, DNS, Kerberos, LDAP, SYSVOL
- **File Servers** - SMB, DFS, BranchCache
- **Web Servers** - HTTP, HTTPS, FTP (if needed)
- **Database Servers** - SQL Server, MySQL, PostgreSQL
- **Certificate Authority** - HTTP/HTTPS (CRL/OCSP), RPC
- **WSUS Servers** - HTTP/HTTPS for client connections

### Phase 3: Profile-Specific Hardening

Different default actions per profile:

| Profile | Inbound | Outbound | Local Rules | Notifications |
|---------|---------|----------|-------------|---------------|
| Domain | Block (explicit allow) | Allow | Merge | No |
| Private | Block (explicit allow) | Allow | Block | No |
| Public | Block (explicit allow) | Block | Block | No |

---

## Rule Templates by Server Role

### 1. Domain Controller Firewall Rules

```powershell
# CIS-FW-DC-001: Active Directory Replication
New-NetFirewallRule -DisplayName "AD-DS Replication (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 135,464,3268,3269,49152-65535 `
    -Action Allow -Profile Domain -Group "Active Directory Domain Services"

# CIS-FW-DC-002: DNS Service
New-NetFirewallRule -DisplayName "DNS (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 53 `
    -Action Allow -Profile Domain,Private -Group "Active Directory Domain Services"

New-NetFirewallRule -DisplayName "DNS (UDP-In)" `
    -Direction Inbound -Protocol UDP -LocalPort 53 `
    -Action Allow -Profile Domain,Private -Group "Active Directory Domain Services"

# CIS-FW-DC-003: LDAP/LDAPS
New-NetFirewallRule -DisplayName "LDAP (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 389 `
    -Action Allow -Profile Domain -Group "Active Directory Domain Services"

New-NetFirewallRule -DisplayName "LDAPS (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 636 `
    -Action Allow -Profile Domain -Group "Active Directory Domain Services"

New-NetFirewallRule -DisplayName "LDAP (UDP-In)" `
    -Direction Inbound -Protocol UDP -LocalPort 389 `
    -Action Allow -Profile Domain -Group "Active Directory Domain Services"

# CIS-FW-DC-004: Kerberos
New-NetFirewallRule -DisplayName "Kerberos (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 88 `
    -Action Allow -Profile Domain -Group "Active Directory Domain Services"

New-NetFirewallRule -DisplayName "Kerberos (UDP-In)" `
    -Direction Inbound -Protocol UDP -LocalPort 88 `
    -Action Allow -Profile Domain -Group "Active Directory Domain Services"

# CIS-FW-DC-005: SYSVOL/NETLOGON
New-NetFirewallRule -DisplayName "SMB (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 445 `
    -Action Allow -Profile Domain -Group "Active Directory Domain Services"

# CIS-FW-DC-006: Global Catalog
New-NetFirewallRule -DisplayName "Global Catalog (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 3268,3269 `
    -Action Allow -Profile Domain -Group "Active Directory Domain Services"

# CIS-FW-DC-007: RPC Endpoint Mapper
New-NetFirewallRule -DisplayName "RPC Endpoint Mapper (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 135 `
    -Action Allow -Profile Domain -Group "Active Directory Domain Services"

# CIS-FW-DC-008: Dynamic RPC
New-NetFirewallRule -DisplayName "AD Dynamic RPC (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 49152-65535 `
    -Action Allow -Profile Domain -Group "Active Directory Domain Services" `
    -Description "Dynamic RPC for AD replication"

# CIS-FW-DC-009: NetBIOS Name Service (if required)
New-NetFirewallRule -DisplayName "NetBIOS Name Service (UDP-In)" `
    -Direction Inbound -Protocol UDP -LocalPort 137 `
    -Action Allow -Profile Domain -Group "Active Directory Domain Services" `
    -Enabled False -Description "Enable only if NetBIOS required"

# CIS-FW-DC-010: W32Time
New-NetFirewallRule -DisplayName "NTP (UDP-In)" `
    -Direction Inbound -Protocol UDP -LocalPort 123 `
    -Action Allow -Profile Domain -Group "Active Directory Domain Services"
```

### 2. File Server Firewall Rules

```powershell
# CIS-FW-FS-001: SMB File Sharing
New-NetFirewallRule -DisplayName "File and Printer Sharing (SMB-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 445 `
    -Action Allow -Profile Domain -Group "File and Printer Sharing"

# CIS-FW-FS-002: DFS Namespace
New-NetFirewallRule -DisplayName "DFS Management (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 135 `
    -Action Allow -Profile Domain -Group "DFS Management"

# CIS-FW-FS-003: DFS Replication
New-NetFirewallRule -DisplayName "DFS Replication (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 5722 `
    -Action Allow -Profile Domain -Group "DFS Management"

# CIS-FW-FS-004: BranchCache (if used)
New-NetFirewallRule -DisplayName "BranchCache Content Retrieval (HTTP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 80 `
    -Action Allow -Profile Domain -Group "BranchCache" `
    -Enabled False -Description "Enable if BranchCache is deployed"

# CIS-FW-FS-005: BranchCache Discovery
New-NetFirewallRule -DisplayName "BranchCache Peer Discovery (WSD-In)" `
    -Direction Inbound -Protocol UDP -LocalPort 3702 `
    -Action Allow -Profile Domain -Group "BranchCache" `
    -Enabled False
```

### 3. Web Server Firewall Rules

```powershell
# CIS-FW-WEB-001: HTTP
New-NetFirewallRule -DisplayName "HTTP (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 80 `
    -Action Allow -Profile Domain,Private,Public -Group "Web Server"

# CIS-FW-WEB-002: HTTPS
New-NetFirewallRule -DisplayName "HTTPS (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 443 `
    -Action Allow -Profile Domain,Private,Public -Group "Web Server"

# CIS-FW-WEB-003: FTP (if required)
New-NetFirewallRule -DisplayName "FTP (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 21 `
    -Action Allow -Profile Domain -Group "FTP Server" `
    -Enabled False -Description "Enable only if FTP required"

# CIS-FW-WEB-004: FTP Passive Mode
New-NetFirewallRule -DisplayName "FTP Passive (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 1024-65535 `
    -Action Allow -Profile Domain -Group "FTP Server" `
    -Enabled False
```

### 4. SQL Server Firewall Rules

```powershell
# CIS-FW-SQL-001: SQL Server Default Instance
New-NetFirewallRule -DisplayName "SQL Server (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 1433 `
    -Action Allow -Profile Domain -Group "SQL Server"

# CIS-FW-SQL-002: SQL Server Browser
New-NetFirewallRule -DisplayName "SQL Server Browser (UDP-In)" `
    -Direction Inbound -Protocol UDP -LocalPort 1434 `
    -Action Allow -Profile Domain -Group "SQL Server"

# CIS-FW-SQL-003: SQL Server Named Instance
New-NetFirewallRule -DisplayName "SQL Server Named Instance (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 1434 `
    -Action Allow -Profile Domain -Group "SQL Server" `
    -Enabled False -Description "Configure port for named instance"

# CIS-FW-SQL-004: SQL Server AlwaysOn
New-NetFirewallRule -DisplayName "SQL AlwaysOn Endpoint (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 5022 `
    -Action Allow -Profile Domain -Group "SQL Server" `
    -Enabled False
```

### 5. Certificate Authority Firewall Rules

```powershell
# CIS-FW-CA-001: HTTP (CRL/OCSP)
New-NetFirewallRule -DisplayName "CA HTTP (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 80 `
    -Action Allow -Profile Domain -Group "Certificate Authority"

# CIS-FW-CA-002: HTTPS (Web Enrollment)
New-NetFirewallRule -DisplayName "CA HTTPS (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 443 `
    -Action Allow -Profile Domain -Group "Certificate Authority"

# CIS-FW-CA-003: RPC/DCOM
New-NetFirewallRule -DisplayName "CA RPC (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 135 `
    -Action Allow -Profile Domain -Group "Certificate Authority"
```

### 6. WSUS Server Firewall Rules

```powershell
# CIS-FW-WSUS-001: HTTP (Client Connections)
New-NetFirewallRule -DisplayName "WSUS HTTP (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 8530 `
    -Action Allow -Profile Domain -Group "WSUS Server"

# CIS-FW-WSUS-002: HTTPS (Client Connections)
New-NetFirewallRule -DisplayName "WSUS HTTPS (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 8531 `
    -Action Allow -Profile Domain -Group "WSUS Server"
```

### 7. Core Management Rules (All Servers)

```powershell
# CIS-FW-CORE-001: RDP from Admin Subnet
New-NetFirewallRule -DisplayName "Remote Desktop (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 3389 `
    -RemoteAddress 10.0.1.0/24 `
    -Action Allow -Profile Domain -Group "Remote Management" `
    -Description "Allow RDP from admin subnet only"

# CIS-FW-CORE-002: WinRM (PowerShell Remoting)
New-NetFirewallRule -DisplayName "WinRM HTTP (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 5985 `
    -Action Allow -Profile Domain -Group "Remote Management"

New-NetFirewallRule -DisplayName "WinRM HTTPS (TCP-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 5986 `
    -Action Allow -Profile Domain -Group "Remote Management"

# CIS-FW-CORE-003: ICMP (Ping) - Domain/Private Only
New-NetFirewallRule -DisplayName "ICMPv4 Echo Request (Ping-In)" `
    -Direction Inbound -Protocol ICMPv4 -IcmpType 8 `
    -Action Allow -Profile Domain,Private -Group "Core Networking"

New-NetFirewallRule -DisplayName "ICMPv6 Echo Request (Ping-In)" `
    -Direction Inbound -Protocol ICMPv6 -IcmpType 128 `
    -Action Allow -Profile Domain,Private -Group "Core Networking"

# CIS-FW-CORE-004: SNMP (if monitoring required)
New-NetFirewallRule -DisplayName "SNMP (UDP-In)" `
    -Direction Inbound -Protocol UDP -LocalPort 161 `
    -RemoteAddress 10.0.1.0/24 `
    -Action Allow -Profile Domain -Group "Monitoring" `
    -Enabled False -Description "Enable if SNMP monitoring is used"
```

---

## Deployment Methods

### Method 1: Group Policy (Recommended)

**Advantages:**
- Centrally managed
- Automatically applied to OUs
- Easy rollback
- Auditable changes

**Process:**
1. Create GPO in appropriate OU
2. Navigate to: Computer Configuration → Policies → Windows Settings → Security Settings → Windows Defender Firewall with Advanced Security
3. Configure profile settings
4. Create inbound/outbound rules
5. Link GPO to target OU

### Method 2: PowerShell Script (Bulk Deployment)

**Advantages:**
- Scriptable and repeatable
- Can be version controlled
- Fast deployment to multiple servers
- Can include validation

**Process:**
1. Create PowerShell script with rules
2. Test on pilot server
3. Deploy via GPO startup script or remote execution
4. Validate with audit script

### Method 3: Import/Export (Clone Configuration)

**Advantages:**
- Quick replication of working config
- Good for similar server roles
- Preserves exact settings

**Process:**
1. Export working firewall config
2. Import to target servers
3. Adjust for server-specific needs

---

## PowerShell Automation

### Complete Deployment Script (All-in-One)

```powershell
<#
.SYNOPSIS
    Deploy CIS-compliant Windows Defender Firewall configuration.

.DESCRIPTION
    Configures Windows Defender Firewall with CIS Benchmark Level 1 & 2 settings.
    Creates role-specific firewall rules based on server function.

.PARAMETER ServerRole
    The role of this server (DomainController, FileServer, WebServer, SQLServer, CA, WSUS, Generic)

.PARAMETER AdminSubnet
    The subnet for administrative access (RDP, WinRM). Default: 10.0.1.0/24

.PARAMETER LogPath
    Path for firewall logs. Default: %SystemRoot%\System32\logfiles\firewall\

.PARAMETER LogMaxSize
    Maximum log file size in KB. Default: 16384 (16 MB)

.PARAMETER ApplyOnly
    Switch to apply settings without validation

.EXAMPLE
    .\Set-CISFirewallBaseline.ps1 -ServerRole DomainController -AdminSubnet 192.168.1.0/24

.NOTES
    Author: Enterprise Security Team
    Version: 1.0
    Requires: PowerShell 5.1+, Run as Administrator
    CIS Benchmark: Windows Server 2022 v2.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("DomainController","FileServer","WebServer","SQLServer","CA","WSUS","Generic")]
    [string]$ServerRole,

    [Parameter(Mandatory=$false)]
    [string]$AdminSubnet = "10.0.1.0/24",

    [Parameter(Mandatory=$false)]
    [string]$LogPath = "$env:SystemRoot\System32\logfiles\firewall",

    [Parameter(Mandatory=$false)]
    [int]$LogMaxSize = 16384,

    [Parameter(Mandatory=$false)]
    [switch]$ApplyOnly
)

#Requires -Version 5.1
#Requires -RunAsAdministrator

# Configure error handling
$ErrorActionPreference = "Stop"
$WarningPreference = "Continue"

# Start transcript
$TranscriptPath = "$env:TEMP\Firewall-Deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Start-Transcript -Path $TranscriptPath

try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  CIS Firewall Baseline Deployment" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "Server Role: $ServerRole" -ForegroundColor Green
    Write-Host "Admin Subnet: $AdminSubnet" -ForegroundColor Green
    Write-Host "Log Path: $LogPath`n" -ForegroundColor Green

    # Step 1: Configure Firewall Profiles (CIS 9.1.x, 9.2.x, 9.3.x)
    Write-Host "[1/5] Configuring Firewall Profiles..." -ForegroundColor Yellow

    # Ensure log directory exists
    if (-not (Test-Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    }

    # Domain Profile
    Set-NetFirewallProfile -Profile Domain -Enabled True `
        -DefaultInboundAction Block `
        -DefaultOutboundAction Allow `
        -AllowInboundRules False `
        -AllowLocalFirewallRules False `
        -AllowLocalIPsecRules False `
        -NotifyOnListen False `
        -LogFileName "$LogPath\pfirewall-domain.log" `
        -LogMaxSizeKilobytes $LogMaxSize `
        -LogAllowed True `
        -LogBlocked True

    # Private Profile
    Set-NetFirewallProfile -Profile Private -Enabled True `
        -DefaultInboundAction Block `
        -DefaultOutboundAction Allow `
        -AllowInboundRules False `
        -AllowLocalFirewallRules False `
        -AllowLocalIPsecRules False `
        -NotifyOnListen False `
        -LogFileName "$LogPath\pfirewall-private.log" `
        -LogMaxSizeKilobytes $LogMaxSize `
        -LogAllowed True `
        -LogBlocked True

    # Public Profile (most restrictive)
    Set-NetFirewallProfile -Profile Public -Enabled True `
        -DefaultInboundAction Block `
        -DefaultOutboundAction Block `
        -AllowInboundRules False `
        -AllowLocalFirewallRules False `
        -AllowLocalIPsecRules False `
        -NotifyOnListen False `
        -LogFileName "$LogPath\pfirewall-public.log" `
        -LogMaxSizeKilobytes $LogMaxSize `
        -LogAllowed True `
        -LogBlocked True

    Write-Host "  ✓ Firewall profiles configured (CIS 9.1.x, 9.2.x, 9.3.x)" -ForegroundColor Green

    # Step 2: Remove Default Rules
    Write-Host "`n[2/5] Removing default firewall rules..." -ForegroundColor Yellow

    $DefaultRules = Get-NetFirewallRule | Where-Object {
        $_.DisplayName -notlike "*Core Networking*" -and
        $_.Group -ne "Remote Management"
    }

    Write-Host "  Found $($DefaultRules.Count) non-essential rules to remove" -ForegroundColor Gray

    if (-not $ApplyOnly) {
        $Confirmation = Read-Host "  Remove default rules? (Y/N)"
        if ($Confirmation -ne 'Y') {
            Write-Host "  Skipping rule removal" -ForegroundColor Yellow
        } else {
            $DefaultRules | Remove-NetFirewallRule -ErrorAction SilentlyContinue
            Write-Host "  ✓ Default rules removed" -ForegroundColor Green
        }
    } else {
        $DefaultRules | Remove-NetFirewallRule -ErrorAction SilentlyContinue
        Write-Host "  ✓ Default rules removed" -ForegroundColor Green
    }

    # Step 3: Create Core Management Rules
    Write-Host "`n[3/5] Creating core management rules..." -ForegroundColor Yellow

    # RDP from Admin Subnet
    New-NetFirewallRule -DisplayName "CIS-FW-CORE-001: Remote Desktop (Admin Subnet)" `
        -Direction Inbound -Protocol TCP -LocalPort 3389 `
        -RemoteAddress $AdminSubnet `
        -Action Allow -Profile Domain -Group "Remote Management" `
        -Description "Allow RDP from admin subnet only" -ErrorAction SilentlyContinue

    # WinRM
    New-NetFirewallRule -DisplayName "CIS-FW-CORE-002: WinRM HTTP" `
        -Direction Inbound -Protocol TCP -LocalPort 5985 `
        -Action Allow -Profile Domain -Group "Remote Management" `
        -ErrorAction SilentlyContinue

    New-NetFirewallRule -DisplayName "CIS-FW-CORE-003: WinRM HTTPS" `
        -Direction Inbound -Protocol TCP -LocalPort 5986 `
        -Action Allow -Profile Domain -Group "Remote Management" `
        -ErrorAction SilentlyContinue

    # ICMP (Ping)
    New-NetFirewallRule -DisplayName "CIS-FW-CORE-004: ICMPv4 Echo Request" `
        -Direction Inbound -Protocol ICMPv4 -IcmpType 8 `
        -Action Allow -Profile Domain,Private -Group "Core Networking" `
        -ErrorAction SilentlyContinue

    New-NetFirewallRule -DisplayName "CIS-FW-CORE-005: ICMPv6 Echo Request" `
        -Direction Inbound -Protocol ICMPv6 -IcmpType 128 `
        -Action Allow -Profile Domain,Private -Group "Core Networking" `
        -ErrorAction SilentlyContinue

    # Server Manager
    New-NetFirewallRule -DisplayName "CIS-FW-CORE-006: Server Manager Remote" `
        -Direction Inbound -Protocol TCP -LocalPort 445 `
        -RemoteAddress $AdminSubnet `
        -Action Allow -Profile Domain -Group "Remote Management" `
        -ErrorAction SilentlyContinue

    Write-Host "  ✓ Core management rules created" -ForegroundColor Green

    # Step 4: Create Role-Specific Rules
    Write-Host "`n[4/5] Creating $ServerRole specific rules..." -ForegroundColor Yellow

    switch ($ServerRole) {
        "DomainController" {
            # DNS
            New-NetFirewallRule -DisplayName "CIS-FW-DC-001: DNS TCP" `
                -Direction Inbound -Protocol TCP -LocalPort 53 `
                -Action Allow -Profile Domain,Private -Group "Active Directory Domain Services" -ErrorAction SilentlyContinue

            New-NetFirewallRule -DisplayName "CIS-FW-DC-002: DNS UDP" `
                -Direction Inbound -Protocol UDP -LocalPort 53 `
                -Action Allow -Profile Domain,Private -Group "Active Directory Domain Services" -ErrorAction SilentlyContinue

            # Kerberos
            New-NetFirewallRule -DisplayName "CIS-FW-DC-003: Kerberos TCP" `
                -Direction Inbound -Protocol TCP -LocalPort 88 `
                -Action Allow -Profile Domain -Group "Active Directory Domain Services" -ErrorAction SilentlyContinue

            New-NetFirewallRule -DisplayName "CIS-FW-DC-004: Kerberos UDP" `
                -Direction Inbound -Protocol UDP -LocalPort 88 `
                -Action Allow -Profile Domain -Group "Active Directory Domain Services" -ErrorAction SilentlyContinue

            # LDAP/LDAPS
            New-NetFirewallRule -DisplayName "CIS-FW-DC-005: LDAP TCP" `
                -Direction Inbound -Protocol TCP -LocalPort 389 `
                -Action Allow -Profile Domain -Group "Active Directory Domain Services" -ErrorAction SilentlyContinue

            New-NetFirewallRule -DisplayName "CIS-FW-DC-006: LDAPS TCP" `
                -Direction Inbound -Protocol TCP -LocalPort 636 `
                -Action Allow -Profile Domain -Group "Active Directory Domain Services" -ErrorAction SilentlyContinue

            New-NetFirewallRule -DisplayName "CIS-FW-DC-007: LDAP UDP" `
                -Direction Inbound -Protocol UDP -LocalPort 389 `
                -Action Allow -Profile Domain -Group "Active Directory Domain Services" -ErrorAction SilentlyContinue

            # Global Catalog
            New-NetFirewallRule -DisplayName "CIS-FW-DC-008: Global Catalog" `
                -Direction Inbound -Protocol TCP -LocalPort 3268,3269 `
                -Action Allow -Profile Domain -Group "Active Directory Domain Services" -ErrorAction SilentlyContinue

            # SMB
            New-NetFirewallRule -DisplayName "CIS-FW-DC-009: SMB" `
                -Direction Inbound -Protocol TCP -LocalPort 445 `
                -Action Allow -Profile Domain -Group "Active Directory Domain Services" -ErrorAction SilentlyContinue

            # RPC
            New-NetFirewallRule -DisplayName "CIS-FW-DC-010: RPC Endpoint Mapper" `
                -Direction Inbound -Protocol TCP -LocalPort 135 `
                -Action Allow -Profile Domain -Group "Active Directory Domain Services" -ErrorAction SilentlyContinue

            New-NetFirewallRule -DisplayName "CIS-FW-DC-011: Dynamic RPC" `
                -Direction Inbound -Protocol TCP -LocalPort 49152-65535 `
                -Action Allow -Profile Domain -Group "Active Directory Domain Services" -ErrorAction SilentlyContinue

            # NTP
            New-NetFirewallRule -DisplayName "CIS-FW-DC-012: NTP" `
                -Direction Inbound -Protocol UDP -LocalPort 123 `
                -Action Allow -Profile Domain -Group "Active Directory Domain Services" -ErrorAction SilentlyContinue

            Write-Host "  ✓ Domain Controller rules created (12 rules)" -ForegroundColor Green
        }

        "FileServer" {
            New-NetFirewallRule -DisplayName "CIS-FW-FS-001: SMB" `
                -Direction Inbound -Protocol TCP -LocalPort 445 `
                -Action Allow -Profile Domain -Group "File and Printer Sharing" -ErrorAction SilentlyContinue

            New-NetFirewallRule -DisplayName "CIS-FW-FS-002: DFS Management" `
                -Direction Inbound -Protocol TCP -LocalPort 135 `
                -Action Allow -Profile Domain -Group "DFS Management" -ErrorAction SilentlyContinue

            New-NetFirewallRule -DisplayName "CIS-FW-FS-003: DFS Replication" `
                -Direction Inbound -Protocol TCP -LocalPort 5722 `
                -Action Allow -Profile Domain -Group "DFS Management" -ErrorAction SilentlyContinue

            Write-Host "  ✓ File Server rules created (3 rules)" -ForegroundColor Green
        }

        "WebServer" {
            New-NetFirewallRule -DisplayName "CIS-FW-WEB-001: HTTP" `
                -Direction Inbound -Protocol TCP -LocalPort 80 `
                -Action Allow -Profile Domain,Private,Public -Group "Web Server" -ErrorAction SilentlyContinue

            New-NetFirewallRule -DisplayName "CIS-FW-WEB-002: HTTPS" `
                -Direction Inbound -Protocol TCP -LocalPort 443 `
                -Action Allow -Profile Domain,Private,Public -Group "Web Server" -ErrorAction SilentlyContinue

            Write-Host "  ✓ Web Server rules created (2 rules)" -ForegroundColor Green
        }

        "SQLServer" {
            New-NetFirewallRule -DisplayName "CIS-FW-SQL-001: SQL Server" `
                -Direction Inbound -Protocol TCP -LocalPort 1433 `
                -Action Allow -Profile Domain -Group "SQL Server" -ErrorAction SilentlyContinue

            New-NetFirewallRule -DisplayName "CIS-FW-SQL-002: SQL Browser" `
                -Direction Inbound -Protocol UDP -LocalPort 1434 `
                -Action Allow -Profile Domain -Group "SQL Server" -ErrorAction SilentlyContinue

            Write-Host "  ✓ SQL Server rules created (2 rules)" -ForegroundColor Green
        }

        "CA" {
            New-NetFirewallRule -DisplayName "CIS-FW-CA-001: HTTP (CRL/OCSP)" `
                -Direction Inbound -Protocol TCP -LocalPort 80 `
                -Action Allow -Profile Domain -Group "Certificate Authority" -ErrorAction SilentlyContinue

            New-NetFirewallRule -DisplayName "CIS-FW-CA-002: HTTPS (Web Enrollment)" `
                -Direction Inbound -Protocol TCP -LocalPort 443 `
                -Action Allow -Profile Domain -Group "Certificate Authority" -ErrorAction SilentlyContinue

            New-NetFirewallRule -DisplayName "CIS-FW-CA-003: RPC" `
                -Direction Inbound -Protocol TCP -LocalPort 135 `
                -Action Allow -Profile Domain -Group "Certificate Authority" -ErrorAction SilentlyContinue

            Write-Host "  ✓ Certificate Authority rules created (3 rules)" -ForegroundColor Green
        }

        "WSUS" {
            New-NetFirewallRule -DisplayName "CIS-FW-WSUS-001: HTTP" `
                -Direction Inbound -Protocol TCP -LocalPort 8530 `
                -Action Allow -Profile Domain -Group "WSUS Server" -ErrorAction SilentlyContinue

            New-NetFirewallRule -DisplayName "CIS-FW-WSUS-002: HTTPS" `
                -Direction Inbound -Protocol TCP -LocalPort 8531 `
                -Action Allow -Profile Domain -Group "WSUS Server" -ErrorAction SilentlyContinue

            Write-Host "  ✓ WSUS Server rules created (2 rules)" -ForegroundColor Green
        }

        "Generic" {
            Write-Host "  ✓ Generic server - no additional rules" -ForegroundColor Green
        }
    }

    # Step 5: Validation
    Write-Host "`n[5/5] Validating configuration..." -ForegroundColor Yellow

    $DomainProfile = Get-NetFirewallProfile -Profile Domain
    $PrivateProfile = Get-NetFirewallProfile -Profile Private
    $PublicProfile = Get-NetFirewallProfile -Profile Public

    $ValidationResults = @()

    # Check firewall enabled
    $ValidationResults += [PSCustomObject]@{
        Check = "Domain Profile Enabled"
        Status = if ($DomainProfile.Enabled) { "PASS" } else { "FAIL" }
        Value = $DomainProfile.Enabled
    }

    $ValidationResults += [PSCustomObject]@{
        Check = "Private Profile Enabled"
        Status = if ($PrivateProfile.Enabled) { "PASS" } else { "FAIL" }
        Value = $PrivateProfile.Enabled
    }

    $ValidationResults += [PSCustomObject]@{
        Check = "Public Profile Enabled"
        Status = if ($PublicProfile.Enabled) { "PASS" } else { "FAIL" }
        Value = $PublicProfile.Enabled
    }

    # Check default actions
    $ValidationResults += [PSCustomObject]@{
        Check = "Domain Inbound Block"
        Status = if ($DomainProfile.DefaultInboundAction -eq 'Block') { "PASS" } else { "FAIL" }
        Value = $DomainProfile.DefaultInboundAction
    }

    $ValidationResults += [PSCustomObject]@{
        Check = "Domain Outbound Allow"
        Status = if ($DomainProfile.DefaultOutboundAction -eq 'Allow') { "PASS" } else { "FAIL" }
        Value = $DomainProfile.DefaultOutboundAction
    }

    # Check logging
    $ValidationResults += [PSCustomObject]@{
        Check = "Domain Logging Enabled"
        Status = if ($DomainProfile.LogBlocked -and $DomainProfile.LogAllowed) { "PASS" } else { "FAIL" }
        Value = "Blocked: $($DomainProfile.LogBlocked), Allowed: $($DomainProfile.LogAllowed)"
    }

    $ValidationResults += [PSCustomObject]@{
        Check = "Log File Size"
        Status = if ($DomainProfile.LogMaxSizeKilobytes -ge 16384) { "PASS" } else { "FAIL" }
        Value = "$($DomainProfile.LogMaxSizeKilobytes) KB"
    }

    # Display validation results
    Write-Host "`nValidation Results:" -ForegroundColor Cyan
    $ValidationResults | Format-Table -AutoSize

    $FailedChecks = ($ValidationResults | Where-Object { $_.Status -eq "FAIL" }).Count

    if ($FailedChecks -eq 0) {
        Write-Host "`n✓ All validation checks passed!" -ForegroundColor Green
    } else {
        Write-Host "`n⚠ $FailedChecks validation check(s) failed!" -ForegroundColor Red
    }

    # Summary
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Deployment Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $TotalRules = (Get-NetFirewallRule | Where-Object { $_.DisplayName -like "CIS-FW-*" }).Count

    Write-Host "Server Role: $ServerRole" -ForegroundColor White
    Write-Host "Total CIS Rules Created: $TotalRules" -ForegroundColor White
    Write-Host "Admin Subnet: $AdminSubnet" -ForegroundColor White
    Write-Host "Log Path: $LogPath" -ForegroundColor White
    Write-Host "Transcript: $TranscriptPath`n" -ForegroundColor White

    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Review firewall logs: $LogPath" -ForegroundColor Gray
    Write-Host "2. Test connectivity to required services" -ForegroundColor Gray
    Write-Host "3. Run Get-FirewallAuditBaseline.ps1 for compliance check" -ForegroundColor Gray
    Write-Host "4. Document any custom rules added" -ForegroundColor Gray

} catch {
    Write-Host "`n❌ Error during deployment: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    throw
} finally {
    Stop-Transcript
}
```

---

## Testing and Validation

### Pre-Deployment Testing

1. **Lab Environment First**
   - Deploy to test server
   - Verify all required services work
   - Check for unexpected blocks

2. **Pilot Group**
   - Deploy to 1-2 production servers
   - Monitor for 48 hours
   - Review firewall logs

3. **Gradual Rollout**
   - Deploy to one OU at a time
   - Wait 24-48 hours between OUs
   - Monitor helpdesk tickets

### Post-Deployment Validation

```powershell
# Run the audit script
.\Get-FirewallAuditBaseline.ps1 -Verbose

# Check specific rule
Get-NetFirewallRule -DisplayName "CIS-FW-*" | Format-Table

# Review blocked connections
Get-Content "$env:SystemRoot\System32\logfiles\firewall\pfirewall-domain.log" |
    Select-String "DROP" |
    Select-Object -Last 50

# Test connectivity
Test-NetConnection -ComputerName DC01 -Port 389  # LDAP
Test-NetConnection -ComputerName DC01 -Port 88   # Kerberos
Test-NetConnection -ComputerName FS01 -Port 445  # SMB
```

### Common Issues and Resolution

| Issue | Symptom | Resolution |
|-------|---------|------------|
| GPO not applying | Rules don't appear | Run `gpupdate /force`, check GPO link |
| Service unreachable | Connection timeout | Check firewall logs, verify rule exists |
| RDP blocked | Can't connect via RDP | Verify admin subnet in rule, check Public profile |
| Replication failing | DC replication errors | Check Dynamic RPC range (49152-65535) |
| Slow logon | Delays during authentication | Check Kerberos (88), LDAP (389), DNS (53) |

---

## Troubleshooting

### Enable Debug Logging

```powershell
# Enable verbose logging for all profiles
Set-NetFirewallProfile -All -LogBlocked True -LogAllowed True -LogIgnored True
```

### Review Firewall Logs

```powershell
# Parse firewall log for blocked connections
Get-Content "$env:SystemRoot\System32\logfiles\firewall\pfirewall-domain.log" |
    Select-String "DROP" |
    ForEach-Object {
        if ($_ -match "(\d+\.\d+\.\d+\.\d+)\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+)\s+(\d+)") {
            [PSCustomObject]@{
                DateTime = ($_ -split ' ')[0,1] -join ' '
                Action = "DROP"
                SourceIP = $matches[1]
                DestIP = $matches[2]
                SourcePort = $matches[3]
                DestPort = $matches[4]
            }
        }
    } |
    Group-Object DestPort |
    Sort-Object Count -Descending |
    Select-Object Count, Name
```

### Check Active Profile

```powershell
# Determine which profile is active
Get-NetConnectionProfile
```

### Temporarily Disable for Testing

```powershell
# ONLY FOR TROUBLESHOOTING - Re-enable immediately after testing
Set-NetFirewallProfile -Profile Domain -Enabled False

# Test connectivity
Test-NetConnection -ComputerName TARGET -Port 445

# RE-ENABLE IMMEDIATELY
Set-NetFirewallProfile -Profile Domain -Enabled True
```

### Export Configuration for Support

```powershell
# Export full firewall configuration
$ExportPath = "$env:TEMP\Firewall-Export-$(Get-Date -Format 'yyyyMMdd').wfw"
Export-NetFirewallProfile -Profile Domain,Private,Public -OutFile $ExportPath
Write-Host "Configuration exported to: $ExportPath"
```

---

## Appendix: CIS Control Mapping

| CIS Control | Requirement | Implementation |
|-------------|-------------|----------------|
| 9.1.1 | Firewall enabled (Domain) | `Set-NetFirewallProfile -Profile Domain -Enabled True` |
| 9.1.2 | Inbound blocked by default | `-DefaultInboundAction Block` |
| 9.1.3 | Outbound allowed by default | `-DefaultOutboundAction Allow` |
| 9.1.4 | Logging configured | `-LogFileName`, `-LogMaxSizeKilobytes` |
| 9.2.1 | Firewall enabled (Private) | `Set-NetFirewallProfile -Profile Private -Enabled True` |
| 9.2.2 | Inbound blocked (Private) | `-DefaultInboundAction Block` |
| 9.2.4 | Disable local rules (Private) | `-AllowLocalFirewallRules False` |
| 9.2.5 | Disable local IPsec (Private) | `-AllowLocalIPsecRules False` |
| 9.2.6 | Log dropped packets (Private) | `-LogBlocked True` |
| 9.2.7 | Log allowed packets (Private) | `-LogAllowed True` |
| 9.2.8 | Log size 16MB+ (Private) | `-LogMaxSizeKilobytes 16384` |
| 9.3.1 | Firewall enabled (Public) | `Set-NetFirewallProfile -Profile Public -Enabled True` |
| 9.3.2 | Inbound blocked (Public) | `-DefaultInboundAction Block` |
| 9.3.3 | Outbound blocked (Public) | `-DefaultOutboundAction Block` |
| 9.3.4 | Disable local rules (Public) | `-AllowLocalFirewallRules False` |
| 9.3.5 | Disable local IPsec (Public) | `-AllowLocalIPsecRules False` |
| 9.3.6 | Log dropped packets (Public) | `-LogBlocked True` |
| 9.3.7 | Log allowed packets (Public) | `-LogAllowed True` |
| 9.3.8 | Log size 16MB+ (Public) | `-LogMaxSizeKilobytes 16384` |

---

## Quick Reference

### Port Numbers by Service

| Service | Protocol | Port(s) | Profile |
|---------|----------|---------|---------|
| RDP | TCP | 3389 | Domain |
| WinRM HTTP | TCP | 5985 | Domain |
| WinRM HTTPS | TCP | 5986 | Domain |
| SMB | TCP | 445 | Domain |
| DNS | TCP/UDP | 53 | Domain, Private |
| Kerberos | TCP/UDP | 88 | Domain |
| LDAP | TCP/UDP | 389 | Domain |
| LDAPS | TCP | 636 | Domain |
| Global Catalog | TCP | 3268, 3269 | Domain |
| RPC Endpoint | TCP | 135 | Domain |
| Dynamic RPC | TCP | 49152-65535 | Domain |
| HTTP | TCP | 80 | All |
| HTTPS | TCP | 443 | All |
| SQL Server | TCP | 1433 | Domain |
| WSUS HTTP | TCP | 8530 | Domain |
| WSUS HTTPS | TCP | 8531 | Domain |

---

**Document Version:** 1.0
**Last Updated:** 2025-12-26
**Next Review:** 2026-03-26
