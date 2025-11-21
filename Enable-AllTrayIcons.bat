@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: WINDOWS SYSTEM TRAY ICONS CONFIGURATION TOOL - BAT VERSION
:: ============================================================================
::
:: Enterprise-grade batch script for managing system tray icon visibility.
:: Features comprehensive error handling and registry operations.
::
:: Author: Mikhail Deynekin (mid1977@gmail.com)
:: Repository: https://github.com/paulmann/windows-show-all-tray-icons
:: Version: 3.3 (BAT Edition)
::
:: Usage: Enable-AllTrayIcons.bat [ACTION] [OPTIONS]
::
:: ACTIONS:
::   Enable    Show all system tray icons (disable auto-hide)
::   Disable   Restore Windows default behavior (enable auto-hide) 
::   Status    Check current configuration without making changes
::   Backup    Create registry backup without making changes
::   Rollback  Revert to previous configuration if backup exists
::
:: OPTIONS:
::   /Restart  Automatically restart Windows Explorer to apply changes
::   /Backup   Create registry backup before making changes
::   /Force    Bypass confirmation prompts and warnings
::   /Help     Display this help information
::
:: EXAMPLES:
::   Enable-AllTrayIcons.bat Enable /Restart
::   Enable-AllTrayIcons.bat Status
::   Enable-AllTrayIcons.bat Backup
::   Enable-AllTrayIcons.bat Disable /Backup /Force
::
:: Note: All parameters are case-insensitive. Admin rights not required.
:: ============================================================================

:: Configuration
set "SCRIPT_VERSION=3.3"
set "SCRIPT_AUTHOR=Mikhail Deynekin (mid1977@gmail.com)"
set "SCRIPT_NAME=Enable-AllTrayIcons.bat"

set "REGISTRY_PATH=HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
set "REGISTRY_VALUE=EnableAutoTray"
set "ENABLE_VALUE=0"
set "DISABLE_VALUE=1"

set "BACKUP_PATH=%TEMP%\TrayIconsBackup.reg"
set "LOG_PATH=%TEMP%\Enable-AllTrayIcons.log"

set "EXIT_CODE=0"

:: Color codes
set "COLOR_RESET=[0m"
set "COLOR_RED=[91m"
set "COLOR_GREEN=[92m"
set "COLOR_YELLOW=[93m"
set "COLOR_CYAN=[96m"
set "COLOR_WHITE=[97m"
set "COLOR_GRAY=[90m"

:: Parse command line arguments
set "ACTION="
set "RESTART_EXPLORER=0"
set "BACKUP_REGISTRY=0"
set "FORCE_MODE=0"
set "SHOW_HELP=0"

:PARSE_ARGS
if "%~1"=="" goto :MAIN_EXECUTION

set "ARG=%~1"
set "ARG_UC=!ARG!"
call :TOUPPER ARG_UC

if "!ARG_UC!"=="HELP" set "SHOW_HELP=1"
if "!ARG_UC!"=="-HELP" set "SHOW_HELP=1"
if "!ARG_UC!"=="/HELP" set "SHOW_HELP=1"
if "!ARG_UC!"=="-?" set "SHOW_HELP=1"
if "!ARG_UC!"=="/?" set "SHOW_HELP=1"

if "!ARG_UC!"=="ENABLE" set "ACTION=ENABLE"
if "!ARG_UC!"=="DISABLE" set "ACTION=DISABLE"
if "!ARG_UC!"=="STATUS" set "ACTION=STATUS"
if "!ARG_UC!"=="BACKUP" set "ACTION=BACKUP"
if "!ARG_UC!"=="ROLLBACK" set "ACTION=ROLLBACK"

if "!ARG_UC!"=="RESTART" set "RESTART_EXPLORER=1"
if "!ARG_UC!"=="-RESTART" set "RESTART_EXPLORER=1"
if "!ARG_UC!"=="/RESTART" set "RESTART_EXPLORER=1"
if "!ARG_UC!"=="RESTARTEXPLORER" set "RESTART_EXPLORER=1"

if "!ARG_UC!"=="BACKUP" if "!ACTION!"=="" set "ACTION=BACKUP"
if "!ARG_UC!"=="-BACKUP" set "BACKUP_REGISTRY=1"
if "!ARG_UC!"=="/BACKUP" set "BACKUP_REGISTRY=1"
if "!ARG_UC!"=="BACKUPREGISTRY" set "BACKUP_REGISTRY=1"

