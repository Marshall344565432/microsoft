function Rotate-LogFile {
    <#
    .SYNOPSIS
        Rotates log files when they exceed maximum size.

    .DESCRIPTION
        Checks log file size and rotates (renames with timestamp) if it exceeds
        the configured maximum. Maintains retention policy by removing old logs.
        Internal helper function for Write-EnterpriseLog.

    .PARAMETER LogFile
        Path to the log file to check for rotation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )

    try {
        if (Test-Path $LogFile) {
            $fileInfo = Get-Item $LogFile
            $sizeMB = $fileInfo.Length / 1MB

            if ($sizeMB -ge $script:LogConfiguration.MaxLogSizeMB) {
                # Rotate the log file
                $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
                $directory = Split-Path $LogFile -Parent
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($LogFile)
                $extension = [System.IO.Path]::GetExtension($LogFile)

                $rotatedName = "$baseName`_$timestamp$extension"
                $rotatedPath = Join-Path $directory $rotatedName

                Move-Item -Path $LogFile -Destination $rotatedPath -Force
                Write-Verbose "Rotated log file: $LogFile -> $rotatedPath"

                # Cleanup old log files
                $logPattern = "$baseName`_*$extension"
                $oldLogs = Get-ChildItem -Path $directory -Filter $logPattern |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -Skip $script:LogConfiguration.MaxLogFiles

                foreach ($oldLog in $oldLogs) {
                    Remove-Item -Path $oldLog.FullName -Force
                    Write-Verbose "Removed old log file: $($oldLog.Name)"
                }
            }
        }
    }
    catch {
        Write-Verbose "Log rotation failed: $($_.Exception.Message)"
    }
}
