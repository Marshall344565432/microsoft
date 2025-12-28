function Start-LogSession {
    <#
    .SYNOPSIS
        Starts a new logging session with a unique correlation ID.

    .DESCRIPTION
        Creates a logging session that assigns a unique correlation ID to all
        subsequent log entries until Stop-LogSession is called. Useful for
        tracking related operations across multiple functions and scripts.

    .PARAMETER SessionName
        Optional name for the logging session.

    .EXAMPLE
        Start-LogSession
        Write-EnterpriseLog -Message "Session operation 1"
        Write-EnterpriseLog -Message "Session operation 2"
        Stop-LogSession

    .EXAMPLE
        Start-LogSession -SessionName "UserProvisioning-JSmith"
        # All logs will share the same correlation ID
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SessionName
    )

    process {
        $sessionId = [guid]::NewGuid().ToString()
        $script:LogConfiguration.SessionId = $sessionId

        $sessionInfo = @{
            SessionId   = $sessionId
            SessionName = $SessionName
            StartTime   = [DateTime]::UtcNow
            MachineName = $env:COMPUTERNAME
            Username    = "$env:USERDOMAIN\$env:USERNAME"
        }

        Write-EnterpriseLog -Message "Log session started" -Level Information -AdditionalData $sessionInfo

        return [PSCustomObject]$sessionInfo
    }
}
