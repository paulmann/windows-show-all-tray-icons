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

## Option B — native Windows, MinGW-w64

```powershell
cmake -S . -B build -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release
cmake --build build -j8
copy build\TrayIconGuard.exe dist\
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
