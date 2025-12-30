function Get-GPOReport {
    <#
    .SYNOPSIS
        Generates comprehensive GPO reports with enhanced formatting.

    .DESCRIPTION
        Creates detailed GPO reports in HTML or XML format with additional
        metadata including links, permissions, and WMI filters.
        Extends the built-in Get-GPOReport with additional features.

    .PARAMETER GPOName
        Name of the GPO to report on. If not specified, reports on all GPOs.

    .PARAMETER ReportType
        Type of report: HTML or XML. Default is HTML.

    .PARAMETER OutputPath
        Path to save the report file.

    .PARAMETER IncludeLinks
        Include OU links in the report.

    .PARAMETER IncludePermissions
        Include GPO permissions in the report.

    .PARAMETER Template
        Report template: Standard, Executive, Technical. Default is Standard.

    .EXAMPLE
        Get-GPOReport -GPOName "Default Domain Policy" -OutputPath "C:\Reports\GPOReport.html"
        Generate HTML report for a single GPO.

    .EXAMPLE
        Get-GPOReport -OutputPath "C:\Reports\AllGPOs.html" -IncludeLinks -IncludePermissions
        Generate comprehensive report for all GPOs with links and permissions.

    .OUTPUTS
        PSCustomObject with report details.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$GPOName,

        [Parameter(Mandatory = $false)]
        [ValidateSet('HTML', 'XML')]
        [string]$ReportType = 'HTML',

        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeLinks,

        [Parameter(Mandatory = $false)]
        [switch]$IncludePermissions,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Standard', 'Executive', 'Technical')]
        [string]$Template = 'Standard'
    )

    process {
        try {
            $gpos = if ($GPOName) {
                @(Get-GPO -Name $GPOName -ErrorAction Stop)
            }
            else {
                Get-GPO -All
            }

            Write-Verbose "Generating report for $($gpos.Count) GPO(s)"

            $reportData = foreach ($gpo in $gpos) {
                Write-Verbose "Processing: $($gpo.DisplayName)"

                # Get basic report
                $gpoReport = Microsoft.GroupPolicy.Commands\Get-GPOReport -Guid $gpo.Id -ReportType $ReportType

                # Get additional metadata
                $gpoData = [PSCustomObject]@{
                    Name             = $gpo.DisplayName
                    GUID             = $gpo.Id
                    CreatedTime      = $gpo.CreationTime
                    ModifiedTime     = $gpo.ModificationTime
                    UserVersion      = $gpo.User.DSVersion
                    ComputerVersion  = $gpo.Computer.DSVersion
                    WMIFilter        = $gpo.WmiFilter.Name
                    Description      = $gpo.Description
                    Report           = $gpoReport
                }

                # Add links if requested
                if ($IncludeLinks) {
                    try {
                        $links = Get-ADObject -Filter "gPLink -like '*$($gpo.Id)*'" -Properties gPLink, distinguishedName |
                            ForEach-Object {
                            [PSCustomObject]@{
                                OU      = $_.distinguishedName
                                Enabled = $true
                            }
                        }
                        $gpoData | Add-Member -MemberType NoteProperty -Name 'Links' -Value $links
                    }
                    catch {
                        Write-Warning "Failed to get links for $($gpo.DisplayName): $_"
                    }
                }

                # Add permissions if requested
                if ($IncludePermissions) {
                    try {
                        $permissions = Get-GPPermission -Guid $gpo.Id -All |
                            Select-Object Trustee, TrusteeType, Permission

                        $gpoData | Add-Member -MemberType NoteProperty -Name 'Permissions' -Value $permissions
                    }
                    catch {
                        Write-Warning "Failed to get permissions for $($gpo.DisplayName): $_"
                    }
                }

                $gpoData
            }

            # Save report if output path specified
            if ($OutputPath) {
                if ($ReportType -eq 'HTML' -and $gpos.Count -gt 1) {
                    # Create combined HTML report
                    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Group Policy Report - $($gpos.Count) GPOs</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #003366; }
        h2 { color: #0066cc; margin-top: 30px; }
        table { border-collapse: collapse; width: 100%; margin-top: 10px; }
        th { background-color: #003366; color: white; padding: 10px; text-align: left; }
        td { border: 1px solid #ddd; padding: 8px; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .metadata { color: #666; font-size: 0.9em; }
        .gpo-section { margin-bottom: 50px; border-bottom: 2px solid #003366; padding-bottom: 20px; }
    </style>
</head>
<body>
    <h1>Group Policy Report</h1>
    <div class="metadata">
        <p><strong>Domain:</strong> $env:USERDNSDOMAIN</p>
        <p><strong>Generated:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p><strong>Generated By:</strong> $env:USERNAME</p>
        <p><strong>Total GPOs:</strong> $($gpos.Count)</p>
    </div>
"@

                    foreach ($gpoInfo in $reportData) {
                        $htmlContent += "<div class='gpo-section'>`n"
                        $htmlContent += "<h2>$($gpoInfo.Name)</h2>`n"
                        $htmlContent += $gpoInfo.Report
                        $htmlContent += "</div>`n"
                    }

                    $htmlContent += "</body></html>"
                    $htmlContent | Set-Content -Path $OutputPath -Encoding UTF8
                }
                else {
                    # Single GPO or XML report
                    $reportData[0].Report | Set-Content -Path $OutputPath -Encoding UTF8
                }

                Write-Verbose "Report saved to: $OutputPath"
            }

            return [PSCustomObject]@{
                PSTypeName = 'EnterpriseGPO.ReportResult'
                GPOCount   = $gpos.Count
                ReportType = $ReportType
                OutputPath = $OutputPath
                ReportDate = Get-Date
                GPOData    = $reportData
            }

        }
        catch {
            Write-Error "Failed to generate GPO report: $_"
            throw
        }
    }
}
