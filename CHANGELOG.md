# Changelog

## 8.6.1 — 2026-10-16

### Fixed
- **CLI output was silently discarded when stdout/stderr were redirected on real Windows**
  (`TrayIconGuard.exe --status --json > state.json`, `| more`, RMM or CI capture: exit code 0,
  empty stream). Two causes in `src/core/cli.cpp`: `Print()` went through `WriteConsoleW`, and
  `AttachConsoleIfPossible()` unconditionally rebound `stdout`/`stderr` to `CONOUT$`, throwing
  away the inherited pipe/file handle — and a GUI-subsystem process has no CRT stream bound to
  that handle, so the old `fwrite(stdout)` fallback wrote nowhere.
  Output now goes to the console when one is attached, and otherwise straight to the inherited
  handle as UTF-8 through `WriteFile`; the console streams are only bound when nothing was
  inherited. Measured on Windows 11 (build 26300): the 8.6.0 binary produced **0 bytes** for
  `--status --json > file` while this build produces the full JSON document, and pipe capture
  returns every line. `--check-update`, `--help` and every other CLI verb benefit equally.
- **Invalid arguments exited 1 in complete silence** — the parser's error string was computed in
  `wWinMain` and dropped. The CLI now prints `error: <reason>` plus a `--help` hint, e.g.
  `error: unknown argument: --bogus`.
- `CMakeLists.txt` still declared the 8.0.0 project version.

### Changed
- Version 8.6.1; store manifest 8.6.1.0.

## 8.6.0 — 2026-10-16

### Fixed
- **Appearance: theme segments were mis-mapped** (`Light` applied System, `Dark` applied
  Light, `System` applied Dark) — item index was cast straight onto `ThemeMode`
  (System=0/Light=1/Dark=2); explicit Light/Dark/System mapping now.
- **Tray icons page: per-row toggles and drag-reorder changed state but not the pixels** —
  the list kept stale entry copies until re-filter; `onData` callback resyncs the view
  immediately after promote/hide and after a drag commit. Sorting by drag now visibly works.
- **Tray menu discipline**: `SetForegroundWindow` before `TrackPopupMenu` + `WM_NULL` after
  (MS-recommended) — fixes menus that vanish/stick and swallow the next clicks;
  double-click (and `NIN_SELECT`) on the tray icon now always opens the window.
- **About: install-mode chip** no longer measures text via a second `Gdiplus::Graphics` on a
  borrowed HDC (GDI+ lock hazard); uses layout-time `gfx::TextWidth`.
- **LegalCopyright** in the PE version info said “MIT” while the project is
  PolyForm Noncommercial 1.0.0 — corrected (Mikhail Deynekin).

### Changed
- **Publication contract 8.6**: `scripts/make_feed.py` generates `update/stable.json` from
  the bytes the GitHub release actually serves; the CI tag pipeline uploads assets and then
  pins+commits the feed itself. Local-byte pinning is gone (no more CI/local hash fights).
- Version 8.6.0; store manifest 8.6.0.0.

### Verified (beta cycle)
- Wine matrix 7 pages x light/dark + wizard light/dark-RU re-shot after fixes;
  click-audit of every button/toggle/segment for visible state change;
  loopback updater E2E re-run; live feed 8.4.1 asset parity re-checked;
  0 warnings, cppcheck clean, manifest gate OK.

## 8.4.1 — 2026-10-16

### Restored
- **Source parity with the published 8.4.0 binary**: the install-scope engine, wizard scope
  picker, About License/Knowledge-base buttons and the perfectionist UI pass had been built
  and released as binaries but their sources were lost before commit; re-implemented from
  the released exe (string + UI archaeology) and re-verified against reference screenshots.

### Added
- Installer: `Scope::Machine` engine — UAC-elevated child (`--install-machine`), Program Files
  target, common Desktop/Start-Menu shortcuts, HKLM Run + HKLM uninstall entry,
  decline-UAC fallback to per-user, `--uninstall` auto-elevation for machine installs.
- Settings: persisted `install.scope` (`user` | `machine`); `settings::Reload()` so the
  wizard host sees state written by the elevated child (relaunch prompt fix).
