# Windows Update Group Policy Configuration Guide for Windows Server 2022

**Version:** 1.0
**Last Updated:** 2025-12-25
**Target Platform:** Windows Server 2022
**Compatible With:** WSUS, Windows Update for Business

---

## Table of Contents

1. [Overview](#overview)
2. [Windows Update GPO Settings Reference](#windows-update-gpo-settings-reference)
3. [Patch Management Strategy](#patch-management-strategy)
4. [Ring Deployment Model](#ring-deployment-model)
5. [WSUS Integration](#wsus-integration)
6. [Automatic Updates Configuration](#automatic-updates-configuration)
7. [Maintenance Windows and Scheduling](#maintenance-windows-and-scheduling)
8. [Reboot Management](#reboot-management)
9. [Update Deferral Policies](#update-deferral-policies)
10. [Role-Based Patch Schedules](#role-based-patch-schedules)
11. [PowerShell Deployment Scripts](#powershell-deployment-scripts)
12. [Troubleshooting](#troubleshooting)

---

## Overview

This guide provides complete Group Policy Object (GPO) configurations for Windows Update management on Windows Server 2022. The documented settings enable:

- **Automated patch deployment** with controlled rollouts
- **WSUS server integration** for enterprise update control
- **Ring-based deployment** for staged testing and validation
- **Role-specific schedules** tailored to server functions
- **Compliance deadlines** to ensure timely patching
- **Reboot control** to minimize service disruptions

### Key Principles

1. **Never auto-patch Domain Controllers** - Use manual or notify-only modes
2. **Stagger schedules** - Prevent all servers from rebooting simultaneously
3. **Test before production** - Use deployment rings with deferred updates
4. **Maintain compliance** - Use deadline policies to enforce critical updates
5. **Monitor and validate** - Track update status across infrastructure

---

## Windows Update GPO Settings Reference

All Windows Update settings are located at:
```
Computer Configuration > Administrative Templates > Windows Components > Windows Update
```

### Master Settings Table

| Setting | Path | Registry Key | Values | Description |
|---------|------|--------------|--------|-------------|
| **Configure Automatic Updates** | Windows Update | `HKLM\...\WindowsUpdate\AU\AUOptions` | 2-7 | Master control for automatic updates |
| **Specify intranet Microsoft update service location** | Windows Update | `HKLM\...\WindowsUpdate\WUServer` | URL string | WSUS server address |
| **Enable client-side targeting** | Windows Update | `HKLM\...\WindowsUpdate\AU\TargetGroup` | Group name | WSUS computer group assignment |
| **Automatic Updates detection frequency** | Windows Update | `HKLM\...\WindowsUpdate\AU\DetectionFrequency` | 1-22 hours | Update check interval |
| **No auto-restart with logged on users** | Windows Update | `HKLM\...\WindowsUpdate\AU\NoAutoRebootWithLoggedOnUsers` | 0/1 | Prevent auto restart if users logged in |
| **Always automatically restart at scheduled time** | Windows Update | `HKLM\...\WindowsUpdate\AU\AlwaysAutoRebootAtScheduledTime` | 0/1 | Force restart with countdown timer |
| **Specify deadlines for automatic updates** | Windows Update | `HKLM\...\WindowsUpdate\ComplianceDeadline` | 2-30 days | Compliance deadline enforcement |
| **Configure active hours** | Windows Update | `HKLM\...\WindowsUpdate\ActiveHoursStart/End` | 0-23 | Prevent restarts during active hours |
| **Select when Quality Updates are received** | WU for Business | `HKLM\...\WindowsUpdate\DeferQualityUpdates` | 0-30 days | Quality update deferral period |
| **Select when Feature Updates are received** | WU for Business | `HKLM\...\WindowsUpdate\DeferFeatureUpdates` | 0-365 days | Feature update deferral period |

### AUOptions Values Explained

| Value | Behavior | Best For |
|-------|----------|----------|
| **2** | Notify for download and auto install | Interactive servers (rare) |
| **3** | Auto download and notify for install | Domain Controllers, Critical SQL Servers |
| **4** | Auto download and schedule the install | Standard member servers |
| **5** | Allow local admin to choose setting | Distributed/remote management |
| **7** | Auto download, notify to install, notify to restart | Windows Server 2016+ (granular control) |

**Recommendation:** Use **3** for DCs, **4** for member servers, **7** for maximum control with notifications.

---

## Patch Management Strategy

### Enterprise Patch Management Workflow

```
┌──────────────────────────────────────────────────────────────┐
│ Phase 1: PATCH RELEASE (Microsoft Patch Tuesday)            │
│  - 2nd Tuesday of every month                                │
│  - Download to WSUS server                                   │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│ Phase 2: WSUS APPROVAL (Tuesday-Thursday)                    │
│  - Review patch metadata and KB articles                     │
│  - Approve for test/dev rings only                           │
│  - Decline superseded and non-applicable updates             │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│ Phase 3: TEST/DEV DEPLOYMENT (Week 1)                        │
│  - Ring 0 (Pilot): Friday-Sunday (0-day deferral)            │
│  - Monitor for issues, application compatibility             │
│  - Validate critical services post-patch                     │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│ Phase 4: STAGED PRODUCTION (Week 2-3)                        │
│  - Ring 1 (Fast): Wednesday-Saturday (7-day deferral)        │
│  - Ring 2 (Slow): Wednesday-Saturday (14-day deferral)       │
│  - Ring 3 (Critical): Manual approval (21-30 day deferral)   │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│ Phase 5: VALIDATION AND REPORTING                            │
│  - Compliance reports from WSUS                              │
│  - Failed installation remediation                           │
│  - Update inventory and documentation                        │
└──────────────────────────────────────────────────────────────┘
```

### Critical vs Non-Critical Updates

| Update Type | Severity | Deferral | Compliance Deadline |
|-------------|----------|----------|---------------------|
| **Critical Security** | Critical | 0-7 days max | 7 days |
| **Important Security** | Important | 7-14 days | 14 days |
| **Quality Updates** | Moderate | 14-30 days | 30 days |
| **Feature Updates** | Optional | 30-365 days | Not enforced |
| **Drivers** | Varies | Excluded (manual) | N/A |

---

## Ring Deployment Model

### Recommended Ring Structure

```
┌─────────────────────────────────────────────────────────────┐
│ RING 0: PILOT (0-Day Deferral)                              │
│  - 5-10% of infrastructure                                  │
│  - Test/dev servers                                         │
│  - Non-critical infrastructure servers                      │
│  - IT staff workstations                                    │
│                                                              │
│  Install Schedule: Friday 11:00 PM                          │
│  Target Group: Ring0-Pilot                                  │
└─────────────────────────────────────────────────────────────┘
                            ↓ (7 days validation)
┌─────────────────────────────────────────────────────────────┐
│ RING 1: FAST (7-Day Deferral)                               │
│  - 30% of infrastructure                                    │
│  - General file servers                                     │
│  - Print servers                                            │
│  - Standard application servers                             │
│                                                              │
│  Install Schedule: Wednesday 2:00 AM                        │
│  Target Group: Ring1-Fast                                   │
└─────────────────────────────────────────────────────────────┘
                            ↓ (7 days validation)
┌─────────────────────────────────────────────────────────────┐
│ RING 2: SLOW (14-Day Deferral)                              │
│  - 50% of infrastructure                                    │
│  - Production web servers (with load balancer)              │
│  - Secondary database servers                               │
│  - VDI infrastructure                                       │
│                                                              │
│  Install Schedule: Wednesday 3:00 AM                        │
│  Target Group: Ring2-Slow                                   │
└─────────────────────────────────────────────────────────────┘
                            ↓ (manual approval)
┌─────────────────────────────────────────────────────────────┐
│ RING 3: CRITICAL (Manual/30-Day Deferral)                   │
│  - 5-10% of infrastructure                                  │
│  - Domain Controllers                                       │
│  - Primary database servers (SQL Always On, Oracle RAC)     │
│  - Business-critical applications                           │
│  - Production SAP/ERP systems                               │
│                                                              │
│  Install Schedule: Maintenance window (manual)              │
│  Target Group: Ring3-Critical                               │
└─────────────────────────────────────────────────────────────┘
```

### Ring Assignment Strategy

**Assign servers to rings based on:**

1. **Business Impact** - Higher impact = higher ring number (later deployment)
2. **Availability Requirements** - 24/7 systems need controlled deployment
3. **Change Windows** - Systems with maintenance windows = Ring 3
4. **Redundancy** - Systems with HA/DR pairs can be split across rings
5. **Application Dependencies** - Deploy dependent systems together

---

## WSUS Integration

### Required GPO Settings for WSUS

#### Setting 1: Specify Intranet Microsoft Update Service Location

**Path:** `Computer Configuration > Administrative Templates > Windows Components > Windows Update`

**Setting:** `Specify intranet Microsoft update service location`

**Configuration:**
```
Status: Enabled

Set the intranet update service for detecting updates:
    https://wsus-server.company.local:8531

Set the intranet statistics server:
    https://wsus-server.company.local:8531

Set the alternate download server (optional):
    (Leave blank for default WSUS download)
```

**Registry Values:**
```
HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate
    WUServer (String) = "https://wsus-server.company.local:8531"
    WUStatusServer (String) = "https://wsus-server.company.local:8531"

HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU
    UseWUServer (DWORD) = 1
```

**Notes:**
- Use `http://` and port `8530` for non-SSL WSUS
- Use `https://` and port `8531` for SSL WSUS (recommended)
- Statistics server can be same as update server

#### Setting 2: Enable Client-Side Targeting

**Path:** `Computer Configuration > Administrative Templates > Windows Components > Windows Update`

**Setting:** `Enable client-side targeting`

**Configuration:**
```
Status: Enabled

Target group name for this computer:
    Ring1-Fast
```

**Registry Value:**
```
HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU
    TargetGroup (String) = "Ring1-Fast"
    TargetGroupEnabled (DWORD) = 1
```

**Group Naming Convention:**
```
Ring0-Pilot
Ring1-Fast
Ring2-Slow
Ring3-Critical-DC
Ring3-Critical-SQL
Ring3-Critical-SAP
```

#### Setting 3: Do Not Connect to Windows Update Internet Locations

**Path:** `Computer Configuration > Administrative Templates > Windows Components > Windows Update`

**Setting:** `Do not connect to any Windows Update Internet locations`

**Configuration:**
```
Status: Enabled
```

**Purpose:** Blocks Windows Update and Microsoft Store connections when WSUS is configured, enforcing all updates through WSUS only.

#### Setting 4: Automatic Updates Detection Frequency

**Path:** `Computer Configuration > Administrative Templates > Windows Components > Windows Update`

**Setting:** `Automatic Updates detection frequency`

**Configuration:**
```
Status: Enabled

Check for updates at the following interval (hours): 4
```

**Registry Value:**
```
HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU
    DetectionFrequency (DWORD) = 4
    DetectionFrequencyEnabled (DWORD) = 1
```

**Recommendation:** 4-8 hours for servers, 22 hours maximum

---

## Automatic Updates Configuration

### GPO: Domain Controllers Update Policy

**GPO Name:** `C-PATCH-DomainControllers`

**Settings:**

| Setting | Value | Rationale |
|---------|-------|-----------|
| Configure Automatic Updates | Enabled | Enable update management |
| Configure automatic updating | **3** - Auto download and notify for install | Prevent automatic installation |
| No auto-restart with logged on users | **Enabled** | Never auto-reboot DCs |
| Do not connect to any Windows Update Internet locations | Enabled | Force WSUS usage |
| Specify intranet Microsoft update service location | `https://wsus.company.local:8531` | WSUS server |
| Enable client-side targeting | `Ring3-Critical-DC` | WSUS group assignment |

**PowerShell Configuration:**

```powershell
# Create Domain Controller update GPO
$DCGPO = New-GPO -Name "C-PATCH-DomainControllers" -Comment "Windows Update configuration for Domain Controllers - Manual installation only"

# Configure Automatic Updates - Option 3 (Notify only)
Set-GPRegistryValue -Name $DCGPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "AUOptions" -Type DWord -Value 3

Set-GPRegistryValue -Name $DCGPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "NoAutoUpdate" -Type DWord -Value 0

# Prevent auto-reboot
Set-GPRegistryValue -Name $DCGPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "NoAutoRebootWithLoggedOnUsers" -Type DWord -Value 1

# WSUS configuration
Set-GPRegistryValue -Name $DCGPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "WUServer" -Type String -Value "https://wsus.company.local:8531"

Set-GPRegistryValue -Name $DCGPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "WUStatusServer" -Type String -Value "https://wsus.company.local:8531"

Set-GPRegistryValue -Name $DCGPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "UseWUServer" -Type DWord -Value 1

# Client-side targeting
Set-GPRegistryValue -Name $DCGPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "TargetGroup" -Type String -Value "Ring3-Critical-DC"

Set-GPRegistryValue -Name $DCGPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "TargetGroupEnabled" -Type DWord -Value 1
```

### GPO: Member Servers Update Policy (Ring 1 - Fast)

**GPO Name:** `C-PATCH-MemberServers-Ring1`

**Settings:**

| Setting | Value | Rationale |
|---------|-------|-----------|
| Configure Automatic Updates | Enabled | Enable update management |
| Configure automatic updating | **4** - Auto download and schedule install | Automated installation |
| Scheduled install day | **4** (Wednesday) | Mid-week deployment |
| Scheduled install time | **2** (2:00 AM) | Off-hours installation |
| Always automatically restart at scheduled time | Enabled (15 minutes) | Force restart with timer |
| Active hours | 6:00 AM - 10:00 PM | Prevent daytime restarts |
| Quality update deferral | **7 days** | Ring 1 staging period |
| Enable client-side targeting | `Ring1-Fast` | WSUS group assignment |

**PowerShell Configuration:**

```powershell
# Create Ring1 Member Server update GPO
$Ring1GPO = New-GPO -Name "C-PATCH-MemberServers-Ring1" -Comment "Windows Update configuration for Ring1 servers - Auto install Wednesday 2 AM"

# Configure Automatic Updates - Option 4 (Auto install on schedule)
Set-GPRegistryValue -Name $Ring1GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "AUOptions" -Type DWord -Value 4

# Scheduled install day (4 = Wednesday)
Set-GPRegistryValue -Name $Ring1GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "ScheduledInstallDay" -Type DWord -Value 4

# Scheduled install time (2 = 2:00 AM)
Set-GPRegistryValue -Name $Ring1GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "ScheduledInstallTime" -Type DWord -Value 2

# Force auto-reboot with 15-minute timer
Set-GPRegistryValue -Name $Ring1GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "AlwaysAutoRebootAtScheduledTime" -Type DWord -Value 1

Set-GPRegistryValue -Name $Ring1GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "AlwaysAutoRebootAtScheduledTimeMinutes" -Type DWord -Value 15

# Configure active hours (6 AM - 10 PM)
Set-GPRegistryValue -Name $Ring1GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "SetActiveHours" -Type DWord -Value 1

Set-GPRegistryValue -Name $Ring1GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "ActiveHoursStart" -Type DWord -Value 6

Set-GPRegistryValue -Name $Ring1GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "ActiveHoursEnd" -Type DWord -Value 22

# Quality update deferral (7 days)
Set-GPRegistryValue -Name $Ring1GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "DeferQualityUpdates" -Type DWord -Value 1

Set-GPRegistryValue -Name $Ring1GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "DeferQualityUpdatesPeriodInDays" -Type DWord -Value 7

# WSUS configuration
Set-GPRegistryValue -Name $Ring1GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "WUServer" -Type String -Value "https://wsus.company.local:8531"

Set-GPRegistryValue -Name $Ring1GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "WUStatusServer" -Type String -Value "https://wsus.company.local:8531"

Set-GPRegistryValue -Name $Ring1GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "UseWUServer" -Type DWord -Value 1

# Client-side targeting
Set-GPRegistryValue -Name $Ring1GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "TargetGroup" -Type String -Value "Ring1-Fast"

Set-GPRegistryValue -Name $Ring1GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "TargetGroupEnabled" -Type DWord -Value 1
```

---

## Maintenance Windows and Scheduling

### Scheduled Installation Days

| Value | Day | Recommended For |
|-------|-----|-----------------|
| **0** | Every day | Test/dev servers |
| **1** | Sunday | Pilot ring servers |
| **2** | Monday | Early week deployment |
| **3** | Tuesday | Post-Patch Tuesday testing |
| **4** | Wednesday | Production ring 1 (common choice) |
| **5** | Thursday | Production ring 2 |
| **6** | Friday | Avoid (weekend support issues) |
| **7** | Saturday | Web servers (low weekend traffic) |

### Install Time Configuration

**24-Hour Format:**
- `0` = Midnight (12:00 AM)
- `2` = 2:00 AM (common choice - off-hours)
- `3` = 3:00 AM (database servers, stagger from ring 1)
- `4` = 4:00 AM (application servers)
- `22` = 10:00 PM (evening maintenance window)

**Best Practices:**

1. **Stagger install times** by server role:
   ```
   Ring1 File Servers:     Wednesday 2:00 AM
   Ring1 Web Servers:      Wednesday 3:00 AM
   Ring1 App Servers:      Wednesday 4:00 AM
   ```

2. **Avoid midnight** (backup jobs, scheduled tasks)

3. **Consider time zones** for multi-region deployments

4. **Coordinate with monitoring** - suppress alerts during maintenance windows

### Maintenance Scheduler Settings

**Path:** `Computer Configuration > Administrative Templates > Windows Components > Maintenance Scheduler`

| Setting | Value | Description |
|---------|-------|-------------|
| **Automatic Maintenance Activation Boundary** | 2:00 AM | Daily maintenance start time |
| **Automatic Maintenance Random Delay** | PT4H (4 hours) | Randomize start within 4 hours |
| **Automatic Maintenance WakeUp Policy** | Enabled | Wake from sleep for maintenance |

**Example Configuration:**
```powershell
# Set maintenance window to start at 2 AM with 4-hour random delay
Set-GPRegistryValue -Name "C-PATCH-MemberServers-Ring1" `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\Maintenance" `
    -ValueName "MaintenanceStartTime" -Type String -Value "02:00"

Set-GPRegistryValue -Name "C-PATCH-MemberServers-Ring1" `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\Maintenance" `
    -ValueName "RandomDelay" -Type String -Value "PT4H"
```

---

## Reboot Management

### Reboot Behavior Settings

| Setting | Purpose | Recommended Value |
|---------|---------|-------------------|
| **No auto-restart with logged on users** | Prevent restart if users signed in | Enabled (servers) |
| **Always automatically restart at scheduled time** | Force restart with countdown timer | Enabled with 15-minute warning |
| **Configure active hours** | Block restarts during business hours | 6 AM - 10 PM |
| **Delay Restart for scheduled installations** | Minutes before restart attempt | 15 minutes |
| **Re-prompt for restart** | Reminder interval | 10 minutes |

### Active Hours Configuration

**Maximum Range:** 18 hours

**Recommended Configurations:**

| Server Type | Active Hours | Rationale |
|-------------|--------------|-----------|
| **Business Hours Servers** | 6 AM - 10 PM (16 hours) | Standard business + evening |
| **24/7 Production** | Not applicable | Use scheduled maintenance windows |
| **Development** | 8 AM - 6 PM (10 hours) | Developer working hours |

**PowerShell Example:**
```powershell
# Configure active hours 6 AM - 10 PM
Set-GPRegistryValue -Name "C-PATCH-MemberServers-Ring1" `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "SetActiveHours" -Type DWord -Value 1

Set-GPRegistryValue -Name "C-PATCH-MemberServers-Ring1" `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "ActiveHoursStart" -Type DWord -Value 6

Set-GPRegistryValue -Name "C-PATCH-MemberServers-Ring1" `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "ActiveHoursEnd" -Type DWord -Value 22
```

### Compliance Deadlines (Windows Server 2022+)

**Path:** `Computer Configuration > Administrative Templates > Windows Components > Windows Update > Specify deadlines for automatic updates and restarts`

**Configuration:**
```
Quality update deadline: 7 days
Feature update deadline: 14 days
Grace period: 3 days
Don't auto-restart until end of grace period: Enabled
```

**How Deadlines Work:**

1. Update becomes available
2. Deferral period passes (if configured)
3. Compliance deadline starts counting (e.g., 7 days)
4. After deadline, grace period begins (e.g., 3 days)
5. After grace period expires, forced restart occurs

**PowerShell Example:**
```powershell
# Configure compliance deadlines
Set-GPRegistryValue -Name "C-PATCH-MemberServers-Ring1" `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "ComplianceDeadline" -Type DWord -Value 7

Set-GPRegistryValue -Name "C-PATCH-MemberServers-Ring1" `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "ConfigureDeadlineGracePeriod" -Type DWord -Value 3

Set-GPRegistryValue -Name "C-PATCH-MemberServers-Ring1" `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "ConfigureDeadlineNoAutoReboot" -Type DWord -Value 1
```

---

## Update Deferral Policies

### Quality Update Deferral

**Purpose:** Delay installation of monthly cumulative updates

**Path:** `Computer Configuration > Administrative Templates > Windows Components > Windows Update > Windows Update for Business > Select when Quality Updates are received`

**Deferral Ranges:**
- Minimum: 0 days (immediate)
- Maximum: 30 days
- Recommended: 7-14 days for production

**Configuration by Ring:**

| Ring | Deferral Period | Install After Patch Tuesday |
|------|-----------------|------------------------------|
| **Ring 0 (Pilot)** | 0 days | Tuesday (same day) |
| **Ring 1 (Fast)** | 7 days | Following Tuesday |
| **Ring 2 (Slow)** | 14 days | 2 weeks later |
| **Ring 3 (Critical)** | 21-30 days | 3-4 weeks later |

**PowerShell Example:**
```powershell
# Ring1: 7-day quality update deferral
Set-GPRegistryValue -Name "C-PATCH-MemberServers-Ring1" `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "DeferQualityUpdates" -Type DWord -Value 1

Set-GPRegistryValue -Name "C-PATCH-MemberServers-Ring1" `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "DeferQualityUpdatesPeriodInDays" -Type DWord -Value 7

# Ring2: 14-day quality update deferral
Set-GPRegistryValue -Name "C-PATCH-MemberServers-Ring2" `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "DeferQualityUpdatesPeriodInDays" -Type DWord -Value 14
```

### Feature Update Deferral

**Purpose:** Delay installation of major Windows versions (semi-annual releases)

**Path:** `Computer Configuration > Administrative Templates > Windows Components > Windows Update > Windows Update for Business > Select when Preview Builds and Feature Updates are received`

**Deferral Ranges:**
- Minimum: 0 days
- Maximum: 365 days
- Recommended: 180-365 days for servers (Windows Server LTSC model)

**Configuration:**

| Server Type | Feature Update Deferral | Rationale |
|-------------|-------------------------|-----------|
| **Test/Dev** | 0-30 days | Early testing |
| **Production** | 180-365 days | Stability, stay on LTSC |
| **Critical** | 365 days (max) | Avoid feature updates entirely |

**PowerShell Example:**
```powershell
# Defer feature updates for 365 days (effectively disable)
Set-GPRegistryValue -Name "C-PATCH-MemberServers-Ring1" `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "DeferFeatureUpdates" -Type DWord -Value 1

Set-GPRegistryValue -Name "C-PATCH-MemberServers-Ring1" `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "DeferFeatureUpdatesPeriodInDays" -Type DWord -Value 365
```

### Pause Updates

**Temporary Freeze:** Pause updates for up to 35 days during critical business periods

**Use Cases:**
- Freeze period (year-end, major events)
- Incident response and remediation
- Major application deployment windows
- Mergers and acquisitions

**PowerShell Example:**
```powershell
# Pause quality updates for 35 days
Set-GPRegistryValue -Name "C-PATCH-MemberServers-Ring1" `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "PauseQualityUpdatesStartTime" -Type String -Value (Get-Date -Format "yyyy-MM-dd")
```

---

## Role-Based Patch Schedules

### Domain Controllers

**Critical Considerations:**
- **NEVER auto-install** - Use notify mode only
- **Patch one DC at a time** - Allow 24-48 hours between DCs
- **Verify AD replication** before proceeding to next DC
- **Patch FSMO role holders last**

**GPO Configuration:**

```powershell
$DCGPO = "C-PATCH-DomainControllers"

Set-GPRegistryValue -Name $DCGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "AUOptions" -Type DWord -Value 3  # Notify only

Set-GPRegistryValue -Name $DCGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "NoAutoRebootWithLoggedOnUsers" -Type DWord -Value 1  # Never auto-reboot

Set-GPRegistryValue -Name $DCGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "TargetGroup" -Type String -Value "Ring3-Critical-DC"
```

**Manual Patching Procedure:**
1. Verify all DCs are healthy: `dcdiag /a`
2. Check replication status: `repadmin /replsummary`
3. Patch non-FSMO DCs first
4. Wait 24 hours, verify replication
5. Patch FSMO role holders
6. Final replication check

---

### SQL Server / Database Servers

**Critical Considerations:**
- **Coordinate with DBA team** - May require SQL maintenance plans
- **Test on secondary replicas first** (Always On Availability Groups)
- **Validate database connectivity** post-patch
- **Schedule during maintenance windows**

**GPO Configuration:**

```powershell
$SQLGPO = "C-PATCH-DatabaseServers"

Set-GPRegistryValue -Name $SQLGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "AUOptions" -Type DWord -Value 3  # Notify only (manual installation)

Set-GPRegistryValue -Name $SQLGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "NoAutoRebootWithLoggedOnUsers" -Type DWord -Value 1  # Never auto-reboot

Set-GPRegistryValue -Name $SQLGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "DeferQualityUpdatesPeriodInDays" -Type DWord -Value 14

Set-GPRegistryValue -Name $SQLGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "TargetGroup" -Type String -Value "Ring3-Critical-SQL"
```

**Patching Sequence for SQL Always On:**
1. Patch secondary replica
2. Fail over to patched secondary
3. Patch former primary (now secondary)
4. Fail back if desired

---

### File Servers / Print Servers

**Considerations:**
- **Low risk** - Good candidates for early deployment rings
- **Schedule during off-hours** to minimize user impact
- **Can tolerate auto-restart** with proper notification

**GPO Configuration:**

```powershell
$FileServerGPO = "C-PATCH-FileServers"

Set-GPRegistryValue -Name $FileServerGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "AUOptions" -Type DWord -Value 4  # Auto install on schedule

Set-GPRegistryValue -Name $FileServerGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "ScheduledInstallDay" -Type DWord -Value 4  # Wednesday

Set-GPRegistryValue -Name $FileServerGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "ScheduledInstallTime" -Type DWord -Value 2  # 2:00 AM

Set-GPRegistryValue -Name $FileServerGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "AlwaysAutoRebootAtScheduledTime" -Type DWord -Value 1

Set-GPRegistryValue -Name $FileServerGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "AlwaysAutoRebootAtScheduledTimeMinutes" -Type DWord -Value 15

Set-GPRegistryValue -Name $FileServerGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "DeferQualityUpdatesPeriodInDays" -Type DWord -Value 7

Set-GPRegistryValue -Name $FileServerGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "TargetGroup" -Type String -Value "Ring1-Fast"
```

---

### Web Servers (IIS)

**Considerations:**
- **Use load balancer** for rolling patching
- **Remove from pool before patching** (health check)
- **Validate application after restart**

**GPO Configuration:**

```powershell
$WebServerGPO = "C-PATCH-WebServers"

Set-GPRegistryValue -Name $WebServerGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "AUOptions" -Type DWord -Value 4

Set-GPRegistryValue -Name $WebServerGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "ScheduledInstallDay" -Type DWord -Value 7  # Saturday (low web traffic)

Set-GPRegistryValue -Name $WebServerGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
    -ValueName "ScheduledInstallTime" -Type DWord -Value 3  # 3:00 AM

Set-GPRegistryValue -Name $WebServerGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "DeferQualityUpdatesPeriodInDays" -Type DWord -Value 7

Set-GPRegistryValue -Name $WebServerGPO -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" `
    -ValueName "TargetGroup" -Type String -Value "Ring2-Slow"
```

**Recommended Patching Script (with LB integration):**
```powershell
# Remove from load balancer pool
Invoke-RestMethod -Uri "http://loadbalancer/api/pool/remove/WEB01" -Method POST

# Install updates
Install-WindowsUpdate -AcceptAll -AutoReboot

# Wait for server to come online
Start-Sleep -Seconds 300

# Validate IIS
if ((Get-Service W3SVC).Status -eq 'Running') {
    # Re-add to load balancer pool
    Invoke-RestMethod -Uri "http://loadbalancer/api/pool/add/WEB01" -Method POST
}
```

---

## PowerShell Deployment Scripts

### Create All Patch Management GPOs

```powershell
#Requires -Modules GroupPolicy
<#
.SYNOPSIS
    Create Windows Update GPOs for all deployment rings
.DESCRIPTION
    Creates standardized Windows Update GPOs for Domain Controllers and Member Servers
    across multiple deployment rings with WSUS integration
.NOTES
    Run on Domain Controller with RSAT-AD-PowerShell and GPMC installed
#>

param(
    [string]$WSUSServer = "https://wsus.company.local:8531",
    [string]$DomainDN = (Get-ADDomain).DistinguishedName
)

# Function to create Windows Update GPO
function New-WindowsUpdateGPO {
    param(
        [Parameter(Mandatory)]
        [string]$GPOName,

        [Parameter(Mandatory)]
        [string]$Comment,

        [Parameter(Mandatory)]
        [hashtable]$Settings
    )

    Write-Host "Creating GPO: $GPOName" -ForegroundColor Cyan

    # Create GPO
    $GPO = New-GPO -Name $GPOName -Comment $Comment

    # Apply settings
    foreach ($Setting in $Settings.GetEnumerator()) {
        $KeyPath = $Setting.Value.Key
        $ValueName = $Setting.Value.Name
        $ValueType = $Setting.Value.Type
        $Value = $Setting.Value.Value

        Set-GPRegistryValue -Name $GPOName -Key $KeyPath -ValueName $ValueName -Type $ValueType -Value $Value | Out-Null
    }

    Write-Host "  ✓ Created: $GPOName" -ForegroundColor Green
    return $GPO
}

# Define WSUS base settings (applied to all GPOs)
$WSUSSettings = @{
    WUServer = @{
        Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        Name = "WUServer"
        Type = "String"
        Value = $WSUSServer
    }
    WUStatusServer = @{
        Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        Name = "WUStatusServer"
        Type = "String"
        Value = $WSUSServer
    }
    UseWUServer = @{
        Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        Name = "UseWUServer"
        Type = "DWord"
        Value = 1
    }
    DisableWindowsUpdateAccess = @{
        Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        Name = "DisableWindowsUpdateAccess"
        Type = "DWord"
        Value = 1
    }
    TargetGroupEnabled = @{
        Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        Name = "TargetGroupEnabled"
        Type = "DWord"
        Value = 1
    }
}

# Domain Controllers GPO
$DCSettings = $WSUSSettings.Clone()
$DCSettings += @{
    TargetGroup = @{
        Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        Name = "TargetGroup"
        Type = "String"
        Value = "Ring3-Critical-DC"
    }
    AUOptions = @{
        Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        Name = "AUOptions"
        Type = "DWord"
        Value = 3  # Notify only
    }
    NoAutoRebootWithLoggedOnUsers = @{
        Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        Name = "NoAutoRebootWithLoggedOnUsers"
        Type = "DWord"
        Value = 1
    }
    NoAutoUpdate = @{
        Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        Name = "NoAutoUpdate"
        Type = "DWord"
        Value = 0
    }
}

New-WindowsUpdateGPO -GPOName "C-PATCH-DomainControllers" `
    -Comment "Windows Update configuration for Domain Controllers - Manual installation only" `
    -Settings $DCSettings

# Ring 0 - Pilot (0-day deferral, Friday 11 PM)
$Ring0Settings = $WSUSSettings.Clone()
$Ring0Settings += @{
    TargetGroup = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "TargetGroup"; Type = "String"; Value = "Ring0-Pilot" }
    AUOptions = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AUOptions"; Type = "DWord"; Value = 4 }
    ScheduledInstallDay = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "ScheduledInstallDay"; Type = "DWord"; Value = 6 }  # Friday
    ScheduledInstallTime = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "ScheduledInstallTime"; Type = "DWord"; Value = 23 }  # 11 PM
    AlwaysAutoRebootAtScheduledTime = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AlwaysAutoRebootAtScheduledTime"; Type = "DWord"; Value = 1 }
    AlwaysAutoRebootAtScheduledTimeMinutes = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AlwaysAutoRebootAtScheduledTimeMinutes"; Type = "DWord"; Value = 15 }
    DeferQualityUpdates = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "DeferQualityUpdates"; Type = "DWord"; Value = 1 }
    DeferQualityUpdatesPeriodInDays = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "DeferQualityUpdatesPeriodInDays"; Type = "DWord"; Value = 0 }
}

New-WindowsUpdateGPO -GPOName "C-PATCH-MemberServers-Ring0" `
    -Comment "Windows Update for Pilot servers - 0-day deferral, Friday 11 PM installation" `
    -Settings $Ring0Settings

# Ring 1 - Fast (7-day deferral, Wednesday 2 AM)
$Ring1Settings = $WSUSSettings.Clone()
$Ring1Settings += @{
    TargetGroup = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "TargetGroup"; Type = "String"; Value = "Ring1-Fast" }
    AUOptions = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AUOptions"; Type = "DWord"; Value = 4 }
    ScheduledInstallDay = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "ScheduledInstallDay"; Type = "DWord"; Value = 4 }  # Wednesday
    ScheduledInstallTime = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "ScheduledInstallTime"; Type = "DWord"; Value = 2 }  # 2 AM
    AlwaysAutoRebootAtScheduledTime = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AlwaysAutoRebootAtScheduledTime"; Type = "DWord"; Value = 1 }
    AlwaysAutoRebootAtScheduledTimeMinutes = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AlwaysAutoRebootAtScheduledTimeMinutes"; Type = "DWord"; Value = 15 }
    DeferQualityUpdates = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "DeferQualityUpdates"; Type = "DWord"; Value = 1 }
    DeferQualityUpdatesPeriodInDays = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "DeferQualityUpdatesPeriodInDays"; Type = "DWord"; Value = 7 }
    ActiveHoursStart = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "ActiveHoursStart"; Type = "DWord"; Value = 6 }
    ActiveHoursEnd = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "ActiveHoursEnd"; Type = "DWord"; Value = 22 }
    SetActiveHours = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "SetActiveHours"; Type = "DWord"; Value = 1 }
}

