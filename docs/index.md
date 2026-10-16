---
title: TrayIconGuard — keep every Windows tray icon visible
description: "TrayIconGuard is a native C++ Win32 guard for Windows 10/11 that keeps notification-area icons on the taskbar, with a Fluent GUI, headless watcher, full CLI, 30 languages and zero dependencies."
---

# TrayIconGuard

**Keep every notification-area (system tray) icon visible on Windows 10/11 — and keep it that way.**
One native executable (~1 MB), zero dependencies, zero telemetry.

[Download the latest release](https://github.com/paulmann/windows-show-all-tray-icons/releases/latest){: .btn}
[Knowledge base (wiki)](https://github.com/paulmann/windows-show-all-tray-icons/wiki){: .btn}
[Source code](https://github.com/paulmann/windows-show-all-tray-icons){: .btn}

---

## The problem it solves

Windows remembers tray-icon visibility per icon and **forgets it constantly**: every time an
application (re)registers its notification icon, Explorer recreates
`HKCU\Control Panel\NotifyIconSettings\{id}` with `IsPromoted = 0` — and the icon drops back into
the `^` overflow flyout. One-shot `.reg` tweaks decay within hours.

TrayIconGuard writes the same store the Windows Settings toggle uses, then keeps a
**`RegNotifyChangeKeyValue` watcher** on it: as soon as Explorer hides a promoted icon, the guard
restores it (typically well under a second). Per user, no admin rights, no telemetry.

## Install in three steps

1. Download `TrayIconGuard.exe` (or the zip with docs and installer helpers) from the
   [latest release](https://github.com/paulmann/windows-show-all-tray-icons/releases/latest).
2. Right-click the exe → **Properties → Unblock** (Mark-of-the-Web) → OK.
3. Run it. The first-run wizard asks for the install scope — *Only for me* (no UAC),
   *For all users* (one UAC prompt) — or pick *just run once* for portable use.

Verify your download: `Get-FileHash .\TrayIconGuard.exe -Algorithm SHA256` and compare it with the
`sha256` field of [`update/stable.json`](https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/update/stable.json).

## Highlights

- **Event-driven guard** — `RegNotifyChangeKeyValue` + debounce, optional polling, pause/resume
- **Visibility modes** — *Full*, *Custom* (your per-icon choices), *Compact* (only TrayIconGuard)
- **Per-icon control** — promote/hide/exclude, wildcard exclusions, drag-reorder
- **Modern Fluent UI** — Light/Dark/System themes, accent colours, Per-Monitor-V2 DPI, keyboard-first
- **Headless too** — `--watch`, `--status --json`, `--promote-all`, stable exit codes `0/1/2/3`
- **Self-updating** — SHA-256-pinned feed in this repository; CI pins the feed from the released bytes
- **Safe by construction** — HKCU only, standard user, snapshots before destructive operations
- **30 languages** with per-string English fallback and OS-language auto-detect

## Command line at a glance

```text
TrayIconGuard.exe                     # tray-resident GUI
TrayIconGuard.exe --minimized         # start hidden in the tray
TrayIconGuard.exe --promote-all       # fix everything now, then exit
TrayIconGuard.exe --watch             # headless guard (Task Scheduler / GPO logon script)
TrayIconGuard.exe --status --json     # machine-readable state for RMM/monitoring
TrayIconGuard.exe --check-update      # ask the feed whether a newer version exists
TrayIconGuard.exe --uninstall         # remove shortcuts, autostart and the installed copy
```

Full list: [Command-Line Interface](https://github.com/paulmann/windows-show-all-tray-icons/wiki/Command-Line-Interface) · exit codes · `--install-machine` for
elevated fleet installs.

## Documentation

| Guide | What's inside |
|---|---|
| [Getting Started](https://github.com/paulmann/windows-show-all-tray-icons/wiki/Getting-Started) | first run, the wizard, portable vs installed |
| [How Tray Visibility Works](https://github.com/paulmann/windows-show-all-tray-icons/wiki/How-Tray-Visibility-Works) | the registry mechanics, the decay problem, the do-not-touch list |
| [The Guard Watcher](https://github.com/paulmann/windows-show-all-tray-icons/wiki/The-Guard-Watcher) | event-driven re-promotion, debounce, polling fallback |
| [GUI Pages Guide](https://github.com/paulmann/windows-show-all-tray-icons/wiki/GUI-Pages-Guide) | every page of the app |
| [Command-Line Interface](https://github.com/paulmann/windows-show-all-tray-icons/wiki/Command-Line-Interface) | all flags, exit codes, automation recipes |
| [Configuration Reference](https://github.com/paulmann/windows-show-all-tray-icons/wiki/Configuration-Reference) | `settings.json` and registry values, in full |
| [Self-Updater Guide](https://github.com/paulmann/windows-show-all-tray-icons/wiki/Self-Updater-Guide) | the feed contract, SHA-256 pinning, verification |
| [Security and Privacy](https://github.com/paulmann/windows-show-all-tray-icons/wiki/Security-and-Privacy) | what the program touches, threat model |
| [Installation and Deployment](https://github.com/paulmann/windows-show-all-tray-icons/wiki/Installation-and-Deployment) | per-user and machine scope, Task Scheduler, RMM |
| [Troubleshooting](https://github.com/paulmann/windows-show-all-tray-icons/wiki/Troubleshooting) | the failures we have actually seen and their fixes |
| [Comparison with Alternatives](https://github.com/paulmann/windows-show-all-tray-icons/wiki/Comparison-with-Alternatives) | TrayIconGuard vs registry scripts, StartAllBack, ExplorerPatcher, Windhawk |
| [Building from Source](https://github.com/paulmann/windows-show-all-tray-icons/wiki/Building-from-Source) | mingw-w64 cross-build and native MSVC |
| [Localization and Themes](https://github.com/paulmann/windows-show-all-tray-icons/wiki/Localization-and-Themes) | 30 locales, adding a language, theming |
| [Architecture](https://github.com/paulmann/windows-show-all-tray-icons/wiki/Architecture) | module map, threading model, IPC |
| [Changelog and Versioning](https://github.com/paulmann/windows-show-all-tray-icons/wiki/Changelog-and-Versioning) | release history and the publication contract |
| [Roadmap and Ideas](https://github.com/paulmann/windows-show-all-tray-icons/wiki/Roadmap-and-Ideas) | what is planned next |
| [FAQ](https://github.com/paulmann/windows-show-all-tray-icons/wiki/FAQ) · [Glossary](https://github.com/paulmann/windows-show-all-tray-icons/wiki/Glossary) | quick answers and vocabulary |

## Security & privacy

- **Registry:** per-icon visibility under `HKCU\Control Panel\NotifyIconSettings`; machine scope only
  through the explicit, UAC-elevated `--install-machine` path.
- **Network:** the update feed and the release asset it points to — HTTPS only, the binary is
  verified against the feed's SHA-256 before it is applied.
- **No telemetry, no auto-install.** The automatic update check is opt-in, at most once per 24 h,
  and only shows a balloon notification.

Reporting a vulnerability: see [SECURITY.md](https://github.com/paulmann/windows-show-all-tray-icons/blob/main/SECURITY.md).

## License

[PolyForm Noncommercial License 1.0.0](https://github.com/paulmann/windows-show-all-tray-icons/blob/main/LICENSE) —
free for noncommercial use; commercial licensing: contact the author.

**Mikhail Deynekin** · <icons@Deynekin.com> · [Deynekin.com](https://Deynekin.com) ·
[GitHub](https://github.com/paulmann)

<sub>TrayIconGuard is not affiliated with Microsoft. Windows is a trademark of Microsoft Corporation.</sub>
