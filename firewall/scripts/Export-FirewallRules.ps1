<#
.SYNOPSIS
    Export Windows Defender Firewall rules to various formats.

.DESCRIPTION
    Exports firewall rules and profile configurations to JSON, CSV, or native WFW format.
    Supports filtering by profile, group, or rule name pattern.

.PARAMETER ExportPath
    Path where exported files will be saved. Default: Current directory

.PARAMETER Format
    Export format: JSON, CSV, WFW, or All. Default: JSON

.PARAMETER Profile
    Filter by profile: Domain, Private, Public, or All. Default: All

.PARAMETER RuleGroup
    Filter by rule group name (e.g., "Remote Management")

.PARAMETER IncludeDisabled
    Include disabled rules in export. Default: False

.EXAMPLE
    .\Export-FirewallRules.ps1 -ExportPath C:\Backup -Format All

.EXAMPLE
    .\Export-FirewallRules.ps1 -Profile Domain -RuleGroup "Remote Management" -Format JSON

.NOTES
    Author: Enterprise Security Team
    Version: 1.0
    Requires: PowerShell 5.1+, Run as Administrator
    Date: 2025-12-26
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ExportPath = ".",

    [Parameter(Mandatory=$false)]
    [ValidateSet("JSON","CSV","WFW","All")]
    [string]$Format = "JSON",

    [Parameter(Mandatory=$false)]
    [ValidateSet("Domain","Private","Public","All")]
    [string]$Profile = "All",

    [Parameter(Mandatory=$false)]
    [string]$RuleGroup,

    [Parameter(Mandatory=$false)]
    [switch]$IncludeDisabled
)

#Requires -Version 5.1
#Requires -RunAsAdministrator

# Configure error handling
$ErrorActionPreference = "Stop"

