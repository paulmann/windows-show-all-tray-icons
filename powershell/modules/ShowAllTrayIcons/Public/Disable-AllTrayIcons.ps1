function Disable-AllTrayIcons {
    <#
    .SYNOPSIS
        Restores default Windows behavior: tray icons may be hidden in the overflow.

    .DESCRIPTION
        Sets IsPromoted = 0 for every registered icon (Windows will keep recently
        interactive icons in the overflow flyout instead of the taskbar) and removes the
        legacy EnableAutoTray override so Windows manages auto-hide again. This is the
        exact inverse of Enable-AllTrayIcons. Use Restore-TrayIconState instead when you
        want to roll back to a specific backup (per-icon choices preserved).

    .PARAMETER RestartExplorer
        Restart explorer.exe so the change applies immediately.

    .PARAMETER KeepLegacySwitch
        Do not touch the legacy EnableAutoTray value.

    .PARAMETER Force
        Bypass confirmation prompts.

    .PARAMETER AsJson
        Emit the summary as JSON.

    .EXAMPLE
        Disable-AllTrayIcons

    .EXAMPLE
        Disable-AllTrayIcons -RestartExplorer -Force

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    .OUTPUTS
        System.String

    .LINK
        https://github.com/paulmann/windows-show-all-tray-icons/blob/main/docs/CLI-REFERENCE.md
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns', '',
        Justification = 'Product command name: inverse of Enable-AllTrayIcons; matches documented CLI.')]
    [OutputType([pscustomobject])]
    [OutputType([string])]
    param(
        [switch] $RestartExplorer,

        [switch] $KeepLegacySwitch,

        [switch] $Force,

        [switch] $AsJson
    )

    if ($Force) { $ConfirmPreference = 'None' }
    script:Assert-WindowsPlatform | Out-Null

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $summary = [ordered]@{
        Action              = 'Disable'
        Timestamp           = (Get-Date).ToUniversalTime().ToString('o')
        TotalIcons          = 0
        Demoted             = 0
        Failed              = 0
        LegacySwitchRemoved = $false
        ExplorerRestarted   = $null
        DurationMs          = 0
    }

    $root = script:Open-TraySettingsRoot -Writable
    try {
        $icons = @(script:Get-AllTrayIconEntries -Root $root)
        $targets = @($icons | Where-Object IsPromoted)
        $summary.TotalIcons = $icons.Count

        $demoteGate = $targets.Count -gt 0 -and (script:Invoke-ShouldProcess -Cmdlet $PSCmdlet -Target ('{0} visible tray icon(s)' -f $targets.Count) -Action 'Return to Windows default (allow hiding)' -MachineReadable:$AsJson)
        if ($demoteGate) {
            foreach ($target in $targets) {
                try {
                    script:Set-TrayIconPromotionCore -Root $root -Id $target.Id -Promoted $false
                    $summary.Demoted++
                }
                catch {
                    $summary.Failed++
                    script:Write-TraceLog "FAILED to demote '$($target.DisplayName)' ($($target.Id)): $($_.Exception.Message)" 'ERROR'
                    if (-not $Force) {
                        Write-Warning "Could not demote '$($target.DisplayName)': $($_.Exception.Message)"
                    }
                }
            }
        }
    }
    finally {
        $root.Dispose()
    }

    if (-not $KeepLegacySwitch) {
        $current = script:Get-ExplorerKeyValue -Name ([TrayPolicy]::EnableAutoTrayName)
        if ($null -ne $current) {
            if (script:Invoke-ShouldProcess -Cmdlet $PSCmdlet -Target 'HKCU\...\Explorer\EnableAutoTray' -Action 'Remove value (restore Windows default)' -MachineReadable:$AsJson) {
                $summary.LegacySwitchRemoved = script:Remove-ExplorerKeyValue -Name ([TrayPolicy]::EnableAutoTrayName)
            }
        }
    }

    if ($RestartExplorer) {
        if (script:Invoke-ShouldProcess -Cmdlet $PSCmdlet -Target 'explorer.exe' -Action 'Restart to apply changes immediately' -MachineReadable:$AsJson) {
            $restart = script:Restart-ExplorerCore
            $summary.ExplorerRestarted = $restart.Success
        }
    }

    $stopwatch.Stop()
    $summary.DurationMs = $stopwatch.ElapsedMilliseconds
    $message = 'Disable finished: demoted={0} failed={1} in {2} ms' -f $summary.Demoted, $summary.Failed, $summary.DurationMs
    script:Write-TraceLog $message

    $result = [pscustomobject] $summary
    if ($AsJson) { return ($result | ConvertTo-Json -Depth 4) }
    $result
}
