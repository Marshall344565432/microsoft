function ConvertTo-HTMLTable {
    <#
    .SYNOPSIS
        Converts data to an HTML table.

    .DESCRIPTION
        Generates an HTML table with sortable columns.
        Internal helper function for Export-ReportToHTML.

    .PARAMETER Data
        Array of objects to convert to table.

    .PARAMETER Columns
        Optional array of properties to display.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Data,

        [Parameter(Mandatory = $false)]
        [string[]]$Columns
    )

    if (-not $Data -or $Data.Count -eq 0) {
        return "            <p><em>No data available</em></p>`n"
    }

    # Get properties to display
    $properties = if ($Columns) {
        $Columns
    }
    elseif ($Data[0] -is [hashtable]) {
        $Data[0].Keys
    }
    else {
        $Data[0].PSObject.Properties.Name
    }

    # Build table header
    $html = "            <table>`n"
    $html += "                <thead>`n"
    $html += "                    <tr>`n"

    foreach ($prop in $properties) {
        $html += "                        <th class=`"sortable`">$prop</th>`n"
    }

    $html += "                    </tr>`n"
    $html += "                </thead>`n"
    $html += "                <tbody>`n"

    # Build table rows
    foreach ($item in $Data) {
        $html += "                    <tr>`n"

        foreach ($prop in $properties) {
            $value = if ($item -is [hashtable]) {
                $item[$prop]
            }
            else {
                $item.$prop
            }

            # Handle null values
            if ($null -eq $value) {
                $value = ''
            }

            # Format boolean values
            if ($value -is [bool]) {
                $value = if ($value) { 'Yes' } else { 'No' }
            }

            # Format dates
            if ($value -is [datetime]) {
                $value = $value.ToString('yyyy-MM-dd HH:mm:ss')
            }

            # Escape HTML
            $value = [System.Web.HttpUtility]::HtmlEncode($value.ToString())

            $html += "                        <td>$value</td>`n"
        }

        $html += "                    </tr>`n"
    }

    $html += "                </tbody>`n"
    $html += "            </table>`n"

    return $html
}
