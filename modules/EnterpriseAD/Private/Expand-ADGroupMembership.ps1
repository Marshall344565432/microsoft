function Expand-ADGroupMembership {
    <#
    .SYNOPSIS
        Recursively expands Active Directory group membership.

    .DESCRIPTION
        Internal helper function that recursively expands group memberships
        to find all effective members including those from nested groups.

    .PARAMETER GroupDN
        Distinguished name of the group to expand.

    .PARAMETER Recursive
        Recursively expand nested groups.

    .PARAMETER MembershipPath
        Internal parameter to track the membership path during recursion.

    .PARAMETER ProcessedGroups
        Internal parameter to track already processed groups and prevent infinite loops.

    .OUTPUTS
        Array of member objects with membership path information.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupDN,

        [Parameter(Mandatory = $false)]
        [switch]$Recursive,

        [Parameter(Mandatory = $false)]
        [string[]]$MembershipPath = @(),

        [Parameter(Mandatory = $false)]
        [System.Collections.Generic.HashSet[string]]$ProcessedGroups
    )

    begin {
        if ($null -eq $ProcessedGroups) {
            $ProcessedGroups = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        }
    }

    process {
        # Prevent infinite recursion
        if ($ProcessedGroups.Contains($GroupDN)) {
            Write-Verbose "Skipping already processed group: $GroupDN"
            return
        }

        $ProcessedGroups.Add($GroupDN) | Out-Null

        try {
            # Get the group
            $group = Get-ADGroup -Identity $GroupDN -ErrorAction Stop

            # Update membership path
            $currentPath = $MembershipPath + $group.Name

            # Get direct members
            $members = Get-ADGroupMember -Identity $GroupDN -ErrorAction Stop

            $results = [System.Collections.ArrayList]::new()

            foreach ($member in $members) {
                if ($member.ObjectClass -eq 'group' -and $Recursive) {
                    # Recursively expand nested group
                    $nestedMembers = Expand-ADGroupMembership -GroupDN $member.DistinguishedName `
                        -Recursive `
                        -MembershipPath $currentPath `
                        -ProcessedGroups $ProcessedGroups

                    foreach ($nestedMember in $nestedMembers) {
                        $results.Add($nestedMember) | Out-Null
                    }
                }
                else {
                    # Add member to results
                    $results.Add([PSCustomObject]@{
                            ObjectClass       = $member.ObjectClass
                            SamAccountName    = $member.SamAccountName
                            Name              = $member.Name
                            DistinguishedName = $member.DistinguishedName
                            MembershipPath    = $currentPath
                            IsDirect          = ($MembershipPath.Count -eq 0)
                        }) | Out-Null
                }
            }

            return $results

        }
        catch {
            Write-Warning "Failed to expand group membership for $GroupDN: $_"
            return @()
        }
    }
}
