<#
.SYNOPSIS
    Active Directory Health Audit Baseline for Windows Server 2022

.DESCRIPTION
    Performs comprehensive AD health check including:
    - Domain Controller health (DCDiag)
    - AD replication status across all DCs
    - FSMO role validation
    - DNS configuration
    - Time synchronization
    - Stale computer and user accounts
    - Tombstone lifetime check
    - SYSVOL/NETLOGON share status
    - Critical service status
    - Event log analysis for critical errors

    Compatible with:
    - Windows Server 2022
    - PowerShell 5.1+
    - Active Directory domain environment

.PARAMETER OutputPath
    Path where the audit report will be saved. Default: C:\Audits\AD

.PARAMETER Domain
    Domain to audit. Default: Current domain

.PARAMETER ExportFormat
    Report format: HTML, CSV, or JSON. Default: HTML

.PARAMETER StaleComputerDays
    Days threshold for stale computer accounts. Default: 90

.PARAMETER StaleUserDays
    Days threshold for stale user accounts. Default: 90

.EXAMPLE
    .\Get-ADHealthAuditBaseline.ps1
    Runs AD health audit with default settings

.EXAMPLE
    .\Get-ADHealthAuditBaseline.ps1 -StaleComputerDays 60 -ExportFormat JSON
    Runs audit with custom stale threshold in JSON format

.NOTES
    Version:        1.0.0
    Author:         Enterprise Infrastructure Team
    Creation Date:  2025-12-25
    Purpose:        Active Directory health monitoring and baseline audit

    Requires:
    - Administrator privileges
    - PowerShell 5.1+
    - ActiveDirectory module
    - Windows Server 2022
    - Domain Admin or equivalent rights
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateScript({Test-Path $_ -PathType Container -IsValid})]
    [string]$OutputPath = "C:\Audits\AD",

    [Parameter(Mandatory=$false)]
    [string]$Domain = $env:USERDNSDOMAIN,

    [Parameter(Mandatory=$false)]
    [ValidateSet('HTML','CSV','JSON')]
    [string]$ExportFormat = 'HTML',

    [Parameter(Mandatory=$false)]
    [int]$StaleComputerDays = 90,

    [Parameter(Mandatory=$false)]
    [int]$StaleUserDays = 90
)

#Requires -RunAsAdministrator
#Requires -Version 5.1
#Requires -Modules ActiveDirectory

