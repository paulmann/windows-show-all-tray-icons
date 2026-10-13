# Show All Tray Icons for Windows 10/11 — v7 "Phoenix"

![Windows 11](https://img.shields.io/badge/Windows-11-0078D6?logo=windows&logoColor=white)
![Windows 10](https://img.shields.io/badge/Windows-10-0078D6?logo=windows&logoColor=white)
![Windows Server](https://img.shields.io/badge/Server-2019%2B-0078D6?logo=windowsserver&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-7.6%2B%20LTS-5391FE?logo=powershell&logoColor=white)
![.NET](https://img.shields.io/badge/.NET-10-512BD4?logo=dotnet&logoColor=white)
![License MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Version](https://img.shields.io/badge/version-7.0.3-green.svg)

**Keeps every notification-area (system tray) icon visible on Windows 10/11 — and keeps
them that way.** Icons that Windows hides in the overflow flyout are promoted back to the
taskbar, and a background watcher instantly re-promotes any icon that Explorer hides again
when applications start, update, or re-register their tray icons.

This is the **v7 "Phoenix" rewrite** of [paulmann/windows-show-all-tray-icons](https://github.com/paulmann/windows-show-all-tray-icons):
correct registry mechanics, a real watcher, three professional editions, tests, CI and docs.
No backward compatibility with the old 4.x/6.x scripts.

> **Why a watcher?** Windows resets an icon's `IsPromoted` flag to `0` whenever an app
> (re)registers its tray icon (app updates, reboots, crashed apps restarting). One-shot
> tweaks — including the original repo — silently decay within days. TrayIconGuard watches
> `HKCU\Control Panel\NotifyIconSettings` with `RegNotifyChangeKeyValue` and fixes icons
> within milliseconds. That is the whole point of v7.

---

## Three editions

| Edition | What it is | Best for | Dependencies |
|---|---|---|---|
| **GUI — `TrayIconGuard.exe`** | WPF app (.NET 10), lives in the tray, event-driven auto-promotion, per-icon toggles, settings, activity log | Daily driving, "set and forget" | .NET 10 Desktop Runtime (or self-contained build) |
| **PowerShell — `ShowAllTrayIcons` module** | 12 tested cmdlets: enable/disable, per-icon control, backup/restore, watcher (`-AsJob`), autostart | Power users, unattended deployment, Intune/SCCM/GPO logon scripts | PowerShell 7.6+ |
| **BAT — `Show-AllTrayIcons.bat`** | Standalone batch tool with menu and a watch loop | Locked-down PCs, quick fixes, no PS7 available | Only `reg.exe`/`taskkill` |

## Quick start

### GUI edition (recommended)

```powershell
# Option A — build it yourself (VS Code: Ctrl+Shift+B, or:)
pwsh -NoProfile -File build.ps1 -Task PublishExe
.\bat\Launch-TrayIconGuard.bat

# Option B — installer (Inno Setup, optional)
# compile installer\TrayIconGuard.iss, run TrayIconGuard-7.0.3-setup.exe
```

`TrayIconGuard.exe` starts minimized to the notification area, promotes every hidden icon,
and from then on guards the tray automatically. Right-click its tray icon for
*Show all icons now / Pause guard / Restart Explorer / Exit*.

Headless one-shots for deployment:

```powershell
TrayIconGuard.exe --promote-all       # promote everything, exit 0 (3 = partial failure)
TrayIconGuard.exe --restore-defaults  # give control back to Windows
TrayIconGuard.exe --minimized         # start GUI hidden in tray
```

### PowerShell edition

```powershell
# One-shot: show all icons (with backup, apply immediately)
.\powershell\Enable-AllTrayIcons.ps1 -Backup -RestartExplorer -Force

# Interactive module session
Import-Module .\powershell\modules\ShowAllTrayIcons
Get-TrayIcon                              # list every registered icon
Get-TrayIcon -Promoted $false             # only hidden ones
Set-TrayIcon -ExecutablePath '*discord*' -Promoted $true
Enable-AllTrayIcons -ExcludeExecutable onedrive.exe
Start-TrayIconWatcher -AsJob              # background guard (thread job)
Install-TrayIconAutostart -Target Gui -StartMinimized
Get-TrayIconState                         # health snapshot (monitoring-friendly)
```

### BAT edition

```bat
bat\Show-AllTrayIcons.bat enable            :: promote all hidden icons
bat\Show-AllTrayIcons.bat enable /restart   :: + restart Explorer
bat\Show-AllTrayIcons.bat watch 3           :: guard loop, re-promote every 3 s
bat\Show-AllTrayIcons.bat status            :: counts + legacy switches
bat\Show-AllTrayIcons.bat                   :: interactive menu
```

## Features (v7)

- **Correct mechanics** — uses `HKCU\Control Panel\NotifyIconSettings\{id}\IsPromoted`,
  the exact store the Windows Settings toggle uses (the old repo wrote several keys to
  invalid paths — see [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md)).
- **Event-driven watcher** — `RegNotifyChangeKeyValue` notifications + 400 ms debounce,
  polling fallback, new-icon discovery, optional auto-restart of Explorer (60 s cooldown).
- **Per-icon control** — promote/hide individual apps by GUID or exe wildcard.
- **Exclusions** — apps you *want* hidden stay hidden (`onedrive.exe`, `*teams*`, ...).
- **Backup / restore** — JSON schema v7 snapshot of the full tray state, `-Latest` restore.
- **Legacy cleanup done right** — `EnableAutoTray` belt-and-suspenders, `HideSCA*` policies
  removed from their real location, optional `Reset-TrayIconCache` for phantom icons.
- **Safe Explorer restart** — kill → wait for auto-restart → start manually if needed.
- **Autostart** — GUI or headless watcher via HKCU Run (`-EncodedCommand`, no quoting bugs).
- **Ops-ready** — `-WhatIf`/`-Confirm`, `-AsJson`, stable exit codes
  (`0/1/2/3`), rotating file logs in every edition, `Get-TrayIconState` for monitoring.
- **GUI polish** — dark/light theme follows Windows, PerMonitorV2 DPI, single instance,
  balloon notifications on auto-promotion, activity log, global exception recovery.
- **Production pipeline** — PSScriptAnalyzer gate, Pester 5 suite, GitHub Actions CI,
  single-file publish, Inno Setup installer, code-signing instructions.

## Repository layout

```
├── app/                 TrayIconGuard C# solution (WPF, net10.0-windows, zero NuGet deps)
├── powershell/          Entry scripts + modules/ShowAllTrayIcons (the PS module)
├── bat/                 Standalone BAT edition + launchers
├── tests/               Pester 5 (cross-platform meta-tests + Windows functional tests)
├── installer/           Inno Setup 6 script (optional)
├── docs/                ARCHITECTURE / HOW-IT-WORKS / CLI-REFERENCE / BUILD / TROUBLESHOOTING
├── .vscode/             tasks.json (Ctrl+Shift+B builds the EXE), launch.json
├── .github/workflows/   CI: analyze → test → build → publish → package → release
├── build.ps1            One-shot orchestrator (Analyze/Test/Verify/BuildExe/PublishExe/Package/All)
└── Enable-AllTrayIcons.*, *.reg   DEPRECATED pre-7.0 files, retained verbatim (see LEGACY-NOTICE.md)
```

## Requirements

| Component | Requirement |
|---|---|
| OS | Windows 10 1703+ (build 15063+), Windows 11, Server 2019/2022/2025 |
| GUI | **Release EXE is self-contained — nothing to install.** Framework-dependent builds (`build.ps1 -Task PublishExe -FrameworkDependent`) need the .NET 10 **Desktop Runtime** (NOT the SDK). If a runtime error appears although .NET 10 is installed, check `DOTNET_ROOT` — see docs/TROUBLESHOOTING.md |
| PowerShell edition | PowerShell **7.6+** (LTS). Windows PowerShell 5.1 is not supported by design |
| BAT edition | Nothing beyond stock Windows (`reg.exe`, `taskkill`, `timeout`) |
| Rights | Standard user (everything is HKCU). No admin required, ever |

## Build in VS Code (GUI edition)

1. Install the [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0) and
   [PowerShell 7.6+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows).
2. Open this folder in VS Code and accept the recommended extensions
   (C# Dev Kit, PowerShell, EditorConfig).
3. `Ctrl+Shift+B` → **Build TrayIconGuard**, or `F5` → *.NET: Launch TrayIconGuard*.
4. Release publish: `pwsh -File build.ps1 -Task PublishExe` (add `-SelfContained` for a
   runtime-free EXE). Full pipeline: `pwsh -File build.ps1 -Task All`.

Details, signing and release checklist: [docs/BUILD-AND-RELEASE.md](docs/BUILD-AND-RELEASE.md).

## Exit codes (all editions)

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Error (see log/output) |
| `2` | Unsupported platform / PowerShell missing |
| `3` | Partial failure (some icons could not be updated) |

## Documentation

- [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md) — the registry mechanics, why the old
  approach decayed, what v7 changed (deep dive)
- [docs/CLI-REFERENCE.md](docs/CLI-REFERENCE.md) — every cmdlet, script, BAT command
  and EXE flag
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — component & data-flow diagrams
- [docs/BUILD-AND-RELEASE.md](docs/BUILD-AND-RELEASE.md) — build, publish, sign, package, release
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — FAQ & fixes
- [CHANGELOG.md](CHANGELOG.md) — release history (what changed in each version)

## FAQ (short)

**Do I need admin rights?** No. Everything lives in HKCU.

**Why did my icons hide again after an app update?** Explorer resets `IsPromoted` when an
icon re-registers. Run the GUI or `Start-TrayIconWatcher` — that is exactly what they guard against.

**Changes don't show until I restart Explorer?** Usually `IsPromoted` applies live; when it
doesn't (fast-user-switching, some 24H2 builds), use `-RestartExplorer` / the toolbar button.

**Can I hide one specific icon again?** Yes: `Set-TrayIcon -ExecutablePath 'app.exe' -Promoted $false`
or untick it in the GUI, and add it to exclusions so the watcher respects it.

**Windows 7/8?** Out of scope: the `NotifyIconSettings` store does not exist there.

## Credits & License

Original concept and repository: **Mikhail Deynekin** ([deynekin.com](https://deynekin.com)).
v7 "Phoenix" rewrite: architecture, watcher, GUI, tests and docs.

MIT License — see [LICENSE](LICENSE).
