# Build & Release Guide

## Prerequisites

| Tool | Version | Used for |
|---|---|---|
| [.NET SDK](https://dotnet.microsoft.com/download/dotnet/10.0) | 10.0.x | Building `TrayIconGuard.exe` (`global.json` pins with `rollForward: latestMinor`) |
| [PowerShell](https://github.com/PowerShell/PowerShell) | 7.6+ (LTS) | Module, `build.ps1`, Pester, PSScriptAnalyzer |
| [VS Code](https://code.visualstudio.com) | any | Recommended editor (`.vscode/` preconfigured) |
| [Inno Setup](https://jrsoftware.org/isinfo.php) | 6.x | Optional installer packaging |

VS Code extensions (auto-recommended on open): **C# Dev Kit**, **PowerShell**,
**EditorConfig**.

## Everyday development (VS Code)

- `Ctrl+Shift+B` → **Build TrayIconGuard** (Debug).
- `F5` → *.NET: Launch TrayIconGuard (Windows)* — builds then launches the GUI.
- `F5` → *PowerShell: Enable-AllTrayIcons.ps1* / *Watch-TrayIcons.ps1* / *Module REPL*.
- Terminal tasks: *Analyze PowerShell*, *Run Pester tests*, *Full pipeline (All)*.

Building the Windows target on Linux/macOS works (`EnableWindowsTargeting=true` is set
in `Directory.Build.props`); running the GUI obviously requires Windows.

## build.ps1 tasks

```powershell
./build.ps1                        # All: Analyze → Test → Verify → BuildExe → PublishExe → Package
./build.ps1 -Task Analyze          # PSScriptAnalyzer (0 warnings gate) + BAT hygiene (ASCII/CRLF)
./build.ps1 -Task Test             # Pester 5
./build.ps1 -Task Verify           # parse all PS, import module, assert 12 exports + help
./build.ps1 -Task PublishExe -SelfContained            # runtime-free single EXE
./build.ps1 -Task PublishExe -Runtime win-arm64        # ARM64 (Snapdragon)
./build.ps1 -Task Package          # artifacts\ShowAllTrayIcons-7.0.3-win-x64.zip
./build.ps1 -Task Clean
```

Publish produces a **single-file** EXE
(`PublishSingleFile`, `IncludeNativeLibrariesForSelfExtract`, no PDBs).

**Since v7.0.3 the default is SELF-CONTAINED** (audit R3-2): the EXE carries its own
runtime, so neither an ambient `DOTNET_ROOT` (dev shells love to set it to a bundled
.NET 8) nor a missing Desktop Runtime can block it. Opt out with
`-FrameworkDependent` (~1–2 MB, requires the .NET 10 **Desktop Runtime** on target;
self-contained ≈ 90–150 MB).

> **SDK vs Runtime:** building this repo needs the .NET **SDK** 10 (`global.json`).
> *Running* a framework-dependent EXE needs only the **.NET 10 Desktop Runtime**
> (`Microsoft.WindowsDesktop.App`). The apphost's "install .NET" dialog links to a
> page offering both — the SDK is NOT required to run the app. Note that
> `winsdksetup.exe` is the *Windows* SDK, a different product entirely.

## Manual dotnet commands

```powershell
dotnet build app/TrayIconGuard.sln -c Release
dotnet publish app/src/TrayIconGuard -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o publish
```

## Installer (optional)

1. `./build.ps1 -Task PublishExe -SelfContained` (installer bundles the EXE folder).
2. `& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\TrayIconGuard.iss`
3. Output: `artifacts\installer\TrayIconGuard-7.0.3-setup.exe`
   (per-user install to `%LOCALAPPDATA%\Programs\TrayIconGuard`, no UAC prompt,
   autostart + apply-now tasks, clean uninstall incl. process kill).

## Code signing (production)

Unsigned EXEs trigger SmartScreen. Recommended:

```powershell
# Azure Trusted Signing (2025+) or any Authenticode cert:
signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 `
  /a artifacts\publish\win-x64\TrayIconGuard.exe
# verify:
signtool verify /pa /v artifacts\publish\win-x64\TrayIconGuard.exe
```

For the PowerShell edition, sign the entry scripts and module files
(`Set-AuthenticodeSignature`) and deploy with `AllSigned` execution policy, or ship
via a trusted repository. CI leaves signing out deliberately (secrets belong in your
release pipeline, not in a public workflow).

## CI/CD

`.github/workflows/ci.yml` on `windows-latest`:

1. PowerShell ≥ 7.6 gate, .NET 10 setup
2. `build.ps1 -Task Analyze` (analyzer + BAT hygiene)
3. `build.ps1 -Task Verify` (module contract)
4. `build.ps1 -Task Test` (**full functional Pester on real Windows registry**)
5. Build + Publish (win-x64 single file) + Package
6. Upload ZIP artifact; on `v*` tags attach assets to a GitHub Release

## Release checklist

- [ ] `CHANGELOG.md` updated; version bumped in **all four** places:
      `ShowAllTrayIcons.psd1` (ModuleVersion), `Directory.Build.props` (Version),
      `installer\TrayIconGuard.iss` (MyAppVersion), `README.md` badge
- [ ] `./build.ps1 -Task All` green locally
- [ ] CI green on the release commit
- [ ] `git tag v7.0.3 && git push --tags` (CI attaches the ZIP to the Release)
- [ ] Smoke-test the published EXE on a clean Windows 11 VM:
      start → icons promoted → reboot → watcher re-promotes → settings persist
