function Get-GPOBackupInfo {
    <#
    .SYNOPSIS
        Retrieves detailed metadata for a GPO backup.

    .DESCRIPTION
        Internal helper function that collects comprehensive GPO metadata
        including links, permissions, WMI filters, and delegation.

    .PARAMETER GPO
        GPO object to get metadata for.

    .OUTPUTS
        PSCustomObject with GPO metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.GroupPolicy.Gpo]$GPO
    )

    process {
        try {
            $metadata = [PSCustomObject]@{
                Name             = $GPO.DisplayName
                GUID             = $GPO.Id
                DomainName       = $GPO.DomainName
                CreatedTime      = $GPO.CreationTime
                ModifiedTime     = $GPO.ModificationTime
                UserVersion      = $GPO.User.DSVersion
                ComputerVersion  = $GPO.Computer.DSVersion
                Description      = $GPO.Description
                WMIFilter        = $null
                Links            = @()
                Permissions      = @()
            }

            # Get WMI filter
            if ($GPO.WmiFilter) {
                $metadata.WMIFilter = [PSCustomObject]@{
                    Name        = $GPO.WmiFilter.Name
                    Description = $GPO.WmiFilter.Description
                    Filter      = $GPO.WmiFilter.Filter
                }
            }

            # Get GPO links
            try {
                $linkedObjects = Get-ADObject -Filter "gPLink -like '*$($GPO.Id)*'" -Properties gPLink, distinguishedName -ErrorAction SilentlyContinue

                $metadata.Links = $linkedObjects | ForEach-Object {
                    $gplinkAttr = $_.gPLink

                    $isEnabled = $gplinkAttr -match "\[LDAP://.*?$($GPO.Id).*?\]" -and $gplinkAttr -notmatch ';1\]'
                    $isEnforced = $gplinkAttr -match ';2\]'

                    $allLinks = $gplinkAttr -split '\]' | Where-Object { $_ -match 'LDAP://' }
                    $linkOrder = ($allLinks.IndexOf(($allLinks | Where-Object { $_ -match $GPO.Id }))) + 1

                    [PSCustomObject]@{
                        Target   = $_.distinguishedName
                        Enabled  = $isEnabled
                        Enforced = $isEnforced
                        Order    = $linkOrder
                    }
                }
            }
            catch {
                Write-Warning "Failed to get GPO links: $_"
            }

            # Get GPO permissions
            try {
                $permissions = Get-GPPermission -Guid $GPO.Id -All -ErrorAction SilentlyContinue

                $metadata.Permissions = $permissions | ForEach-Object {
                    [PSCustomObject]@{
                        Trustee     = $_.Trustee.Name
                        TrusteeType = $_.TrusteeType
                        Permission  = $_.Permission
                        Inherited   = $_.Inherited
                    }
                }
            }
            catch {
                Write-Warning "Failed to get GPO permissions: $_"
            }

            return $metadata

        }
        catch {
            Write-Warning "Failed to get GPO backup info: $_"
            return $null
        }
    }
}
