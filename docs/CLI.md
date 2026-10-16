# CLI reference — TrayIconGuard.exe

Exit codes: `0` ok · `1` invalid arguments · `2` unsupported OS/store · `3` partial failure.

Headless modes print to the attached console, and to the inherited handle as UTF-8 when the
process is started with a redirect (`> state.json`, `| more`, RMM/CI capture) — so automation
gets the same bytes as a human does. Invalid arguments print `error: <reason>` followed by a
`--help` hint and exit with code 1.

| Command | Effect |
|---|---|
| *(no args)* | Start the tray-resident GUI (restores window position/page from settings) |
| `--minimized`, `-m` | Start GUI hidden in the notification area (autostart uses this) |
| `--show` | IPC: activate the window of a running instance |
| `--toggle-guard` | IPC: pause/resume the guard of a running instance |
| `--status` | Print tray state (counts, legacy switches, autostart) and exit |
| `--status --json` | Same as machine-readable JSON (icons array included) |
| `--promote-all` | Set `IsPromoted=1` on every non-excluded icon; applies legacy belt & HideSCA* cleanup; optional auto-backup; exit |
| `--restore-defaults` | Delete all `IsPromoted` values (hand control back to Windows); remove `EnableAutoTray`; exit |
| `--restart-explorer` | Safe shell restart (kill → wait ≤8 s → manual start if needed); exit |
| `--backup` | Write a JSON snapshot to `%LOCALAPPDATA%\TrayIconGuard\backups`; exit |
| `--restore-latest` | Apply the newest snapshot; exit |
| `--watch` | Headless event-driven guard loop (Ctrl+C stops). Replaces v7 BAT/PS watcher editions |
| `--install-autostart` | Add `HKCU\...\Run\TrayIconGuard = "<exe>" --minimized` |
| `--uninstall-autostart` | Remove the Run value |
| `--install-machine <dir> [--autostart] [--desktop] [--menu]` | all-users install body; must run elevated (UAC child) |
| `--uninstall` | Embedded uninstaller: exit running instance, delete shortcuts, autostart, Apps&Features entry; schedules self-delete of the install folder |
| `--ui-test [page]` | QA: render page (`dashboard icons guard appearance backups activity about`), self-capture PNG to `%TEMP%\tig-uitest-<page>.png`, exit |
| `--version`, `-v` | Print version |
| `--help`, `-h`, `/?` | Help text |

Notes:

- `--promote-all` / `--restore-defaults` / `--backup` / `--restore-latest` operate directly on
  the registry; a concurrently running GUI instance reconciles via its watcher.
- When a GUI instance already runs, a second GUI launch forwards `--show` to it and exits 0
  (single-instance mutex).
- `--json` guarantees stdout purity: nothing else is printed in JSON mode.
- Redirecting or piping stdout is safe: the JSON document goes to the inherited pipe/file handle
  (fixed in 8.6.1), so both `--status --json > state.json` and
  `TrayIconGuard.exe --status --json | ConvertFrom-Json` work on real Windows.

Examples:

```powershell
TrayIconGuard.exe --status --json | ConvertFrom-Json | Select-Object promoted, hidden
schtasks /Create /TN TrayGuard /TR "C:\Tools\TrayIconGuard.exe --watch" /SC ONLOGON   # headless deployment
TrayIconGuard.exe --promote-all; if ($LASTEXITCODE -ne 0) { Write-Host "partial failure" }
```