if "!ARG_UC!"=="FORCE" set "FORCE_MODE=1"
if "!ARG_UC!"=="-FORCE" set "FORCE_MODE=1"
if "!ARG_UC!"=="/FORCE" set "FORCE_MODE=1"

shift
goto :PARSE_ARGS

:: ============================================================================
:: MAIN EXECUTION
:: ============================================================================
:MAIN_EXECUTION
call :INITIALIZE_LOGGING

if "!SHOW_HELP!"=="1" (
    call :SHOW_HELP
    goto :EXIT_SCRIPT
)

if "!ACTION!"=="" (
    call :SHOW_BANNER
    call :SHOW_APPLICATION_INFO
    goto :EXIT_SCRIPT
)

call :SHOW_BANNER

:: Execute the requested action
if "!ACTION!"=="STATUS" (
    call :SHOW_ENHANCED_STATUS
    goto :EXIT_SCRIPT
)

if "!ACTION!"=="BACKUP" (
    call :SHOW_HEADER "Create Registry Backup" "Saving current configuration"
    call :BACKUP_REGISTRY_CONFIGURATION
    goto :EXIT_SCRIPT
)

if "!ACTION!"=="ENABLE" (
    call :SHOW_HEADER "Enable All Tray Icons" "Making all icons always visible"
    call :SET_TRAY_ICON_CONFIGURATION ENABLE
    if "!EXIT_CODE!"=="0" if "!RESTART_EXPLORER!"=="1" (
        call :WRITE_STATUS "Applying changes immediately..." "INFO"
        call :RESTART_WINDOWS_EXPLORER_SAFELY
    )
    goto :EXIT_SCRIPT
)

if "!ACTION!"=="DISABLE" (
    call :SHOW_HEADER "Restore Default Behavior" "Enabling auto-hide for tray icons"
    call :SET_TRAY_ICON_CONFIGURATION DISABLE
    if "!EXIT_CODE!"=="0" if "!RESTART_EXPLORER!"=="1" (
        call :WRITE_STATUS "Applying changes immediately..." "INFO"
        call :RESTART_WINDOWS_EXPLORER_SAFELY
    )
    goto :EXIT_SCRIPT
)

if "!ACTION!"=="ROLLBACK" (
    call :SHOW_HEADER "Configuration Rollback" "Reverting to previous settings"
    call :INVOKE_CONFIGURATION_ROLLBACK
    if "!EXIT_CODE!"=="0" if "!RESTART_EXPLORER!"=="1" (
        call :WRITE_STATUS "Applying changes immediately..." "INFO"
        call :RESTART_WINDOWS_EXPLORER_SAFELY
    )
    goto :EXIT_SCRIPT
)

call :WRITE_STATUS "Unknown action: !ACTION!" "ERROR"
set "EXIT_CODE=1"
goto :EXIT_SCRIPT

:: ============================================================================
:: CORE FUNCTIONS
:: ============================================================================

:INITIALIZE_LOGGING
echo [%DATE% %TIME%] Script started: %SCRIPT_NAME% v%SCRIPT_VERSION% > "%LOG_PATH%"
echo [%DATE% %TIME%] User: %USERNAME% >> "%LOG_PATH%"
echo [%DATE% %TIME%] Computer: %COMPUTERNAME% >> "%LOG_PATH%"
goto :EOF

:SHOW_BANNER
echo.
echo ================================================================
echo    WINDOWS SYSTEM TRAY ICONS CONFIGURATION TOOL
echo ================================================================
echo.
goto :EOF

:SHOW_HEADER
set "TITLE=%~1"
set "SUBTITLE=%~2"
echo.
echo ================================================================
echo    !TITLE! - !SUBTITLE!
echo ================================================================
echo.
goto :EOF

:WRITE_STATUS
set "MESSAGE=%~1"
set "TYPE=%~2"
set "COLOR=!COLOR_WHITE!"

if "!TYPE!"=="SUCCESS" set "COLOR=!COLOR_GREEN!"
if "!TYPE!"=="ERROR" set "COLOR=!COLOR_RED!"
if "!TYPE!"=="WARNING" set "COLOR=!COLOR_YELLOW!"
if "!TYPE!"=="INFO" set "COLOR=!COLOR_CYAN!"

set "PREFIX=  "
if "!TYPE!"=="SUCCESS" set "PREFIX=  [OK] "
if "!TYPE!"=="ERROR" set "PREFIX=  [ERROR] "
if "!TYPE!"=="WARNING" set "PREFIX=  [WARN] "
if "!TYPE!"=="INFO" set "PREFIX=  [INFO] "

