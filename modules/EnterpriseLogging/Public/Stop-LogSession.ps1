function Stop-LogSession {
    <#
    .SYNOPSIS
        Stops the current logging session.

    .DESCRIPTION
        Ends the current logging session and clears the session correlation ID.
        Logs a session end event with duration information.

    .EXAMPLE
        Start-LogSession -SessionName "Deployment"
        # ... operations ...
        Stop-LogSession
    #>
    [CmdletBinding()]
    param()

    process {
        if ($script:LogConfiguration.SessionId) {
            Write-EnterpriseLog -Message "Log session ended" -Level Information
            $script:LogConfiguration.SessionId = $null
        }
        else {
            Write-Warning "No active log session to stop"
        }
    }
}
