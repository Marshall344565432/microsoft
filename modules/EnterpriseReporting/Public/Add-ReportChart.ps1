function Add-ReportChart {
    <#
    .SYNOPSIS
        Adds a chart to an enterprise report.

    .DESCRIPTION
        Adds a chart visualization to the report. Supports bar, pie, and line charts.

    .PARAMETER Report
        The report object from New-EnterpriseReport.

    .PARAMETER Name
        Chart name/title.

    .PARAMETER ChartData
        Hashtable with labels and values. Example: @{Labels=@('A','B'); Values=@(10,20)}

    .PARAMETER Type
        Chart type: Bar, Pie, Line.

    .EXAMPLE
        $report = New-EnterpriseReport -Title "Usage Report"
        $chartData = @{
            Labels = @('Windows 10', 'Windows 11', 'Windows Server')
            Values = @(150, 200, 50)
        }
        $report | Add-ReportChart -Name "OS Distribution" -ChartData $chartData -Type Pie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSTypeName('EnterpriseReport')]
        $Report,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if (-not $_.ContainsKey('Labels') -or -not $_.ContainsKey('Values')) {
                throw "ChartData must contain 'Labels' and 'Values' keys"
            }
            $true
        })]
        [hashtable]$ChartData,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Bar', 'Pie', 'Line')]
        [string]$Type = 'Bar'
    )

    process {
        $Report.AddChart($Name, $ChartData, $Type)
        return $Report
    }
}
