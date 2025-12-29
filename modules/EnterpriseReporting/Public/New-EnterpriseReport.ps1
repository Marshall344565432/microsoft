function New-EnterpriseReport {
    <#
    .SYNOPSIS
        Creates a new enterprise report object.

    .DESCRIPTION
        Initializes a report object that can be populated with sections,
        tables, and charts, then exported to multiple formats.

    .PARAMETER Title
        Report title.

    .PARAMETER Description
        Report description/summary.

    .PARAMETER Author
        Report author name. Defaults to current user.

    .PARAMETER Template
        HTML template to use: Default, Executive, Technical, Minimal.

    .PARAMETER CompanyName
        Company name for branding.

    .PARAMETER LogoPath
        Path to company logo image file.

    .EXAMPLE
        $report = New-EnterpriseReport -Title "AD Health Report" -Author "IT Team"
        $report | Add-ReportSection -Name "Users" -Data $userData
        $report | Export-ReportToHTML -Path "C:\Reports\ADHealth.html"

    .EXAMPLE
        $report = New-EnterpriseReport -Title "Monthly Stats" -Template Executive -CompanyName "Contoso Corp"
        $report | Add-ReportTable -Name "Statistics" -Data $stats
        $report | Export-ReportToHTML -Path "report.html" -Open
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter(Mandatory = $false)]
        [string]$Description = '',

        [Parameter(Mandatory = $false)]
        [string]$Author = "$env:USERDOMAIN\$env:USERNAME",

        [Parameter(Mandatory = $false)]
        [ValidateSet('Default', 'Executive', 'Technical', 'Minimal')]
        [string]$Template = 'Default',

        [Parameter(Mandatory = $false)]
        [string]$CompanyName = 'Your Organization',

        [Parameter(Mandatory = $false)]
        [ValidateScript({
            if ($_ -and -not (Test-Path $_)) {
                throw "Logo file not found: $_"
            }
            $true
        })]
        [string]$LogoPath
    )

    $report = [PSCustomObject]@{
        PSTypeName    = 'EnterpriseReport'
        Id            = [guid]::NewGuid().ToString()
        Title         = $Title
        Description   = $Description
        Author        = $Author
        CompanyName   = $CompanyName
        LogoPath      = $LogoPath
        Template      = $Template
        CreatedAt     = [DateTime]::UtcNow
        GeneratedOn   = $env:COMPUTERNAME
        Sections      = [System.Collections.ArrayList]::new()
        Tables        = [System.Collections.ArrayList]::new()
        Charts        = [System.Collections.ArrayList]::new()
        Summary       = @{}
        Metadata      = @{}
    }

    # Add methods to the report object
    $report | Add-Member -MemberType ScriptMethod -Name 'AddSection' -Value {
        param([string]$Name, [object]$Data, [string]$Description)
        $section = @{
            Name        = $Name
            Data        = $Data
            Description = $Description
            Order       = $this.Sections.Count + 1
        }
        $this.Sections.Add($section) | Out-Null
    }

    $report | Add-Member -MemberType ScriptMethod -Name 'AddTable' -Value {
        param([string]$Name, [object]$Data, [string[]]$Columns)
        $table = @{
            Name    = $Name
            Data    = $Data
            Columns = $Columns
            Order   = $this.Tables.Count + 1
        }
        $this.Tables.Add($table) | Out-Null
    }

    $report | Add-Member -MemberType ScriptMethod -Name 'AddChart' -Value {
        param([string]$Name, [hashtable]$ChartData, [string]$Type = 'Bar')
        $chart = @{
            Name      = $Name
            Data      = $ChartData
            Type      = $Type
            Order     = $this.Charts.Count + 1
        }
        $this.Charts.Add($chart) | Out-Null
    }

    return $report
}
