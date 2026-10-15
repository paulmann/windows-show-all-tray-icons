# Changelog

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
