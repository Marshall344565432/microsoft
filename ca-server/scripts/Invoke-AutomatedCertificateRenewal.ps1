<#
.SYNOPSIS
    Automated Certificate Renewal for Windows Server 2022

.DESCRIPTION
    Automates certificate renewal for:
    - Computer certificates enrolled via auto-enrollment
    - Web server certificates (IIS)
    - Service certificates
    - Custom certificates from templates
    - Triggers auto-enrollment policy update
    - Verifies renewal success
    - Logs all renewal activities

    Compatible with:
    - Windows Server 2022
    - PowerShell 5.1+
    - Active Directory Certificate Services (ADCS)
    - Auto-enrollment GPO configured

.PARAMETER DaysBeforeExpiration
    Renew certificates expiring within this many days. Default: 30

.PARAMETER TemplateName
    Specific certificate template to renew. If not specified, renews all eligible certificates.

.PARAMETER LogPath
    Path for renewal log files. Default: C:\Logs\CertificateRenewal

.PARAMETER Force
    Force renewal even if certificate is not near expiration

.PARAMETER TestMode
    Run in test mode (show what would be renewed without actually renewing)

.PARAMETER RestartServices
    Restart services after certificate renewal

.PARAMETER SendNotification
    Send email notification after renewal

.PARAMETER SMTPServer
    SMTP server for notifications

.PARAMETER EmailTo
    Email recipient address

.PARAMETER EmailFrom
    Email sender address

.EXAMPLE
    .\Invoke-AutomatedCertificateRenewal.ps1
    Renews certificates expiring within 30 days using auto-enrollment

.EXAMPLE
    .\Invoke-AutomatedCertificateRenewal.ps1 -DaysBeforeExpiration 60 -RestartServices -SendNotification -SMTPServer "smtp.domain.com" -EmailTo "admin@domain.com" -EmailFrom "certs@domain.com"
    Renews certificates expiring within 60 days, restarts services, and sends notification

.EXAMPLE
    .\Invoke-AutomatedCertificateRenewal.ps1 -TemplateName "WebServer" -Force
    Forces renewal of all WebServer template certificates

.NOTES
    Version:        1.0.0
    Author:         Enterprise Infrastructure Team
    Creation Date:  2025-12-25
    Purpose:        Automated certificate lifecycle management

    Requires:
    - Administrator privileges
    - PowerShell 5.1+
    - Windows Server 2022
    - ADCS with auto-enrollment configured
    - Group Policy for auto-enrollment enabled
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [ValidateRange(1,365)]
    [int]$DaysBeforeExpiration = 30,

    [Parameter(Mandatory=$false)]
    [string]$TemplateName,

    [Parameter(Mandatory=$false)]
    [ValidateScript({Test-Path $_ -PathType Container -IsValid})]
    [string]$LogPath = "C:\Logs\CertificateRenewal",

    [Parameter(Mandatory=$false)]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [switch]$TestMode,

    [Parameter(Mandatory=$false)]
    [switch]$RestartServices,

    [Parameter(Mandatory=$false)]
    [switch]$SendNotification,

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
$RenewalResults = @{
    RenewedCertificates = @()
    FailedRenewals = @()
    SkippedCertificates = @()
    Summary = @{}
}

#region Logging Functions

function Write-RenewalLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Info','Warning','Error','Success','Critical')]
        [string]$Level = 'Info'
    )

    $LogTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$LogTimestamp] [$Level] $Message"

    # Write to console
    $Color = switch ($Level) {
        'Info'     { 'White' }
        'Warning'  { 'Yellow' }
        'Error'    { 'Red' }
        'Success'  { 'Green' }
        'Critical' { 'Magenta' }
    }

    Write-Host $LogMessage -ForegroundColor $Color

    # Write to log file
    $LogFile = Join-Path $LogPath "CertRenewal_${Timestamp}.log"
    $LogMessage | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

#endregion

#region Certificate Renewal Functions