New-WindowsUpdateGPO -GPOName "C-PATCH-MemberServers-Ring1" `
    -Comment "Windows Update for Ring1 servers - 7-day deferral, Wednesday 2 AM installation" `
    -Settings $Ring1Settings

# Ring 2 - Slow (14-day deferral, Wednesday 3 AM)
$Ring2Settings = $WSUSSettings.Clone()
$Ring2Settings += @{
    TargetGroup = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "TargetGroup"; Type = "String"; Value = "Ring2-Slow" }
    AUOptions = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AUOptions"; Type = "DWord"; Value = 4 }
    ScheduledInstallDay = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "ScheduledInstallDay"; Type = "DWord"; Value = 4 }  # Wednesday
    ScheduledInstallTime = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "ScheduledInstallTime"; Type = "DWord"; Value = 3 }  # 3 AM
    AlwaysAutoRebootAtScheduledTime = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AlwaysAutoRebootAtScheduledTime"; Type = "DWord"; Value = 1 }
    AlwaysAutoRebootAtScheduledTimeMinutes = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AlwaysAutoRebootAtScheduledTimeMinutes"; Type = "DWord"; Value = 15 }
    DeferQualityUpdates = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "DeferQualityUpdates"; Type = "DWord"; Value = 1 }
    DeferQualityUpdatesPeriodInDays = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "DeferQualityUpdatesPeriodInDays"; Type = "DWord"; Value = 14 }
    ActiveHoursStart = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "ActiveHoursStart"; Type = "DWord"; Value = 6 }
    ActiveHoursEnd = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "ActiveHoursEnd"; Type = "DWord"; Value = 22 }
    SetActiveHours = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "SetActiveHours"; Type = "DWord"; Value = 1 }
}

