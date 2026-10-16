## What does this change?

<!-- One short paragraph: the problem, the approach, the user-visible effect. -->

Fixes #

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Documentation / wiki
- [ ] Localization (i18n)
- [ ] Build, CI or release tooling

## Checklist

- [ ] `./scripts/build.sh` finishes with **zero warnings** and the manifest + OS-DLL gates pass.
- [ ] `cppcheck --enable=warning,performance,portability src` reports no new findings.
- [ ] No new runtime dependencies — the import table still lists Windows system DLLs only.
- [ ] Registry access stays `HKCU`-only for a standard user (machine scope only through the elevated `--install-machine` path).
- [ ] Smoke-tested: `TrayIconGuard.exe --status --json` (plus a GUI run for UI changes).
- [ ] `CHANGELOG.md` updated; `docs/` and the README translations updated if behaviour changed.
- [ ] No published release tag or `update/stable.json` was rewritten (the feed is monotonic).

## Screenshots or logs

<!-- Before/after screenshots of the affected page, or the relevant log lines. -->