- About: License and Knowledge-base buttons open the GitHub LICENSE / wiki; links flow into
  stable rows at any width; install-mode chip sits on the Links card title row.
- CLI: `--install-machine <dir> [--autostart] [--desktop] [--menu]`; help and `--status`
  banners now take the version from `version.h` (no more hard-coded strings).

### Fixed
- **About page z-order**: update/links card fills were painted over their widgets — every
  button on the page was invisible (bug present since 8.0.0, caught by the beta cycle).
- Wizard: Browse button vertically aligned with the folder field; scope segmented placed
  below the card title (no overlap); window height 688 px for the new row.
- Dashboard hero: stat tiles got borders + responsive width, 12 px gap to the action row;
  System card key column responsive.
- GCC `-Wmissing-field-initializers` on `SHELLEXECUTEINFOW`; cppcheck shadowed `sbar`
  members renamed to `listBar` (Activity/Backups); wizard folder moved to the init list.

### Verified (beta cycle)
- Wine matrix: 7 pages x light/dark + wizard light + wizard dark-RU; CLI matrix incl.
  `--check-update` against the live git feed and a loopback E2E update
  (download -> SHA-256 -> rename-chain -> relaunch, exit 0).
- 0 compiler warnings (`-Wall -Wextra`), cppcheck clean, manifest gate OK,
  imports = Windows system DLLs only.

## 8.4.0 — 2026-10-16

### Added
- Installer wizard: **scope choice — “Only for me” / “For all users”** (machine scope runs
  elevated via UAC: Program Files, common Desktop/Start-Menu shortcuts, HKLM Run +
  HKLM uninstall entry); `--install-machine <dir> <opts>` headless equivalent;
  `--uninstall` auto-elevates for machine installs.
- About: **License** and **Knowledge base (wiki)** buttons, author block, install-mode chip
  moved to the card title row; links reflow into stable rows at any width.
- Language default is the **system UI language** (`auto`), verified for all 30 mappings.

### Fixed
- CI: `bcrypt.dll` added to the dependency whitelist; `scripts/*.sh` exec bits restored.
- CMake: GCC-only flags no longer passed to MSVC (`/W4 /O2 /utf-8` branch added).
- Perfectionist pass: hero tiles get borders + responsive width and 12 px gap to the action
  row; settings-row labels vertically centered when no description; System card columns
  widened; wizard scope segmented no longer overlaps the card title; scope-aware hints.

### Verified (beta cycle)
- Real-git updater E2E: feed (raw.githubusercontent) → GitHub release asset → SHA-256 →
  rename-chain apply → relaunch (8.2.9 → 8.3.0, exit 0); `--check-update`/`--update-now`.
- Beta screenshot cycle light/dark × 7 pages + wizard; two fix cycles applied.

## 8.3.0 — 2026-10-16

## 8.3.0 — 2026-10-16

### Added
- **Git-based self-updater**: feed `update/stable.json` (schema, sha256 pinning, channels),
  WinHTTP download, BCrypt SHA-256 verify, rename-chain self-replace + relaunch;
  `--check-update`, `--update-now`, opt-in daily auto-check with balloon; About panel with
  notes and “Download and update”. Publication contract: `Updater_SKILL.MD`.
