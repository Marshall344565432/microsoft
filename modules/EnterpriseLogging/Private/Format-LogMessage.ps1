function Format-LogMessage {
    <#
    .SYNOPSIS
        Formats a log entry for Event Log or text display.

    .DESCRIPTION
        Converts structured log entry hashtable to human-readable text format.
        Internal helper function for Write-EnterpriseLog.

    .PARAMETER LogEntry
        Structured log entry hashtable.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$LogEntry
    )

    $lines = @()
    $lines += "Message: $($LogEntry.Message)"
    $lines += "Timestamp: $($LogEntry.Timestamp)"
    $lines += "Level: $($LogEntry.Level)"
    $lines += "Machine: $($LogEntry.MachineName)"
    $lines += "User: $($LogEntry.Username)"
    $lines += "CorrelationId: $($LogEntry.CorrelationId)"

    if ($LogEntry.CallerFunction) {
        $lines += "Caller: $($LogEntry.CallerFunction)"
        if ($LogEntry.CallerScript) {
            $lines += "Script: $($LogEntry.CallerScript):$($LogEntry.CallerLine)"
        }
    }

    if ($LogEntry.ExceptionType) {
        $lines += ""
        $lines += "Exception Details:"
        $lines += "  Type: $($LogEntry.ExceptionType)"
        $lines += "  Message: $($LogEntry.ExceptionMessage)"
        if ($LogEntry.StackTrace) {
            $lines += "  Stack Trace:"
            $lines += "    $($LogEntry.StackTrace -replace "`r?`n", "`n    ")"
        }
    }

    if ($LogEntry.AdditionalData) {
        $lines += ""
        $lines += "Additional Data:"
        foreach ($key in $LogEntry.AdditionalData.Keys) {
            $lines += "  $key = $($LogEntry.AdditionalData[$key])"
        }
    }

    return ($lines -join "`r`n")
}
