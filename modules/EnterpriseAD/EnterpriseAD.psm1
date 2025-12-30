#Requires -Version 5.1
#Requires -Modules ActiveDirectory

# Get public and private function definition files
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# Export public functions
Export-ModuleMember -Function $Public.BaseName

# Module variables
$script:ServiceAccountIndicators = @(
    '*svc*', '*service*', '*sql*', '*iis*', '*app*',
    '*web*', '*db*', '*backup*', '*admin*', '*test*'
)

$script:PrivilegedGroups = @(
    'Domain Admins',
    'Enterprise Admins',
    'Schema Admins',
    'Administrators',
    'Account Operators',
    'Backup Operators',
    'Server Operators',
    'Print Operators',
    'DNSAdmins',
    'Group Policy Creator Owners'
)
