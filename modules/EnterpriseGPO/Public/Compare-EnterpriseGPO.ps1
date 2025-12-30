function Compare-EnterpriseGPO {
    <#
    .SYNOPSIS
        Compares two Group Policy Objects or a GPO with a backup.

    .DESCRIPTION
        Performs detailed comparison between GPOs to identify differences in settings.
        Can compare two live GPOs or a GPO against a backup.
        Generates HTML diff report highlighting changes.

    .PARAMETER ReferenceGPO
        Name of the reference GPO.

    .PARAMETER DifferenceGPO
        Name of the GPO to compare against the reference.

    .PARAMETER BackupPath
        Path to backup directory (for comparing against backup).

    .PARAMETER BackupId
        GUID of the backup to compare against.

    .PARAMETER OutputPath
        Path to save the comparison report HTML file.

    .EXAMPLE
        Compare-EnterpriseGPO -ReferenceGPO "Default Domain Policy" -DifferenceGPO "Custom Domain Policy"
        Compare two live GPOs.

    .EXAMPLE
        Compare-EnterpriseGPO -ReferenceGPO "Default Domain Policy" -BackupPath "C:\GPOBackups" -BackupId "{12345678-1234-1234-1234-123456789012}"
        Compare a live GPO against a backup.

    .OUTPUTS
        PSCustomObject with comparison results.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReferenceGPO,

        [Parameter(Mandatory = $false)]
        [string]$DifferenceGPO,

        [Parameter(Mandatory = $false)]
        [string]$BackupPath,

        [Parameter(Mandatory = $false)]
        [guid]$BackupId,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    process {
        try {
            Write-Verbose "Comparing GPOs..."

            # Get reference GPO
            $refGPO = Get-GPO -Name $ReferenceGPO -ErrorAction Stop

            # Get reference GPO report
            $refReport = Get-GPOReport -Name $ReferenceGPO -ReportType Xml

            # Get difference GPO report
            if ($DifferenceGPO) {
                Write-Verbose "Comparing against live GPO: $DifferenceGPO"
                $diffGPO = Get-GPO -Name $DifferenceGPO -ErrorAction Stop
                $diffReport = Get-GPOReport -Name $DifferenceGPO -ReportType Xml
                $diffName = $DifferenceGPO
            }
            elseif ($BackupPath -and $BackupId) {
                Write-Verbose "Comparing against backup: $BackupId"

                # Get backup report
                $backupGpoPath = Join-Path $BackupPath $BackupId.ToString("B")
                if (-not (Test-Path $backupGpoPath)) {
                    throw "Backup not found: $backupGpoPath"
                }

                # Read backup info
                $bkupInfoPath = Join-Path $backupGpoPath "bkupInfo.xml"
                [xml]$bkupInfo = Get-Content $bkupInfoPath
                $diffName = "$($bkupInfo.BackupInst.GPODisplayName.'#cdata-section') (Backup)"

                # Create temporary GPO to import backup for comparison
                $tempGPO = New-GPO -Name "TempCompare_$([guid]::NewGuid())" -ErrorAction Stop

                try {
                    Import-GPO -BackupId $BackupId -Path $BackupPath -TargetGuid $tempGPO.Id -ErrorAction Stop
                    $diffReport = Get-GPOReport -Guid $tempGPO.Id -ReportType Xml
                }
                finally {
                    Remove-GPO -Guid $tempGPO.Id -ErrorAction SilentlyContinue
                }
            }
            else {
                throw "Must specify either -DifferenceGPO or both -BackupPath and -BackupId"
            }

            # Compare settings
            $differences = Compare-GPOSettings -ReferenceXml $refReport -DifferenceXml $diffReport

            # Generate HTML report if output path specified
            if ($OutputPath) {
                $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>GPO Comparison Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #003366; }
        h2 { color: #0066cc; margin-top: 30px; }
        table { border-collapse: collapse; width: 100%; margin-top: 10px; }
        th { background-color: #003366; color: white; padding: 10px; text-align: left; }
        td { border: 1px solid #ddd; padding: 8px; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .added { background-color: #d4edda; }
        .removed { background-color: #f8d7da; }
        .modified { background-color: #fff3cd; }
        .metadata { color: #666; font-size: 0.9em; margin-top: 20px; }
    </style>
</head>
<body>
    <h1>GPO Comparison Report</h1>
    <div class="metadata">
        <p><strong>Reference GPO:</strong> $ReferenceGPO</p>
        <p><strong>Difference GPO:</strong> $diffName</p>
        <p><strong>Comparison Date:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p><strong>Differences Found:</strong> $($differences.Count)</p>
    </div>

    <h2>Differences</h2>
    <table>
        <thead>
            <tr>
                <th>Type</th>
                <th>Setting</th>
                <th>Reference Value</th>
                <th>Difference Value</th>
            </tr>
        </thead>
        <tbody>
"@

                foreach ($diff in $differences) {
                    $rowClass = switch ($diff.ChangeType) {
                        'Added' { 'added' }
                        'Removed' { 'removed' }
                        'Modified' { 'modified' }
                        default { '' }
                    }

                    $htmlReport += @"
            <tr class="$rowClass">
                <td>$($diff.ChangeType)</td>
                <td>$($diff.Setting)</td>
                <td>$($diff.ReferenceValue)</td>
                <td>$($diff.DifferenceValue)</td>
            </tr>
"@
                }

                $htmlReport += @"
        </tbody>
    </table>
</body>
</html>
"@

                $htmlReport | Set-Content -Path $OutputPath -Encoding UTF8
                Write-Verbose "Comparison report saved to: $OutputPath"
            }

            return [PSCustomObject]@{
                PSTypeName        = 'EnterpriseGPO.CompareResult'
                ReferenceGPO      = $ReferenceGPO
                DifferenceGPO     = $diffName
                DifferencesFound  = $differences.Count
                Differences       = $differences
                ReportPath        = $OutputPath
                ComparisonDate    = Get-Date
            }

        }
        catch {
            Write-Error "Failed to compare GPOs: $_"
            throw
        }
    }
}
