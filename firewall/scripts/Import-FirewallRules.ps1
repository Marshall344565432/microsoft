<#
.SYNOPSIS
    Import Windows Defender Firewall rules from exported configuration.

.DESCRIPTION
    Imports firewall rules from JSON, WFW, or native export formats.
    Can merge with existing rules or replace completely.

.PARAMETER ImportPath
    Path to the import file (JSON or WFW format)

.PARAMETER Mode
    Import mode: Merge (add to existing) or Replace (remove all first). Default: Merge

.PARAMETER WhatIf
    Show what would be imported without making changes

.PARAMETER SkipProfileSettings
    Skip importing profile settings (only import rules)

.PARAMETER Backup
    Create backup of current firewall config before import. Default: True

.EXAMPLE
    .\Import-FirewallRules.ps1 -ImportPath C:\Backup\FirewallRules.json -Mode Merge

.EXAMPLE
    .\Import-FirewallRules.ps1 -ImportPath C:\Backup\FirewallConfig.wfw -Mode Replace -Backup

.EXAMPLE
    .\Import-FirewallRules.ps1 -ImportPath .\rules.json -WhatIf

.NOTES
    Author: Enterprise Security Team
    Version: 1.0
    Requires: PowerShell 5.1+, Run as Administrator
    Date: 2025-12-26
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [string]$ImportPath,

    [Parameter(Mandatory=$false)]
    [ValidateSet("Merge","Replace")]
    [string]$Mode = "Merge",

    [Parameter(Mandatory=$false)]
    [switch]$SkipProfileSettings,

    [Parameter(Mandatory=$false)]
    [switch]$Backup = $true
)

#Requires -Version 5.1
#Requires -RunAsAdministrator

# Configure error handling
$ErrorActionPreference = "Stop"

