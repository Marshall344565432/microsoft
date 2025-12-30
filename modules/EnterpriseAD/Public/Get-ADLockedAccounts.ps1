function Get-ADLockedAccounts {
    <#
    .SYNOPSIS
        Retrieves all locked user accounts in Active Directory.

    .DESCRIPTION
        Finds all currently locked user accounts with detailed lockout information.
        Includes lockout time, bad password attempts, and user details.

    .PARAMETER SearchBase
        Optional OU distinguished name to limit the search scope.

    .PARAMETER IncludeUnlockTime
        Calculate and include when the account will automatically unlock.

    .EXAMPLE
        Get-ADLockedAccounts
        Get all locked accounts in the domain.

    .EXAMPLE
        Get-ADLockedAccounts -SearchBase "OU=Users,DC=contoso,DC=com" -IncludeUnlockTime
        Get locked accounts in a specific OU with unlock time calculation.

    .OUTPUTS
        PSCustomObject with locked account details and lockout information.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SearchBase,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeUnlockTime
    )

    begin {
        $results = [System.Collections.ArrayList]::new()

        # Get lockout duration from domain policy
        $lockoutDuration = (Get-ADDefaultDomainPasswordPolicy).LockoutDuration
        Write-Verbose "Domain lockout duration: $($lockoutDuration.TotalMinutes) minutes"
    }

    process {
        try {
            $searchParams = @{
                Properties = @('LockedOut', 'LockoutTime', 'BadPwdCount', 'LastLogonDate', 'EmailAddress', 'Description', 'Enabled')
            }

            if ($SearchBase) {
                $searchParams['SearchBase'] = $SearchBase
            }

            # Use Search-ADAccount for locked accounts
            $lockedAccounts = Search-ADAccount -LockedOut @searchParams

            foreach ($account in $lockedAccounts) {
                $lockoutTime = if ($account.LockoutTime) {
                    [DateTime]::FromFileTime($account.LockoutTime)
                }
                else {
                    $null
                }

                $unlockTime = if ($IncludeUnlockTime -and $lockoutTime -and $lockoutDuration) {
                    $lockoutTime + $lockoutDuration
                }
                else {
                    $null
                }

                $minutesUntilUnlock = if ($unlockTime) {
                    $span = New-TimeSpan -Start (Get-Date) -End $unlockTime
                    if ($span.TotalMinutes -gt 0) {
                        [math]::Round($span.TotalMinutes, 1)
                    }
                    else {
                        0
                    }
                }
                else {
                    $null
                }

                $results.Add([PSCustomObject]@{
                        PSTypeName          = 'EnterpriseAD.LockedAccount'
                        SamAccountName      = $account.SamAccountName
                        Name                = $account.Name
                        EmailAddress        = $account.EmailAddress
                        Enabled             = $account.Enabled
                        LockedOut           = $account.LockedOut
                        LockoutTime         = $lockoutTime
                        UnlockTime          = $unlockTime
                        MinutesUntilUnlock  = $minutesUntilUnlock
                        BadPwdCount         = $account.BadPwdCount
                        LastLogonDate       = $account.LastLogonDate
                        Description         = $account.Description
                        DistinguishedName   = $account.DistinguishedName
                    }) | Out-Null
            }

            Write-Verbose "Found $($results.Count) locked accounts"
            return $results | Sort-Object LockoutTime -Descending

        }
        catch {
            Write-Error "Failed to retrieve locked accounts: $_"
            throw
        }
    }
}
