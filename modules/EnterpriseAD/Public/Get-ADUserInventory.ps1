function Get-ADUserInventory {
    <#
    .SYNOPSIS
        Generates a comprehensive user inventory from Active Directory.

    .DESCRIPTION
        Retrieves detailed information about all users in Active Directory including
        account status, last logon, department, email, and organizational unit.

    .PARAMETER Department
        Filter by department name (supports wildcards).

    .PARAMETER IncludeDisabled
        Include disabled user accounts in the inventory.

    .PARAMETER SearchBase
        Optional OU distinguished name to limit the search scope.

    .PARAMETER DaysInactive
        Only include users that have logged on within the specified days.

    .EXAMPLE
        Get-ADUserInventory
        Get inventory of all enabled users.

    .EXAMPLE
        Get-ADUserInventory -Department "IT*"
        Get inventory of users in IT departments.

    .EXAMPLE
        Get-ADUserInventory -DaysInactive 90 -IncludeDisabled
        Get all users (including disabled) that logged on in the last 90 days.

    .OUTPUTS
        PSCustomObject with user inventory details.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Department,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeDisabled,

        [Parameter(Mandatory = $false)]
        [string]$SearchBase,

        [Parameter(Mandatory = $false)]
        [int]$DaysInactive
    )

    process {
        try {
            $results = [System.Collections.ArrayList]::new()

            $searchParams = @{
                Filter     = '*'
                Properties = @(
                    'Department', 'Title', 'EmailAddress', 'Manager',
                    'LastLogonDate', 'Enabled', 'PasswordLastSet',
                    'PasswordNeverExpires', 'PasswordExpired', 'LockedOut',
                    'whenCreated', 'Description', 'DistinguishedName'
                )
            }

            if ($SearchBase) {
                $searchParams['SearchBase'] = $SearchBase
            }

            Write-Verbose "Retrieving user inventory..."
            $users = Get-ADUser @searchParams

            # Apply filters
            if ($Department) {
                $users = $users | Where-Object { $_.Department -like $Department }
            }

            if (-not $IncludeDisabled) {
                $users = $users | Where-Object { $_.Enabled -eq $true }
            }

            if ($DaysInactive) {
                $cutoffDate = (Get-Date).AddDays(-$DaysInactive)
                $users = $users | Where-Object {
                    $_.LastLogonDate -and $_.LastLogonDate -gt $cutoffDate
                }
            }

            foreach ($user in $users) {
                $daysInactive = if ($user.LastLogonDate) {
                    [math]::Round((New-TimeSpan -Start $user.LastLogonDate -End (Get-Date)).TotalDays)
                }
                else {
                    $null
                }

                # Get manager name
                $managerName = if ($user.Manager) {
                    try {
                        (Get-ADUser -Identity $user.Manager -ErrorAction SilentlyContinue).Name
                    }
                    catch {
                        $user.Manager
                    }
                }
                else {
                    $null
                }

                # Extract OU path
                $ouPath = if ($user.DistinguishedName -match '^CN=.+?,(.+)$') {
                    $matches[1]
                }
                else {
                    $user.DistinguishedName
                }

                $results.Add([PSCustomObject]@{
                        PSTypeName           = 'EnterpriseAD.UserInventory'
                        SamAccountName       = $user.SamAccountName
                        Name                 = $user.Name
                        EmailAddress         = $user.EmailAddress
                        Department           = $user.Department
                        Title                = $user.Title
                        Manager              = $managerName
                        Enabled              = $user.Enabled
                        LockedOut            = $user.LockedOut
                        PasswordExpired      = $user.PasswordExpired
                        PasswordNeverExpires = $user.PasswordNeverExpires
                        PasswordLastSet      = $user.PasswordLastSet
                        LastLogonDate        = $user.LastLogonDate
                        DaysInactive         = $daysInactive
                        whenCreated          = $user.whenCreated
                        Description          = $user.Description
                        OrganizationalUnit   = $ouPath
                        DistinguishedName    = $user.DistinguishedName
                    }) | Out-Null
            }

            Write-Verbose "Found $($results.Count) users matching criteria"
            return $results | Sort-Object Name

        }
        catch {
            Write-Error "Failed to retrieve user inventory: $_"
            throw
        }
    }
}
