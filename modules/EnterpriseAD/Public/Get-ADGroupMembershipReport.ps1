function Get-ADGroupMembershipReport {
    <#
    .SYNOPSIS
        Generates a detailed group membership report with recursive expansion.

    .DESCRIPTION
        Provides comprehensive group membership information including nested groups.
        Shows full membership paths and identifies direct vs. inherited membership.
        Supports filtering by user or group.

    .PARAMETER GroupName
        Name of the group to analyze.

    .PARAMETER UserName
        Optional username to filter results (show only this user's membership).

    .PARAMETER Recursive
        Recursively expand nested group memberships.

    .PARAMETER ShowMembershipPath
        Include the full membership path for each member.

    .EXAMPLE
        Get-ADGroupMembershipReport -GroupName "Domain Admins" -Recursive
        Get all members of Domain Admins including nested groups.

    .EXAMPLE
        Get-ADGroupMembershipReport -GroupName "IT Department" -ShowMembershipPath
        Get IT Department members with membership path details.

    .OUTPUTS
        PSCustomObject with group membership details.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupName,

        [Parameter(Mandatory = $false)]
        [string]$UserName,

        [Parameter(Mandatory = $false)]
        [switch]$Recursive,

        [Parameter(Mandatory = $false)]
        [switch]$ShowMembershipPath
    )

    process {
        try {
            # Get the group
            $group = Get-ADGroup -Identity $GroupName -ErrorAction Stop
            Write-Verbose "Analyzing group: $($group.Name)"

            $results = [System.Collections.ArrayList]::new()

            if ($Recursive) {
                # Use helper function for recursive expansion
                $members = Expand-ADGroupMembership -GroupDN $group.DistinguishedName -Recursive
            }
            else {
                # Get direct members only
                $directMembers = Get-ADGroupMember -Identity $group.DistinguishedName

                $members = $directMembers | ForEach-Object {
                    [PSCustomObject]@{
                        ObjectClass    = $_.ObjectClass
                        SamAccountName = $_.SamAccountName
                        Name           = $_.Name
                        DistinguishedName = $_.DistinguishedName
                        MembershipPath = @($group.Name)
                        IsDirect       = $true
                    }
                }
            }

            # Filter by username if specified
            if ($UserName) {
                $members = $members | Where-Object { $_.SamAccountName -eq $UserName }
            }

            foreach ($member in $members) {
                $memberType = switch ($member.ObjectClass) {
                    'user' { 'User' }
                    'computer' { 'Computer' }
                    'group' { 'Group' }
                    default { $member.ObjectClass }
                }

                $result = [PSCustomObject]@{
                    PSTypeName        = 'EnterpriseAD.GroupMember'
                    GroupName         = $group.Name
                    MemberName        = $member.Name
                    MemberType        = $memberType
                    SamAccountName    = $member.SamAccountName
                    IsDirect          = $member.IsDirect
                    DistinguishedName = $member.DistinguishedName
                }

                if ($ShowMembershipPath -and $member.MembershipPath) {
                    $result | Add-Member -MemberType NoteProperty -Name 'MembershipPath' -Value ($member.MembershipPath -join ' -> ')
                }

                $results.Add($result) | Out-Null
            }

            Write-Verbose "Found $($results.Count) members"
            return $results | Sort-Object MemberType, MemberName

        }
        catch {
            Write-Error "Failed to generate group membership report: $_"
            throw
        }
    }
}
