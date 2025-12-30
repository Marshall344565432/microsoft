function Get-GPOLinkage {
    <#
    .SYNOPSIS
        Retrieves GPO linkage information across the domain.

    .DESCRIPTION
        Identifies all OUs where a GPO is linked and provides detailed link information
        including link order, enabled status, and enforcement.

    .PARAMETER GPOName
        Name of the GPO to check linkage for. If not specified, reports all GPO links.

    .PARAMETER OU
        Specific OU to check for linked GPOs.

    .PARAMETER IncludeInherited
        Include inherited GPO links from parent OUs.

    .EXAMPLE
        Get-GPOLinkage -GPOName "Default Domain Policy"
        Get all OUs where the Default Domain Policy is linked.

    .EXAMPLE
        Get-GPOLinkage -OU "OU=Servers,DC=contoso,DC=com"
        Get all GPOs linked to a specific OU.

    .EXAMPLE
        Get-GPOLinkage
        Get all GPO links in the domain.

    .OUTPUTS
        PSCustomObject with GPO linkage details.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$GPOName,

        [Parameter(Mandatory = $false)]
        [string]$OU,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeInherited
    )

    process {
        try {
            $results = [System.Collections.ArrayList]::new()

            if ($GPOName) {
                # Get linkage for specific GPO
                Write-Verbose "Getting linkage for GPO: $GPOName"

                $gpo = Get-GPO -Name $GPOName -ErrorAction Stop

                # Find all OUs/containers with this GPO linked
                $linkedObjects = Get-ADObject -Filter "gPLink -like '*$($gpo.Id)*'" -Properties gPLink, distinguishedName

                foreach ($obj in $linkedObjects) {
                    # Parse gPLink attribute
                    $gplinkAttr = $obj.gPLink

                    if ($gplinkAttr -match "\[LDAP://.*?$($gpo.Id).*?\]") {
                        $linkInfo = $matches[0]

                        # Extract link properties
                        $isEnabled = $linkInfo -notmatch ';1\]'
                        $isEnforced = $linkInfo -match ';2\]'

                        # Get link order
                        $allLinks = $gplinkAttr -split '\]' | Where-Object { $_ -match 'LDAP://' }
                        $linkOrder = ($allLinks.IndexOf(($allLinks | Where-Object { $_ -match $gpo.Id }))) + 1

                        $results.Add([PSCustomObject]@{
                                PSTypeName = 'EnterpriseGPO.LinkageInfo'
                                GPOName    = $gpo.DisplayName
                                GPOGUID    = $gpo.Id
                                LinkedTo   = $obj.distinguishedName
                                LinkOrder  = $linkOrder
                                Enabled    = $isEnabled
                                Enforced   = $isEnforced
                            }) | Out-Null
                    }
                }
            }
            elseif ($OU) {
                # Get all GPOs linked to specific OU
                Write-Verbose "Getting GPOs linked to OU: $OU"

                $ouObject = Get-ADObject -Identity $OU -Properties gPLink -ErrorAction Stop

                if ($ouObject.gPLink) {
                    # Parse gPLink attribute
                    $links = $ouObject.gPLink -split '\]' | Where-Object { $_ -match 'LDAP://' }

                    $linkOrder = 1
                    foreach ($link in $links) {
                        if ($link -match 'CN=(\{[^}]+\})') {
                            $gpoGuid = $matches[1]

                            try {
                                $gpo = Get-GPO -Guid $gpoGuid -ErrorAction SilentlyContinue

                                if ($gpo) {
                                    $isEnabled = $link -notmatch ';1'
                                    $isEnforced = $link -match ';2'

                                    $results.Add([PSCustomObject]@{
                                            PSTypeName = 'EnterpriseGPO.LinkageInfo'
                                            GPOName    = $gpo.DisplayName
                                            GPOGUID    = $gpo.Id
                                            LinkedTo   = $OU
                                            LinkOrder  = $linkOrder
                                            Enabled    = $isEnabled
                                            Enforced   = $isEnforced
                                        }) | Out-Null

                                    $linkOrder++
                                }
                            }
                            catch {
                                Write-Warning "Failed to get GPO $gpoGuid : $_"
                            }
                        }
                    }
                }

                # Get inherited links if requested
                if ($IncludeInherited) {
                    Write-Verbose "Including inherited GPO links"

                    # Get parent OUs
                    $parentDN = $OU -replace '^[^,]+,', ''

                    while ($parentDN -match '(OU=|DC=)') {
                        $parentLinks = Get-GPOLinkage -OU $parentDN

                        foreach ($parentLink in $parentLinks) {
                            $parentLink | Add-Member -MemberType NoteProperty -Name 'Inherited' -Value $true -Force
                            $results.Add($parentLink) | Out-Null
                        }

                        $parentDN = $parentDN -replace '^[^,]+,', ''
                    }
                }
            }
            else {
                # Get all GPO links in the domain
                Write-Verbose "Getting all GPO links in the domain"

                $allOUs = Get-ADObject -Filter "gPLink -like '*'" -Properties gPLink, distinguishedName

                foreach ($ou in $allOUs) {
                    $ouLinks = Get-GPOLinkage -OU $ou.distinguishedName
                    $results.AddRange($ouLinks)
                }
            }

            Write-Verbose "Found $($results.Count) GPO link(s)"
            return $results | Sort-Object GPOName, LinkedTo

        }
        catch {
            Write-Error "Failed to get GPO linkage: $_"
            throw
        }
    }
}