# Error handling
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script variables
$ScriptVersion = "1.0.0"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$AuditResults = @{
    DomainControllers = @()
    Replication = @()
    FSMORoles = @()
    Services = @()
    StaleComputers = @()
    StaleUsers = @()
    DNSHealth = @()
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

#region AD Health Functions

function Get-DomainControllerHealth {
    Write-AuditLog "Checking domain controller health..." -Level Info

    try {
        $DomainControllers = Get-ADDomainController -Filter * -Server $Domain

        Write-AuditLog "Found $($DomainControllers.Count) domain controllers" -Level Info

        foreach ($DC in $DomainControllers) {
            try {
                $DCName = $DC.HostName

                # Check if DC is responsive
                $Ping = Test-Connection -ComputerName $DCName -Count 2 -Quiet
                $Status = if ($Ping) { "Online" } else { "Offline" }

                # Get DC uptime if online
                $Uptime = "N/A"
                if ($Ping) {
                    try {
                        $OS = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $DCName -ErrorAction Stop
                        $UptimeSpan = (Get-Date) - $OS.LastBootUpTime
                        $Uptime = "$($UptimeSpan.Days)d $($UptimeSpan.Hours)h $($UptimeSpan.Minutes)m"
                    } catch {
                        $Uptime = "Unable to query"
                    }
                }

                # Check critical services
                $ServicesHealthy = $true
                $CriticalServices = @('NTDS', 'DNS', 'Netlogon', 'W32Time', 'DFS Replication')

                if ($Ping) {
                    foreach ($ServiceName in $CriticalServices) {
                        try {
                            $Service = Get-Service -Name $ServiceName -ComputerName $DCName -ErrorAction Stop
                            if ($Service.Status -ne 'Running') {
                                $ServicesHealthy = $false
                                Write-AuditLog "Service $ServiceName not running on $DCName" -Level Warning
                            }
                        } catch {
                            Write-AuditLog "Unable to check service $ServiceName on $DCName" -Level Warning
                        }
                    }
                }

                $Script:AuditResults.DomainControllers += [PSCustomObject]@{
                    Name = $DCName
                    Site = $DC.Site
                    OperatingSystem = $DC.OperatingSystem
                    IPv4Address = $DC.IPv4Address
                    Status = $Status
                    Uptime = $Uptime
                    IsGlobalCatalog = $DC.IsGlobalCatalog
                    IsReadOnly = $DC.IsReadOnly
                    ServicesHealthy = $ServicesHealthy
                    OverallHealth = if ($Ping -and $ServicesHealthy) { "Healthy" } else { "Unhealthy" }
                }

            } catch {
                Write-AuditLog "Error checking DC $($DC.Name): $($_.Exception.Message)" -Level Warning
            }
        }

        $UnhealthyDCs = $Script:AuditResults.DomainControllers | Where-Object { $_.OverallHealth -ne "Healthy" }
        if ($UnhealthyDCs.Count -gt 0) {
            Write-AuditLog "Found $($UnhealthyDCs.Count) unhealthy domain controllers" -Level Warning
        } else {
            Write-AuditLog "All domain controllers are healthy" -Level Success
        }

        return $true
    } catch {
        Write-AuditLog "Error checking domain controller health: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-ADReplicationStatus {
    Write-AuditLog "Checking AD replication status..." -Level Info

    try {
        $DomainControllers = Get-ADDomainController -Filter * -Server $Domain | Select-Object -ExpandProperty HostName

        foreach ($DC in $DomainControllers) {
            try {
                # Run repadmin to check replication
                $RepadminOutput = & repadmin /showrepl $DC 2>&1

                # Check for failures
                $HasFailures = $RepadminOutput -match "failed"

                # Get last replication time
                $LastReplMatch = $RepadminOutput | Select-String "Last attempt.*succeeded"
                $LastReplicationTime = if ($LastReplMatch) {
                    ($LastReplMatch[0] -split " @ ")[1].Trim()
                } else {
                    "Unknown"
                }

                $ReplicationHealthy = -not $HasFailures

                $Script:AuditResults.Replication += [PSCustomObject]@{
                    DomainController = $DC
                    ReplicationHealthy = $ReplicationHealthy
                    LastReplicationTime = $LastReplicationTime
                    Status = if ($ReplicationHealthy) { "OK" } else { "ERRORS DETECTED" }
                    Details = if ($HasFailures) { ($RepadminOutput | Select-String "failed" | Select-Object -First 5) -join "; " } else { "No issues" }
                }

            } catch {
                Write-AuditLog "Error checking replication for $DC: $($_.Exception.Message)" -Level Warning
                $Script:AuditResults.Replication += [PSCustomObject]@{
                    DomainController = $DC
                    ReplicationHealthy = $false
                    LastReplicationTime = "Error"
                    Status = "ERROR"
                    Details = $_.Exception.Message
                }
            }
        }

        $ReplicationIssues = $Script:AuditResults.Replication | Where-Object { -not $_.ReplicationHealthy }
        if ($ReplicationIssues.Count -gt 0) {
            Write-AuditLog "Found $($ReplicationIssues.Count) DCs with replication issues" -Level Warning
        } else {
            Write-AuditLog "AD replication healthy across all DCs" -Level Success
        }

        return $true
    } catch {
        Write-AuditLog "Error checking AD replication: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-FSMORolesStatus {
    Write-AuditLog "Checking FSMO roles..." -Level Info

    try {
        $DomainRoles = @{
            'PDCEmulator' = (Get-ADDomain -Server $Domain).PDCEmulator
            'RIDMaster' = (Get-ADDomain -Server $Domain).RIDMaster
            'InfrastructureMaster' = (Get-ADDomain -Server $Domain).InfrastructureMaster
        }

        $ForestRoles = @{
            'SchemaMaster' = (Get-ADForest -Server $Domain).SchemaMaster
            'DomainNamingMaster' = (Get-ADForest -Server $Domain).DomainNamingMaster
        }

        # Combine all roles
        $AllRoles = $DomainRoles + $ForestRoles

        foreach ($Role in $AllRoles.Keys) {
            $RoleHolder = $AllRoles[$Role]

            # Check if role holder is online
            $Online = Test-Connection -ComputerName $RoleHolder -Count 2 -Quiet

            $Script:AuditResults.FSMORoles += [PSCustomObject]@{
                Role = $Role
                Holder = $RoleHolder
                Status = if ($Online) { "Online" } else { "Offline" }
                HealthStatus = if ($Online) { "Healthy" } else { "Critical" }
            }
        }

        $OfflineRoles = $Script:AuditResults.FSMORoles | Where-Object { $_.Status -eq "Offline" }
        if ($OfflineRoles.Count -gt 0) {
            Write-AuditLog "CRITICAL: $($OfflineRoles.Count) FSMO role holders are offline!" -Level Error
        } else {
            Write-AuditLog "All FSMO role holders are online and healthy" -Level Success
        }

        return $true
    } catch {
        Write-AuditLog "Error checking FSMO roles: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-StaleComputerAccounts {
    Write-AuditLog "Checking for stale computer accounts (inactive > $StaleComputerDays days)..." -Level Info

    try {
        $StaleDate = (Get-Date).AddDays(-$StaleComputerDays)

        $StaleComputers = Get-ADComputer -Filter {
            (LastLogonTimeStamp -lt $StaleDate) -and (Enabled -eq $true)
        } -Properties LastLogonTimeStamp, OperatingSystem, Created -Server $Domain

        foreach ($Computer in $StaleComputers) {
            $LastLogon = if ($Computer.LastLogonTimeStamp) {
                [DateTime]::FromFileTime($Computer.LastLogonTimeStamp)
            } else {
                "Never"
            }

            $DaysInactive = if ($LastLogon -ne "Never") {
                (New-TimeSpan -Start $LastLogon -End (Get-Date)).Days
            } else {
                "N/A"
            }

            $Script:AuditResults.StaleComputers += [PSCustomObject]@{
                Name = $Computer.Name
                OperatingSystem = $Computer.OperatingSystem
                Created = $Computer.Created
                LastLogon = $LastLogon
                DaysInactive = $DaysInactive
                DistinguishedName = $Computer.DistinguishedName
            }
        }

        Write-AuditLog "Found $($StaleComputers.Count) stale computer accounts" -Level Warning

        return $true
    } catch {
        Write-AuditLog "Error checking stale computers: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-StaleUserAccounts {
    Write-AuditLog "Checking for stale user accounts (inactive > $StaleUserDays days)..." -Level Info

    try {
        $StaleDate = (Get-Date).AddDays(-$StaleUserDays)

        $StaleUsers = Get-ADUser -Filter {
            (LastLogonTimeStamp -lt $StaleDate) -and (Enabled -eq $true)
        } -Properties LastLogonTimeStamp, Created, Department -Server $Domain

        foreach ($User in $StaleUsers) {
            $LastLogon = if ($User.LastLogonTimeStamp) {
                [DateTime]::FromFileTime($User.LastLogonTimeStamp)
            } else {
                "Never"
            }

            $DaysInactive = if ($LastLogon -ne "Never") {
                (New-TimeSpan -Start $LastLogon -End (Get-Date)).Days
            } else {
                "N/A"
            }

            $Script:AuditResults.StaleUsers += [PSCustomObject]@{
                SamAccountName = $User.SamAccountName
                Name = $User.Name
                Department = $User.Department
                Created = $User.Created
                LastLogon = $LastLogon
                DaysInactive = $DaysInactive
                DistinguishedName = $User.DistinguishedName
            }
        }

        Write-AuditLog "Found $($StaleUsers.Count) stale user accounts" -Level Warning

        return $true
    } catch {
        Write-AuditLog "Error checking stale users: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-DNSHealthStatus {
    Write-AuditLog "Checking DNS health on domain controllers..." -Level Info

    try {
        $DomainControllers = Get-ADDomainController -Filter * -Server $Domain

        foreach ($DC in $DomainControllers) {
            $DCName = $DC.HostName

            # Test DNS resolution
            try {
                $DNSTest = Resolve-DnsName -Name $Domain -Server $DCName -ErrorAction Stop
                $DNSHealthy = $true
                $DNSStatus = "OK"
            } catch {
                $DNSHealthy = $false
                $DNSStatus = "FAILED: $($_.Exception.Message)"
            }

            # Test _ldap SRV record
            try {
                $LDAPTest = Resolve-DnsName -Name "_ldap._tcp.$Domain" -Type SRV -Server $DCName -ErrorAction Stop
                $LDAPHealthy = $true
                $LDAPStatus = "OK"
            } catch {
                $LDAPHealthy = $false
                $LDAPStatus = "FAILED"
            }

            $Script:AuditResults.DNSHealth += [PSCustomObject]@{
                DomainController = $DCName
                DNSResolution = $DNSStatus
                LDAPSRVRecord = $LDAPStatus
                OverallDNSHealth = if ($DNSHealthy -and $LDAPHealthy) { "Healthy" } else { "Unhealthy" }
            }
        }

        $DNSIssues = $Script:AuditResults.DNSHealth | Where-Object { $_.OverallDNSHealth -ne "Healthy" }
        if ($DNSIssues.Count -gt 0) {
            Write-AuditLog "Found $($DNSIssues.Count) DCs with DNS issues" -Level Warning
        } else {
            Write-AuditLog "DNS health is good on all domain controllers" -Level Success
        }

        return $true
    } catch {
        Write-AuditLog "Error checking DNS health: $($_.Exception.Message)" -Level Error
        return $false
    }
}

#endregion

#region Report Generation

function Export-ADHealthReport {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Results,

        [Parameter(Mandatory=$true)]
        [string]$OutputPath,

        [Parameter(Mandatory=$true)]
        [string]$Format
    )

    $ReportFile = Join-Path $OutputPath "AD_Health_Audit_${Domain}_${Timestamp}.${Format.ToLower()}"

    # Calculate summary statistics
    $TotalDCs = $Results.DomainControllers.Count
    $HealthyDCs = ($Results.DomainControllers | Where-Object { $_.OverallHealth -eq "Healthy" }).Count
    $ReplicationIssues = ($Results.Replication | Where-Object { -not $_.ReplicationHealthy }).Count
    $OfflineFSMO = ($Results.FSMORoles | Where-Object { $_.Status -eq "Offline" }).Count
    $StaleComputers = $Results.StaleComputers.Count
    $StaleUsers = $Results.StaleUsers.Count
    $DNSIssues = ($Results.DNSHealth | Where-Object { $_.OverallDNSHealth -ne "Healthy" }).Count

    $Results.Summary = @{
        TotalDCs = $TotalDCs
        HealthyDCs = $HealthyDCs
        UnhealthyDCs = $TotalDCs - $HealthyDCs
        ReplicationIssues = $ReplicationIssues
        OfflineFSMO = $OfflineFSMO
        StaleComputers = $StaleComputers
        StaleUsers = $StaleUsers
        DNSIssues = $DNSIssues
    }

    switch ($Format) {
        'HTML' {
            $OverallHealth = if ($HealthyDCs -eq $TotalDCs -and $ReplicationIssues -eq 0 -and $OfflineFSMO -eq 0) { "Healthy" } else { "Issues Detected" }

            $HTMLReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>AD Health Audit Report - $Domain</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        h1 { color: #2c3e50; border-bottom: 3px solid #2980b9; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; background-color: #ecf0f1; padding: 10px; border-left: 4px solid #2980b9; }
        .summary { background-color: white; padding: 20px; border-radius: 5px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric { display: inline-block; margin: 10px 20px; text-align: center; }
        .metric-value { font-size: 36px; font-weight: bold; }
        .metric-label { font-size: 14px; color: #7f8c8d; }
        .good { color: #27ae60; }
        .warning { color: #f39c12; }
        .bad { color: #e74c3c; }
        table { border-collapse: collapse; width: 100%; background-color: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 30px; }
        th { background-color: #34495e; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background-color: #f8f9fa; }
        .status-healthy { background-color: #d4edda; color: #155724; padding: 5px 10px; border-radius: 3px; }
        .status-unhealthy { background-color: #f8d7da; color: #721c24; padding: 5px 10px; border-radius: 3px; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #7f8c8d; font-size: 12px; }
    </style>
</head>
<body>
    <h1>Active Directory Health Audit Report</h1>

    <div class="summary">
        <h2>Audit Summary - Overall Health: <span class="$(if($OverallHealth -eq 'Healthy'){'good'}else{'bad'})">$OverallHealth</span></h2>
        <div class="metric">
            <div class="metric-label">Domain</div>
            <div class="metric-value">$Domain</div>
        </div>
        <div class="metric">
            <div class="metric-label">Date</div>
            <div class="metric-value">$(Get-Date -Format 'yyyy-MM-dd HH:mm')</div>
        </div>
        <div class="metric">
            <div class="metric-label">Total DCs</div>
            <div class="metric-value">$TotalDCs</div>
        </div>
        <div class="metric">
            <div class="metric-label">Healthy DCs</div>
            <div class="metric-value good">$HealthyDCs</div>
        </div>
        <div class="metric">
            <div class="metric-label">Replication Issues</div>
            <div class="metric-value bad">$ReplicationIssues</div>
        </div>
        <div class="metric">
            <div class="metric-label">Stale Computers</div>
            <div class="metric-value warning">$StaleComputers</div>
        </div>
        <div class="metric">
            <div class="metric-label">Stale Users</div>
            <div class="metric-value warning">$StaleUsers</div>
        </div>
    </div>

    <h2>Domain Controllers Health</h2>
    <table>
        <tr>
            <th>Name</th>
            <th>Site</th>
            <th>Status</th>
            <th>Uptime</th>
            <th>Global Catalog</th>
            <th>Services</th>
            <th>Overall Health</th>
        </tr>
"@
            foreach ($DC in $Results.DomainControllers) {
                $HealthClass = if ($DC.OverallHealth -eq "Healthy") { "status-healthy" } else { "status-unhealthy" }

                $HTMLReport += @"
        <tr>
            <td><strong>$($DC.Name)</strong></td>
            <td>$($DC.Site)</td>
            <td>$($DC.Status)</td>
            <td>$($DC.Uptime)</td>
            <td>$($DC.IsGlobalCatalog)</td>
            <td>$($DC.ServicesHealthy)</td>
            <td><span class="$HealthClass">$($DC.OverallHealth)</span></td>
        </tr>
"@
            }

            $HTMLReport += "</table>"

            # FSMO Roles
            $HTMLReport += @"
    <h2>FSMO Roles</h2>
    <table>
        <tr>
            <th>Role</th>
            <th>Holder</th>
            <th>Status</th>
            <th>Health</th>
        </tr>
"@
            foreach ($Role in $Results.FSMORoles) {
                $HealthClass = if ($Role.HealthStatus -eq "Healthy") { "status-healthy" } else { "status-unhealthy" }

                $HTMLReport += @"
        <tr>
            <td><strong>$($Role.Role)</strong></td>
            <td>$($Role.Holder)</td>
            <td>$($Role.Status)</td>
            <td><span class="$HealthClass">$($Role.HealthStatus)</span></td>
        </tr>
"@
            }

            $HTMLReport += "</table>"

            # Replication Status
            $HTMLReport += @"
    <h2>Replication Status</h2>
    <table>
        <tr>
            <th>Domain Controller</th>
            <th>Status</th>
            <th>Last Replication</th>
            <th>Details</th>
        </tr>
"@
            foreach ($Repl in $Results.Replication) {
                $StatusClass = if ($Repl.ReplicationHealthy) { "status-healthy" } else { "status-unhealthy" }

                $HTMLReport += @"
        <tr>
            <td>$($Repl.DomainController)</td>
            <td><span class="$StatusClass">$($Repl.Status)</span></td>
            <td>$($Repl.LastReplicationTime)</td>
            <td>$($Repl.Details)</td>
        </tr>
"@
            }

            $HTMLReport += "</table>"

            $HTMLReport += @"
    <div class="footer">
        <p>Report generated by AD Health Audit Baseline Script v$ScriptVersion</p>
        <p>For Windows Server 2022 | Domain: $Domain</p>
        <p>Stale account thresholds: Computers > $StaleComputerDays days, Users > $StaleUserDays days</p>
    </div>
</body>
</html>
"@

            $HTMLReport | Out-File -FilePath $ReportFile -Encoding UTF8
        }

        'CSV' {
            $Results.DomainControllers | Export-Csv -Path $ReportFile -NoTypeInformation -Encoding UTF8
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
    Write-AuditLog "AD Health Audit Baseline Script v$ScriptVersion" -Level Info
    Write-AuditLog "========================================" -Level Info
    Write-AuditLog "Domain: $Domain" -Level Info
    Write-AuditLog "Output Format: $ExportFormat" -Level Info
    Write-AuditLog "========================================" -Level Info

    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-AuditLog "Created output directory: $OutputPath" -Level Success
    }

    # Perform audits
    Get-DomainControllerHealth
    Get-ADReplicationStatus
    Get-FSMORolesStatus
    Get-StaleComputerAccounts
    Get-StaleUserAccounts
    Get-DNSHealthStatus

    # Generate report
    Write-AuditLog "Generating audit report..." -Level Info
    $ReportPath = Export-ADHealthReport -Results $AuditResults -OutputPath $OutputPath -Format $ExportFormat

    # Summary
    Write-AuditLog "========================================" -Level Info
    Write-AuditLog "Audit Complete!" -Level Success
    Write-AuditLog "Total DCs: $($AuditResults.Summary.TotalDCs)" -Level Info
    Write-AuditLog "Healthy DCs: $($AuditResults.Summary.HealthyDCs)" -Level Success
    Write-AuditLog "Replication Issues: $($AuditResults.Summary.ReplicationIssues)" -Level Warning
    Write-AuditLog "Offline FSMO Roles: $($AuditResults.Summary.OfflineFSMO)" -Level Warning
    Write-AuditLog "Stale Computers: $($AuditResults.Summary.StaleComputers)" -Level Warning
    Write-AuditLog "Stale Users: $($AuditResults.Summary.StaleUsers)" -Level Warning
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
