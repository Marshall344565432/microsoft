<#
.SYNOPSIS
    CIS Benchmark Audit Baseline for Windows Server 2022

.DESCRIPTION
    Performs a comprehensive CIS Level 1 & 2 audit of Windows Server 2022 configuration.
    Checks critical security settings against CIS benchmarks and generates a compliance report.

    Compatible with:
    - Windows Server 2022
    - PowerShell 5.1+

.PARAMETER OutputPath
    Path where the audit report will be saved. Default: C:\Audits\CIS

.PARAMETER Level
    CIS Level to audit (1 or 2). Default: 1

.PARAMETER ExportFormat
    Report format: HTML, CSV, or JSON. Default: HTML

.EXAMPLE
    .\Get-CISAuditBaseline.ps1
    Runs a Level 1 audit and generates HTML report

.EXAMPLE
    .\Get-CISAuditBaseline.ps1 -Level 2 -OutputPath "D:\Reports" -ExportFormat JSON
    Runs a Level 2 audit with JSON output

.NOTES
    Version:        1.0.0
    Author:         Enterprise Infrastructure Team
    Creation Date:  2025-12-25
    Purpose:        CIS Benchmark compliance baseline auditing

    Requires:
    - Administrator privileges
    - PowerShell 5.1+
    - Windows Server 2022
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateScript({Test-Path $_ -PathType Container -IsValid})]
    [string]$OutputPath = "C:\Audits\CIS",

    [Parameter(Mandatory=$false)]
    [ValidateSet(1,2)]
    [int]$Level = 1,

    [Parameter(Mandatory=$false)]
    [ValidateSet('HTML','CSV','JSON')]
    [string]$ExportFormat = 'HTML'
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
$AuditResults = @()

#region Logging Functions

function Write-AuditLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Info','Warning','Error','Success')]
        [string]$Level = 'Info'
    )

    $LogTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$LogTimestamp] [$Level] $Message"

    $Color = switch ($Level) {
        'Info'    { 'White' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        'Success' { 'Green' }
    }

    Write-Host $LogMessage -ForegroundColor $Color
}

#endregion

#region CIS Audit Functions

function Test-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$ExpectedValue,
        [string]$Description
    )

    try {
        if (Test-Path $Path) {
            $ActualValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
            $Compliant = $ActualValue -eq $ExpectedValue
        } else {
            $ActualValue = "Registry path not found"
            $Compliant = $false
        }
    } catch {
        $ActualValue = "Error reading registry"
        $Compliant = $false
    }

    return [PSCustomObject]@{
        Check = $Description
        Path = $Path
        Name = $Name
        Expected = $ExpectedValue
        Actual = $ActualValue
        Compliant = $Compliant
        Severity = if($Compliant){'Pass'}else{'Fail'}
    }
}

function Test-AccountPolicy {
    param(
        [string]$PolicyName,
        [object]$ExpectedValue,
        [string]$Description
    )

    try {
        # Export security policy
        $SecEditFile = "$env:TEMP\secedit_$Timestamp.txt"
        secedit /export /cfg $SecEditFile /quiet | Out-Null

        $PolicyContent = Get-Content $SecEditFile
        $PolicyLine = $PolicyContent | Where-Object { $_ -match "^$PolicyName\s*=" }

        if ($PolicyLine) {
            $ActualValue = ($PolicyLine -split '=')[1].Trim()
            $Compliant = $ActualValue -eq $ExpectedValue
        } else {
            $ActualValue = "Policy not found"
            $Compliant = $false
        }

        Remove-Item $SecEditFile -Force -ErrorAction SilentlyContinue
    } catch {
        $ActualValue = "Error reading policy"
        $Compliant = $false
    }

    return [PSCustomObject]@{
        Check = $Description
        Policy = $PolicyName
        Expected = $ExpectedValue
        Actual = $ActualValue
        Compliant = $Compliant
        Severity = if($Compliant){'Pass'}else{'Fail'}
    }
}

