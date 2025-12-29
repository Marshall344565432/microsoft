function Get-ReportCSS {
    <#
    .SYNOPSIS
        Returns CSS styles for HTML reports.

    .DESCRIPTION
        Generates CSS based on selected template.
        Internal helper function for Export-ReportToHTML.

    .PARAMETER Template
        Template name: Default, Executive, Technical, Minimal.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Default', 'Executive', 'Technical', 'Minimal')]
        [string]$Template = 'Default'
    )

    # Color schemes
    $colors = switch ($Template) {
        'Executive' {
            @{
                Primary   = '#1a237e'
                Secondary = '#283593'
                Success   = '#2e7d32'
                Warning   = '#f57c00'
                Danger    = '#c62828'
                Light     = '#f5f5f5'
                Dark      = '#212121'
            }
        }
        'Technical' {
            @{
                Primary   = '#01579b'
                Secondary = '#0277bd'
                Success   = '#00695c'
                Warning   = '#f57f17'
                Danger    = '#b71c1c'
                Light     = '#eceff1'
                Dark      = '#263238'
            }
        }
        'Minimal' {
            @{
                Primary   = '#424242'
                Secondary = '#616161'
                Success   = '#66bb6a'
                Warning   = '#ffa726'
                Danger    = '#ef5350'
                Light     = '#fafafa'
                Dark      = '#212121'
            }
        }
        default {  # Default
            @{
                Primary   = '#0078d4'
                Secondary = '#106ebe'
                Success   = '#107c10'
                Warning   = '#ff8c00'
                Danger    = '#d13438'
                Light     = '#f3f2f1'
                Dark      = '#323130'
            }
        }
    }

    return @"
<style>
    :root {
        --primary-color: $($colors.Primary);
        --secondary-color: $($colors.Secondary);
        --success-color: $($colors.Success);
        --warning-color: $($colors.Warning);
        --danger-color: $($colors.Danger);
        --light-gray: $($colors.Light);
        --dark-gray: $($colors.Dark);
    }

    * {
        box-sizing: border-box;
    }

    body {
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        margin: 0;
        padding: 0;
        background-color: #faf9f8;
        color: var(--dark-gray);
        line-height: 1.6;
    }

    .report-header {
        background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
        color: white;
        padding: 40px 20px;
        margin-bottom: 30px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }

    .header-content {
        max-width: 1200px;
        margin: 0 auto;
    }

    .company-logo {
        max-height: 60px;
        max-width: 200px;
        margin-bottom: 20px;
    }

    .report-header h1 {
        margin: 0 0 10px 0;
        font-size: 2.5em;
        font-weight: 300;
    }

    .description {
        font-size: 1.1em;
        margin: 10px 0;
        opacity: 0.95;
    }

    .meta {
        opacity: 0.9;
        font-size: 0.9em;
        margin-top: 15px;
    }

    .report-body {
        max-width: 1200px;
        margin: 0 auto;
        padding: 0 20px 40px;
    }

    .section {
        background: white;
        border-radius: 8px;
        padding: 30px;
        margin-bottom: 25px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.08);
    }

    .section h2 {
        color: var(--primary-color);
        border-bottom: 2px solid var(--light-gray);
        padding-bottom: 12px;
        margin-top: 0;
        margin-bottom: 20px;
        font-size: 1.8em;
        font-weight: 400;
    }

    .section-description {
        color: #666;
        font-style: italic;
        margin-bottom: 20px;
    }

    table {
        width: 100%;
        border-collapse: collapse;
        margin: 20px 0;
        font-size: 0.95em;
    }

    th, td {
        padding: 14px 16px;
        text-align: left;
        border-bottom: 1px solid var(--light-gray);
    }

    th {
        background-color: var(--primary-color);
        color: white;
        font-weight: 600;
        position: sticky;
        top: 0;
        z-index: 10;
    }

    th.sortable {
        cursor: pointer;
        user-select: none;
        position: relative;
        padding-right: 30px;
    }

    th.sortable:hover {
        background-color: var(--secondary-color);
    }

    th.sortable::after {
        content: '⇅';
        position: absolute;
        right: 10px;
        opacity: 0.5;
    }

    th.sort-asc::after {
        content: '↑';
        opacity: 1;
    }

    th.sort-desc::after {
        content: '↓';
        opacity: 1;
    }

    tbody tr:hover {
        background-color: #f5f5f5;
    }

    tbody tr:nth-child(even) {
        background-color: #fafafa;
    }

    .chart-container {
        margin: 20px 0;
        padding: 20px;
        background: #f9f9f9;
        border-radius: 4px;
    }

    .chart-bar {
        margin: 8px 0;
    }

    .chart-label {
        display: inline-block;
        width: 150px;
        font-weight: 500;
    }

    .chart-value {
        display: inline-block;
        background: var(--primary-color);
        color: white;
        padding: 6px 12px;
        border-radius: 3px;
        margin-left: 10px;
        min-width: 40px;
        text-align: center;
    }

    .chart-fill {
        display: inline-block;
        height: 28px;
        background: linear-gradient(90deg, var(--primary-color), var(--secondary-color));
        border-radius: 3px;
        vertical-align: middle;
        margin-left: 10px;
    }

    .footer {
        text-align: center;
        padding: 30px 20px;
        background: var(--light-gray);
        color: #666;
        font-size: 0.9em;
        margin-top: 40px;
    }

    .footer p {
        margin: 5px 0;
    }

    .status-success {
        color: var(--success-color);
        font-weight: 600;
    }

    .status-warning {
        color: var(--warning-color);
        font-weight: 600;
    }

    .status-danger {
        color: var(--danger-color);
        font-weight: 600;
    }

    @media print {
        body {
            background: white;
        }
        .section {
            box-shadow: none;
            border: 1px solid #ddd;
            page-break-inside: avoid;
        }
        .report-header {
            page-break-after: avoid;
        }
        th {
            background-color: var(--primary-color) !important;
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
        }
    }

    @media (max-width: 768px) {
        .report-header {
            padding: 20px 10px;
        }
        .report-header h1 {
            font-size: 1.8em;
        }
        .section {
            padding: 15px;
        }
        table {
            font-size: 0.85em;
        }
        th, td {
            padding: 10px 8px;
        }
    }
</style>
"@
}
