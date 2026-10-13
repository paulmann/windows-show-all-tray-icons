function Start-TrayIconWatcher {
    <#
    .SYNOPSIS
        Watches the tray registry and instantly re-promotes icons Windows hides.

    .DESCRIPTION
        Explorer resets IsPromoted to 0 whenever an application (re)registers its tray
        icon -- this is why "show all icons" silently decays over time. The watcher
        prevents that:

        * Event-driven by default: arms RegNotifyChangeKeyValue on
          HKCU\Control Panel\NotifyIconSettings (subtree, NAME|LAST_SET), waits on an
          async event, debounces, then scans and promotes everything hidden.
        * -UsePolling falls back to a plain scan loop (every -IntervalSec seconds).
        * New subkeys are reported as discoveries; promotions are logged and can trigger
          your -OnPromoted callback and (optionally) an Explorer restart.
        * -AsJob runs it in a background thread job (Microsoft.PowerShell.ThreadJob).
        * Ctrl+C stops cleanly; -TimeoutSec bounds unattended runs.

        For a set-and-forget experience use the TrayIconGuard GUI (app/) which embeds the
        same logic with a tray icon, or install autostart: Install-TrayIconAutostart.

    .PARAMETER IntervalSec
        Poll interval (polling mode) / max re-arm wait so the deadline is honored
        (event mode). Default 3.

    .PARAMETER DebounceMs
        Quiet period after a registry notification before scanning (100-10000). Default 400.

    .PARAMETER UsePolling
        Disable event-driven notification; poll every IntervalSec instead.

    .PARAMETER ExcludeExecutable
        Executable names/paths/wildcards never to promote.

    .PARAMETER AutoRestartExplorer
        Restart explorer.exe after promoting icons (60 s cooldown between restarts).

    .PARAMETER TimeoutSec
        Stop the watcher after N seconds. 0 = run until Ctrl+C (default).

    .PARAMETER OnPromoted
        Scriptblock invoked with the [TrayIconInfo] for every auto-promoted icon.

    .PARAMETER AsJob
        Run in a background thread job instead of the foreground (returns the job).

    .PARAMETER JobName
        Name of the thread job created by -AsJob.

    .PARAMETER WhatIf
        Observe mode: the watcher runs and reports hidden icons but promotes nothing.

    .EXAMPLE
        Start-TrayIconWatcher

    .EXAMPLE
        Start-TrayIconWatcher -AsJob -ExcludeExecutable onedrive.exe

    .EXAMPLE
        Start-TrayIconWatcher -OnPromoted { param($icon) [console]::beep(880, 60) } -TimeoutSec 300

    .OUTPUTS
        System.Management.Automation.Job

    .LINK
        https://github.com/paulmann/windows-show-all-tray-icons/blob/main/docs/CLI-REFERENCE.md
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    [OutputType([System.Management.Automation.Job])]
    param(
        [ValidateRange(1, 3600)]
        [int] $IntervalSec = 3,

        [ValidateRange(100, 10000)]
        [int] $DebounceMs = 400,

        [switch] $UsePolling,

        [string[]] $ExcludeExecutable,

        [switch] $AutoRestartExplorer,

        [ValidateRange(0, 604800)]
        [int] $TimeoutSec = 0,

        [scriptblock] $OnPromoted,

        [switch] $AsJob,

        [string] $JobName = 'TrayIconWatcher'
    )

    # ---- Background mode: re-enter this function inside a thread job --------
    if ($AsJob) {
        $innerParams = @{}
        foreach ($pair in $PSBoundParameters.GetEnumerator()) {
            if ($pair.Key -notin @('AsJob', 'JobName', 'OnPromoted')) {
                $innerParams[$pair.Key] = $pair.Value
            }
        }
        $manifestPath = Join-Path $script:ModuleRoot 'ShowAllTrayIcons.psd1'
        $jobScript = {
            param($Manifest, $Params)
            Import-Module -Name $Manifest -Force
            Start-TrayIconWatcher @Params
        }
        return Start-ThreadJob -Name $JobName -ScriptBlock $jobScript -ArgumentList @($manifestPath, $innerParams)
    }

    script:Assert-WindowsPlatform | Out-Null

    $root = script:Open-TraySettingsRoot
    $writableRoot = $null
    $notifyEvent = $null
    $native = ('ShowAllTrayIcons.Native.RegistryNotify' -as [type])
    $useEvents = (-not $UsePolling) -and ($null -ne $native)

    if (-not $UsePolling -and -not $useEvents) {
        script:Write-TraceLog 'RegNotifyChangeKeyValue unavailable; falling back to polling mode.' 'WARN'
    }

    $modeText = if ($useEvents) { "event-driven (debounce ${DebounceMs}ms)" } else { "polling (every ${IntervalSec}s)" }
    $timeoutText = if ($TimeoutSec -gt 0) { "${TimeoutSec}s" } else { 'infinite' }
    $excludeText = if ($ExcludeExecutable) { $ExcludeExecutable -join ', ' } else { '<none>' }
    $startupMessage = ('Tray watcher started | mode: {0} | timeout: {1} | autoRestartExplorer: {2} | excludes: {3} | Ctrl+C to stop.' -f `
            $modeText, $timeoutText, $AutoRestartExplorer.IsPresent, $excludeText)
    script:Write-TraceLog $startupMessage
    Write-Information "[TrayWatcher] $startupMessage" -InformationAction Continue

    $deadline = if ($TimeoutSec -gt 0) { [System.DateTime]::UtcNow.AddSeconds($TimeoutSec) } else { $null }
    $knownIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try { [void] $knownIds.UnionWith([string[]] $root.GetSubKeyNames()) }
    catch { Write-Debug "Could not seed known ids: $($_.Exception.Message)" }

    $lastHeartbeat = [System.DateTime]::UtcNow
    $lastExplorerRestart = $null
    $totalPromoted = 0

    try {
        if ($useEvents) { $notifyEvent = [System.Threading.ManualResetEvent]::new($false) }

        while ($true) {
            if ($deadline -and [System.DateTime]::UtcNow -ge $deadline) {
                script:Write-TraceLog 'Watcher timeout reached; stopping.'
                break
            }

            # ---- Wait for a registry change (or the poll interval) ----------
            if ($useEvents) {
                $notifyEvent.Reset()
                $filter = $native::REG_NOTIFY_CHANGE_NAME -bor $native::REG_NOTIFY_CHANGE_LAST_SET
                $rc = $native::RegNotifyChangeKeyValue($root.Handle, $true, $filter, $notifyEvent.SafeWaitHandle, $true)
                if ($rc -ne 0) {
                    script:Write-TraceLog "RegNotifyChangeKeyValue failed (code $rc); polling this cycle." 'WARN'
                    if ($rc -eq $native::ERROR_KEY_DELETED) {
                        $root.Dispose()
                        $root = script:Open-TraySettingsRoot
                    }
                    Start-Sleep -Seconds $IntervalSec
                }
                else {
                    $signaled = $notifyEvent.WaitOne($IntervalSec * 1000)
                    if ($signaled) {
                        Write-Information '[TrayWatcher] Registry change detected; debouncing...'
                        Start-Sleep -Milliseconds $DebounceMs
                    }
                }
            }
            else {
                Start-Sleep -Seconds $IntervalSec
            }

            # ---- Scan --------------------------------------------------------
            try {
                $icons = @(script:Get-AllTrayIconEntries -Root $root -ExcludeExecutable $ExcludeExecutable)
            }
            catch {
                script:Write-TraceLog "Scan failed: $($_.Exception.Message); reopening registry key." 'WARN'
                try { $root.Dispose() } catch { Write-Debug "Dispose during recovery ignored: $($_.Exception.Message)" }
                $root = script:Open-TraySettingsRoot
                continue
            }

            # ---- Discoveries -------------------------------------------------
            foreach ($icon in $icons) {
                if ($knownIds.Add($icon.Id)) {
                    $discoveryMessage = "New tray icon discovered: '$($icon.DisplayName)' ($($icon.Id))"
                    script:Write-TraceLog $discoveryMessage
                    Write-Information "[TrayWatcher] $discoveryMessage"
                }
            }

            # ---- Auto-promotion ----------------------------------------------
            $hidden = @($icons | Where-Object { -not $_.IsPromoted -and -not $_.IsExcluded })
            if ($hidden.Count -gt 0 -and
                $PSCmdlet.ShouldProcess(('{0} hidden icon(s)' -f $hidden.Count), 'Auto-promote to always visible')) {
                if (-not $writableRoot) { $writableRoot = script:Open-TraySettingsRoot -Writable }
                foreach ($icon in $hidden) {
                    try {
                        script:Set-TrayIconPromotionCore -Root $writableRoot -Id $icon.Id -Promoted $true
                        $totalPromoted++
                        $promoteMessage = "Auto-promoted '$($icon.DisplayName)' ($($icon.Id))"
                        script:Write-TraceLog $promoteMessage
                        Write-Information "[TrayWatcher] $promoteMessage"
                        if ($OnPromoted) {
                            try { & $OnPromoted $icon }
                            catch { script:Write-TraceLog "OnPromoted callback failed: $($_.Exception.Message)" 'WARN' }
                        }
                    }
                    catch {
                        script:Write-TraceLog "Auto-promotion failed for '$($icon.Id)': $($_.Exception.Message)" 'ERROR'
                    }
                }

                if ($AutoRestartExplorer) {
                    $cooldownOk = (-not $lastExplorerRestart) -or (((Get-Date) - $lastExplorerRestart).TotalSeconds -ge 60)
                    if ($cooldownOk) {
                        script:Write-TraceLog 'AutoRestartExplorer triggered (cooldown ok).'
                        script:Restart-ExplorerCore | Out-Null
                        $lastExplorerRestart = Get-Date
                    }
                    else {
                        script:Write-TraceLog 'AutoRestartExplorer skipped (cooldown active).' 'DEBUG'
                    }
                }
            }

            # ---- Heartbeat (60 s) --------------------------------------------
            if (([System.DateTime]::UtcNow - $lastHeartbeat).TotalSeconds -ge 60) {
                $lastHeartbeat = [System.DateTime]::UtcNow
                $stillHidden = @($icons | Where-Object { -not $_.IsPromoted -and -not $_.IsExcluded }).Count
                $heartbeat = '[TrayWatcher] heartbeat | icons: {0} | hidden now: {1} | promoted this session: {2}' -f $icons.Count, $stillHidden, $totalPromoted
                Write-Information $heartbeat
            }
        }
    }
    finally {
        if ($notifyEvent) { $notifyEvent.Dispose() }
        if ($writableRoot) { $writableRoot.Dispose() }
        if ($root) { $root.Dispose() }
        script:Write-TraceLog "Watcher stopped; auto-promoted $totalPromoted icon(s) this session."
    }
}
