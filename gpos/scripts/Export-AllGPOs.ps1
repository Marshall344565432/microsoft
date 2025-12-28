<#
.SYNOPSIS
    Exports all Group Policy Objects from a domain for backup or migration.

.DESCRIPTION
    Creates comprehensive backups of all GPOs including settings, links,
    permissions, and WMI filters. Generates a manifest file for easy
    restoration and includes retention policy for old backups.

.PARAMETER BackupPath
    Root directory for GPO backups. Creates timestamped subdirectories.

.PARAMETER RetentionDays
    Number of days to retain old backups. Default is 90 days.

.PARAMETER IncludeLinks
    Export GPO link information to JSON file.

.PARAMETER IncludePermissions
    Export GPO permission ACLs to JSON file.

.PARAMETER Compress
    Compress the backup folder to a ZIP file after export.

.PARAMETER Domain
    Target domain to export GPOs from. Defaults to current domain.

.EXAMPLE
    .\Export-AllGPOs.ps1 -BackupPath "C:\Backup\GPO"

.EXAMPLE
    .\Export-AllGPOs.ps1 -BackupPath "\\fileserver\GPOBackups" `
        -RetentionDays 30 `
        -IncludeLinks `
        -IncludePermissions `
        -Compress

.EXAMPLE
    .\Export-AllGPOs.ps1 -BackupPath "D:\GPO-Backups" -Domain "contoso.com"

.NOTES
    Requires:
    - PowerShell 5.1 or higher
    - GroupPolicy module (RSAT-GPMC)
    - Domain Admin or delegated GPO management permissions

    Author: Enterprise IT Team
    Version: 1.0.0
    Date: 2025-12-27
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({
        $parent = if (Test-Path $_) { $_ } else { Split-Path $_ -Parent }
        if (Test-Path $parent -PathType Container) { $true }
        else { throw "Parent directory does not exist: $parent" }
    })]
    [string]$BackupPath,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 365)]
    [int]$RetentionDays = 90,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeLinks,

    [Parameter(Mandatory = $false)]
    [switch]$IncludePermissions,

    [Parameter(Mandatory = $false)]
    [switch]$Compress,

    [Parameter(Mandatory = $false)]
    [string]$Domain = $env:USERDNSDOMAIN,

    [Parameter(Mandatory = $false)]
    [PSCredential]$Credential
)

#Requires -Modules GroupPolicy

# Initialize
$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($PSBoundParameters['Verbose']) { 'Continue' } else { 'SilentlyContinue' }

# Script functions
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        'ERROR'   { Write-Host $logMessage -ForegroundColor Red }
        'WARNING' { Write-Host $logMessage -ForegroundColor Yellow }
        'SUCCESS' { Write-Host $logMessage -ForegroundColor Green }
        default   { Write-Host $logMessage }
    }
}

