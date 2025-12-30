function Get-ADPrivilegedUsers {
    <#
    .SYNOPSIS
        Retrieves all users with privileged access in Active Directory.

    .DESCRIPTION
        Identifies users who are members of privileged groups (Domain Admins, Enterprise Admins, etc.).
        Recursively expands nested group memberships to find all effective privileged users.
        Provides detailed information about group membership paths.

    .PARAMETER IncludeGroups
        Array of additional groups to consider as privileged beyond the default list.

    .PARAMETER ExcludeGroups
        Array of groups to exclude from the privileged group list.

    .PARAMETER ShowMembershipPath
        Include the full membership path showing how the user gained privilege.

    .EXAMPLE
        Get-ADPrivilegedUsers
        Get all users with privileged access using default privileged groups.

    .EXAMPLE
        Get-ADPrivilegedUsers -ShowMembershipPath
        Get privileged users with detailed membership path information.

    .EXAMPLE
        Get-ADPrivilegedUsers -IncludeGroups @('Custom Admins', 'Security Team')
        Include custom groups in the privileged group scan.

    .OUTPUTS
        PSCustomObject with user details and group membership information.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$IncludeGroups = @(),

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludeGroups = @(),

        [Parameter(Mandatory = $false)]
        [switch]$ShowMembershipPath
    )

    begin {
        # Build privileged groups list
        $privilegedGroups = $script:PrivilegedGroups + $IncludeGroups |
        Where-Object { $_ -notin $ExcludeGroups } |
        Select-Object -Unique

        Write-Verbose "Scanning $($privilegedGroups.Count) privileged groups"

        $results = @{}  # Use hashtable to track unique users
    }

    process {
        try {
            foreach ($groupName in $privilegedGroups) {
                Write-Verbose "Processing group: $groupName"

                try {
                    $group = Get-ADGroup -Identity $groupName -ErrorAction Stop
                }
                catch {
                    Write-Warning "Group not found: $groupName"
                    continue
                }

                # Get all members recursively
                $members = Expand-ADGroupMembership -GroupDN $group.DistinguishedName -Recursive

                foreach ($member in $members) {
                    # Only process user objects
                    if ($member.ObjectClass -ne 'user') { continue }

                    $userKey = $member.DistinguishedName

                    if (-not $results.ContainsKey($userKey)) {
                        # Get full user details
                        $user = Get-ADUser -Identity $member.DistinguishedName -Properties Enabled, LastLogonDate, Description, whenCreated

                        $results[$userKey] = [PSCustomObject]@{
                            PSTypeName        = 'EnterpriseAD.PrivilegedUser'
                            SamAccountName    = $user.SamAccountName
                            Name              = $user.Name
                            Enabled           = $user.Enabled
                            LastLogonDate     = $user.LastLogonDate
                            Description       = $user.Description
                            whenCreated       = $user.whenCreated
                            PrivilegedGroups  = [System.Collections.ArrayList]::new()
                            MembershipPaths   = [System.Collections.ArrayList]::new()
                            DistinguishedName = $user.DistinguishedName
                        }
                    }

                    # Add group to user's privileged groups list
                    if ($groupName -notin $results[$userKey].PrivilegedGroups) {
                        $results[$userKey].PrivilegedGroups.Add($groupName) | Out-Null
                    }

                    # Add membership path if requested
                    if ($ShowMembershipPath -and $member.MembershipPath) {
                        $pathString = $member.MembershipPath -join ' -> '
                        if ($pathString -notin $results[$userKey].MembershipPaths) {
                            $results[$userKey].MembershipPaths.Add($pathString) | Out-Null
                        }
                    }
                }
            }

            $outputResults = $results.Values | Sort-Object Name

            Write-Verbose "Found $($outputResults.Count) privileged users"
            return $outputResults

        }
        catch {
            Write-Error "Failed to retrieve privileged users: $_"
            throw
        }
    }
}
