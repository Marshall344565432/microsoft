function Add-ReportTable {
    <#
    .SYNOPSIS
        Adds a table to an enterprise report.

    .DESCRIPTION
        Adds a formatted table with optional column selection to the report.

    .PARAMETER Report
        The report object from New-EnterpriseReport.

    .PARAMETER Name
        Table name/caption.

    .PARAMETER Data
        Data for the table (array of objects).

    .PARAMETER Columns
        Optional array of column names to display. Defaults to all properties.

    .EXAMPLE
        $report = New-EnterpriseReport -Title "Server Inventory"
        $servers = Get-ADComputer -Filter {OperatingSystem -like "*Server*"} -Properties OperatingSystem
        $report | Add-ReportTable -Name "Windows Servers" -Data $servers -Columns @('Name', 'OperatingSystem', 'Enabled')

    .EXAMPLE
        $report | Add-ReportTable -Name "Statistics" -Data $statsData
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
        [AllowEmptyCollection()]
        [object[]]$Data,

        [Parameter(Mandatory = $false)]
        [string[]]$Columns
    )

    process {
        $Report.AddTable($Name, $Data, $Columns)
        return $Report
    }
}