function Test-ServiceConfiguration {
    param(
        [string]$ServiceName,
        [string]$ExpectedStartType,
        [string]$Description
    )

    try {
        $Service = Get-Service -Name $ServiceName -ErrorAction Stop
        $ServiceDetails = Get-WmiObject -Class Win32_Service -Filter "Name='$ServiceName'"
        $ActualStartType = $ServiceDetails.StartMode
        $Compliant = $ActualStartType -eq $ExpectedStartType
    } catch {
        $ActualStartType = "Service not found"
        $Compliant = $false
    }

    return [PSCustomObject]@{
        Check = $Description
        Service = $ServiceName
        Expected = $ExpectedStartType
        Actual = $ActualStartType
        Compliant = $Compliant
        Severity = if($Compliant){'Pass'}else{'Fail'}
    }
}

function Test-AuditPolicy {
    param(
        [string]$Category,
        [string]$Subcategory,
        [string]$ExpectedSetting,
        [string]$Description
    )

    try {
        $AuditOutput = auditpol /get /subcategory:"$Subcategory" 2>&1

        if ($AuditOutput -match "Success and Failure") {
            $ActualSetting = "Success and Failure"
        } elseif ($AuditOutput -match "Success") {
            $ActualSetting = "Success"
        } elseif ($AuditOutput -match "Failure") {
            $ActualSetting = "Failure"
        } elseif ($AuditOutput -match "No Auditing") {
            $ActualSetting = "No Auditing"
        } else {
            $ActualSetting = "Unknown"
        }

        $Compliant = $ActualSetting -eq $ExpectedSetting
    } catch {
        $ActualSetting = "Error reading audit policy"
        $Compliant = $false
    }

    return [PSCustomObject]@{
        Check = $Description
        Category = $Category
        Subcategory = $Subcategory
        Expected = $ExpectedSetting
        Actual = $ActualSetting
        Compliant = $Compliant
        Severity = if($Compliant){'Pass'}else{'Fail'}
    }
}

#endregion

#region CIS Benchmark Checks

