@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: ==========================================================================
:: SHOW ALL TRAY ICONS - BAT EDITION v7.0.3 "Phoenix"
:: --------------------------------------------------------------------------
:: Standalone Windows tool: requires only reg.exe / taskkill (NO PowerShell).
:: Keeps every notification-area icon visible on Windows 10 1703+, 11, Server.
::
:: Mechanism: HKCU\Control Panel\NotifyIconSettings\{id}\IsPromoted = 1
::            (the same store the Windows Settings toggle uses), plus the
::            legacy EnableAutoTray switch and HideSCA* policy cleanup at
::            their CORRECT registry locations.
::
:: Usage:   Show-AllTrayIcons.bat [command] [interval] [/restart]
::          (no command = interactive menu)
::
:: Commands:
::   enable            Promote every hidden tray icon (default action)
::   disable           Restore Windows default behavior (icons may hide)
::   status            Show current configuration and counts
::   backup            Export current tray configuration to a .reg file
::   restore           Import the configuration saved by 'backup'
::   watch [N]         Forever loop: re-promote icons every N seconds (5)
::   restart           Restart explorer.exe
::   help              Show this help
::
:: Exit codes: 0 success | 1 error | 2 unsupported Windows | 3 partial failure
:: ==========================================================================

set "PRODUCT=Show All Tray Icons - BAT Edition"
set "VERSION=7.0.3"
set "REG_NIS=HKCU\Control Panel\NotifyIconSettings"
set "NIS_FULL=HKEY_CURRENT_USER\Control Panel\NotifyIconSettings"
set "REG_EXPLORER=HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer"
set "REG_POLICIES=HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
set "REG_RUN=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "DATA_DIR=%LOCALAPPDATA%\ShowAllTrayIcons"
set "BACKUP_DIR=%DATA_DIR%\backups"
set "BACKUP_FILE=%BACKUP_DIR%\TrayIconsBackup.reg"
set "BACKUP_PREV=%BACKUP_DIR%\TrayIconsBackup-prev.reg"
set "BACKUP_EXPLORER=%BACKUP_DIR%\ExplorerBackup.reg"
set "LOG_FILE=%DATA_DIR%\logs\bat.log"
set "EXITCODE=0"

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%" >nul 2>&1
if not exist "%DATA_DIR%\logs" mkdir "%DATA_DIR%\logs" >nul 2>&1
call :LOG "Session start v%VERSION%"

:: ---- Windows build gate: NotifyIconSettings needs 1703 (15063) ----------
set "WINBUILD="
for /f "tokens=4-6 delims=[]. " %%A in ('ver') do set "WINBUILD=%%C"
if not defined WINBUILD set "WINBUILD=0"
if !WINBUILD! LSS 15063 (
    echo   [ERROR] Windows build !WINBUILD! is too old.
    echo           Windows 10 1703 ^(build 15063^) or newer is required.
    set "EXITCODE=2"
    goto :EXIT
)

:: ---- Argument handling ---------------------------------------------------
set "CMD=%~1"
set "ARG2=%~2"
set "WANT_RESTART="
rem /c: forces a literal search string; without it findstr treats a leading
rem "/" or "-" as its own switch list (defect P1-1).
echo %* | findstr /i /c:"/restart" >nul && set "WANT_RESTART=1"
echo %* | findstr /i /c:"-restart" >nul && set "WANT_RESTART=1"

if not defined CMD goto :MENU
if /i "%CMD%"=="enable"   goto :DO_ENABLE
if /i "%CMD%"=="disable"  goto :DO_DISABLE
if /i "%CMD%"=="status"   goto :DO_STATUS
if /i "%CMD%"=="backup"   goto :DO_BACKUP
if /i "%CMD%"=="restore"  goto :DO_RESTORE
if /i "%CMD%"=="watch"    goto :DO_WATCH
if /i "%CMD%"=="restart"  goto :DO_RESTART_EXPLORER
if /i "%CMD%"=="help"     goto :DO_HELP
if /i "%CMD%"=="/?"       goto :DO_HELP
if /i "%CMD%"=="-?"       goto :DO_HELP
if /i "%CMD%"=="--help"   goto :DO_HELP
if /i "%CMD%"=="/help"    goto :DO_HELP
if /i "%CMD%"=="-help"    goto :DO_HELP

