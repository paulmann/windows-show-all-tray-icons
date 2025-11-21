@echo off
rem =====================================================================
rem Windows 11/10 - Show All System Tray Icons (Enable AutoTray = 0)
rem Professional BAT Script for System Administrators
rem Author: Mikhail Deynekin (mid1977@gmail.com) | https://deynekin.com
rem Version: 2.2 | Last Updated: 2025-11-21
rem ---------------------------------------------------------------------
rem This script disables automatic hiding of tray icons (EnableAutoTray=0)
rem - Applies setting to current user (HKCU registry)
rem - Restarts Explorer for immediate effect
rem - Creates a backup of the registry key before changing
rem =====================================================================

setlocal
set "KEY=HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
set "VAL=EnableAutoTray"
set "BACKUP=%TEMP%\trayicons_backup.reg"

echo [INFO] Backing up registry key...
reg export "%KEY%" "%BACKUP%" /y >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] Registry backup was NOT successful - proceeding anyway.
) else (
    echo [SUCCESS] Backup created: %BACKUP%
)

echo [INFO] Setting %VAL% to 0 (Show ALL icons)...
reg add "%KEY%" /v %VAL% /t REG_DWORD /d 0 /f >nul
if %errorlevel% neq 0 (
    echo [ERROR] Failed to set registry value.
    echo   Make sure you have rights to modify HKCU registry.
    echo   Try running as administrator if you see errors.
    goto :END
) else (
    echo [SUCCESS] %VAL% set to 0.
)

rem Restart Windows Explorer for changes to take effect
echo [INFO] Restarting Windows Explorer...
taskkill /f /im explorer.exe >nul
timeout /t 2 /nobreak >nul
start explorer.exe
if %errorlevel% neq 0 (
    echo [WARNING] Explorer restart failed. Restart manually if needed.
) else (
    echo [SUCCESS] Explorer restarted.
)

echo [DONE] All notification area (tray) icons should now be visible!

:END
endlocal
exit /b
