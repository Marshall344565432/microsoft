# CIS-Compliant GPO Implementation Guide for Windows Server 2022

**Version:** 1.0
**Last Updated:** 2025-12-25
**Target Platform:** Windows Server 2022
**Compliance Standards:** CIS Level 1 & 2, Microsoft Security Baseline

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [GPO Structure and Naming Conventions](#gpo-structure-and-naming-conventions)
4. [CIS Benchmark Profiles](#cis-benchmark-profiles)
5. [OU Design for GPO Deployment](#ou-design-for-gpo-deployment)
6. [GPO Layering Strategy](#gpo-layering-strategy)
7. [Step-by-Step Implementation](#step-by-step-implementation)
8. [Obtaining CIS Build Kits](#obtaining-cis-build-kits)
9. [Microsoft Security Baseline Integration](#microsoft-security-baseline-integration)
10. [Validation and Testing](#validation-and-testing)
11. [Troubleshooting](#troubleshooting)

---

## Overview

This guide provides a complete implementation plan for deploying CIS-compliant Group Policy Objects (GPOs) for Windows Server 2022 environments. The implementation follows industry best practices for:

- **Defense in depth** security architecture
- **Minimal business impact** configurations (Level 1)
- **Enhanced security** for high-security environments (Level 2)
- **Integration** with Microsoft Security Baselines
- **Scalability** for enterprise deployments

### Key Benefits

- **Compliance**: Meet CIS Benchmark requirements for audits and certifications
- **Security**: Implement proven security configurations from industry experts
- **Consistency**: Standardized security across all servers
- **Automation**: PowerShell scripts for repeatable deployments
- **Flexibility**: Override GPOs for documented exceptions

---

## Prerequisites

### Required Software and Features

| Component | Requirement | Installation Command |
|-----------|-------------|---------------------|
| **RSAT Tools** | Group Policy Management | `Install-WindowsFeature GPMC` |
| **ADMX Templates** | Windows Server 2022 | Install to Central Store |
| **PowerShell** | Version 5.1+ | Pre-installed on Server 2022 |
| **ActiveDirectory Module** | For AD operations | `Import-Module ActiveDirectory` |

### Required Permissions

- **Domain Admin** or equivalent rights for GPO creation and linking
- **SYSVOL write access** for ADMX template deployment
- **Backup Operators** membership for GPO backup operations

### Lab Environment

Before production deployment, set up a test environment:

```
Test OU Structure:
├── Test-DomainControllers
│   └── TEST-DC01
├── Test-MemberServers
│   └── TEST-SVR01
└── Test-Users
    └── testuser01
```

---

## GPO Structure and Naming Conventions

### Recommended Naming Schema

Use a structured naming convention:

```
[Scope]-[Type]-[Category]-[Function]-[Version/Level]
```

**Components:**
- **Scope**: G (Global), S (Site), D (Domain), OU name
- **Type**: C (Computer), U (User), B (Both)
- **Category**: SEC (Security), APP (Application), CFG (Config), PATCH (Updates)
- **Function**: Descriptive purpose
- **Version**: L1, L2, or version number

### Example GPO Names

```
Security Baselines:
├── C-SEC-CIS-DomainController-L1
├── C-SEC-CIS-DomainController-L1-Services
├── C-SEC-CIS-MemberServer-L1
├── C-SEC-CIS-MemberServer-L1-Services
├── C-SEC-CIS-MemberServer-L2
├── C-SEC-CIS-MemberServer-L2-Services
├── U-SEC-CIS-UserSettings-L1
└── U-SEC-CIS-UserSettings-L2

Microsoft Baselines:
├── C-SEC-MSFT-Server2022-MemberServer
├── C-SEC-MSFT-Server2022-DomainController
└── C-SEC-MSFT-DefenderAV

Patch Management:
├── C-PATCH-DomainControllers
├── C-PATCH-MemberServers-Ring1
├── C-PATCH-MemberServers-Ring2
└── C-PATCH-MemberServers-Ring3

Override GPOs (use underscore prefix for sorting):
├── _C-SEC-Override-DomainController
├── _C-SEC-Override-MemberServer
├── _C-SEC-Override-FileServer
└── _C-SEC-Override-WebServer
```

---

## CIS Benchmark Profiles

### Profile Comparison

| Aspect | Level 1 | Level 2 |
|--------|---------|---------|
| **Purpose** | Baseline security, minimal business impact | Enhanced security, defense in depth |
| **Target** | All production servers | High-security environments |
| **Restrictiveness** | Moderate | Very restrictive |
| **Application Compatibility** | High | May impact some applications |
| **Recommended For** | Standard enterprise servers | Sensitive data systems, DMZ servers |

### Level 1 Settings Categories

- Password policies (14 character minimum, 365 day max age)
- Account lockout policies (5 attempts, 15 minute lockout)
- User rights assignments (principle of least privilege)
- Audit policies (comprehensive logging)
- Security options (disable Guest, SMBv1, anonymous enumeration)
- Windows Firewall (enabled on all profiles)
- Remote Desktop restrictions
- Service configurations (disable unnecessary services)

### Level 2 Additional Settings

- More restrictive password policies
- Enhanced audit logging
- Additional service hardening
- Stricter remote access controls
- Advanced network security settings

### Domain Controller vs Member Server

**Important:** CIS provides separate GPOs for Domain Controllers and Member Servers:

| GPO Type | Target | Critical Differences |
|----------|--------|----------------------|
| **DC GPOs** | Domain Controllers | Less restrictive user rights, DC-specific audit policies |
| **MS GPOs** | Member Servers | Administrator account disabled, stricter lockdown |
| **Services GPOs** | Both | Separate service configuration policies (cannot be merged) |

**Never apply Member Server GPOs to Domain Controllers** - this will break your AD environment.

---

## OU Design for GPO Deployment

### Recommended OU Structure

```
Domain Root (company.local)
│
├── _Admin                              # Administrative accounts
│   ├── Tier0-Accounts                  # Domain/Enterprise Admins
│   ├── Tier1-Accounts                  # Server Admins
│   ├── Tier2-Accounts                  # Workstation Admins
│   └── Service-Accounts                # Service accounts
│
├── _Computers
│   ├── Servers
│   │   ├── Tier0-DomainControllers    # Link DC GPOs here
│   │   │   ├── DC01
│   │   │   ├── DC02
│   │   │   └── DC03
│   │   │
│   │   ├── Tier1-MemberServers
│   │   │   ├── FileServers            # Link role-specific GPOs
│   │   │   ├── WebServers
│   │   │   ├── DatabaseServers
│   │   │   ├── ApplicationServers
│   │   │   └── PrintServers
│   │   │
│   │   ├── Tier2-Test                 # Test/staging servers
│   │   │   ├── Test-DomainControllers
│   │   │   └── Test-MemberServers
│   │   │
│   │   └── _Quarantine                # New/non-compliant servers
│   │
│   └── Workstations                   # If managing workstations
│       ├── Standard
│       └── HighSecurity
│
└── _Users
    ├── StandardUsers
    ├── PrivilegedUsers
    └── DisabledAccounts
```

### OU Design Principles

1. **Tiered Administration Model**
   - Tier 0: Domain Controllers and identity infrastructure
   - Tier 1: Enterprise servers and applications
   - Tier 2: Workstations and user devices

2. **Separate Users and Computers** - Essential for proper GPO targeting

3. **Use underscores for priority OUs** - `_Admin` sorts to top

4. **Limit OU depth** - Maximum 10 levels for performance

5. **Create role-specific server OUs** - Enables targeted security policies

---

## GPO Layering Strategy

### Application Order (LSDOU)

GPOs apply in this order, with later policies taking precedence:

1. **L**ocal Policy (lowest precedence)
2. **S**ite-linked GPOs
3. **D**omain-linked GPOs
4. **O**rganizational **U**nit GPOs (highest precedence)

Within each level, link order determines precedence (lower number = higher precedence).

### Recommended Layering Model

```
┌─────────────────────────────────────────────────────────┐
│ Layer 5: OVERRIDE GPOs (Highest Precedence)            │
│   Link Order: 1                                         │
│   _C-SEC-Override-[Role]                                │
│   Purpose: Organization-specific exceptions             │
├─────────────────────────────────────────────────────────┤
│ Layer 4: ROLE-SPECIFIC GPOs                            │
│   Link Order: 2                                         │
│   C-SEC-SQLServer-Hardening, C-SEC-WebServer-Hardening  │
│   Purpose: Application/role-specific security           │
├─────────────────────────────────────────────────────────┤
│ Layer 3: CIS SECURITY BASELINE GPOs                    │
│   Link Order: 3-4                                       │
│   C-SEC-CIS-MemberServer-L1-Services (Order 3)          │
│   C-SEC-CIS-MemberServer-L1 (Order 4)                   │
│   Purpose: CIS compliance settings                      │
├─────────────────────────────────────────────────────────┤
│ Layer 2: MICROSOFT SECURITY BASELINE GPOs              │
│   Link Order: 5                                         │
│   C-SEC-MSFT-Server2022-MemberServer                    │
│   Purpose: Microsoft recommended settings               │
├─────────────────────────────────────────────────────────┤
│ Layer 1: BASE CONFIGURATION GPOs (Lowest Precedence)   │
│   Link Order: 6                                         │
│   C-CFG-AllServers-BaseConfig                           │
│   Purpose: Common settings (time sync, event log)       │
└─────────────────────────────────────────────────────────┘
```

### Link Order Examples

**For Domain Controllers OU:**

| Link Order | GPO Name | Purpose |
|------------|----------|---------|
| 1 | _C-SEC-Override-DC | Documented exceptions |
| 2 | C-SEC-CIS-DomainController-L1-Services | CIS service settings |
| 3 | C-SEC-CIS-DomainController-L1 | CIS baseline |
| 4 | C-SEC-MSFT-Server2022-DC | Microsoft baseline |
| 5 | Default Domain Controllers Policy | Keep at bottom |

**For Member Servers OU:**

| Link Order | GPO Name | Purpose |
|------------|----------|---------|
| 1 | _C-SEC-Override-MemberServer | Documented exceptions |
| 2 | C-SEC-[Role]-Hardening | Role-specific (if applicable) |
| 3 | C-SEC-CIS-MS-L1-Services | CIS service settings |
| 4 | C-SEC-CIS-MS-L1 | CIS baseline |
| 5 | C-SEC-MSFT-Server2022-MS | Microsoft baseline |
| 6 | C-CFG-AllServers-BaseConfig | Common configuration |

---

## Step-by-Step Implementation

### Phase 1: Preparation (Week 1)

#### 1.1 Create Central Store for ADMX Templates

```powershell
# Run on Domain Controller
$CentralStore = "\\$env:USERDNSDOMAIN\SYSVOL\$env:USERDNSDOMAIN\Policies\PolicyDefinitions"

# Create directory structure
New-Item -Path $CentralStore -ItemType Directory -Force
New-Item -Path "$CentralStore\en-US" -ItemType Directory -Force

# Copy ADMX templates from local machine
Copy-Item -Path "$env:SystemRoot\PolicyDefinitions\*.admx" -Destination $CentralStore -Force
Copy-Item -Path "$env:SystemRoot\PolicyDefinitions\en-US\*.adml" -Destination "$CentralStore\en-US" -Force

Write-Output "Central Store created at: $CentralStore"
```

#### 1.2 Create Test OU Structure

```powershell
# Import Active Directory module
Import-Module ActiveDirectory

# Get domain DN
$DomainDN = (Get-ADDomain).DistinguishedName

# Create Test OUs
$TestOUs = @(
    "OU=_Test,DC=company,DC=local",
    "OU=Test-DomainControllers,OU=_Test,$DomainDN",
    "OU=Test-MemberServers,OU=_Test,$DomainDN"
)

foreach ($OU in $TestOUs) {
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$OU'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name ($OU -split ',')[0].Replace('OU=','') -Path (($OU -split ',',2)[1])
        Write-Output "Created OU: $OU"
    }
}
```

#### 1.3 Document Current State

```powershell
# Backup all existing GPOs
$BackupPath = "C:\GPO-Backups\Pre-CIS-Baseline"
New-Item -Path $BackupPath -ItemType Directory -Force

# Backup each GPO
Get-GPO -All | ForEach-Object {
    Backup-GPO -Name $_.DisplayName -Path $BackupPath
}

# Generate GPO inventory report
Get-GPO -All | Select-Object DisplayName, GpoStatus, CreationTime, ModificationTime |
    Export-Csv -Path "$BackupPath\GPO-Inventory.csv" -NoTypeInformation

Write-Output "GPO backup completed: $BackupPath"
```

---

### Phase 2: Obtain and Import Security Baselines (Week 2)

#### 2.1 Download Microsoft Security Compliance Toolkit

1. Download from: https://www.microsoft.com/en-us/download/details.aspx?id=55319
2. Extract to: `C:\SecurityBaselines\Microsoft-SCT`
3. Navigate to: `Windows Server 2022 Security Baseline\GPOs`

#### 2.2 Obtain CIS Build Kits

**Option A: CIS SecureSuite Membership (Recommended)**

1. Visit: https://www.cisecurity.org/cis-securesuite
2. Download: CIS Microsoft Windows Server 2022 Benchmark Build Kit
3. Extract to: `C:\SecurityBaselines\CIS-BuildKit`

**Option B: Manual GPO Creation (Free)**

1. Download CIS Benchmark PDF: https://www.cisecurity.org/benchmark/microsoft_windows_server
2. Manually configure GPOs following the recommendations
3. Use the included PowerShell scripts in `/gpos/deployment/` to assist

**Option C: Use HardeningKitty (Automated - Free)**

```powershell
# Clone HardeningKitty repository
git clone https://github.com/scipag/HardeningKitty.git C:\SecurityBaselines\HardeningKitty

# Import module
Import-Module C:\SecurityBaselines\HardeningKitty\HardeningKitty.psm1

# Run audit to assess current state
Invoke-HardeningKitty -Mode Audit -Log -Report -FileFindingList .\lists\finding_list_cis_microsoft_windows_server_2022_21h2.csv
```

#### 2.3 Create Empty Override GPOs

```powershell
# Create override GPOs for future customization
$OverrideGPOs = @(
    "_C-SEC-Override-DomainController",
    "_C-SEC-Override-MemberServer",
    "_C-SEC-Override-FileServer",
    "_C-SEC-Override-WebServer",
    "_C-SEC-Override-DatabaseServer"
)

foreach ($GPOName in $OverrideGPOs) {
    if (-not (Get-GPO -Name $GPOName -ErrorAction SilentlyContinue)) {
        New-GPO -Name $GPOName -Comment "Override GPO for baseline exceptions - Document all changes in description"
        Write-Output "Created: $GPOName"
    }
}
```

---

### Phase 3: Import and Configure GPOs (Week 3)

#### 3.1 Import Microsoft Security Baselines

```powershell
# Import Microsoft baselines
$MSFTBaselinePath = "C:\SecurityBaselines\Microsoft-SCT\Windows Server 2022 Security Baseline\GPOs"

# Member Server Baseline
$MSFT_MS = New-GPO -Name "C-SEC-MSFT-Server2022-MemberServer" -Comment "Microsoft Security Baseline for Windows Server 2022 Member Servers"
Import-GPO -BackupGpoName "MSFT Windows Server 2022 - Member Server" -Path $MSFTBaselinePath -TargetName $MSFT_MS.DisplayName

# Domain Controller Baseline
$MSFT_DC = New-GPO -Name "C-SEC-MSFT-Server2022-DomainController" -Comment "Microsoft Security Baseline for Windows Server 2022 Domain Controllers"
Import-GPO -BackupGpoName "MSFT Windows Server 2022 - Domain Controller" -Path $MSFTBaselinePath -TargetName $MSFT_DC.DisplayName

Write-Output "Microsoft baselines imported successfully"
```

#### 3.2 Import CIS Build Kit GPOs

```powershell
# Import CIS GPOs (requires CIS Build Kit download)
$CISBuildKitPath = "C:\SecurityBaselines\CIS-BuildKit\Windows-Server-2022"

$CISGPOs = @{
    "CIS-DC-L1" = "C-SEC-CIS-DomainController-L1"
    "CIS-DC-L1-Services" = "C-SEC-CIS-DomainController-L1-Services"
    "CIS-MS-L1" = "C-SEC-CIS-MemberServer-L1"
    "CIS-MS-L1-Services" = "C-SEC-CIS-MemberServer-L1-Services"
    "CIS-User-L1" = "U-SEC-CIS-UserSettings-L1"
}

foreach ($Source in $CISGPOs.Keys) {
    $TargetName = $CISGPOs[$Source]
    $BackupPath = Join-Path $CISBuildKitPath $Source

    if (Test-Path $BackupPath) {
        $GPO = New-GPO -Name $TargetName -Comment "CIS Benchmark Windows Server 2022 - $Source"
        Import-GPO -BackupGpoName $Source -Path $CISBuildKitPath -TargetName $TargetName
        Write-Output "Imported: $TargetName"
    } else {
        Write-Warning "CIS Build Kit not found at: $BackupPath"
    }
}
```

#### 3.3 Create WMI Filters (OS Version Targeting)

```powershell
# Create WMI filter for Windows Server 2022
$WMIFilter = @{
    Name = "Windows Server 2022"
    Description = "Target only Windows Server 2022 systems (Build 20348)"
    Query = "SELECT * FROM Win32_OperatingSystem WHERE Version LIKE '10.0.20348%' AND ProductType = '3'"
}

# Function to create WMI filter
function New-GPOWMIFilter {
    param(
        [string]$Name,
        [string]$Description,
        [string]$Query
    )

    $Domain = Get-ADDomain
    $WMIGUID = [string]"{" + ([System.Guid]::NewGuid()) + "}"
    $WMIDN = "CN=$WMIGUID,CN=SOM,CN=WmiPolicy,CN=System,$($Domain.DistinguishedName)"
    $WMICN = $WMIGUID
    $WMICreationDate = (Get-Date).ToUniversalTime().ToString("yyyyMMddhhmmss.ffffff-000")

    $Attributes = @{
        "msWMI-Name" = $Name
        "msWMI-Parm1" = $Description
        "msWMI-Parm2" = "1;3;10;$($Query.Length);WQL;root\CIMv2;$Query;"
        "msWMI-Author" = "$env:USERNAME@$env:USERDNSDOMAIN"
        "msWMI-ID" = $WMIGUID
        "instanceType" = 4
        "showInAdvancedViewOnly" = "TRUE"
        "distinguishedname" = $WMIDN
        "msWMI-ChangeDate" = $WMICreationDate
        "msWMI-CreationDate" = $WMICreationDate
    }

    New-ADObject -Name $WMICN -Type "msWMI-Som" -Path "CN=SOM,CN=WmiPolicy,CN=System,$($Domain.DistinguishedName)" -OtherAttributes $Attributes
}

# Create the WMI filter
New-GPOWMIFilter -Name $WMIFilter.Name -Description $WMIFilter.Description -Query $WMIFilter.Query
Write-Output "WMI Filter created: $($WMIFilter.Name)"
```

---

### Phase 4: Test Deployment (Week 4)

#### 4.1 Link GPOs to Test OUs

```powershell
# Link GPOs to Test Domain Controllers OU
$TestDC_OU = "OU=Test-DomainControllers,OU=_Test,$DomainDN"

New-GPLink -Name "_C-SEC-Override-DomainController" -Target $TestDC_OU -LinkEnabled Yes -Order 1
New-GPLink -Name "C-SEC-CIS-DomainController-L1-Services" -Target $TestDC_OU -LinkEnabled Yes -Order 2
New-GPLink -Name "C-SEC-CIS-DomainController-L1" -Target $TestDC_OU -LinkEnabled Yes -Order 3
New-GPLink -Name "C-SEC-MSFT-Server2022-DomainController" -Target $TestDC_OU -LinkEnabled Yes -Order 4

# Link GPOs to Test Member Servers OU
$TestMS_OU = "OU=Test-MemberServers,OU=_Test,$DomainDN"

New-GPLink -Name "_C-SEC-Override-MemberServer" -Target $TestMS_OU -LinkEnabled Yes -Order 1
New-GPLink -Name "C-SEC-CIS-MemberServer-L1-Services" -Target $TestMS_OU -LinkEnabled Yes -Order 2
New-GPLink -Name "C-SEC-CIS-MemberServer-L1" -Target $TestMS_OU -LinkEnabled Yes -Order 3
New-GPLink -Name "C-SEC-MSFT-Server2022-MemberServer" -Target $TestMS_OU -LinkEnabled Yes -Order 4

Write-Output "Test GPO links created"
```

#### 4.2 Move Test Server to Test OU and Force Update

```powershell
# Move test server to test OU
$TestServer = "TEST-SVR01"
Move-ADObject -Identity "CN=$TestServer,OU=Servers,DC=company,DC=local" -TargetPath $TestMS_OU

# On the test server, force GPO update
Invoke-Command -ComputerName $TestServer -ScriptBlock {
    gpupdate /force
}

# Wait for replication
Start-Sleep -Seconds 30

# Generate GPResult report
Invoke-Command -ComputerName $TestServer -ScriptBlock {
    gpresult /H "C:\Temp\GPResult_PostBaseline.html" /F
}

Write-Output "Test deployment completed. Review GPResult report on $TestServer"
```

#### 4.3 Validate GPO Application

```powershell
# On the test server, check which GPOs were applied
Invoke-Command -ComputerName TEST-SVR01 -ScriptBlock {
    Write-Output "`n=== Applied Computer GPOs ==="
    gpresult /r /scope:computer | Select-String "Applied Group Policy Objects" -Context 0,20

    Write-Output "`n=== Denied GPOs (if any) ==="
    gpresult /r | Select-String "The following GPOs were not applied" -Context 0,10
}
```

---

### Phase 5: Production Deployment (Week 5-6)

#### 5.1 Domain Controllers First (Lowest Risk)

**Why DCs first?** Domain Controllers benefit most from security hardening and have the least application compatibility issues.

```powershell
# Production Domain Controllers OU
$ProdDC_OU = "OU=Tier0-DomainControllers,OU=Servers,OU=_Computers,$DomainDN"

# Link GPOs with proper order
New-GPLink -Name "_C-SEC-Override-DomainController" -Target $ProdDC_OU -LinkEnabled Yes -Order 1
New-GPLink -Name "C-SEC-CIS-DomainController-L1-Services" -Target $ProdDC_OU -LinkEnabled Yes -Order 2
New-GPLink -Name "C-SEC-CIS-DomainController-L1" -Target $ProdDC_OU -LinkEnabled Yes -Order 3
New-GPLink -Name "C-SEC-MSFT-Server2022-DomainController" -Target $ProdDC_OU -LinkEnabled Yes -Order 4

# Set Default Domain Controllers Policy to lowest priority
Set-GPLink -Name "Default Domain Controllers Policy" -Target $ProdDC_OU -Order 99

Write-Output "Production DC GPO links created"
```

**Deployment Schedule for DCs:**

1. **DC01** - Apply and monitor for 24 hours
2. Verify AD replication: `repadmin /showrepl`
3. **DC02** - Apply after DC01 verification
4. **DC03+** - Continue staged rollout

#### 5.2 Member Servers by Role

```powershell
# File Servers
$FileServers_OU = "OU=FileServers,OU=Tier1-MemberServers,OU=Servers,OU=_Computers,$DomainDN"
New-GPLink -Name "_C-SEC-Override-FileServer" -Target $FileServers_OU -LinkEnabled Yes -Order 1
New-GPLink -Name "C-SEC-CIS-MS-L1-Services" -Target $FileServers_OU -LinkEnabled Yes -Order 2
New-GPLink -Name "C-SEC-CIS-MS-L1" -Target $FileServers_OU -LinkEnabled Yes -Order 3
New-GPLink -Name "C-SEC-MSFT-Server2022-MemberServer" -Target $FileServers_OU -LinkEnabled Yes -Order 4

# Web Servers
$WebServers_OU = "OU=WebServers,OU=Tier1-MemberServers,OU=Servers,OU=_Computers,$DomainDN"
New-GPLink -Name "_C-SEC-Override-WebServer" -Target $WebServers_OU -LinkEnabled Yes -Order 1
New-GPLink -Name "C-SEC-CIS-MS-L1-Services" -Target $WebServers_OU -LinkEnabled Yes -Order 2
New-GPLink -Name "C-SEC-CIS-MS-L1" -Target $WebServers_OU -LinkEnabled Yes -Order 3
New-GPLink -Name "C-SEC-MSFT-Server2022-MemberServer" -Target $WebServers_OU -LinkEnabled Yes -Order 4

# Database Servers
$DBServers_OU = "OU=DatabaseServers,OU=Tier1-MemberServers,OU=Servers,OU=_Computers,$DomainDN"
New-GPLink -Name "_C-SEC-Override-DatabaseServer" -Target $DBServers_OU -LinkEnabled Yes -Order 1
New-GPLink -Name "C-SEC-CIS-MS-L1-Services" -Target $DBServers_OU -LinkEnabled Yes -Order 2
New-GPLink -Name "C-SEC-CIS-MS-L1" -Target $DBServers_OU -LinkEnabled Yes -Order 3
New-GPLink -Name "C-SEC-MSFT-Server2022-MemberServer" -Target $DBServers_OU -LinkEnabled Yes -Order 4
```

**Deployment Schedule:**
- Week 1: File servers (low risk)
- Week 2: Application servers
- Week 3: Web servers (coordinate with load balancer)
- Week 4: Database servers (highest risk - schedule maintenance window)

---

## Obtaining CIS Build Kits

### Official CIS SecureSuite (Recommended)

**CIS SecureSuite Membership Levels:**

| Level | Cost | What's Included |
|-------|------|-----------------|
| **Free Tier** | $0 | CIS Benchmarks PDF, sample Build Kit |
| **Standard** | $495/year | Full Build Kits, CIS-CAT Lite |
| **Pro** | $2,495/year | All Standard + CIS-CAT Pro automated assessment |

**To Download:**

1. Create account at: https://www.cisecurity.org/
2. Navigate to: https://www.cisecurity.org/cis-securesuite/cis-securesuite-build-kit-content
3. Download: "CIS Microsoft Windows Server 2022 Benchmark Build Kit"
4. Extract the GPO backup folders

### Alternative: Use HardeningKitty (Free, Open Source)

HardeningKitty can audit and apply CIS settings without requiring CIS membership:

```powershell
# Clone repository
git clone https://github.com/scipag/HardeningKitty.git

# Import module
Import-Module .\HardeningKitty\HardeningKitty.psm1

# Audit current state against CIS benchmark
Invoke-HardeningKitty -Mode Audit -Log -Report `
    -FileFindingList .\HardeningKitty\lists\finding_list_cis_microsoft_windows_server_2022_21h2.csv

# Apply hardening (use with caution in test environment first!)
Invoke-HardeningKitty -Mode HailMary -Log -Report `
    -FileFindingList .\HardeningKitty\lists\finding_list_cis_microsoft_windows_server_2022_21h2.csv
```

### Alternative: Manual GPO Creation

If you cannot obtain CIS Build Kits, you can manually configure GPOs:

1. Download CIS Benchmark PDF (free): https://www.cisecurity.org/benchmark/microsoft_windows_server
2. Use the included PowerShell audit script: `/audits/cis-benchmarks/Get-CISAuditBaseline.ps1`
3. Manually configure GPO settings following the PDF recommendations
4. Use Policy Analyzer to compare with Microsoft baselines

---

## Microsoft Security Baseline Integration

### Comparison: CIS vs Microsoft Baselines

| Aspect | CIS Benchmark | Microsoft Security Baseline |
|--------|---------------|----------------------------|
| **Source** | Independent, vendor-neutral | Microsoft official |
| **Coverage** | Cross-platform | Microsoft products only |
| **Update Cycle** | Regular updates | Per OS release |
| **Stringency** | More restrictive | Balanced for compatibility |
| **Cost** | Build Kits require membership | Free |
| **Best For** | Compliance requirements | Microsoft-centric environments |

### Integration Strategies

**Option 1: CIS Only**
- Use CIS GPOs exclusively
- Best for: Organizations requiring CIS certification

**Option 2: Microsoft Only**
- Use Microsoft Security Baselines only
- Best for: Simpler environments, lower overhead

**Option 3: Layered Approach (Recommended)**
- Apply Microsoft baseline first (Layer 2)
- Apply CIS baseline on top (Layer 3)
- Use override GPOs for conflicts (Layer 5)
- Best for: Maximum security coverage

### Using Policy Analyzer to Compare

```powershell
# Policy Analyzer is included in Microsoft Security Compliance Toolkit
$PolicyAnalyzer = "C:\SecurityBaselines\Microsoft-SCT\Policy Analyzer\PolicyAnalyzer.exe"

# Launch Policy Analyzer
& $PolicyAnalyzer

# Steps in GUI:
# 1. File > Add Policy File > Select Microsoft baseline GPO backup
# 2. File > Add Policy File > Select CIS baseline GPO backup
# 3. View > Compare > Select both policies
# 4. Review differences and conflicts
# 5. Export comparison report
```

---

## Validation and Testing

### Phase 1: Pre-Deployment Validation

```powershell
# Validate GPO syntax and settings
Get-GPO -Name "C-SEC-CIS-MemberServer-L1" | Test-GPO

# Generate GPO report
Get-GPOReport -Name "C-SEC-CIS-MemberServer-L1" -ReportType HTML -Path "C:\Reports\GPO-Report-CIS-MS-L1.html"

# Check for conflicting settings
Import-Module GroupPolicy
$Baseline1 = Get-GPOReport -Name "C-SEC-MSFT-Server2022-MemberServer" -ReportType XML
$Baseline2 = Get-GPOReport -Name "C-SEC-CIS-MemberServer-L1" -ReportType XML

# Manual comparison or use Policy Analyzer
```

### Phase 2: Post-Deployment Validation

#### 2.1 GPResult Validation

```powershell
# On target server, generate comprehensive GPResult report
gpresult /H "C:\Temp\GPResult_$env:COMPUTERNAME.html" /F

# Check applied GPOs
gpresult /r /scope:computer

# Check for errors or denied GPOs
gpresult /r | Select-String "denied\|error" -Context 2,5
```

#### 2.2 Security Audit with CIS-CAT

If you have CIS-CAT Pro (part of CIS SecureSuite Pro):

```powershell
# Run CIS-CAT assessment
.\Assessor-CLI.bat -i -b benchmarks\CIS_Microsoft_Windows_Server_2022_Benchmark_v2.0.0-xccdf.xml -p "Level 1 - Member Server"

# Review HTML report
# Compliance percentage should be 95%+ after GPO deployment
```

#### 2.3 HardeningKitty Audit

```powershell
# Audit compliance with HardeningKitty
Invoke-HardeningKitty -Mode Audit -Log -Report `
    -FileFindingList .\lists\finding_list_cis_microsoft_windows_server_2022_21h2.csv

# Review compliance report
# Check for "False" findings and address with override GPOs if needed
```

### Phase 3: Application Testing

**Critical Testing Checklist:**

- [ ] Domain authentication still works
- [ ] File shares accessible
- [ ] Web applications load correctly
- [ ] Database connections functional
- [ ] Remote Desktop access works
- [ ] Administrative tools accessible
- [ ] Critical services running
- [ ] Application-specific functionality validated

```powershell
# Service validation script
$CriticalServices = @("W32Time", "DNS", "DFSR", "Netlogon", "EventLog", "WinRM")

foreach ($Service in $CriticalServices) {
    $Status = Get-Service -Name $Service -ErrorAction SilentlyContinue
    if ($Status.Status -ne "Running") {
        Write-Warning "Service $Service is $($Status.Status)"
    } else {
        Write-Output "✓ Service $Service is running"
    }
}
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: GPO Not Applying

**Symptoms:** `gpresult` shows GPO as "Denied" or not listed

**Troubleshooting Steps:**

```powershell
# Check GPO replication
Get-GPO -Name "C-SEC-CIS-MemberServer-L1" | Select-Object DisplayName, GpoStatus

# Force replication
Invoke-GPUpdate -Computer "SERVER01" -Force -RandomDelayInMinutes 0

# Check SYSVOL replication
dcdiag /test:sysvolcheck /test:advertising

# Verify permissions
Get-GPPermission -Name "C-SEC-CIS-MemberServer-L1" -All
```

**Solution:** Ensure "Authenticated Users" has "Read" permission on the GPO.

#### Issue 2: Application Compatibility Issues

**Symptoms:** Application fails after baseline deployment

**Troubleshooting:**

1. Generate "before" and "after" GPResult reports
2. Compare settings to identify the breaking change
3. Add exception to override GPO
4. Document the exception with business justification

```powershell
# Create targeted exception in override GPO
# Example: Re-enable a service that was disabled by baseline

$OverrideGPO = "_C-SEC-Override-MemberServer"

# Navigate to the setting in GPMC and configure the exception
# Always document WHY in the GPO description
Set-GPO -Name $OverrideGPO -Description "Override: Re-enabled AppXSvc for Application Store requirement - Approved by Change Control #12345"
```

#### Issue 3: Performance Impact

**Symptoms:** Slow logon or startup after GPO deployment

**Diagnosis:**

```powershell
# Check GPO processing time
Get-WinEvent -LogName "Microsoft-Windows-GroupPolicy/Operational" |
    Where-Object { $_.Id -eq 8001 } |
    Select-Object TimeCreated, Message -First 10

# Identify slow-processing GPOs
```

**Solutions:**
- Simplify GPO structure (consolidate small GPOs)
- Remove loopback processing if not needed
- Disable unused settings sections
- Enable "Run in logged-on user's security context" for user policies

#### Issue 4: Conflicting Settings

**Symptoms:** Expected setting not applied, different setting in effect

**Diagnosis:** Use Policy Analyzer or GPResult HTML report

**Solution:**
1. Review GPO link order (lower number = higher precedence)
2. Check for "Enforced" and "Block Inheritance" flags
3. Use override GPO to explicitly set desired value

#### Issue 5: Password Policy Not Working

**Symptom:** Password policy from GPO linked to OU not enforced

**Explanation:** Password policies ONLY apply from GPOs linked to the **domain root**, not OUs.

**Solution:**
- Link password policy GPO to domain root
- Use Fine-Grained Password Policies (PSOs) for OU-specific requirements

```powershell
# Create Fine-Grained Password Policy for specific OU
New-ADFineGrainedPasswordPolicy -Name "FileServerAdmins-PSO" `
    -Precedence 10 `
    -MinPasswordLength 16 `
    -MaxPasswordAge "90.00:00:00" `
    -ComplexityEnabled $true

# Apply to specific group
Add-ADFineGrainedPasswordPolicySubject -Identity "FileServerAdmins-PSO" -Subjects "FileServer-Admins"
```

---

## Ongoing Maintenance

### Monthly Tasks

- [ ] Review new CIS Benchmark releases
- [ ] Check for Microsoft Security Baseline updates
- [ ] Audit compliance with CIS-CAT or HardeningKitty
- [ ] Review override GPO exceptions (ensure still needed)
- [ ] Update documentation for any changes

### Quarterly Tasks

- [ ] Full GPO audit and cleanup
- [ ] Validate all GPOs still linked and functioning
- [ ] Test GPO deployment in lab environment
- [ ] Review and update WMI filters

### Annual Tasks

- [ ] Major version upgrade testing
- [ ] Complete security baseline review
- [ ] Update Central Store ADMX templates
- [ ] Renew CIS SecureSuite membership (if applicable)

---

## Additional Resources

### Official Documentation

- [CIS Microsoft Windows Server Benchmarks](https://www.cisecurity.org/benchmark/microsoft_windows_server)
- [Microsoft Security Compliance Toolkit](https://www.microsoft.com/en-us/download/details.aspx?id=55319)
- [Group Policy Best Practices](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/best-practices-for-securing-active-directory)

### Tools

- [HardeningKitty](https://github.com/scipag/HardeningKitty) - Free CIS auditing and hardening
- [Policy Analyzer](https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/security-compliance-toolkit-10) - Compare GPO baselines
- [CIS-CAT Pro](https://www.cisecurity.org/cybersecurity-tools/cis-cat-pro) - Automated compliance assessment

### Community Resources

- [r/sysadmin](https://reddit.com/r/sysadmin) - IT professional community
- [Spiceworks Community](https://community.spiceworks.com/) - IT Q&A forum
- [TechNet Forums](https://social.technet.microsoft.com/) - Microsoft official forums

---

## Conclusion

Implementing CIS-compliant GPOs for Windows Server 2022 is a critical security initiative that requires careful planning, testing, and validation. By following this guide, you will:

✅ **Achieve compliance** with industry-recognized security standards
✅ **Improve security posture** across your server infrastructure
✅ **Maintain flexibility** through override GPOs for business needs
✅ **Enable auditing** and continuous compliance monitoring
✅ **Standardize configurations** for consistency and reduced attack surface

Remember: **Security is a journey, not a destination.** Regular reviews, updates, and validation are essential to maintaining a strong security baseline.

---

**Document Version:** 1.0
**Last Updated:** 2025-12-25
**Next Review Date:** 2026-01-25
