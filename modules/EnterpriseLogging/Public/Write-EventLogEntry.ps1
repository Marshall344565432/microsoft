function Write-EventLogEntry {
    <#
    .SYNOPSIS
        Writes a direct entry to Windows Event Log.

    .DESCRIPTION
        Simplified function for writing directly to Windows Event Log without
        the full structured logging pipeline. Useful for quick Event Log entries.

    .PARAMETER Message
        The event log message.

    .PARAMETER EventId
        Event ID number (1000-9999 recommended).

    .PARAMETER EntryType
        Entry type: Information, Warning, Error, SuccessAudit, FailureAudit.

    .PARAMETER Source
        Event source name. Defaults to configured source.

    .PARAMETER LogName
        Event log name. Defaults to 'Application'.

    .EXAMPLE
        Write-EventLogEntry -Message "Service started" -EventId 1001 -EntryType Information

    .EXAMPLE
        Write-EventLogEntry -Message "Authentication failed" -EventId 4625 -EntryType FailureAudit
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 65535)]
        [int]$EventId = 1000,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Information', 'Warning', 'Error', 'SuccessAudit', 'FailureAudit')]
        [string]$EntryType = 'Information',

        [Parameter(Mandatory = $false)]
        [string]$Source,

        [Parameter(Mandatory = $false)]
        [string]$LogName = 'Application'
    )

    process {
        try {
            if (-not $Source) {
                $Source = $script:LogConfiguration.EventLogSource
            }

            # Verify source exists
            if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) {
                Write-Warning "Event Log source '$Source' does not exist. Entry not written."
                return
            }

            Write-EventLog -LogName $LogName `
                -Source $Source `
                -EventId $EventId `
                -EntryType $EntryType `
                -Message $Message

            Write-Verbose "Event Log entry written: $Message"
        }
        catch {
            Write-Warning "Failed to write Event Log entry: $($_.Exception.Message)"
        }
    }
}
