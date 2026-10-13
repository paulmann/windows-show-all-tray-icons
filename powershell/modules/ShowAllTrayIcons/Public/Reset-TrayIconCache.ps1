function Reset-TrayIconCache {
    <#
    .SYNOPSIS
        Deletes the legacy tray icon cache so Windows rebuilds icon registrations.

    .DESCRIPTION
        Removes IconStreams / PastIconsStream from the pre-1703 cache location
        (HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\
        TrayNotify) and restarts Explorer. Use this when the tray shows phantom icons,
        wrong icons, or stale entries. On modern Windows 11 this key is often absent --
        the command then reports "nothing to do". WARNING: all per-icon visibility
        choices are forgotten; run Enable-AllTrayIcons afterwards.

    .PARAMETER SkipExplorerRestart
        Do not restart Explorer (the cache rebuild then happens at next sign-in).

    .EXAMPLE
        Reset-TrayIconCache

    .OUTPUTS
        System.Management.Automation.PSCustomObject

    .LINK
        https://github.com/paulmann/windows-show-all-tray-icons/blob/main/docs/CLI-REFERENCE.md
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [switch] $SkipExplorerRestart
    )

    script:Assert-WindowsPlatform | Out-Null

    $summary = [ordered]@{
        Action          = 'ResetCache'
        DeletedValues   = @()
        KeyPresent      = $false
        ExplorerRestarted = $null
    }

    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey([TrayPolicy]::LegacyTrayNotifyKey, $true)
    if (-not $key) {
        Write-Warning 'Legacy TrayNotify cache key not present (normal on Windows 11); nothing to reset.'
        return [pscustomobject] $summary
    }

    try {
        $summary.KeyPresent = $true
        foreach ($valueName in [TrayPolicy]::LegacyCacheValues) {
            if ($null -ne $key.GetValue($valueName)) {
                if ($PSCmdlet.ShouldProcess("TrayNotify\$valueName", 'Delete cached icon stream')) {
                    $key.DeleteValue($valueName, $false)
                    $summary.DeletedValues += $valueName
                    script:Write-TraceLog "Deleted legacy cache value: $valueName"
                }
            }
        }
    }
    finally {
        $key.Dispose()
    }

    if (-not $SkipExplorerRestart -and $summary.DeletedValues.Count -gt 0) {
        if ($PSCmdlet.ShouldProcess('explorer.exe', 'Restart to rebuild the tray icon cache')) {
            $restart = script:Restart-ExplorerCore
            $summary.ExplorerRestarted = $restart.Success
        }
    }

    [pscustomobject] $summary
}
