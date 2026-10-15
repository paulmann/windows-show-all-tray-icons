# Architecture — TrayIconGuard v8

Single native Win32 C++17 executable. No frameworks, no runtimes: Win32 API + GDI+ only.
Cross-compiled with mingw-w64 (`-static`), or natively with MSVC/MinGW via CMake.

## Thread model

| Thread | Responsibility |
|---|---|
| UI (main) | Window messages, all HWND/GDI+ work, settings writes, clipboard, dialogs |
| Guard worker | `RegNotifyChangeKeyValue` wait → debounce → reconcile pass → events |
| Transient workers | Update check (one-shot `CreateThread`) |

Worker → UI communication is **PostMessage only** (`WM_APP+1`, heap-copied payload deleted by
the UI). No shared UI state; shared engine state is guarded by SRWLOCKs.

## Module map

```
src/core/     engine (no UI includes)
  registry    thin Reg* wrappers (GetDword/SetDword/EnumSubkeys/…)
  trayicons   TrayIconStore: Rescan/SetPromoted/PromoteAll/RestoreDefaults,
              friendly names (FileDescription), HICON cache
  guard       watcher thread: arm→wait→debounce→pass→events; stats; pause/resume
  legacy      EnableAutoTray, HideSCA* cleanup, TrayNotify cache reset
  explorer    safe shell restart (kill → wait 8 s → manual start)
  backup      JSON snapshots v8: create/restore/export/prune
  autostart   HKCU Run install/remove
  settings    settings.json load/save (defaults for missing keys), first-run flag
  log         rotating daily file log + 500-entry ring for the Activity page
  json        dependency-free JSON subset parser/writer (ordered objects)
  cli         argv parsing, headless execution, exit codes, IPC client
  update      manual WinHTTP GET GitHub releases/latest, semver compare
  os          RtlGetVersion, system theme/accent/language, DPI helpers
src/ui/
  theme       Palette resolution (light/dark × accent), subscribers
  gfx         GDI+ bootstrap, fonts cache, rounded rects, text, icon raster
  kit/        Widget base + Button/IconButton/Toggle/Segmented/SearchBox/ScrollBar
  mainwindow  shell: nav rail, top bar, status bar, input routing, double buffering,
                DWM (dark titlebar, rounded corners), animation timer, IPC-free QA hooks
  pages/      7 pages (Dashboard, Icons, Guard, Appearance, Backups, Activity, About)
  trayicon    own notification icon (state dot overlay), menu, balloons, TaskbarCreated
  lang/       EN/RU string tables, auto-detect
src/app/      bootstrap: single-instance mutex, init order, IPC message-only window, loop
```

## Key design decisions

- **Custom-drawn UI** (no common controls except a borderless EDIT for search input and
  TaskDialog for confirmations): full theming control, identical look on Win10/11, tiny
  binary. Double-buffered: one compatible DC + BitBlt per WM_PAINT.
- **Widgets are retained-mode objects** with `Layout/Paint/OnMouse/Tick`; pages own them.
  Page-local coordinates are translated to window coordinates once per layout
  (`Page::Layout` offsets widget rects), so hit-testing and painting share one space.
- **Paint order:** page background → `PaintBackground` (cards, labels) → widgets →
  scrollbars. Cards never cover interactive elements.
- **Animations:** exponential approach (`Widget::Approach`), 16 ms timer armed only while
  something moves; disabled entirely by the “Animations” setting.
- **Themes:** palette structs resolved from mode (Light/Dark/System) + accent
  (system colorization or `#RRGGBB`); `WM_SETTINGCHANGE(ImmersiveColorSet)` re-resolves live.
- **Crash safety:** settings and snapshots written via tmp file + `MoveFileExW(REPLACE_EXISTING)`.
- **Graceful degradation:** missing `NotifyIconSettings` (pre-1703) → Dashboard reports it,
  CLI exits 2 for store operations; wine/VMs never crash the app.
- **QA hook:** `--ui-test <page>` renders a page headless-friendly and self-captures a PNG
  (`%TEMP%\tig-uitest-<page>.png`) — used for the wine screenshot matrix in `shots/`.

## Exit codes

`0` ok · `1` invalid arguments · `2` unsupported OS/store · `3` partial failure.
