function Get-ADComputerInventory {
    <#
    .SYNOPSIS
        Generates a comprehensive computer inventory from Active Directory.

    .DESCRIPTION
        Retrieves detailed information about all computers in Active Directory including
        operating system, last logon, enabled status, and organizational unit.

    .PARAMETER OperatingSystem
        Filter by operating system (supports wildcards, e.g., "*Server 2022*").

    .PARAMETER IncludeDisabled
        Include disabled computer accounts in the inventory.

    .PARAMETER SearchBase
        Optional OU distinguished name to limit the search scope.

    .PARAMETER DaysInactive
        Only include computers that have logged on within the specified days.

    .EXAMPLE
        Get-ADComputerInventory
        Get inventory of all enabled computers.

    .EXAMPLE
        Get-ADComputerInventory -OperatingSystem "*Server 2022*"
        Get inventory of Windows Server 2022 computers.

    .EXAMPLE
        Get-ADComputerInventory -DaysInactive 90 -IncludeDisabled
        Get all computers (including disabled) that logged on in the last 90 days.

    .OUTPUTS
        PSCustomObject with computer inventory details.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OperatingSystem,

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
                    'OperatingSystem', 'OperatingSystemVersion', 'LastLogonDate',
                    'Enabled', 'IPv4Address', 'Description', 'whenCreated',
                    'DistinguishedName', 'DNSHostName'
                )
            }

            if ($SearchBase) {
                $searchParams['SearchBase'] = $SearchBase
            }

            Write-Verbose "Retrieving computer inventory..."
            $computers = Get-ADComputer @searchParams

            # Apply filters
            if ($OperatingSystem) {
                $computers = $computers | Where-Object { $_.OperatingSystem -like $OperatingSystem }
            }

            if (-not $IncludeDisabled) {
                $computers = $computers | Where-Object { $_.Enabled -eq $true }
            }

            if ($DaysInactive) {
                $cutoffDate = (Get-Date).AddDays(-$DaysInactive)
                $computers = $computers | Where-Object {
                    $_.LastLogonDate -and $_.LastLogonDate -gt $cutoffDate
                }
            }

            foreach ($computer in $computers) {
                $daysInactive = if ($computer.LastLogonDate) {
                    [math]::Round((New-TimeSpan -Start $computer.LastLogonDate -End (Get-Date)).TotalDays)
                }
                else {
                    $null
                }

                # Extract OU path
                $ouPath = if ($computer.DistinguishedName -match '^CN=.+?,(.+)$') {
                    $matches[1]
                }
                else {
                    $computer.DistinguishedName
                }

                $results.Add([PSCustomObject]@{
                        PSTypeName              = 'EnterpriseAD.ComputerInventory'
                        Name                    = $computer.Name
                        DNSHostName             = $computer.DNSHostName
                        OperatingSystem         = $computer.OperatingSystem
                        OperatingSystemVersion  = $computer.OperatingSystemVersion
                        Enabled                 = $computer.Enabled
                        IPv4Address             = $computer.IPv4Address
                        LastLogonDate           = $computer.LastLogonDate
                        DaysInactive            = $daysInactive
                        whenCreated             = $computer.whenCreated
                        Description             = $computer.Description
                        OrganizationalUnit      = $ouPath
                        DistinguishedName       = $computer.DistinguishedName
                    }) | Out-Null
            }

            Write-Verbose "Found $($results.Count) computers matching criteria"
            return $results | Sort-Object Name

        }
        catch {
            Write-Error "Failed to retrieve computer inventory: $_"
            throw
        }
    }
}
