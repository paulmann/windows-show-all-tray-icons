@echo off
REM ============================================================================
REM  Windows 11/10 - SHOW ALL SYSTEM TRAY ICONS (EnableAutoTray=0)
REM  Professional BAT Script for Modern System Administrators
REM  Author: Mikhail Deynekin (mid1977@gmail.com) | https://deynekin.com
REM  Repository: https://github.com/paulmann/windows-show-all-tray-icons
REM  Version: 2.2 (Enterprise-ready, with error handling and backup)
REM ============================================================================

setlocal EnableDelayedExpansion

set "KEY=HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
set "VAL=EnableAutoTray"
set "VREG=REG_DWORD"
set "BACKUP=%TEMP%\trayicons_backup_%USERNAME%.reg"
set "LOG=%TEMP%\EnableTrayIcons_%USERNAME%.log"

echo ==================================================
echo   Show All System Tray Icons - Setup Script
echo   Author: Mikhail Deynekin (mid1977@gmail.com)
echo   Website: https://deynekin.com
echo   Log: %LOG%
echo ==================================================
echo.

:: --- Logging macro ---------------------------
call :log "[INFO] Script start: %DATE% %TIME%" 
:: --------------------------------------------

:: Backup registry key for safety
call :log "[INFO] Backing up registry key: %KEY%"
reg export "%KEY%" "%BACKUP%" /y >nul 2>&1
if %errorlevel% neq 0 (
    call :log "[WARNING] Registry backup was NOT successful (may not exist yet)."
) else (
    call :log "[SUCCESS] Backup created: %BACKUP%"
)

:: Set registry value
call :log "[INFO] Setting %VAL% to 0 (Show ALL icons)..."
reg add "%KEY%" /v "%VAL%" /t %VREG% /d 0 /f >nul
if %errorlevel% neq 0 (
    call :log "[ERROR] Failed to set registry value. Try running as administrator."
    echo [ERROR] Could not set registry value. See log %LOG%
    goto:END
) else (
    call :log "[SUCCESS] Registry value '%VAL%' set to 0."
)

:: Restart Explorer (for effect)
call :log "[INFO] Attempting to restart Windows Explorer."
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 2 /nobreak >nul
start explorer.exe
if %errorlevel% neq 0 (
    call :log "[WARNING] Explorer restart failed, may need manual restart."
) else (
    call :log "[SUCCESS] Explorer restarted."
)

:: Verify
call :log "[INFO] Verifying registry value..."
reg query "%KEY%" /v "%VAL%" | find "0x0" >nul 2>&1
if %errorlevel% neq 0 (
    call :log "[ERROR] Value not set as expected."
) else (
    call :log "[SUCCESS] Tray icon setting verified."
)

:: Final message
echo.
echo [DONE] All system tray icons should now be visible. 
echo See %LOG% for details or troubleshooting steps.
call :log "[INFO] Script completed successfully."

:END
endlocal
exit /b

:: Logging function
:log
echo %~1
echo %~1>>"%LOG%"
exit /b