echo   [ERROR] Unknown command: %CMD%
echo           Run 'Show-AllTrayIcons.bat help' for usage.
set "EXITCODE=1"
goto :EXIT

:: ==========================================================================
:: ACTIONS
:: ==========================================================================

:DO_ENABLE
call :BANNER
echo   Promoting every hidden tray icon...
echo.
call :SCAN_AND_PROMOTE
reg add "%REG_EXPLORER%" /v EnableAutoTray /t REG_DWORD /d 0 /f >nul 2>&1
call :CLEAR_HIDE_POLICIES
echo.
echo   Registered icons .....: !COUNT_TOTAL!
echo   Already visible ......: !COUNT_ALREADY!
echo   Promoted now .........: !COUNT_PROMOTED!
echo   Failed ...............: !COUNT_FAILED!
echo   Legacy EnableAutoTray : set to 0 ^(show all^)
if !COUNT_FAILED! GTR 0 (
    echo   [WARN] Some icons could not be promoted; see log.
    set "EXITCODE=3"
) else (
    echo   [OK] All tray icons are now visible.
    set "EXITCODE=0"
)
if defined WANT_RESTART call :RESTART_EXPLORER
call :LOG "enable done total=!COUNT_TOTAL! promoted=!COUNT_PROMOTED! failed=!COUNT_FAILED!"
goto :EXIT

:DO_DISABLE
call :BANNER
echo   Restoring Windows default tray behavior...
echo.
call :SCAN_AND_DEMOTE
reg delete "%REG_EXPLORER%" /v EnableAutoTray /f >nul 2>&1
echo.
echo   Registered icons .....: !COUNT_TOTAL!
echo   Returned to default ..: !COUNT_DEMOTED!
echo   Failed ...............: !COUNT_FAILED!
echo   Legacy EnableAutoTray : removed ^(Windows default^)
if !COUNT_FAILED! GTR 0 (set "EXITCODE=3") else (set "EXITCODE=0")
if defined WANT_RESTART call :RESTART_EXPLORER
call :LOG "disable done demoted=!COUNT_DEMOTED! failed=!COUNT_FAILED!"
goto :EXIT

:DO_STATUS
call :BANNER
call :SCAN_COUNTS
set "AUTOTRAY=^<not set - Windows default^>"
for /f "tokens=3" %%V in ('reg query "%REG_EXPLORER%" /v EnableAutoTray 2^>nul ^| findstr /i "EnableAutoTray"') do set "AUTOTRAY=%%V"
set "AUTOSTART=not installed"
for /f "tokens=2,*" %%A in ('reg query "%REG_RUN%" /v TrayIconGuard 2^>nul ^| findstr /i "TrayIconGuard"') do set "AUTOSTART=%%B"
set "STALE_POLICIES=none"
for %%V in (HideSCAVolume HideSCANetwork HideSCAPower) do (
    reg query "%REG_POLICIES%" /v %%V 2>nul | findstr /i "%%V" >nul && set "STALE_POLICIES=!STALE_POLICIES! %%V"
)
echo   Windows build ........: !WINBUILD!
echo   Registered icons .....: !COUNT_TOTAL!
echo   Visible ^(promoted^) ....: !COUNT_PROMOTED!
echo   Hidden ...............: !COUNT_HIDDEN!
echo   Legacy EnableAutoTray : !AUTOTRAY!
echo   Hide policies ........:!STALE_POLICIES!
echo   Autostart TrayIconGuard: !AUTOSTART!
echo.
if !COUNT_TOTAL! EQU 0 (
    echo   [INFO] No icons registered yet - the store fills as apps add tray icons.
) else if !COUNT_HIDDEN! EQU 0 (
    echo   [OK] All registered icons are visible.
) else (
    echo   [WARN] !COUNT_HIDDEN! icon^(s^) hidden. Run 'enable' or 'watch'.
)
set "EXITCODE=0"
goto :EXIT

