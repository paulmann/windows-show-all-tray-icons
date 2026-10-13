function Enable-AllTrayIcons {
    <#
    .SYNOPSIS
        Makes every notification-area icon permanently visible (disables tray hiding).

    .DESCRIPTION
        The modern, reliable mechanism: enumerates HKCU\Control Panel\NotifyIconSettings
        and sets IsPromoted = 1 for every hidden icon (this is exactly what the Windows
        Settings toggle does per icon). Optionally also:

        * LegacyAutoTray     -- sets the legacy EnableAutoTray = 0 switch (Win7-era
                               "hide inactive icons"; harmless belt-and-suspenders).
        * SystemIconPolicies -- removes stale HideSCAVolume/HideSCANetwork/HideSCAPower
                               policy values from their CORRECT location
                               (HKCU\...\Policies\Explorer).

        Explorer usually applies IsPromoted changes without a restart; pass
        -RestartExplorer to force immediate application. New icons registered later can
        be hidden again by Explorer -- use Start-TrayIconWatcher (or the TrayIconGuard
        GUI) to re-promote them automatically.

        Supports -WhatIf/-Confirm. Returns a summary object (or JSON with -AsJson).

    .PARAMETER Components
        Which fixes to apply (flags enum). Default: All.

    .PARAMETER ExcludeExecutable
        Executable names/paths/wildcards to never promote (e.g. 'onedrive.exe').

    .PARAMETER RestartExplorer
        Restart explorer.exe after making changes so they apply immediately.

    .PARAMETER Backup
        Create a JSON state backup (Backup-TrayIconState) before changing anything.

    .PARAMETER Force
        Bypass confirmation prompts and per-icon warnings.

    .PARAMETER AsJson
        Emit the summary as JSON (for pipelines and unattended deployment).

    .EXAMPLE
        Enable-AllTrayIcons -Backup

    .EXAMPLE
        Enable-AllTrayIcons -RestartExplorer -ExcludeExecutable onedrive.exe -Force

    .EXAMPLE
        Enable-AllTrayIcons -Components PromoteIcons -AsJson | ConvertFrom-Json

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
        Justification = 'Product command name: enables ALL tray icons; matches documented CLI across BAT/PS/GUI editions.')]
    [OutputType([pscustomobject])]
    [OutputType([string])]
    param(
        [TrayFixComponents] $Components = [TrayFixComponents]::All,

        [string[]] $ExcludeExecutable,

        [switch] $RestartExplorer,

        [switch] $Backup,

        [switch] $Force,

        [switch] $AsJson
    )

    if ($Force) { $ConfirmPreference = 'None' }
    script:Assert-WindowsPlatform | Out-Null

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $summary = [ordered]@{
        Action             = 'Enable'
        Timestamp          = (Get-Date).ToUniversalTime().ToString('o')
        WindowsBuild       = [System.Environment]::OSVersion.Version.Build
        TotalIcons         = 0
        AlreadyVisible     = 0
        Promoted           = 0
        Excluded           = 0
        Failed             = 0
        LegacyAutoTraySet  = $false
        PoliciesCleared    = @()
        BackupFile         = $null
        ExplorerRestarted  = $null
        DurationMs         = 0
    }

    if ($Backup) {
        $backupFile = Backup-TrayIconState
        $summary.BackupFile = $backupFile.FullName
        script:Write-TraceLog "Backup created: $($backupFile.FullName)"
    }

    # ---- 1. Promote hidden icons (primary mechanism) ------------------------
    if ($Components -band [TrayFixComponents]::PromoteIcons) {
        $root = script:Open-TraySettingsRoot -Writable
        try {
            $icons = @(script:Get-AllTrayIconEntries -Root $root -ExcludeExecutable $ExcludeExecutable)
            $targets = @($icons | Where-Object { -not $_.IsPromoted -and -not $_.IsExcluded })

            $summary.TotalIcons     = $icons.Count
            $summary.AlreadyVisible = @($icons | Where-Object IsPromoted).Count
            $summary.Excluded       = @($icons | Where-Object IsExcluded).Count

            $promoteGate = $targets.Count -gt 0 -and (script:Invoke-ShouldProcess -Cmdlet $PSCmdlet -Target ('{0} hidden tray icon(s)' -f $targets.Count) -Action 'Promote to always visible' -MachineReadable:$AsJson)
            if ($promoteGate) {
                foreach ($target in $targets) {
                    try {
                        script:Set-TrayIconPromotionCore -Root $root -Id $target.Id -Promoted $true
                        $summary.Promoted++
                        script:Write-TraceLog "Promoted '$($target.DisplayName)' ($($target.Id))"
                    }
                    catch {
                        $summary.Failed++
                        script:Write-TraceLog "FAILED to promote '$($target.DisplayName)' ($($target.Id)): $($_.Exception.Message)" 'ERROR'
                        if (-not $Force) {
                            Write-Warning "Could not promote '$($target.DisplayName)': $($_.Exception.Message)"
                        }
                    }
                }
            }
        }
        finally {
            $root.Dispose()
        }
    }

    # ---- 2. Legacy EnableAutoTray switch ------------------------------------
    if ($Components -band [TrayFixComponents]::LegacyAutoTray) {
        $current = script:Get-ExplorerKeyValue -Name ([TrayPolicy]::EnableAutoTrayName)
        if ($null -eq $current -or [Convert]::ToInt32($current) -ne 0) {
            if (script:Invoke-ShouldProcess -Cmdlet $PSCmdlet -Target 'HKCU\...\Explorer\EnableAutoTray' -Action 'Set to 0 (legacy show-all switch)' -MachineReadable:$AsJson) {
                script:Set-ExplorerKeyValue -Name ([TrayPolicy]::EnableAutoTrayName) -Value 0
                $summary.LegacyAutoTraySet = $true
                script:Write-TraceLog 'Legacy EnableAutoTray set to 0.'
            }
        }
    }

    # ---- 3. Stale system-icon hide policies ---------------------------------
    if ($Components -band [TrayFixComponents]::SystemIconPolicies) {
        if (script:Invoke-ShouldProcess -Cmdlet $PSCmdlet -Target 'HideSCAVolume / HideSCANetwork / HideSCAPower' -Action 'Remove stale hide-policies' -MachineReadable:$AsJson) {
            $removed = @(script:Clear-SystemIconPolicies)
            $summary.PoliciesCleared = $removed
            if ($removed.Count -gt 0) {
                script:Write-TraceLog "Removed system-icon hide policies: $($removed -join ', ')"
            }
        }
    }

    # ---- 4. Optional Explorer restart ----------------------------------------
    if ($RestartExplorer) {
        if (script:Invoke-ShouldProcess -Cmdlet $PSCmdlet -Target 'explorer.exe' -Action 'Restart to apply changes immediately' -MachineReadable:$AsJson) {
            $restart = script:Restart-ExplorerCore
            $summary.ExplorerRestarted = $restart.Success
        }
    }

    $stopwatch.Stop()
    $summary.DurationMs = $stopwatch.ElapsedMilliseconds
    $message = 'Enable finished: promoted={0} alreadyVisible={1} excluded={2} failed={3} in {4} ms' -f $summary.Promoted, $summary.AlreadyVisible, $summary.Excluded, $summary.Failed, $summary.DurationMs
    script:Write-TraceLog $message

    $result = [pscustomobject] $summary
    if ($AsJson) { return ($result | ConvertTo-Json -Depth 4) }
    $result
}
