<#
.SYNOPSIS
    Windows Firewall Audit Baseline for Windows Server 2022

.DESCRIPTION
    Performs comprehensive Windows Defender Firewall audit including:
    - Firewall profile status (Domain, Private, Public)
    - Inbound/Outbound firewall rules inventory
    - Enabled vs Disabled rules
    - Default action policies
    - IPSec configuration
    - Logging configuration
    - CIS benchmark compliance for firewall settings
    - Security risk analysis (overly permissive rules)

    Compatible with:
    - Windows Server 2022
    - PowerShell 5.1+

.PARAMETER OutputPath
    Path where the audit report will be saved. Default: C:\Audits\Firewall

.PARAMETER ExportFormat
    Report format: HTML, CSV, or JSON. Default: HTML

.PARAMETER IncludeRuleDetails
    Include detailed information for all firewall rules

.EXAMPLE
    .\Get-FirewallAuditBaseline.ps1
    Runs firewall audit with default settings

.EXAMPLE
    .\Get-FirewallAuditBaseline.ps1 -IncludeRuleDetails -ExportFormat JSON
    Runs full audit with rule details in JSON format

.NOTES
    Version:        1.0.0
    Author:         Enterprise Infrastructure Team
    Creation Date:  2025-12-25
    Purpose:        Firewall configuration audit and security baseline

    Requires:
    - Administrator privileges
    - PowerShell 5.1+
    - Windows Server 2022
    - NetSecurity module
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateScript({Test-Path $_ -PathType Container -IsValid})]
    [string]$OutputPath = "C:\Audits\Firewall",

    [Parameter(Mandatory=$false)]
    [ValidateSet('HTML','CSV','JSON')]
    [string]$ExportFormat = 'HTML',

    [Parameter(Mandatory=$false)]
    [switch]$IncludeRuleDetails
)

#Requires -RunAsAdministrator
#Requires -Version 5.1
#Requires -Modules NetSecurity

# Error handling
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script variables
$ScriptVersion = "1.0.0"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ComputerName = $env:COMPUTERNAME
$AuditResults = @{
    Profiles = @()
    Rules = @()
    SecurityRisks = @()
    Logging = @()
    IPSec = @()
    Summary = @{}
}

#region Logging Functions

function Write-AuditLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Info','Warning','Error','Success')]
        [string]$Level = 'Info'
    )

    $LogTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$LogTimestamp] [$Level] $Message"

    $Color = switch ($Level) {
        'Info'    { 'White' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        'Success' { 'Green' }
    }

    Write-Host $LogMessage -ForegroundColor $Color
}

#endregion

#region Firewall Audit Functions

