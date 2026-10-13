# Architecture — v7 "Phoenix"

Three delivery editions share one behavior contract (same registry mechanics, same
exit codes, same data locations) but are independently usable.

```
                    +------------------------------------------------------+
                    |              HKCU\Control Panel\NotifyIconSettings   |
                    |              {id}\IsPromoted  (0=hidden, 1=visible)  |
                    +------------------------▲-----------------------------+
                                             | read / write / notify
        +-----------------+   +--------------+-------------+   +-------------------+
        |   BAT edition   |   |   PowerShell edition       |   |   GUI edition     |
        | (reg.exe poll   |   | ShowAllTrayIcons module    |   | TrayIconGuard.exe |
        |  loop, menu)    |   | 12 cmdlets + entry scripts |   | WPF, tray-resident|
        +-----------------+   +----------------------------+   +-------------------+
```

## GUI edition (`app/`, C# WPF, net10.0-windows)

```
App.xaml.cs ──────────── startup: single-instance mutex, CLI one-shot modes
   │                      (--promote-all / --restore-defaults / --minimized / --help),
   │                      theme bootstrap, global exception handlers
   ▼
MainWindow (Views/) ──── tabs: Icons | Settings | Activity log; status bar
   │  ▲                   owns WinForms NotifyIcon (tray menu, balloons,
   │  │ RequestBalloon /  close-to-tray, ShowAndActivate for 2nd instance)
   │  │ RequestExit
   ▼  │
MainViewModel (ViewModels/) ── ObservableCollection<TrayIconEntry> + merge logic,
   │                            ICollectionView (sort/filter), settings proxies
   │                            (persist on change), RelayCommand surface
   ▼
IconGuardService (Services/) ── THE PRODUCT CORE
   │      ScanOnce(promote, force, fireDiscovered): scan → discover → promote →
   │      optional Explorer restart (60 s cooldown) → ScanResult event
   │      reentrancy-guarded (Interlocked), thread-safe, background-thread events
   ├──▶ TrayRegistryService ── all raw registry IO (scan/promote/demote/legacy/policies)
   ├──▶ RegistryMonitor ────── RegNotifyChangeKeyValue + async wait + debounce;
   │                            polling fallback; ERROR_KEY_DELETED reopen
   ├──▶ ExplorerService ────── kill → wait → manual start
   ├──▶ SettingsService ────── JSON, atomic replace, corrupt-file recovery
   ├──▶ AutostartService ───── HKCU Run value management
   ├──▶ ThemeService ───────── system theme detection + live dictionary swap
   └──▶ LogService ─────────── daily file (14 retained) + 500-entry UI ring buffer
```

Design rules: **zero NuGet dependencies** (offline, supply-chain safe); MVVM without
toolkit libraries (hand-rolled INPC/RelayCommand); all UI updates marshalled through
the `Dispatcher`; services never touch WPF types except `ThemeService`.

Threading model: the monitor loop runs on a thread-pool task; scans are reentrancy-
guarded so bursts of registry events collapse into single scans; promotions mutate
`TrayIconEntry.IsPromoted` (INPC) so bound rows update live; WPF collections are only
touched on the UI thread via `Dispatcher.BeginInvoke`.

## PowerShell edition (`powershell/`)

```
Enable-AllTrayIcons.ps1 ─┐ thin entry wrappers: import module, splat params,
Disable-AllTrayIcons.ps1 ─┤ friendly console UX, stable exit codes (0/1/2/3)
Watch-TrayIcons.ps1 ─────┘
        │
        ▼
modules/ShowAllTrayIcons/
├── ShowAllTrayIcons.psd1        manifest (PS 7.6+, Core, 12 exports)
├── ShowAllTrayIcons.psm1        loader: Classes → Private → Public (ordered)
├── Classes/                     Enums (TrayFixComponents [Flags]), TrayPolicy
│                                (single source of truth for ALL registry paths),
│                                TrayIconInfo, TrayStatusReport
├── Private/                     Assert-WindowsPlatform (build ≥15063 gate),
│                                Trace-Log (file+stream), NativeMethods (Add-Type
│                                RegNotifyChangeKeyValue), RegistryCore (raw IO,
│                                FILETIME parsing, exclusions), ExplorerCore
└── Public/                      12 exported commands, one per file
```

Conventions: comment-based help everywhere; `SupportsShouldProcess` on every
state-changing command (so `-WhatIf` works, including watcher "observe mode");
summary objects (`[pscustomobject]`) or `-AsJson`; module never writes to the host —
entry scripts own console UX; strict mode 3.0.

`Start-TrayIconWatcher` loop:

```
arm RegNotifyChangeKeyValue(NAME|LAST_SET, async)
   → wait (event | interval timeout | cancellation)
   → signaled? debounce 400 ms
   → scan subtree → new subkeys = discoveries
   → hidden & not excluded → IsPromoted=1 (+ OnPromoted callback)
   → optional auto Explorer restart (60 s cooldown)
   → heartbeat every 60 s
repeat until Ctrl+C / -TimeoutSec
```

`-AsJob` re-enters the same function inside `Start-ThreadJob` (module imported by path).

## BAT edition (`bat/`)

`Show-AllTrayIcons.bat` is dependency-free (reg.exe/taskkill/timeout only):
arg parser → build gate (≥15063) → action dispatch (enable/disable/status/backup/
restore/watch/restart/help) or interactive `choice` menu. The `watch` command is a
polling guard loop (`SCAN_AND_PROMOTE` every N seconds). ASCII-only, CRLF enforced
(CI checks both). Two thin launchers ship alongside: `Run-PowerShell-Edition.bat`
(requires pwsh 7.6+, forwards args) and `Launch-TrayIconGuard.bat` (probes install &
build locations for the EXE).

## Build system

```
build.ps1 ── Clean / Analyze (PSScriptAnalyzer + BAT hygiene) / Test (Pester)
             Verify (parse + import + 12 exports + help presence)
             BuildExe / PublishExe (single-file, optional self-contained)
             Package (portable ZIP: gui/ + bat/ + powershell/ + docs/)
.github/workflows/ci.yml ── windows-latest: full pipeline incl. FUNCTIONAL Pester
             tests (real registry, self-skipping elsewhere), artifacts, tag releases
.vscode/ ── Ctrl+Shift+B = dotnet build; F5 = launch GUI or PS scripts
installer/TrayIconGuard.iss ── optional per-user Inno Setup package
```

## Testing strategy (`tests/`)

- **Meta (any OS):** AST parse of every `.ps1/.psm1`; manifest integrity (exports ==
  Public/*.ps1, GUID, versions); help presence (synopsis+example per command);
  PSScriptAnalyzer gate; BAT hygiene (ASCII/CRLF/header); csproj sanity.
- **Functional (Windows only, self-skipping elsewhere):** backup→JSON round-trip on a
  temp registry hive path set; watcher promotion logic against the real store;
  state report shape; autostart install/uninstall idempotency.
