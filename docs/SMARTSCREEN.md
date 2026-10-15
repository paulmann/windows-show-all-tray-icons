# How to stop Windows from complaining about TrayIconGuard at startup

Symptoms: SmartScreen “Windows protected your PC” on first launch, or an
“unknown publisher” warning when the autostart entry runs at logon.

## Why it happens
The community build is **not code-signed**, and files downloaded from the Internet carry a
Mark-of-the-Web (MOTW, `Zone.Identifier` ADS). SmartScreen keys on both.

## Fixes, in order of preference

1. **Use the embedded installer (recommended).**
   Run the downloaded exe once, choose *Install* in the first-run wizard. The installer
   copies the exe with `CopyFileW`, which does **not** copy the Zone.Identifier ADS — the
   installed copy in `%LOCALAPPDATA%\Programs\TrayIconGuard` is MOTW-free, so autostart and
   later launches run without SmartScreen prompts.
2. **Unblock the portable copy** (if you run it from Downloads etc.):
   - Explorer: right-click the exe → *Properties* → tick *Unblock* → OK; or
   - PowerShell: `Unblock-File .\TrayIconGuard.exe`
   Then (re)create autostart from the unblocked location (`--install-autostart`).
3. **Code-sign the binary (orgs / mass deployment).**
   ```powershell
   signtool sign /fd SHA256 /tr http://timestamp.sectigo.com /td SHA256 ^
     /f cert.pfx /p <pwd> dist\TrayIconGuard.exe
   ```
   An OV/EV certificate removes SmartScreen prompts entirely (EV immediately, OV after
   reputation builds). CI notes: sign after `package.sh`, then re-hash and republish the
   feed (`Updater_SKILL.MD` §3 — sha256 must match the signed bytes).
4. **Defender/SmartScreen exclusion (last resort, per-machine):**
   Windows Security → App & Browser control → Exclusions → add the install folder.
   Not recommended for general users.

## Autostart-specific notes
- The Run-key entry points at the **installed** path; keep the installed copy (fix #1) and
  no prompt appears at logon.
- If you moved the exe manually, re-run `TrayIconGuard.exe --install-autostart` from its new
  (unblocked) location so the Run value and the MOTW-free copy agree.
- Group Policy “SmartScreen for apps” in managed environments can block unsigned binaries
  regardless of MOTW; there the only answer is code signing (#3) or an allow-list policy.