New-WindowsUpdateGPO -GPOName "C-PATCH-MemberServers-Ring2" `
    -Comment "Windows Update for Ring2 servers - 14-day deferral, Wednesday 3 AM installation" `
    -Settings $Ring2Settings

# Ring 3 - Critical (21-day deferral, manual approval)
$Ring3Settings = $WSUSSettings.Clone()
$Ring3Settings += @{
    TargetGroup = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "TargetGroup"; Type = "String"; Value = "Ring3-Critical" }
    AUOptions = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AUOptions"; Type = "DWord"; Value = 3 }  # Notify only
    NoAutoRebootWithLoggedOnUsers = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "NoAutoRebootWithLoggedOnUsers"; Type = "DWord"; Value = 1 }
    DeferQualityUpdates = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "DeferQualityUpdates"; Type = "DWord"; Value = 1 }
    DeferQualityUpdatesPeriodInDays = @{ Key = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "DeferQualityUpdatesPeriodInDays"; Type = "DWord"; Value = 21 }
}

New-WindowsUpdateGPO -GPOName "C-PATCH-MemberServers-Ring3" `
    -Comment "Windows Update for Ring3 critical servers - 21-day deferral, manual installation" `
    -Settings $Ring3Settings

Write-Host "`n✓ All Windows Update GPOs created successfully!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Link GPOs to appropriate OUs"
Write-Host "  2. Create WSUS computer groups matching ring names"
Write-Host "  3. Test GPO application with 'gpupdate /force' and 'gpresult /r'"
```

---

## Troubleshooting

### Issue: Updates Not Downloading

**Symptoms:**
- Windows Update shows "Checking for updates..." indefinitely
- `wuauclt /detectnow` has no effect

**Diagnosis:**
```powershell
# Check WSUS configuration
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

