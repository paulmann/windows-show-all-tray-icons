# CLI Reference — v7.0.3

Exit codes (all editions): `0` success · `1` error · `2` unsupported platform ·
`3` partial failure (some icons could not be updated).

---

## PowerShell module `ShowAllTrayIcons` (pwsh 7.6+)

```powershell
Import-Module .\powershell\modules\ShowAllTrayIcons
```

Every state-changing command supports `-WhatIf` / `-Confirm`. Commands returning
summaries support `-AsJson` where noted.

### Get-TrayIcon

Lists registered notification-area icons.

| Parameter | Type | Notes |
|---|---|---|
| `-Name` | wildcard string | Matches DisplayName, Id, ExecutablePath |
| `-Promoted` | `bool?` | `$true` visible only / `$false` hidden only |
| `-ExcludeExecutable` | `string[]` | Mark matching apps as excluded |
| `-AsJson` | switch | JSON array output |

Output: `TrayIconInfo[]` (Id, DisplayName, ExecutablePath, IconResource, IsPromoted,
LastNotification, HasSnapshot, IsExcluded).

### Get-TrayIconState

Health snapshot for monitoring: counts, `EnableAutoTray`, `HideSCA*` policies,
autostart command, Windows edition/build. `-ExcludeExecutable`, `-AsJson`.
Output: `TrayStatusReport` (`AllIconsVisible` accounts for exclusions).

### Enable-AllTrayIcons

The primary command. Promotes all hidden icons; optionally legacy switch + policy cleanup.

| Parameter | Default | Notes |
|---|---|---|
| `-Components` | `All` | Flags: `PromoteIcons`, `LegacyAutoTray`, `SystemIconPolicies`, `None` |
| `-ExcludeExecutable` | — | Never promote these apps |
| `-RestartExplorer` | off | Apply immediately |
| `-Backup` | off | JSON snapshot before changes |
| `-Force` | off | No prompts/warnings |
| `-AsJson` | off | JSON summary |

Summary: `TotalIcons, AlreadyVisible, Promoted, Excluded, Failed, LegacyAutoTraySet,
PoliciesCleared, BackupFile, ExplorerRestarted, DurationMs`.

### Disable-AllTrayIcons

Inverse: `IsPromoted=0` for all, removes the `EnableAutoTray` override.
`-RestartExplorer`, `-KeepLegacySwitch`, `-Force`, `-AsJson`.

### Set-TrayIcon

Per-icon control. `-Id <guid>` **or** `-ExecutablePath <wildcard>` (all matches),
`-Promoted $true|$false`, `-RestartExplorer`. Returns updated `TrayIconInfo`.

```powershell
Set-TrayIcon -ExecutablePath 'discord*' -Promoted $true
Set-TrayIcon -Id '{B15FA34F-...}' -Promoted $false -RestartExplorer
```

### Backup-TrayIconState / Restore-TrayIconState

- `Backup-TrayIconState [-Path <file.json>]` → schema v7 JSON (icons + legacy +
  policies). Default: `%LOCALAPPDATA%\ShowAllTrayIcons\backups\TrayIconState-<ts>.json`.
- `Restore-TrayIconState [-Path <file> | -Latest] [-RestartExplorer] [-AsJson]` →
  recreates recorded `IsPromoted`/`ExecutablePath` per icon, restores legacy values.
  `ConfirmImpact=High`.

**Machine-readable contract (`-AsJson`, audit R3-1):** with `-AsJson`, stdout contains
ONLY the JSON document — under `-WhatIf` the announcement is routed to the information
stream (visible interactively, capturable via `6>`, never mixed into stdout/pipes).

### Reset-TrayIconCache

Deletes legacy `TrayNotify\IconStreams` / `PastIconsStream` (phantom/stale icons),
restarts Explorer. `-SkipExplorerRestart`. Often a no-op on Windows 11 (key absent).

### Restart-Explorer

Safe shell restart (kill → wait → manual start if needed). `-TimeoutSec 2..30`, `-Force`.

### Start-TrayIconWatcher

Foreground guard; `-AsJob` moves it into a thread job (`Receive-Job` shows its stream).

