# Security Policy

## Scope

This project intentionally operates with **standard-user privileges only**:

- Writes are limited to the current user's registry hive (`HKCU`):
  `Control Panel\NotifyIconSettings\*\IsPromoted`, the legacy `EnableAutoTray` value,
  stale `HideSCA*` policy cleanup, and the HKCU `Run` autostart value (only when you
  ask for autostart).
- No elevation (UAC) is requested or required by any edition.
- **No network activity of any kind**: no telemetry, no update phone-home
  (the pre-7.0 self-update code was removed), no external endpoints at runtime.
- The GUI (TrayIconGuard) has **zero NuGet dependencies** — supply-chain surface is
  the .NET runtime itself.
- File writes are limited to `%APPDATA%\TrayIconGuard`, `%LOCALAPPDATA%\TrayIconGuard`
  and `%LOCALAPPDATA%\ShowAllTrayIcons` (settings, logs, backups).

## Hardening notes for deployers

- The Run-key autostart value points at an absolute EXE path (or `pwsh
  -EncodedCommand` for the headless watcher). If you sign your builds, enforce
  `AllSigned` / WDAC accordingly — the tools do not self-elevate and cannot.
- Backups may contain executable paths (not secrets), but treat
  `%LOCALAPPDATA%\ShowAllTrayIcons\backups\*.json` as configuration data.
- Killing `explorer.exe` (only with explicit `-RestartExplorer` / GUI button) is
  session-local and recoverable: the shell auto-restarts, and v7 starts it manually
  if that fails.

## Reporting a vulnerability

Please do **not** open a public issue for security problems.

- Email the maintainer listed in the repository profile, or
- Use GitHub's private vulnerability reporting if enabled on the fork you use.

Include: version/commit, edition (BAT/PS/GUI), reproduction steps, and impact.
We aim to acknowledge within 7 days and release fixes as patch versions.

## Supported versions

| Version | Supported |
|---|---|
| 7.x | Yes |
| ≤ 6.x (legacy upstream) | No — known incorrect registry paths; migrate per CHANGELOG |
