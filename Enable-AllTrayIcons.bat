@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: WINDOWS SYSTEM TRAY ICONS CONFIGURATION TOOL 4.0
:: ============================================================================

:: Enhanced Configuration
set "SCRIPT_VERSION=4.1"
set "SCRIPT_AUTHOR=Mikhail Deynekin (mid1977@gmail.com)"
set "SCRIPT_NAME=Enable-AllTrayIcons.bat"

:: Registry Configuration
set "REGISTRY_PATH=HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
set "REGISTRY_VALUE=EnableAutoTray"
set "ENABLE_VALUE=0"
set "DISABLE_VALUE=1"

:: Path Configuration
set "BACKUP_PATH=%TEMP%\TrayIconsBackup.reg"
set "LOG_PATH=%TEMP%\Enable-AllTrayIcons.log"

:: Parse command line arguments
set "ACTION="
set "RESTART_EXPLORER=0"
set "EXIT_CODE=0"

:PARSE_ARGS
if "%~1"=="" goto :MAIN_EXECUTION

set "ARG=%~1"

if /i "!ARG!"=="help" set "SHOW_HELP=1"
if /i "!ARG!"=="/help" set "SHOW_HELP=1"
if /i "!ARG!"=="-help" set "SHOW_HELP=1"
if /i "!ARG!"=="-?" set "SHOW_HELP=1"
if /i "!ARG!"=="/?" set "SHOW_HELP=1"

if /i "!ARG!"=="enable" set "ACTION=ENABLE"
if /i "!ARG!"=="disable" set "ACTION=DISABLE"
if /i "!ARG!"=="status" set "ACTION=STATUS"
if /i "!ARG!"=="backup" set "ACTION=BACKUP"
if /i "!ARG!"=="restore" set "ACTION=RESTORE"

if /i "!ARG!"=="restart" set "RESTART_EXPLORER=1"
if /i "!ARG!"=="/restart" set "RESTART_EXPLORER=1"
if /i "!ARG!"=="-restart" set "RESTART_EXPLORER=1"

shift
goto :PARSE_ARGS

:: ============================================================================
:: BACKUP SYSTEM (перемещено выше для доступности)
:: ============================================================================

:BACKUP_REGISTRY_CONFIGURATION
call :WRITE_STATUS "Creating registry backup..." "PROCESSING"

call :GET_CURRENT_TRAY_CONFIGURATION
set "CURRENT_CONFIG=!ERRORLEVEL!"

:: Create backup file
(
echo Windows Registry Editor Version 5.00
echo.
echo [!REGISTRY_PATH!]
) > "!BACKUP_PATH!" 2>nul

if !errorlevel! neq 0 (
    call :WRITE_STATUS "Failed to create backup file" "ERROR"
    set "EXIT_CODE=1"
    goto :EOF
)

if "!CURRENT_CONFIG!"=="255" (
    echo "!REGISTRY_VALUE!"=- >> "!BACKUP_PATH!" 2>nul
) else (
    echo "!REGISTRY_VALUE!"=dword:!CURRENT_CONFIG! >> "!BACKUP_PATH!" 2>nul
)

if !errorlevel! neq 0 (
    call :WRITE_STATUS "Failed to write backup data" "ERROR"
    set "EXIT_CODE=1"
    goto :EOF
)

for %%F in ("!BACKUP_PATH!") do (
    set "BACKUP_SIZE=%%~zF"
    if defined BACKUP_SIZE (
        set /a BACKUP_SIZE_KB=!BACKUP_SIZE!/1024 2>nul
    ) else (
        set "BACKUP_SIZE_KB=0"
    )
)

call :WRITE_STATUS "Backup created successfully" "SUCCESS"
call :SHOW_CARD "  Location" "!BACKUP_PATH!"
call :SHOW_CARD "  Size" "!BACKUP_SIZE_KB! KB"
set "EXIT_CODE=0"
goto :EOF