:DO_BACKUP
call :BANNER
echo   Backing up tray configuration...
if exist "%BACKUP_FILE%" move /y "%BACKUP_FILE%" "%BACKUP_PREV%" >nul 2>&1
reg export "%REG_NIS%" "%BACKUP_FILE%" /y >nul 2>&1
if errorlevel 1 (
    echo   [WARN] NotifyIconSettings key could not be exported ^(no icons registered?^).
    set "EXITCODE=1"
    goto :EXIT
)
reg export "%REG_EXPLORER%" "%BACKUP_EXPLORER%" /y >nul 2>&1
echo   [OK] Saved: %BACKUP_FILE%
echo        Previous backup ^(if any^): %BACKUP_PREV%
call :LOG "backup saved"
set "EXITCODE=0"
goto :EXIT

:DO_RESTORE
call :BANNER
if not exist "%BACKUP_FILE%" (
    echo   [ERROR] No backup found at %BACKUP_FILE%
    echo           Run 'Show-AllTrayIcons.bat backup' first.
    set "EXITCODE=1"
    goto :EXIT
)
echo   Restoring tray configuration...
reg import "%BACKUP_FILE%" >nul 2>&1
if errorlevel 1 (
    echo   [ERROR] reg import failed.
    set "EXITCODE=1"
    goto :EXIT
)
if exist "%BACKUP_EXPLORER%" reg import "%BACKUP_EXPLORER%" >nul 2>&1
echo   [OK] Configuration restored.
if defined WANT_RESTART call :RESTART_EXPLORER
call :LOG "restore done"
set "EXITCODE=0"
goto :EXIT

:DO_WATCH
set "WATCH_INTERVAL=%ARG2%"
if not defined WATCH_INTERVAL set "WATCH_INTERVAL=5"
echo !WATCH_INTERVAL!| findstr /r "^[1-9][0-9]*$" >nul
if errorlevel 1 (
    echo   [ERROR] Invalid watch interval: '!WATCH_INTERVAL!' ^(whole seconds^)
    set "EXITCODE=1"
    goto :EXIT
)
call :BANNER
echo   Watching every !WATCH_INTERVAL!s - hidden icons are re-promoted instantly.
echo   Press Ctrl+C to stop ^(answer Y to terminate^).
echo.
call :LOG "watch started interval=!WATCH_INTERVAL!"
:WATCH_LOOP
call :SCAN_AND_PROMOTE
if !COUNT_PROMOTED! GTR 0 (
    echo   [%DATE% %TIME%] Promoted !COUNT_PROMOTED! icon^(s^) ^(of !COUNT_TOTAL! registered^).
    call :LOG "watch promoted=!COUNT_PROMOTED!"
)
timeout /t !WATCH_INTERVAL! /nobreak >nul 2>&1
if errorlevel 1 ping -n !WATCH_INTERVAL! 127.0.0.1 >nul
goto :WATCH_LOOP

:DO_RESTART_EXPLORER
call :RESTART_EXPLORER
goto :EXIT

:DO_HELP
call :BANNER
echo   USAGE: Show-AllTrayIcons.bat [command] [interval] [/restart]
echo.
echo   COMMANDS
echo     enable     Promote every hidden tray icon ^(IsPromoted=1^)
echo     disable    Restore Windows default behavior
echo     status     Show counts, legacy switch, autostart
echo     backup     Export configuration to %BACKUP_FILE%
echo     restore    Import configuration saved by 'backup'
echo     watch [N]  Forever loop, re-promoting every N seconds ^(default 5^)
echo     restart    Restart explorer.exe
echo     help       This help
echo.
echo   OPTIONS
echo     /restart   Also restart Explorer after enable/disable/restore
echo.
echo   EXAMPLES
echo     Show-AllTrayIcons.bat enable
echo     Show-AllTrayIcons.bat enable /restart
echo     Show-AllTrayIcons.bat watch 3
echo     Show-AllTrayIcons.bat status
echo.
echo   EXIT CODES  0 success ^| 1 error ^| 2 unsupported Windows ^| 3 partial
echo.
echo   NOTES
echo     - No administrator rights required ^(HKCU only^).
echo     - Windows 10 1703+ / 11 / Server 2019+ required.
echo     - Logs: %LOG_FILE%
set "EXITCODE=0"
goto :EXIT

