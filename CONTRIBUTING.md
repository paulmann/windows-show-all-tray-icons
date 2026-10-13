# Contributing

Thanks for considering a contribution to **windows-show-all-tray-icons v7**!

## Ground rules

- **PowerShell 7.6+ only.** Do not add Windows PowerShell 5.1 compatibility shims —
  v7 dropped them deliberately.
- **C#: zero NuGet dependencies.** The GUI must build offline with only the .NET 10 SDK.
- **Correct registry paths only.** See `docs/HOW-IT-WORKS.md` — especially:
  `NotifyIconSettings` lives under `HKCU\Control Panel`, `HideSCA*` under
  `...\Policies\Explorer`. Never reintroduce the old wrong paths.
- English everywhere: code, comments, docs, UI strings, commit messages.
- BAT files: ASCII only, CRLF line endings (CI enforces both).

## Development loop

```powershell
./build.ps1 -Task Analyze    # PSScriptAnalyzer gate (0 findings) + BAT hygiene
./build.ps1 -Task Test       # Pester 5 (functional tests need Windows)
./build.ps1 -Task Verify     # module contract: parse, import, 12 exports, help
./build.ps1 -Task BuildExe   # dotnet build (0 warnings expected)
```

VS Code: `Ctrl+Shift+B` builds the EXE; `F5` launches it (Windows).

> **Pester note (5 vs 6):** do not pass bare computed expressions positionally to
> `Should` (e.g. `Should -Match [regex]::Escape($s)`) — Pester 6's reworked parser
> mis-binds them. Pre-compute into a variable, wrap in parentheses, or use literal
> checks like `$text.Contains($s) | Should -BeTrue`.

## Adding a module command

1. Create `powershell/modules/ShowAllTrayIcons/Public/<Verb-Noun>.ps1`
   (approved verbs only; full comment-based help with `.EXAMPLE`).
2. Add the name to `FunctionsToExport` in `ShowAllTrayIcons.psd1`.
3. Registry paths/constants belong in `Classes/TrayPolicy.ps1` — no literals in commands.
4. Add Pester coverage in `tests/` (meta-tests must pass on any OS; guard functional
   tests with `-Skip:(-not $IsWindows)`).
5. Update `docs/CLI-REFERENCE.md` and `README.md` if user-facing.

## Changing the GUI

- Keep MVVM: no business logic in `Views/*`; services must not reference WPF types
  (exception: `ThemeService`).
- All UI mutations from background threads go through `Dispatcher.BeginInvoke`.
- New settings: add to `AppSettings` (they serialize automatically), expose a proxy
  property in `MainViewModel`, add the control to the Settings tab, document the key.

## Pull request checklist

- [ ] `./build.ps1 -Task All` passes locally
- [ ] No new analyzer findings / build warnings
- [ ] Tests added or updated; CHANGELOG entry under *Unreleased*
- [ ] Docs touched if behavior changed (README, CLI-REFERENCE, HOW-IT-WORKS)
- [ ] One logical change per PR; squash-merge preferred

## Versioning

SemVer. Breaking CLI/registry-format changes require a major bump and a CHANGELOG
migration note. Version lives in four places (see BUILD-AND-RELEASE.md → Release
checklist) — bump them together.

## Conduct

Be pragmatic and kind. This is a small utility with enterprise users; correctness and
reversibility beat cleverness.
