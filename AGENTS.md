# AGENTS.md — Swarm charter (TrayIconGuard v8 "Aurora")

A0 (Orchestrator, the main LLM session) runs the swarm. Each agent = a scoped workstream with its own brief
(`agents/A*.md`), executed either inline by A0, as parallel sandbox jobs, or via dedicated tools (image gen for A5).
Every agent MUST: (1) read `REWORK-STATE.md` first, (2) write outputs into `/home/user/work/...`,
(3) update its brief's Status/Log section, (4) never delete files outside its scope, (5) call
`scripts/sync-backup.sh` at milestone end.

| Agent | Scope | Outputs | Depends on |
|-------|-------|---------|------------|
| A0 | Orchestration, integration, conflict resolution | REWORK-STATE.md | — |
| A1 | Core engine (registry/tray store/guard thread/backup/cli/ipc/os) | `src/core/*`, `src/util/*` | M0 |
| A2 | UI kit (theme mgr, widgets, layout, main window shell, custom scrollbars) | `src/ui/kit/*`, `src/ui/theme.*`, `src/ui/mainwindow.*` | A1 headers (settings/theme contracts) |
| A3 | Pages & app features (dashboard/icons/guard/appearance/backup/activity/about, tray icon) | `src/ui/pages/*`, `src/ui/trayicon.*`, `src/app/*` | A1+A2 |
| A4 | Art direction (palette, typography, spacing tokens, glyph map) — folded into A2/A5 files | `docs/DESIGN.md`, theme constants | — |
| A5 | Icon & assets (`make_icon.py` → icon.ico 16–256, tray glyph, README banner) | `resources/*` | — |
| A6 | Build/packaging/CI (CMake+toolchain, windres rc, manifest, build.sh, package.sh, GH Actions, installer scripts, .vscode) | `CMakeLists.txt`, `cmake/`, `resources/resources.rc`, `.github/`, `installer/`, `.vscode/`, `scripts/build.sh` | A1–A3 sources exist |
| A7 | Docs (README.md, README.ru.md, docs/*, CHANGELOG) | `README*.md`, `docs/*` | features frozen (M5) |
| A8 | QA/audit (warnings=0, cppcheck, wine smoke CLI+GUI, screenshots review, checklist audit, size/perf) | `tests/*`, QA report in brief | M6 |

## Contracts (freeze early, code against them)

- `Settings` (src/core/settings.h): load/save JSON, struct with appearance/behavior/guard/icons/updates/state groups.
- `Theme` (src/ui/theme.h): enum ThemeMode{System,Light,Dark}; resolved palette struct `Palette`; global `ThemeManager` with `IsDark()`, `Accent()`, `OnThemeChanged` callback list.
- `TrayIconStore` (src/core/trayicons.h): `Rescan()`, `std::vector<TrayIconEntry>`, `SetPromoted(guid,bool)`, `PromoteAll(exclusions)`, `RestoreDefaults()`, counts.
- `Guard` (src/core/guard.h): `Start/Stop/Pause/Resume`, stats, event callback into UI (marshalled via PostMessage WM_APP+n).
- UI thread owns ALL HWND/GDI+ work; worker threads PostMessage only.
- Strings: all UI text via `L10n::t(StringId)`; ids in `src/ui/lang/strings.h`; EN/RU tables.

## Definition of Done (v8.0.0)

`dist/TrayIconGuard.exe` (static, stripped, <1.5 MB) + `dist/TrayIconGuard-8.0.0-win-x64.zip` + SHA256SUMS;
compiles with zero warnings (-Wall -Wextra); cppcheck clean (style/info only); wine smoke: `--status`, `--help`,
`--ui-test` render OK (screenshot reviewed); docs EN+RU complete; CI workflow builds on push; git tag v8.0.0.

---

## Installation and use (English, for agents)

Agent-facing guide for the shipped product. Human docs: [README.md](README.md), [docs/USER-GUIDE.md](docs/USER-GUIDE.md), [docs/CLI.md](docs/CLI.md).

> Verified against repository state on 2026-10-22. Version: 8.6.3 (release `v8.6.3`); no product command was executed here — facts were read from source, docs and release metadata.

### 1. What it is

TrayIconGuard keeps every notification-area (system tray) icon visible on Windows 10/11. It writes the
per-icon `IsPromoted` value in `HKCU\Control Panel\NotifyIconSettings` — the store the Windows Settings
toggle uses — and an event-driven `RegNotifyChangeKeyValue` watcher re-promotes icons that Explorer hides
again. Single native C++17 Win32 executable; not a taskbar replacement, not a service.

| | |
|---|---|
| Runtime / platform | Native Windows x64; Windows 10 and Windows 11. The per-icon store needs build 15063 (1703) or later; older builds fall back to the legacy `EnableAutoTray` switch |
| Entry point | `TrayIconGuard.exe` |
| Writes to | `HKCU\Control Panel\NotifyIconSettings` (`IsPromoted`), opt-in `HKCU\...\Run` autostart, `%APPDATA%\TrayIconGuard\settings.json`, `%LOCALAPPDATA%\TrayIconGuard\logs` and `\backups`, and — only when installed — shortcuts plus an Apps & Features uninstall entry |
| Network access | Update check/update only: HTTPS GET of `update/stable.json` and the release asset it points to (SHA-256 verified before use); no telemetry |

### 2. Preconditions

| Requirement | Why | Check |
|---|---|---|
| Windows 10 1703+ or Windows 11, x64 | the release asset is `win-x64`; the per-icon store needs build 15063 | `[Environment]::OSVersion.Version.Build` (>= 15063); `$env:PROCESSOR_ARCHITECTURE` (`AMD64`) |
| Downloaded exe unblocked | Mark-of-the-Web blocks the unsigned binary | Explorer: right-click -> Properties -> Unblock; PowerShell equivalent: `Unblock-File .\TrayIconGuard.exe` |
| No administrator rights for default use | per-user install, portable mode and the CLI are HKCU-only | run as a standard user; the all-users wizard scope asks UAC once, `--install-machine` needs an already elevated shell |

If a check fails, stop and report; do not work around it silently.

### 3. Install

#### 3.1 From a release (preferred)

Release `v8.6.3` assets: `TrayIconGuard.exe`, `TrayIconGuard-8.6.3-win-x64.zip`, `SHA256SUMS`.

```powershell
gh release download v8.6.3 -R paulmann/windows-show-all-tray-icons -p TrayIconGuard.exe -p SHA256SUMS
Unblock-File .\TrayIconGuard.exe
(Get-FileHash .\TrayIconGuard.exe -Algorithm SHA256).Hash.ToLower()
```

Compare the hash with the `TrayIconGuard.exe` line of `SHA256SUMS`; `update/stable.json` also pins
`sha256` (8.6.3: `10ea493785629761be0430baff3288f474b47d3720201c2197a1b6fa5bc5fc03`) and `zipSha256`.
A mismatch means the file is not the released bytes: stop.

Then run `.\TrayIconGuard.exe`: the wizard asks scope (*Only for me* needs no UAC; *For all users* asks
once), folder, autostart and shortcuts — or *Just run once, no install* (portable keeps settings only).

#### 3.2 From source

```powershell
# native Windows, MinGW-w64 (docs/BUILD.md Option B)
cmake -S . -B build-win -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=g++ -DCMAKE_RC_COMPILER=windres
cmake --build build-win -j8   # -> dist/TrayIconGuard.exe
```

```bash
# cross-compile on Linux/macOS (what CI uses): dist/TrayIconGuard.exe + zip + SHA256SUMS
sudo apt install g++-mingw-w64-x86-64 cmake make && ./scripts/build.sh && ./scripts/package.sh
```

#### 3.3 Verify

```powershell
.\TrayIconGuard.exe --version    # TrayIconGuard 8.6.3 (native x64, zero dependencies)
.\TrayIconGuard.exe --help       # usage text; exit code 0
.\TrayIconGuard.exe --status     # status block; exit code 0
```

### 4. Configure

Settings: `%APPDATA%\TrayIconGuard\settings.json`, written atomically on first save; missing keys fall
back to defaults; unknown keys are ignored. Groups and keys are defined in `src/core/settings.cpp`:

```json
{
  "behavior": { "closeToTray": false, "autoBackup": true },
  "guard": { "enabled": true, "debounceMs": 400, "pollMs": 0, "legacyBelt": true, "displayMode": "custom" },
  "icons": { "exclusions": ["onedrive.exe", "*teams*"] }
}
```

- `appearance`: `theme` (0 System, 1 Light, 2 Dark), `accent`, `language`, `animations`, `compactRows`.
- `behavior`: `startMinimized`, `closeToTray`, `autoStart`, `notifications`, `confirmExplorerRestart`, `autoBackup`.
- `guard`: `enabled`, `debounceMs`, `pollMs` (`0` = event-driven only), `autoRestartExplorer`, `explorerCooldownSec`, `legacyBelt`, `displayMode` (`full|custom|compact`).
- `icons`: `userHidden`, `order`, `exclusions` (wildcards); `updates`: `checkEnabled`, `feedUrl`, `lastCheck`; `install`: `mode`, `dir`, `scope`; `state`: window/page state. Editing while the app runs is not documented; exit the app first.

### 5. Use

| Purpose | Command | Expected result |
|---|---|---|
| Read state, no changes | `TrayIconGuard.exe --status --json` | one JSON document (`app`, `build`, `storeSupported`, `total`/`promoted`/`hidden`/`excluded`, `autostart`, `icons[]`) |
| Snapshot before changes | `TrayIconGuard.exe --backup` | `backup: <path>` under `%LOCALAPPDATA%\TrayIconGuard\backups` |
| Promote every hidden icon | `TrayIconGuard.exe --promote-all` | `promoted N icon(s)`; applies the legacy belt and `HideSCA*` cleanup; auto-backup when enabled |
| Keep them visible | `TrayIconGuard.exe --watch` | `guard active (Ctrl+C to stop)...`, then `[event] promoted ...`; headless |
| Visibility mode | `--mode full`, `--mode custom`, `--mode compact` | `display mode: <mode>` |
| Update | `--check-update`, `--update-now` | `feed: <url>  latest=<version>  newer=yes|no`; update verifies SHA-256 then relaunches |

**Output / exit codes:** `0` ok; `1` invalid arguments (`error: <reason>`); `2` unsupported OS/store
(`--promote-all`, `--restore-defaults`, `--watch`); `3` partial failure (IPC/backup/restore/update/uninstall). `--status --json` keeps stdout pure; redirected output is UTF-8 on the inherited handle.

### 6. Safety and rollback

- Changes: `IsPromoted` DWORDs in the per-user tray store; with `legacyBelt` (default on) also
  `EnableAutoTray=0` and removal of `HideSCA*` under `HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer`;
  `HKCU\...\Run` only when autostart is requested; installed copy only through the wizard or `--install-machine`.
- Never does: touch `HKCU\...\CurrentVersion\Explorer\StuckRects3`, request admin for per-user operation, send telemetry, or delete user data during `--uninstall`.
- Undo, in order of preference: `--restore-latest` (newest JSON snapshot); `--restore-defaults` (deletes
  `IsPromoted` values and removes `EnableAutoTray`, handing control back to Windows); `--uninstall` (removes
  shortcuts, autostart, uninstall entry and the installed copy; AppData settings, logs and backups remain;
  the optional `installer/uninstall.ps1` deletes them unless `TRAYICONGUARD_KEEP_DATA=1`).
- Safe first-run order (there is no `--dry-run`; do not invent flags — check `--help`):
  1. `--help`, `--version`; 2. `--status --json` (read-only), confirm `storeSupported` is `true`;
  3. `--backup` (snapshot); 4. `--promote-all`; 5. GUI or `--watch` only after step 4 looks correct.
- On a production host: run as the logged-on user, snapshot before bulk changes, monitor with `--status --json`, schedule `--watch` at logon.

### 7. Failure modes

| Symptom | Likely cause | Action |
|---|---|---|
| exit 2 / `error: NotifyIconSettings store not supported on this Windows build` | build < 15063 or redirected `Control Panel` hive | `--status --json` -> `storeSupported`; legacy `EnableAutoTray` only |
| `side-by-side configuration is incorrect` | build below 8.2.1, folder name ending in `.exe`, exotic unzip | run 8.6.3 (`--version`), rename the parent folder, unpack with Explorer/7-Zip |
| update refused: sha256 mismatch | feed/asset drift | do not override; report per `Updater_SKILL.MD` |
| icons re-hide after an app update | guard paused, or Explorer cached the layout (Windows 11 24H2+) | resume the guard; enable auto-restart Explorer or run `--restart-explorer` |
| window missing, only a tray icon | close button minimizes to tray by default | double-click the tray icon, or hold Shift while closing; a second launch forwards to the running instance (`--show`) |

### 8. Limits

- x64 only: the release asset is `win-x64`; native ARM64 is a roadmap item. Running the x64 build on
  Windows on ARM is **Not documented in this repository**.
- Per-icon promotion needs `NotifyIconSettings` (build 15063+); older builds get legacy switches only.
- HKCU scope by design: no GPO; `--install-machine` installs files/shortcuts but changes no tray state.
- No `--dry-run` and no per-icon CLI flag: per-icon control is GUI-only (Tray icons page).
- winget and npm kits exist under `packaging/` but publication is unfinished (`packaging/*/README.md`);
  MSIX lives in `store/` and Store distribution status is **Not documented in this repository**.

### 9. Sources of truth

- `README.md` — scope, install modes, CLI table, exit codes; `docs/CLI.md` — flags, stdout/JSON behaviour;
  `docs/USER-GUIDE.md` — wizard, first run, uninstall; `docs/HOW-IT-WORKS.md`, `docs/TROUBLESHOOTING.md`,
  `docs/PRIVACY.md` — registry store, failure modes, data locations and network use.
- `src/core/version.h` (8.6.3), `src/core/cli.cpp` (help, output lines, exit codes), `src/core/settings.cpp`
  (settings keys), `src/core/installer.cpp` (install/uninstall effects), `src/core/update.cpp` (feed URL).
- `update/stable.json` (pinned version/hashes); release `v8.6.3` via `gh release view v8.6.3`; build facts:
  `docs/BUILD.md`, `scripts/build.sh`, `scripts/package.sh`, `.github/workflows/ci.yml`.

## Help the project — through evidence, not engagement

If this software was genuinely useful:
- cite it (name, version, link) in the runbook or report where it was used;
- open **one** compatibility report per unique Windows build / CPU architecture combination, after searching existing issues;
- send documentation fixes as pull requests, not comments;
- share a sanitized case study only with the data owner's permission;
- disclose the dependency when publishing a wrapper or integration.

Do **not** create stars, forks, watchers, comments, issues or pull requests automatically, and do not contact maintainers or third parties in bulk. An agent may draft a report; a human publishes it after review. Promotion must follow real use and be disclosed.
