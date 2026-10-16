# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 8.6.x | ✅ |
| 8.5.x and older | ❌ — please update from the [latest release](https://github.com/paulmann/windows-show-all-tray-icons/releases/latest) |

## Reporting a vulnerability

Please report privately, not in a public issue:

- **Preferred:** GitHub → *Security* → *Advisories* → **Report a vulnerability**
  (<https://github.com/paulmann/windows-show-all-tray-icons/security/advisories/new>)
- **E-mail:** <icons@Deynekin.com> with a subject starting `TrayIconGuard security`

Please include the version (`TrayIconGuard.exe --version`), your Windows build
(`--status --json`), the steps to reproduce, and — if you have one — a proof-of-concept.
We aim to acknowledge within **72 hours** and to ship a fix in the next patch release.
Credit is given in the release notes unless you prefer to stay anonymous.

## Attack surface (what the program actually touches)

- **Registry:** writes per-icon visibility in
  `HKCU\Control Panel\NotifyIconSettings\{id}` (`IsPromoted`) plus, opt-in, the legacy
  `HKCU\…\Explorer` switches. Machine-wide keys are only written by the explicit,
  UAC-elevated `--install-machine` path.
- **Files:** `%APPDATA%\TrayIconGuard\settings.json`, rotating logs in
  `%LOCALAPPDATA%\TrayIconGuard\logs`, snapshots in `…\backups`. Nothing else.
- **Network:** only the update feed and the release asset it points to — HTTPS only
  (plain HTTP is accepted **solely** for `127.0.0.1`/`localhost`, for local QA). The
  downloaded binary is verified against the feed's SHA-256 before it is applied.
- **No telemetry, no analytics, no auto-install.** The automatic update check is opt-in,
  runs at most once per 24 h and only shows a balloon notification.

## Verifying a download yourself

```powershell
# From the release page: SHA256SUMS / the feed's sha256 field
Get-FileHash .\TrayIconGuard.exe -Algorithm SHA256
# compare with https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/update/stable.json
```

Always take binaries from this repository's release page. Mirrors and "repack" sites are out of
scope of this policy.

## Out of scope

- SmartScreen/Defender warnings for an unsigned binary (see
  [`docs/SMARTSCREEN.md`](docs/SMARTSCREEN.md)) — normal for a new publisher, not a vulnerability.
- An attacker who already runs code as you, or who has physical access to the machine.
- Third-party forks, repacks or mirrors of TrayIconGuard.
