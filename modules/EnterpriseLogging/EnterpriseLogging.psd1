@{
    # Module identification
    RootModule        = 'EnterpriseLogging.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'Enterprise IT Team'
    CompanyName       = 'Your Organization'
    Copyright         = '(c) 2025 Your Organization. All rights reserved.'
    Description       = 'Enterprise-grade centralized logging for file, Event Log, and SIEM integration.'

    # PowerShell version requirements
    PowerShellVersion = '5.1'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # Required modules
    RequiredModules   = @()

    # Functions to export - NEVER use wildcards
    FunctionsToExport = @(
        'Write-EnterpriseLog',
        'Start-LogSession',
        'Stop-LogSession',
        'Set-LogConfiguration',
        'Send-LogToSIEM',
        'Write-EventLogEntry'
    )

    # Cmdlets, Variables, Aliases to export
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # Private data for module configuration
    PrivateData       = @{
        PSData = @{
            Tags         = @('Logging', 'Enterprise', 'SIEM', 'EventLog', 'Monitoring')
            ProjectUri   = 'https://github.com/yourorg/EnterpriseLogging'
            ReleaseNotes = 'Initial release with file, Event Log, and SIEM support.'
        }
    }
}
