#!/usr/bin/env pwsh
#Requires -Version 7.6
<#
.SYNOPSIS
    Foreground tray watcher: keeps every icon visible, re-promoting hidden ones instantly.

.DESCRIPTION
    Runs Start-TrayIconWatcher in the current console. Explorer resets icon visibility
    whenever an app (re)registers its tray icon; this watcher detects that through
    RegNotifyChangeKeyValue (event-driven, no busy loop), debounces, and promotes the
    icon again within milliseconds. Ctrl+C stops cleanly. For a windowless deployment
    use Install-TrayIconAutostart -Target Watcher, or the TrayIconGuard GUI which adds
    a tray-resident monitor with notifications.

.PARAMETER IntervalSec
    Poll interval / max re-arm wait. Default 3.

.PARAMETER UsePolling
    Disable registry change notifications; poll instead.

.PARAMETER Exclude
    Executable names/paths/wildcards never to promote.

.PARAMETER AutoRestartExplorer
    Restart Explorer after promotions (60 s cooldown). Off by default.

.PARAMETER TimeoutSec
    Stop after N seconds (0 = run until Ctrl+C).

.EXAMPLE
    .\Watch-TrayIcons.ps1
.EXAMPLE
    .\Watch-TrayIcons.ps1 -Exclude onedrive.exe -TimeoutSec 3600

.NOTES
    Exit codes: 0 success | 1 error | 2 unsupported platform.
    Part of windows-show-all-tray-icons v7 "Phoenix" (MIT).

.LINK
    https://github.com/paulmann/windows-show-all-tray-icons
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [ValidateRange(1, 3600)]
    [int] $IntervalSec = 3,

    [switch] $UsePolling,

    [string[]] $Exclude,

    [switch] $AutoRestartExplorer,

    [ValidateRange(0, 604800)]
    [int] $TimeoutSec = 0
)

$ErrorActionPreference = 'Stop'
$exitCode = 0

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

try {
    Import-Module -Name (Join-Path $PSScriptRoot 'modules/ShowAllTrayIcons/ShowAllTrayIcons.psd1') -Force -ErrorAction Stop

    $watcherParams = @{
        IntervalSec          = $IntervalSec
        UsePolling           = $UsePolling
        AutoRestartExplorer  = $AutoRestartExplorer
        TimeoutSec           = $TimeoutSec
    }
    if ($Exclude) { $watcherParams.ExcludeExecutable = $Exclude }
    if ($PSBoundParameters.ContainsKey('WhatIf')) { $watcherParams.WhatIf = $PSBoundParameters['WhatIf'] }

    ShowAllTrayIcons\Start-TrayIconWatcher @watcherParams -InformationAction Continue
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
