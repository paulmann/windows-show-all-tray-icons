# Troubleshooting — TrayIconGuard v8

## “Not supported on this Windows build” on Dashboard
The per-icon store `HKCU\Control Panel\NotifyIconSettings` exists since Windows 10 1703
(build 15063). Older builds: only the legacy `EnableAutoTray=0` belt is available.

## Icons hid again after an app update
Expected Windows behavior — the guard re-promotes within ~0.5 s. If it does not:
1. Is the guard running? (status bar / tray dot green). Resume from Dashboard or tray menu.
2. Check Activity page for errors; export the log for reports.
3. Some Windows 11 24H2+ builds cache the tray layout: enable *Auto-restart Explorer*
   (Guard page) or press *Restart Explorer* once.

## “The application has failed to start because its side-by-side configuration is incorrect”
Fixed for official builds in **8.2.1** (the embedded manifest now uses the canonical form;
earlier 8.2.0/8.1.0/8.0.0 manifests could be rejected by strict Windows 11 SxS validation).
If you still see it:
1. Make sure you run **TrayIconGuard.exe 8.2.1+** (`--version` prints it).
2. Do not keep the app in a directory whose name ends with `.exe` (e.g. `v8.exe\dist\`) —
   rename the parent folder (e.g. `v8\dist\`); such names confuse activation-context
   probing on some Windows 11 builds.
3. Unpack the zip with a standard tool (Explorer, 7-Zip); some exotic unpackers truncate
   PE resources.
4. If it persists, capture `sxstrace.exe -logfile:sxs.log` output and open an issue.

## SmartScreen / “unknown publisher”
The binary is not code-signed (community project). Right-click → Properties → Unblock,
or sign it yourself: `signtool sign /fd sha256 /a TrayIconGuard.exe` (see CI notes).
SHA-256 of official releases is published in `SHA256SUMS`.

## Antivirus false positives
Static-linked mingw binaries occasionally trigger generic heuristics. The app writes only to
`HKCU\Control Panel\NotifyIconSettings`, `HKCU\...\Run` (opt-in) and its own AppData
folders; review the source or build it yourself (`scripts/build.sh`).

## Nothing happens on `--promote-all` (exit 2)
Store missing (pre-1703) or the `Control Panel` hive is redirected (rare corporate
environments). Run `--status --json` and check `storeSupported`.

## Window does not appear, only tray icon
By design: close button minimizes to tray. Double-click the tray icon, or hold `Shift`
while closing to really exit, or disable *close-to-tray* via settings.json
(`"behavior": {"closeToTray": false}`).

## Dark title bar on Windows 10
`DWMWA_USE_IMMERSIVE_DARK_MODE` is supported from Windows 10 1809; earlier builds keep the
light frame while the client area follows the app theme.

## Glyphs show as boxes (□) in screenshots from wine/VMs
The nav/icons font is *Segoe Fluent Icons* (Win11) with fallback *Segoe MDL2 Assets*
(Win10 1607+). Wine and stripped-down VMs lack both; real Windows always has one.

## Logs & diagnostics
- Log: `%LOCALAPPDATA%\TrayIconGuard\logs\TrayIconGuard-yyyyMMdd.log` (14-day rotation)
- Settings: `%APPDATA%\TrayIconGuard\settings.json` (safe to hand-edit; unknown keys ignored)
- About → **Copy diagnostics** puts a ready-to-paste report in the clipboard.

## Reset everything
Exit the app, delete both AppData folders, run `TrayIconGuard.exe --restore-defaults`.