| Parameter | Default | Notes |
|---|---|---|
| `-IntervalSec` | 3 | Poll interval / event re-arm window |
| `-DebounceMs` | 400 | Settle time after a notification |
| `-UsePolling` | off | Disable `RegNotifyChangeKeyValue` |
| `-ExcludeExecutable` | — | Never promote |
| `-AutoRestartExplorer` | off | Restart after promotions (60 s cooldown) |
| `-TimeoutSec` | 0 | 0 = until Ctrl+C |
| `-OnPromoted` | — | `scriptblock` invoked with each promoted `TrayIconInfo` |
| `-AsJob` | off | Background thread job |
| `-JobName` | `TrayIconWatcher` | Job name |
| `-WhatIf` | — | Observe mode: report but promote nothing |

### Install-TrayIconAutostart / Uninstall-TrayIconAutostart

- `-Target Gui|Watcher` (Run value `TrayIconGuard`), `-GuiExecutablePath`,
  `-StartMinimized`, `-WatcherIntervalSec`, `-ExcludeExecutable`.
- Watcher target uses `pwsh -EncodedCommand` (no quoting bugs).
- Uninstall removes the value; safe when absent.

---

## Entry scripts (`powershell/`)

| Script | Maps to | Extra |
|---|---|---|
| `Enable-AllTrayIcons.ps1` | `Enable-AllTrayIcons` | `-Components`, `-Exclude`, `-Backup`, `-RestartExplorer`, `-Force`, `-AsJson`, **`-AndWatch`**, `-WatchTimeoutSec` |
| `Disable-AllTrayIcons.ps1` | `Disable-AllTrayIcons` | **`-FromBackup`**, `-BackupPath`, `-RestartExplorer`, `-Force`, `-AsJson` |
| `Watch-TrayIcons.ps1` | `Start-TrayIconWatcher` | `-IntervalSec`, `-UsePolling`, `-Exclude`, `-AutoRestartExplorer`, `-TimeoutSec` |

```powershell
.\Enable-AllTrayIcons.ps1 -Backup -RestartExplorer -Force        # unattended deploy
.\Enable-AllTrayIcons.ps1 -AsJson | ConvertFrom-Json             # machine readable
.\Disable-AllTrayIcons.ps1 -FromBackup -RestartExplorer           # rollback (newest backup)
.\Disable-AllTrayIcons.ps1 -FromBackup -BackupPath .\TrayIconState-20261012-090000.json
```

---

## BAT edition (`bat/Show-AllTrayIcons.bat`)

```
Show-AllTrayIcons.bat [command] [interval] [/restart]
```

| Command | Effect |
|---|---|
| `enable` | Promote all hidden icons + `EnableAutoTray=0` + `HideSCA*` cleanup |
| `disable` | `IsPromoted=0` for all + remove `EnableAutoTray` |
| `status` | Counts, legacy switch, policies, autostart, build |
| `backup` | `reg export` → `%LOCALAPPDATA%\ShowAllTrayIcons\backups\TrayIconsBackup.reg` (previous kept as `-prev`) |
| `restore` | `reg import` the backup |
| `watch [N]` | Guard loop every N seconds (default 5); Ctrl+C to stop |
| `restart` | Restart explorer.exe |
| `help` | Usage |
| *(none)* | Interactive menu |

`/restart` (or `-restart`) may be appended to `enable|disable|restore`.

Launchers: `Run-PowerShell-Edition.bat [enable|disable|watch|help] [args...]`
(requires pwsh 7.6+ on PATH) and `Launch-TrayIconGuard.bat [exe-args...]`
(probes install/build locations for the EXE).

---

## GUI edition (`TrayIconGuard.exe`)

| Flag | Effect |
|---|---|
| *(none)* | Start with GUI (honors `startMinimized` setting) |
| `--minimized` | Start hidden in the notification area |
| `--promote-all` | Headless: promote everything, write log, exit (`0`/`3`) |
| `--restore-defaults` | Headless: return icons to Windows defaults, exit |
| `--help`, `-h`, `/?` | Show usage dialog |

Second instance activates the running window and exits `0`.
Settings: `%APPDATA%\TrayIconGuard\settings.json` (documented keys map 1:1 to the
Settings tab). Logs: `%LOCALAPPDATA%\TrayIconGuard\logs\`.

Tray menu: *Open TrayIconGuard · Show all icons now · Pause/resume guard ·
Restart Explorer · Exit*.
