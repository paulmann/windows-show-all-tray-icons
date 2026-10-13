# Changelog

All notable changes to **windows-show-all-tray-icons** are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [SemVer](https://semver.org/spec/v2.0.0.html).

## [7.0.3] — 2026-10-13

Third independent Windows audit round. Rounds 1–2 confirmed fixed on Windows 11
(including the GUI headless mode: `--promote-all` → "18 promoted, 76/76 visible,
0 failed"). The round-2 runtime launcher tests earned their keep: executed on
Windows for the first time, they caught a real product defect (R3-1).

### Fixed

- **R3-1 (blocker)** — `-AsJson -WhatIf` polluted stdout: `$PSCmdlet.ShouldProcess`
  prints its "What if:" announcement to the HOST, which lands on **stdout** in a
  redirected child process (measured: stream 1; `-InformationAction SilentlyContinue`
  and `6>$null` do NOT suppress it — reproduced identically in the Linux sandbox).
  New internal gate `Invoke-ShouldProcess`: in machine-readable mode with
  `$WhatIfPreference`, it announces via the **information stream** and returns
  `$false` without calling ShouldProcess. `-WhatIf` safety is unchanged (nothing is
  written anywhere); `... -AsJson -WhatIf | ConvertFrom-Json` now parses without
  pre-cleaning. Applied at every gate in `Enable-AllTrayIcons`,
  `Disable-AllTrayIcons`; `Restore-TrayIconState` gained `-AsJson` with the same
  behavior; entry wrappers add `-InformationAction SilentlyContinue` on JSON paths.
- **R3-1b** — launcher runtime tests no longer require `$env:ComSpec`: explicit
  fallback to `%SystemRoot%\System32\cmd.exe` and a clear error when neither exists
  (previously: 8/88 opaque failures in a filtered environment).
- **R3-2** — the GUI is no longer hostage to an ambient `DOTNET_ROOT` (dev shells
  export it pointing at bundled .NET 8, hiding an installed .NET 10 and triggering
  the apphost's "install .NET" dialog): `build.ps1 -Task PublishExe` now defaults to
  **self-contained** (opt out: `-FrameworkDependent`), `Launch-TrayIconGuard.bat`
  clears `DOTNET_ROOT` for the child process, and README / TROUBLESHOOTING /
  BUILD-AND-RELEASE document the apphost resolution order plus the
  SDK-vs-Desktop-Runtime distinction (the app never needed the SDK).
- **R3-3** — reporting honesty: `.agent/PROGRESS.json` and this changelog now carry
  the ACTUAL round-2 Windows result (85 passed / 3 failed → fixed here); no
  green-washing of unexecuted checks.

### Added

- Regression tests: machine-readable WhatIf routing (announcement on the information
  stream, `$false` returned, stdout pure) and interactive-mode delegation to
  ShouldProcess.

[7.0.3]: https://github.com/paulmann/windows-show-all-tray-icons/releases/tag/v7.0.3

## [7.0.2] — 2026-10-13

Second independent Windows audit round. All nine v7.0.1 fixes were **confirmed on real
Windows 11** (build 26300): Pester 77 passed / 0 failed / 0 skipped (functional suite
executed for real), Analyze 0 findings, BAT counts match the module (76/58/18, Failed 0,
exit 0). Two new blockers were found in that round and are fixed here.

### Fixed

- **N1 (blocker)** — `bat/Run-PowerShell-Edition.bat` did not work with ANY action
  keyword: cmd.exe `shift` also shifts `%0`, so `%~dp0` lost the `bat\` segment and the
  wrapper path resolved above the repository. Rewritten: `SCRIPT_DIR=%~dp0` is captured
  before anything else, the file contains **no `shift` at all** (arguments are collected
  in one pass, `%~1..%~9`, via an `:ADDARG` helper), and a `help` action was added
  (works without pwsh). Works from any current directory.
- **N2 (blocker)** — `.gitignore` lost the `.ragraf/` rule when the file was rewritten
  during round 1; restored without a leading slash (matches at any depth).
  `git check-ignore -v .ragraf` → exit 0.
- README changelog link text said "what changed in 7.0.0"; installer header comment
  still referenced `TrayIconGuard-7.0.0-setup.exe`. Both corrected.

### Added

- `tests/BatLaunchers.Functional.Tests.ps1` — Windows-only suite that **actually
  executes** the BAT launchers and asserts exit codes/output: `help` from repo root and
  from `bat\` (the two broken N1 scenarios), `enable -AsJson -WhatIf` and
  `disable -AsJson -WhatIf` (mapping + forwarding + parseable JSON, no registry writes),
  `Show-AllTrayIcons.bat help|status` (read-only), and a no-FINDSTR-noise assertion.
  *Round-3 note: executed on Windows for the first time, this suite caught defect R3-1
  (`What if:` host text polluting stdout under `-AsJson -WhatIf`); after the v7.0.3 fix
  all its assertions pass.*
- Static launcher guards in the meta-tests (any OS): no `shift` lines, the only `%~dp0`
  use is the early `SCRIPT_DIR` capture, help action present.

[7.0.2]: https://github.com/paulmann/windows-show-all-tray-icons/releases/tag/v7.0.2

## [7.0.1] — 2026-10-13

Defect-fix release after an independent audit on real Windows (Windows 11 build 26300,
PowerShell 7.6.6, PSScriptAnalyzer 1.25.0, Pester 6.2.0). All fixes address root causes;
the public contract (command names, parameters, exit codes) is unchanged.

### Fixed

- **P0-1** — module failed to import **on Windows**: `Add-Type` in
  `Private/NativeMethods.ps1` received `-UsingNamespace 'System.Runtime.InteropServices'`,
  duplicating the using-directive Add-Type emits itself (CS0105). The `$IsWindows` guard
  hid the defect from Linux CI. Removed the parameter; the native type is now compiled at
  import **on every OS** so cross-platform tests catch compilation regressions.
- **P0-2** — `powershell/Enable-AllTrayIcons.ps1` cast to `[TrayFixComponents]`, a
  module-scoped type invisible to callers ("Unable to find type"). Components are now
  passed as a comma-joined string that the module parameter binds itself. All three
  wrappers declare `SupportsShouldProcess` and forward `-WhatIf`/`-Confirm` (the audited
  invocation `Enable-AllTrayIcons.ps1 ... -WhatIf` previously could not bind at all).
- **P0-3** — `powershell/Disable-AllTrayIcons.ps1 -FromBackup` splatted a non-existent
  `-Force` onto `Restore-TrayIconState`; now passes `Confirm=$false` when `-Force` is
  given (standard ShouldProcess suppression), consistent with the other branch.
- **P1-1** — BAT `/restart` detection used `findstr "/restart"`; findstr parsed the
  leading `/`/`-` as its own switches ("FINDSTR: /t ignored ... Bad command line"),
  never matched, and polluted output. Now literal: `findstr /i /c:"/restart"` (and `-restart`).
- **P1-2** — BAT scan loops treated the root key's own value lines (`Version`,
  `MigrationStatus`, `UIOrderList`) as icons: inflated counts (79 vs 76) and false
  `Failed=3` → exit code 3 on healthy machines. Loops now enumerate only `HKEY_`-prefixed
  subkey lines; BAT numbers match the module's.
- **P2-1** — `.gitignore` rule for the analyzer cache had a leading space and never matched.
- **P2-2** — `docs/CLI-REFERENCE.md` documented a non-existent `-Latest` parameter on the
  wrapper; corrected to the actual `-FromBackup` / `-BackupPath` contract.
- `bat/Launch-TrayIconGuard.bat` now also probes `artifacts\publish\win-x64|win-arm64`
  (where `build.ps1 -Task PublishExe` writes), fixing the README quick-start sequence.

### Added

- Regression meta-tests: native P/Invoke type compiles at import (any OS); wrapper
  scripts contain no module-scoped type references; wrappers declare ShouldProcess;
  BAT retains the literal-findstr and `HKEY_`-filter guards.
- Functional tests snapshot the live icon state before the suite and restore it after
  (tests no longer leave real icons promoted/demoted).
- `LEGACY-NOTICE.md`; the four pre-7.0 files are retained verbatim at the repo root
  (owner decision on removal is still open — see the notice).
- `.agent/` coordination files are untracked by git (kept on disk for LLM handoff, not
  published with the product — audit P2-3).

[7.0.1]: https://github.com/paulmann/windows-show-all-tray-icons/releases/tag/v7.0.1

## [7.0.0] "Phoenix" — 2026-10-12

Complete professional rewrite for **PowerShell 7.6+ (LTS)** and **.NET 10**.
No backward compatibility with 4.x/6.x — old parameters, paths and behavior are gone.

### Added

- **TrayIconGuard GUI (new EXE edition)** — C#/WPF `net10.0-windows`, zero NuGet
  dependencies, compiles in VS Code (`Ctrl+Shift+B`) or `dotnet build`:
  - lives in the notification area (minimize/close-to-tray, tray context menu);
  - **event-driven watcher** (`RegNotifyChangeKeyValue` + debounce, polling fallback)
    that instantly re-promotes icons Windows hides when apps (re)register them;
  - per-icon visibility toggles, live search/filter, activity log tab;
  - settings (auto-promote, auto-restart Explorer with 60 s cooldown, balloons,
    theme, exclusions, start with Windows, start minimized) persisted to
    `%APPDATA%\TrayIconGuard\settings.json`;
  - headless one-shot modes for deployment: `--promote-all`, `--restore-defaults`,
    `--minimized`, `--help` with stable exit codes;
  - dark/light themes following the system, PerMonitorV2 DPI manifest,
    single-instance mutex with activation of the running window;
  - global exception handling that logs and keeps the guard alive.
- **ShowAllTrayIcons PowerShell module (new architecture)** — `Classes/`,
  `Private/`, `Public/`; 12 exported commands:
  `Get-TrayIcon`, `Get-TrayIconState`, `Enable-AllTrayIcons`,
  `Disable-AllTrayIcons`, `Set-TrayIcon`, `Backup-TrayIconState`,
  `Restore-TrayIconState`, `Reset-TrayIconCache`, `Restart-Explorer`,
  `Start-TrayIconWatcher` (`-AsJob`, `-WhatIf` observe mode),
  `Install-TrayIconAutostart`, `Uninstall-TrayIconAutostart`.
- **Per-icon control** for the first time (promote/hide by GUID or exe wildcard).
- **JSON backup/restore** of the full tray state (schema v7), with `-Latest`
  restore and Explorer-restart integration.
- **BAT edition rewritten as a standalone tool** (`bat/Show-AllTrayIcons.bat`):
  enable/disable/status/backup/restore/**watch loop**/restart + interactive menu,
  Windows build gate, logging, stable exit codes — still zero dependencies.
- Exclusion lists everywhere (never promote chosen apps): GUI settings,
  `-ExcludeExecutable` (PS), watcher.
- Autostart management (HKCU Run) for both GUI and headless watcher
  (`-EncodedCommand`, no quoting issues).
- Balloon notifications on auto-promotion (GUI, throttled 10 s).
- `build.ps1` orchestrator: Clean/Analyze/Test/Verify/BuildExe/PublishExe/Package/All;
  single-file self-contained publish support.
- GitHub Actions CI on `windows-latest`: analyzer, BAT hygiene, Pester (full
  functional suite on Windows), build, publish, portable ZIP artifact, release
  automation on tags.
- VS Code workspace integration: `tasks.json` (default build task), `launch.json`
  (GUI + PS debugging), recommended extensions.
- Inno Setup 6 installer script (per-user, autostart task, post-install apply).
- Pester 5 test suite: manifest/help/analyzer/BAT meta-tests (cross-platform)
  + Windows-only functional registry tests (self-skipping elsewhere).
- Documentation set: README, ARCHITECTURE, HOW-IT-WORKS (registry deep dive),
  CLI-REFERENCE, BUILD-AND-RELEASE, TROUBLESHOOTING, CONTRIBUTING, SECURITY.

### Fixed (vs. the pre-7.0 code base)

- `HideSCAVolume/HideSCANetwork/HideSCAPower` are now read/written at their
  **correct** location `HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer`
  (old `.reg` files wrote them under `...\CurrentVersion\Explorer`, where they do nothing).
- `NotifyIconSettings` is addressed at its **correct** location
  `HKCU\Control Panel\NotifyIconSettings` (old `.reg` used a non-existent path under
  `...\Explorer\NotifyIconSettings` with invented subkey names).
- Removed bogus/irrelevant tweaks from the old `.reg` files (resolution-dependent
  `StuckRects3` binary, `TaskbarSi`, Office `UISettings`, WindowsUpdate UX flags).
- The primary mechanism is now `IsPromoted` per icon (what Windows itself uses)
  instead of relying only on the legacy `EnableAutoTray` switch, which modern
  Windows largely ignores. EnableAutoTray is kept strictly as belt-and-suspenders.
- Removed the ~3,000-line monolithic PS1 (fake "Group Policy/AllUsers" claims,
  self-update-from-GitHub code, mixed concerns) in favor of a tested module.

### Changed

- PowerShell floor raised to **7.6** (`#Requires -Version 7.6`), Core edition only.
- BAT output, logging and exit-code contract standardized across all editions
  (0 ok, 1 error, 2 unsupported platform, 3 partial failure).

[7.0.0]: https://github.com/paulmann/windows-show-all-tray-icons/releases/tag/v7.0.0

---

## Pre-7.0 history (upstream, kept for reference)

- 6.x — "Enterprise Edition" monolithic `Enable-AllTrayIcons.ps1` (superseded).
- 4.x — BAT tool around `EnableAutoTray` + `.reg` tweaks (superseded).
- Original concept and repository by **Mikhail Deynekin** (MIT License).