# Check Windows Update service
Get-Service wuauserv

# Review Windows Update event log
Get-WinEvent -LogName "System" -ProviderName "Microsoft-Windows-WindowsUpdateClient" -MaxEvents 50 | Format-Table TimeCreated, Message -AutoSize
```

**Solutions:**
1. Verify WSUS server is accessible:
   ```powershell
   Test-NetConnection -ComputerName wsus.company.local -Port 8531
   ```

2. Reset Windows Update components:
   ```powershell
   Stop-Service wuauserv
   Remove-Item C:\Windows\SoftwareDistribution -Recurse -Force
   Start-Service wuauserv
   wuauclt /detectnow
   ```

3. Force GPO update:
   ```powershell
   gpupdate /force
   ```

---

### Issue: Incorrect Computer Group in WSUS

**Symptoms:**
- Server appears in wrong WSUS group
- Target group setting not applying

**Diagnosis:**
```powershell
# Check configured target group
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "TargetGroup"

# Check WSUS registration
$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
$UpdateSearcher.ServerSelection
```

**Solution:**
```powershell
# Re-register with WSUS
Stop-Service wuauserv
wuauclt /resetauthorization /detectnow
Start-Service wuauserv

# Force re-registration
wuauclt /reportnow
```

---

### Issue: Updates Installing Outside Maintenance Window

**Symptoms:**
- Updates install during business hours despite schedule

**Diagnosis:**
```powershell
# Check active hours configuration
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" | Select-Object *Active*