:: ==========================================================================
:: INTERACTIVE MENU
:: ==========================================================================

:MENU
call :BANNER
echo   [1] Enable  - show all tray icons
echo   [2] Disable - restore Windows defaults
echo   [3] Status  - current configuration
echo   [4] Backup  - save configuration
echo   [5] Restore - load saved configuration
echo   [6] Watch   - keep icons visible forever
echo   [7] Restart Explorer
echo   [8] Help
echo   [0] Exit
echo.
choice /c 123456780 /n /m "  Select action: "
set "SEL=!ERRORLEVEL!"
if !SEL! EQU 1 call :DO_ENABLE_MENU
if !SEL! EQU 2 call :DO_DISABLE_MENU
if !SEL! EQU 3 call :DO_STATUS
if !SEL! EQU 4 call :DO_BACKUP
if !SEL! EQU 5 call :DO_RESTORE
if !SEL! EQU 6 call :DO_WATCH
if !SEL! EQU 7 call :RESTART_EXPLORER
if !SEL! EQU 8 call :DO_HELP
if !SEL! EQU 9 goto :EXIT
echo.
pause
goto :MENU

:DO_ENABLE_MENU
set "CMD=enable"
call :DO_ENABLE
exit /b 0

:DO_DISABLE_MENU
set "CMD=disable"
call :DO_DISABLE
exit /b 0

:: ==========================================================================
:: SUBROUTINES
:: ==========================================================================

:BANNER
echo.
echo  ==============================================================
echo    %PRODUCT% v%VERSION%
echo    Windows build !WINBUILD! - HKCU\Control Panel\NotifyIconSettings
echo  ==============================================================
echo.
exit /b 0

:LOG
>>"%LOG_FILE%" echo [%DATE% %TIME%] %~1
exit /b 0

:SCAN_AND_PROMOTE
set /a COUNT_TOTAL=0, COUNT_PROMOTED=0, COUNT_ALREADY=0, COUNT_FAILED=0
reg query "%REG_NIS%" >nul 2>&1
if errorlevel 1 (
    echo   [INFO] NotifyIconSettings does not exist yet ^(no tray icons registered^).
    exit /b 0
)
rem findstr /b HKEY_ keeps only subkey lines; reg query also prints the root
rem key's own VALUES (Version, MigrationStatus, UIOrderList) as indented lines,
rem which must never be counted as icons (defect P1-2).
for /f "usebackq delims=" %%K in (`reg query "%REG_NIS%" 2^>nul ^| findstr /b "HKEY_"`) do (
    set "SUBKEY=%%K"
    if /i not "!SUBKEY!"=="!NIS_FULL!" (
        set /a COUNT_TOTAL+=1
        call :PROMOTE_KEY "!SUBKEY!"
    )
)
exit /b 0

:PROMOTE_KEY
set "PKEY=%~1"
set "PROMOTED="
for /f "tokens=3" %%V in ('reg query "%PKEY%" /v IsPromoted 2^>nul ^| findstr /i "IsPromoted"') do set "PROMOTED=%%V"
if not defined PROMOTED (
    reg add "%PKEY%" /v IsPromoted /t REG_DWORD /d 1 /f >nul 2>&1
    if errorlevel 1 (
        set /a COUNT_FAILED+=1
    ) else (
        set /a COUNT_PROMOTED+=1
        call :LOG "promoted(new): %PKEY%"
    )
) else (
    if /i "!PROMOTED!"=="0x0" (
        reg add "%PKEY%" /v IsPromoted /t REG_DWORD /d 1 /f >nul 2>&1
        if errorlevel 1 (
            set /a COUNT_FAILED+=1
        ) else (
            set /a COUNT_PROMOTED+=1
            call :LOG "promoted: %PKEY%"
        )
    ) else (
        set /a COUNT_ALREADY+=1
    )
)
exit /b 0

