# winget package — submission kit

These are the **Windows Package Manager (winget)** manifests for TrayIconGuard, already in the
directory layout `microsoft/winget-pkgs` expects, so submitting a new version is a copy-paste.

```
packaging/winget/manifests/m/MikhailDeynekin/TrayIconGuard/8.6.0/
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
[`update/stable.json`](../../../../update/stable.json), i.e. Windows 10 1703+; the app degrades
gracefully on builds without the `NotifyIconSettings` store).

## Validate locally (Windows, winget 1.24+)

```powershell
winget validate --manifest packaging\winget\manifests\m\MikhailDeynekin\TrayIconGuard\8.6.0
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
winget install --manifest packaging\winget\manifests\m\MikhailDeynekin\TrayIconGuard\8.6.0
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
  --prtitle "New package: MikhailDeynekin.TrayIconGuard version 8.6.0" `
  packaging\winget\manifests\m\MikhailDeynekin\TrayIconGuard\8.6.0
```

`wingetcreate` needs a **classic** personal access token with the `public_repo` scope
(fine-grained tokens are not supported); prefer the `WINGET_CREATE_GITHUB_TOKEN` environment
variable over `--token`.

## Checklist for the next release

1. Bump `PackageVersion` and `ManifestVersion` headers in all three files.
2. Take the new hashes **from the published release**
   ([`update/stable.json`](../../../../update/stable.json) is already pinned to the served bytes,
   so its `sha256` is authoritative).
3. Set `ReleaseDate` to the release's `published_at` date and update `LicenseUrl`
   (`…/blob/v<version>/LICENSE`) and `ReleaseNotesUrl` to the new tag.
4. Run `winget validate --manifest <dir>` and require a clean exit.
