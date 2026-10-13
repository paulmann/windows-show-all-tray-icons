@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: ==========================================================================
:: PowerShell Edition launcher v7.0.3
:: Runs the ShowAllTrayIcons PowerShell entry scripts with pwsh 7.6+.
::
:: Usage:
::   Run-PowerShell-Edition.bat [enable|disable|watch|help] [script args...]
::   (no action keyword = enable; extra arguments are forwarded verbatim)
::
:: Exit codes mirror the PowerShell scripts:
::   0 success | 1 error | 2 unsupported platform / pwsh missing | 3 partial
::
:: IMPLEMENTATION NOTES (defect N1, audit round 2):
::   cmd.exe SHIFT also shifts %0, so %~dp0 becomes garbage after the first
::   shift. Therefore this script (a) captures SCRIPT_DIR BEFORE anything else
::   and (b) contains NO shift at all: the action keyword is consumed logically
::   and the remaining arguments are collected in one pass (%~1..%~9).
:: ==========================================================================
title Show All Tray Icons - PowerShell Edition

:: Capture the script directory FIRST - before any parsing (see notes above).
set "SCRIPT_DIR=%~dp0"

set "SCRIPT=Enable-AllTrayIcons.ps1"
set "ACTION=%~1"

if /i "%ACTION%"=="help"   goto :HELP
if /i "%ACTION%"=="/?"     goto :HELP
if /i "%ACTION%"=="-?"     goto :HELP
if /i "%ACTION%"=="--help" goto :HELP
if /i "%ACTION%"=="/help"  goto :HELP
if /i "%ACTION%"=="-help"  goto :HELP

if /i "%ACTION%"=="disable" set "SCRIPT=Disable-AllTrayIcons.ps1"
if /i "%ACTION%"=="watch"   set "SCRIPT=Watch-TrayIcons.ps1"
if /i "%ACTION%"=="enable"  set "SCRIPT=Enable-AllTrayIcons.ps1"

:: Was the first argument an action keyword (to be consumed)?
set "CONSUME="
if /i "%ACTION%"=="enable"  set "CONSUME=1"
if /i "%ACTION%"=="disable" set "CONSUME=1"
if /i "%ACTION%"=="watch"   set "CONSUME=1"

:: Collect forwarded arguments in one pass, without shift.
set REST=
if defined CONSUME (
    call :ADDARG "%~2"
    call :ADDARG "%~3"
    call :ADDARG "%~4"
    call :ADDARG "%~5"
    call :ADDARG "%~6"
    call :ADDARG "%~7"
    call :ADDARG "%~8"
    call :ADDARG "%~9"
) else (
    call :ADDARG "%~1"
    call :ADDARG "%~2"
    call :ADDARG "%~3"
    call :ADDARG "%~4"
    call :ADDARG "%~5"
    call :ADDARG "%~6"
    call :ADDARG "%~7"
    call :ADDARG "%~8"
    call :ADDARG "%~9"
)

:RUN
where pwsh >nul 2>&1
if errorlevel 1 (
    echo   [ERROR] PowerShell 7.6+ ^(pwsh^) was not found on PATH.
    echo           Install it with: winget install --id Microsoft.PowerShell
    echo           ...or use the standalone BAT edition: Show-AllTrayIcons.bat
    set "EC=2"
    goto :EXIT
)

pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%SCRIPT_DIR%..\powershell\%SCRIPT%" !REST!
set "EC=%ERRORLEVEL%"
goto :EXIT

:ADDARG
if not "%~1"=="" set REST=!REST! "%~1"
exit /b 0

:HELP
echo.
echo   USAGE: Run-PowerShell-Edition.bat [enable^|disable^|watch^|help] [args...]
echo.
echo     enable    ^(default^)  Show all tray icons    -^> powershell\Enable-AllTrayIcons.ps1
echo     disable              Restore Windows defaults -^> powershell\Disable-AllTrayIcons.ps1
echo     watch                Foreground icon guard    -^> powershell\Watch-TrayIcons.ps1
echo     help                 This help ^(no pwsh required^)
echo.
echo   The first argument is treated as an action only if it is one of the
echo   keywords above; anything else is forwarded to the script as-is.
echo   Up to 8 extra arguments are forwarded, quotes and spaces preserved.
echo.
echo   EXAMPLES
echo     Run-PowerShell-Edition.bat enable -AsJson -WhatIf
echo     Run-PowerShell-Edition.bat enable -Backup -RestartExplorer -Force
echo     Run-PowerShell-Edition.bat disable -FromBackup -Force
echo     Run-PowerShell-Edition.bat watch -TimeoutSec 60
echo     Run-PowerShell-Edition.bat -Exclude onedrive.exe   ^(action defaults to enable^)
echo.
echo   REQUIREMENTS
echo     PowerShell 7.6+ ^(pwsh^) on PATH; Windows 10 1703+ / 11 / Server 2019+.
echo.
echo   EXIT CODES  0 success ^| 1 error ^| 2 pwsh missing ^| 3 partial failure
echo.
set "EC=0"
goto :EXIT

:EXIT
endlocal & exit /b %EC%
