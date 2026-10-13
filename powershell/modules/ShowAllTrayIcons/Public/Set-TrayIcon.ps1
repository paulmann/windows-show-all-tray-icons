function Set-TrayIcon {
    <#
    .SYNOPSIS
        Shows or hides individual notification-area icons.

    .DESCRIPTION
        Per-icon control over the same store Windows Settings uses
        (HKCU\Control Panel\NotifyIconSettings). Target icons either by their registry Id
        (GUID) or by an executable wildcard. Every matching icon is updated and the
        refreshed [TrayIconInfo] objects are returned.

    .PARAMETER Id
        Exact NotifyIconSettings subkey name (GUID), e.g. '{B15FA34F-...}'.

    .PARAMETER ExecutablePath
        Wildcard matched against the owning executable path and its file name,
        e.g. 'discord*', '*steam*'. All matches are updated.

    .PARAMETER Promoted
        $true = always visible on the taskbar; $false = hidden in the overflow flyout.

    .PARAMETER RestartExplorer
        Restart explorer.exe so the change applies immediately.

    .EXAMPLE
        Set-TrayIcon -ExecutablePath 'discord.exe' -Promoted $true

    .EXAMPLE
        Get-TrayIcon -Name '*onedrive*' | ForEach-Object { Set-TrayIcon -Id $_.Id -Promoted $false }

    .OUTPUTS
        TrayIconInfo

    .LINK
        https://github.com/paulmann/windows-show-all-tray-icons/blob/main/docs/CLI-REFERENCE.md
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ById')]
    [OutputType('TrayIconInfo')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById', Position = 0)]
        [string] $Id,

        [Parameter(Mandatory, ParameterSetName = 'ByExecutable', Position = 0)]
        [SupportsWildcards()]
        [string] $ExecutablePath,

        [Parameter(Mandatory)]
        [bool] $Promoted,

        [switch] $RestartExplorer
    )

    script:Assert-WindowsPlatform | Out-Null

    $root = script:Open-TraySettingsRoot -Writable
    try {
        $all = @(script:Get-AllTrayIconEntries -Root $root)
        $targets = switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                $match = @($all | Where-Object Id -EQ $Id)
                if ($match.Count -eq 0) {
                    Write-Error "No tray icon with Id '$Id'. Run Get-TrayIcon to list registered icons."
                    return
                }
                $match
            }
            'ByExecutable' {
                $match = @($all | Where-Object {
                        $_.ExecutablePath -and (
                            $_.ExecutablePath -like $ExecutablePath -or
                            [System.IO.Path]::GetFileName($_.ExecutablePath) -like $ExecutablePath -or
                            $_.DisplayName -like $ExecutablePath)
                    })
                if ($match.Count -eq 0) {
                    Write-Error "No tray icon matches '$ExecutablePath'. Run Get-TrayIcon to list registered icons."
                    return
                }
                $match
            }
        }

        $verb = if ($Promoted) { 'Show (promote)' } else { 'Hide (demote)' }
        foreach ($target in $targets) {
            if ($PSCmdlet.ShouldProcess("$($target.DisplayName) [$($target.Id)]", $verb)) {
                script:Set-TrayIconPromotionCore -Root $root -Id $target.Id -Promoted $Promoted
                script:Write-TraceLog "Set-TrayIcon: '$($target.DisplayName)' -> IsPromoted=$Promoted"
                $target.IsPromoted = $Promoted
                $target
            }
        }
    }
    finally {
        $root.Dispose()
    }

    if ($RestartExplorer) {
        if ($PSCmdlet.ShouldProcess('explorer.exe', 'Restart to apply changes immediately')) {
            script:Restart-ExplorerCore | Out-Null
        }
    }
}