# Check scheduled install settings
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" | Select-Object *Scheduled*
```

**Solution:**
- Verify GPO settings are correctly configured
- Ensure no conflicting local policies exist
- Check compliance deadline isn't forcing installation

---

## Additional Resources

### Official Microsoft Documentation

- [Configure Group Policy Settings for Automatic Updates](https://learn.microsoft.com/en-us/windows-server/administration/windows-server-update-services/deploy/4-configure-group-policy-settings-for-automatic-updates)
- [Windows Update for Business Group Policy Reference](https://learn.microsoft.com/en-us/windows/deployment/update/waas-wufb-group-policy)
- [Manage Device Restarts After Updates](https://learn.microsoft.com/en-us/windows/deployment/update/waas-restart)
- [Compliance Deadlines for Updates](https://learn.microsoft.com/en-us/windows/deployment/update/wufb-compliancedeadlines)

### Community Resources

- [r/sysadmin - Patch Tuesday Megathread](https://reddit.com/r/sysadmin)
- [Spiceworks WSUS Community](https://community.spiceworks.com/windows/wsus)
- [4sysops Windows Update Articles](https://4sysops.com/tag/windows-update/)

---

## Conclusion

Proper Windows Update Group Policy configuration is critical for:
- **Security**: Timely deployment of security patches
- **Stability**: Controlled rollouts with testing periods
- **Compliance**: Meeting patch management requirements
- **Availability**: Minimizing unplanned downtime

By implementing the ring deployment model with appropriate deferral periods, maintenance windows, and role-based schedules, you can maintain a secure and stable Windows Server infrastructure while minimizing business disruption.

---

**Document Version:** 1.0
**Last Updated:** 2025-12-25
**Next Review Date:** 2026-01-25