function Invoke-CISLevel1Checks {
    Write-AuditLog "Performing CIS Level 1 benchmark checks..." -Level Info

    $Results = @()

    # 1.1.1 - Password Policy
    Write-AuditLog "Checking password policies..." -Level Info
    $Results += Test-AccountPolicy -PolicyName "MinimumPasswordLength" -ExpectedValue "14" -Description "CIS 1.1.1 - Minimum password length (14 characters)"
    $Results += Test-AccountPolicy -PolicyName "PasswordComplexity" -ExpectedValue "1" -Description "CIS 1.1.2 - Password must meet complexity requirements"
    $Results += Test-AccountPolicy -PolicyName "PasswordHistorySize" -ExpectedValue "24" -Description "CIS 1.1.3 - Enforce password history (24 passwords)"
    $Results += Test-AccountPolicy -PolicyName "MaximumPasswordAge" -ExpectedValue "365" -Description "CIS 1.1.4 - Maximum password age (365 days or less)"
    $Results += Test-AccountPolicy -PolicyName "MinimumPasswordAge" -ExpectedValue "1" -Description "CIS 1.1.5 - Minimum password age (1 day or more)"

    # 1.2 - Account Lockout Policy
    Write-AuditLog "Checking account lockout policies..." -Level Info
    $Results += Test-AccountPolicy -PolicyName "LockoutBadCount" -ExpectedValue "5" -Description "CIS 1.2.1 - Account lockout threshold (5 invalid attempts)"
    $Results += Test-AccountPolicy -PolicyName "LockoutDuration" -ExpectedValue "15" -Description "CIS 1.2.2 - Account lockout duration (15 minutes)"
    $Results += Test-AccountPolicy -PolicyName "ResetLockoutCount" -ExpectedValue "15" -Description "CIS 1.2.3 - Reset account lockout counter (15 minutes)"

    # 2.2.1 - User Rights Assignment
    Write-AuditLog "Checking user rights assignments..." -Level Info
    $Results += Test-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse" -ExpectedValue 1 -Description "CIS 2.2.1 - Accounts: Limit local account use of blank passwords"
    $Results += Test-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "NoLMHash" -ExpectedValue 1 -Description "CIS 2.2.2 - Network security: Do not store LAN Manager hash"
    $Results += Test-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "RequireSecuritySignature" -ExpectedValue 1 -Description "CIS 2.2.3 - SMB client signing required"
    $Results += Test-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters" -Name "RequireSecuritySignature" -ExpectedValue 1 -Description "CIS 2.2.4 - SMB server signing required"

    # 2.3.1 - Audit Policy
    Write-AuditLog "Checking audit policies..." -Level Info
    $Results += Test-AuditPolicy -Category "Account Logon" -Subcategory "Credential Validation" -ExpectedSetting "Success and Failure" -Description "CIS 17.1.1 - Audit Credential Validation"
    $Results += Test-AuditPolicy -Category "Account Management" -Subcategory "Security Group Management" -ExpectedSetting "Success" -Description "CIS 17.2.1 - Audit Security Group Management"
    $Results += Test-AuditPolicy -Category "Account Management" -Subcategory "User Account Management" -ExpectedSetting "Success and Failure" -Description "CIS 17.2.2 - Audit User Account Management"
    $Results += Test-AuditPolicy -Category "Logon/Logoff" -Subcategory "Logon" -ExpectedSetting "Success and Failure" -Description "CIS 17.5.1 - Audit Logon"
    $Results += Test-AuditPolicy -Category "Logon/Logoff" -Subcategory "Logoff" -ExpectedSetting "Success" -Description "CIS 17.5.2 - Audit Logoff"
    $Results += Test-AuditPolicy -Category "Policy Change" -Subcategory "Audit Policy Change" -ExpectedSetting "Success and Failure" -Description "CIS 17.6.1 - Audit Policy Change"
    $Results += Test-AuditPolicy -Category "Privilege Use" -Subcategory "Sensitive Privilege Use" -ExpectedSetting "Success and Failure" -Description "CIS 17.7.1 - Audit Sensitive Privilege Use"
    $Results += Test-AuditPolicy -Category "System" -Subcategory "Security System Extension" -ExpectedSetting "Success" -Description "CIS 17.9.1 - Audit Security System Extension"
    $Results += Test-AuditPolicy -Category "System" -Subcategory "System Integrity" -ExpectedSetting "Success and Failure" -Description "CIS 17.9.2 - Audit System Integrity"

    # 18.1 - Windows Firewall
    Write-AuditLog "Checking Windows Firewall settings..." -Level Info
    $Results += Test-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile" -Name "EnableFirewall" -ExpectedValue 1 -Description "CIS 9.1.1 - Firewall enabled (Domain)"
    $Results += Test-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PrivateProfile" -Name "EnableFirewall" -ExpectedValue 1 -Description "CIS 9.2.1 - Firewall enabled (Private)"
    $Results += Test-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile" -Name "EnableFirewall" -ExpectedValue 1 -Description "CIS 9.3.1 - Firewall enabled (Public)"

    # 18.2 - Remote Desktop Services
    Write-AuditLog "Checking Remote Desktop settings..." -Level Info
    $Results += Test-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -ExpectedValue 1 -Description "CIS 18.9.48.3.1 - Remote Desktop disabled (if not needed)"
    $Results += Test-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "fEncryptRPCTraffic" -ExpectedValue 1 -Description "CIS 18.9.48.3.3.2 - RDP encryption level (High)"

    # 18.3 - Windows Update
    Write-AuditLog "Checking Windows Update settings..." -Level Info
    $Results += Test-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -ExpectedValue 0 -Description "CIS 18.9.101.1.1 - Configure Automatic Updates enabled"

    # 18.4 - Security Options
    Write-AuditLog "Checking security options..." -Level Info
    $Results += Test-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictAnonymous" -ExpectedValue 1 -Description "CIS 2.3.11.7 - Restrict anonymous access to SAM"
    $Results += Test-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictAnonymousSAM" -ExpectedValue 1 -Description "CIS 2.3.11.8 - Restrict anonymous enumeration of SAM accounts"
    $Results += Test-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "DisableDomainCreds" -ExpectedValue 1 -Description "CIS 2.3.11.3 - Do not allow storage of passwords"

    # Services
    Write-AuditLog "Checking service configurations..." -Level Info
    $Results += Test-ServiceConfiguration -ServiceName "RemoteRegistry" -ExpectedStartType "Disabled" -Description "CIS 5.28 - Remote Registry service disabled"
    $Results += Test-ServiceConfiguration -ServiceName "SSDPSRV" -ExpectedStartType "Disabled" -Description "CIS 5.36 - SSDP Discovery service disabled"
    $Results += Test-ServiceConfiguration -ServiceName "upnphost" -ExpectedStartType "Disabled" -Description "CIS 5.40 - UPnP Device Host disabled"

    return $Results
}

