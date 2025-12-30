function Compare-GPOSettings {
    <#
    .SYNOPSIS
        Compares GPO settings from XML reports.

    .DESCRIPTION
        Internal helper function that performs detailed comparison between
        two GPO XML reports to identify added, removed, and modified settings.

    .PARAMETER ReferenceXml
        XML report content for the reference GPO.

    .PARAMETER DifferenceXml
        XML report content for the difference GPO.

    .OUTPUTS
        Array of differences with change type and details.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReferenceXml,

        [Parameter(Mandatory = $true)]
        [string]$DifferenceXml
    )

    process {
        try {
            $differences = [System.Collections.ArrayList]::new()

            [xml]$refXml = $ReferenceXml
            [xml]$diffXml = $DifferenceXml

            # Compare Computer Configuration
            $refComputer = $refXml.GPO.Computer
            $diffComputer = $diffXml.GPO.Computer

            if ($refComputer -and $diffComputer) {
                # Compare Extension Data
                $refExtensions = $refComputer.ExtensionData
                $diffExtensions = $diffComputer.ExtensionData

                if ($refExtensions -and $diffExtensions) {
                    # Compare each extension type
                    foreach ($refExt in $refExtensions.Extension) {
                        $extType = $refExt.type

                        $diffExt = $diffExtensions.Extension | Where-Object { $_.type -eq $extType }

                        if (-not $diffExt) {
                            $differences.Add([PSCustomObject]@{
                                    ChangeType       = 'Removed'
                                    Category         = 'Computer Configuration'
                                    Setting          = $extType
                                    ReferenceValue   = 'Configured'
                                    DifferenceValue  = 'Not Configured'
                                }) | Out-Null
                        }
                        else {
                            # Deep comparison of settings within extension
                            # (Simplified - full implementation would parse all setting types)
                            $refSettings = ($refExt.InnerXml | Out-String).Trim()
                            $diffSettings = ($diffExt.InnerXml | Out-String).Trim()

                            if ($refSettings -ne $diffSettings) {
                                $differences.Add([PSCustomObject]@{
                                        ChangeType      = 'Modified'
                                        Category        = 'Computer Configuration'
                                        Setting         = $extType
                                        ReferenceValue  = 'Modified'
                                        DifferenceValue = 'Modified'
                                    }) | Out-Null
                            }
                        }
                    }

                    # Check for added extensions
                    foreach ($diffExt in $diffExtensions.Extension) {
                        $extType = $diffExt.type

                        $refExt = $refExtensions.Extension | Where-Object { $_.type -eq $extType }

                        if (-not $refExt) {
                            $differences.Add([PSCustomObject]@{
                                    ChangeType      = 'Added'
                                    Category        = 'Computer Configuration'
                                    Setting         = $extType
                                    ReferenceValue  = 'Not Configured'
                                    DifferenceValue = 'Configured'
                                }) | Out-Null
                        }
                    }
                }
            }

            # Compare User Configuration (similar logic)
            $refUser = $refXml.GPO.User
            $diffUser = $diffXml.GPO.User

            if ($refUser -and $diffUser) {
                $refExtensions = $refUser.ExtensionData
                $diffExtensions = $diffUser.ExtensionData

                if ($refExtensions -and $diffExtensions) {
                    foreach ($refExt in $refExtensions.Extension) {
                        $extType = $refExt.type

                        $diffExt = $diffExtensions.Extension | Where-Object { $_.type -eq $extType }

                        if (-not $diffExt) {
                            $differences.Add([PSCustomObject]@{
                                    ChangeType      = 'Removed'
                                    Category        = 'User Configuration'
                                    Setting         = $extType
                                    ReferenceValue  = 'Configured'
                                    DifferenceValue = 'Not Configured'
                                }) | Out-Null
                        }
                        else {
                            $refSettings = ($refExt.InnerXml | Out-String).Trim()
                            $diffSettings = ($diffExt.InnerXml | Out-String).Trim()

                            if ($refSettings -ne $diffSettings) {
                                $differences.Add([PSCustomObject]@{
                                        ChangeType      = 'Modified'
                                        Category        = 'User Configuration'
                                        Setting         = $extType
                                        ReferenceValue  = 'Modified'
                                        DifferenceValue = 'Modified'
                                    }) | Out-Null
                            }
                        }
                    }

                    # Check for added extensions
                    foreach ($diffExt in $diffExtensions.Extension) {
                        $extType = $diffExt.type

                        $refExt = $refExtensions.Extension | Where-Object { $_.type -eq $extType }

                        if (-not $refExt) {
                            $differences.Add([PSCustomObject]@{
                                    ChangeType      = 'Added'
                                    Category        = 'User Configuration'
                                    Setting         = $extType
                                    ReferenceValue  = 'Not Configured'
                                    DifferenceValue = 'Configured'
                                }) | Out-Null
                        }
                    }
                }
            }

            return $differences

        }
        catch {
            Write-Warning "Failed to compare GPO settings: $_"
            return @()
        }
    }
}
