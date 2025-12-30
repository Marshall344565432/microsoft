function Backup-EnterpriseGPO {
    <#
    .SYNOPSIS
        Backs up Group Policy Objects to a specified location.

    .DESCRIPTION
        Creates backups of one or all GPOs with metadata including links and permissions.
        Supports retention policies and compression for archival storage.

    .PARAMETER GPOName
        Name of the GPO to backup. If not specified, backs up all GPOs.

    .PARAMETER BackupPath
        Directory path where backups will be stored.

    .PARAMETER Compress
        Compress the backup into a ZIP file.

    .PARAMETER IncludeMetadata
        Include detailed metadata file with GPO links, permissions, and WMI filters.

    .PARAMETER RetentionDays
        Number of days to keep old backups. Older backups will be deleted.

    .PARAMETER Comment
        Optional comment to include in the backup metadata.

    .EXAMPLE
        Backup-EnterpriseGPO -GPOName "Default Domain Policy" -BackupPath "C:\GPOBackups"
        Backup a single GPO.

    .EXAMPLE
        Backup-EnterpriseGPO -BackupPath "C:\GPOBackups" -Compress -IncludeMetadata
        Backup all GPOs with metadata and compression.

    .EXAMPLE
        Backup-EnterpriseGPO -BackupPath "C:\GPOBackups" -RetentionDays 30
        Backup all GPOs and delete backups older than 30 days.

    .OUTPUTS
        PSCustomObject with backup details including path, size, and GPO count.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$GPOName,

        [Parameter(Mandatory = $true)]
        [string]$BackupPath,

        [Parameter(Mandatory = $false)]
        [switch]$Compress,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeMetadata,

        [Parameter(Mandatory = $false)]
        [int]$RetentionDays = 0,

        [Parameter(Mandatory = $false)]
        [string]$Comment
    )

    begin {
        # Ensure backup path exists
        if (-not (Test-Path $BackupPath)) {
            if ($PSCmdlet.ShouldProcess($BackupPath, "Create backup directory")) {
                New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
                Write-Verbose "Created backup directory: $BackupPath"
            }
        }

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupFolder = Join-Path $BackupPath "GPO_Backup_$timestamp"
        $gpoCount = 0
        $totalSize = 0
    }

    process {
        try {
            if ($PSCmdlet.ShouldProcess("GPOs", "Backup")) {
                # Create backup folder
                New-Item -Path $backupFolder -ItemType Directory -Force | Out-Null

                # Get GPOs to backup
                if ($GPOName) {
                    $gpos = @(Get-GPO -Name $GPOName -ErrorAction Stop)
                    Write-Verbose "Backing up GPO: $GPOName"
                }
                else {
                    $gpos = Get-GPO -All
                    Write-Verbose "Backing up all GPOs ($($gpos.Count) total)"
                }

                # Backup each GPO
                foreach ($gpo in $gpos) {
                    Write-Verbose "Backing up: $($gpo.DisplayName)"

                    $backupResult = Backup-GPO -Guid $gpo.Id -Path $backupFolder -ErrorAction Stop

                    if ($IncludeMetadata) {
                        # Get additional metadata
                        $metadata = Get-GPOBackupInfo -GPO $gpo

                        $metadataPath = Join-Path $backupFolder "$($backupResult.Id)\metadata.json"
                        $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataPath
                    }

                    $gpoCount++
                }

                # Create backup manifest
                $manifest = [PSCustomObject]@{
                    BackupDate      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    BackupUser      = $env:USERNAME
                    DomainName      = $env:USERDNSDOMAIN
                    GPOCount        = $gpoCount
                    Comment         = $Comment
                    IncludeMetadata = $IncludeMetadata.IsPresent
                    GPOs            = $gpos | ForEach-Object {
                        [PSCustomObject]@{
                            Name        = $_.DisplayName
                            GUID        = $_.Id
                            CreatedTime = $_.CreationTime
                            ModifiedTime = $_.ModificationTime
                        }
                    }
                }

                $manifestPath = Join-Path $backupFolder "backup_manifest.json"
                $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath

                # Calculate total size
                $totalSize = (Get-ChildItem -Path $backupFolder -Recurse -File |
                    Measure-Object -Property Length -Sum).Sum

                # Compress if requested
                $finalPath = $backupFolder
                if ($Compress) {
                    Write-Verbose "Compressing backup..."
                    $zipPath = "$backupFolder.zip"

                    # Use .NET compression
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::CreateFromDirectory($backupFolder, $zipPath)

                    # Remove uncompressed folder
                    Remove-Item -Path $backupFolder -Recurse -Force
                    $finalPath = $zipPath

                    $totalSize = (Get-Item $zipPath).Length
                }

                # Apply retention policy
                if ($RetentionDays -gt 0) {
                    Write-Verbose "Applying retention policy: $RetentionDays days"
                    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)

                    $pattern = if ($Compress) { "GPO_Backup_*.zip" } else { "GPO_Backup_*" }

                    Get-ChildItem -Path $BackupPath -Filter $pattern |
                        Where-Object {
                        if ($Compress) { -not $_.PSIsContainer } else { $_.PSIsContainer }
                    } |
                        Where-Object { $_.CreationTime -lt $cutoffDate } |
                        ForEach-Object {
                        Write-Verbose "Removing old backup: $($_.Name)"
                        Remove-Item -Path $_.FullName -Recurse -Force
                    }
                }

                # Return backup info
                return [PSCustomObject]@{
                    PSTypeName   = 'EnterpriseGPO.BackupResult'
                    BackupPath   = $finalPath
                    GPOCount     = $gpoCount
                    TotalSizeKB  = [math]::Round($totalSize / 1KB, 2)
                    Compressed   = $Compress.IsPresent
                    BackupDate   = Get-Date
                    Success      = $true
                }
            }

        }
        catch {
            Write-Error "Failed to backup GPO(s): $_"
            return [PSCustomObject]@{
                PSTypeName = 'EnterpriseGPO.BackupResult'
                BackupPath = $null
                GPOCount   = 0
                Success    = $false
                Error      = $_.Exception.Message
            }
        }
    }
}
