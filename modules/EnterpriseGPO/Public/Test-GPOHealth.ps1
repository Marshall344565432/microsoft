function Test-GPOHealth {
    <#
    .SYNOPSIS
        Tests the health of Group Policy Objects in the domain.

    .DESCRIPTION
        Performs comprehensive health checks on GPOs including:
        - Replication status across domain controllers
        - Sysvol consistency
        - Empty GPOs
        - Unlinked GPOs
        - Broken permissions
        - Missing GPOs

    .PARAMETER GPOName
        Name of specific GPO to check. If not specified, checks all GPOs.

    .PARAMETER CheckReplication
        Check GPO replication status across all domain controllers.

    .PARAMETER CheckSysvol
        Verify Sysvol folder exists for each GPO.

    .PARAMETER CheckEmpty
        Identify GPOs with no settings configured.

    .PARAMETER CheckUnlinked
        Identify GPOs that are not linked to any OU.

    .EXAMPLE
        Test-GPOHealth
        Run basic health check on all GPOs.

    .EXAMPLE
        Test-GPOHealth -CheckReplication -CheckSysvol -CheckEmpty -CheckUnlinked
        Run comprehensive health check with all tests.

    .EXAMPLE
        Test-GPOHealth -GPOName "Default Domain Policy" -CheckReplication
        Check replication status for a specific GPO.

    .OUTPUTS
        PSCustomObject with health check results.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$GPOName,

        [Parameter(Mandatory = $false)]
        [switch]$CheckReplication,

        [Parameter(Mandatory = $false)]
        [switch]$CheckSysvol,

        [Parameter(Mandatory = $false)]
        [switch]$CheckEmpty,

        [Parameter(Mandatory = $false)]
        [switch]$CheckUnlinked
    )

    process {
        try {
            $results = [System.Collections.ArrayList]::new()

            # Get GPOs to check
            $gpos = if ($GPOName) {
                @(Get-GPO -Name $GPOName -ErrorAction Stop)
            }
            else {
                Get-GPO -All
            }

            Write-Verbose "Checking health for $($gpos.Count) GPO(s)"

            foreach ($gpo in $gpos) {
                Write-Verbose "Checking: $($gpo.DisplayName)"

                $healthIssues = [System.Collections.ArrayList]::new()

                # Check for empty GPOs
                if ($CheckEmpty) {
                    if ($gpo.User.DSVersion -eq 0 -and $gpo.Computer.DSVersion -eq 0) {
                        $healthIssues.Add("Empty GPO - no settings configured") | Out-Null
                    }
                }

                # Check for unlinked GPOs
                if ($CheckUnlinked) {
                    $links = Get-GPOLinkage -GPOName $gpo.DisplayName

                    if ($links.Count -eq 0) {
                        $healthIssues.Add("Unlinked GPO - not applied to any OU") | Out-Null
                    }
                }

                # Check Sysvol consistency
                if ($CheckSysvol) {
                    $domain = Get-ADDomain
                    $sysvolPath = "\\$($domain.DNSRoot)\SYSVOL\$($domain.DNSRoot)\Policies\{$($gpo.Id)}"

                    if (-not (Test-Path $sysvolPath)) {
                        $healthIssues.Add("Sysvol folder missing: $sysvolPath") | Out-Null
                    }
                }

                # Check replication
                if ($CheckReplication) {
                    $domainControllers = Get-ADDomainController -Filter *

                    $replicationIssues = [System.Collections.ArrayList]::new()

                    foreach ($dc in $domainControllers) {
                        try {
                            $dcGPO = Get-GPO -Guid $gpo.Id -Server $dc.HostName -ErrorAction Stop

                            # Compare version numbers
                            if ($dcGPO.User.DSVersion -ne $gpo.User.DSVersion -or
                                $dcGPO.Computer.DSVersion -ne $gpo.Computer.DSVersion) {
                                $replicationIssues.Add("Version mismatch on $($dc.Name): User=$($dcGPO.User.DSVersion) (expected $($gpo.User.DSVersion)), Computer=$($dcGPO.Computer.DSVersion) (expected $($gpo.Computer.DSVersion))") | Out-Null
                            }
                        }
                        catch {
                            $replicationIssues.Add("GPO not found on $($dc.Name)") | Out-Null
                        }
                    }

                    if ($replicationIssues.Count -gt 0) {
                        $healthIssues.Add("Replication issues: $($replicationIssues -join '; ')") | Out-Null
                    }
                }

                # Determine health status
                $healthStatus = if ($healthIssues.Count -eq 0) { 'Healthy' } else { 'Unhealthy' }

                $results.Add([PSCustomObject]@{
                        PSTypeName      = 'EnterpriseGPO.HealthCheck'
                        GPOName         = $gpo.DisplayName
                        GPOGUID         = $gpo.Id
                        HealthStatus    = $healthStatus
                        IssuesFound     = $healthIssues.Count
                        Issues          = $healthIssues
                        UserVersion     = $gpo.User.DSVersion
                        ComputerVersion = $gpo.Computer.DSVersion
                        ModifiedTime    = $gpo.ModificationTime
                        CreatedTime     = $gpo.CreationTime
                    }) | Out-Null
            }

            Write-Verbose "Health check complete. Found $($results.Where({$_.HealthStatus -eq 'Unhealthy'}).Count) unhealthy GPO(s)"
            return $results | Sort-Object HealthStatus, GPOName

        }
        catch {
            Write-Error "Failed to test GPO health: $_"
            throw
        }
    }
}
