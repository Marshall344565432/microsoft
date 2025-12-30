function Test-ADReplicationHealth {
    <#
    .SYNOPSIS
        Tests Active Directory replication health across domain controllers.

    .DESCRIPTION
        Checks replication status, identifies replication failures, and provides
        detailed information about replication partners and last replication times.

    .PARAMETER DomainController
        Specific domain controller to check. If not specified, checks all DCs in the domain.

    .PARAMETER ShowPartners
        Include detailed replication partner information.

    .EXAMPLE
        Test-ADReplicationHealth
        Check replication health for all domain controllers.

    .EXAMPLE
        Test-ADReplicationHealth -DomainController "DC01" -ShowPartners
        Check replication health for DC01 with partner details.

    .OUTPUTS
        PSCustomObject with replication health status.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DomainController,

        [Parameter(Mandatory = $false)]
        [switch]$ShowPartners
    )

    process {
        try {
            $results = [System.Collections.ArrayList]::new()

            # Get domain controllers to check
            if ($DomainController) {
                $domainControllers = @(Get-ADDomainController -Identity $DomainController)
            }
            else {
                $domainControllers = Get-ADDomainController -Filter *
            }

            Write-Verbose "Checking replication health for $($domainControllers.Count) domain controller(s)"

            foreach ($dc in $domainControllers) {
                Write-Verbose "Checking DC: $($dc.HostName)"

                try {
                    # Get replication failures
                    $replFailures = Get-ADReplicationFailure -Target $dc.HostName -ErrorAction SilentlyContinue

                    # Get replication partners
                    $replPartners = Get-ADReplicationPartnerMetadata -Target $dc.HostName -ErrorAction SilentlyContinue

                    # Calculate health status
                    $hasFailures = $replFailures -ne $null -and $replFailures.Count -gt 0
                    $healthStatus = if ($hasFailures) { 'Unhealthy' } else { 'Healthy' }

                    # Get last replication time
                    $lastReplication = if ($replPartners) {
                        ($replPartners | Sort-Object LastReplicationSuccess -Descending | Select-Object -First 1).LastReplicationSuccess
                    }
                    else {
                        $null
                    }

                    $result = [PSCustomObject]@{
                        PSTypeName            = 'EnterpriseAD.ReplicationHealth'
                        DomainController      = $dc.Name
                        HostName              = $dc.HostName
                        Site                  = $dc.Site
                        HealthStatus          = $healthStatus
                        FailureCount          = if ($replFailures) { $replFailures.Count } else { 0 }
                        LastReplication       = $lastReplication
                        IsGlobalCatalog       = $dc.IsGlobalCatalog
                        IsReadOnly            = $dc.IsReadOnly
                        OperatingSystem       = $dc.OperatingSystem
                    }

                    if ($ShowPartners -and $replPartners) {
                        $partnerInfo = $replPartners | ForEach-Object {
                            [PSCustomObject]@{
                                Partner               = $_.Partner
                                Partition             = $_.Partition
                                LastReplicationSuccess = $_.LastReplicationSuccess
                                LastReplicationAttempt = $_.LastReplicationAttempt
                                ConsecutiveFailures   = $_.ConsecutiveReplicationFailures
                            }
                        }
                        $result | Add-Member -MemberType NoteProperty -Name 'ReplicationPartners' -Value $partnerInfo
                    }

                    if ($hasFailures) {
                        $failureDetails = $replFailures | ForEach-Object {
                            [PSCustomObject]@{
                                Partner       = $_.Partner
                                FirstFailure  = $_.FirstFailureTime
                                FailureCount  = $_.FailureCount
                                LastError     = $_.LastError
                            }
                        }
                        $result | Add-Member -MemberType NoteProperty -Name 'Failures' -Value $failureDetails
                    }

                    $results.Add($result) | Out-Null

                }
                catch {
                    Write-Warning "Failed to check replication for $($dc.HostName): $_"

                    $results.Add([PSCustomObject]@{
                            PSTypeName       = 'EnterpriseAD.ReplicationHealth'
                            DomainController = $dc.Name
                            HostName         = $dc.HostName
                            Site             = $dc.Site
                            HealthStatus     = 'Unknown'
                            FailureCount     = $null
                            LastReplication  = $null
                            Error            = $_.Exception.Message
                        }) | Out-Null
                }
            }

            Write-Verbose "Replication health check complete"
            return $results | Sort-Object HealthStatus, DomainController

        }
        catch {
            Write-Error "Failed to test AD replication health: $_"
            throw
        }
    }
}