function Invoke-CertificateAutoEnrollment {
    Write-RenewalLog "Triggering certificate auto-enrollment policy update..." -Level Info

    try {
        # Update Group Policy
        Write-RenewalLog "Updating Group Policy..." -Level Info
        $GPUpdateOutput = & gpupdate /force 2>&1
        Write-RenewalLog "Group Policy updated successfully" -Level Success

        # Trigger auto-enrollment using certutil
        Write-RenewalLog "Triggering certificate auto-enrollment..." -Level Info
        $CertUtilOutput = & certutil -pulse 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-RenewalLog "Auto-enrollment triggered successfully" -Level Success
            return $true
        } else {
            Write-RenewalLog "Auto-enrollment trigger completed with warnings. Output: $CertUtilOutput" -Level Warning
            return $true
        }

    } catch {
        Write-RenewalLog "Error triggering auto-enrollment: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-EligibleCertificatesForRenewal {
    Write-RenewalLog "Identifying certificates eligible for renewal..." -Level Info

    try {
        $ExpirationThreshold = (Get-Date).AddDays($DaysBeforeExpiration)
        $EligibleCertificates = @()

        # Scan computer certificate store
        $Certificates = Get-ChildItem -Path Cert:\LocalMachine\My

        foreach ($Cert in $Certificates) {
            $DaysUntilExpiration = (New-TimeSpan -Start (Get-Date) -End $Cert.NotAfter).Days

            # Check if certificate has auto-enrollment template
            $TemplateInfo = $Cert.Extensions | Where-Object {$_.Oid.FriendlyName -eq "Certificate Template Information"}

            if ($TemplateInfo) {
                $TemplateFormat = $TemplateInfo.Format($false)

                # Extract template name
                if ($TemplateFormat -match "Template=([^\(]+)") {
                    $CertTemplateName = $matches[1].Trim()
                } else {
                    $CertTemplateName = "Unknown"
                }

                # Check eligibility
                $IsEligible = $false

                if ($Force) {
                    $IsEligible = $true
                    $Reason = "Force renewal"
                } elseif ($Cert.NotAfter -lt $ExpirationThreshold) {
                    $IsEligible = $true
                    $Reason = "Expiring in $DaysUntilExpiration days"
                } else {
                    $Reason = "Not near expiration ($DaysUntilExpiration days remaining)"
                }

                # Filter by template if specified
                if ($TemplateName -and $CertTemplateName -ne $TemplateName) {
                    $IsEligible = $false
                    $Reason = "Template filter does not match"
                }

                if ($IsEligible) {
                    $EligibleCertificates += [PSCustomObject]@{
                        Subject = $Cert.Subject
                        Thumbprint = $Cert.Thumbprint
                        NotAfter = $Cert.NotAfter
                        DaysUntilExpiration = $DaysUntilExpiration
                        Template = $CertTemplateName
                        Reason = $Reason
                        HasPrivateKey = $Cert.HasPrivateKey
                    }
                }
            }
        }

        Write-RenewalLog "Found $($EligibleCertificates.Count) certificates eligible for renewal" -Level Info

        return $EligibleCertificates

    } catch {
        Write-RenewalLog "Error identifying eligible certificates: $($_.Exception.Message)" -Level Error
        return @()
    }
}

