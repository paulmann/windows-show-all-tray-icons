# User guide — TrayIconGuard v8 «Aurora»

## First run — setup wizard

Launch `TrayIconGuard.exe` on a new machine and the **built-in setup wizard** opens
(no external installer needed):

1. **Install folder** — default `%LOCALAPPDATA%\Programs\TrayIconGuard`; change with *Browse…*.
2. **Start with Windows** — autostart entry (HKCU Run, minimized).
3. **Desktop shortcut** and **Start Menu shortcut** (Programs group + uninstall link).
4. Press **Install** — the exe is copied, shortcuts/uninstall entry are created and the app
   relaunches from the install location. Or press **Just run once, no install** for portable mode.

The wizard appears only while the install mode is unknown; portable users can install later
from **About → Install to this PC…**. Uninstall: *Apps & Features → TrayIconGuard* or
`TrayIconGuard.exe --uninstall` (removes shortcuts, autostart and the installed copy).

After that, on the very first start TrayIconGuard:

1. detects your Windows theme (light/dark) and UI language (EN/RU) automatically;
2. promotes every hidden tray icon once;
3. arms the guard and shows a welcome balloon;
4. lives in the notification area (double-click its shield icon to open the window).

Nothing is installed system-wide; settings go to `%APPDATA%\TrayIconGuard\settings.json`.

## Pages

### Dashboard
Hero card with live guard status and counters (registered / on taskbar / hidden / excluded),
quick actions (**Promote all now**, **Pause/Resume guard**, **Restart Explorer**), a System
card (Windows build, icon store, Explorer pid, legacy switches) and the recent activity feed.
Hint cards offer autostart enablement and greet you on first run.

### Tray icons
The full list from `NotifyIconSettings`: extracted icon, friendly name (file description),
executable path, state chip and a Fluent toggle per icon. Toolbar: search (Ctrl+F),
filter segments (All / On taskbar / Hidden / Excluded), **Promote all**, **Restore Windows
defaults** (with confirmation + auto-backup). Right-click a row for the context menu:
show/hide, keep hidden (exclusion), open file location, copy path/id. Excluded icons are
locked (remove the exclusion first). F5 rescans.

### Guard
- **Run the guard** — master switch for the watcher thread.
- **Debounce** — settle time after registry bursts (200/400/800/1500 ms).
- **Polling fallback** — periodic rescan if events are missed (Off/2/5/15 s).
- **Auto-restart Explorer** — with cooldown (30/60/120/300 s) and flap protection.
- **Balloon notifications** — toast when the guard promotes icons.
- Repairs: keep `EnableAutoTray=0`, remove `HideSCA*` policies, reset legacy tray cache
  (phantom icons; restart Explorer afterwards).
- Session statistics: passes, promotions, last fix time, uptime.
- **Exclusions** — wildcard patterns (`onedrive.exe`, `*teams*`) for apps you want hidden.

### Appearance
- **Theme**: Light / Dark / System (System follows Windows live; the sun/moon button in the
  top-right cycles themes anywhere).
- **Accent**: follow Windows or pick one of 8 presets.
- **Language**: Auto / English / Русский (instant).
- Effects: animations, compact icon rows. Reset appearance button.

### Backups
JSON snapshots of the whole tray state. Auto-backup before bulk changes (default on),
manual **Create snapshot now**, **Restore latest**, per-row Restore / Delete / Export,
open folder. Retention: 30 newest.

### Activity
Live log viewer (level colors, mono font), filters (All / Events / Issues), follow-new toggle,
export to file. Backed by the rotating file log (14 days).

### About
Version, manual **Check for updates** (never automatic), repository link,
**Copy diagnostics** (OS, theme, settings/log paths, last log lines) for bug reports,
license and credits.

## Tray menu

Right-click the shield: *Show TrayIconGuard · Promote all now · Pause/Resume guard ·
Restart Explorer · Exit*. The shield carries a small dot: green = guarding, amber = paused.

## Keyboard

`Tab`/`Shift+Tab` focus traversal · `Space`/`Enter` activate · `←/→` segmented controls ·
`Ctrl+F` search · `Ctrl+1..7` pages · `F5` rescan · `Esc` blur · `Shift`+close button bypasses
close-to-tray.

## Uninstall

Portable: delete the exe (optionally remove `%APPDATA%\TrayIconGuard` and
`%LOCALAPPDATA%\TrayIconGuard`). Installed via `install.ps1`: run `uninstall.ps1` or use
*Apps & features → TrayIconGuard → Uninstall*.
