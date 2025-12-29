function Export-ReportToCSV {
    <#
    .SYNOPSIS
        Exports an enterprise report to CSV format.

    .DESCRIPTION
        Generates CSV files for each section and table in the report.
        Creates a summary file with report metadata.

    .PARAMETER Report
        The report object from New-EnterpriseReport.

    .PARAMETER Path
        Output directory or file path for CSV export.

    .PARAMETER Encoding
        File encoding. Defaults to UTF8.

    .PARAMETER NoTypeInformation
        Omit type information in CSV files.

    .EXAMPLE
        $report | Export-ReportToCSV -Path "C:\Reports\ADReport"

    .EXAMPLE
        $report | Export-ReportToCSV -Path "C:\Reports" -Encoding ASCII
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSTypeName('EnterpriseReport')]
        $Report,

        [Parameter(Mandatory = $true)]
        [ValidateScript({
            $parent = Split-Path $_ -Parent
            if ($parent -and -not (Test-Path $parent -PathType Container)) {
                throw "Parent directory does not exist: $parent"
            }
            $true
        })]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet('ASCII', 'UTF8', 'UTF7', 'UTF32', 'Unicode', 'BigEndianUnicode', 'Default', 'OEM')]
        [string]$Encoding = 'UTF8',

        [Parameter(Mandatory = $false)]
        [switch]$NoTypeInformation
    )

    process {
        try {
            # Determine if Path is directory or file
            $isDirectory = (Test-Path $Path -PathType Container) -or (-not (Split-Path $Path -Leaf).Contains('.'))

            if ($isDirectory) {
                $outputDir = $Path
                if (-not (Test-Path $outputDir)) {
                    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
                }
            }
            else {
                $outputDir = Split-Path $Path -Parent
                if (-not $outputDir) { $outputDir = Get-Location }
            }

            $baseName = $Report.Title -replace '[^\w\s-]', '' -replace '\s+', '_'
            $files = @()

            # Export sections
            $sectionNum = 0
            foreach ($section in $Report.Sections) {
                $sectionNum++
                if ($section.Data) {
                    $sectionFile = Join-Path $outputDir "$baseName`_Section$sectionNum`_$($section.Name -replace '[^\w\s-]', '').csv"

                    $exportParams = @{
                        Path     = $sectionFile
                        Encoding = $Encoding
                    }
                    if ($NoTypeInformation) { $exportParams['NoTypeInformation'] = $true }

                    $section.Data | Export-Csv @exportParams
                    $files += $sectionFile
                }
            }

            # Export tables
            $tableNum = 0
            foreach ($table in $Report.Tables) {
                $tableNum++
                if ($table.Data) {
                    $tableFile = Join-Path $outputDir "$baseName`_Table$tableNum`_$($table.Name -replace '[^\w\s-]', '').csv"

                    $exportParams = @{
                        Path     = $tableFile
                        Encoding = $Encoding
                    }
                    if ($NoTypeInformation) { $exportParams['NoTypeInformation'] = $true }

                    if ($table.Columns) {
                        $table.Data | Select-Object -Property $table.Columns | Export-Csv @exportParams
                    }
                    else {
                        $table.Data | Export-Csv @exportParams
                    }

                    $files += $tableFile
                }
            }

            # Create summary file
            $summaryFile = Join-Path $outputDir "$baseName`_Summary.txt"
            $summary = @"
Report Summary
==============
Title: $($Report.Title)
Description: $($Report.Description)
Author: $($Report.Author)
Generated: $($Report.CreatedAt.ToString('yyyy-MM-dd HH:mm:ss')) UTC
Generated On: $($Report.GeneratedOn)
Company: $($Report.CompanyName)

Sections: $($Report.Sections.Count)
Tables: $($Report.Tables.Count)
Charts: $($Report.Charts.Count)

Exported Files:
$(($files | ForEach-Object { "  - $(Split-Path $_ -Leaf)" }) -join "`n")
"@

            $summary | Out-File -FilePath $summaryFile -Encoding $Encoding
            $files += $summaryFile

            return [PSCustomObject]@{
                OutputDirectory = $outputDir
                Files           = $files
                FileCount       = $files.Count
                ExportDate      = [DateTime]::UtcNow
            }
        }
        catch {
            throw "Failed to export report to CSV: $($_.Exception.Message)"
        }
    }
}
