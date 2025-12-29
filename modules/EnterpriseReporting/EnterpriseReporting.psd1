@{
    RootModule        = 'EnterpriseReporting.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b2c3d4e5-f6a7-8901-bcde-f23456789012'
    Author            = 'Enterprise IT Team'
    CompanyName       = 'Your Organization'
    Copyright         = '(c) 2025 Your Organization. All rights reserved.'
    Description       = 'Enterprise reporting module for generating HTML, CSV, Excel, and JSON reports with professional styling.'

    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    RequiredModules   = @()

    FunctionsToExport = @(
        'New-EnterpriseReport',
        'Export-ReportToHTML',
        'Export-ReportToCSV',
        'Export-ReportToJSON',
        'Export-ReportToExcel',
        'Add-ReportSection',
        'Add-ReportTable',
        'Add-ReportChart'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('Reporting', 'HTML', 'CSV', 'Excel', 'Enterprise', 'Dashboard')
            ProjectUri   = 'https://github.com/yourorg/EnterpriseReporting'
            ReleaseNotes = 'Initial release with HTML, CSV, JSON, and Excel export capabilities.'
        }
    }
}
