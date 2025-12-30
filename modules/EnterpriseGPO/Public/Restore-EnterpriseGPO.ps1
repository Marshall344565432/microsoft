function Restore-EnterpriseGPO {
    <#
    .SYNOPSIS
        Restores a Group Policy Object from backup.

    .DESCRIPTION
        Restores a GPO from a backup created by Backup-EnterpriseGPO or Backup-GPO.
        Supports restoring to a new GPO or overwriting an existing one.

    .PARAMETER BackupId
        GUID of the backup to restore.

    .PARAMETER BackupPath
        Path to the backup directory.

    .PARAMETER TargetName
        Name for the restored GPO. If not specified, uses the original name.

    .PARAMETER CreateNew
        Create a new GPO instead of restoring to the original.

    .PARAMETER RestoreLinks
        Restore OU links and permissions from metadata (requires metadata file).

    .EXAMPLE
        Restore-EnterpriseGPO -BackupId "{12345678-1234-1234-1234-123456789012}" -BackupPath "C:\GPOBackups\GPO_Backup_20250127"
        Restore a GPO from backup.

    .EXAMPLE
        Restore-EnterpriseGPO -BackupId "{12345678-1234-1234-1234-123456789012}" -BackupPath "C:\GPOBackups\GPO_Backup_20250127" -CreateNew -TargetName "Restored_Policy"
        Restore backup to a new GPO with a different name.

    .OUTPUTS
        PSCustomObject with restore details.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [guid]$BackupId,

        [Parameter(Mandatory = $true)]
        [string]$BackupPath,

        [Parameter(Mandatory = $false)]
        [string]$TargetName,

        [Parameter(Mandatory = $false)]
        [switch]$CreateNew,

        [Parameter(Mandatory = $false)]
        [switch]$RestoreLinks
    )

    process {
        try {
            # Verify backup exists
            $backupGpoPath = Join-Path $BackupPath $BackupId.ToString("B")

            if (-not (Test-Path $backupGpoPath)) {
                throw "Backup not found: $backupGpoPath"
            }

            # Read backup metadata
            $bkupInfoPath = Join-Path $backupGpoPath "bkupInfo.xml"
            if (-not (Test-Path $bkupInfoPath)) {
                throw "Backup info file not found: $bkupInfoPath"
            }

            [xml]$bkupInfo = Get-Content $bkupInfoPath
            $originalName = $bkupInfo.BackupInst.GPODisplayName.'#cdata-section'

            Write-Verbose "Backup GPO Name: $originalName"

            if ($PSCmdlet.ShouldProcess($originalName, "Restore GPO")) {
                if ($CreateNew) {
                    # Create new GPO
                    $newGPOName = if ($TargetName) { $TargetName } else { "$originalName (Restored)" }

                    Write-Verbose "Creating new GPO: $newGPOName"
                    $newGPO = New-GPO -Name $newGPOName -ErrorAction Stop

                    # Import settings from backup
                    Import-GPO -BackupId $BackupId -Path $BackupPath -TargetGuid $newGPO.Id -ErrorAction Stop

                    $restoredGPO = $newGPO
                }
                else {
                    # Restore to existing GPO (overwrite)
                    $existingGPO = try {
                        Get-GPO -Name $originalName -ErrorAction Stop
                    }
                    catch {
                        # GPO doesn't exist, create it
                        Write-Verbose "Original GPO not found, creating: $originalName"
                        New-GPO -Name $originalName -ErrorAction Stop
                    }

                    # Import settings
                    Import-GPO -BackupId $BackupId -Path $BackupPath -TargetGuid $existingGPO.Id -ErrorAction Stop

                    $restoredGPO = Get-GPO -Guid $existingGPO.Id
                }

                # Restore links and permissions if metadata exists
                if ($RestoreLinks) {
                    $metadataPath = Join-Path $backupGpoPath "metadata.json"

                    if (Test-Path $metadataPath) {
                        Write-Verbose "Restoring links and permissions from metadata..."

                        $metadata = Get-Content $metadataPath | ConvertFrom-Json

                        # Restore OU links
                        if ($metadata.Links) {
                            foreach ($link in $metadata.Links) {
                                try {
                                    Write-Verbose "Linking to: $($link.Target)"
                                    New-GPLink -Guid $restoredGPO.Id -Target $link.Target -LinkEnabled $link.Enabled -Order $link.Order -ErrorAction SilentlyContinue
                                }
                                catch {
                                    Write-Warning "Failed to restore link to $($link.Target): $_"
                                }
                            }
                        }

                        # Restore permissions
                        if ($metadata.Permissions) {
                            foreach ($permission in $metadata.Permissions) {
                                try {
                                    Set-GPPermission -Guid $restoredGPO.Id `
                                        -TargetName $permission.Trustee `
                                        -TargetType $permission.TrusteeType `
                                        -PermissionLevel $permission.Permission `
                                        -ErrorAction SilentlyContinue
                                }
                                catch {
                                    Write-Warning "Failed to restore permission for $($permission.Trustee): $_"
                                }
                            }
                        }
                    }
                    else {
                        Write-Warning "Metadata file not found. Links and permissions not restored."
                    }
                }

                return [PSCustomObject]@{
                    PSTypeName    = 'EnterpriseGPO.RestoreResult'
                    GPOName       = $restoredGPO.DisplayName
                    GPOGUID       = $restoredGPO.Id
                    BackupId      = $BackupId
                    CreatedNew    = $CreateNew.IsPresent
                    LinksRestored = $RestoreLinks.IsPresent
                    Success       = $true
                }
            }

        }
        catch {
            Write-Error "Failed to restore GPO: $_"
            return [PSCustomObject]@{
                PSTypeName = 'EnterpriseGPO.RestoreResult'
                GPOName    = $null
                BackupId   = $BackupId
                Success    = $false
                Error      = $_.Exception.Message
            }
        }
    }
}
