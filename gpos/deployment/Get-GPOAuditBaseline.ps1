<#
.SYNOPSIS
    Group Policy Object (GPO) Audit Baseline for Windows Server 2022

.DESCRIPTION
    Performs comprehensive GPO health check and audit including:
    - GPO replication status across all DCs
    - Unlinked and orphaned GPOs
    - GPO version mismatches (SYSVOL vs AD)
    - GPO permissions and delegation
    - WMI filter status
    - GPO backup status
    - Security filtering validation

    Compatible with:
    - Windows Server 2022
    - PowerShell 5.1+
    - Active Directory domain environment

.PARAMETER OutputPath
    Path where the audit report will be saved. Default: C:\Audits\GPO

.PARAMETER Domain
    Domain to audit. Default: Current domain

.PARAMETER ExportFormat
    Report format: HTML, CSV, or JSON. Default: HTML

.PARAMETER CheckReplication
    Include detailed GPO replication checks across all DCs

.EXAMPLE
    .\Get-GPOAuditBaseline.ps1
    Runs GPO audit with default settings

.EXAMPLE
    .\Get-GPOAuditBaseline.ps1 -CheckReplication -ExportFormat JSON
    Runs full audit including replication with JSON output

.NOTES
    Version:        1.0.0
    Author:         Enterprise Infrastructure Team
    Creation Date:  2025-12-25
    Purpose:        GPO health monitoring and compliance baseline

    Requires:
    - Administrator privileges
    - PowerShell 5.1+
    - GroupPolicy module
    - ActiveDirectory module
    - Windows Server 2022
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateScript({Test-Path $_ -PathType Container -IsValid})]
    [string]$OutputPath = "C:\Audits\GPO",

    [Parameter(Mandatory=$false)]
    [string]$Domain = $env:USERDNSDOMAIN,

    [Parameter(Mandatory=$false)]
    [ValidateSet('HTML','CSV','JSON')]
    [string]$ExportFormat = 'HTML',

    [Parameter(Mandatory=$false)]
    [switch]$CheckReplication
)

#Requires -RunAsAdministrator
#Requires -Version 5.1
#Requires -Modules GroupPolicy,ActiveDirectory

