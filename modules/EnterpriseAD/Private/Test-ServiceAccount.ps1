function Test-ServiceAccount {
    <#
    .SYNOPSIS
        Identifies if an account is likely a service account.

    .DESCRIPTION
        Internal helper function that uses heuristics to identify service accounts
        based on naming patterns and account properties.

    .PARAMETER Account
        AD user account object to test.

    .OUTPUTS
        Boolean indicating if the account is likely a service account.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$Account
    )

    process {
        try {
            # Check naming patterns
            $name = $Account.SamAccountName.ToLower()

            foreach ($indicator in $script:ServiceAccountIndicators) {
                if ($name -like $indicator) {
                    Write-Verbose "Account $($Account.SamAccountName) matches service account pattern: $indicator"
                    return $true
                }
            }

            # Check description for service account keywords
            if ($Account.Description) {
                $description = $Account.Description.ToLower()
                $serviceKeywords = @('service account', 'service user', 'application account', 'app account')

                foreach ($keyword in $serviceKeywords) {
                    if ($description -match $keyword) {
                        Write-Verbose "Account $($Account.SamAccountName) description indicates service account"
                        return $true
                    }
                }
            }

            # Check if password never expires (common for service accounts)
            if ($Account.PasswordNeverExpires) {
                Write-Verbose "Account $($Account.SamAccountName) has PasswordNeverExpires set"
                # Don't return true solely on this, but it's an indicator
            }

            return $false

        }
        catch {
            Write-Warning "Failed to test service account for $($Account.SamAccountName): $_"
            return $false
        }
    }
}
