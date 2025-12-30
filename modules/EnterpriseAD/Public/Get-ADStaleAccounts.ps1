function Get-ADStaleAccounts {
    <#
    .SYNOPSIS
        Finds stale user and computer accounts in Active Directory.

    .DESCRIPTION
        Identifies accounts that haven't been used within a specified time period.
        Excludes service accounts and disabled accounts by default.
        Supports filtering by account type (user, computer, or both).

    .PARAMETER DaysInactive
        Number of days of inactivity to consider an account stale. Default is 90 days.

    .PARAMETER AccountType
        Type of accounts to check: User, Computer, or Both. Default is Both.

    .PARAMETER IncludeDisabled
        Include disabled accounts in the results.

    .PARAMETER ExcludeServiceAccounts
        Exclude detected service accounts from results. Default is $true.

    .PARAMETER SearchBase
        Optional OU distinguished name to limit the search scope.

    .EXAMPLE
        Get-ADStaleAccounts -DaysInactive 90
        Find all user and computer accounts inactive for 90+ days.

    .EXAMPLE
        Get-ADStaleAccounts -AccountType User -DaysInactive 180 -IncludeDisabled
        Find user accounts inactive for 180+ days, including disabled accounts.

    .EXAMPLE
        Get-ADStaleAccounts -SearchBase "OU=Users,DC=contoso,DC=com" -DaysInactive 60
        Find stale accounts in a specific OU.

    .OUTPUTS
        PSCustomObject with account details including name, type, last logon, and days inactive.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysInactive = 90,

        [Parameter(Mandatory = $false)]
        [ValidateSet('User', 'Computer', 'Both')]
        [string]$AccountType = 'Both',

        [Parameter(Mandatory = $false)]
        [switch]$IncludeDisabled,

        [Parameter(Mandatory = $false)]
        [switch]$ExcludeServiceAccounts = $true,

        [Parameter(Mandatory = $false)]
        [string]$SearchBase
    )

    begin {
        $cutoffDate = (Get-Date).AddDays(-$DaysInactive)
        $results = [System.Collections.ArrayList]::new()

        Write-Verbose "Searching for accounts inactive since: $($cutoffDate.ToString('yyyy-MM-dd'))"
    }

    process {
        try {
            $searchParams = @{
                Properties = @('LastLogonDate', 'Enabled', 'Description', 'DistinguishedName', 'whenCreated')
            }

            if ($SearchBase) {
                $searchParams['SearchBase'] = $SearchBase
            }

            # Process user accounts
            if ($AccountType -in @('User', 'Both')) {
                Write-Verbose "Searching for stale user accounts..."

                $filter = if ($IncludeDisabled) {
                    { LastLogonDate -lt $cutoffDate -or (-not $_.LastLogonDate -and $_.whenCreated -lt $cutoffDate) }
                }
                else {
                    { (LastLogonDate -lt $cutoffDate -or (-not $_.LastLogonDate -and $_.whenCreated -lt $cutoffDate)) -and Enabled -eq $true }
                }

                $staleUsers = Get-ADUser -Filter * @searchParams | Where-Object $filter

                foreach ($user in $staleUsers) {
                    # Check if it's a service account
                    if ($ExcludeServiceAccounts -and (Test-ServiceAccount -Account $user)) {
                        Write-Verbose "Excluding service account: $($user.SamAccountName)"
                        continue
                    }

                    $lastLogon = if ($user.LastLogonDate) { $user.LastLogonDate } else { $user.whenCreated }
                    $daysInactive = [math]::Round((New-TimeSpan -Start $lastLogon -End (Get-Date)).TotalDays)

                    $results.Add([PSCustomObject]@{
                            PSTypeName        = 'EnterpriseAD.StaleAccount'
                            AccountType       = 'User'
                            SamAccountName    = $user.SamAccountName
                            Name              = $user.Name
                            Enabled           = $user.Enabled
                            LastLogonDate     = $lastLogon
                            DaysInactive      = $daysInactive
                            Description       = $user.Description
                            DistinguishedName = $user.DistinguishedName
                        }) | Out-Null
                }
            }

            # Process computer accounts
            if ($AccountType -in @('Computer', 'Both')) {
                Write-Verbose "Searching for stale computer accounts..."

                $filter = if ($IncludeDisabled) {
                    { LastLogonDate -lt $cutoffDate -or (-not $_.LastLogonDate -and $_.whenCreated -lt $cutoffDate) }
                }
                else {
                    { (LastLogonDate -lt $cutoffDate -or (-not $_.LastLogonDate -and $_.whenCreated -lt $cutoffDate)) -and Enabled -eq $true }
                }

                $staleComputers = Get-ADComputer -Filter * @searchParams | Where-Object $filter

                foreach ($computer in $staleComputers) {
                    $lastLogon = if ($computer.LastLogonDate) { $computer.LastLogonDate } else { $computer.whenCreated }
                    $daysInactive = [math]::Round((New-TimeSpan -Start $lastLogon -End (Get-Date)).TotalDays)

                    $results.Add([PSCustomObject]@{
                            PSTypeName        = 'EnterpriseAD.StaleAccount'
                            AccountType       = 'Computer'
                            SamAccountName    = $computer.SamAccountName
                            Name              = $computer.Name
                            Enabled           = $computer.Enabled
                            LastLogonDate     = $lastLogon
                            DaysInactive      = $daysInactive
                            Description       = $computer.Description
                            DistinguishedName = $computer.DistinguishedName
                        }) | Out-Null
                }
            }

            Write-Verbose "Found $($results.Count) stale accounts"
            return $results | Sort-Object DaysInactive -Descending

        }
        catch {
            Write-Error "Failed to retrieve stale accounts: $_"
            throw
        }
    }
}