# Main execution
try {
    Write-Log "Starting GPO export for domain: $Domain"

    # Verify GroupPolicy module
    if (-not (Get-Module -Name GroupPolicy -ListAvailable)) {
        throw "GroupPolicy module not found. Install RSAT-GPMC: Install-WindowsFeature RSAT-GPMC"
    }

    Import-Module GroupPolicy

    # Create backup directory
    if (-not (Test-Path $BackupPath)) {
        New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
        Write-Log "Created backup root directory: $BackupPath"
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupFolder = Join-Path $BackupPath "GPOBackup_$timestamp"
    New-Item -Path $backupFolder -ItemType Directory -Force | Out-Null
    Write-Log "Created backup folder: $backupFolder"

    $gpoDataFolder = Join-Path $backupFolder 'GPOData'
    New-Item -Path $gpoDataFolder -ItemType Directory -Force | Out-Null

    # Initialize manifest
    $manifest = @{
        BackupDate     = [DateTime]::UtcNow.ToString('o')
        BackupFolder   = $backupFolder
        DomainName     = $Domain
        BackedUpBy     = "$env:USERDOMAIN\$env:USERNAME"
        MachineName    = $env:COMPUTERNAME
        GPOs           = [System.Collections.ArrayList]::new()
        Statistics     = @{
            Total   = 0
            Success = 0
            Failed  = 0
        }
    }

    # Get all GPOs
    $gpoParams = @{
        All    = $true
        Domain = $Domain
    }
    if ($Credential) { $gpoParams['Server'] = $Domain }

    $allGPOs = Get-GPO @gpoParams
    $manifest.Statistics.Total = $allGPOs.Count
    Write-Log "Found $($allGPOs.Count) GPOs to backup"

    # Progress tracking
    $progressParams = @{
        Activity = 'Backing up Group Policy Objects'
        Status   = 'Initializing...'
    }

    # Backup each GPO
    $counter = 0
    foreach ($gpo in $allGPOs) {
        $counter++
        $percentComplete = [math]::Round(($counter / $allGPOs.Count) * 100)

        Write-Progress @progressParams `
            -Status "Processing $($gpo.DisplayName) ($counter of $($allGPOs.Count))" `
            -PercentComplete $percentComplete

        Write-Verbose "Backing up GPO: $($gpo.DisplayName) [GUID: $($gpo.Id)]"

        try {
            # Backup GPO
            $backupParams = @{
                Guid   = $gpo.Id
                Path   = $gpoDataFolder
                Domain = $Domain
            }
            if ($Credential) { $backupParams['Server'] = $Domain }

            $backup = Backup-GPO @backupParams

            $gpoInfo = @{
                Name              = $gpo.DisplayName
                Id                = $gpo.Id.ToString()
                BackupId          = $backup.Id.ToString()
                Status            = 'Success'
                CreationTime      = $gpo.CreationTime
                ModificationTime  = $gpo.ModificationTime
                UserVersionNumber = $gpo.UserVersion
                ComputerVersionNumber = $gpo.ComputerVersion
                WmiFilter         = $gpo.WmiFilter.Name
                Description       = $gpo.Description
            }

            # Export HTML report
            $reportPath = Join-Path $gpoDataFolder "$($gpo.Id)_Report.html"
            $reportParams = @{
                Guid       = $gpo.Id
                ReportType = 'Html'
                Path       = $reportPath
                Domain     = $Domain
            }
            if ($Credential) { $reportParams['Server'] = $Domain }

            Get-GPOReport @reportParams

            # Include links if requested
            if ($IncludeLinks) {
                try {
                    $xmlReport = Get-GPOReport -Guid $gpo.Id -ReportType Xml -Domain $Domain
                    [xml]$xmlData = $xmlReport
                    $links = $xmlData.GPO.LinksTo

                    if ($links) {
                        $gpoInfo.Links = @($links | ForEach-Object {
                            @{
                                SOMPath    = $_.SOMPath
                                SOMName    = $_.SOMName
                                Enabled    = $_.Enabled
                                NoOverride = $_.NoOverride
                            }
                        })
                    }
                }
                catch {
                    Write-Verbose "Could not export links for GPO: $($gpo.DisplayName)"
                }
            }

            # Include permissions if requested
            if ($IncludePermissions) {
                try {
                    $perms = Get-GPPermission -Guid $gpo.Id -All -Domain $Domain
                    $gpoInfo.Permissions = @($perms | ForEach-Object {
                        @{
                            Trustee    = $_.Trustee.Name
                            TrusteeSid = $_.Trustee.Sid.Value
                            Permission = $_.Permission.ToString()
                            Inherited  = $_.Inherited
                            Denied     = $_.Denied
                        }
                    })
                }
                catch {
                    Write-Verbose "Could not export permissions for GPO: $($gpo.DisplayName)"
                }
            }

            $manifest.GPOs.Add($gpoInfo) | Out-Null
            $manifest.Statistics.Success++

            Write-Log "Successfully backed up: $($gpo.DisplayName)"
        }
        catch {
            $failInfo = @{
                Name   = $gpo.DisplayName
                Id     = $gpo.Id.ToString()
                Status = 'Failed'
                Error  = $_.Exception.Message
            }
            $manifest.GPOs.Add($failInfo) | Out-Null
            $manifest.Statistics.Failed++

            Write-Log "Failed to backup GPO: $($gpo.DisplayName) - $($_.Exception.Message)" -Level WARNING
        }
    }

    Write-Progress @progressParams -Completed

    # Save manifest
    $manifestPath = Join-Path $backupFolder 'BackupManifest.json'
    $manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $manifestPath -Encoding UTF8
    Write-Log "Backup manifest saved: $manifestPath"

    # Create summary report
    $summaryPath = Join-Path $backupFolder 'BackupSummary.txt'
    $summary = @"
GPO Backup Summary
==================
Backup Date: $($manifest.BackupDate)
Domain: $($manifest.DomainName)
Backup Location: $backupFolder

Statistics:
-----------
Total GPOs: $($manifest.Statistics.Total)
Successful: $($manifest.Statistics.Success)
Failed: $($manifest.Statistics.Failed)

Backed Up By: $($manifest.BackedUpBy)
Machine: $($manifest.MachineName)

Failed GPOs:
$(if ($manifest.Statistics.Failed -gt 0) {
    $manifest.GPOs | Where-Object Status -eq 'Failed' | ForEach-Object {
        "  - $($_.Name): $($_.Error)"
    }
} else {
    "  None"
})

"@
    $summary | Out-File -FilePath $summaryPath -Encoding UTF8

    # Compress if requested
    if ($Compress) {
        Write-Log "Compressing backup folder..."
        $archivePath = "$backupFolder.zip"

        try {
            Compress-Archive -Path $backupFolder -DestinationPath $archivePath -Force
            Remove-Item -Path $backupFolder -Recurse -Force
            Write-Log "Backup compressed to: $archivePath" -Level SUCCESS
            $finalPath = $archivePath
        }
        catch {
            Write-Log "Failed to compress backup: $($_.Exception.Message)" -Level WARNING
            $finalPath = $backupFolder
        }
    }
    else {
        $finalPath = $backupFolder
    }

    # Cleanup old backups
    Write-Log "Cleaning up backups older than $RetentionDays days..."
    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)

    $oldBackups = Get-ChildItem -Path $BackupPath -Directory -Filter 'GPOBackup_*' |
        Where-Object { $_.CreationTime -lt $cutoffDate }

    $oldBackupsZip = Get-ChildItem -Path $BackupPath -File -Filter 'GPOBackup_*.zip' |
        Where-Object { $_.CreationTime -lt $cutoffDate }

    $totalRemoved = 0
    foreach ($oldBackup in ($oldBackups + $oldBackupsZip)) {
        try {
            Remove-Item -Path $oldBackup.FullName -Recurse -Force
            Write-Verbose "Removed old backup: $($oldBackup.Name)"
            $totalRemoved++
        }
        catch {
            Write-Log "Failed to remove old backup: $($oldBackup.Name)" -Level WARNING
        }
    }

    if ($totalRemoved -gt 0) {
        Write-Log "Removed $totalRemoved old backup(s)"
    }

    # Final summary
    Write-Log "=" * 70
    Write-Log "GPO Backup Completed Successfully" -Level SUCCESS
    Write-Log "=" * 70
    Write-Log "Backup Location: $finalPath"
    Write-Log "Total GPOs: $($manifest.Statistics.Total)"
    Write-Log "Successful: $($manifest.Statistics.Success)"
    Write-Log "Failed: $($manifest.Statistics.Failed)"
    Write-Log "Manifest: $manifestPath"
    Write-Log "Summary: $summaryPath"
    Write-Log "=" * 70

    # Return result object
    [PSCustomObject]@{
        BackupPath     = $finalPath
        ManifestPath   = $manifestPath
        SummaryPath    = $summaryPath
        TotalGPOs      = $manifest.Statistics.Total
        SuccessCount   = $manifest.Statistics.Success
        FailCount      = $manifest.Statistics.Failed
        BackupDate     = [DateTime]::Parse($manifest.BackupDate)
        Compressed     = $Compress.IsPresent
    }
}
catch {
    Write-Log "GPO export failed: $($_.Exception.Message)" -Level ERROR
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level ERROR
    exit 1
}
