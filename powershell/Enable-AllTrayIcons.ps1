#!/usr/bin/env pwsh
#Requires -Version 7.6
<#
.SYNOPSIS
    Show All Tray Icons -- PowerShell edition entry point (enable).

.DESCRIPTION
    Thin, production-grade wrapper around the ShowAllTrayIcons module command
    Enable-AllTrayIcons. Promotes every hidden notification-area icon
    (HKCU\Control Panel\NotifyIconSettings -> IsPromoted = 1), sets the legacy
    EnableAutoTray switch, cleans stale HideSCA* policies, optionally backs the
    state up first and restarts Explorer. Stable exit codes make it safe for
    unattended deployment (SCCM/Intune/GPO logon scripts).

    With -AndWatch it keeps running in the foreground and instantly re-promotes
    any icon Windows hides later (event-driven registry watcher).

.PARAMETER Components
    Any combination of: All | PromoteIcons | LegacyAutoTray | SystemIconPolicies.

.PARAMETER Exclude
    Executable names/paths/wildcards never to promote (e.g. onedrive.exe).

.PARAMETER RestartExplorer
    Restart explorer.exe so changes apply immediately.

.PARAMETER Backup
    Create a JSON backup (Restore-TrayIconState -Latest rolls it back).

.PARAMETER Force
    No prompts, no per-icon warnings.

.PARAMETER AsJson
    Machine-readable JSON summary on stdout.

.PARAMETER AndWatch
    After enabling, run Start-TrayIconWatcher in the foreground (Ctrl+C stops).

.PARAMETER WatchTimeoutSec
    With -AndWatch: stop the watcher after N seconds (0 = until Ctrl+C).

.EXAMPLE
    .\Enable-AllTrayIcons.ps1
.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -RestartExplorer -Backup -Force
.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -AsJson -Exclude onedrive.exe, teams.exe

.NOTES
    Exit codes: 0 success | 1 error | 2 unsupported platform | 3 partial failure.
    Part of windows-show-all-tray-icons v7 "Phoenix" (MIT).

.LINK
    https://github.com/paulmann/windows-show-all-tray-icons
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateSet('All', 'PromoteIcons', 'LegacyAutoTray', 'SystemIconPolicies')]
    [string[]] $Components = @('All'),

    [string[]] $Exclude,

    [switch] $RestartExplorer,

    [switch] $Backup,

    [switch] $Force,

    [switch] $AsJson,

    [switch] $AndWatch,

    [ValidateRange(0, 604800)]
    [int] $WatchTimeoutSec = 0
)

$ErrorActionPreference = 'Stop'

function Write-Status {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '',
        Justification = 'Console UX entry point; colored host output is the product surface here.')]
    param(
        [Parameter(Mandatory)][string] $Message,
        [string] $Color = 'Gray'
    )
    Write-Host $Message -ForegroundColor $Color
}

$exitCode = 0
try {
    Import-Module -Name (Join-Path $PSScriptRoot 'modules/ShowAllTrayIcons/ShowAllTrayIcons.psd1') -Force -ErrorAction Stop

    # Pass Components as a comma-joined string: the module parameter binds it to
    # the [TrayFixComponents] flags enum itself. The enum type lives in the module
    # scope and is NOT resolvable from a caller script (defect P0-2 post-mortem).
    $invokeParams = @{
        Components = ($Components -join ',')
        Force      = $Force
        AsJson     = $AsJson
    }
    if ($Exclude)          { $invokeParams.ExcludeExecutable = $Exclude }
    if ($RestartExplorer)  { $invokeParams.RestartExplorer = $true }
    if ($Backup)           { $invokeParams.Backup = $true }
    if ($PSBoundParameters.ContainsKey('WhatIf'))  { $invokeParams.WhatIf  = $PSBoundParameters['WhatIf'] }
    if ($PSBoundParameters.ContainsKey('Confirm')) { $invokeParams.Confirm = $PSBoundParameters['Confirm'] }
    # Audit R3-1: keep stdout pure JSON - silence the information stream in the child process.
    if ($AsJson) { $invokeParams.InformationAction = 'SilentlyContinue' }

    if (-not $AsJson) {
        Write-Status 'Show All Tray Icons v7.0.3 -- PowerShell Edition' 'Cyan'
        Write-Status '------------------------------------------------' 'DarkGray'
    }

    $result = ShowAllTrayIcons\Enable-AllTrayIcons @invokeParams

    if ($AsJson) {
        Write-Output $result
    }
    else {
        Write-Status ("  Icons          : {0} registered | {1} already visible | {2} promoted now | {3} excluded" -f `
                $result.TotalIcons, $result.AlreadyVisible, $result.Promoted, $result.Excluded) 'Green'
        if ($result.LegacyAutoTraySet)  { Write-Status '  Legacy switch  : EnableAutoTray = 0 applied' }
        if ($result.PoliciesCleared)    { Write-Status ("  Policies cleaned: {0}" -f ($result.PoliciesCleared -join ', ')) }
        if ($result.BackupFile)         { Write-Status ("  Backup         : {0}" -f $result.BackupFile) }
        if ($null -ne $result.ExplorerRestarted) {
            Write-Status ("  Explorer       : restarted={0}" -f $result.ExplorerRestarted)
        }
        Write-Status ("  Done in {0} ms." -f $result.DurationMs) 'Cyan'
        if ($result.Failed -gt 0) {
            Write-Status ("  {0} icon(s) FAILED to promote -- see log." -f $result.Failed) 'Yellow'
            $exitCode = 3
        }
        else {
            Write-Status '  All tray icons are now visible.' 'Green'
        }
    }

    if ($AndWatch) {
        $watcherParams = @{ TimeoutSec = $WatchTimeoutSec }
        if ($Exclude) { $watcherParams.ExcludeExecutable = $Exclude }
        if ($PSBoundParameters.ContainsKey('WhatIf')) { $watcherParams.WhatIf = $PSBoundParameters['WhatIf'] }
        ShowAllTrayIcons\Start-TrayIconWatcher @watcherParams
    }
}
catch [System.PlatformNotSupportedException] {
    Write-Status "UNSUPPORTED PLATFORM: $($_.Exception.Message)" 'Red'
    $exitCode = 2
}
catch {
    Write-Status "ERROR: $($_.Exception.Message)" 'Red'
    $exitCode = 1
}

exit $exitCode
