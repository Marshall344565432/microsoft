function ConvertTo-HTMLChart {
    <#
    .SYNOPSIS
        Converts chart data to HTML representation.

    .DESCRIPTION
        Generates simple HTML bar chart visualization.
        Internal helper function for Export-ReportToHTML.

    .PARAMETER ChartData
        Hashtable with Labels and Values.

    .PARAMETER Type
        Chart type: Bar, Pie, Line.

    .PARAMETER Name
        Chart name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ChartData,

        [Parameter(Mandatory = $false)]
        [string]$Type = 'Bar',

        [Parameter(Mandatory = $false)]
        [string]$Name
    )

    $labels = $ChartData.Labels
    $values = $ChartData.Values

    if (-not $labels -or -not $values) {
        return "                <p><em>No chart data available</em></p>`n"
    }

    # Calculate max value for scaling
    $maxValue = ($values | Measure-Object -Maximum).Maximum
    if ($maxValue -eq 0) { $maxValue = 1 }

    $html = ""

    switch ($Type) {
        'Bar' {
            for ($i = 0; $i -lt $labels.Count; $i++) {
                $label = $labels[$i]
                $value = $values[$i]
                $percentage = [math]::Round(($value / $maxValue) * 100)

                $html += @"
                <div class="chart-bar">
                    <span class="chart-label">$label</span>
                    <span class="chart-value">$value</span>
                    <span class="chart-fill" style="width: $percentage%; max-width: 400px;"></span>
                </div>

"@
            }
        }

        'Pie' {
            # Simple table representation for pie chart
            $total = ($values | Measure-Object -Sum).Sum
            if ($total -eq 0) { $total = 1 }

            $html += "                <table style=`"width: auto;`">`n"
            $html += "                    <thead><tr><th>Category</th><th>Value</th><th>Percentage</th></tr></thead>`n"
            $html += "                    <tbody>`n"

            for ($i = 0; $i -lt $labels.Count; $i++) {
                $label = $labels[$i]
                $value = $values[$i]
                $percentage = [math]::Round(($value / $total) * 100, 1)

                $html += "                        <tr><td>$label</td><td>$value</td><td>$percentage%</td></tr>`n"
            }

            $html += "                    </tbody>`n"
            $html += "                </table>`n"
        }

        'Line' {
            # Simple bar representation for line chart
            $html += "                <p><strong>Line Chart Data:</strong></p>`n"
            $html += "                <table style=`"width: auto;`">`n"
            $html += "                    <thead><tr><th>Point</th><th>Value</th></tr></thead>`n"
            $html += "                    <tbody>`n"

            for ($i = 0; $i -lt $labels.Count; $i++) {
                $html += "                        <tr><td>$($labels[$i])</td><td>$($values[$i])</td></tr>`n"
            }

            $html += "                    </tbody>`n"
            $html += "                </table>`n"
        }
    }

    return $html
}
