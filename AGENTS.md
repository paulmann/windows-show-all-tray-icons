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