:RESTORE_REGISTRY_CONFIGURATION
if not exist "!BACKUP_PATH!" (
    call :WRITE_STATUS "No backup file found" "ERROR"
    call :WRITE_STATUS "Run 'Backup' first to create a backup" "INFO"
    set "EXIT_CODE=1"
    goto :EOF
)

call :WRITE_STATUS "Restoring registry from backup..." "INFO"
reg import "!BACKUP_PATH!" >nul 2>&1
if !errorlevel! neq 0 (
    call :WRITE_STATUS "Restore failed" "ERROR"
    set "EXIT_CODE=1"
    goto :EOF
)

call :WRITE_STATUS "Registry restored successfully!" "SUCCESS"
call :WRITE_STATUS "Backup file preserved: !BACKUP_PATH!" "INFO"
set "EXIT_CODE=0"
goto :EOF

:: ============================================================================
:: MAIN EXECUTION
:: ============================================================================
:MAIN_EXECUTION
call :INITIALIZE_LOGGING

:: Handle Help first
if "!SHOW_HELP!"=="1" (
    call :SHOW_BANNER
    call :SHOW_SIMPLE_HELP
    goto :EXIT_SCRIPT
)

:: Show application info if no specific action
if "!ACTION!"=="" (
    call :SHOW_BANNER
    call :SHOW_APPLICATION_INFO
    goto :EXIT_SCRIPT
)

call :SHOW_BANNER

:: Execute the requested action
if /i "!ACTION!"=="STATUS" (
    call :SHOW_ENHANCED_STATUS
    goto :EXIT_SCRIPT
)

if /i "!ACTION!"=="BACKUP" (
    call :SHOW_ACTION_HEADER "Create Backup" "Saving tray settings"
    call :BACKUP_REGISTRY_CONFIGURATION
    goto :EXIT_SCRIPT
)

if /i "!ACTION!"=="RESTORE" (
    call :SHOW_ACTION_HEADER "Restore Backup" "Restoring tray settings from backup"
    call :RESTORE_REGISTRY_CONFIGURATION
    if "!EXIT_CODE!"=="0" if "!RESTART_EXPLORER!"=="1" (
        call :WRITE_STATUS "Applying changes immediately..." "INFO"
        call :RESTART_WINDOWS_EXPLORER
    )
    goto :EXIT_SCRIPT
)

if /i "!ACTION!"=="ENABLE" (
    call :SHOW_ACTION_HEADER "Enable ALL Tray Icons" "Showing all icons in system tray"
    call :ENABLE_ALL_TRAY_ICONS
    if "!EXIT_CODE!"=="0" if "!RESTART_EXPLORER!"=="1" (
        call :WRITE_STATUS "Applying changes immediately..." "INFO"
        call :RESTART_WINDOWS_EXPLORER
    )
    goto :EXIT_SCRIPT
)

if /i "!ACTION!"=="DISABLE" (
    call :SHOW_ACTION_HEADER "Restore Default" "Enabling auto-hide for tray icons"
    call :DISABLE_TRAY_ICONS
    if "!EXIT_CODE!"=="0" if "!RESTART_EXPLORER!"=="1" (
        call :WRITE_STATUS "Applying changes immediately..." "INFO"
        call :RESTART_WINDOWS_EXPLORER
    )
    goto :EXIT_SCRIPT
)

call :WRITE_STATUS "Unknown action: !ACTION!" "ERROR"
call :WRITE_STATUS "Use 'Enable-AllTrayIcons.bat Help' for usage information" "INFO"
set "EXIT_CODE=1"
goto :EXIT_SCRIPT

:: ============================================================================
:: CORE FUNCTIONS
:: ============================================================================

:INITIALIZE_LOGGING
echo [%DATE% %TIME%] Script started: %SCRIPT_NAME% v%SCRIPT_VERSION% > "!LOG_PATH!"
echo [%DATE% %TIME%] User: %USERNAME% >> "!LOG_PATH!"
echo [%DATE% %TIME%] Computer: %COMPUTERNAME% >> "!LOG_PATH!"
goto :EOF

