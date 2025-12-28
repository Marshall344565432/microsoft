function Get-CallerInfo {
    <#
    .SYNOPSIS
        Gets information about the calling function/script.

    .DESCRIPTION
        Retrieves caller information from the call stack for logging purposes.
        Internal helper function for Write-EnterpriseLog.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    try {
        $callStack = Get-PSCallStack

        # Skip this function and Write-EnterpriseLog to get actual caller
        $caller = $callStack | Where-Object {
            $_.Command -ne 'Get-CallerInfo' -and
            $_.Command -ne 'Write-EnterpriseLog'
        } | Select-Object -First 1

        if ($caller) {
            return @{
                FunctionName = $caller.Command
                ScriptName   = $caller.ScriptName
                LineNumber   = $caller.ScriptLineNumber
            }
        }
        else {
            return @{
                FunctionName = 'Unknown'
                ScriptName   = 'Unknown'
                LineNumber   = 0
            }
        }
    }
    catch {
        return @{
            FunctionName = 'Unknown'
            ScriptName   = 'Unknown'
            LineNumber   = 0
        }
    }
}