function Invoke-ManualCertificateRenewal {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Thumbprint,

        [Parameter(Mandatory=$true)]
        [string]$Template
    )

    Write-RenewalLog "Attempting manual renewal for certificate $Thumbprint (Template: $Template)..." -Level Info

    try {
        # Get the certificate
        $Cert = Get-ChildItem -Path Cert:\LocalMachine\My\$Thumbprint -ErrorAction Stop

        if ($TestMode) {
            Write-RenewalLog "[TEST MODE] Would renew certificate: $($Cert.Subject)" -Level Warning
            return [PSCustomObject]@{
                Success = $true
                Method = "Test Mode"
                Message = "Test mode - no actual renewal"
            }
        }

        # Request new certificate using same template
        # Note: This requires proper auto-enrollment configuration
        Write-RenewalLog "Requesting new certificate from template: $Template" -Level Info

        # Use certreq to request renewal
        $InfFile = "$env:TEMP\certreq_${Thumbprint}.inf"
        $RequestFile = "$env:TEMP\certreq_${Thumbprint}.req"
        $CertFile = "$env:TEMP\certreq_${Thumbprint}.cer"

        # Create INF file for certificate request
        $InfContent = @"
[Version]
Signature = "`$Windows NT`$"

[NewRequest]
Subject = "$($Cert.Subject)"
Exportable = TRUE
KeyLength = 2048
KeySpec = 1
KeyUsage = 0xA0
MachineKeySet = TRUE
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
ProviderType = 12
RequestType = PKCS10

[EnhancedKeyUsageExtension]
OID=1.3.6.1.5.5.7.3.1
"@

        $InfContent | Out-File -FilePath $InfFile -Encoding ASCII

        # Create certificate request
        $certreqOutput = & certreq -new $InfFile $RequestFile 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-RenewalLog "Certificate request created successfully" -Level Success

            # Submit request to CA
            $certreqOutput = & certreq -submit -config "$env:USERDNSDOMAIN\$env:COMPUTERNAME" $RequestFile $CertFile 2>&1

            if ($LASTEXITCODE -eq 0) {
                # Accept and install the certificate
                $certreqOutput = & certreq -accept $CertFile 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-RenewalLog "Certificate renewed and installed successfully" -Level Success

                    # Cleanup temp files
                    Remove-Item $InfFile, $RequestFile, $CertFile -Force -ErrorAction SilentlyContinue

                    return [PSCustomObject]@{
                        Success = $true
                        Method = "Manual Renewal"
                        Message = "Certificate renewed successfully"
                    }
                } else {
                    throw "Failed to accept certificate: $certreqOutput"
                }
            } else {
                throw "Failed to submit request: $certreqOutput"
            }
        } else {
            throw "Failed to create request: $certreqOutput"
        }

    } catch {
        Write-RenewalLog "Manual renewal failed: $($_.Exception.Message)" -Level Error
        return [PSCustomObject]@{
            Success = $false
            Method = "Manual Renewal"
            Message = $_.Exception.Message
        }
    }
}

function Invoke-ServiceRestart {
    Write-RenewalLog "Checking services that may need restart after certificate renewal..." -Level Info

    try {
        # Common services that use certificates
        $ServicesToCheck = @(
            @{Name="W3SVC"; DisplayName="World Wide Web Publishing Service (IIS)"},
            @{Name="IISADMIN"; DisplayName="IIS Admin Service"},
            @{Name="WinRM"; DisplayName="Windows Remote Management"},
            @{Name="RemoteAccess"; DisplayName="Routing and Remote Access"}
        )

        $RestartedServices = @()

        foreach ($ServiceInfo in $ServicesToCheck) {
            try {
                $Service = Get-Service -Name $ServiceInfo.Name -ErrorAction SilentlyContinue

                if ($Service -and $Service.Status -eq 'Running') {
                    if ($TestMode) {
                        Write-RenewalLog "[TEST MODE] Would restart service: $($ServiceInfo.DisplayName)" -Level Warning
                    } else {
                        Write-RenewalLog "Restarting service: $($ServiceInfo.DisplayName)" -Level Info
                        Restart-Service -Name $ServiceInfo.Name -Force
                        Write-RenewalLog "Service restarted successfully: $($ServiceInfo.DisplayName)" -Level Success
                        $RestartedServices += $ServiceInfo.DisplayName
                    }
                }
            } catch {
                Write-RenewalLog "Error restarting service $($ServiceInfo.Name): $($_.Exception.Message)" -Level Warning
            }
        }

        if ($RestartedServices.Count -gt 0) {
            Write-RenewalLog "Restarted $($RestartedServices.Count) services" -Level Success
        }

        return $RestartedServices

    } catch {
        Write-RenewalLog "Error during service restart: $($_.Exception.Message)" -Level Error
        return @()
    }
}

#endregion

#region Notification Functions