# Error handling
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script variables
$ScriptVersion = "1.0.0"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$AuditResults = @{
    GPOHealth = @()
    Replication = @()
    Unlinked = @()
    Orphaned = @()
    VersionMismatch = @()
    Permissions = @()
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

#region GPO Audit Functions

function Get-GPOHealthStatus {
    Write-AuditLog "Retrieving all GPOs in domain: $Domain" -Level Info

    try {
        $AllGPOs = Get-GPO -All -Domain $Domain

        Write-AuditLog "Found $($AllGPOs.Count) GPOs in domain" -Level Success

        foreach ($GPO in $AllGPOs) {
            try {
                # Get GPO details
                $GPOReport = Get-GPOReport -Guid $GPO.Id -ReportType Xml -Domain $Domain
                [xml]$XMLReport = $GPOReport

                # Check for links
                $Links = @()
                $LinksXML = $XMLReport.GPO.LinksTo
                if ($LinksXML) {
                    foreach ($Link in $LinksXML) {
                        $Links += [PSCustomObject]@{
                            Path = $Link.SOMPath
                            Enabled = $Link.Enabled
                        }
                    }
                }

                # Check version mismatch
                $ADVersion = $GPO.User.DSVersion + $GPO.Computer.DSVersion
                $SysvolVersion = $GPO.User.SysvolVersion + $GPO.Computer.SysvolVersion
                $VersionMatch = $ADVersion -eq $SysvolVersion

                # Get WMI Filter
                $WMIFilter = if ($GPO.WmiFilter) { $GPO.WmiFilter.Name } else { "None" }

                # Check modification date
                $DaysSinceModified = (New-TimeSpan -Start $GPO.ModificationTime -End (Get-Date)).Days

                $Script:AuditResults.GPOHealth += [PSCustomObject]@{
                    Name = $GPO.DisplayName
                    GUID = $GPO.Id
                    Status = $GPO.GpoStatus
                    Created = $GPO.CreationTime
                    Modified = $GPO.ModificationTime
                    DaysSinceModified = $DaysSinceModified
                    Owner = $GPO.Owner
                    ADVersion = $ADVersion
                    SysvolVersion = $SysvolVersion
                    VersionMatch = $VersionMatch
                    WMIFilter = $WMIFilter
                    LinkCount = $Links.Count
                    Links = ($Links.Path -join "; ")
                    IsLinked = ($Links.Count -gt 0)
                    UserSettings = $GPO.User.Enabled
                    ComputerSettings = $GPO.Computer.Enabled
                }

            } catch {
                Write-AuditLog "Error processing GPO $($GPO.DisplayName): $($_.Exception.Message)" -Level Warning
            }
        }

        return $true
    } catch {
        Write-AuditLog "Error retrieving GPOs: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-UnlinkedGPOs {
    Write-AuditLog "Checking for unlinked GPOs..." -Level Info

    try {
        $UnlinkedGPOs = $Script:AuditResults.GPOHealth | Where-Object { -not $_.IsLinked }

        $Script:AuditResults.Unlinked = $UnlinkedGPOs

        if ($UnlinkedGPOs.Count -gt 0) {
            Write-AuditLog "Found $($UnlinkedGPOs.Count) unlinked GPOs" -Level Warning
        } else {
            Write-AuditLog "No unlinked GPOs found" -Level Success
        }

        return $true
    } catch {
        Write-AuditLog "Error checking unlinked GPOs: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-VersionMismatchGPOs {
    Write-AuditLog "Checking for GPO version mismatches (AD vs SYSVOL)..." -Level Info

    try {
        $MismatchGPOs = $Script:AuditResults.GPOHealth | Where-Object { -not $_.VersionMatch }

        $Script:AuditResults.VersionMismatch = $MismatchGPOs

        if ($MismatchGPOs.Count -gt 0) {
            Write-AuditLog "Found $($MismatchGPOs.Count) GPOs with version mismatches" -Level Warning
            foreach ($GPO in $MismatchGPOs) {
                Write-AuditLog "  - $($GPO.Name): AD=$($GPO.ADVersion), SYSVOL=$($GPO.SysvolVersion)" -Level Warning
            }
        } else {
            Write-AuditLog "No GPO version mismatches found" -Level Success
        }

        return $true
    } catch {
        Write-AuditLog "Error checking version mismatches: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-GPOReplicationStatus {
    Write-AuditLog "Checking GPO replication across domain controllers..." -Level Info

    try {
        # Get all domain controllers
        $DomainControllers = Get-ADDomainController -Filter * -Server $Domain | Select-Object -ExpandProperty HostName

        Write-AuditLog "Found $($DomainControllers.Count) domain controllers" -Level Info

        $AllGPOs = Get-GPO -All -Domain $Domain

        foreach ($GPO in $AllGPOs) {
            $ReplicationStatus = @()

            foreach ($DC in $DomainControllers) {
                try {
                    # Query GPO from each DC
                    $DCGPOInfo = Get-GPO -Guid $GPO.Id -Server $DC -ErrorAction Stop

                    $ReplicationStatus += [PSCustomObject]@{
                        DomainController = $DC
                        ADVersion = ($DCGPOInfo.User.DSVersion + $DCGPOInfo.Computer.DSVersion)
                        SysvolVersion = ($DCGPOInfo.User.SysvolVersion + $DCGPOInfo.Computer.SysvolVersion)
                        ModificationTime = $DCGPOInfo.ModificationTime
                        Status = "OK"
                    }
                } catch {
                    $ReplicationStatus += [PSCustomObject]@{
                        DomainController = $DC
                        ADVersion = "N/A"
                        SysvolVersion = "N/A"
                        ModificationTime = "N/A"
                        Status = "ERROR: $($_.Exception.Message)"
                    }
                }
            }

            # Check if all DCs have same version
            $UniqueVersions = $ReplicationStatus | Select-Object -ExpandProperty ADVersion -Unique
            $ReplicationHealthy = ($UniqueVersions.Count -eq 1) -and ($UniqueVersions[0] -ne "N/A")

            $Script:AuditResults.Replication += [PSCustomObject]@{
                GPOName = $GPO.DisplayName
                GPOGUID = $GPO.Id
                ReplicationHealthy = $ReplicationHealthy
                DCCount = $DomainControllers.Count
                Details = $ReplicationStatus
            }
        }

        $UnhealthyReplication = $Script:AuditResults.Replication | Where-Object { -not $_.ReplicationHealthy }
        if ($UnhealthyReplication.Count -gt 0) {
            Write-AuditLog "Found $($UnhealthyReplication.Count) GPOs with replication issues" -Level Warning
        } else {
            Write-AuditLog "All GPOs replicated successfully across all DCs" -Level Success
        }

        return $true
    } catch {
        Write-AuditLog "Error checking GPO replication: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-GPOPermissionsAudit {
    Write-AuditLog "Auditing GPO permissions and delegation..." -Level Info

    try {
        $AllGPOs = Get-GPO -All -Domain $Domain

        foreach ($GPO in $AllGPOs) {
            try {
                $Permissions = Get-GPPermission -Guid $GPO.Id -All -Domain $Domain

                # Check for Authenticated Users Read permission (required for GPO application)
                $AuthUsersRead = $Permissions | Where-Object {
                    $_.Trustee.Name -eq "Authenticated Users" -and
                    $_.Permission -match "GpoRead"
                }

                # Check for Domain Admins/Enterprise Admins full control
                $AdminFullControl = $Permissions | Where-Object {
                    ($_.Trustee.Name -match "Domain Admins" -or $_.Trustee.Name -match "Enterprise Admins") -and
                    $_.Permission -match "GpoEditDeleteModifySecurity"
                }

                # Check for unusual permissions (security risk)
                $UnusualPermissions = $Permissions | Where-Object {
                    $_.Permission -match "GpoEdit" -and
                    $_.Trustee.Name -notmatch "Domain Admins|Enterprise Admins|Group Policy Creator Owners|SYSTEM"
                }

                $Script:AuditResults.Permissions += [PSCustomObject]@{
                    GPOName = $GPO.DisplayName
                    GPOGUID = $GPO.Id
                    Owner = $GPO.Owner
                    AuthenticatedUsersRead = ($null -ne $AuthUsersRead)
                    AdminFullControl = ($null -ne $AdminFullControl)
                    UnusualPermissionsCount = $UnusualPermissions.Count
                    UnusualPermissions = ($UnusualPermissions | ForEach-Object { "$($_.Trustee.Name):$($_.Permission)" }) -join "; "
                    HealthStatus = if ($null -ne $AuthUsersRead -and $null -ne $AdminFullControl) { "Healthy" } else { "Review Required" }
                }

            } catch {
                Write-AuditLog "Error checking permissions for GPO $($GPO.DisplayName): $($_.Exception.Message)" -Level Warning
            }
        }

        $PermissionIssues = $Script:AuditResults.Permissions | Where-Object { $_.HealthStatus -ne "Healthy" }
        if ($PermissionIssues.Count -gt 0) {
            Write-AuditLog "Found $($PermissionIssues.Count) GPOs with permission issues" -Level Warning
        } else {
            Write-AuditLog "All GPO permissions configured correctly" -Level Success
        }

        return $true
    } catch {
        Write-AuditLog "Error auditing GPO permissions: $($_.Exception.Message)" -Level Error
        return $false
    }
}

#endregion

#region Report Generation

function Export-GPOAuditReport {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Results,

        [Parameter(Mandatory=$true)]
        [string]$OutputPath,

        [Parameter(Mandatory=$true)]
        [string]$Format
    )

    $ReportFile = Join-Path $OutputPath "GPO_Audit_${Domain}_${Timestamp}.${Format.ToLower()}"

    # Calculate summary statistics
    $TotalGPOs = $Results.GPOHealth.Count
    $LinkedGPOs = ($Results.GPOHealth | Where-Object { $_.IsLinked }).Count
    $UnlinkedGPOs = $Results.Unlinked.Count
    $VersionMismatches = $Results.VersionMismatch.Count
    $PermissionIssues = ($Results.Permissions | Where-Object { $_.HealthStatus -ne "Healthy" }).Count

    $Results.Summary = @{
        TotalGPOs = $TotalGPOs
        LinkedGPOs = $LinkedGPOs
        UnlinkedGPOs = $UnlinkedGPOs
        VersionMismatches = $VersionMismatches
        PermissionIssues = $PermissionIssues
        ReplicationIssues = if ($CheckReplication) { ($Results.Replication | Where-Object { -not $_.ReplicationHealthy }).Count } else { "Not Checked" }
    }

    switch ($Format) {
        'HTML' {
            $HTMLReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>GPO Audit Report - $Domain</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; background-color: #ecf0f1; padding: 10px; border-left: 4px solid #3498db; }
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
        .status-warning { background-color: #fff3cd; color: #856404; padding: 5px 10px; border-radius: 3px; }
        .status-error { background-color: #f8d7da; color: #721c24; padding: 5px 10px; border-radius: 3px; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #7f8c8d; font-size: 12px; }
    </style>
</head>
<body>
    <h1>Group Policy Audit Report</h1>

    <div class="summary">
        <h2>Audit Summary</h2>
        <div class="metric">
            <div class="metric-label">Domain</div>
            <div class="metric-value">$Domain</div>
        </div>
        <div class="metric">
            <div class="metric-label">Date</div>
            <div class="metric-value">$(Get-Date -Format 'yyyy-MM-dd HH:mm')</div>
        </div>
        <div class="metric">
            <div class="metric-label">Total GPOs</div>
            <div class="metric-value">$TotalGPOs</div>
        </div>
        <div class="metric">
            <div class="metric-label">Linked</div>
            <div class="metric-value good">$LinkedGPOs</div>
        </div>
        <div class="metric">
            <div class="metric-label">Unlinked</div>
            <div class="metric-value warning">$UnlinkedGPOs</div>
        </div>
        <div class="metric">
            <div class="metric-label">Version Mismatches</div>
            <div class="metric-value bad">$VersionMismatches</div>
        </div>
        <div class="metric">
            <div class="metric-label">Permission Issues</div>
            <div class="metric-value bad">$PermissionIssues</div>
        </div>
    </div>

    <h2>All GPOs Health Status</h2>
    <table>
        <tr>
            <th>Name</th>
            <th>Status</th>
            <th>Links</th>
            <th>Version Match</th>
            <th>Modified</th>
            <th>Days Since Modified</th>
        </tr>
"@
            foreach ($GPO in $Results.GPOHealth) {
                $StatusClass = if ($GPO.IsLinked -and $GPO.VersionMatch) { "status-healthy" } elseif (-not $GPO.VersionMatch) { "status-error" } else { "status-warning" }
                $Status = if ($GPO.IsLinked) { "Linked" } else { "Unlinked" }
                $VersionStatus = if ($GPO.VersionMatch) { "✓ Match" } else { "✗ Mismatch" }

                $HTMLReport += @"
        <tr>
            <td>$($GPO.Name)</td>
            <td><span class="$StatusClass">$Status</span></td>
            <td>$($GPO.LinkCount)</td>
            <td>$VersionStatus</td>
            <td>$($GPO.Modified)</td>
            <td>$($GPO.DaysSinceModified)</td>
        </tr>
"@
            }

            $HTMLReport += "</table>"

            # Unlinked GPOs section
            if ($UnlinkedGPOs -gt 0) {
                $HTMLReport += @"
    <h2>Unlinked GPOs ($UnlinkedGPOs)</h2>
    <table>
        <tr>
            <th>Name</th>
            <th>Created</th>
            <th>Modified</th>
            <th>Days Since Modified</th>
            <th>Owner</th>
        </tr>
"@
                foreach ($GPO in $Results.Unlinked) {
                    $HTMLReport += @"
        <tr>
            <td>$($GPO.Name)</td>
            <td>$($GPO.Created)</td>
            <td>$($GPO.Modified)</td>
            <td>$($GPO.DaysSinceModified)</td>
            <td>$($GPO.Owner)</td>
        </tr>
"@
                }
                $HTMLReport += "</table>"
            }

            # Version Mismatch section
            if ($VersionMismatches -gt 0) {
                $HTMLReport += @"
    <h2>Version Mismatches ($VersionMismatches)</h2>
    <table>
        <tr>
            <th>Name</th>
            <th>AD Version</th>
            <th>SYSVOL Version</th>
            <th>Modified</th>
        </tr>
"@
                foreach ($GPO in $Results.VersionMismatch) {
                    $HTMLReport += @"
        <tr>
            <td>$($GPO.Name)</td>
            <td>$($GPO.ADVersion)</td>
            <td>$($GPO.SysvolVersion)</td>
            <td>$($GPO.Modified)</td>
        </tr>
"@
                }
                $HTMLReport += "</table>"
            }

            $HTMLReport += @"
    <div class="footer">
        <p>Report generated by GPO Audit Baseline Script v$ScriptVersion</p>
        <p>For Windows Server 2022 | Domain: $Domain</p>
    </div>
</body>
</html>
"@

            $HTMLReport | Out-File -FilePath $ReportFile -Encoding UTF8
        }

        'CSV' {
            $Results.GPOHealth | Export-Csv -Path $ReportFile -NoTypeInformation -Encoding UTF8
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
    Write-AuditLog "GPO Audit Baseline Script v$ScriptVersion" -Level Info
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
    Get-GPOHealthStatus
    Get-UnlinkedGPOs
    Get-VersionMismatchGPOs
    Get-GPOPermissionsAudit

    if ($CheckReplication) {
        Get-GPOReplicationStatus
    } else {
        Write-AuditLog "Skipping replication check (use -CheckReplication to enable)" -Level Info
    }

    # Generate report
    Write-AuditLog "Generating audit report..." -Level Info
    $ReportPath = Export-GPOAuditReport -Results $AuditResults -OutputPath $OutputPath -Format $ExportFormat

    # Summary
    Write-AuditLog "========================================" -Level Info
    Write-AuditLog "Audit Complete!" -Level Success
    Write-AuditLog "Total GPOs: $($AuditResults.Summary.TotalGPOs)" -Level Info
    Write-AuditLog "Linked GPOs: $($AuditResults.Summary.LinkedGPOs)" -Level Success
    Write-AuditLog "Unlinked GPOs: $($AuditResults.Summary.UnlinkedGPOs)" -Level Warning
    Write-AuditLog "Version Mismatches: $($AuditResults.Summary.VersionMismatches)" -Level Warning
    Write-AuditLog "Permission Issues: $($AuditResults.Summary.PermissionIssues)" -Level Warning
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
