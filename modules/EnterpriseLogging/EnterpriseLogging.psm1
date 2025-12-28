#Requires -Version 5.1

<#
.SYNOPSIS
    EnterpriseLogging module for centralized logging across Windows Server infrastructure.

.DESCRIPTION
    Provides enterprise-grade logging capabilities including:
    - Structured JSON file logging
    - Windows Event Log integration
    - SIEM forwarding (Splunk, Elasticsearch, Azure Sentinel)
    - Log rotation and retention policies
    - Correlation ID tracking for distributed operations

.NOTES
    Author: Enterprise IT Team
    Version: 1.0.0
    Requires: PowerShell 5.1 or higher
#>

# Module-scoped variables
$script:ModuleRoot = $PSScriptRoot
$script:LogConfiguration = @{
    LogPath          = "$env:ProgramData\EnterpriseLogs"
    LogLevel         = 'Information'
    MaxLogSizeMB     = 50
    MaxLogFiles      = 10
    EnableEventLog   = $true
    EnableFileLog    = $true
    EnableSIEM       = $false
    SIEMEndpoint     = $null
    SIEMToken        = $null
    SIEMType         = 'Generic'
    EventLogSource   = 'EnterpriseAutomation'
    SessionId        = $null
}

# Dot-source all functions from Public and Private folders
$Public = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue)

foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# Export only Public functions
Export-ModuleMember -Function $Public.BaseName

# Module initialization
try {
    # Ensure log directory exists
    if (-not (Test-Path $script:LogConfiguration.LogPath)) {
        New-Item -Path $script:LogConfiguration.LogPath -ItemType Directory -Force | Out-Null
    }

    # Register Event Log source if needed
    if ($script:LogConfiguration.EnableEventLog) {
        $logName = 'Application'
        $source = $script:LogConfiguration.EventLogSource

        # Check if running as administrator
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if ($isAdmin -and -not [System.Diagnostics.EventLog]::SourceExists($source)) {
            try {
                [System.Diagnostics.EventLog]::CreateEventSource($source, $logName)
            }
            catch {
                Write-Warning "Unable to create Event Log source '$source'. Run as Administrator to enable Event Log integration."
                $script:LogConfiguration.EnableEventLog = $false
            }
        }
        elseif (-not $isAdmin -and -not [System.Diagnostics.EventLog]::SourceExists($source)) {
            Write-Verbose "Event Log source does not exist and not running as Administrator. Event Log disabled."
            $script:LogConfiguration.EnableEventLog = $false
        }
    }
}
catch {
    Write-Warning "Module initialization warning: $_"
}
