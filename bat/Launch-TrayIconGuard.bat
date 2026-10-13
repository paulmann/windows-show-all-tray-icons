@echo off
setlocal EnableExtensions DisableDelayedExpansion
:: ==========================================================================
:: TrayIconGuard launcher v7.0.3 - finds and starts the GUI edition.
:: Search order: per-user install, machine install, repo build output.
:: Extra arguments are forwarded (e.g. --minimized, --promote-all).
:: ==========================================================================
title TrayIconGuard launcher

:: R3-2: the .NET apphost resolves the runtime via DOTNET_ROOT when it is set.
:: A DOTNET_ROOT pointing at an embedded/bundled runtime (dev shells, build
:: tools) hides an installed .NET and triggers a bogus 'install .NET' dialog.
:: Clear it for the child process; self-contained builds ignore it anyway.
set "DOTNET_ROOT="

set "EXE="
if exist "%LOCALAPPDATA%\Programs\TrayIconGuard\TrayIconGuard.exe" set "EXE=%LOCALAPPDATA%\Programs\TrayIconGuard\TrayIconGuard.exe"
if not defined EXE if exist "%ProgramFiles%\TrayIconGuard\TrayIconGuard.exe" set "EXE=%ProgramFiles%\TrayIconGuard\TrayIconGuard.exe"
if not defined EXE if exist "%~dp0..\artifacts\publish\win-x64\TrayIconGuard.exe" set "EXE=%~dp0..\artifacts\publish\win-x64\TrayIconGuard.exe"
if not defined EXE if exist "%~dp0..\artifacts\publish\win-arm64\TrayIconGuard.exe" set "EXE=%~dp0..\artifacts\publish\win-arm64\TrayIconGuard.exe"
if not defined EXE if exist "%~dp0..\app\src\TrayIconGuard\bin\Release\net10.0-windows\TrayIconGuard.exe" set "EXE=%~dp0..\app\src\TrayIconGuard\bin\Release\net10.0-windows\TrayIconGuard.exe"
if not defined EXE if exist "%~dp0..\app\src\TrayIconGuard\bin\Release\net10.0-windows\win-x64\TrayIconGuard.exe" set "EXE=%~dp0..\app\src\TrayIconGuard\bin\Release\net10.0-windows\win-x64\TrayIconGuard.exe"
if not defined EXE if exist "%~dp0..\app\src\TrayIconGuard\bin\Debug\net10.0-windows\TrayIconGuard.exe" set "EXE=%~dp0..\app\src\TrayIconGuard\bin\Debug\net10.0-windows\TrayIconGuard.exe"

if not defined EXE (
    for /r "%~dp0..\app\src\TrayIconGuard\bin" %%F in (TrayIconGuard.exe) do (
        if not defined EXE set "EXE=%%~F"
    )
)

if not defined EXE (
    echo.
    echo   [ERROR] TrayIconGuard.exe was not found.
    echo.
    echo   Build it first, either of:
    echo     1^) VS Code: open this repo, press Ctrl+Shift+B ^(Build TrayIconGuard^)
    echo     2^) CLI:     pwsh -NoProfile -File build.ps1 -Task PublishExe
    echo.
    echo   Then re-run this launcher, or install via installer\TrayIconGuard.iss.
    exit /b 1
)

start "" "%EXE%" %*
exit /b 0
