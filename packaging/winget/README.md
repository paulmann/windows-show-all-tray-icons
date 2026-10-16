# winget package — submission kit

These are the **Windows Package Manager (winget)** manifests for TrayIconGuard, already in the
directory layout `microsoft/winget-pkgs` expects, so submitting a new version is a copy-paste.

```
packaging/winget/manifests/m/MikhailDeynekin/TrayIconGuard/8.6.3/
├── MikhailDeynekin.TrayIconGuard.yaml                  # version file
├── MikhailDeynekin.TrayIconGuard.locale.en-US.yaml     # defaultLocale file
└── MikhailDeynekin.TrayIconGuard.installer.yaml        # installer file
```

Everything is schema **1.12.0** (the version named by the winget-pkgs PR template; 1.10.0 is
still accepted, 1.6.0 and older are deprecated).

## Which installer route, and why

The manifests use the **plain `.exe` portable route**:

| Route | Manifest shape | Notes |
|---|---|---|
| **`.exe` portable (used here)** | `InstallerType: portable` + `Commands` | Simplest and lowest-risk: nothing is nested, so the archive rules (`Portable-Archive`, a *blocking* label in the winget validation guide) do not apply |
| zip + nested portable (alternative) | `InstallerType: zip` + `NestedInstallerType: portable` + `NestedInstallerFiles` | Legal and common, but the zip wraps everything in a `TrayIconGuard/` folder, so `RelativeFilePath` must be `TrayIconGuard\TrayIconGuard.exe` — a wrong path **passes `winget validate`** and only fails at install time with `NESTEDINSTALLER_NOT_FOUND` |

`Scope` is deliberately **absent**: winget reports “Scope is not supported for InstallerType
portable” as a warning, and a warning makes `winget validate` exit non-zero
(`0x8A150028`), which breaks CI gating.

`MinimumOSVersion: 10.0.15063.0` matches the project's own claim (the `minBuild` field of
[`update/stable.json`](../../update/stable.json), i.e. Windows 10 1703+; the app degrades
gracefully on builds without the `NotifyIconSettings` store).

## Validate locally (Windows, winget 1.24+)

```powershell
winget validate --manifest packaging\winget\manifests\m\MikhailDeynekin\TrayIconGuard\8.6.3
# expect: "Manifest validation succeeded." and exit code 0
```

- `--manifest` must point at the **directory**; a single file fails with
  “The multi file manifest is incomplete”.
- `--nowarn` turns warnings into a success exit code for CI use.
- `winget hash <file>` prints the SHA-256 of an installer (lowercase), the value
  `InstallerSha256` expects.

End-to-end install test (needs an **elevated** shell once, then it persists):

```powershell
winget settings --enable LocalManifestFiles
winget install --manifest packaging\winget\manifests\m\MikhailDeynekin\TrayIconGuard\8.6.3
winget list --id MikhailDeynekin.TrayIconGuard
winget uninstall --id MikhailDeynekin.TrayIconGuard
```

A portable install only extracts the exe and links `trayiconguard` into the WinGet Links folder;
it does not launch the GUI and it does not touch the registry.

## Submitting an update (manual route)

1. Fork `microsoft/winget-pkgs` and clone your fork shallowly.
2. Copy this `manifests/m/MikhailDeynekin/TrayIconGuard/<version>/` tree into the fork at the same
   path (`manifests/m/MikhailDeynekin/TrayIconGuard/<version>/`).
3. Commit on a branch, push, open a PR against `microsoft/winget-pkgs` — **one package version per
   PR**, and keep documentation/tooling changes in a separate PR. The CLA must be signed once
   (label `Needs-CLA`).
4. The automated validation pipeline plus a moderator review run on the PR.

Automated alternative (`wingetcreate`), which forks and opens the PR itself:

```powershell
wingetcreate.exe submit `
  --prtitle "New package: MikhailDeynekin.TrayIconGuard version 8.6.3" `
  packaging\winget\manifests\m\MikhailDeynekin\TrayIconGuard\8.6.3
```