echo !PREFIX!!MESSAGE!
echo [%DATE% %TIME%] [!TYPE!] !MESSAGE! >> "%LOG_PATH%"
goto :EOF

:SHOW_CARD
set "TITLE=%~1"
set "VALUE=%~2"
set "VALUE_COLOR=%~3"
if "!VALUE_COLOR!"=="" set "VALUE_COLOR=WHITE"

set "DISPLAY_COLOR=!COLOR_!VALUE_COLOR!!"
echo   [*] !TITLE! ^| !DISPLAY_COLOR!!VALUE!!COLOR_RESET!
goto :EOF

:: ============================================================================
:: HELP SYSTEM
:: ============================================================================

:SHOW_HELP
call :SHOW_BANNER
call :SHOW_HEADER "Windows System Tray Icons Configuration Tool" "v%SCRIPT_VERSION%"

echo DESCRIPTION:
echo   Professional tool for managing system tray icon visibility in Windows 10/11.
echo   Modifies registry settings to control notification area behavior.
echo.

echo USAGE:
echo   %SCRIPT_NAME% [ACTION] [OPTIONS]
echo.

echo QUICK COMMANDS:
call :SHOW_CARD "Show All Icons" "%SCRIPT_NAME% Enable"
call :SHOW_CARD "Restore Default" "%SCRIPT_NAME% Disable" 
call :SHOW_CARD "Check Status" "%SCRIPT_NAME% Status"
call :SHOW_CARD "Create Backup" "%SCRIPT_NAME% Backup"
call :SHOW_CARD "Show Help" "%SCRIPT_NAME% Help"
echo.

echo ACTION PARAMETERS:
call :SHOW_CARD "Enable" "Show all system tray icons"
call :SHOW_CARD "Disable" "Restore Windows default behavior"
call :SHOW_CARD "Status" "Display current configuration"
call :SHOW_CARD "Backup" "Create registry backup"
call :SHOW_CARD "Rollback" "Revert to previous configuration"
echo.

echo OPTIONAL PARAMETERS:
call :SHOW_CARD "/Restart" "Apply changes immediately"
call :SHOW_CARD "/Backup" "Create backup before changes"
call :SHOW_CARD "/Force" "Bypass confirmation prompts"
call :SHOW_CARD "/Help" "Display this help message"
echo.

echo EXAMPLES:
echo   %SCRIPT_NAME% Enable /Restart
echo     # Enable all icons and restart Explorer immediately
echo.
echo   %SCRIPT_NAME% Status
echo     # Display current system configuration
echo.
echo   %SCRIPT_NAME% Backup
echo     # Create registry backup without changes
echo.
echo   %SCRIPT_NAME% Disable /Backup /Force
echo     # Restore defaults with backup, no prompts
echo.

echo ADDITIONAL INFORMATION:
call :SHOW_CARD "Version" "%SCRIPT_VERSION%"
call :SHOW_CARD "Author" "%SCRIPT_AUTHOR%"
call :SHOW_CARD "Repository" "https://github.com/paulmann/windows-show-all-tray-icons"
call :SHOW_CARD "Compatibility" "Windows 10/11, Server 2019+"
echo.

echo Note: All parameters are case-insensitive. Admin rights not required.
echo.
goto :EOF

:SHOW_APPLICATION_INFO
call :SHOW_HEADER "Application Information" "v%SCRIPT_VERSION%"

call :SHOW_CARD "Script Name" "%SCRIPT_NAME%"
call :SHOW_CARD "Version" "%SCRIPT_VERSION%"
call :SHOW_CARD "Author" "%SCRIPT_AUTHOR%"
call :SHOW_CARD "Repository" "https://github.com/paulmann/windows-show-all-tray-icons"
call :SHOW_CARD "Compatibility" "Windows 10/11, Server 2019+"
call :SHOW_CARD "Windows Version" "!OS_VERSION!"
echo.

echo Use 'Help' for detailed usage information.
echo.
goto :EOF

:: ============================================================================
:: STATUS DISPLAY
:: ============================================================================

:SHOW_ENHANCED_STATUS
call :SHOW_HEADER "System Status" "Current Tray Icons Configuration"

call :GET_CURRENT_TRAY_CONFIGURATION
set "CURRENT_CONFIG=!ERRORLEVEL!"