function Send-RenewalNotification {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Results
    )

    if (-not $SendNotification) {
        return
    }

    if (-not $SMTPServer -or -not $EmailTo -or -not $EmailFrom) {
        Write-RenewalLog "Email parameters not fully specified. Skipping notification." -Level Warning
        return
    }

    try {
        $RenewedCount = $Results.RenewedCertificates.Count
        $FailedCount = $Results.FailedRenewals.Count
        $SkippedCount = $Results.SkippedCertificates.Count

        $EmailBody = @"
<html>
<head>
<style>
    body { font-family: Arial, sans-serif; }
    h2 { color: #9b59b6; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
    th { background-color: #34495e; color: white; padding: 10px; text-align: left; }
    td { padding: 8px; border-bottom: 1px solid #ddd; }
    .success { background-color: #d4edda; }
    .failed { background-color: #f8d7da; }
</style>
</head>
<body>
<h2>Certificate Renewal Report - $ComputerName</h2>
<p><strong>Report Date:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
<p><strong>Test Mode:</strong> $(if($TestMode){'Yes'}else{'No'})</p>

<h3>Summary</h3>
<ul>
<li><strong>Renewed:</strong> $RenewedCount</li>
<li><strong>Failed:</strong> $FailedCount</li>
<li><strong>Skipped:</strong> $SkippedCount</li>
</ul>
"@

        if ($RenewedCount -gt 0) {
            $EmailBody += "<h3>Successfully Renewed Certificates</h3>"
            $EmailBody += "<table><tr><th>Subject</th><th>Template</th><th>Previous Expiration</th><th>Method</th></tr>"
            foreach ($Cert in $Results.RenewedCertificates) {
                $EmailBody += "<tr class='success'><td>$($Cert.Subject)</td><td>$($Cert.Template)</td><td>$($Cert.NotAfter)</td><td>$($Cert.RenewalMethod)</td></tr>"
            }
            $EmailBody += "</table>"
        }

        if ($FailedCount -gt 0) {
            $EmailBody += "<h3>Failed Renewals</h3>"
            $EmailBody += "<table><tr><th>Subject</th><th>Template</th><th>Error</th></tr>"
            foreach ($Cert in $Results.FailedRenewals) {
                $EmailBody += "<tr class='failed'><td>$($Cert.Subject)</td><td>$($Cert.Template)</td><td>$($Cert.Error)</td></tr>"
            }
            $EmailBody += "</table>"
        }

        $EmailBody += @"
<p><i>This is an automated notification from the Certificate Renewal Service.</i></p>
</body>
</html>
"@

        $EmailParams = @{
            From = $EmailFrom
            To = $EmailTo
            Subject = "Certificate Renewal Report - $ComputerName - $RenewedCount Renewed, $FailedCount Failed"
            Body = $EmailBody
            BodyAsHtml = $true
            SmtpServer = $SMTPServer
        }

        Send-MailMessage @EmailParams

        Write-RenewalLog "Notification email sent to $EmailTo" -Level Success

    } catch {
        Write-RenewalLog "Error sending notification: $($_.Exception.Message)" -Level Error
    }
}

#endregion

#region Main Execution

try {
    Write-RenewalLog "========================================" -Level Info
    Write-RenewalLog "Automated Certificate Renewal v$ScriptVersion" -Level Info
    Write-RenewalLog "========================================" -Level Info
    Write-RenewalLog "Computer: $ComputerName" -Level Info
    Write-RenewalLog "Renewal Threshold: $DaysBeforeExpiration days" -Level Info
    Write-RenewalLog "Test Mode: $(if($TestMode){'Enabled'}else{'Disabled'})" -Level Info
    if ($TemplateName) {
        Write-RenewalLog "Template Filter: $TemplateName" -Level Info
    }
    Write-RenewalLog "========================================" -Level Info

    # Create log directory
    if (-not (Test-Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
        Write-RenewalLog "Created log directory: $LogPath" -Level Success
    }

    # Step 1: Trigger auto-enrollment
    $AutoEnrollmentSuccess = Invoke-CertificateAutoEnrollment

    # Step 2: Get eligible certificates
    $EligibleCertificates = Get-EligibleCertificatesForRenewal

    if ($EligibleCertificates.Count -eq 0) {
        Write-RenewalLog "No certificates require renewal at this time" -Level Success
    } else {
        Write-RenewalLog "Processing $($EligibleCertificates.Count) certificates for renewal..." -Level Info

        # Step 3: Wait for auto-enrollment to complete
        Write-RenewalLog "Waiting 10 seconds for auto-enrollment to complete..." -Level Info
        Start-Sleep -Seconds 10

        # Step 4: Verify renewals
        foreach ($Cert in $EligibleCertificates) {
            try {
                # Check if certificate was auto-renewed
                $NewCert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {
                    $_.Subject -eq $Cert.Subject -and
                    $_.NotAfter -gt $Cert.NotAfter
                } | Select-Object -First 1

                if ($NewCert) {
                    Write-RenewalLog "Certificate auto-renewed successfully: $($Cert.Subject)" -Level Success

                    $Script:RenewalResults.RenewedCertificates += [PSCustomObject]@{
                        Subject = $Cert.Subject
                        Template = $Cert.Template
                        NotAfter = $Cert.NotAfter
                        NewNotAfter = $NewCert.NotAfter
                        RenewalMethod = "Auto-Enrollment"
                        Timestamp = Get-Date
                    }
                } else {
                    # Auto-enrollment didn't work, try manual renewal
                    Write-RenewalLog "Auto-enrollment did not renew certificate, attempting manual renewal..." -Level Warning

                    $RenewalResult = Invoke-ManualCertificateRenewal -Thumbprint $Cert.Thumbprint -Template $Cert.Template

                    if ($RenewalResult.Success) {
                        $Script:RenewalResults.RenewedCertificates += [PSCustomObject]@{
                            Subject = $Cert.Subject
                            Template = $Cert.Template
                            NotAfter = $Cert.NotAfter
                            NewNotAfter = "See store"
                            RenewalMethod = $RenewalResult.Method
                            Timestamp = Get-Date
                        }
                    } else {
                        $Script:RenewalResults.FailedRenewals += [PSCustomObject]@{
                            Subject = $Cert.Subject
                            Template = $Cert.Template
                            NotAfter = $Cert.NotAfter
                            Error = $RenewalResult.Message
                            Timestamp = Get-Date
                        }
                    }
                }

            } catch {
                Write-RenewalLog "Error processing certificate $($Cert.Subject): $($_.Exception.Message)" -Level Error

                $Script:RenewalResults.FailedRenewals += [PSCustomObject]@{
                    Subject = $Cert.Subject
                    Template = $Cert.Template
                    NotAfter = $Cert.NotAfter
                    Error = $_.Exception.Message
                    Timestamp = Get-Date
                }
            }
        }
    }

    # Step 5: Restart services if requested
    $RestartedServices = @()
    if ($RestartServices -and $RenewalResults.RenewedCertificates.Count -gt 0) {
        $RestartedServices = Invoke-ServiceRestart
    }

    # Step 6: Calculate summary
    $RenewalResults.Summary = @{
        TotalProcessed = $EligibleCertificates.Count
        Renewed = $RenewalResults.RenewedCertificates.Count
        Failed = $RenewalResults.FailedRenewals.Count
        Skipped = $RenewalResults.SkippedCertificates.Count
        RestartedServices = $RestartedServices.Count
        TestMode = $TestMode
    }

    # Step 7: Send notification
    if ($SendNotification) {
        Send-RenewalNotification -Results $RenewalResults
    }

    # Final Summary
    Write-RenewalLog "========================================" -Level Info
    Write-RenewalLog "Certificate Renewal Complete!" -Level Success
    Write-RenewalLog "Eligible Certificates: $($EligibleCertificates.Count)" -Level Info
    Write-RenewalLog "Successfully Renewed: $($RenewalResults.RenewedCertificates.Count)" -Level Success
    Write-RenewalLog "Failed Renewals: $($RenewalResults.FailedRenewals.Count)" -Level Error
    if ($RestartServices) {
        Write-RenewalLog "Services Restarted: $($RestartedServices.Count)" -Level Info
    }
    Write-RenewalLog "========================================" -Level Info

    # Return results for automation
    return [PSCustomObject]@{
        Success = ($RenewalResults.FailedRenewals.Count -eq 0)
        Summary = $RenewalResults.Summary
        RenewedCertificates = $RenewalResults.RenewedCertificates
        FailedRenewals = $RenewalResults.FailedRenewals
    }

} catch {
    Write-RenewalLog "CRITICAL ERROR: $($_.Exception.Message)" -Level Critical
    Write-RenewalLog "Stack Trace: $($_.ScriptStackTrace)" -Level Error
    throw
}

#endregion
