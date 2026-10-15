# TrayIconGuard v8 “Aurora”

![Windows 11](https://img.shields.io/badge/Windows-11-0078D6?logo=windows&logoColor=white)
![Windows 10](https://img.shields.io/badge/Windows-10-0078D6?logo=windows&logoColor=white)
![Native C++](https://img.shields.io/badge/Native-C%2B%2B17-00599C?logo=cplusplus&logoColor=white)
![Zero dependencies](https://img.shields.io/badge/Dependencies-ZERO-brightgreen)
![Size](https://img.shields.io/badge/EXE-~800%20KB-blue)
![License](https://img.shields.io/badge/License-PolyForm%20Noncommercial%201.0.0-orange)
![Version](https://img.shields.io/badge/version-8.3.0-green)

**Keeps every notification-area (system tray) icon visible on Windows 10/11 — and keeps them
that way.** Icons that Windows hides in the overflow flyout are promoted back to the taskbar,
and an event-driven watcher re-promotes any icon Explorer hides again the moment apps start,
update or re-register their tray icons.

v8 “Aurora” is a **complete ground-up rewrite** of
[paulmann/windows-show-all-tray-icons](https://github.com/paulmann/windows-show-all-tray-icons)
(v7 “Phoenix”, C# WPF / .NET 10): same researched registry mechanics, but now a **single native
Win32 C++ executable with zero install dependencies** — no .NET, no SDK, no runtimes, no
redistributables. Copy the exe anywhere and run it.

![Dashboard](resources/banner.png)

---

## Why v8 exists

| v7 “Phoenix” | v8 “Aurora” |
|---|---|
| WPF GUI needs **.NET 10 Desktop Runtime** (or a ~150 MB self-contained publish) | **One 800 KB native exe**, static-linked, only stock Windows DLLs |
| Three editions (GUI + PowerShell module + BAT) to maintain | **One exe**: GUI + `--watch` headless guard + full CLI |
| Theme follows Windows only | **Light / Dark / System switcher**, persisted, auto-detected on first run |
| English only | **English + Russian**, auto-detected, live switching |
| Per-icon control via PowerShell | **Per-icon toggles, search, filters, exclusions, context menu in the GUI** |
| — | JSON snapshots with auto-backup, activity log viewer, diagnostics copy, manual update check |

## Features

- **Correct mechanics** — writes `HKCU\Control Panel\NotifyIconSettings\{id}\IsPromoted`,
  the exact store the Windows Settings toggle uses (see [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md)).
- **Event-driven guard** — `RegNotifyChangeKeyValue` on the store subtree, 400 ms debounce,
  optional polling fallback, optional auto-restart of Explorer with cooldown.
- **Per-icon control** — promote/hide individual icons, exclusion wildcards (`onedrive.exe`,
  `*teams*`), search, filters, extracted icons and friendly names.
- **i18n: 30 locales** — English default with per-string fallback, OS auto-detect,
  live switching and a native-name picker (see [docs/I18N.md](docs/I18N.md)).
- **Modern Fluent UI (2026)** — custom-drawn Win32/GDI+ interface: nav rail, cards, animated
  toggle switches, segmented controls, overlay scrollbars; **Light/Dark/System themes with a
  quick switcher**, 8 accent presets or “follow Windows”, Per-Monitor-V2 DPI, Windows 11
  rounded corners and dark title bar.
- **Safety** — JSON snapshots (schema v8) with automatic backup before bulk changes,
  restore/export/delete manager, 30-snapshot retention.
- **Ops-ready CLI** — `--promote-all`, `--status --json`, `--watch`, stable exit codes
  (`0/1/2/3`), rotating 14-day logs.
- **Embedded installer (new in 8.1)** — on first run a built-in setup wizard asks: install
  folder (default `%LOCALAPPDATA%\Programs\TrayIconGuard`), autostart, Desktop and Start Menu
  shortcuts — or *just run once* in portable mode. Creates an Apps & Features uninstall entry;
  `--uninstall` removes everything. Still zero dependencies, still one exe.
- **Git-based self-updater** — opt-in check against `update/stable.json` in this repo,
  SHA-256-pinned download, self-replace and relaunch (`Updater_SKILL.MD`).
- **Visibility modes** — Full / Custom / Compact from the tray menu; drag-reorder icons.
- **Respectful** — HKCU only (no admin, ever), no telemetry, opt-in update checks,
  close-to-tray, single instance, autostart opt-in.

## Quick start

1. Download `TrayIconGuard-8.0.0-win-x64.zip` from
   [Releases](https://github.com/paulmann/windows-show-all-tray-icons/releases) (or build it,
   see [docs/BUILD.md](docs/BUILD.md)).
2. Unblock & run `TrayIconGuard.exe`. That's the whole installation.
3. First run: everything is promoted once, the guard arms itself, a balloon welcomes you.
   Open **Appearance** to pick a theme/accent/language.

Optional per-user install (Start Menu shortcut + uninstaller entry):

```powershell
powershell -ExecutionPolicy Bypass -File installer\install.ps1
```

### Headless / deployment

```powershell
TrayIconGuard.exe --promote-all        # one-shot, exit 0 (3 = partial failure)
TrayIconGuard.exe --watch              # headless guard (replaces v7 BAT/PS editions)
TrayIconGuard.exe --status --json      # monitoring-friendly snapshot
TrayIconGuard.exe --install-autostart  # HKCU Run entry (--minimized)
```

Full CLI reference: [docs/CLI.md](docs/CLI.md). User guide: [docs/USER-GUIDE.md](docs/USER-GUIDE.md).

## Requirements

| Component | Requirement |
|---|---|
| OS | Windows 10 1703+ (build 15063+), Windows 11, Server 2019/2022/2025 (x64) |
| Runtimes | **None.** Uses only OS-provided DLLs (user32, gdiplus, comctl32, …) |
| Rights | Standard user. Everything is HKCU; no UAC prompt, ever |
| Disk | < 1 MB |

On builds without `NotifyIconSettings` (pre-1703) the app degrades gracefully and reports the
limitation on the Dashboard.

## Repository layout

```
├── src/                  C++17 sources (core engine, UI kit, pages)
│   ├── core/             registry store, guard thread, backups, CLI, logs, settings
│   ├── ui/               theme manager, GDI+ kit, main window, 7 pages, tray icon
│   └── app/              bootstrap, single instance, IPC
├── resources/            icon.ico (10 sizes), manifest, version info, banner
├── scripts/              build.sh (mingw cross), package.sh, make_icon.py, sync-backup.sh
├── cmake/                mingw-w64 toolchain file
├── installer/            install.ps1 / uninstall.ps1 / install.bat / TrayIconGuard.iss (Inno, optional)
├── docs/                 ARCHITECTURE / HOW-IT-WORKS / CLI / BUILD / USER-GUIDE / TROUBLESHOOTING / DESIGN
├── .vscode/              build tasks (Ctrl+Shift+B), debug config
└── .github/workflows/    CI: cross-build on ubuntu + MSVC build on windows, artifacts
```

## Build it yourself

Cross-compile from Linux/macOS (what CI does):

```bash
sudo apt install g++-mingw-w64-x86-64 cmake
./scripts/build.sh          # -> dist/TrayIconGuard.exe (static, stripped)
```

Or natively on Windows with MSVC/MinGW via CMake — see [docs/BUILD.md](docs/BUILD.md).

## Verification & QA

- Compiles with `-Wall -Wextra` at **zero warnings**.
- Imported DLLs are exclusively Windows system libraries (verified with `objdump -p`).
- Wine smoke matrix: CLI modes + all 7 pages rendered in light, dark and RU locale
  (screenshots in `shots/`, self-captured by the app via `--ui-test`).
- No telemetry; network access only via the manual “Check for updates” button.

## Author & license

**Author: Mikhail Deynekin** — icons@Deynekin.com · https://Deynekin.com ·
[paulmann/windows-show-all-tray-icons](https://github.com/paulmann/windows-show-all-tray-icons)

PolyForm Noncommercial 1.0.0 © 2026 Mikhail Deynekin.
Registry mechanics researched and documented by Mikhail Deynekin
([paulmann/windows-show-all-tray-icons](https://github.com/paulmann/windows-show-all-tray-icons),
v7 “Phoenix”); v8 is an independent clean-room C++ implementation of those mechanics with a
new UI, icon and codebase.
