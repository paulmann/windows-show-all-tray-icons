# REWORK-STATE.md — TrayIconGuard v8 "Aurora" (master continuity file)

> **Purpose:** any new agent/session continues from THIS file. Read it first, then `AGENTS.md`.
> Mirrors: `/home/user/REWORK-STATE.md` (pointer) and `/home/user/backup/work/REWORK-STATE.md` (auto-synced).
> Sync after every milestone: `bash /home/user/work/scripts/sync-backup.sh "message"`

## 1. Mission

Complete professional rewrite/refactor of https://github.com/paulmann/windows-show-all-tray-icons
("TrayIconGuard v7 Phoenix", C# WPF net10.0-windows + PowerShell 7.6 + BAT) into:

**TrayIconGuard v8 "Aurora"** — a single native Win32 C++17 executable for Windows 10/11 that:

1. Has ZERO install dependencies (no .NET, no SDK, no runtimes) — static-linked native exe (~0.5 MB), uses only OS DLLs.
2. Modern 2026 UI, adaptive/responsive, **Light/Dark/System theme with toggle, persistence, auto-detect on first run**.
3. Adds features the original missed (see §4 feature list).
4. Beautiful custom icon (programmatic vector-quality .ico 16→256 px).
5. Production-ready: CI, versioning, checksums, docs EN+RU, installer scripts, CLI, exit codes, logs, backups.

All decisions are made autonomously (user directive: «Все вопросы решай самостоятельно»).

## 2. Key decisions (locked)

| # | Decision | Rationale |
|---|---|---|
| D1 | Native C++17 Win32 + GDI+ custom-drawn UI (no Qt/WPF/WebView2/Electron) | zero deps, compact, full theme control |
| D2 | Cross-compile with mingw-w64 (Debian sandbox), static: `-static -static-libgcc -static-libstdc++`, `-municode`, strip | single exe, no MSVC needed here |
| D3 | mingw is **win32 threads model** → use Win32 threads (CreateThread, SRWLOCK, CONDITION_VARIABLE), NOT std::thread | avoids missing <thread> |
| D4 | One exe replaces all three v7 editions: GUI + `--watch` headless guard + CLI one-shots (replaces PS module & BAT) | simpler distribution |
| D5 | Settings: `%APPDATA%\TrayIconGuard\settings.json` (hand-rolled JSON subset parser, no deps) | matches v7 layout |
| D6 | Logs: `%LOCALAPPDATA%\TrayIconGuard\logs\TrayIconGuard-yyyyMMdd.log` (14-day retention) + in-memory ring (500) for Activity page | matches v7 |
| D7 | Backups: `%LOCALAPPDATA%\TrayIconGuard\backups\TrayIconState-*.json` schema v8, cap 30, auto-backup before destructive ops (default ON) | matches v7, improved |
| D8 | License: MIT (clean-room rewrite, no upstream code copied; upstream went PolyForm Noncommercial) + attribution in README/About | legal safety |
| D9 | HKCU-only, standard user, no admin ever. No telemetry. Update check = manual button only (no auto phone-home) | respects v7 philosophy |
| D10 | UI: left nav rail (Dashboard/Icons/Guard/Appearance/Backup/Activity/About), responsive collapse < 860 px, status bar, custom toggles/scrollbars, Segoe UI Variable/MDL2 glyphs, DWM dark titlebar, PerMonitorV2 DPI | modern Fluent look |
| D11 | Localization EN + RU, auto-detect via GetUserDefaultUILanguage on first run | user is RU-speaking |
| D12 | Explorer restart: kill all explorer.exe → wait ≤8 s → start manually if absent; confirmation dialog (configurable) | v7 mechanics |
| D13 | Version 8.0.0, ProductName "TrayIconGuard", exe `TrayIconGuard.exe` | continuity |
| D14 | Solid themed backgrounds (Win11 #F3F3F3/#202020 family) instead of Mica (GDI+ over DWM backdrop is risky) — documented as future option | stability |

## 3. Registry mechanics (from upstream docs/HOW-IT-WORKS.md — VERIFIED FACTS, keep)

- **Primary store (Win10 1703+/Win11):** `HKCU\Control Panel\NotifyIconSettings\{<icon-id>}` values:
  `IsPromoted` DWORD (1=on taskbar, 0=overflow flyout), `ExecutablePath` REG_SZ, `IconResource` REG_SZ (`path,-id`),
  `IconSnapshot` REG_BINARY, `LastNotificationAddedTime` REG_QWORD.
- **Decay problem:** Explorer recreates subkeys with `IsPromoted=0` on every app (re)registration → one-shot tweaks fail.
  **Fix = watcher:** `RegNotifyChangeKeyValue` on the subtree (`REG_NOTIFY_CHANGE_NAME | REG_NOTIFY_CHANGE_LAST_SET`), ~400 ms debounce, rescan, re-promote.
- **Live apply:** Explorer usually picks up external writes; on some Win11 24H2+/fast-switch cases → shell restart needed.
- **Legacy belt-and-suspenders:** `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer` → `EnableAutoTray`=DWORD 0 (harmless, helps legacy components).
- **HideSCA* policies (correct path!):** `HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer` → remove `HideSCAVolume/HideSCANetwork/HideSCAPower` when =1. (Old .reg files wrote wrong path without `Policies` — no effect.)
- **Legacy cache repair (explicit only):** delete `IconStreams`,`PastIconsStream` under `HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify` (often absent on Win11).
- **Autostart:** `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` → `TrayIconGuard = "C:\...\TrayIconGuard.exe" --minimized`.
- **DO NOT TOUCH:** `StuckRects3\Settings` (corrupts taskbar layout), no GPO/all-users claims (doesn't exist for per-icon promotion).

## 4. Feature list (v8 = v7 GUI features + NEW)

v7 parity: tray-resident guard, event-driven watcher (debounce+poll fallback+new-icon discovery), per-icon toggles, exclusions, promote-all now, pause/resume guard, Explorer restart, JSON backup/restore, legacy cleanup (EnableAutoTray, HideSCA*, tray cache reset), autostart, start minimized, single instance, balloon notifications, activity log, CLI (`--promote-all`, `--restore-defaults`, `--minimized`, exit codes 0/1/2/3), dark/light follow Windows, PerMonitorV2.

NEW in v8 (user asked «add what I forgot»):
1. **Explicit theme switcher Light/Dark/System** + persisted + first-run auto-detect (v7 only followed system).
2. **Accent color**: follow-Windows (DWM colorization) or 8 presets.
3. **Full localization EN/RU** + auto-detect + live switch.
4. **Search + filters** in icon list (all/promoted/hidden/excluded), sort by name/state/recent.
5. **Icon metadata**: extracted icon image, FileDescription friendly name, exe path, GUID, last-notification time; row context menu (promote/hide/exclude/open location/copy GUID/copy path).
6. **Guard stats**: total promotions this session, last event time, uptime, events/sec chart? (no — keep: counters + last events feed).
7. **Activity page**: persisted log viewer with level filter + export + open folder.
8. **Backup page**: snapshot list w/ size/date, create/restore/delete/export, auto-backup toggle, "restore latest".
9. **`--watch` headless mode** (replaces BAT+PS editions), `--status [--json]`, `--toggle-guard`, `--restart-explorer`, `--backup`, `--restore-latest`, `--install-autostart`, `--uninstall-autostart`, `--show`, `--version`, `--help`.
10. **IPC single-instance**: second launch activates window / passes CLI to running instance (hidden msg window + RegisterWindowMessage).
11. **Close-to-tray** (configurable) + first-close hint balloon.
12. **Keyboard/accessibility**: full Tab traversal, Space toggles, Esc back, accelerators (Ctrl+F search, Ctrl+1..7 pages), focus rings.
13. **Responsive layout**: nav rail collapses to icons < 860 px; content reflows; min 640×480.
14. **Animations**: toggle slide 140 ms, page transitions, hover states (60 fps timer only while animating).
15. **Diagnostics**: About → "Copy diagnostics" (OS build, version, settings, log tail).
16. **Manual update check** via WinHTTP → GitHub releases/latest (semver compare), never automatic.
17. **Onboarding hint cards** on Dashboard (enable autostart, etc.).
18. **Auto-backup before promote-all/restore-defaults**.
19. **Graceful degradation**: no NotifyIconSettings (ancient Win10) → status explains, offers EnableAutoTray; no crash if registry ops fail.
20. **Rotating logs, 14-day cleanup, crash-safe settings writes (tmp+rename).**

## 5. Environment (sandbox)

- Debian 12 bookworm, root, 9.3 GB disk, network OK.
- `x86_64-w64-mingw32-g++` GCC 12.2 (**win32 threads!**), `x86_64-w64-mingw32-windres`, cmake 3.25.1, make, git.
- wine64: see status in §8 (for smoke tests under `xvfb-run`, screenshots via `import`/xwd? ImageMagick NOT installed — use `python3 -m PIL`? wine screenshots: use `xwd`? If unavailable, install imagemagick).
- python3.11 + PIL 12.3.0 (icon generation), cppcheck (static analysis), rsync (backup sync).
- **No Windows machine available** → verification = compile(-Wall -Wextra) + cppcheck + wine smoke run + screenshot review + rigorous code review checklist (agents/A8-qa.md).

## 6. Workspace layout

```
/home/user/work/            ← ACTIVE project (git repo)
  REWORK-STATE.md AGENTS.md
  src/            app/ core/ ui/{kit,pages}/ util/  (C++17)
  resources/      icon.ico, resources.rc, banner/
  scripts/        sync-backup.sh, make_icon.py, build.sh, package.sh
  docs/ installer/ tests/ .vscode/ .github/workflows/ agents/ dist/
/home/user/backup/work/     ← rsync mirror (run scripts/sync-backup.sh)
/home/user/REWORK-STATE.md  ← pointer copy
```

## 7. Build commands (once CMakeLists exists)

```bash
cd /home/user/work
cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE=cmake/mingw-w64-x86_64.cmake -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
# artifact: build/TrayIconGuard.exe  → copy to dist/
x86_64-w64-mingw32-strip dist/TrayIconGuard.exe   # (cmake does it)
# smoke test:
xvfb-run -a wine64 dist/TrayIconGuard.exe --status   # CLI path
xvfb-run -a wine64 dist/TrayIconGuard.exe --ui-test  # GUI: create window, render, exit after N ms
```

## 8. Milestones

| ID | Milestone | Status |
|----|-----------|--------|
| M0 | Research upstream, env setup, state files, swarm charter | ✅ DONE |
| M1 | Icon + visual assets (make_icon.py → resources/icon.ico, banner) | ✅ DONE |
| M2 | Foundation: util/str, util/fs, json, settings, log, osinfo — COMPILES | ✅ DONE |
| M3 | Core engine: registry, trayicons store, guard watcher thread, explorer, legacy, backup, autostart, update, cli, ipc — COMPILES | ✅ DONE |
| M4 | UI kit: theme manager, widget framework (button/toggle/segment/search/list/scroll/nav), mainwindow shell — COMPILES | ✅ DONE |
| M5 | Pages: dashboard, icons, guard, appearance, backup, activity, about + tray icon + balloons — COMPILES | ✅ DONE |
| M6 | Resources: .rc (icon, version, manifest), CMake, windres → **TrayIconGuard.exe built 801 KB static stripped** | ✅ DONE |
| M7 | Wine smoke: CLI ok, 7 pages × light/dark/RU reviewed, cppcheck clean (style only), warnings=0 | ✅ DONE |
| M8 | Docs EN/RU (README×2, 7 docs), .vscode, CI (cross+MSVC+release), installer ps1/bat/iss, package.sh → zip+SHA256 | ✅ DONE |
| M9 | Final QA: 0 warnings, cppcheck no errors, wine CLI+GUI matrix, zip+SHA256, tag v8.0.0 | ✅ DONE |
| M10 | v8.4.1: restored lost 8.4.0 sources (scope engine, wizard picker, About buttons, polish), About z-order fix, beta cycle clean, feed+package 8.4.1 | ✅ DONE |
| M11 | v8.6.0: real-Windows beta findings fixed (theme seg mapping, icons toggle/reorder repaint, tray menu discipline + dblclk), LegalCopyright, CI feed contract (make_feed.py) | ✅ DONE |

## 9. Agent swarm roster (details in AGENTS.md + agents/*.md)

A0 Orchestrator (main LLM) · A1 Core engine · A2 UI kit · A3 Pages/features · A4 Theme/art direction · A5 Icon & assets · A6 Build/packaging/CI · A7 Docs · A8 QA/audit.
Parallelization: independent bash jobs (compile loops, icon gen, doc drafting) run concurrently; A5 art via image tools while A1–A3 code.

## 10. Pitfalls log (append-only; read before coding!)

- P1: mingw g++ is **win32 threads** → `<thread>`/`<mutex>` may be missing; use CreateThread/SRWLOCK/CONDITION_VARIABLE. (`g++-mingw-w64-x86-64-posix` also installed; switching alternatives is possible but Win32 API preferred.)
- P2: mingw-w64 v10 headers may lack: `DWMWA_USE_IMMERSIVE_DARK_MODE`(20)/`DWMWA_SYSTEMBACKDROP_TYPE`(38)/`DWMSBT_*`, `TaskDialogIndirect` needs `_WIN32_WINNT>=0x0601` + comctl32 v6 manifest, `RegNotifyChangeKeyValue` in winreg.h (OK). → define missing constants ourselves in `src/core/win_compat.h`.
- P3: Use `-DUNICODE -D_UNICODE -DWIN32_LEAN_AND_MEAN -DNOMINMAX -D_WIN32_WINNT=0x0A00 -municode` (wWinMain). GDI+ header: include `<gdiplus.h>` AFTER `<windows.h>`; works with NOMINMAX (verify at first compile; if clash, `using min/max` locally).
- P4: All file I/O UTF-8; registry APIs WIDE only (`*W`). Convert with util/str (MultiByteToWideChar CP_UTF8).
- P5: wine may lack Segoe fonts → screenshots show fallback boxes for glyphs; judge layout, not font rendering. Install ms fonts? (ttf-mscorefonts needs contrib; skip — note in QA.)
- P6: `Shell_NotifyIcon`, taskbar behaviors don't exist under wine → GUI smoke must tolerate failures; add `--ui-test` mode (render main window, dump screenshot-able state, auto-exit after 1.5 s, skip tray).
- P7: Static link order matters; libs: `-lgdiplus -lcomctl32 -ldwmapi -luxtheme -lshlwapi -lversion -lwinhttp -lole32 -loleaut32 -lshell32 -ladvapi32 -lgdi32 -luser32 -lkernel32`.
- P8: Settings writes: write tmp → `MoveFileExW(...REPLACE_EXISTING)` for crash safety.
- P9: RegNotifyChangeKeyValue one-shot per signal → re-arm after each event; watch handle must stay open.
- P10: exe size control: `-ffunction-sections -fdata-sections -Wl,--gc-sections -O2 -s`; GDI+ pulls ~200 KB — acceptable.
- P11: NEVER touch StuckRects3 (D-list §3). HKCU only.
- P12: gcc12 `-Wall -Wextra` must end with zero warnings before M7 sign-off (cast pitfalls: DWORD↔int, LONG↔size_t).
- P13: Backup dir sync: `scripts/sync-backup.sh` does rsync work→backup/work + git add/commit. Run after EVERY milestone. Do not delete via wildcards; if cleanup needed, verify with `git status` after.
- P14: wine first run creates ~/.wine (may be slow ~60 s, prints fixme noise; use `WINEDEBUG=-all`).
- P15: `settings::Load()` latches (`g_loaded`); after an elevated child wrote settings.json the
  parent MUST call `settings::Reload()` or `NeedsRelaunch()` sees stale state (fixed in 8.4.1).
- P16: `ThemeMode{System=0, Light=1, Dark=2}` — QA seeds use theme 1/2, NOT 0/1.
- P17: wine as root reports `TokenIsElevated=TRUE` — the `--install-machine` elevation gate
  cannot be exercised under wine; verify on real Windows (code path is standard TokenElevation).
- P18: Page subclasses must draw card FILLS in `PaintBackground`, never in `Paint`
  (`Page::Paint` draws widgets between them) — About hid all its buttons until 8.4.1.
- P19: arena harness may rewrite quoted literal `"$ARENA_WORKSPACE"/work/...` paths inside heredocs;
  use relative paths + `cd` in python snippets.

## 11. Progress journal (newest last)

- 2026-10-16 J1: Env ready (mingw/cmake/PIL/cppcheck/xvfb/rsync). Upstream researched: README + HOW-IT-WORKS fully captured (§3/§4). Dirs + git initialized. State files created. Wine install retried (see env §5).
- 2026-10-16 J2: A5 done: icon.ico (10 sizes, BMP+PNG entries), icon_256/512, logo_mono, banner 1680x720 (sheet reviewed).
- 2026-10-16 J3: M2+M3 core compiles -Wall -Wextra with 0 errors / 0 warnings.
- 2026-10-16 J4: exe built: 801 KB static; imports = only Windows system DLLs (advapi32 comctl32 comdlg32 dwmapi gdi32 gdiplus kernel32 ole32 shell32 shlwapi user32 version winhttp msvcrt). ZERO non-OS deps => user requirement met.
- 2026-10-16 J5: wine QA: CLI exit codes ok; graceful 'store not supported' path; ui-test self-screenshot mechanism works (CaptureSelfPng); shots/ has light+dark+ru-violet for all 7 pages.
- 2026-10-16 J6: fixed 3 systemic UI bugs: (a) page content offset under nav rail (widget rects now offset to window coords in Page::Layout), (b) cards painted over widgets (PaintBackground split), (c) settings row desc overlap. Dark theme + RU locale + custom accent verified visually.
- 2026-10-16 J7: wine %APPDATA% = users/root/AppData/Roaming (win10 mode) — QA note for future sessions.
- 2026-10-16 J8: M8 done: README EN/RU, docs/{HOW-IT-WORKS,ARCHITECTURE,CLI,BUILD,USER-GUIDE,TROUBLESHOOTING,DESIGN}, CHANGELOG, LICENSE(MIT+attribution), CI (ubuntu cross + windows MSVC + release), installer/{install.ps1,uninstall.ps1,install.bat,TrayIconGuard.iss}, .vscode tasks/launch, package.sh.
- 2026-10-16 J9: M9 done: dist/TrayIconGuard.exe 821,760 B static stripped; zip 374 KB; SHA256SUMS published; --status --json verified; preview montage shots/preview-2x2.png; git tag v8.0.0.
- 2026-10-16 J10 (v8.1.0): EMBEDDED INSTALLER shipped per user request: src/core/installer.{h,cpp} (IShellLink shortcuts Desktop/StartMenu+uninstall lnk, HKCU Uninstall entry, autostart at dest path, copy+relaunch, --uninstall with IPC-exit + delayed self-delete via detached cmd), src/ui/setupwizard.{h,cpp} (modal custom-drawn first-run wizard: folder+Browse (IFileOpenDialog FOS_PICKFOLDERS), 3 toggles, Install / Just-run-once portable), settings.install{mode,dir}, About: mode badge + Install button, strings +19×2 langs, version.h single source (8.1.0).
- QA v8.1: wine: fresh profile → wizard (light+dark-RU shots in shots/setup-wizard-*.png), portable mode skips wizard, --uninstall exit 0, 0 warnings, exe 860,672 B static; zip 8.1.0 + SHA256SUMS; tag v8.1.0.
- 2026-10-16 J11 (v8.2.0): i18n shipped: 30 locales (en base complete; ru complete; zh/es/de/fr/pt/ja/ko/it core ~150 ids; 20 locales essential ~50-75 ids; per-string EN fallback), lang_<code>.cpp sparse packs + langdef.h macros, registry+resolver in strings.cpp, OS auto-detect map (30 LANGID->code) in core/os.cpp, scrollable native-name LanguageList on Appearance, settings language=BCP-47 tag. exe 973 KB. QA: wine zh dashboard + lang list shots (CJK tofu in wine = missing fonts only; GDI+ per-char fallback on real Windows). docs/I18N.md added. RTL mirroring = tracked future item.
- 2026-10-16 J12 (v8.2.1): FIXED Win11 SxS launch failure reported by user (screenshot: 'side-by-side configuration is incorrect'): root cause = non-canonical embedded manifest (duplicate supportedOS GUID + activeCodePage/heapCompatibility/longPathAware elements) rejected by strict Win11 SxS validation; wine CreateActCtx test harness added (build/actctx-test.c) proves embed OK but wine is lenient; manifest rewritten to canonical minimal form; build.sh manifest regression gate added; docs/TROUBLESHOOTING section + hint: avoid parent dirs named *.exe. exe re-packaged 8.2.1.
- 2026-10-16 J13 (v8.3.0): tray RMB fixed (NOTIFYICON_VERSION_4 removed) + tray menu modes Full/Custom/Compact (+author site, exit); guard mode engine (compact hides all but own icon via OwnIconId); userHidden per-icon intent; icons drag-reorder (settings.iconsOrder); About author block (Mikhail Deynekin <icons@Deynekin.com>, Deynekin.com); license MIT->PolyForm Noncommercial 1.0.0 (LICENSE + strings); toggle OFF redesigned (no outline, dark-orange #9D4A00/#A84A00 track, white knob = ON rotated 180); git updater: update/stable.json feed + WinHTTP + BCrypt sha256 + rename-chain apply + relaunch, --check-update/--update-now, opt-in daily auto-check, About update panel; Updater_SKILL.MD publication contract; E2E verified in wine via local http feed (download->sha->rename->.old->relaunch, exit 0); Store kit store/{AppxManifest.xml,37 assets,make_msix.ps1} + docs/STORE.md + docs/PRIVACY.md; docs/SMARTSCREEN.md (MOTW/installer-copy/signing); dist/git-upload-v8.3.0.zip prepared for user's git push.
- SESSION CLOSED: M0–M9 ✅, v8.1 installer ✅, v8.2 i18n ✅, v8.2.1 SxS ✅, v8.3.0 updater+modes+store ✅. Continue: AGENTS.md → scripts/build.sh → QA via --ui-test / TIG_SETUP_SHOT=1 + wine.
- 2026-10-16 J14 (v8.4.1): discovered published 8.4.0 binaries contained features whose sources
  were never committed (lost session work): install scope (per-user/all-users UAC engine),
  wizard scope segmented, About License/Wiki buttons, perfectionist pass. Reconstructed from
  release exe (UTF-16 string mining) + release zip CHANGELOG + wine reference screenshots of
  the published exe (`.agent/ref/`). Re-implemented in source: installer Scope::Machine
  (RunElevated runas child `--install-machine`, HKLM Run/Uninstall, common shortcuts,
  decline-UAC per-user fallback), settings.installScope + Reload(), wizard 688px + segmented +
  scope-aware hints, About buttons + flow rows + title-row chip, hero tile borders/responsive/
  12px gap, CLI/help/status version single-sourcing.
- 2026-10-16 J15 (beta cycle v8.4.1): found+fixed About z-order (cards over widgets — buttons
  invisible since 8.0.0!), wizard Browse misalignment, GCC missing-field-init warnings,
  cppcheck sbar shadowing, settings latch bug. Wine matrix 14 pages + 2 wizards re-shot
  (shots/), loopback updater E2E re-verified (rename-chain + relaunch exit 0), live-feed
  `--check-update` OK. 0 warnings, cppcheck clean.
- 2026-10-16 J17 (v8.6.0): user real-Windows beta round: (a) Appearance segmented cast index
  onto ThemeMode{System,Light,Dark} while items are {Light,Dark,System} → swapped themes;
  fixed with explicit ModeToIdx/IdxToMode. (b) IconList kept stale entry copies after
  SetPromoted/CommitDrag → toggles & drag-reorder looked dead; added onData→Refilter.
  (c) Tray: TrackPopupMenu lacked SetForegroundWindow/WM_NULL (vanishing/sticky menu that
  swallows clicks); dblclk open hardened (+NIN_SELECT). (d) About chip dropped the
  GetHDC/second-Graphics measure (GDI+ lock hazard) → gfx::TextWidth. (e) LegalCopyright
  MIT→PolyForm in resources.rc. (f) Publication contract 8.6: scripts/make_feed.py pins the
  feed from SERVED release bytes (self-test vs live 8.4.1 feed = MATCH); ci.yml release job
  now: normalize layout → upload → make_feed → commit+push feed; Updater_SKILL.MD §3 rewritten.
  Version 8.6.0 (user asked to skip 8.5); store manifest 8.6.0.0; E2E loopback re-run OK;
  wine matrix + wizards re-shot; 0 warnings; cppcheck clean.
- 2026-10-16 J16: packaged 8.4.1 (exe sha 9f7d6f39…, zip 657abf7f…), update/stable.json → 8.4.1,
  store manifest 8.4.1.0, docs (USER-GUIDE scope, CLI.md, README badges), dist/git-upload-v8.4.1.zip
  prepared for the user's git push. SESSION STATE: all user requirements green; awaiting user's
  git upload of the release assets to verify auto-update from live feed.


