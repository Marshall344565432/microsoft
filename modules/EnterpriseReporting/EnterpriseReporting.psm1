#Requires -Version 5.1

<#
.SYNOPSIS
    EnterpriseReporting module for generating professional reports.

.DESCRIPTION
    Provides enterprise reporting capabilities including:
    - HTML reports with responsive design
    - CSV export for Excel compatibility
    - JSON export for APIs and automation
    - Excel export with formatting (requires ImportExcel module)
    - Report sections, tables, and charts
    - Professional styling and templates

.NOTES
    Author: Enterprise IT Team
    Version: 1.0.0
    Requires: PowerShell 5.1 or higher
    Optional: ImportExcel module for Excel export
#>

# Module-scoped variables
$script:ModuleRoot = $PSScriptRoot
$script:TemplatesPath = Join-Path $PSScriptRoot 'Templates'

# Dot-source all functions
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
