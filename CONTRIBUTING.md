# Contributing to TrayIconGuard

Thanks for taking the time to help. TrayIconGuard ships as a **single dependency-free Windows
executable**, so a handful of rules are non-negotiable — they are what makes the tool
trustworthy enough to run on other people's machines.

## Ground rules

1. **Zero runtime dependencies.** The import table may only contain Windows system DLLs
   (`ADVAPI32 BCRYPT COMCTL32 COMDLG32 DWMAPI GDI32 GDIPLUS KERNEL32 MSVCRT OLE32 OLEAUT32
   SHELL32 SHLWAPI USER32 VERSION WINHTTP`). CI enforces this with `objdump`.
2. **HKCU only, standard user.** Never write machine-wide hives except in the explicit
   elevated `--install-machine` code path, and never touch the do-not-touch keys
   (`StuckRects3`, …) listed in [`docs/HOW-IT-WORKS.md`](docs/HOW-IT-WORKS.md).
   No telemetry, no phone-home, no silent updates.
3. **Warning-free builds.** GCC `-Wall -Wextra` and MSVC `/W4 /permissive-` must stay clean;
   CI fails the build on any `warning:` line.
4. **The publication contract.** Releases and the update feed follow
   [`Updater_SKILL.MD`](Updater_SKILL.MD): the feed's `sha256` is always pinned from the bytes
   the GitHub release actually serves — never from a local build.
5. **Docs travel with code.** A user-visible change needs a [`CHANGELOG.md`](CHANGELOG.md)
   entry and, when behaviour changes, an update under [`docs/`](docs/).

## Development setup

```bash
# Cross-build on Linux/macOS (this is what CI uses)
sudo apt install g++-mingw-w64-x86-64 cmake make
./scripts/build.sh          # build + gates: warnings, manifest check, OS-DLL-only audit
./scripts/package.sh        # dist/TrayIconGuard-<ver>-win-x64.zip + SHA256SUMS

# Native MSVC on Windows
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

Optional local checks:

```bash
cppcheck --enable=warning,performance,portability --inline-suppr src
wine dist/TrayIconGuard.exe --status      # CLI smoke run
wine dist/TrayIconGuard.exe --ui-test     # renders every page and writes shots/uitest-*.png
```

## Translations

UI strings live in `src/ui/lang/`: ids in `strings.h`, English table in `strings.cpp`, one
sparse pack per locale (`lang_<code>.cpp`). Missing ids fall back to English **per string**,
so a partial pack is genuinely useful. See [`docs/I18N.md`](docs/I18N.md) and the language
switcher in **Appearance → Language**.

## Pull requests

- One logical change per PR; rebase on `main` instead of merging it in.
- Imperative, conventional commit subjects (`fix:`, `feat:`, `docs:`, `i18n:`, `ci:`).
- Make sure `Cross-build` and `Native build (windows, MSVC)` are green.
- Never rewrite a published tag or feed file — ship a new version instead.
- Update `README.md` and its translations when you change a documented behaviour.

Security problems do **not** belong in a public issue: follow [`SECURITY.md`](SECURITY.md).

## Code of Conduct

Participation in this project is covered by our
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).
