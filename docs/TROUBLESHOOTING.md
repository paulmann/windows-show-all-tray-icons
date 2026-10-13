# Troubleshooting & FAQ

## Symptoms

### Icons are hidden again hours/days after running the tool
Expected Windows behavior: Explorer resets `IsPromoted` when apps re-register icons
(updates, crashes, reboots). Run a **guard**: `TrayIconGuard.exe` (GUI),
`Start-TrayIconWatcher -AsJob` (PowerShell) or `Show-AllTrayIcons.bat watch`.
Enable *Start with Windows* so protection survives reboots.

### Changes only apply after a reboot / Explorer restart
Most systems apply `IsPromoted` live. When they don't (observed on some Windows 11
24H2+ builds and during fast-user switching):
`Enable-AllTrayIcons -RestartExplorer`, the GUI **Restart Explorer** button, or
`Show-AllTrayIcons.bat enable /restart`. The taskbar flashes for ~2 s — that's normal.

### The taskbar didn't come back after restarting Explorer
Run `Restart-Explorer` again (it starts the shell manually if auto-restart failed),
or press `Ctrl+Shift+Esc` → Task Manager → *Run new task* → `explorer.exe`.

### One app's icon never appears at all
The app itself may not register a tray icon (check the app's own settings), or it
registers only while showing notifications. `Get-TrayIcon | Where-Object DisplayName -like '*app*'`
shows whether Windows knows the icon at all. TrayIconGuard can only promote icons
that exist in `NotifyIconSettings`.

### Phantom icons of uninstalled apps
`Reset-TrayIconCache` (PS) deletes the legacy `TrayNotify` caches and restarts
Explorer. On Windows 11 the entries usually clear once the owning app is gone;
if a stale subkey remains, remove it:
`Get-TrayIcon -Name '*oldapp*'` → note Id →
`Remove-Item "HKCU:\Control Panel\NotifyIconSettings\<Id>" -Recurse` (advanced users).

### `Get-TrayIcon` returns nothing
No app has registered a notification icon for this user yet (fresh profile / Server
Core-ish sessions). The store fills as apps start; the watcher will pick them up.

### GUI: "Another instance is already running" but I see no window
It's minimized to the notification area — click the overflow chevron `^` and
double-click the TrayIconGuard icon. If it's truly orphaned:
`Stop-Process -Name TrayIconGuard -Force`.

## Platform & install

### "PowerShell 7.6+ required" when running the scripts
Install: `winget install --id Microsoft.PowerShell` (or the MSI from GitHub releases).
Windows PowerShell 5.1 is intentionally unsupported in v7.

### BAT: "Windows build ... is too old"
`NotifyIconSettings` requires Windows 10 1703 (build 15063)+. Older builds have no
supported per-icon store; v7 refuses rather than corrupting legacy caches.

### SmartScreen warns about TrayIconGuard.exe
The open-source build is unsigned. Click *More info → Run anyway*, or build/sign it
yourself (docs/BUILD-AND-RELEASE.md → Code signing).

### GUI demands ".NET must be installed" although .NET 10 IS installed
The EXE's apphost resolves the runtime through `DOTNET_ROOT` **first** when that
environment variable is set. Developer shells and bundled tools (build wrappers,
IDE-side toolchains) often export `DOTNET_ROOT` pointing at their own embedded
.NET (frequently 8.x without `Microsoft.WindowsDesktop.App`) — the apphost then
never looks into `C:\Program Files\dotnet` and shows the install dialog even
though the correct runtime exists.

Diagnose:

```bat
echo %DOTNET_ROOT%
dotnet --list-runtimes
```

Fixes (any one):
- Use the **self-contained** build (`build.ps1 -Task PublishExe` — default since
  v7.0.3): it carries its own runtime and ignores all of the above.
- In that shell: `set "DOTNET_ROOT="` before launching (our
  `bat\Launch-TrayIconGuard.bat` already does this), or
- Point it at the real install: `set "DOTNET_ROOT=C:\Program Files\dotnet"`
  (`DOTNET_ROOT_X64` also works and takes precedence for x64).

Also note: the app needs the .NET 10 **Desktop Runtime** only — never the SDK.
The download page opened by the dialog offers both; installing the SDK "works"
merely because it contains the runtime.

### Antivirus flags registry writes
The tool only writes `HKCU\Control Panel\NotifyIconSettings\*\IsPromoted` (DWORD),
the HKCU Run value (autostart) and reads only elsewhere. Whitelist if your AV is
overzealous; there is no network activity, no telemetry, no persistence beyond the
Run key you control.

## Behavior details

### Does it hide the chevron (overflow flyout) itself?
No — the overflow flyout remains (Windows 11 has no supported "always show all"
shell switch), but it stays **empty** because every icon is promoted to the taskbar.
New icons are promoted by the guard within ~1 s of registration.

### Taskbar space: too many icons on small screens?
Use exclusions (`Settings → Exclusions` in GUI, `-ExcludeExecutable` in PS) for apps
you don't need to see. Promoted icons that don't fit are clipped by Windows itself —
promote selectively on 1366×768-class displays.

### Multi-user / RDP / kiosk
Everything is per-user (HKCU). For fleets: deploy the Run-key autostart
(`Install-TrayIconAutostart`) via GPP registry item / Intune / logon script **targeting
the user hive** — there is no machine-wide equivalent, and v7 deliberately doesn't
pretend otherwise (the old "AllUsers/Group Policy" mode was removed as misleading).

### How do I fully uninstall?
1. GUI: Settings → untick *Start with Windows*; tray menu → Exit.
   PS: `Uninstall-TrayIconAutostart`.
2. Restore defaults: `Disable-AllTrayIcons` or `TrayIconGuard.exe --restore-defaults`
   or `Restore-TrayIconState -Latest` (from your backup).
3. Delete the folder you extracted/built into, plus (optional)
   `%APPDATA%\TrayIconGuard`, `%LOCALAPPDATA%\TrayIconGuard`,
   `%LOCALAPPDATA%\ShowAllTrayIcons`.

## Where are the logs?

| Edition | Location |
|---|---|
| GUI | `%LOCALAPPDATA%\TrayIconGuard\logs\TrayIconGuard-yyyyMMdd.log` (Activity log tab mirrors it) |
| PowerShell | `%LOCALAPPDATA%\ShowAllTrayIcons\logs\ShowAllTrayIcons-yyyyMMdd.log` |
| BAT | `%LOCALAPPDATA%\ShowAllTrayIcons\logs\bat.log` |

Still stuck? Open an issue with: Windows build (`winver`), edition + version,
the relevant log tail, and `Get-TrayIconState | ConvertTo-Json` output.
