# Build guide — TrayIconGuard v8

## Option A — cross-compile from Linux/macOS (recommended, what CI uses)

```bash
sudo apt install g++-mingw-w64-x86-64 cmake make      # Debian/Ubuntu
./scripts/build.sh                                     # -> dist/TrayIconGuard.exe
./scripts/package.sh                                   # -> dist/TrayIconGuard-8.0.0-win-x64.zip + SHA256SUMS
```

`scripts/build.sh` runs CMake with `cmake/mingw-w64-x86_64.cmake` and links
`-static -static-libgcc -static-libstdc++ -Wl,--gc-sections -s -municode`.
The result imports **only** Windows system DLLs.

## Option B — native Windows, MinGW-w64 (verified with winlibs GCC 16.2 + CMake 4.4.4)

```powershell
winget install BrechtSanders.WinLibs.POSIX.MSVCRT        # UCRT variant works too
winget install Kitware.CMake                              # or a portable CMake zip

$mingw = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Directory |
          Where-Object Name -like 'BrechtSanders.WinLibs.POSIX.MSVCRT*' | Select-Object -First 1).FullName +
         '\mingw64\bin'
$env:PATH = "$mingw;$env:PATH"      # windres needs `gcc` on PATH: it preprocesses resources.rc
cmake -S . -B build-win -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release `
      -DCMAKE_MAKE_PROGRAM="$mingw\mingw32-make.exe" `
      -DCMAKE_CXX_COMPILER="$mingw\g++.exe" -DCMAKE_RC_COMPILER="$mingw\windres.exe"
cmake --build build-win -j8                              # -> dist/TrayIconGuard.exe
```

**Pitfall (winlibs):** that toolchain ships
`mingw64/x86_64-w64-mingw32/lib/default-manifest.o`, which GCC's link spec picks up
automatically. It embeds a *second* `RT_MANIFEST` resource and makes `ld` print
`.rsrc merge failure: multiple non-default manifests`. Rename it to
`default-manifest.o.disabled` so only the project's canonical manifest is embedded (the
Debian/CI toolchain has no such file). Check the result: `objdump -p dist\TrayIconGuard.exe`
must list system DLLs only, `--version` must report the version from `src/core/version.h`, and
`g++ -Wall -Wextra` must stay at zero warnings.

Without CMake, this is the exact flag set `CMakeLists.txt` applies to GNU toolchains:

```powershell
$src = Get-ChildItem -Recurse src -Filter *.cpp | ForEach-Object FullName
& "$mingw\g++.exe" -std=c++17 -O2 -municode -DUNICODE -D_UNICODE -DWIN32_LEAN_AND_MEAN `
  -DNOMINMAX -DWINVER=0x0A00 -D_WIN32_WINNT=0x0A00 -DNTDDI_VERSION=0x0A000006 `
  -Wall -Wextra -Wno-unused-parameter -ffunction-sections -fdata-sections -Isrc `
  $src resources/resources.rc -o dist/TrayIconGuard.exe `
  -static -static-libgcc -static-libstdc++ -Wl,--gc-sections -s `
  -lgdiplus -lcomctl32 -lcomdlg32 -ldwmapi -luxtheme -lshlwapi -lversion -lwinhttp `
  -lole32 -loleaut32 -lshell32 -ladvapi32 -lgdi32 -luser32 -lkernel32 -lbcrypt
```

Always smoke-test the **redirected** CLI as well — the 8.6.0 regression (output discarded when
stdout was a pipe or file) is invisible in an interactive console, and wine does not reproduce it:

```powershell
.\dist\TrayIconGuard.exe --status --json > $env:TEMP\status.json
(Get-Content $env:TEMP\status.json -Raw | ConvertFrom-Json).total   # must not be empty
.\dist\TrayIconGuard.exe --help > $env:TEMP\help.txt                 # must not be empty
.\dist\TrayIconGuard.exe --bogus; $LASTEXITCODE                      # 1 + "error: unknown argument"
```

## Option C — native Windows, MSVC (VS 2022)

The code is compiler-agnostic C++17; add the sources to a CMake project:

```powershell
cmake -S . -B build-msvc -G "Visual Studio 17 2022" -A x64
cmake --build build-msvc --config Release
```

MSVC note: replace the GNU-specific link options in `CMakeLists.txt` with
`/MT /OPT:REF` equivalents if you prefer static CRT (the provided flags are guarded for
GNU; MSVC users should drop `-static … -municode` and add `/ENTRY:wWinMainCRTStartup`).

## VS Code

- `Ctrl+Shift+B` → task “build (mingw cross)” or “build (windows mingw)” auto-selected per OS.
- F5 → `cppvsdbg` launch of the GUI on Windows.
- Recommended extensions: `ms-vscode.cpptools`, `ms-vscode.cmake-tools`.

## Regenerating the icon / banner assets

```bash
python3 scripts/make_icon.py     # resources/icon.ico (16..256), icon_256/512.png, sheet
```

The `.ico` contains BMP-DIB entries for 16–128 px (maximum shell compatibility) and a PNG
entry for 256 px. Size-specific detail: solid shield ≤32 px, shield + three dots ≥40 px.

## Compile-time contract

- Defines: `UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX WINVER=0x0A00 _WIN32_WINNT=0x0A00`.
- Warnings: `-Wall -Wextra` must stay at **zero** (QA gate).
- mingw threads model may be `win32`: the code intentionally uses Win32 threads
  (`CreateThread`, SRWLOCK) and never `<thread>`/`<mutex>`.