function Invoke-CISLevel2Checks {
    Write-AuditLog "Performing CIS Level 2 benchmark checks..." -Level Info

    $Results = @()

    # Additional Level 2 checks (more restrictive)
    Write-AuditLog "Checking advanced security settings..." -Level Info

    $Results += Test-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" -Name "AllowBasic" -ExpectedValue 0 -Description "CIS L2 - WinRM Client: Disallow Basic authentication"
    $Results += Test-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" -Name "AllowBasic" -ExpectedValue 0 -Description "CIS L2 - WinRM Service: Disallow Basic authentication"
    $Results += Test-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\0e796bdb-100d-47d6-a2d5-f7d2daa51f51" -Name "DCSettingIndex" -ExpectedValue 1 -Description "CIS L2 - Require password on wake (plugged in)"
    $Results += Test-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "InactivityTimeoutSecs" -ExpectedValue 900 -Description "CIS L2 - Interactive logon: Machine inactivity limit (900 seconds)"

    $Results += Test-ServiceConfiguration -ServiceName "XblAuthManager" -ExpectedStartType "Disabled" -Description "CIS L2 - Xbox Live Auth Manager disabled"
    $Results += Test-ServiceConfiguration -ServiceName "XblGameSave" -ExpectedStartType "Disabled" -Description "CIS L2 - Xbox Live Game Save disabled"

    return $Results
}

#endregion

#region Report Generation

