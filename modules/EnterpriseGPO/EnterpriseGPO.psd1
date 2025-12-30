@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'EnterpriseGPO.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = 'a7b8c9d0-e1f2-3456-7890-abcdef123456'

    # Author of this module
    Author = 'Enterprise IT'

    # Company or vendor of this module
    CompanyName = 'Enterprise'

    # Copyright statement for this module
    Copyright = '(c) 2025 Enterprise IT. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Enterprise Group Policy management module for backup, comparison, reporting, and health monitoring.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @('GroupPolicy')

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Backup-EnterpriseGPO',
        'Restore-EnterpriseGPO',
        'Compare-EnterpriseGPO',
        'Get-GPOReport',
        'Get-GPOLinkage',
        'Test-GPOHealth'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            Tags = @('GroupPolicy', 'GPO', 'Enterprise', 'Windows', 'Server')
            ProjectUri = ''
            LicenseUri = ''
            ReleaseNotes = 'Initial release - v1.0.0'
        }
    }
}
