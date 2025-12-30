@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'EnterpriseAD.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = 'f3e4d5c6-b7a8-9012-cdef-345678901234'

    # Author of this module
    Author = 'Enterprise IT'

    # Company or vendor of this module
    CompanyName = 'Enterprise'

    # Copyright statement for this module
    Copyright = '(c) 2025 Enterprise IT. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Enterprise Active Directory management module for user, computer, and group operations with health monitoring.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @('ActiveDirectory')

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Get-ADStaleAccounts',
        'Get-ADPrivilegedUsers',
        'Get-ADPasswordExpiring',
        'Get-ADLockedAccounts',
        'Get-ADGroupMembershipReport',
        'Test-ADReplicationHealth',
        'Get-ADComputerInventory',
        'Get-ADUserInventory'
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
            Tags = @('ActiveDirectory', 'AD', 'Enterprise', 'Windows', 'Server')
            ProjectUri = ''
            LicenseUri = ''
            ReleaseNotes = 'Initial release - v1.0.0'
        }
    }
}