function Export-AuditReport {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Results,

        [Parameter(Mandatory=$true)]
        [string]$OutputPath,

        [Parameter(Mandatory=$true)]
        [string]$Format
    )

    $ReportFile = Join-Path $OutputPath "CIS_Audit_${ComputerName}_${Timestamp}.${Format.ToLower()}"

    switch ($Format) {
        'HTML' {
            $PassCount = ($Results | Where-Object {$_.Compliant -eq $true}).Count
            $FailCount = ($Results | Where-Object {$_.Compliant -eq $false}).Count
            $TotalCount = $Results.Count
            $CompliancePercent = [math]::Round(($PassCount / $TotalCount) * 100, 2)

            $HTMLReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>CIS Benchmark Audit Report - $ComputerName</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .summary { background-color: white; padding: 20px; border-radius: 5px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric { display: inline-block; margin: 10px 20px; }
        .metric-value { font-size: 36px; font-weight: bold; }
        .metric-label { font-size: 14px; color: #7f8c8d; }
        .pass { color: #27ae60; }
        .fail { color: #e74c3c; }
        table { border-collapse: collapse; width: 100%; background-color: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        th { background-color: #34495e; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background-color: #f8f9fa; }
        .status-pass { background-color: #d4edda; color: #155724; padding: 5px 10px; border-radius: 3px; font-weight: bold; }
        .status-fail { background-color: #f8d7da; color: #721c24; padding: 5px 10px; border-radius: 3px; font-weight: bold; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #7f8c8d; font-size: 12px; }
    </style>
</head>
<body>
    <h1>CIS Benchmark Audit Report</h1>

    <div class="summary">
        <h2>Audit Summary</h2>
        <div class="metric">
            <div class="metric-label">Computer</div>
            <div class="metric-value">$ComputerName</div>
        </div>
        <div class="metric">
            <div class="metric-label">Date</div>
            <div class="metric-value">$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</div>
        </div>
        <div class="metric">
            <div class="metric-label">Total Checks</div>
            <div class="metric-value">$TotalCount</div>
        </div>
        <div class="metric">
            <div class="metric-label">Passed</div>
            <div class="metric-value pass">$PassCount</div>
        </div>
        <div class="metric">
            <div class="metric-label">Failed</div>
            <div class="metric-value fail">$FailCount</div>
        </div>
        <div class="metric">
            <div class="metric-label">Compliance</div>
            <div class="metric-value">$CompliancePercent%</div>
        </div>
    </div>

    <h2>Audit Results</h2>
    <table>
        <tr>
            <th>Status</th>
            <th>Check Description</th>
            <th>Expected</th>
            <th>Actual</th>
        </tr>
"@
            foreach ($Result in $Results) {
                $StatusClass = if ($Result.Compliant) { "status-pass" } else { "status-fail" }
                $Status = if ($Result.Compliant) { "PASS" } else { "FAIL" }

                $HTMLReport += @"
        <tr>
            <td><span class="$StatusClass">$Status</span></td>
            <td>$($Result.Check)</td>
            <td>$($Result.Expected)</td>
            <td>$($Result.Actual)</td>
        </tr>
"@
            }

            $HTMLReport += @"
    </table>

    <div class="footer">
        <p>Report generated by CIS Audit Baseline Script v$ScriptVersion</p>
        <p>For Windows Server 2022 | CIS Level $Level</p>
    </div>
</body>
</html>
"@

            $HTMLReport | Out-File -FilePath $ReportFile -Encoding UTF8
        }

        'CSV' {
            $Results | Export-Csv -Path $ReportFile -NoTypeInformation -Encoding UTF8
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
    Write-AuditLog "========================================" -Level Info
    Write-AuditLog "CIS Benchmark Audit Script v$ScriptVersion" -Level Info
    Write-AuditLog "========================================" -Level Info
    Write-AuditLog "Computer: $ComputerName" -Level Info
    Write-AuditLog "CIS Level: $Level" -Level Info
    Write-AuditLog "Output Format: $ExportFormat" -Level Info
    Write-AuditLog "========================================" -Level Info

    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-AuditLog "Created output directory: $OutputPath" -Level Success
    }

    # Perform audits
    $AuditResults += Invoke-CISLevel1Checks

    if ($Level -eq 2) {
        $AuditResults += Invoke-CISLevel2Checks
    }

    # Generate report
    Write-AuditLog "Generating audit report..." -Level Info
    $ReportPath = Export-AuditReport -Results $AuditResults -OutputPath $OutputPath -Format $ExportFormat

    # Summary
    $PassCount = ($AuditResults | Where-Object {$_.Compliant -eq $true}).Count
    $FailCount = ($AuditResults | Where-Object {$_.Compliant -eq $false}).Count
    $TotalCount = $AuditResults.Count
    $CompliancePercent = [math]::Round(($PassCount / $TotalCount) * 100, 2)

    Write-AuditLog "========================================" -Level Info
    Write-AuditLog "Audit Complete!" -Level Success
    Write-AuditLog "Total Checks: $TotalCount" -Level Info
    Write-AuditLog "Passed: $PassCount" -Level Success
    Write-AuditLog "Failed: $FailCount" -Level Warning
    Write-AuditLog "Compliance: $CompliancePercent%" -Level Info
    Write-AuditLog "Report saved to: $ReportPath" -Level Success
    Write-AuditLog "========================================" -Level Info

    # Return report path for automation
    return [PSCustomObject]@{
        Success = $true
        ReportPath = $ReportPath
        TotalChecks = $TotalCount
        Passed = $PassCount
        Failed = $FailCount
        CompliancePercent = $CompliancePercent
    }

} catch {
    Write-AuditLog "CRITICAL ERROR: $($_.Exception.Message)" -Level Error
    Write-AuditLog "Stack Trace: $($_.ScriptStackTrace)" -Level Error
    throw
}

#endregion