function Get-FirewallProfileStatus {
    Write-AuditLog "Auditing firewall profile configurations..." -Level Info

    try {
        $Profiles = @('Domain', 'Private', 'Public')

        foreach ($ProfileName in $Profiles) {
            $Profile = Get-NetFirewallProfile -Name $ProfileName

            $Script:AuditResults.Profiles += [PSCustomObject]@{
                Profile = $ProfileName
                Enabled = $Profile.Enabled
                DefaultInboundAction = $Profile.DefaultInboundAction
                DefaultOutboundAction = $Profile.DefaultOutboundAction
                AllowInboundRules = $Profile.AllowInboundRules
                AllowLocalFirewallRules = $Profile.AllowLocalFirewallRules
                AllowLocalIPsecRules = $Profile.AllowLocalIPsecRules
                NotifyOnListen = $Profile.NotifyOnListen
                LogFileName = $Profile.LogFileName
                LogMaxSizeKilobytes = $Profile.LogMaxSizeKilobytes
                LogAllowed = $Profile.LogAllowed
                LogBlocked = $Profile.LogBlocked
                LogIgnored = $Profile.LogIgnored
                CISCompliant = ($Profile.Enabled -eq $true -and
                              $Profile.DefaultInboundAction -eq 'Block' -and
                              $Profile.LogBlocked -eq $true)
            }
        }

        $NonCompliantProfiles = $Script:AuditResults.Profiles | Where-Object { -not $_.CISCompliant }
        if ($NonCompliantProfiles.Count -gt 0) {
            Write-AuditLog "Found $($NonCompliantProfiles.Count) non-CIS compliant profiles" -Level Warning
        } else {
            Write-AuditLog "All firewall profiles are CIS compliant" -Level Success
        }

        return $true
    } catch {
        Write-AuditLog "Error auditing firewall profiles: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-FirewallRulesInventory {
    Write-AuditLog "Retrieving firewall rules inventory..." -Level Info

    try {
        $AllRules = Get-NetFirewallRule

        Write-AuditLog "Found $($AllRules.Count) total firewall rules" -Level Info

        foreach ($Rule in $AllRules) {
            try {
                # Get address filter
                $AddressFilter = $Rule | Get-NetFirewallAddressFilter
                $PortFilter = $Rule | Get-NetFirewallPortFilter
                $ApplicationFilter = $Rule | Get-NetFirewallApplicationFilter

                # Determine security risk
                $SecurityRisk = "Low"
                $RiskFactors = @()

                # Check for permissive rules
                if ($Rule.Enabled -eq $true) {
                    if ($Rule.Action -eq 'Allow') {
                        if ($AddressFilter.RemoteAddress -contains 'Any') {
                            $RiskFactors += "Allow from Any address"
                            $SecurityRisk = "Medium"
                        }
                        if ($PortFilter.RemotePort -contains 'Any') {
                            $RiskFactors += "Allow on Any port"
                            $SecurityRisk = "Medium"
                        }
                        if ($Rule.Direction -eq 'Inbound' -and $AddressFilter.RemoteAddress -contains 'Any' -and $PortFilter.RemotePort -contains 'Any') {
                            $RiskFactors += "Inbound Allow from Any:Any"
                            $SecurityRisk = "High"
                        }
                    }
                }

                $RuleDetails = [PSCustomObject]@{
                    Name = $Rule.DisplayName
                    Enabled = $Rule.Enabled
                    Direction = $Rule.Direction
                    Action = $Rule.Action
                    Profile = $Rule.Profile
                    LocalAddress = $AddressFilter.LocalAddress -join ', '
                    RemoteAddress = $AddressFilter.RemoteAddress -join ', '
                    Protocol = $PortFilter.Protocol
                    LocalPort = $PortFilter.LocalPort -join ', '
                    RemotePort = $PortFilter.RemotePort -join ', '
                    Program = $ApplicationFilter.Program
                    Service = $ApplicationFilter.Service
                    Description = $Rule.Description
                    SecurityRisk = $SecurityRisk
                    RiskFactors = ($RiskFactors -join "; ")
                }

                if ($IncludeRuleDetails) {
                    $Script:AuditResults.Rules += $RuleDetails
                }

                # Track security risks
                if ($SecurityRisk -ne "Low") {
                    $Script:AuditResults.SecurityRisks += $RuleDetails
                }

            } catch {
                Write-AuditLog "Error processing rule $($Rule.DisplayName): $($_.Exception.Message)" -Level Warning
            }
        }

        $EnabledRules = $AllRules | Where-Object { $_.Enabled -eq $true }
        $InboundAllow = $EnabledRules | Where-Object { $_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' }
        $OutboundBlock = $EnabledRules | Where-Object { $_.Direction -eq 'Outbound' -and $_.Action -eq 'Block' }

        Write-AuditLog "Enabled Rules: $($EnabledRules.Count)" -Level Info
        Write-AuditLog "Inbound Allow Rules: $($InboundAllow.Count)" -Level Info
        Write-AuditLog "Outbound Block Rules: $($OutboundBlock.Count)" -Level Info
        Write-AuditLog "Security Risks Found: $($Script:AuditResults.SecurityRisks.Count)" -Level Warning

        return $true
    } catch {
        Write-AuditLog "Error retrieving firewall rules: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-FirewallLoggingConfiguration {
    Write-AuditLog "Checking firewall logging configuration..." -Level Info

    try {
        $Profiles = @('Domain', 'Private', 'Public')

        foreach ($ProfileName in $Profiles) {
            $Profile = Get-NetFirewallProfile -Name $ProfileName

            $LogFileExists = $false
            $LogFileSize = 0

            if (Test-Path $Profile.LogFileName) {
                $LogFileExists = $true
                $LogFileSize = [math]::Round((Get-Item $Profile.LogFileName).Length / 1KB, 2)
            }

            $Script:AuditResults.Logging += [PSCustomObject]@{
                Profile = $ProfileName
                LoggingEnabled = ($Profile.LogAllowed -or $Profile.LogBlocked)
                LogAllowed = $Profile.LogAllowed
                LogBlocked = $Profile.LogBlocked
                LogFileName = $Profile.LogFileName
                LogFileExists = $LogFileExists
                CurrentSizeKB = $LogFileSize
                MaxSizeKB = $Profile.LogMaxSizeKilobytes
                CISCompliant = ($Profile.LogBlocked -eq $true)
            }
        }

        $LoggingIssues = $Script:AuditResults.Logging | Where-Object { -not $_.CISCompliant }
        if ($LoggingIssues.Count -gt 0) {
            Write-AuditLog "Found $($LoggingIssues.Count) profiles with logging not CIS compliant" -Level Warning
        } else {
            Write-AuditLog "All firewall logging configurations are CIS compliant" -Level Success
        }

        return $true
    } catch {
        Write-AuditLog "Error checking logging configuration: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-IPSecConfiguration {
    Write-AuditLog "Checking IPSec configuration..." -Level Info

    try {
        $IPSecRules = Get-NetIPsecRule -ErrorAction SilentlyContinue

        if ($IPSecRules) {
            Write-AuditLog "Found $($IPSecRules.Count) IPSec rules" -Level Info

            foreach ($Rule in $IPSecRules) {
                $Script:AuditResults.IPSec += [PSCustomObject]@{
                    Name = $Rule.DisplayName
                    Enabled = $Rule.Enabled
                    Profile = $Rule.Profile
                    Description = $Rule.Description
                }
            }
        } else {
            Write-AuditLog "No IPSec rules configured" -Level Info
        }

        return $true
    } catch {
        Write-AuditLog "Error checking IPSec configuration: $($_.Exception.Message)" -Level Warning
        return $true  # Non-critical error
    }
}

#endregion

#region Report Generation

function Export-FirewallAuditReport {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Results,

        [Parameter(Mandatory=$true)]
        [string]$OutputPath,

        [Parameter(Mandatory=$true)]
        [string]$Format
    )

    $ReportFile = Join-Path $OutputPath "Firewall_Audit_${ComputerName}_${Timestamp}.${Format.ToLower()}"

    # Calculate summary statistics
    $AllRules = Get-NetFirewallRule
    $TotalRules = $AllRules.Count
    $EnabledRules = ($AllRules | Where-Object { $_.Enabled -eq $true }).Count
    $DisabledRules = $TotalRules - $EnabledRules
    $InboundAllow = ($AllRules | Where-Object { $_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' -and $_.Enabled -eq $true }).Count
    $OutboundBlock = ($AllRules | Where-Object { $_.Direction -eq 'Outbound' -and $_.Action -eq 'Block' -and $_.Enabled -eq $true }).Count
    $SecurityRisks = $Results.SecurityRisks.Count
    $HighRisks = ($Results.SecurityRisks | Where-Object { $_.SecurityRisk -eq 'High' }).Count
    $CISCompliant = ($Results.Profiles | Where-Object { $_.CISCompliant }).Count

    $Results.Summary = @{
        TotalRules = $TotalRules
        EnabledRules = $EnabledRules
        DisabledRules = $DisabledRules
        InboundAllowRules = $InboundAllow
        OutboundBlockRules = $OutboundBlock
        SecurityRisks = $SecurityRisks
        HighRisks = $HighRisks
        CISCompliantProfiles = $CISCompliant
    }

    switch ($Format) {
        'HTML' {
            $HTMLReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Firewall Audit Report - $ComputerName</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        h1 { color: #2c3e50; border-bottom: 3px solid #e74c3c; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; background-color: #ecf0f1; padding: 10px; border-left: 4px solid #e74c3c; }
        .summary { background-color: white; padding: 20px; border-radius: 5px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric { display: inline-block; margin: 10px 20px; text-align: center; }
        .metric-value { font-size: 36px; font-weight: bold; }
        .metric-label { font-size: 14px; color: #7f8c8d; }
        .good { color: #27ae60; }
        .warning { color: #f39c12; }
        .bad { color: #e74c3c; }
        table { border-collapse: collapse; width: 100%; background-color: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 30px; }
        th { background-color: #34495e; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; font-size: 13px; }
        tr:hover { background-color: #f8f9fa; }
        .status-enabled { background-color: #d4edda; color: #155724; padding: 5px 10px; border-radius: 3px; }
        .status-disabled { background-color: #f8d7da; color: #721c24; padding: 5px 10px; border-radius: 3px; }
        .status-block { background-color: #fff3cd; color: #856404; padding: 5px 10px; border-radius: 3px; }
        .risk-high { background-color: #f8d7da; color: #721c24; padding: 5px 10px; border-radius: 3px; font-weight: bold; }
        .risk-medium { background-color: #fff3cd; color: #856404; padding: 5px 10px; border-radius: 3px; }
        .risk-low { background-color: #d4edda; color: #155724; padding: 5px 10px; border-radius: 3px; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #7f8c8d; font-size: 12px; }
    </style>
</head>
<body>
    <h1>Windows Firewall Audit Report</h1>

    <div class="summary">
        <h2>Audit Summary</h2>
        <div class="metric">
            <div class="metric-label">Computer</div>
            <div class="metric-value">$ComputerName</div>
        </div>
        <div class="metric">
            <div class="metric-label">Date</div>
            <div class="metric-value">$(Get-Date -Format 'yyyy-MM-dd HH:mm')</div>
        </div>
        <div class="metric">
            <div class="metric-label">Total Rules</div>
            <div class="metric-value">$TotalRules</div>
        </div>
        <div class="metric">
            <div class="metric-label">Enabled</div>
            <div class="metric-value good">$EnabledRules</div>
        </div>
        <div class="metric">
            <div class="metric-label">Security Risks</div>
            <div class="metric-value bad">$SecurityRisks</div>
        </div>
        <div class="metric">
            <div class="metric-label">High Risks</div>
            <div class="metric-value bad">$HighRisks</div>
        </div>
        <div class="metric">
            <div class="metric-label">CIS Compliant Profiles</div>
            <div class="metric-value">$CISCompliant / 3</div>
        </div>
    </div>

    <h2>Firewall Profile Status</h2>
    <table>
        <tr>
            <th>Profile</th>
            <th>Enabled</th>
            <th>Default Inbound</th>
            <th>Default Outbound</th>
            <th>Log Blocked</th>
            <th>CIS Compliant</th>
        </tr>
"@
            foreach ($Profile in $Results.Profiles) {
                $EnabledStatus = if ($Profile.Enabled) { "<span class='status-enabled'>Enabled</span>" } else { "<span class='status-disabled'>Disabled</span>" }
                $CISStatus = if ($Profile.CISCompliant) { "<span class='good'>✓ Yes</span>" } else { "<span class='bad'>✗ No</span>" }

                $HTMLReport += @"
        <tr>
            <td><strong>$($Profile.Profile)</strong></td>
            <td>$EnabledStatus</td>
            <td>$($Profile.DefaultInboundAction)</td>
            <td>$($Profile.DefaultOutboundAction)</td>
            <td>$($Profile.LogBlocked)</td>
            <td>$CISStatus</td>
        </tr>
"@
            }

            $HTMLReport += "</table>"

            # Security Risks section
            if ($SecurityRisks -gt 0) {
                $HTMLReport += @"
    <h2>Security Risks ($SecurityRisks)</h2>
    <table>
        <tr>
            <th>Rule Name</th>
            <th>Risk Level</th>
            <th>Direction</th>
            <th>Action</th>
            <th>Remote Address</th>
            <th>Remote Port</th>
            <th>Risk Factors</th>
        </tr>
"@
                foreach ($Risk in $Results.SecurityRisks) {
                    $RiskClass = switch ($Risk.SecurityRisk) {
                        'High' { 'risk-high' }
                        'Medium' { 'risk-medium' }
                        default { 'risk-low' }
                    }

                    $HTMLReport += @"
        <tr>
            <td>$($Risk.Name)</td>
            <td><span class='$RiskClass'>$($Risk.SecurityRisk)</span></td>
            <td>$($Risk.Direction)</td>
            <td>$($Risk.Action)</td>
            <td>$($Risk.RemoteAddress)</td>
            <td>$($Risk.RemotePort)</td>
            <td>$($Risk.RiskFactors)</td>
        </tr>
"@
                }
                $HTMLReport += "</table>"
            }

            # Logging Configuration
            $HTMLReport += @"
    <h2>Logging Configuration</h2>
    <table>
        <tr>
            <th>Profile</th>
            <th>Log Blocked</th>
            <th>Log Allowed</th>
            <th>Log File</th>
            <th>File Exists</th>
            <th>CIS Compliant</th>
        </tr>
"@
            foreach ($Log in $Results.Logging) {
                $CISStatus = if ($Log.CISCompliant) { "<span class='good'>✓ Yes</span>" } else { "<span class='bad'>✗ No</span>" }

                $HTMLReport += @"
        <tr>
            <td><strong>$($Log.Profile)</strong></td>
            <td>$($Log.LogBlocked)</td>
            <td>$($Log.LogAllowed)</td>
            <td>$($Log.LogFileName)</td>
            <td>$($Log.LogFileExists)</td>
            <td>$CISStatus</td>
        </tr>
"@
            }

            $HTMLReport += "</table>"

            $HTMLReport += @"
    <div class="footer">
        <p>Report generated by Firewall Audit Baseline Script v$ScriptVersion</p>
        <p>For Windows Server 2022 | Computer: $ComputerName</p>
    </div>
</body>
</html>
"@

            $HTMLReport | Out-File -FilePath $ReportFile -Encoding UTF8
        }

        'CSV' {
            if ($IncludeRuleDetails) {
                $Results.Rules | Export-Csv -Path $ReportFile -NoTypeInformation -Encoding UTF8
            } else {
                $Results.SecurityRisks | Export-Csv -Path $ReportFile -NoTypeInformation -Encoding UTF8
            }
        }

        'JSON' {
            $Results | ConvertTo-Json -Depth 10 | Out-File -FilePath $ReportFile -Encoding UTF8
        }
    }

    return $ReportFile
}

#endregion

#region Main Execution

try {
    Write-AuditLog "========================================" -Level Info
    Write-AuditLog "Firewall Audit Baseline Script v$ScriptVersion" -Level Info
    Write-AuditLog "========================================" -Level Info
    Write-AuditLog "Computer: $ComputerName" -Level Info
    Write-AuditLog "Output Format: $ExportFormat" -Level Info
    Write-AuditLog "========================================" -Level Info

    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-AuditLog "Created output directory: $OutputPath" -Level Success
    }

    # Perform audits
    Get-FirewallProfileStatus
    Get-FirewallRulesInventory
    Get-FirewallLoggingConfiguration
    Get-IPSecConfiguration

    # Generate report
    Write-AuditLog "Generating audit report..." -Level Info
    $ReportPath = Export-FirewallAuditReport -Results $AuditResults -OutputPath $OutputPath -Format $ExportFormat

    # Summary
    Write-AuditLog "========================================" -Level Info
    Write-AuditLog "Audit Complete!" -Level Success
    Write-AuditLog "Total Rules: $($AuditResults.Summary.TotalRules)" -Level Info
    Write-AuditLog "Enabled Rules: $($AuditResults.Summary.EnabledRules)" -Level Info
    Write-AuditLog "Security Risks: $($AuditResults.Summary.SecurityRisks)" -Level Warning
    Write-AuditLog "High Risks: $($AuditResults.Summary.HighRisks)" -Level Warning
    Write-AuditLog "CIS Compliant Profiles: $($AuditResults.Summary.CISCompliantProfiles) / 3" -Level Info
    Write-AuditLog "Report saved to: $ReportPath" -Level Success
    Write-AuditLog "========================================" -Level Info

    # Return report path for automation
    return [PSCustomObject]@{
        Success = $true
        ReportPath = $ReportPath
        Summary = $AuditResults.Summary
    }

} catch {
    Write-AuditLog "CRITICAL ERROR: $($_.Exception.Message)" -Level Error
    Write-AuditLog "Stack Trace: $($_.ScriptStackTrace)" -Level Error
    throw
}

#endregion
