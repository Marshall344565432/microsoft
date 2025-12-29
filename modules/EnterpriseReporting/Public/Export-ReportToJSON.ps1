function Export-ReportToJSON {
    <#
    .SYNOPSIS
        Exports an enterprise report to JSON format.

    .DESCRIPTION
        Generates a JSON file containing the entire report structure
        suitable for API consumption or automation.

    .PARAMETER Report
        The report object from New-EnterpriseReport.

    .PARAMETER Path
        Output file path for JSON export.

    .PARAMETER Depth
        JSON depth for nested objects. Default is 10.

    .PARAMETER Compress
        Create compressed (single-line) JSON.

    .EXAMPLE
        $report | Export-ReportToJSON -Path "C:\Reports\report.json"

    .EXAMPLE
        $report | Export-ReportToJSON -Path "C:\Reports\report.json" -Compress
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
        [ValidateRange(1, 100)]
        [int]$Depth = 10,

        [Parameter(Mandatory = $false)]
        [switch]$Compress
    )

    process {
        try {
            $jsonParams = @{
                Depth = $Depth
            }
            if ($Compress) { $jsonParams['Compress'] = $true }

            $json = $Report | ConvertTo-Json @jsonParams
            $json | Out-File -FilePath $Path -Encoding UTF8 -Force

            return [PSCustomObject]@{
                Path       = $Path
                Size       = (Get-Item $Path).Length
                ExportDate = [DateTime]::UtcNow
                Compressed = $Compress.IsPresent
            }
        }
        catch {
            throw "Failed to export report to JSON: $($_.Exception.Message)"
        }
    }
}
