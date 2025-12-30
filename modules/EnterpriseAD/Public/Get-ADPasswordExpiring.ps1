function Get-ADPasswordExpiring {
    <#
    .SYNOPSIS
        Finds user accounts with passwords expiring within a specified timeframe.

    .DESCRIPTION
        Identifies users whose passwords are set to expire soon.
        Excludes accounts with passwords set to never expire unless specified.
        Useful for proactive password expiration notifications.

    .PARAMETER DaysAhead
        Number of days ahead to check for password expiration. Default is 14 days.

    .PARAMETER IncludeNeverExpire
        Include accounts with passwords set to never expire.

    .PARAMETER IncludeDisabled
        Include disabled accounts in the results.

    .PARAMETER SearchBase
        Optional OU distinguished name to limit the search scope.

    .EXAMPLE
        Get-ADPasswordExpiring -DaysAhead 7
        Find users whose passwords expire within 7 days.

    .EXAMPLE
        Get-ADPasswordExpiring -DaysAhead 30 -IncludeDisabled
        Find all accounts (including disabled) with passwords expiring within 30 days.

    .OUTPUTS
        PSCustomObject with user details and password expiration information.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysAhead = 14,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeNeverExpire,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeDisabled,

        [Parameter(Mandatory = $false)]
        [string]$SearchBase
    )

    begin {
        $results = [System.Collections.ArrayList]::new()
        $targetDate = (Get-Date).AddDays($DaysAhead)

        Write-Verbose "Checking for passwords expiring before: $($targetDate.ToString('yyyy-MM-dd'))"
    }

    process {
        try {
            # Get domain password policy
            $domain = Get-ADDomain
            $defaultMaxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge

            if ($defaultMaxPasswordAge -eq $null -or $defaultMaxPasswordAge.Days -eq 0) {
                Write-Warning "Domain password policy has no maximum password age configured"
                $defaultMaxPasswordAge = [TimeSpan]::FromDays(42) # Default fallback
            }

            $searchParams = @{
                Filter     = '*'
                Properties = @('PasswordLastSet', 'PasswordNeverExpires', 'Enabled', 'EmailAddress', 'LastLogonDate', 'Description')
            }

            if ($SearchBase) {
                $searchParams['SearchBase'] = $SearchBase
            }

            $users = Get-ADUser @searchParams

            foreach ($user in $users) {
                # Skip disabled accounts unless specified
                if (-not $IncludeDisabled -and -not $user.Enabled) { continue }

                # Skip password never expires unless specified
                if (-not $IncludeNeverExpire -and $user.PasswordNeverExpires) { continue }

                # Calculate password expiration date
                if ($user.PasswordLastSet -and -not $user.PasswordNeverExpires) {
                    $expirationDate = $user.PasswordLastSet + $defaultMaxPasswordAge
                    $daysUntilExpiration = [math]::Round((New-TimeSpan -Start (Get-Date) -End $expirationDate).TotalDays)

                    # Check if expiring within the target window
                    if ($expirationDate -le $targetDate -and $expirationDate -gt (Get-Date)) {
                        $results.Add([PSCustomObject]@{
                                PSTypeName           = 'EnterpriseAD.PasswordExpiring'
                                SamAccountName       = $user.SamAccountName
                                Name                 = $user.Name
                                EmailAddress         = $user.EmailAddress
                                Enabled              = $user.Enabled
                                PasswordLastSet      = $user.PasswordLastSet
                                PasswordExpiresOn    = $expirationDate
                                DaysUntilExpiration  = $daysUntilExpiration
                                PasswordNeverExpires = $user.PasswordNeverExpires
                                LastLogonDate        = $user.LastLogonDate
                                Description          = $user.Description
                                DistinguishedName    = $user.DistinguishedName
                            }) | Out-Null
                    }
                }
                elseif ($IncludeNeverExpire -and $user.PasswordNeverExpires) {
                    $results.Add([PSCustomObject]@{
                            PSTypeName           = 'EnterpriseAD.PasswordExpiring'
                            SamAccountName       = $user.SamAccountName
                            Name                 = $user.Name
                            EmailAddress         = $user.EmailAddress
                            Enabled              = $user.Enabled
                            PasswordLastSet      = $user.PasswordLastSet
                            PasswordExpiresOn    = $null
                            DaysUntilExpiration  = $null
                            PasswordNeverExpires = $true
                            LastLogonDate        = $user.LastLogonDate
                            Description          = $user.Description
                            DistinguishedName    = $user.DistinguishedName
                        }) | Out-Null
                }
            }

            Write-Verbose "Found $($results.Count) accounts with expiring passwords"
            return $results | Sort-Object DaysUntilExpiration

        }
        catch {
            Write-Error "Failed to retrieve password expiration information: $_"
            throw
        }
    }
}
