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
    Switch to apply settings without validation prompts

.EXAMPLE
    .\Set-CISFirewallBaseline.ps1 -ServerRole DomainController -AdminSubnet 192.168.1.0/24

.EXAMPLE
    .\Set-CISFirewallBaseline.ps1 -ServerRole WebServer -ApplyOnly

.NOTES
    Author: Enterprise Security Team
    Version: 1.0
    Requires: PowerShell 5.1+, Run as Administrator
    CIS Benchmark: Windows Server 2022 v2.0.0
    Date: 2025-12-26
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

    # Step 2: Remove Default Rules (optional)
    Write-Host "`n[2/5] Reviewing default firewall rules..." -ForegroundColor Yellow

    $DefaultRules = Get-NetFirewallRule | Where-Object {
        $_.DisplayName -notlike "*Core Networking*" -and
        $_.Group -ne "Remote Management" -and
        $_.DisplayName -notlike "CIS-FW-*"
    }

    Write-Host "  Found $($DefaultRules.Count) non-essential rules" -ForegroundColor Gray

    if (-not $ApplyOnly) {
        $Confirmation = Read-Host "  Remove default rules? (Y/N)"
        if ($Confirmation -ne 'Y') {
            Write-Host "  Skipping rule removal" -ForegroundColor Yellow
        } else {
            $DefaultRules | Remove-NetFirewallRule -ErrorAction SilentlyContinue
            Write-Host "  ✓ Default rules removed" -ForegroundColor Green
        }
    } else {
        Write-Host "  Skipping rule removal (use -ApplyOnly with caution)" -ForegroundColor Yellow
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

    Write-Host "  ✓ Core management rules created (6 rules)" -ForegroundColor Green

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
    Write-Host "4. Document any custom rules added`n" -ForegroundColor Gray

} catch {
    Write-Host "`n❌ Error during deployment: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    throw
} finally {
    Stop-Transcript
}
