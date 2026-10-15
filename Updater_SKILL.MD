# Updater_SKILL.MD — how to publish an update so TrayIconGuard can install it

This document is the **contract between the release engineer (human or agent) and the
updater built into `TrayIconGuard.exe`**. Follow it exactly when producing a new bundle;
the program verifies every step cryptographically and refuses anything non-conforming.

## 1. What the program does at update time

1. Reads feed URL: `settings.updates.feedUrl` override, else the built-in default
   `https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/update/stable.json`
   (HTTPS only; plain HTTP is accepted **only** for `127.0.0.1`/`localhost` — local QA).
2. `GET`s the feed JSON (WinHTTP, UA `TrayIconGuard/<ver>`, timeouts 8/10/60 s).
3. Parses fields (schema below), compares `version` with the running version
   (4-component numeric compare, `v` prefix tolerated).
4. If newer and the user confirms: downloads `url` to `%TEMP%\TrayIconGuard-update.exe`.
5. Computes **SHA-256** of the download (BCrypt) and compares with `sha256`
   (lowercase hex, 64 chars). Mismatch → delete file, abort, show error.
6. Applies: renames the running exe to `TrayIconGuard.exe.old` (renaming a running image
   is allowed), moves the new file into place, schedules `.old` for delete-at-reboot
   (`MoveFileEx(MOVEFILE_DELAY_UNTIL_REBOOT)`), relaunches the new exe and exits.
7. Auto-check (opt-in, About → “Check for updates automatically”) runs at most once per
   24 h and only shows a balloon; it never downloads or applies silently.

## 2. Feed file: `update/stable.json` (repository root path `update/`)

```json
{
  "schema": 1,
  "channel": "stable",
  "version": "8.3.0",
  "released": "2026-10-16",
  "minBuild": 15063,
  "url": "https://github.com/<owner>/<repo>/releases/download/v8.3.0/TrayIconGuard.exe",
  "sha256": "<64 hex chars of the EXE>",
  "zipUrl": "https://github.com/<owner>/<repo>/releases/download/v8.3.0/TrayIconGuard-8.3.0-win-x64.zip",
  "zipSha256": "<64 hex chars of the ZIP>",
  "notes": "One paragraph shown in About → update panel."
}
```

Rules:
- `version` MUST be greater than the previously published one; format `MAJOR.MINOR.PATCH`.
- `sha256` MUST match the byte-identical exe offered at `url` (compute on the final,
  stripped, signed-if-you-sign binary: `sha256sum dist/TrayIconGuard.exe`).
- `url` should be a **release asset** (stable, CDN-cached). Raw-git URLs for binaries are
  discouraged (size limits, no caching); the feed file itself lives in git and is served
  through `raw.githubusercontent.com`.
- Channels: `update/stable.json`, `update/beta.json`. Client picks its channel only via
  `feedUrl` override (default = stable).
- Keep old feeds: never rewrite history of a published version; publish a new version.

## 3. Release publication checklist (agent procedure)

1. `./scripts/build.sh` → `dist/TrayIconGuard.exe` (gate: 0 warnings + manifest gate).
2. Bump version in ONE place: `src/core/version.h` (`kVersion`, quad, `TIG_VERSION_A`),
   then mirror: `resources/resources.rc`, `resources/app.manifest`,
   `src/core/installer.cpp` (DisplayVersion), `scripts/package.sh` (VER).
3. `./scripts/package.sh` → `dist/TrayIconGuard-<ver>-win-x64.zip` + `dist/SHA256SUMS`.
4. Write `update/stable.json` with the NEW sha256 values and release notes.
5. Git: commit everything, tag `v<ver>`, push. Create the GitHub release `v<ver>` with
   assets: `TrayIconGuard.exe`, `TrayIconGuard-<ver>-win-x64.zip`, `SHA256SUMS`
   (asset names must match the URLs in the feed).
6. Verify: `TrayIconGuard.exe --check-update` prints `latest=<ver> newer=no` after the
   update; before the update it prints `newer=yes`.
7. Optional E2E on any machine: serve a folder containing `stable.json` (with a loopback
   `url`) + the exe via `python3 -m http.server`, set
   `settings.updates.feedUrl = "http://127.0.0.1:8000/stable.json"`, run `--update-now`.

## 4. Failure matrix

| Symptom | Cause | Action |
|---|---|---|
| `update check failed: HTTP 404` | feed path/branch wrong | check `update/stable.json` exists on the default branch |
| `sha256 mismatch` | exe re-uploaded/re-signed after feed written | republish feed with the hash of the served bytes |
| `only https … allowed` | feed url http on non-loopback | use https |
| `cannot rename running exe` | AV/EDR locking the file | retry; exclude folder |
| update applied but old UI | relaunch blocked by user/session | start manually; `.old` removed at reboot |

## 5. Security properties

- HTTPS-only feeds and downloads (loopback http for QA only).
- Mandatory SHA-256 pinning of the binary; no apply without match.
- No silent auto-apply: user confirmation dialog always precedes download+apply.
- No telemetry: the only requests are the feed GET and the binary GET.