try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Firewall Rules Export Utility" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # Ensure export path exists
    if (-not (Test-Path $ExportPath)) {
        New-Item -Path $ExportPath -ItemType Directory -Force | Out-Null
        Write-Host "Created export directory: $ExportPath" -ForegroundColor Green
    }

    $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $ExportPath = Resolve-Path $ExportPath

    # Step 1: Get Firewall Rules
    Write-Host "[1/4] Collecting firewall rules..." -ForegroundColor Yellow

    $FilterParams = @{}

    if ($Profile -ne "All") {
        $FilterParams['Profile'] = $Profile
    }

    if ($RuleGroup) {
        $FilterParams['Group'] = $RuleGroup
    }

    $Rules = Get-NetFirewallRule @FilterParams

    if (-not $IncludeDisabled) {
        $Rules = $Rules | Where-Object { $_.Enabled -eq $true }
    }

    Write-Host "  Found $($Rules.Count) rules matching criteria" -ForegroundColor Green

    # Step 2: Collect Detailed Rule Information
    Write-Host "`n[2/4] Gathering rule details..." -ForegroundColor Yellow

    $DetailedRules = @()
    $Counter = 0

    foreach ($Rule in $Rules) {
        $Counter++
        Write-Progress -Activity "Processing Rules" -Status "Rule $Counter of $($Rules.Count)" -PercentComplete (($Counter / $Rules.Count) * 100)

        # Get address filter
        $AddressFilter = $Rule | Get-NetFirewallAddressFilter

        # Get port filter
        $PortFilter = $Rule | Get-NetFirewallPortFilter

        # Get application filter
        $ApplicationFilter = $Rule | Get-NetFirewallApplicationFilter

        # Get service filter
        $ServiceFilter = $Rule | Get-NetFirewallServiceFilter

        $DetailedRules += [PSCustomObject]@{
            DisplayName = $Rule.DisplayName
            Name = $Rule.Name
            Description = $Rule.Description
            Group = $Rule.Group
            Enabled = $Rule.Enabled
            Profile = $Rule.Profile
            Direction = $Rule.Direction
            Action = $Rule.Action
            Protocol = $PortFilter.Protocol
            LocalPort = $PortFilter.LocalPort -join ','
            RemotePort = $PortFilter.RemotePort -join ','
            LocalAddress = $AddressFilter.LocalAddress -join ','
            RemoteAddress = $AddressFilter.RemoteAddress -join ','
            Program = $ApplicationFilter.Program
            Service = $ServiceFilter.Service
            InterfaceType = $Rule.InterfaceType
            Owner = $Rule.Owner
        }
    }

    Write-Progress -Activity "Processing Rules" -Completed
    Write-Host "  ✓ Collected details for $($DetailedRules.Count) rules" -ForegroundColor Green

    # Step 3: Export to Requested Formats
    Write-Host "`n[3/4] Exporting to $Format format(s)..." -ForegroundColor Yellow

    $ExportedFiles = @()

    # JSON Export
    if ($Format -eq "JSON" -or $Format -eq "All") {
        $JsonPath = Join-Path $ExportPath "FirewallRules-$Timestamp.json"

        $ExportData = @{
            ExportDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            ComputerName = $env:COMPUTERNAME
            Profile = $Profile
            RuleCount = $DetailedRules.Count
            Rules = $DetailedRules
        }

        $ExportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $JsonPath -Encoding UTF8
        $ExportedFiles += $JsonPath
        Write-Host "  ✓ JSON export: $JsonPath" -ForegroundColor Green
    }

    # CSV Export
    if ($Format -eq "CSV" -or $Format -eq "All") {
        $CsvPath = Join-Path $ExportPath "FirewallRules-$Timestamp.csv"
        $DetailedRules | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
        $ExportedFiles += $CsvPath
        Write-Host "  ✓ CSV export: $CsvPath" -ForegroundColor Green
    }

    # WFW (Native Windows Firewall) Export
    if ($Format -eq "WFW" -or $Format -eq "All") {
        $WfwPath = Join-Path $ExportPath "FirewallConfig-$Timestamp.wfw"

        # Determine which profiles to export
        $ProfilesToExport = switch ($Profile) {
            "All" { @("Domain","Private","Public") }
            default { @($Profile) }
        }

        # Export native firewall configuration
        netsh advfirewall export $WfwPath | Out-Null

        $ExportedFiles += $WfwPath
        Write-Host "  ✓ WFW export: $WfwPath" -ForegroundColor Green
    }

    # Step 4: Export Profile Settings
    Write-Host "`n[4/4] Exporting profile configurations..." -ForegroundColor Yellow

    $ProfileSettings = @()

    $ProfilesToCheck = switch ($Profile) {
        "All" { @("Domain","Private","Public") }
        default { @($Profile) }
    }

    foreach ($ProfileName in $ProfilesToCheck) {
        $ProfileConfig = Get-NetFirewallProfile -Profile $ProfileName

        $ProfileSettings += [PSCustomObject]@{
            Profile = $ProfileName
            Enabled = $ProfileConfig.Enabled
            DefaultInboundAction = $ProfileConfig.DefaultInboundAction
            DefaultOutboundAction = $ProfileConfig.DefaultOutboundAction
            AllowInboundRules = $ProfileConfig.AllowInboundRules
            AllowLocalFirewallRules = $ProfileConfig.AllowLocalFirewallRules
            AllowLocalIPsecRules = $ProfileConfig.AllowLocalIPsecRules
            AllowUserApps = $ProfileConfig.AllowUserApps
            AllowUserPorts = $ProfileConfig.AllowUserPorts
            AllowUnicastResponseToMulticast = $ProfileConfig.AllowUnicastResponseToMulticast
            NotifyOnListen = $ProfileConfig.NotifyOnListen
            EnableStealthModeForIPsec = $ProfileConfig.EnableStealthModeForIPsec
            LogFileName = $ProfileConfig.LogFileName
            LogMaxSizeKilobytes = $ProfileConfig.LogMaxSizeKilobytes
            LogAllowed = $ProfileConfig.LogAllowed
            LogBlocked = $ProfileConfig.LogBlocked
            LogIgnored = $ProfileConfig.LogIgnored
        }
    }

    $ProfilePath = Join-Path $ExportPath "FirewallProfiles-$Timestamp.json"
    $ProfileSettings | ConvertTo-Json -Depth 5 | Out-File -FilePath $ProfilePath -Encoding UTF8
    $ExportedFiles += $ProfilePath
    Write-Host "  ✓ Profile settings: $ProfilePath" -ForegroundColor Green

    # Summary
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Export Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    Write-Host "Computer: $env:COMPUTERNAME" -ForegroundColor White
    Write-Host "Profile: $Profile" -ForegroundColor White
    Write-Host "Rules Exported: $($DetailedRules.Count)" -ForegroundColor White
    Write-Host "Format(s): $Format" -ForegroundColor White
    Write-Host "Export Path: $ExportPath`n" -ForegroundColor White

    Write-Host "Exported Files:" -ForegroundColor Yellow
    foreach ($File in $ExportedFiles) {
        $FileInfo = Get-Item $File
        Write-Host "  $($FileInfo.Name) ($([math]::Round($FileInfo.Length / 1KB, 2)) KB)" -ForegroundColor Gray
    }

    Write-Host "`n✓ Export completed successfully!" -ForegroundColor Green

    # Return file paths for scripting
    return $ExportedFiles

} catch {
    Write-Host "`n❌ Error during export: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    throw
}