echo CONFIGURATION STATUS:
if "!CURRENT_CONFIG!"=="255" (
    call :SHOW_CARD "Tray Icons Behavior" "Auto-hide inactive icons (Windows default)" "GREEN"
    call :SHOW_CARD "Registry Value" "Not configured - using system default" "CYAN"
) else (
    if "!CURRENT_CONFIG!"=="!ENABLE_VALUE!" (
        call :SHOW_CARD "Tray Icons Behavior" "Show ALL tray icons (auto-hide disabled)" "GREEN"
    ) else (
        call :SHOW_CARD "Tray Icons Behavior" "Auto-hide inactive icons (Windows default)" "GREEN"
    )
    call :SHOW_CARD "Registry Value" "!CURRENT_CONFIG!" "WHITE"
)
echo.

echo SYSTEM INFORMATION:
for /f "tokens=*" %%i in ('ver') do set "OS_VERSION=%%i"
call :SHOW_CARD "Operating System" "Windows"
call :SHOW_CARD "OS Version" "!OS_VERSION!"
call :SHOW_CARD "Computer Name" "%COMPUTERNAME%"
call :SHOW_CARD "User Name" "%USERNAME%"
echo.

echo SESSION CONTEXT:
call :SHOW_CARD "Current User" "%USERNAME%"
call :SHOW_CARD "Computer" "%COMPUTERNAME%"
call :SHOW_CARD "Admin Rights" "Not checked in BAT version" "YELLOW"
echo.

echo BACKUP STATUS:
if exist "!BACKUP_PATH!" (
    call :SHOW_CARD "Backup Available" "Yes" "GREEN"
    for %%F in ("!BACKUP_PATH!") do (
        call :SHOW_CARD "Backup Created" "%%~tF"
    )
) else (
    call :SHOW_CARD "Backup Available" "No" "CYAN"
)
echo.

echo Use 'Enable' to show all icons or 'Disable' for default behavior.
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

:SET_TRAY_ICON_CONFIGURATION
set "BEHAVIOR=%~1"
set "VALUE=!DISABLE_VALUE!"

if "!BEHAVIOR!"=="ENABLE" set "VALUE=!ENABLE_VALUE!"
if "!BEHAVIOR!"=="DISABLE" set "VALUE=!DISABLE_VALUE!"

set "DESCRIPTION=Enable auto-hide (Windows default)"
if "!BEHAVIOR!"=="ENABLE" set "DESCRIPTION=Show all tray icons"

call :WRITE_STATUS "Configuring tray behavior: !DESCRIPTION!" "INFO"

:: Create backup if requested
if "!BACKUP_REGISTRY!"=="1" (
    call :WRITE_STATUS "Creating registry backup before changes..." "INFO"
    call :BACKUP_REGISTRY_CONFIGURATION
)

:: Ensure registry path exists
reg query "!REGISTRY_PATH!" >nul 2>&1
if !errorlevel! neq 0 (
    call :WRITE_STATUS "Creating registry path: !REGISTRY_PATH!" "INFO"
    reg add "!REGISTRY_PATH!" /f >nul 2>&1
)

:: Set registry value
reg add "!REGISTRY_PATH!" /v "!REGISTRY_VALUE!" /t REG_DWORD /d "!VALUE!" /f >nul 2>&1
if !errorlevel! neq 0 (
    call :WRITE_STATUS "Failed to configure registry" "ERROR"
    set "EXIT_CODE=1"
    goto :EOF
)

call :WRITE_STATUS "Registry configuration updated successfully: !DESCRIPTION!" "SUCCESS"

if "!RESTART_EXPLORER!"=="0" (
    call :WRITE_STATUS "Configuration updated successfully!" "SUCCESS"
    call :WRITE_STATUS "Restart Explorer or use /Restart to apply changes" "INFO"
)
goto :EOF

:BACKUP_REGISTRY_CONFIGURATION
:: Check if backup already exists
if exist "!BACKUP_PATH!" (
    if "!FORCE_MODE!"=="0" (
        call :WRITE_STATUS "Backup already exists: !BACKUP_PATH!" "WARNING"
        call :WRITE_STATUS "Use /Force to overwrite existing backup" "INFO"
        exit /b 1
    ) else (
        call :WRITE_STATUS "Overwriting existing backup..." "WARNING"
    )
)

call :GET_CURRENT_TRAY_CONFIGURATION
set "CURRENT_CONFIG=!ERRORLEVEL!"

