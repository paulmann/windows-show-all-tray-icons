# A6-build — task brief
## Scope
BUILD+PACKAGING+CI. CMakeLists.txt (mingw toolchain cmake/mingw-w64-x86_64.cmake), -O2 -Wall -Wextra -ffunction-sections -Wl,--gc-sections -static-libgcc -static-libstdc++ -static -municode -s; libs gdiplus comctl32 dwmapi uxtheme shlwapi version winhttp ole32 shell32 advapi32 gdi32 user32 kernel32; resources/resources.rc (ICON, VERSIONINFO 8.0.0.0, RT_MANIFEST: PerMonitorV2+comctl32v6+supportedOS+UTF8 ACP+longPath); scripts/build.sh, package.sh (zip+SHA256SUMS), installer/install.ps1+uninstall.ps1+install.bat (copy LOCALAPPDATA\Programs, shortcuts, uninstall reg key), installer/TrayIconGuard.iss (Inno, optional), .github/workflows/ci.yml (ubuntu mingw cross-build + windows MSVC build + artifacts), .vscode/{tasks,launch,settings,extensions}.json.
## Rules
Read "/tmp/arena/tenants/2ac01412-00e0-452b-8d75-2c08c7a303a2/sessions/37021a58-8685-4790-968b-f449bd91bd19/workspace"/work/REWORK-STATE.md (esp. §3 mechanics, §10 pitfalls) before any change.
Write only inside your scope paths. Update Status below. After milestone: bash scripts/sync-backup.sh.
## Status
- [x] DONE (2026-10-16)
See REWORK-STATE.md §8/§11 for evidence.
## Log