- **Tray visibility modes**: Full / Custom / Compact — tray menu radios, `--mode`,
  guard-aware reconciliation (Compact keeps only TrayIconGuard's own icon visible).
- **Tray menu fixed & extended** (Windows 11 RMB regression via NOTIFYICON_VERSION_4
  removed): Show, modes, Promote all, Pause/Resume, **Author's website**, Exit.
- **Drag-reorder** of tray icons in the Icons page (persisted per-PC order).
- **Author block** in About: Mikhail Deynekin <icons@Deynekin.com>, https://Deynekin.com.
- Microsoft Store kit: `store/AppxManifest.xml`, 37 logo assets, `make_msix.ps1`,
  `docs/STORE.md`, `docs/PRIVACY.md`; `docs/SMARTSCREEN.md` anti-warning guide.

### Changed
- License: MIT → **PolyForm Noncommercial 1.0.0** (LICENSE, About, badges).
- Toggle OFF state redesigned: no outline; ON-state pill rotated 180°, dark-orange track,
  white knob.

## 8.2.1 — 2026-10-16

## 8.2.1 — 2026-10-16

### Fixed
- **Windows 11 “side-by-side configuration is incorrect” launch failure**: the embedded
  manifest contained a duplicated `supportedOS` GUID and non-canonical `windowsSettings`
  elements (`activeCodePage`, `heapCompatibility`, `longPathAware`) that strict Win11 SxS
  validation rejects (lenient parsers — wine, older Windows — accept them). The manifest is
  now the conservative canonical form (single supportedOS, dpiAware/dpiAwareness only).
- `scripts/build.sh` gained a manifest regression gate: well-formed XML + unique
  supportedOS GUIDs + required nodes, or the build fails.

## 8.2.0 — 2026-10-16

## 8.2.0 — 2026-10-16

### Added
- **i18n: 30 locales** (en default/fallback, zh, hi, es, ar, fr, bn, ru, pt, ur, id, de, ja,
  tr, ko, vi, it, th, pl, nl, uk, fa, el, cs, sv, hu, ro, he, fi, da) with per-string English
  fallback; sparse id-tagged language packs (`lang_xx.cpp`), OS auto-detect across all 30,
  scrollable native-name language picker on the Appearance page, live switching.
- docs/I18N.md contributor guide.

### Changed
- Language setting now stores BCP-47 primary tags ("auto"/"de"/…); legacy "ru"/"en" values
  still accepted.
- Version 8.2.0 (exe ~950 KB static).

## 8.1.0 — 2026-10-16

## 8.1.0 — 2026-10-16

### Added
- **Embedded dependency-free installer**: first-run setup wizard inside the exe — install
  folder picker, autostart / Desktop / Start Menu shortcut toggles, or portable one-time run;
  creates Apps & Features uninstall entry; relaunch from install dir after copy.
- `--uninstall` self-removal mode (IPC-exits running instance, deletes shortcuts, autostart,
  registry entry; delayed self-delete of the install folder).
- About page: install-mode badge and *Install to this PC…* action for portable copies.

### Changed
- Button hit/label padding tolerant to fallback font metrics; setup note wraps.

## 8.0.0 “Aurora” — 2026-10-16

## 8.0.0 “Aurora” — 2026-10-16

Complete ground-up rewrite of v7 “Phoenix” (C# WPF / .NET 10) in native C++17 Win32.

### Added
- Light/Dark/**System** theme switcher with persistence and first-run auto-detection;
  quick-cycle button in the top bar; live reaction to Windows mode changes.
- Accent color: follow-Windows or 8 presets; EN/**RU** localization with auto-detect.
- Per-icon GUI management: search, filters, state chips, toggles, context menu,
  exclusion wildcards editor; extracted icons + friendly names.
- Backups page: JSON snapshots v8, auto-backup before bulk changes, restore/export/delete,
  30-snapshot retention; Activity page: live leveled log viewer with export.
- `--watch` headless guard, `--status --json`, `--toggle-guard`, `--show`,
  `--install-autostart`, `--uninstall-autostart`, `--ui-test` QA mode.
- Dashboard: live counters, quick actions, system card, hint cards, activity feed.
- Diagnostics copy, manual update check (never automatic), close-to-tray with hint,
  single instance with IPC forwarding, keyboard navigation, Per-Monitor-V2 DPI.
- New programmatic icon (10 sizes) + Fluent banner; MIT license.

### Changed
- One static ~800 KB exe replaces GUI+PowerShell+BAT editions; **zero install dependencies**
  (no .NET/SDK/runtime), imports only OS DLLs.
- Watcher: event-driven with debounce, polling fallback, flap-protected Explorer
  auto-restart with cooldown.
- Settings moved to schema v8 JSON with atomic writes and defaults for missing keys.

### Fixed (vs v7)
- No DOTNET_ROOT/runtime probing issues (native code).
- HideSCA* cleanup uses the correct `Policies\Explorer` path; `StuckRects3` never touched.
- Explorer restart waits for shell window and verifies recovery.

### Removed
- .NET/WPF stack, Pester/BAT/PS editions (functionality merged into the exe),
  Inno-only installer (now optional; PS/BAT installers added).
