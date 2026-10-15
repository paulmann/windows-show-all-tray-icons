# Privacy Policy — TrayIconGuard

Short version: **the app collects nothing and sends nothing.**

- No telemetry, no analytics, no crash reporting, no advertising identifiers.
- All data (settings, logs, tray-state snapshots) is stored locally in your user profile:
  `%APPDATA%\TrayIconGuard` and `%LOCALAPPDATA%\TrayIconGuard`.
- Network access happens **only** when you press *About → Check for updates* (or enable the
  opt-in automatic check): one HTTPS GET of a small JSON feed and, if you confirm an update,
  one HTTPS GET of the new executable, whose SHA-256 hash is verified before installation.
- The app never requests administrator rights and writes only per-user registry keys
  (`HKCU\Control Panel\NotifyIconSettings`, opt-in `HKCU\...\Run`).
- Uninstalling removes the program files; your settings/logs/backups remain until you
  delete them or run `--uninstall`, which also offers to keep them.

Questions: icons@Deynekin.com · https://Deynekin.com
