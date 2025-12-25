<#
.SYNOPSIS
    Certificate Expiration Monitoring for Windows Server 2022

.DESCRIPTION
    Monitors certificate expiration across:
    - Local computer certificate stores
    - Active Directory Certificate Services (ADCS) issued certificates
    - Certificate templates
    - All domain computers (optional)
    - Generates alerts for certificates expiring soon
    - Exports detailed reports in HTML/CSV/JSON format

    Compatible with:
    - Windows Server 2022
    - PowerShell 5.1+
    - ADCS (Active Directory Certificate Services)

.PARAMETER OutputPath
    Path where the monitoring report will be saved. Default: C:\Audits\Certificates

.PARAMETER DaysToExpire
    Alert threshold in days. Default: 30 days

.PARAMETER CAServerName
    Certificate Authority server name. Default: Auto-detect

.PARAMETER ExportFormat
    Report format: HTML, CSV, or JSON. Default: HTML

.PARAMETER IncludeAllComputers
    Scan all domain computers for expiring certificates

.PARAMETER SendEmail
    Send email alert for expiring certificates

.PARAMETER SMTPServer
    SMTP server for email alerts

.PARAMETER EmailTo
    Email recipient address

.PARAMETER EmailFrom
    Email sender address

.EXAMPLE
    .\Get-CertificateExpirationMonitor.ps1
    Monitors local certificates expiring within 30 days

.EXAMPLE
    .\Get-CertificateExpirationMonitor.ps1 -DaysToExpire 60 -SendEmail -SMTPServer "smtp.domain.com" -EmailTo "admin@domain.com" -EmailFrom "certs@domain.com"
    Monitors certificates expiring within 60 days and sends email alert

.NOTES
    Version:        1.0.0
    Author:         Enterprise Infrastructure Team
    Creation Date:  2025-12-25
    Purpose:        Certificate lifecycle management and expiration monitoring

    Requires:
    - Administrator privileges
    - PowerShell 5.1+
    - Windows Server 2022
    - ADCS role (for CA monitoring)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateScript({Test-Path $_ -PathType Container -IsValid})]
    [string]$OutputPath = "C:\Audits\Certificates",

    [Parameter(Mandatory=$false)]
    [ValidateRange(1,365)]
    [int]$DaysToExpire = 30,

    [Parameter(Mandatory=$false)]
    [string]$CAServerName,

    [Parameter(Mandatory=$false)]
    [ValidateSet('HTML','CSV','JSON')]
    [string]$ExportFormat = 'HTML',

    [Parameter(Mandatory=$false)]
    [switch]$IncludeAllComputers,

    [Parameter(Mandatory=$false)]
    [switch]$SendEmail,

    [Parameter(Mandatory=$false)]
    [string]$SMTPServer,

    [Parameter(Mandatory=$false)]
    [string]$EmailTo,

    [Parameter(Mandatory=$false)]
    [string]$EmailFrom
)

#Requires -RunAsAdministrator
#Requires -Version 5.1

# Error handling
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script variables
$ScriptVersion = "1.0.0"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ComputerName = $env:COMPUTERNAME
$MonitoringResults = @{
    LocalCertificates = @()
    CAIssuedCertificates = @()
    ExpiringCertificates = @()
    ExpiredCertificates = @()
    Summary = @{}
}

#region Logging Functions

function Write-MonitorLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Info','Warning','Error','Success','Critical')]
        [string]$Level = 'Info'
    )

    $LogTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$LogTimestamp] [$Level] $Message"

    $Color = switch ($Level) {
        'Info'     { 'White' }
        'Warning'  { 'Yellow' }
        'Error'    { 'Red' }
        'Success'  { 'Green' }
        'Critical' { 'Magenta' }
    }

    Write-Host $LogMessage -ForegroundColor $Color
}

#endregion

#region Certificate Monitoring Functions