:SHOW_BANNER
echo.
echo ================================================================
echo    WINDOWS SYSTEM TRAY ICONS CONFIGURATION TOOL
echo ================================================================
echo.
goto :EOF

:SHOW_ACTION_HEADER
set "HEADER_TITLE=%~1"
set "HEADER_SUBTITLE=%~2"
echo.
echo !HEADER_TITLE!
echo !HEADER_SUBTITLE!
echo -----------------------------------------------
echo.
goto :EOF

:WRITE_STATUS
set "STATUS_MESSAGE=%~1"
set "STATUS_TYPE=%~2"
set "STATUS_PREFIX=  [INFO] "

if "!STATUS_TYPE!"=="SUCCESS" set "STATUS_PREFIX=  [OK] "
if "!STATUS_TYPE!"=="ERROR" set "STATUS_PREFIX=  [ERROR] "
if "!STATUS_TYPE!"=="WARNING" set "STATUS_PREFIX=  [WARN] "
if "!STATUS_TYPE!"=="INFO" set "STATUS_PREFIX=  [INFO] "
if "!STATUS_TYPE!"=="PROCESSING" set "STATUS_PREFIX=  [....] "

echo !STATUS_PREFIX!!STATUS_MESSAGE!
echo [%DATE% %TIME%] [!STATUS_TYPE!] !STATUS_MESSAGE! >> "!LOG_PATH!"
goto :EOF

:SHOW_CARD
set "CARD_TITLE=%~1"
set "CARD_VALUE=%~2"
echo   !CARD_TITLE! : !CARD_VALUE!
goto :EOF

:: ============================================================================
:: SIMPLIFIED HELP SYSTEM
:: ============================================================================

:SHOW_SIMPLE_HELP
echo QUICK EXAMPLES:
call :SHOW_CARD "  Show all icons" "%SCRIPT_NAME% Enable"
call :SHOW_CARD "  Show all + restart" "%SCRIPT_NAME% Enable /Restart"
call :SHOW_CARD "  Restore default" "%SCRIPT_NAME% Disable"
call :SHOW_CARD "  Check status" "%SCRIPT_NAME% Status"
call :SHOW_CARD "  Create backup" "%SCRIPT_NAME% Backup"
call :SHOW_CARD "  Restore backup" "%SCRIPT_NAME% Restore"
echo.

echo ACTIONS:
call :SHOW_CARD "  Enable" "Show all tray icons (disable auto-hide)"
call :SHOW_CARD "  Disable" "Restore Windows default (enable auto-hide)"
call :SHOW_CARD "  Status" "Show current configuration"
call :SHOW_CARD "  Backup" "Create registry backup"
call :SHOW_CARD "  Restore" "Restore from backup"
echo.

echo OPTIONS:
call :SHOW_CARD "  /Restart" "Apply changes immediately"
call :SHOW_CARD "  /Help" "Show this help"
echo.

echo NOTES:
echo   - All parameters are case-insensitive
echo   - Admin rights not required
echo   - Works on Windows 10/11
echo.
goto :EOF

:SHOW_APPLICATION_INFO
echo Application Information:
call :SHOW_CARD "  Version" "!SCRIPT_VERSION!"
call :SHOW_CARD "  Author" "!SCRIPT_AUTHOR!"
echo.
echo Type '%SCRIPT_NAME% Help' for usage information.
echo.
goto :EOF

:: ============================================================================
:: STATUS DISPLAY
:: ============================================================================

:SHOW_ENHANCED_STATUS
echo Current Tray Icons Configuration:
echo.

call :GET_CURRENT_TRAY_CONFIGURATION
set "CURRENT_CONFIG=!ERRORLEVEL!"

if "!CURRENT_CONFIG!"=="255" (
    call :SHOW_CARD "  Status" "Auto-hide inactive icons (Windows default)"
    call :SHOW_CARD "  Registry" "Not configured - using system default"
) else (
    if "!CURRENT_CONFIG!"=="!ENABLE_VALUE!" (
        call :SHOW_CARD "  Status" "Show ALL tray icons (auto-hide disabled)"
    ) else (
        call :SHOW_CARD "  Status" "Auto-hide inactive icons (Windows default)"
    )
    call :SHOW_CARD "  Registry Value" "!CURRENT_CONFIG!"
)
echo.