try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Firewall Rules Import Utility" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $ImportPath = Resolve-Path $ImportPath
    $FileExtension = [System.IO.Path]::GetExtension($ImportPath)

    Write-Host "Import File: $ImportPath" -ForegroundColor Green
    Write-Host "Import Mode: $Mode" -ForegroundColor Green
    Write-Host "Backup First: $Backup`n" -ForegroundColor Green

    # Step 1: Backup Current Configuration
    if ($Backup) {
        Write-Host "[1/5] Creating backup of current configuration..." -ForegroundColor Yellow

        $BackupPath = "$env:TEMP\Firewall-Backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').wfw"

        if ($PSCmdlet.ShouldProcess("Current firewall config", "Backup to $BackupPath")) {
            netsh advfirewall export $BackupPath | Out-Null
            Write-Host "  ✓ Backup created: $BackupPath" -ForegroundColor Green
        }
    } else {
        Write-Host "[1/5] Skipping backup (not recommended)" -ForegroundColor Yellow
    }

    # Step 2: Load Import Data
    Write-Host "`n[2/5] Loading import data..." -ForegroundColor Yellow

    $ImportData = $null
    $RulesToImport = @()

    if ($FileExtension -eq ".json") {
        $ImportData = Get-Content -Path $ImportPath -Raw | ConvertFrom-Json

        if ($ImportData.Rules) {
            $RulesToImport = $ImportData.Rules
        } else {
            # Direct JSON array of rules
            $RulesToImport = $ImportData
        }

        Write-Host "  ✓ Loaded $($RulesToImport.Count) rules from JSON" -ForegroundColor Green

    } elseif ($FileExtension -eq ".wfw") {
        Write-Host "  Using native WFW import (netsh)" -ForegroundColor Gray

        if ($PSCmdlet.ShouldProcess("Firewall configuration", "Import from WFW")) {
            netsh advfirewall import $ImportPath
            Write-Host "  ✓ WFW import completed" -ForegroundColor Green
            Write-Host "`n✓ Import completed successfully!" -ForegroundColor Green
            return
        } else {
            Write-Host "  WhatIf: Would import from $ImportPath" -ForegroundColor Yellow
            return
        }

    } else {
        throw "Unsupported file format: $FileExtension (supported: .json, .wfw)"
    }

    # Step 3: Replace Mode - Remove Existing Rules
    if ($Mode -eq "Replace") {
        Write-Host "`n[3/5] Removing existing firewall rules (Replace mode)..." -ForegroundColor Yellow

        $ExistingRules = Get-NetFirewallRule

        if ($PSCmdlet.ShouldProcess("$($ExistingRules.Count) existing rules", "Remove")) {
            Write-Host "  Removing $($ExistingRules.Count) existing rules..." -ForegroundColor Gray
            $ExistingRules | Remove-NetFirewallRule -ErrorAction SilentlyContinue
            Write-Host "  ✓ Existing rules removed" -ForegroundColor Green
        } else {
            Write-Host "  WhatIf: Would remove $($ExistingRules.Count) rules" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n[3/5] Merge mode - keeping existing rules" -ForegroundColor Yellow
    }

    # Step 4: Import Rules
    Write-Host "`n[4/5] Importing rules..." -ForegroundColor Yellow

    $ImportedCount = 0
    $SkippedCount = 0
    $ErrorCount = 0

    foreach ($Rule in $RulesToImport) {
        try {
            # Check if rule already exists (in Merge mode)
            if ($Mode -eq "Merge") {
                $ExistingRule = Get-NetFirewallRule -DisplayName $Rule.DisplayName -ErrorAction SilentlyContinue

                if ($ExistingRule) {
                    Write-Host "  Skipping (exists): $($Rule.DisplayName)" -ForegroundColor Gray
                    $SkippedCount++
                    continue
                }
            }

            # Build New-NetFirewallRule parameters
            $RuleParams = @{
                DisplayName = $Rule.DisplayName
                Direction = $Rule.Direction
                Action = $Rule.Action
                Profile = $Rule.Profile
            }

            if ($Rule.Description) { $RuleParams['Description'] = $Rule.Description }
            if ($Rule.Group) { $RuleParams['Group'] = $Rule.Group }
            if ($Rule.Enabled -ne $null) { $RuleParams['Enabled'] = [System.Convert]::ToBoolean($Rule.Enabled) }
            if ($Rule.Protocol) { $RuleParams['Protocol'] = $Rule.Protocol }

            # Port filter
            if ($Rule.LocalPort -and $Rule.LocalPort -ne '') {
                $RuleParams['LocalPort'] = $Rule.LocalPort -split ','
            }
            if ($Rule.RemotePort -and $Rule.RemotePort -ne '') {
                $RuleParams['RemotePort'] = $Rule.RemotePort -split ','
            }

            # Address filter
            if ($Rule.LocalAddress -and $Rule.LocalAddress -ne '') {
                $RuleParams['LocalAddress'] = $Rule.LocalAddress -split ','
            }
            if ($Rule.RemoteAddress -and $Rule.RemoteAddress -ne '') {
                $RuleParams['RemoteAddress'] = $Rule.RemoteAddress -split ','
            }

            # Application filter
            if ($Rule.Program -and $Rule.Program -ne '') {
                $RuleParams['Program'] = $Rule.Program
            }

            # Service filter
            if ($Rule.Service -and $Rule.Service -ne '') {
                $RuleParams['Service'] = $Rule.Service
            }

            if ($PSCmdlet.ShouldProcess($Rule.DisplayName, "Create firewall rule")) {
                New-NetFirewallRule @RuleParams -ErrorAction Stop | Out-Null
                $ImportedCount++
                Write-Progress -Activity "Importing Rules" -Status "Imported $ImportedCount rules" -PercentComplete (($ImportedCount / $RulesToImport.Count) * 100)
            } else {
                Write-Host "  WhatIf: Would create $($Rule.DisplayName)" -ForegroundColor Yellow
            }

        } catch {
            Write-Host "  ⚠ Error importing '$($Rule.DisplayName)': $($_.Exception.Message)" -ForegroundColor Red
            $ErrorCount++
        }
    }

    Write-Progress -Activity "Importing Rules" -Completed
    Write-Host "  ✓ Imported $ImportedCount rules" -ForegroundColor Green

    if ($SkippedCount -gt 0) {
        Write-Host "  ⊘ Skipped $SkippedCount existing rules" -ForegroundColor Yellow
    }

    if ($ErrorCount -gt 0) {
        Write-Host "  ⚠ Failed to import $ErrorCount rules" -ForegroundColor Red
    }

    # Step 5: Import Profile Settings
    if (-not $SkipProfileSettings -and $ImportData.PSObject.Properties.Name -contains 'ProfileSettings') {
        Write-Host "`n[5/5] Importing profile settings..." -ForegroundColor Yellow

        # Note: Profile settings import would go here
        # For now, we'll skip this as it requires careful handling
        Write-Host "  Profile settings import not yet implemented" -ForegroundColor Gray

    } else {
        Write-Host "`n[5/5] Skipping profile settings" -ForegroundColor Yellow
    }

    # Summary
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Import Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    Write-Host "Import File: $ImportPath" -ForegroundColor White
    Write-Host "Mode: $Mode" -ForegroundColor White
    Write-Host "Rules Imported: $ImportedCount" -ForegroundColor White
    Write-Host "Rules Skipped: $SkippedCount" -ForegroundColor White
    Write-Host "Errors: $ErrorCount" -ForegroundColor White

    if ($Backup) {
        Write-Host "Backup Location: $BackupPath" -ForegroundColor White
    }

    Write-Host "`n✓ Import completed!" -ForegroundColor Green

    if ($ErrorCount -gt 0) {
        Write-Host "`n⚠ Warning: Some rules failed to import. Review errors above." -ForegroundColor Yellow
    }

    Write-Host "`nNext Steps:" -ForegroundColor Yellow
    Write-Host "1. Verify rules: Get-NetFirewallRule | Where DisplayName -like '*'" -ForegroundColor Gray
    Write-Host "2. Test connectivity to required services" -ForegroundColor Gray
    Write-Host "3. Run Get-FirewallAuditBaseline.ps1 for compliance check" -ForegroundColor Gray

    if ($Backup) {
        Write-Host "4. If issues occur, restore from: $BackupPath" -ForegroundColor Gray
    }

} catch {
    Write-Host "`n❌ Error during import: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red

    if ($Backup -and (Test-Path $BackupPath)) {
        Write-Host "`n⚠ To restore backup, run:" -ForegroundColor Yellow
        Write-Host "  netsh advfirewall import `"$BackupPath`"" -ForegroundColor Gray
    }

    throw
}
