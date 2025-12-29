function Export-ReportToExcel {
    <#
    .SYNOPSIS
        Exports an enterprise report to Excel format.

    .DESCRIPTION
        Generates an Excel workbook with formatted sheets for each section/table.
        Requires the ImportExcel PowerShell module.

    .PARAMETER Report
        The report object from New-EnterpriseReport.

    .PARAMETER Path
        Output file path for the Excel workbook.

    .PARAMETER AutoSize
        Auto-size columns to fit content.

    .PARAMETER FreezeTopRow
        Freeze the top row (headers).

    .PARAMETER TableStyle
        Excel table style name. Defaults to 'Medium6'.

    .EXAMPLE
        $report | Export-ReportToExcel -Path "C:\Reports\Report.xlsx" -AutoSize -FreezeTopRow

    .EXAMPLE
        $report | Export-ReportToExcel -Path "C:\Reports\Report.xlsx" -TableStyle "Light1"
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
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
        [switch]$AutoSize,

        [Parameter(Mandatory = $false)]
        [switch]$FreezeTopRow,

        [Parameter(Mandatory = $false)]
        [string]$TableStyle = 'Medium6'
    )

    process {
        # Check for ImportExcel module
        if (-not (Get-Module -Name ImportExcel -ListAvailable)) {
            throw "ImportExcel module is required for Excel export. Install with: Install-Module -Name ImportExcel"
        }

        try {
            Import-Module ImportExcel -ErrorAction Stop

            # Remove existing file
            if (Test-Path $Path) {
                Remove-Item $Path -Force
            }

            $sheetNum = 0

            # Export sections
            foreach ($section in $Report.Sections) {
                if ($section.Data) {
                    $sheetNum++
                    $sheetName = "$sheetNum-$($section.Name)" -replace '[^\w\s-]', '' | Select-Object -First 31

                    $excelParams = @{
                        Path          = $Path
                        WorksheetName = $sheetName
                        TableStyle    = $TableStyle
                    }

                    if ($AutoSize) { $excelParams['AutoSize'] = $true }
                    if ($FreezeTopRow) { $excelParams['FreezeTopRow'] = $true }

                    $section.Data | Export-Excel @excelParams
                }
            }

            # Export tables
            foreach ($table in $Report.Tables) {
                if ($table.Data) {
                    $sheetNum++
                    $sheetName = "$sheetNum-$($table.Name)" -replace '[^\w\s-]', '' | Select-Object -First 31

                    $excelParams = @{
                        Path          = $Path
                        WorksheetName = $sheetName
                        TableStyle    = $TableStyle
                    }

                    if ($AutoSize) { $excelParams['AutoSize'] = $true }
                    if ($FreezeTopRow) { $excelParams['FreezeTopRow'] = $true }

                    if ($table.Columns) {
                        $table.Data | Select-Object -Property $table.Columns | Export-Excel @excelParams
                    }
                    else {
                        $table.Data | Export-Excel @excelParams
                    }
                }
            }

            # Add summary sheet
            $summaryData = [PSCustomObject]@{
                ReportTitle   = $Report.Title
                Description   = $Report.Description
                Author        = $Report.Author
                Company       = $Report.CompanyName
                Generated     = $Report.CreatedAt.ToString('yyyy-MM-dd HH:mm:ss')
                GeneratedOn   = $Report.GeneratedOn
                SectionCount  = $Report.Sections.Count
                TableCount    = $Report.Tables.Count
                ChartCount    = $Report.Charts.Count
            }

            $summaryData | Export-Excel -Path $Path -WorksheetName "Summary" -AutoSize -MoveToStart

            return [PSCustomObject]@{
                Path       = $Path
                Size       = (Get-Item $Path).Length
                Sheets     = $sheetNum + 1
                ExportDate = [DateTime]::UtcNow
            }
        }
        catch {
            throw "Failed to export report to Excel: $($_.Exception.Message)"
        }
    }
}
