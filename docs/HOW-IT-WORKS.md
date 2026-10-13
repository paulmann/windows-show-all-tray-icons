# How It Works — Windows Tray Visibility Mechanics

This document explains the actual Windows mechanisms v7 uses, and documents the
errors in the pre-7.0 approach that this rewrite fixes.

## 1. The store Windows really uses: `NotifyIconSettings`

Since Windows 10 1703 (build 15063), per-icon notification-area visibility lives in:

```
HKEY_CURRENT_USER\Control Panel\NotifyIconSettings\{<icon-id>}
```

Each application icon registration gets a subkey (usually a GUID). Relevant values:

| Value | Type | Meaning |
|---|---|---|
| `IsPromoted` | `REG_DWORD` | **1 = always visible on the taskbar, 0 = hidden in the overflow flyout.** This is exactly what the Windows Settings toggle ("Select which icons appear on the taskbar") reads and writes. |
| `ExecutablePath` | `REG_SZ` | Owning executable, e.g. `C:\Program Files\App\app.exe` |
| `IconResource` | `REG_SZ` | Icon resource, e.g. `C:\...\app.exe,-101` |
| `IconSnapshot` | `REG_BINARY` | Last rendered bitmap of the icon |
| `LastNotificationAddedTime` | `REG_QWORD` | FILETIME (UTC) of the last notification |
| `InitialTimeElapsed` | `REG_QWORD` | Bookkeeping for first registration |

### The decay problem (why one-shot tweaks fail)

Explorer (re)creates these subkeys **every time an application registers its tray
icon**: at app start, after app updates, after crashes, at logon. On (re)registration
Windows writes `IsPromoted = 0` unless it decides the icon was "recently interactive".
That is why every registry-tweak-only guide (and the pre-7.0 code in this repo) stops
working within days: new/updated apps simply reappear hidden.

**v7 answer:** a watcher. `RegNotifyChangeKeyValue` is armed on the
`NotifyIconSettings` subtree with `REG_NOTIFY_CHANGE_NAME | REG_NOTIFY_CHANGE_LAST_SET`.
When Explorer creates a subkey or flips `IsPromoted` back to 0, the watcher wakes up
(within milliseconds), debounces ~400 ms to let burst writes settle, rescans and sets
`IsPromoted = 1` again. Implementations: `TrayIconGuard.exe` (GUI),
`Start-TrayIconWatcher` (PowerShell, event-driven + `-AsJob`), `watch` loop (BAT, polling).

### Applying changes live

Explorer usually picks up external `IsPromoted` writes without a restart (icons move
on the next tray refresh). When it does not (observed on some Windows 11 24H2+ builds,
fast user switching, or when Explorer cached the layout), a shell restart applies
everything immediately. v7 provides `Restart-Explorer` / the toolbar button /
`/restart` (BAT) which:

1. kills every `explorer.exe` (the shell normally auto-restarts within ~2 s),
2. waits up to 8 s,
3. starts `explorer.exe` manually if Windows did not bring it back.

## 2. Legacy switch: `EnableAutoTray`

```
HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer  →  EnableAutoTray (DWORD)
```

`0` = "show all icons" for the Windows XP–7 era *Hide inactive icons* checkbox.
Modern Windows largely ignores it, but writing `0` is harmless and helps a few
legacy shell components. v7 keeps it strictly as belt-and-suspenders
(`TrayFixComponents.LegacyAutoTray`), never as the primary mechanism.

## 3. System-icon policies: `HideSCA*` — correct location

Volume/network/power system icons can be force-hidden by policy values
`HideSCAVolume`, `HideSCANetwork`, `HideSCAPower`. Their **correct** home is:

```
HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer
```

The pre-7.0 `.reg` files wrote them under `...\CurrentVersion\Explorer` (no
`Policies` segment), where they have **no effect at all**. v7 removes stale `HideSCA* = 1`
values from the correct Policies path during `Enable-AllTrayIcons`
(`TrayFixComponents.SystemIconPolicies`).

## 4. Pre-1703 icon cache: `TrayNotify`

```
HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify
  → IconStreams, PastIconsStream (binary caches)
```

Older Windows 10 builds cached per-icon preferences here. Deleting these values forces
a rebuild and clears phantom/stale icons. v7 exposes this only as an explicit repair
command (`Reset-TrayIconCache`), never automatically — on Windows 11 the key is often
absent entirely.

## 5. What the old `.reg` files got wrong (and v7 dropped)

| Old content | Problem | v7 |
|---|---|---|
| `...\Explorer\NotifyIconSettings\Microsoft.VolumeControl` etc. | Path does not exist; real store is `Control Panel\NotifyIconSettings` with GUID subkeys; invented names like `Microsoft.VolumeControl` are not how Windows keys this store | Correct path, enumerate real subkeys |
| `HideSCA*` under `...\CurrentVersion\Explorer` | Wrong hive path (belongs under `Policies\Explorer`) | Correct path cleanup |
| `StuckRects3\Settings` binary blob | Resolution/monitor-specific taskbar state; overwriting it corrupts taskbar layout on other displays | Removed entirely |
| `TaskbarSi`, Office `UISettings`, `WindowsUpdate\UX` values | Unrelated to tray visibility / no documented effect | Removed |
| "Group Policy / AllUsers" mode in the 6.x ps1 | No such GPO exists for per-icon promotion; HKCU-only by design; claims were misleading | Removed; deployment docs describe honest per-user options (Run key, logon script, GPP registry item targeting HKCU) |

## 6. Autostart

Both the GUI and the headless watcher register the same HKCU Run value:

```
HKCU\Software\Microsoft\Windows\CurrentVersion\Run
  TrayIconGuard = "C:\...\TrayIconGuard.exe" --minimized
```

The PowerShell watcher variant uses `-EncodedCommand` (UTF-16LE base64) to avoid all
quoting problems in Run values. `Install-TrayIconAutostart` /
`Uninstall-TrayIconAutostart` / the GUI Settings tab manage it.

## 7. Data & logs

| Data | Location |
|---|---|
| GUI settings | `%APPDATA%\TrayIconGuard\settings.json` |
| GUI logs (14 days) | `%LOCALAPPDATA%\TrayIconGuard\logs\TrayIconGuard-yyyyMMdd.log` |
| PS module logs | `%LOCALAPPDATA%\ShowAllTrayIcons\logs\ShowAllTrayIcons-yyyyMMdd.log` |
| PS backups (JSON) | `%LOCALAPPDATA%\ShowAllTrayIcons\backups\TrayIconState-*.json` |
| BAT backup (.reg) | `%LOCALAPPDATA%\ShowAllTrayIcons\backups\TrayIconsBackup.reg` (+ `-prev`) |
| BAT log | `%LOCALAPPDATA%\ShowAllTrayIcons\logs\bat.log` |

Nothing ever leaves the machine; there is no telemetry, no updater phone-home
(the 6.x self-update-from-GitHub code was removed on purpose).