:: Create backup file
(
echo Windows Registry Editor Version 5.00
echo.
echo [!REGISTRY_PATH!]
echo "!REGISTRY_VALUE!"=dword:!CURRENT_CONFIG!
echo.
)> "!BACKUP_PATH!" 2>nul

if !errorlevel! neq 0 (
    call :WRITE_STATUS "Failed to create registry backup" "ERROR"
    exit /b 1
)

call :WRITE_STATUS "Registry configuration backed up to: !BACKUP_PATH!" "SUCCESS"

:: Display backup information
call :SHOW_CARD "Backup Location" "!BACKUP_PATH!"
call :SHOW_CARD "Backup Time" "%DATE% %TIME%"
if "!CURRENT_CONFIG!"=="255" (
    call :SHOW_CARD "Original Value" "Not Set (Default)"
) else (
    call :SHOW_CARD "Original Value" "!CURRENT_CONFIG!"
)
goto :EOF

:INVOKE_CONFIGURATION_ROLLBACK
if not exist "!BACKUP_PATH!" (
    call :WRITE_STATUS "No backup found for rollback: !BACKUP_PATH!" "ERROR"
    set "EXIT_CODE=5"
    goto :EOF
)

call :WRITE_STATUS "Attempting rollback to previous configuration..." "INFO"

:: Import backup registry file
reg import "!BACKUP_PATH!" >nul 2>&1
if !errorlevel! neq 0 (
    call :WRITE_STATUS "Rollback failed" "ERROR"
    set "EXIT_CODE=5"
    goto :EOF
)

call :WRITE_STATUS "Configuration restored from backup successfully!" "SUCCESS"

:: Remove backup file after successful rollback
del "!BACKUP_PATH!" >nul 2>&1
call :WRITE_STATUS "Backup file removed after successful rollback" "INFO"
goto :EOF

:: ============================================================================
:: EXPLORER MANAGEMENT
:: ============================================================================

:RESTART_WINDOWS_EXPLORER_SAFELY
call :WRITE_STATUS "Initiating safe Windows Explorer restart..." "INFO"

:: Check if Explorer is running
tasklist /fi "imagename eq explorer.exe" | find /i "explorer.exe" >nul
if !errorlevel! neq 0 (
    call :WRITE_STATUS "Windows Explorer not running, starting process..." "WARNING"
    start "" explorer.exe
    timeout /t 2 /nobreak >nul
    call :WRITE_STATUS "Windows Explorer started successfully" "SUCCESS"
    goto :EOF
)

:: Stop Explorer processes
call :WRITE_STATUS "Stopping Windows Explorer processes..." "INFO"
taskkill /f /im explorer.exe >nul 2>&1

:: Wait for processes to terminate
set "TIMEOUT=10"
set "TIMER=0"
:WAIT_FOR_EXPLORER_STOP
tasklist /fi "imagename eq explorer.exe" | find /i "explorer.exe" >nul
if !errorlevel! neq 0 goto :START_EXPLORER
timeout /t 1 /nobreak >nul
set /a TIMER+=1
if !TIMER! geq !TIMEOUT! goto :START_EXPLORER
goto :WAIT_FOR_EXPLORER_STOP

:START_EXPLORER
:: Start Explorer
call :WRITE_STATUS "Starting Windows Explorer..." "INFO"
start "" explorer.exe

:: Wait for initialization
timeout /t 2 /nobreak >nul

:: Verify Explorer started
tasklist /fi "imagename eq explorer.exe" | find /i "explorer.exe" >nul
if !errorlevel! neq 0 (
    call :WRITE_STATUS "Windows Explorer may not have started properly" "WARNING"
    exit /b 1
)

call :WRITE_STATUS "Windows Explorer restarted successfully" "SUCCESS"
goto :EOF

:: ============================================================================
:: UTILITY FUNCTIONS
:: ============================================================================

:TOUPPER
set "VAR=!%~1!"
for %%a in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    set "VAR=!VAR:%%a=%%a!"
)
set "%~1=!VAR!"
goto :EOF

:: ============================================================================
:: EXIT HANDLING
:: ============================================================================

:EXIT_SCRIPT
echo [%DATE% %TIME%] Script completed with exit code: !EXIT_CODE! >> "%LOG_PATH%"

if "!EXIT_CODE!"=="0" (
    call :WRITE_STATUS "Script completed successfully" "SUCCESS"
) else (
    call :WRITE_STATUS "Script completed with errors (Exit Code: !EXIT_CODE!)" "ERROR"
)

endlocal
exit /b %EXIT_CODE%
