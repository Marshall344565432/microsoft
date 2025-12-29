function Add-ReportSection {
    <#
    .SYNOPSIS
        Adds a section to an enterprise report.

    .DESCRIPTION
        Adds a named section with data and optional description to the report.
        Sections appear in the order they are added.

    .PARAMETER Report
        The report object from New-EnterpriseReport.

    .PARAMETER Name
        Section name/title.

    .PARAMETER Data
        Data to include in the section (objects, arrays, etc.).

    .PARAMETER Description
        Optional description for the section.

    .EXAMPLE
        $report = New-EnterpriseReport -Title "User Report"
        $users = Get-ADUser -Filter * -Properties Department
        $report | Add-ReportSection -Name "Active Directory Users" -Data $users -Description "All enabled users"

    .EXAMPLE
        $report | Add-ReportSection -Name "Summary" -Data @{TotalUsers=100; ActiveUsers=95} -Description "User statistics"
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
        [AllowNull()]
        [object]$Data,

        [Parameter(Mandatory = $false)]
        [string]$Description = ''
    )

    process {
        $Report.AddSection($Name, $Data, $Description)
        return $Report
    }
}