:SCAN_AND_DEMOTE
set /a COUNT_TOTAL=0, COUNT_DEMOTED=0, COUNT_FAILED=0
reg query "%REG_NIS%" >nul 2>&1
if errorlevel 1 exit /b 0
rem findstr /b HKEY_ keeps only subkey lines; reg query also prints the root
rem key's own VALUES (Version, MigrationStatus, UIOrderList) as indented lines,
rem which must never be counted as icons (defect P1-2).
for /f "usebackq delims=" %%K in (`reg query "%REG_NIS%" 2^>nul ^| findstr /b "HKEY_"`) do (
    set "SUBKEY=%%K"
    if /i not "!SUBKEY!"=="!NIS_FULL!" (
        set /a COUNT_TOTAL+=1
        call :DEMOTE_KEY "!SUBKEY!"
    )
)
exit /b 0

:DEMOTE_KEY
set "PKEY=%~1"
reg add "%PKEY%" /v IsPromoted /t REG_DWORD /d 0 /f >nul 2>&1
if errorlevel 1 (
    set /a COUNT_FAILED+=1
) else (
    set /a COUNT_DEMOTED+=1
)
exit /b 0

:SCAN_COUNTS
set /a COUNT_TOTAL=0, COUNT_PROMOTED=0, COUNT_HIDDEN=0
reg query "%REG_NIS%" >nul 2>&1
if errorlevel 1 exit /b 0
rem findstr /b HKEY_ keeps only subkey lines; reg query also prints the root
rem key's own VALUES (Version, MigrationStatus, UIOrderList) as indented lines,
rem which must never be counted as icons (defect P1-2).
for /f "usebackq delims=" %%K in (`reg query "%REG_NIS%" 2^>nul ^| findstr /b "HKEY_"`) do (
    set "SUBKEY=%%K"
    if /i not "!SUBKEY!"=="!NIS_FULL!" (
        set /a COUNT_TOTAL+=1
        set "PROMOTED="
        for /f "tokens=3" %%V in ('reg query "!SUBKEY!" /v IsPromoted 2^>nul ^| findstr /i "IsPromoted"') do set "PROMOTED=%%V"
        if defined PROMOTED (
            if /i "!PROMOTED!"=="0x1" (set /a COUNT_PROMOTED+=1) else (set /a COUNT_HIDDEN+=1)
        ) else (
            set /a COUNT_HIDDEN+=1
        )
    )
)
exit /b 0

:CLEAR_HIDE_POLICIES
for %%V in (HideSCAVolume HideSCANetwork HideSCAPower) do (
    reg query "%REG_POLICIES%" /v %%V 2>nul | findstr /i "%%V" >nul && (
        reg delete "%REG_POLICIES%" /v %%V /f >nul 2>&1
        echo   Removed stale hide-policy: %%V
        call :LOG "removed policy %%V"
    )
)
exit /b 0

:RESTART_EXPLORER
echo.
echo   Restarting explorer.exe...
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 2 /nobreak >nul 2>&1
tasklist /fi "imagename eq explorer.exe" 2>nul | findstr /i "explorer.exe" >nul
if errorlevel 1 (
    start "" explorer.exe
    echo   [OK] Explorer started manually.
) else (
    echo   [OK] Explorer auto-restarted.
)
call :LOG "explorer restarted"
exit /b 0

:EXIT
set "EC=!EXITCODE!"
call :LOG "exit code !EC!"
endlocal & exit /b %EC%
