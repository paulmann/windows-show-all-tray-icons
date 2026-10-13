#!/usr/bin/env pwsh
#Requires -Version 7.6
<#
.SYNOPSIS
    Show All Tray Icons -- PowerShell edition entry point (restore defaults).

.DESCRIPTION
    Reverts everything Enable-AllTrayIcons.ps1 did: icons return to Windows-managed
    visibility (IsPromoted = 0), the legacy EnableAutoTray override is removed, and
    Explorer can be restarted to apply immediately. Prefer -FromBackup to restore a
    specific JSON snapshot (per-icon user choices preserved) instead of blanket defaults.

.PARAMETER RestartExplorer
    Restart explorer.exe so changes apply immediately.

.PARAMETER FromBackup
    Restore the latest JSON backup (Restore-TrayIconState -Latest) instead of resetting
    every icon to hidden-by-default.

.PARAMETER BackupPath
    Explicit backup file to restore with -FromBackup.

.PARAMETER Force
    No confirmation prompts.

.PARAMETER AsJson
    Machine-readable JSON summary on stdout.

.EXAMPLE
    .\Disable-AllTrayIcons.ps1
.EXAMPLE
    .\Disable-AllTrayIcons.ps1 -FromBackup -RestartExplorer -Force

.NOTES
    Exit codes: 0 success | 1 error | 2 unsupported platform | 3 partial failure.
    Part of windows-show-all-tray-icons v7 "Phoenix" (MIT).

.LINK
    https://github.com/paulmann/windows-show-all-tray-icons
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [switch] $RestartExplorer,

    [switch] $FromBackup,

    [string] $BackupPath,

    [switch] $Force,

    [switch] $AsJson
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

    if (-not $AsJson) {
        Write-Status 'Show All Tray Icons v7.0.3 -- restore defaults' 'Cyan'
        Write-Status '---------------------------------------------' 'DarkGray'
    }

    if ($FromBackup) {
        # Restore-TrayIconState exposes ShouldProcess (ConfirmImpact=High) but no
        # -Force parameter: suppress its prompt the standard way (defect P0-3).
        $restoreParams = @{ RestartExplorer = $RestartExplorer; AsJson = $AsJson }
        if ($Force) { $restoreParams.Confirm = $false }
        if ($PSBoundParameters.ContainsKey('WhatIf')) { $restoreParams.WhatIf = $PSBoundParameters['WhatIf'] }
        if ($BackupPath) { $restoreParams.Path = $BackupPath } else { $restoreParams.Latest = $true }
        # Audit R3-1: keep stdout pure JSON - silence the information stream.
        if ($AsJson) { $restoreParams.InformationAction = 'SilentlyContinue' }
        $result = ShowAllTrayIcons\Restore-TrayIconState @restoreParams
        if ($AsJson) { Write-Output $result }
        else {
            Write-Status ("  Restored {0} icon(s) from {1}" -f $result.IconsRestored, $result.File) 'Green'
            if ($result.IconsFailed -gt 0) { $exitCode = 3 }
        }
    }
    else {
        $disableParams = @{ Force = $Force; AsJson = $AsJson }
        if ($RestartExplorer) { $disableParams.RestartExplorer = $true }
        if ($PSBoundParameters.ContainsKey('WhatIf'))  { $disableParams.WhatIf  = $PSBoundParameters['WhatIf'] }
        if ($PSBoundParameters.ContainsKey('Confirm')) { $disableParams.Confirm = $PSBoundParameters['Confirm'] }
        if ($AsJson) { $disableParams.InformationAction = 'SilentlyContinue' }
        $result = ShowAllTrayIcons\Disable-AllTrayIcons @disableParams
        if ($AsJson) { Write-Output $result }
        else {
            Write-Status ("  Icons returned to default: {0} | failed: {1}" -f $result.Demoted, $result.Failed) 'Green'
            if ($result.Failed -gt 0) { $exitCode = 3 }
        }
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