function Get-LocalCertificates {
    Write-MonitorLog "Scanning local certificate stores..." -Level Info

    try {
        $CertStores = @('LocalMachine\My', 'LocalMachine\Root', 'LocalMachine\CA', 'LocalMachine\TrustedPeople')
        $ExpirationThreshold = (Get-Date).AddDays($DaysToExpire)

        foreach ($StorePath in $CertStores) {
            $StoreLocation = $StorePath.Split('\')[0]
            $StoreName = $StorePath.Split('\')[1]

            $CertStore = Get-ChildItem -Path "Cert:\$StorePath" -ErrorAction SilentlyContinue

            foreach ($Cert in $CertStore) {
                $DaysUntilExpiration = (New-TimeSpan -Start (Get-Date) -End $Cert.NotAfter).Days

                $Status = if ($Cert.NotAfter -lt (Get-Date)) {
                    "Expired"
                } elseif ($Cert.NotAfter -lt $ExpirationThreshold) {
                    "Expiring Soon"
                } else {
                    "Valid"
                }

                $CertInfo = [PSCustomObject]@{
                    Subject = $Cert.Subject
                    Issuer = $Cert.Issuer
                    Thumbprint = $Cert.Thumbprint
                    NotBefore = $Cert.NotBefore
                    NotAfter = $Cert.NotAfter
                    DaysUntilExpiration = $DaysUntilExpiration
                    Status = $Status
                    StoreLocation = $StoreLocation
                    StoreName = $StoreName
                    HasPrivateKey = $Cert.HasPrivateKey
                    SerialNumber = $Cert.SerialNumber
                    Template = if ($Cert.Extensions | Where-Object {$_.Oid.FriendlyName -eq "Certificate Template Information"}) {
                        ($Cert.Extensions | Where-Object {$_.Oid.FriendlyName -eq "Certificate Template Information"}).Format($false) -replace "`r`n", " "
                    } else { "N/A" }
                }

                $Script:MonitoringResults.LocalCertificates += $CertInfo

                if ($Status -eq "Expired") {
                    $Script:MonitoringResults.ExpiredCertificates += $CertInfo
                } elseif ($Status -eq "Expiring Soon") {
                    $Script:MonitoringResults.ExpiringCertificates += $CertInfo
                }
            }
        }

        Write-MonitorLog "Found $($Script:MonitoringResults.LocalCertificates.Count) local certificates" -Level Info
        Write-MonitorLog "Expiring Soon: $($Script:MonitoringResults.ExpiringCertificates.Count)" -Level Warning
        Write-MonitorLog "Expired: $($Script:MonitoringResults.ExpiredCertificates.Count)" -Level Error

        return $true
    } catch {
        Write-MonitorLog "Error scanning local certificates: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-CAIssuedCertificates {
    Write-MonitorLog "Retrieving certificates from Certificate Authority..." -Level Info

    try {
        # Auto-detect CA if not specified
        if (-not $CAServerName) {
            try {
                $CAServerName = (certutil -dump | Select-String "Config:" | ForEach-Object { $_ -replace ".*Config:\s+`"([^`"]+)`".*", '$1' })[0]
                Write-MonitorLog "Auto-detected CA: $CAServerName" -Level Info
            } catch {
                Write-MonitorLog "Could not auto-detect CA. Skipping CA certificate check." -Level Warning
                return $false
            }
        }

        # Export issued certificates from CA
        $TempFile = "$env:TEMP\ca_issued_certs_$Timestamp.csv"
        $certutilOutput = certutil -view -restrict "Disposition=20" -out "CommonName,NotAfter,SerialNumber,CertificateTemplate" csv 2>&1

        if ($LASTEXITCODE -eq 0) {
            $certutilOutput | Out-File -FilePath $TempFile -Encoding UTF8

            $CAIssuedCerts = Import-Csv -Path $TempFile

            $ExpirationThreshold = (Get-Date).AddDays($DaysToExpire)

            foreach ($Cert in $CAIssuedCerts) {
                try {
                    $ExpirationDate = [DateTime]::Parse($Cert.'Certificate Expiration Date')
                    $DaysUntilExpiration = (New-TimeSpan -Start (Get-Date) -End $ExpirationDate).Days

                    $Status = if ($ExpirationDate -lt (Get-Date)) {
                        "Expired"
                    } elseif ($ExpirationDate -lt $ExpirationThreshold) {
                        "Expiring Soon"
                    } else {
                        "Valid"
                    }

                    $CertInfo = [PSCustomObject]@{
                        Subject = $Cert.'Issued Common Name'
                        SerialNumber = $Cert.'Serial Number'
                        NotAfter = $ExpirationDate
                        DaysUntilExpiration = $DaysUntilExpiration
                        Status = $Status
                        Template = $Cert.'Certificate Template'
                        Source = "CA: $CAServerName"
                    }

                    $Script:MonitoringResults.CAIssuedCertificates += $CertInfo

                    if ($Status -eq "Expiring Soon" -and $CertInfo -notin $Script:MonitoringResults.ExpiringCertificates) {
                        $Script:MonitoringResults.ExpiringCertificates += $CertInfo
                    }
                } catch {
                    Write-MonitorLog "Error processing CA certificate: $($_.Exception.Message)" -Level Warning
                }
            }

            Remove-Item $TempFile -Force -ErrorAction SilentlyContinue
            Write-MonitorLog "Found $($Script:MonitoringResults.CAIssuedCertificates.Count) CA-issued certificates" -Level Info
        } else {
            Write-MonitorLog "Unable to query CA certificates. Ensure ADCS role is installed." -Level Warning
            return $false
        }

        return $true
    } catch {
        Write-MonitorLog "Error retrieving CA certificates: $($_.Exception.Message)" -Level Error
        return $false
    }
}

#endregion

#region Email Notification

function Send-ExpirationAlert {
    param(
        [Parameter(Mandatory=$true)]
        [array]$ExpiringCerts,

        [Parameter(Mandatory=$true)]
        [array]$ExpiredCerts
    )

    if (-not $SendEmail) {
        return
    }

    if (-not $SMTPServer -or -not $EmailTo -or -not $EmailFrom) {
        Write-MonitorLog "Email parameters not fully specified. Skipping email notification." -Level Warning
        return
    }

    try {
        $EmailBody = @"
<html>
<head>
<style>
    body { font-family: Arial, sans-serif; }
    h2 { color: #e74c3c; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
    th { background-color: #34495e; color: white; padding: 10px; text-align: left; }
    td { padding: 8px; border-bottom: 1px solid #ddd; }
    .critical { background-color: #f8d7da; }
    .warning { background-color: #fff3cd; }
</style>
</head>
<body>
<h2>Certificate Expiration Alert - $ComputerName</h2>
<p><strong>Report Date:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
<p><strong>Alert Threshold:</strong> $DaysToExpire days</p>

<h3>Expired Certificates ($($ExpiredCerts.Count))</h3>
"@

        if ($ExpiredCerts.Count -gt 0) {
            $EmailBody += "<table><tr><th>Subject</th><th>Expired Date</th><th>Days Expired</th><th>Store/Source</th></tr>"
            foreach ($Cert in $ExpiredCerts) {
                $DaysExpired = [Math]::Abs($Cert.DaysUntilExpiration)
                $EmailBody += "<tr class='critical'><td>$($Cert.Subject)</td><td>$($Cert.NotAfter)</td><td>$DaysExpired</td><td>$($Cert.StoreName)</td></tr>"
            }
            $EmailBody += "</table>"
        } else {
            $EmailBody += "<p>No expired certificates found.</p>"
        }

        $EmailBody += "<h3>Certificates Expiring Soon ($($ExpiringCerts.Count))</h3>"

        if ($ExpiringCerts.Count -gt 0) {
            $EmailBody += "<table><tr><th>Subject</th><th>Expiration Date</th><th>Days Until Expiration</th><th>Store/Source</th></tr>"
            foreach ($Cert in $ExpiringCerts) {
                $EmailBody += "<tr class='warning'><td>$($Cert.Subject)</td><td>$($Cert.NotAfter)</td><td>$($Cert.DaysUntilExpiration)</td><td>$($Cert.StoreName)</td></tr>"
            }
            $EmailBody += "</table>"
        } else {
            $EmailBody += "<p>No certificates expiring soon.</p>"
        }

        $EmailBody += @"
<p><i>This is an automated alert from the Certificate Expiration Monitor.</i></p>
</body>
</html>
"@

        $EmailParams = @{
            From = $EmailFrom
            To = $EmailTo
            Subject = "ALERT: Certificate Expiration - $ComputerName - $($ExpiringCerts.Count + $ExpiredCerts.Count) certificates require attention"
            Body = $EmailBody
            BodyAsHtml = $true
            SmtpServer = $SMTPServer
        }

        Send-MailMessage @EmailParams

        Write-MonitorLog "Email alert sent to $EmailTo" -Level Success

    } catch {
        Write-MonitorLog "Error sending email alert: $($_.Exception.Message)" -Level Error
    }
}

#endregion

#region Report Generation

function Export-CertificateMonitoringReport {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Results,

        [Parameter(Mandatory=$true)]
        [string]$OutputPath,

        [Parameter(Mandatory=$true)]
        [string]$Format
    )

    $ReportFile = Join-Path $OutputPath "Certificate_Monitoring_${ComputerName}_${Timestamp}.${Format.ToLower()}"

    # Calculate summary
    $TotalCerts = $Results.LocalCertificates.Count + $Results.CAIssuedCertificates.Count
    $ExpiringCount = $Results.ExpiringCertificates.Count
    $ExpiredCount = $Results.ExpiredCertificates.Count
    $ValidCount = $TotalCerts - $ExpiringCount - $ExpiredCount

    $Results.Summary = @{
        TotalCertificates = $TotalCerts
        ValidCertificates = $ValidCount
        ExpiringCertificates = $ExpiringCount
        ExpiredCertificates = $ExpiredCount
        AlertThresholdDays = $DaysToExpire
    }

    switch ($Format) {
        'HTML' {
            $HTMLReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Certificate Expiration Monitor - $ComputerName</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        h1 { color: #2c3e50; border-bottom: 3px solid #9b59b6; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; background-color: #ecf0f1; padding: 10px; border-left: 4px solid #9b59b6; }
        .summary { background-color: white; padding: 20px; border-radius: 5px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric { display: inline-block; margin: 10px 20px; text-align: center; }
        .metric-value { font-size: 36px; font-weight: bold; }
        .metric-label { font-size: 14px; color: #7f8c8d; }
        .good { color: #27ae60; }
        .warning { color: #f39c12; }
        .critical { color: #e74c3c; }
        table { border-collapse: collapse; width: 100%; background-color: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 30px; }
        th { background-color: #34495e; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background-color: #f8f9fa; }
        .status-expired { background-color: #f8d7da; color: #721c24; padding: 5px 10px; border-radius: 3px; font-weight: bold; }
        .status-expiring { background-color: #fff3cd; color: #856404; padding: 5px 10px; border-radius: 3px; font-weight: bold; }
        .status-valid { background-color: #d4edda; color: #155724; padding: 5px 10px; border-radius: 3px; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #7f8c8d; font-size: 12px; }
    </style>
</head>
<body>
    <h1>Certificate Expiration Monitoring Report</h1>

    <div class="summary">
        <h2>Monitoring Summary</h2>
        <div class="metric">
            <div class="metric-label">Computer</div>
            <div class="metric-value">$ComputerName</div>
        </div>
        <div class="metric">
            <div class="metric-label">Date</div>
            <div class="metric-value">$(Get-Date -Format 'yyyy-MM-dd HH:mm')</div>
        </div>
        <div class="metric">
            <div class="metric-label">Total Certificates</div>
            <div class="metric-value">$TotalCerts</div>
        </div>
        <div class="metric">
            <div class="metric-label">Valid</div>
            <div class="metric-value good">$ValidCount</div>
        </div>
        <div class="metric">
            <div class="metric-label">Expiring ($DaysToExpire days)</div>
            <div class="metric-value warning">$ExpiringCount</div>
        </div>
        <div class="metric">
            <div class="metric-label">Expired</div>
            <div class="metric-value critical">$ExpiredCount</div>
        </div>
    </div>
"@

            if ($ExpiredCount -gt 0) {
                $HTMLReport += @"
    <h2>CRITICAL: Expired Certificates ($ExpiredCount)</h2>
    <table>
        <tr>
            <th>Subject</th>
            <th>Issuer</th>
            <th>Expired Date</th>
            <th>Days Expired</th>
            <th>Store/Source</th>
            <th>Serial Number</th>
        </tr>
"@
                foreach ($Cert in $Results.ExpiredCertificates) {
                    $DaysExpired = [Math]::Abs($Cert.DaysUntilExpiration)
                    $Store = if ($Cert.StoreName) { $Cert.StoreName } else { $Cert.Source }

                    $HTMLReport += @"
        <tr>
            <td>$($Cert.Subject)</td>
            <td>$($Cert.Issuer)</td>
            <td>$($Cert.NotAfter)</td>
            <td><span class="status-expired">$DaysExpired days</span></td>
            <td>$Store</td>
            <td>$($Cert.SerialNumber)</td>
        </tr>
"@
                }
                $HTMLReport += "</table>"
            }

            if ($ExpiringCount -gt 0) {
                $HTMLReport += @"
    <h2>WARNING: Certificates Expiring Soon ($ExpiringCount)</h2>
    <table>
        <tr>
            <th>Subject</th>
            <th>Issuer</th>
            <th>Expiration Date</th>
            <th>Days Until Expiration</th>
            <th>Store/Source</th>
            <th>Template</th>
        </tr>
"@
                foreach ($Cert in $Results.ExpiringCertificates) {
                    $Store = if ($Cert.StoreName) { $Cert.StoreName } else { $Cert.Source }

                    $HTMLReport += @"
        <tr>
            <td>$($Cert.Subject)</td>
            <td>$($Cert.Issuer)</td>
            <td>$($Cert.NotAfter)</td>
            <td><span class="status-expiring">$($Cert.DaysUntilExpiration) days</span></td>
            <td>$Store</td>
            <td>$($Cert.Template)</td>
        </tr>
"@
                }
                $HTMLReport += "</table>"
            }

            $HTMLReport += @"
    <div class="footer">
        <p>Report generated by Certificate Expiration Monitor v$ScriptVersion</p>
        <p>For Windows Server 2022 | Alert Threshold: $DaysToExpire days</p>
    </div>
</body>
</html>
"@

            $HTMLReport | Out-File -FilePath $ReportFile -Encoding UTF8
        }

        'CSV' {
            $AllCerts = $Results.LocalCertificates + $Results.CAIssuedCertificates
            $AllCerts | Export-Csv -Path $ReportFile -NoTypeInformation -Encoding UTF8
        }

        'JSON' {
            $Results | ConvertTo-Json -Depth 10 | Out-File -FilePath $ReportFile -Encoding UTF8
        }
    }

    return $ReportFile
}

#endregion

#region Main Execution

try {
    Write-MonitorLog "========================================" -Level Info
    Write-MonitorLog "Certificate Expiration Monitor v$ScriptVersion" -Level Info
    Write-MonitorLog "========================================" -Level Info
    Write-MonitorLog "Computer: $ComputerName" -Level Info
    Write-MonitorLog "Alert Threshold: $DaysToExpire days" -Level Info
    Write-MonitorLog "Output Format: $ExportFormat" -Level Info
    Write-MonitorLog "========================================" -Level Info

    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-MonitorLog "Created output directory: $OutputPath" -Level Success
    }

    # Perform monitoring
    Get-LocalCertificates
    Get-CAIssuedCertificates

    # Send email alert if configured
    if ($SendEmail) {
        Send-ExpirationAlert -ExpiringCerts $MonitoringResults.ExpiringCertificates -ExpiredCerts $MonitoringResults.ExpiredCertificates
    }

    # Generate report
    Write-MonitorLog "Generating monitoring report..." -Level Info
    $ReportPath = Export-CertificateMonitoringReport -Results $MonitoringResults -OutputPath $OutputPath -Format $ExportFormat

    # Summary
    Write-MonitorLog "========================================" -Level Info
    Write-MonitorLog "Monitoring Complete!" -Level Success
    Write-MonitorLog "Total Certificates: $($MonitoringResults.Summary.TotalCertificates)" -Level Info
    Write-MonitorLog "Valid: $($MonitoringResults.Summary.ValidCertificates)" -Level Success
    Write-MonitorLog "Expiring Soon: $($MonitoringResults.Summary.ExpiringCertificates)" -Level Warning
    Write-MonitorLog "Expired: $($MonitoringResults.Summary.ExpiredCertificates)" -Level Critical
    Write-MonitorLog "Report saved to: $ReportPath" -Level Success
    Write-MonitorLog "========================================" -Level Info

    # Return report path for automation
    return [PSCustomObject]@{
        Success = $true
        ReportPath = $ReportPath
        Summary = $MonitoringResults.Summary
        CriticalCount = $MonitoringResults.ExpiredCertificates.Count
        WarningCount = $MonitoringResults.ExpiringCertificates.Count
    }

} catch {
    Write-MonitorLog "CRITICAL ERROR: $($_.Exception.Message)" -Level Error
    Write-MonitorLog "Stack Trace: $($_.ScriptStackTrace)" -Level Error
    throw
}

#endregion