`wingetcreate` needs a **classic** personal access token with the `public_repo` scope
(fine-grained tokens are not supported); prefer the `WINGET_CREATE_GITHUB_TOKEN` environment
variable over `--token`.

## Checklist for the next release

1. Bump `PackageVersion` and `ManifestVersion` headers in all three files.
2. Take the new hashes **from the published release**
   ([`update/stable.json`](../../update/stable.json) is already pinned to the served bytes,
   so its `sha256` is authoritative).
3. Set `ReleaseDate` to the release's `published_at` date and update `LicenseUrl`
   (`…/blob/v<version>/LICENSE`) and `ReleaseNotesUrl` to the new tag.
4. Run `winget validate --manifest <dir>` and require a clean exit.

## Publication status — 2026-10-16

| Step | State |
|---|---|
| Local validation | ✅ `winget validate --manifest <dir>` → “Manifest validation succeeded.”, exit code 0 (winget v1.29.380), run against these 8.6.3 manifests |
| Fork | ✅ [`paulmann/winget-pkgs`](https://github.com/paulmann/winget-pkgs) |
| Branch | ✅ pushed: `MikhailDeynekin.TrayIconGuard-8.6.3` with `manifests/m/MikhailDeynekin/TrayIconGuard/8.6.3/`. The superseded branches (8.6.0, 8.6.1, 8.6.2) were deleted — its installer URL died together with the removed release. |
| Pull request | ⛔ **needs a human click** — the automation token is a *fine-grained* PAT and GitHub refuses PR creation in `microsoft/winget-pkgs` (`Resource not accessible by personal access token`, HTTP 403). `wingetcreate` has the same limitation: it requires a **classic** PAT with the `public_repo` scope. |

**Open the PR here (one click, prefilled):**

<https://github.com/paulmann/winget-pkgs/pull/new/MikhailDeynekin.TrayIconGuard-8.6.3>

Title:

```text
New package: MikhailDeynekin.TrayIconGuard version 8.6.3
```

Body to paste (the CLA box is yours to tick after signing):

```markdown
## 📖 Description

Adds the **TrayIconGuard 8.6.3** package (publisher: Mikhail Deynekin).

TrayIconGuard keeps every notification-area (system tray) icon visible on Windows 10/11: it
writes the same `HKCU\Control Panel\NotifyIconSettings` values the Windows Settings toggle
uses, and an event-driven `RegNotifyChangeKeyValue` watcher re-promotes icons that Explorer
hides again. It is a single native Win32 C++ executable with **zero runtime dependencies**
(no .NET, no VC++ redistributable), per-user, no admin.

Manifest notes:

- `InstallerType: portable` on the plain `.exe` release asset, `Commands: trayiconguard`
- `InstallerSha256` is the hash of the released asset; the project's own update feed is pinned
  to the same bytes by CI
- `MinimumOSVersion: 10.0.15063.0` matches the project's declared `minBuild` (Windows 10 1703+)
- `Scope` is intentionally absent: it is not supported for `portable` and makes
  `winget validate` exit non-zero
- `LicenseUrl` points at the version tag; the project uses PolyForm Noncommercial License 1.0.0

## ✅ Checklist

- [ ] Signed the Contributor License Agreement — the author will sign in the CLA step of this PR
- [ ] Linked to an issue (if applicable) — n/a, new package

## 📦 Manifest Checklist

- [x] Checked that there aren't other open pull requests for the same manifest update/change
- [x] This PR only modifies one (1) manifest
- [x] Validated manifest locally with `winget validate --manifest <path>` → "Manifest validation
  succeeded.", exit code 0 (winget v1.29.380)
- [ ] Tested manifest locally with `winget install --manifest <path>` — requires an elevated
  shell (LocalManifestFiles), which the submitting environment does not have
- [x] Manifest conforms to the 1.12 schema

Project: https://github.com/paulmann/windows-show-all-tray-icons
Docs: https://paulmann.github.io/windows-show-all-tray-icons/
Release: https://github.com/paulmann/windows-show-all-tray-icons/releases/tag/v8.6.3
```

After the CLA is signed and the PR is merged, add an install row to the READMEs:

```text
winget install MikhailDeynekin.TrayIconGuard
```