echo System Information:
for /f "tokens=*" %%i in ('ver') do set "OS_VERSION=%%i"
call :SHOW_CARD "  OS Version" "!OS_VERSION!"
call :SHOW_CARD "  Computer" "%COMPUTERNAME%"
call :SHOW_CARD "  User" "%USERNAME%"
echo.

if exist "!BACKUP_PATH!" (
    for %%F in ("!BACKUP_PATH!") do (
        call :SHOW_CARD "  Backup Available" "Yes (%%~tF)"
    )
) else (
    call :SHOW_CARD "  Backup Available" "No"
)
echo.
goto :EOF

:: ============================================================================
:: REGISTRY OPERATIONS
:: ============================================================================

:GET_CURRENT_TRAY_CONFIGURATION
reg query "!REGISTRY_PATH!" /v "!REGISTRY_VALUE!" >nul 2>&1
if !errorlevel! neq 0 exit /b 255

for /f "tokens=3" %%i in ('reg query "!REGISTRY_PATH!" /v "!REGISTRY_VALUE!" 2^>nul') do (
    exit /b %%i
)
exit /b 255

:ENABLE_ALL_TRAY_ICONS
call :WRITE_STATUS "Enabling all tray icons..." "PROCESSING"

:: Ensure registry path exists
reg query "!REGISTRY_PATH!" >nul 2>&1
if !errorlevel! neq 0 (
    call :WRITE_STATUS "Creating registry path..." "INFO"
    reg add "!REGISTRY_PATH!" /f >nul 2>&1
)

:: Set registry value to show all icons
reg add "!REGISTRY_PATH!" /v "!REGISTRY_VALUE!" /t REG_DWORD /d "!ENABLE_VALUE!" /f >nul 2>&1
if !errorlevel! neq 0 (
    call :WRITE_STATUS "Failed to configure registry" "ERROR"
    set "EXIT_CODE=1"
    goto :EOF
)

call :WRITE_STATUS "All tray icons will be visible" "SUCCESS"
set "EXIT_CODE=0"
goto :EOF

:DISABLE_TRAY_ICONS
call :WRITE_STATUS "Restoring default tray behavior..." "PROCESSING"

:: Set registry value to enable auto-hide
reg add "!REGISTRY_PATH!" /v "!REGISTRY_VALUE!" /t REG_DWORD /d "!DISABLE_VALUE!" /f >nul 2>&1
if !errorlevel! neq 0 (
    call :WRITE_STATUS "Failed to configure registry" "ERROR"
    set "EXIT_CODE=1"
    goto :EOF
)

call :WRITE_STATUS "Windows default behavior restored" "SUCCESS"
set "EXIT_CODE=0"
goto :EOF

:: ============================================================================
:: EXPLORER MANAGEMENT
:: ============================================================================

:RESTART_WINDOWS_EXPLORER
call :WRITE_STATUS "Restarting Windows Explorer..." "INFO"

:: Stop Explorer processes
taskkill /f /im explorer.exe >nul 2>&1

:: Wait a moment
timeout /t 2 /nobreak >nul

:: Start Explorer
start "" explorer.exe >nul 2>&1
call :WRITE_STATUS "Windows Explorer restarted" "SUCCESS"
goto :EOF

:: ============================================================================
:: EXIT HANDLING
:: ============================================================================

:EXIT_SCRIPT
echo [%DATE% %TIME%] Script completed with exit code: !EXIT_CODE! >> "!LOG_PATH!"

if "!EXIT_CODE!"=="0" (
    call :WRITE_STATUS "Script completed successfully" "SUCCESS"
) else (
    call :WRITE_STATUS "Script completed with errors" "ERROR"
)

endlocal
exit /b %EXIT_CODE%
