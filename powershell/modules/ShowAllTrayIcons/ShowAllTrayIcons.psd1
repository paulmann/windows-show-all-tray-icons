@{
    RootModule           = 'ShowAllTrayIcons.psm1'
    ModuleVersion        = '7.0.3'
    CompatiblePSEditions = @('Core')
    GUID                 = '52f95744-327f-4889-9151-2ada389e7bed'
    Author               = 'Mikhail Deynekin; v7 "Phoenix" contributors'
    CompanyName          = 'windows-show-all-tray-icons'
    Copyright            = '(c) 2025 Mikhail Deynekin; (c) 2026 Phoenix contributors. MIT License.'
    Description          = 'Keeps every Windows 10/11 notification-area (system tray) icon visible. Promotes hidden icons via HKCU\Control Panel\NotifyIconSettings\IsPromoted, cleans stale legacy switches, backs the state up, and watches the registry to instantly re-promote icons that Explorer hides again. PowerShell 7.6+ (LTS), Windows only. Part of the v7 "Phoenix" rewrite: BAT edition, PowerShell edition, and the TrayIconGuard GUI.'
    PowerShellVersion    = '7.6'
    # NOTE: platform is enforced at runtime (Assert-WindowsPlatform) because the
    # manifest schema has no CompatibleOSPlatform member in PowerShell 7.6.

    FunctionsToExport    = @(
        'Get-TrayIcon'
        'Get-TrayIconState'
        'Enable-AllTrayIcons'
        'Disable-AllTrayIcons'
        'Set-TrayIcon'
        'Backup-TrayIconState'
        'Restore-TrayIconState'
        'Reset-TrayIconCache'
        'Restart-Explorer'
        'Start-TrayIconWatcher'
        'Install-TrayIconAutostart'
        'Uninstall-TrayIconAutostart'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags         = @('Windows', 'Windows10', 'Windows11', 'WindowsServer', 'Tray', 'SystemTray', 'NotificationArea', 'Taskbar', 'Registry', 'Explorer')
            LicenseUri   = 'https://github.com/paulmann/windows-show-all-tray-icons/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/paulmann/windows-show-all-tray-icons'
            ReleaseNotes = @'
7.0.3 - audit round 3: pure-JSON stdout under -AsJson -WhatIf (information-stream gate),
self-contained publish by default (DOTNET_ROOT immunity), launcher test ComSpec fallback.

7.0.2 - audit round 2: BAT launcher rewritten (no shift; %~dp0 captured first; help action),
.ragraf/ ignore rule restored, runtime launcher tests added. Round 1 fixes confirmed on Windows.

7.0.1 - defect-fix release after independent Windows audit (module import CS0105,
wrapper type/parameter binding, BAT findstr & icon counting). Details in CHANGELOG.md.

7.0.0 "Phoenix" - complete rewrite, no backward compatibility with 4.x/6.x.
- Correct registry locations (NotifyIconSettings under HKCU\Control Panel, HideSCA* under Policies\Explorer).
- Per-icon control (Get/Set-TrayIcon), JSON state backup/restore, legacy cache reset.
- Event-driven Start-TrayIconWatcher (RegNotifyChangeKeyValue) with -AsJob support.
- TrayIconGuard WPF GUI companion (app/), BAT edition (bat/), Pester tests, CI.
'@
        }
    }
}
