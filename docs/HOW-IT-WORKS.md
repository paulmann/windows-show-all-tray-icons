# How It Works — Windows Tray Visibility Mechanics (v8)

## 1. The store Windows really uses: `NotifyIconSettings`

Since Windows 10 1703 (build 15063), per-icon notification-area visibility lives in:

```
HKEY_CURRENT_USER\Control Panel\NotifyIconSettings\{<icon-id>}
```

Each application icon registration gets a subkey (usually a GUID). Relevant values:

| Value | Type | Meaning |
|---|---|---|
| `IsPromoted` | `REG_DWORD` | **1 = always visible on the taskbar, 0 = hidden in the overflow flyout.** Exactly what the Windows Settings toggle reads/writes. |
| `ExecutablePath` | `REG_SZ` | Owning executable. |
| `IconResource` | `REG_SZ` | Icon resource, e.g. `C:\...\app.exe,-101`. |
| `IconSnapshot` | `REG_BINARY` | Last rendered bitmap of the icon. |
| `LastNotificationAddedTime` | `REG_QWORD` | FILETIME (UTC) of the last notification. |

### The decay problem (why one-shot tweaks fail)

Explorer (re)creates these subkeys **every time an application registers its tray icon**:
at app start, after updates, after crashes, at logon. On (re)registration Windows writes
`IsPromoted = 0` unless it decides the icon was “recently interactive”. Registry-tweak-only
guides therefore silently decay within days.

**v8 answer:** a watcher thread. `RegNotifyChangeKeyValue` is armed on the
`NotifyIconSettings` subtree with `REG_NOTIFY_CHANGE_NAME | REG_NOTIFY_CHANGE_LAST_SET`
(one-shot event, re-armed after every pass). On signal the watcher debounces ~400 ms,
rescans, and sets `IsPromoted = 1` again for every non-excluded icon. An optional polling
fallback covers missed notifications; an optional Explorer auto-restart (with cooldown and
flap protection: two consecutive fixing passes required) handles builds where Explorer
cached the layout.

### Applying changes live

Explorer usually picks up external `IsPromoted` writes without a restart. When it does not
(observed on some Windows 11 24H2+ builds, fast user switching, cached layouts), a shell
restart applies everything immediately: kill every `explorer.exe` → wait up to 8 s for
auto-restart → start `explorer.exe` manually if absent.

## 2. Legacy switch: `EnableAutoTray`

```
HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer  →  EnableAutoTray (DWORD)
```

`0` = the XP–7 era “hide inactive icons” checkbox off. Modern Windows largely ignores it;
writing `0` is harmless and helps a few legacy shell components. v8 keeps it strictly as
belt-and-suspenders (Guard → “Keep EnableAutoTray = 0”, default on), never as the primary
mechanism.

## 3. System-icon policies: `HideSCA*` — correct location

Volume/network/power system icons can be force-hidden by policy values
`HideSCAVolume`, `HideSCANetwork`, `HideSCAPower`. Their **correct** home is:

```
HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer
```

(Historical `.reg` files wrote them under `...\CurrentVersion\Explorer` — no `Policies`
segment — where they have **no effect at all**.) v8 counts and removes `=1` values from the
correct path: Guard → “Remove HideSCA* policies”.

## 4. Pre-1703 icon cache: `TrayNotify`

```
HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify
  → IconStreams, PastIconsStream (binary caches)
```

Older builds cached per-icon preferences here. Deleting these values forces a rebuild and
clears phantom/stale icons. v8 exposes this only as an explicit repair
(Guard → “Reset legacy tray cache”), never automatically; on Windows 11 the key is often
absent entirely.

## 5. What v8 deliberately does NOT touch

| Item | Reason |
|---|---|
| `StuckRects3\Settings` binary blob | Resolution/monitor-specific taskbar state; overwriting corrupts taskbar layout on other displays |
| `TaskbarSi`, Office `UISettings`, `WindowsUpdate\UX` | Unrelated to tray visibility |
| HKLM / “all users” modes | No GPO exists for per-icon promotion; HKCU-only by design, standard user forever |

## 6. Autostart

```
HKCU\Software\Microsoft\Windows\CurrentVersion\Run
  TrayIconGuard = "C:\...\TrayIconGuard.exe" --minimized
```

Managed from Dashboard hint card, Guard page or `--install-autostart` / `--uninstall-autostart`.

## 7. Data & logs

| Data | Location |
|---|---|
| Settings | `%APPDATA%\TrayIconGuard\settings.json` (atomic writes: tmp + rename) |
| Logs (14-day rotation) | `%LOCALAPPDATA%\TrayIconGuard\logs\TrayIconGuard-yyyyMMdd.log` |
| Snapshots (JSON v8, cap 30) | `%LOCALAPPDATA%\TrayIconGuard\backups\TrayIconState-*.json` |

Nothing ever leaves the machine; there is no telemetry. The only network code path is the
manual “Check for updates” button (WinHTTP GET to the GitHub releases API).
