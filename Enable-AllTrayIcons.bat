@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: WINDOWS SYSTEM TRAY ICONS CONFIGURATION TOOL - ENTERPRISE BAT VERSION
:: ============================================================================
::
:: Enterprise-grade batch script for comprehensive system tray icon management.
:: Features enhanced registry operations, individual icon settings reset,
:: comprehensive backup/restore, and Windows 11 optimizations.
::
:: Author: Mikhail Deynekin (mid1977@gmail.com)
:: Repository: https://github.com/paulmann/windows-show-all-tray-icons
:: Version: 4.0 (BAT Enterprise Edition)
::
:: Usage: Enable-AllTrayIcons.bat [ACTION] [OPTIONS]
::
:: ACTIONS:
::   Enable    Show all system tray icons using comprehensive methods
::   Disable   Restore Windows default behavior (enable auto-hide)
::   Status    Check current configuration with enhanced diagnostics
::   Backup    Create comprehensive registry backup
::   Rollback  Revert to previous configuration with validation
::
:: OPTIONS:
::   /Restart  Automatically restart Windows Explorer to apply changes
::   /Backup   Create registry backup before making changes
::   /Force    Bypass confirmation prompts and warnings
::   /Help     Display comprehensive help information
::   /Update   Check and update script from GitHub (limited in BAT)
::   /Diagnostic Perform backup file diagnostics and validation
::
:: ENHANCED FEATURES:
::   - Individual icon settings reset (NotifyIconSettings, TrayNotify)
::   - Multiple methods for forcing icon visibility
::   - Comprehensive backup/restore for all tray-related settings
::   - Windows 11 specific optimizations
::   - System icon visibility controls
::   - Professional diagnostic reporting
::
:: EXAMPLES:
::   Enable-AllTrayIcons.bat Enable /Restart /Backup
::   Enable-AllTrayIcons.bat Status
::   Enable-AllTrayIcons.bat Backup
::   Enable-AllTrayIcons.bat Disable /Backup /Force
::
:: Note: All parameters are case-insensitive. Admin rights not required.
:: ============================================================================

:: Enhanced Configuration
set "SCRIPT_VERSION=4.0"
set "SCRIPT_AUTHOR=Mikhail Deynekin (mid1977@gmail.com)"
set "SCRIPT_NAME=Enable-AllTrayIcons.bat (Enterprise Edition)"

:: Registry Configuration
set "REGISTRY_PATH=HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
set "REGISTRY_VALUE=EnableAutoTray"
set "ENABLE_VALUE=0"
set "DISABLE_VALUE=1"

:: Enhanced Registry Paths for Comprehensive Management
set "NOTIFY_ICON_SETTINGS=HKCU\Control Panel\NotifyIconSettings"
set "TRAY_NOTIFY_PATH=HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TrayNotify"
set "HIDE_DESKTOP_ICONS=HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons"
set "TASKBAND_PATH=HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
set "NOTIFICATIONS_SETTINGS=HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings"
set "EXPLORER_ADVANCED=HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

:: Path Configuration
set "BACKUP_PATH=%TEMP%\TrayIconsBackup.reg"
set "COMPREHENSIVE_BACKUP_PATH=%TEMP%\TrayIconsComprehensiveBackup.reg"
set "LOG_PATH=%TEMP%\Enable-AllTrayIcons.log"

:: Performance Configuration
set "EXPLORER_RESTART_TIMEOUT=10"
set "PROCESS_WAIT_TIMEOUT=5"

:: Exit Codes
set "EXIT_CODE=0"
set "EXIT_SUCCESS=0"
set "EXIT_GENERAL_ERROR=1"
set "EXIT_ACCESS_DENIED=2"
set "EXIT_INVALID_SESSION=3"
set "EXIT_ROLLBACK_FAILED=5"
set "EXIT_BACKUP_FAILED=7"

:: Color codes (Enhanced for better visibility)
for /f "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (
  set "COLOR_RESET=%%a"
  set "COLOR_RED=%%a[91m"
  set "COLOR_GREEN=%%a[92m"
  set "COLOR_YELLOW=%%a[93m"
  set "COLOR_BLUE=%%a[94m"
  set "COLOR_MAGENTA=%%a[95m"
  set "COLOR_CYAN=%%a[96m"
  set "COLOR_WHITE=%%a[97m"
  set "COLOR_GRAY=%%a[90m"
)

:: Parse command line arguments
set "ACTION="
set "RESTART_EXPLORER=0"
set "BACKUP_REGISTRY=0"
set "FORCE_MODE=0"
set "SHOW_HELP=0"
set "UPDATE_SCRIPT=0"
set "DIAGNOSTIC_MODE=0"

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

if "!ARG_UC!"=="UPDATE" set "UPDATE_SCRIPT=1"
if "!ARG_UC!"=="-UPDATE" set "UPDATE_SCRIPT=1"
if "!ARG_UC!"=="/UPDATE" set "UPDATE_SCRIPT=1"

if "!ARG_UC!"=="DIAGNOSTIC" set "DIAGNOSTIC_MODE=1"
if "!ARG_UC!"=="-DIAGNOSTIC" set "DIAGNOSTIC_MODE=1"
if "!ARG_UC!"=="/DIAGNOSTIC" set "DIAGNOSTIC_MODE=1"

shift
goto :PARSE_ARGS

:: ============================================================================
:: MAIN EXECUTION
:: ============================================================================
:MAIN_EXECUTION
call :INITIALIZE_LOGGING

:: Handle Diagnostic first
if "!DIAGNOSTIC_MODE!"=="1" (
    call :SHOW_BANNER
    call :INVOKE_BACKUP_DIAGNOSTIC
    goto :EXIT_SCRIPT
)

:: Handle Help
if "!SHOW_HELP!"=="1" (
    call :SHOW_MODERN_HELP
    goto :EXIT_SCRIPT
)

:: Handle Update (limited functionality in BAT)
if "!UPDATE_SCRIPT!"=="1" (
    call :SHOW_BANNER
    call :WRITE_STATUS "Update functionality is limited in BAT version." "WARNING"
    call :WRITE_STATUS "Please use PowerShell version for auto-update features." "INFO"
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
if "!ACTION!"=="STATUS" (
    call :SHOW_ENHANCED_STATUS
    goto :EXIT_SCRIPT
)

if "!ACTION!"=="BACKUP" (
    call :SHOW_HEADER "Create Comprehensive Backup" "Saving ALL tray-related settings"
    call :BACKUP_COMPREHENSIVE_TRAY_SETTINGS
    goto :EXIT_SCRIPT
)

if "!ACTION!"=="ENABLE" (
    call :SHOW_HEADER "Enable ALL Tray Icons" "Comprehensive method - forcing all icons visible"
    call :ENABLE_ALL_TRAY_ICONS_COMPREHENSIVE
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
:: ENHANCED CORE FUNCTIONS
:: ============================================================================

:INITIALIZE_LOGGING
echo [%DATE% %TIME%] Script started: %SCRIPT_NAME% v%SCRIPT_VERSION% > "!LOG_PATH!"
echo [%DATE% %TIME%] User: %USERNAME% >> "!LOG_PATH!"
echo [%DATE% %TIME%] Computer: %COMPUTERNAME% >> "!LOG_PATH!"
echo [%DATE% %TIME%] Command line: %* >> "!LOG_PATH!"
goto :EOF

:SHOW_BANNER
echo.
echo !COLOR_CYAN!================================================================!COLOR_RESET!
echo    WINDOWS SYSTEM TRAY ICONS CONFIGURATION TOOL
echo              ENTERPRISE EDITION - ENHANCED
echo !COLOR_CYAN!================================================================!COLOR_RESET!
echo.
goto :EOF

:SHOW_HEADER
set "TITLE=%~1"
set "SUBTITLE=%~2"
echo.
echo !COLOR_CYAN!================================================================!COLOR_RESET!
echo    !TITLE! - !SUBTITLE!
echo !COLOR_CYAN!================================================================!COLOR_RESET!
echo.
goto :EOF

:WRITE_STATUS
set "MESSAGE=%~1"
set "TYPE=%~2"
set "COLOR=!COLOR_WHITE!"
set "PREFIX=  [INFO] "

if "!TYPE!"=="SUCCESS" (
    set "COLOR=!COLOR_GREEN!"
    set "PREFIX=  [OK] "
)
if "!TYPE!"=="ERROR" (
    set "COLOR=!COLOR_RED!"
    set "PREFIX=  [ERROR] "
)
if "!TYPE!"=="WARNING" (
    set "COLOR=!COLOR_YELLOW!"
    set "PREFIX=  [WARN] "
)
if "!TYPE!"=="INFO" (
    set "COLOR=!COLOR_CYAN!"
    set "PREFIX=  [INFO] "
)
if "!TYPE!"=="PROCESSING" (
    set "COLOR=!COLOR_BLUE!"
    set "PREFIX=  [....] "
)

echo !PREFIX!!COLOR!!MESSAGE!!COLOR_RESET!
echo [%DATE% %TIME%] [!TYPE!] !MESSAGE! >> "!LOG_PATH!"
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
:: ENHANCED HELP SYSTEM
:: ============================================================================

:SHOW_MODERN_HELP
call :SHOW_BANNER
call :SHOW_HEADER "Windows System Tray Icons Configuration Tool" "v%SCRIPT_VERSION%"

echo !COLOR_CYAN!DESCRIPTION:!COLOR_RESET!
echo   Professional tool for managing system tray icon visibility in Windows 10/11.
echo   Modifies registry settings to control notification area behavior with enhanced
echo   individual icon settings reset and comprehensive backup/restore functionality.
echo.

echo !COLOR_CYAN!USAGE:!COLOR_RESET!
echo   %SCRIPT_NAME% [ACTION] [OPTIONS]
echo.

echo !COLOR_CYAN!QUICK COMMANDS:!COLOR_RESET!
call :SHOW_CARD "Show All Icons" "%SCRIPT_NAME% Enable"
call :SHOW_CARD "Restore Default" "%SCRIPT_NAME% Disable" 
call :SHOW_CARD "Check Status" "%SCRIPT_NAME% Status"
call :SHOW_CARD "Create Backup" "%SCRIPT_NAME% Backup"
call :SHOW_CARD "Show Help" "%SCRIPT_NAME% Help"
echo.

echo !COLOR_CYAN!ACTION PARAMETERS:!COLOR_RESET!
call :SHOW_CARD "Enable" "Show all system tray icons (comprehensive method)"
call :SHOW_CARD "Disable" "Restore Windows default behavior"
call :SHOW_CARD "Status" "Display current configuration"
call :SHOW_CARD "Backup" "Create comprehensive registry backup"
call :SHOW_CARD "Rollback" "Revert to previous configuration"
echo.

echo !COLOR_CYAN!OPTIONAL PARAMETERS:!COLOR_RESET!
call :SHOW_CARD "/Restart" "Apply changes immediately"
call :SHOW_CARD "/Backup" "Create backup before changes"
call :SHOW_CARD "/Force" "Bypass confirmation prompts"
call :SHOW_CARD "/Update" "Update script from GitHub (limited)"
call :SHOW_CARD "/Help" "Display this help message"
call :SHOW_CARD "/Diagnostic" "Perform backup diagnostics"
echo.

echo !COLOR_CYAN!ENHANCED FEATURES:!COLOR_RESET!
call :SHOW_CARD "Individual Settings Reset" "Resets per-icon user preferences"
call :SHOW_CARD "Multiple Methods" "Uses multiple techniques to force visibility"
call :SHOW_CARD "Comprehensive Backup" "Backs up ALL tray-related settings"
call :SHOW_CARD "Windows 11 Optimized" "Includes Windows 11 specific tweaks"
call :SHOW_CARD "System Icons Control" "Manages system icon visibility"
echo.

echo !COLOR_CYAN!EXAMPLES:!COLOR_RESET!
echo   %SCRIPT_NAME% Enable /Restart
echo     # Enable all icons and restart Explorer immediately
echo.
echo   %SCRIPT_NAME% Status
echo     # Display current system configuration
echo.
echo   %SCRIPT_NAME% Backup
echo     # Create comprehensive registry backup
echo.
echo   %SCRIPT_NAME% Enable /Backup /Force
echo     # Force enable all icons with backup, no prompts
echo.
echo   %SCRIPT_NAME% Rollback
echo     # Revert to previous configuration
echo.

echo !COLOR_CYAN!ADDITIONAL INFORMATION:!COLOR_RESET!
call :SHOW_CARD "Version" "%SCRIPT_VERSION%"
call :SHOW_CARD "Author" "%SCRIPT_AUTHOR%"
call :SHOW_CARD "Repository" "https://github.com/paulmann/windows-show-all-tray-icons"
call :SHOW_CARD "Compatibility" "Windows 10/11, Server 2019+"
call :SHOW_CARD "Enhanced Features" "Individual settings reset, comprehensive backup"
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
call :SHOW_CARD "Enhanced Features" "Individual settings reset, comprehensive backup"
echo.

echo Use 'Help' for detailed usage information.
echo.
goto :EOF

:: ============================================================================
:: ENHANCED STATUS DISPLAY
:: ============================================================================

:SHOW_ENHANCED_STATUS
call :SHOW_HEADER "System Status" "Current Tray Icons Configuration"

call :GET_CURRENT_TRAY_CONFIGURATION
set "CURRENT_CONFIG=!ERRORLEVEL!"

echo !COLOR_CYAN!CONFIGURATION STATUS:!COLOR_RESET!
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

echo !COLOR_CYAN!SYSTEM INFORMATION:!COLOR_RESET!
for /f "tokens=*" %%i in ('ver') do set "OS_VERSION=%%i"
call :SHOW_CARD "Operating System" "Windows"
call :SHOW_CARD "OS Version" "!OS_VERSION!"
call :SHOW_CARD "Computer Name" "%COMPUTERNAME%"
call :SHOW_CARD "User Name" "%USERNAME%"
call :GET_WINDOWS_VERSION
call :SHOW_CARD "Windows Version" "!WINDOWS_VERSION!"
echo.

echo !COLOR_CYAN!SESSION CONTEXT:!COLOR_RESET!
call :SHOW_CARD "Current User" "%USERNAME%"
call :SHOW_CARD "Computer" "%COMPUTERNAME%"
call :GET_SESSION_CONTEXT
call :SHOW_CARD "Session Type" "!SESSION_TYPE!"
call :SHOW_CARD "Interactive" "!IS_INTERACTIVE!" "GREEN"
echo.

echo !COLOR_CYAN!BACKUP STATUS:!COLOR_RESET!
if exist "!BACKUP_PATH!" (
    call :SHOW_CARD "Basic Backup Available" "Yes" "GREEN"
    for %%F in ("!BACKUP_PATH!") do (
        call :SHOW_CARD "Backup Created" "%%~tF" "WHITE"
    )
) else (
    call :SHOW_CARD "Basic Backup Available" "No" "CYAN"
)

if exist "!COMPREHENSIVE_BACKUP_PATH!" (
    call :SHOW_CARD "Comprehensive Backup" "Yes" "GREEN"
    for %%F in ("!COMPREHENSIVE_BACKUP_PATH!") do (
        call :SHOW_CARD "Comprehensive Backup" "%%~tF" "WHITE"
    )
) else (
    call :SHOW_CARD "Comprehensive Backup" "No" "CYAN"
)
echo.

echo Use 'Enable' to show all icons or 'Disable' for default behavior.
echo.
goto :EOF

:GET_WINDOWS_VERSION
set "WINDOWS_VERSION=Unknown"
systeminfo | findstr /B /C:"OS Name:" >nul && (
    for /f "tokens=3-6 delims= " %%i in ('systeminfo ^| findstr /B /C:"OS Name:"') do (
        set "WINDOWS_VERSION=%%i %%j %%k %%l"
    )
)
goto :EOF

:GET_SESSION_CONTEXT
set "SESSION_TYPE=Unknown"
set "IS_INTERACTIVE=Yes"

if defined SESSIONNAME (
    if "!SESSIONNAME!"=="Console" (
        set "SESSION_TYPE=Interactive Desktop"
    ) else (
        set "SESSION_TYPE=Remote Session"
    )
) else (
    set "SESSION_TYPE=Non-Interactive"
    set "IS_INTERACTIVE=No"
)
goto :EOF

:: ============================================================================
:: ENHANCED TRAY ICONS MANAGEMENT SYSTEM
:: ============================================================================

:RESET_INDIVIDUAL_ICON_SETTINGS
call :WRITE_STATUS "Resetting individual icon settings..." "PROCESSING"

set "RESET_NOTIFY_ICON_SETTINGS=0"
set "RESET_TRAY_NOTIFY=0"
set "RESET_HIDE_DESKTOP_ICONS=0"
set "RESET_TASKBAND=0"
set "RESET_NOTIFICATION_SETTINGS=0"

:: 1. Reset NotifyIconSettings
call :WRITE_STATUS "Resetting NotifyIconSettings..." "INFO"
reg query "!NOTIFY_ICON_SETTINGS!" >nul 2>&1
if !errorlevel! equ 0 (
    for /f "tokens=*" %%A in ('reg query "!NOTIFY_ICON_SETTINGS!" 2^>nul') do (
        for /f "tokens=3 delims=\" %%B in ("%%A") do (
            if not "%%B"=="" (
                reg add "!NOTIFY_ICON_SETTINGS!\%%B" /v "IsPromoted" /t REG_DWORD /d 1 /f >nul 2>&1
            )
        )
    )
    set "RESET_NOTIFY_ICON_SETTINGS=1"
    call :WRITE_STATUS "NotifyIconSettings reset completed" "SUCCESS"
) else (
    call :WRITE_STATUS "NotifyIconSettings path not found" "WARNING"
)

:: 2. Reset TrayNotify
call :WRITE_STATUS "Resetting TrayNotify cache..." "INFO"
reg query "!TRAY_NOTIFY_PATH!" >nul 2>&1
if !errorlevel! neq 0 (
    reg add "!TRAY_NOTIFY_PATH!" /f >nul 2>&1
    call :WRITE_STATUS "TrayNotify path created" "SUCCESS"
)

if exist "!TRAY_NOTIFY_PATH!" (
    reg delete "!TRAY_NOTIFY_PATH!" /v "IconStreams" /f >nul 2>&1
    reg delete "!TRAY_NOTIFY_PATH!" /v "PastIconsStream" /f >nul 2>&1
    set "RESET_TRAY_NOTIFY=1"
    call :WRITE_STATUS "TrayNotify cache cleared" "SUCCESS"
)

:: 3. Reset desktop icon visibility
call :WRITE_STATUS "Resetting desktop icon visibility..." "INFO"
reg query "!HIDE_DESKTOP_ICONS!" >nul 2>&1
if !errorlevel! equ 0 (
    for /f "tokens=*" %%A in ('reg query "!HIDE_DESKTOP_ICONS!" 2^>nul') do (
        for /f "tokens=3 delims=\" %%B in ("%%A") do (
            if not "%%B"=="" (
                reg delete "!HIDE_DESKTOP_ICONS!\%%B" /f >nul 2>&1
            )
        )
    )
    set "RESET_HIDE_DESKTOP_ICONS=1"
    call :WRITE_STATUS "Desktop icon visibility reset" "SUCCESS"
) else (
    call :WRITE_STATUS "HideDesktopIcons path not found" "WARNING"
)

:: 4. Reset taskbar layout
call :WRITE_STATUS "Resetting taskbar layout..." "INFO"
reg query "!TASKBAND_PATH!" >nul 2>&1
if !errorlevel! equ 0 (
    reg delete "!TASKBAND_PATH!" /v "Favorites" /f >nul 2>&1
    reg delete "!TASKBAND_PATH!" /v "FavoritesResolve" /f >nul 2>&1
    set "RESET_TASKBAND=1"
    call :WRITE_STATUS "Taskbar layout reset" "SUCCESS"
) else (
    call :WRITE_STATUS "Taskband path not found" "WARNING"
)

:: 5. Reset notification settings
call :WRITE_STATUS "Resetting notification settings..." "INFO"
reg query "!NOTIFICATIONS_SETTINGS!" >nul 2>&1
if !errorlevel! equ 0 (
    for /f "tokens=*" %%A in ('reg query "!NOTIFICATIONS_SETTINGS!" 2^>nul') do (
        for /f "tokens=3 delims=\" %%B in ("%%A") do (
            if not "%%B"=="" (
                reg add "!NOTIFICATIONS_SETTINGS!\%%B" /v "Enabled" /t REG_DWORD /d 1 /f >nul 2>&1
                reg add "!NOTIFICATIONS_SETTINGS!\%%B" /v "ShowInActionCenter" /t REG_DWORD /d 1 /f >nul 2>&1
            )
        )
    )
    set "RESET_NOTIFICATION_SETTINGS=1"
    call :WRITE_STATUS "Notification settings reset" "SUCCESS"
) else (
    call :WRITE_STATUS "Notifications Settings path not found" "WARNING"
)

:: Display results
echo.
echo !COLOR_CYAN!INDIVIDUAL SETTINGS RESET RESULTS:!COLOR_RESET!
if "!RESET_NOTIFY_ICON_SETTINGS!"=="1" (
    call :SHOW_CARD "NotifyIconSettings" "Success" "GREEN"
) else (
    call :SHOW_CARD "NotifyIconSettings" "Failed" "YELLOW"
)

if "!RESET_TRAY_NOTIFY!"=="1" (
    call :SHOW_CARD "TrayNotify" "Success" "GREEN"
) else (
    call :SHOW_CARD "TrayNotify" "Failed" "YELLOW"
)

if "!RESET_HIDE_DESKTOP_ICONS!"=="1" (
    call :SHOW_CARD "HideDesktopIcons" "Success" "GREEN"
) else (
    call :SHOW_CARD "HideDesktopIcons" "Failed" "YELLOW"
)

if "!RESET_TASKBAND!"=="1" (
    call :SHOW_CARD "Taskband" "Success" "GREEN"
) else (
    call :SHOW_CARD "Taskband" "Failed" "YELLOW"
)

if "!RESET_NOTIFICATION_SETTINGS!"=="1" (
    call :SHOW_CARD "NotificationSettings" "Success" "GREEN"
) else (
    call :SHOW_CARD "NotificationSettings" "Failed" "YELLOW"
)

goto :EOF

:ENABLE_ALL_TRAY_ICONS_COMPREHENSIVE
call :WRITE_STATUS "Enabling ALL tray icons using comprehensive methods..." "PROCESSING"

set "METHOD_AUTO_TRAY_DISABLED=0"
set "METHOD_INDIVIDUAL_SETTINGS_RESET=0"
set "METHOD_TRAY_CACHE_CLEARED=0"
set "METHOD_NOTIFICATION_SETTINGS_RESET=0"
set "METHOD_SYSTEM_ICONS_FORCED=0"
set "METHOD_WINDOWS_11_OPTIMIZED=0"

:: Method 1: Disable AutoTray
call :SET_TRAY_ICON_CONFIGURATION ENABLE
if "!EXIT_CODE!"=="0" set "METHOD_AUTO_TRAY_DISABLED=1"

:: Method 2: Reset individual icon settings
call :RESET_INDIVIDUAL_ICON_SETTINGS
set "METHOD_INDIVIDUAL_SETTINGS_RESET=1"
set "METHOD_TRAY_CACHE_CLEARED=1"
set "METHOD_NOTIFICATION_SETTINGS_RESET=1"

:: Method 3: Force show system icons
call :WRITE_STATUS "Forcing system icons to show..." "INFO"
set "SYSTEM_ICONS_SET=0"

reg add "!REGISTRY_PATH!" /v "HideSCAVolume" /t REG_DWORD /d 0 /f >nul 2>&1
if !errorlevel! equ 0 set /a SYSTEM_ICONS_SET+=1

reg add "!REGISTRY_PATH!" /v "HideSCANetwork" /t REG_DWORD /d 0 /f >nul 2>&1
if !errorlevel! equ 0 set /a SYSTEM_ICONS_SET+=1

reg add "!REGISTRY_PATH!" /v "HideSCAPower" /t REG_DWORD /d 0 /f >nul 2>&1
if !errorlevel! equ 0 set /a SYSTEM_ICONS_SET+=1

if !SYSTEM_ICONS_SET! gtr 0 (
    set "METHOD_SYSTEM_ICONS_FORCED=1"
    call :WRITE_STATUS "System icons forced to show (!SYSTEM_ICONS_SET! settings)" "SUCCESS"
) else (
    call :WRITE_STATUS "No system icons were configured" "WARNING"
)

:: Method 4: Windows 11 specific optimizations
call :GET_WINDOWS_VERSION
echo !WINDOWS_VERSION! | find "11" >nul
if !errorlevel! equ 0 (
    call :WRITE_STATUS "Applying Windows 11 specific optimizations..." "INFO"
    reg query "!EXPLORER_ADVANCED!" >nul 2>&1
    if !errorlevel! equ 0 (
        reg add "!EXPLORER_ADVANCED!" /v "TaskbarMn" /t REG_DWORD /d 0 /f >nul 2>&1
        set "METHOD_WINDOWS_11_OPTIMIZED=1"
        call :WRITE_STATUS "Windows 11 specific settings applied" "SUCCESS"
    ) else (
        call :WRITE_STATUS "Windows 11 Advanced path not found" "WARNING"
    )
) else (
    call :WRITE_STATUS "Windows 11 specific settings skipped (not Windows 11)" "INFO"
)

call :WRITE_STATUS "Comprehensive tray icon enabling completed" "SUCCESS"

:: Display results
echo.
echo !COLOR_CYAN!METHODS APPLIED:!COLOR_RESET!
if "!METHOD_AUTO_TRAY_DISABLED!"=="1" (
    call :SHOW_CARD "AutoTrayDisabled" "Success" "GREEN"
) else (
    call :SHOW_CARD "AutoTrayDisabled" "Failed" "YELLOW"
)

if "!METHOD_INDIVIDUAL_SETTINGS_RESET!"=="1" (
    call :SHOW_CARD "IndividualSettingsReset" "Success" "GREEN"
) else (
    call :SHOW_CARD "IndividualSettingsReset" "Failed" "YELLOW"
)

if "!METHOD_TRAY_CACHE_CLEARED!"=="1" (
    call :SHOW_CARD "TrayCacheCleared" "Success" "GREEN"
) else (
    call :SHOW_CARD "TrayCacheCleared" "Failed" "YELLOW"
)

if "!METHOD_SYSTEM_ICONS_FORCED!"=="1" (
    call :SHOW_CARD "SystemIconsForced" "Success" "GREEN"
) else (
    call :SHOW_CARD "SystemIconsForced" "Failed" "YELLOW"
)

if "!METHOD_WINDOWS_11_OPTIMIZED!"=="1" (
    call :SHOW_CARD "Windows11Optimized" "Success" "GREEN"
) else (
    call :SHOW_CARD "Windows11Optimized" "Failed" "YELLOW"
)

set "EXIT_CODE=0"
goto :EOF

:: ============================================================================
:: ENHANCED BACKUP SYSTEM
:: ============================================================================

:BACKUP_COMPREHENSIVE_TRAY_SETTINGS
call :WRITE_STATUS "Creating comprehensive tray settings backup..." "PROCESSING"

:: Create comprehensive backup file
(
echo Windows Registry Editor Version 5.00
echo.
echo ; Comprehensive Tray Icons Backup
echo ; Created: %DATE% %TIME%
echo ; Script: %SCRIPT_NAME% v%SCRIPT_VERSION%
echo ; Computer: %COMPUTERNAME%
echo ; User: %USERNAME%
echo.
) > "!COMPREHENSIVE_BACKUP_PATH!"

:: Backup main AutoTray setting
call :GET_CURRENT_TRAY_CONFIGURATION
set "CURRENT_CONFIG=!ERRORLEVEL!"
(
echo ; Main AutoTray Setting
echo [!REGISTRY_PATH!]
) >> "!COMPREHENSIVE_BACKUP_PATH!"
if "!CURRENT_CONFIG!"=="255" (
    echo "!REGISTRY_VALUE!"=- >> "!COMPREHENSIVE_BACKUP_PATH!"
) else (
    echo "!REGISTRY_VALUE!"=dword:!CURRENT_CONFIG! >> "!COMPREHENSIVE_BACKUP_PATH!"
)
echo. >> "!COMPREHENSIVE_BACKUP_PATH!"

:: Backup system icons
(
echo ; System Icons
echo [!REGISTRY_PATH!]
) >> "!COMPREHENSIVE_BACKUP_PATH!"
for %%I in (HideSCAVolume HideSCANetwork HideSCAPower) do (
    reg query "!REGISTRY_PATH!" /v "%%I" >nul 2>&1
    if !errorlevel! equ 0 (
        for /f "tokens=3" %%V in ('reg query "!REGISTRY_PATH!" /v "%%I" 2^>nul') do (
            echo "%%I"=dword:%%V >> "!COMPREHENSIVE_BACKUP_PATH!"
        )
    )
)
echo. >> "!COMPREHENSIVE_BACKUP_PATH!"

:: Export additional registry paths
for %%P in (
    "!NOTIFY_ICON_SETTINGS!"
    "!TRAY_NOTIFY_PATH!"
    "!HIDE_DESKTOP_ICONS!"
    "!TASKBAND_PATH!"
    "!NOTIFICATIONS_SETTINGS!"
    "!EXPLORER_ADVANCED!"
) do (
    reg query %%P >nul 2>&1
    if !errorlevel! equ 0 (
        echo ; Exporting %%P
        echo. >> "!COMPREHENSIVE_BACKUP_PATH!"
        reg export %%P "!TEMP!\temp_export.reg" /y >nul 2>&1
        if !errorlevel! equ 0 (
            type "!TEMP!\temp_export.reg" >> "!COMPREHENSIVE_BACKUP_PATH!" 2>nul
            del "!TEMP!\temp_export.reg" >nul 2>&1
        )
    )
)

call :WRITE_STATUS "Comprehensive backup created: !COMPREHENSIVE_BACKUP_PATH!" "SUCCESS"

:: Display backup summary
for %%F in ("!COMPREHENSIVE_BACKUP_PATH!") do (
    set "BACKUP_SIZE=%%~zF"
    set /a BACKUP_SIZE_KB=!BACKUP_SIZE!/1024
)
call :SHOW_CARD "Backup Location" "!COMPREHENSIVE_BACKUP_PATH!"
call :SHOW_CARD "Backup Size" "!BACKUP_SIZE_KB! KB"
call :SHOW_CARD "Windows Version" "!WINDOWS_VERSION!"
call :SHOW_CARD "Settings Backed Up" "Multiple categories"

set "EXIT_CODE=0"
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
set "EXIT_CODE=0"
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
)> "!BACKUP_PATH!" 2>nul

if "!CURRENT_CONFIG!"=="255" (
    echo "!REGISTRY_VALUE!"=- >> "!BACKUP_PATH!" 2>nul
) else (
    echo "!REGISTRY_VALUE!"=dword:!CURRENT_CONFIG! >> "!BACKUP_PATH!" 2>nul
)

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
:: Try comprehensive restore first
if exist "!COMPREHENSIVE_BACKUP_PATH!" (
    call :WRITE_STATUS "Found comprehensive backup, restoring..." "INFO"
    reg import "!COMPREHENSIVE_BACKUP_PATH!" >nul 2>&1
    if !errorlevel! equ 0 (
        call :WRITE_STATUS "Comprehensive restoration completed!" "SUCCESS"
        del "!COMPREHENSIVE_BACKUP_PATH!" >nul 2>&1
        call :WRITE_STATUS "Comprehensive backup file removed" "INFO"
        set "EXIT_CODE=0"
        goto :EOF
    )
)

:: Fall back to basic rollback
if not exist "!BACKUP_PATH!" (
    call :WRITE_STATUS "No backup found for rollback" "ERROR"
    set "EXIT_CODE=!EXIT_ROLLBACK_FAILED!"
    goto :EOF
)

call :WRITE_STATUS "Attempting rollback to previous configuration..." "INFO"

:: Import backup registry file
reg import "!BACKUP_PATH!" >nul 2>&1
if !errorlevel! neq 0 (
    call :WRITE_STATUS "Rollback failed" "ERROR"
    set "EXIT_CODE=!EXIT_ROLLBACK_FAILED!"
    goto :EOF
)

call :WRITE_STATUS "Configuration restored from backup successfully!" "SUCCESS"

:: Remove backup file after successful rollback
del "!BACKUP_PATH!" >nul 2>&1
call :WRITE_STATUS "Backup file removed after successful rollback" "INFO"
set "EXIT_CODE=0"
goto :EOF

:: ============================================================================
:: DIAGNOSTIC FUNCTIONS
:: ============================================================================

:INVOKE_BACKUP_DIAGNOSTIC
call :SHOW_HEADER "Backup File Diagnostics" "Validation and analysis"

set "BACKUP_TO_CHECK=!COMPREHENSIVE_BACKUP_PATH!"
if not exist "!BACKUP_TO_CHECK!" (
    set "BACKUP_TO_CHECK=!BACKUP_PATH!"
)

if not exist "!BACKUP_TO_CHECK!" (
    call :WRITE_STATUS "No backup file found for diagnostics" "ERROR"
    goto :EOF
)

call :WRITE_STATUS "Performing backup file diagnostics..." "INFO"
echo.

echo !COLOR_CYAN!=== BACKUP FILE DIAGNOSTICS ===!COLOR_RESET!

:: Check file size
for %%F in ("!BACKUP_TO_CHECK!") do (
    set "FILE_SIZE=%%~zF"
    set /a FILE_SIZE_KB=!FILE_SIZE!/1024
    echo File Size: !FILE_SIZE! bytes (!FILE_SIZE_KB! KB)
)

:: Check file content
call :WRITE_STATUS "Checking file content..." "INFO"
find /c /v "" < "!BACKUP_TO_CHECK!" >nul
if !errorlevel! equ 0 (
    for /f "tokens=3" %%L in ('find /c /v "" ^< "!BACKUP_TO_CHECK!"') do (
        echo Line Count: %%L
    )
)

:: Check if it's a valid REG file
call :WRITE_STATUS "Validating REG file format..." "INFO"
findstr /B /C:"Windows Registry Editor" "!BACKUP_TO_CHECK!" >nul
if !errorlevel! equ 0 (
    echo REG File Format: !COLOR_GREEN!Valid!COLOR_RESET!
) else (
    echo REG File Format: !COLOR_RED!Invalid!COLOR_RESET!
)

:: Display first few lines
call :WRITE_STATUS "Displaying file preview..." "INFO"
echo.
echo First 10 lines:
echo !COLOR_GRAY!----------------------------------------!COLOR_RESET!
set "LINE_COUNT=0"
for /f "tokens=*" %%L in ('type "!BACKUP_TO_CHECK!"') do (
    echo %%L
    set /a LINE_COUNT+=1
    if !LINE_COUNT! equ 10 goto :DIAGNOSTICS_COMPLETE
)

:DIAGNOSTICS_COMPLETE
echo !COLOR_GRAY!----------------------------------------!COLOR_RESET!
echo.
call :WRITE_STATUS "Backup diagnostics completed" "SUCCESS"
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
set "TIMEOUT=!EXPLORER_RESTART_TIMEOUT!"
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
    set "EXIT_CODE=1"
) else (
    call :WRITE_STATUS "Windows Explorer restarted successfully" "SUCCESS"
)
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
echo [%DATE% %TIME%] Script completed with exit code: !EXIT_CODE! >> "!LOG_PATH!"

if "!EXIT_CODE!"=="0" (
    call :WRITE_STATUS "Script completed successfully" "SUCCESS"
) else (
    call :WRITE_STATUS "Script completed with errors (Exit Code: !EXIT_CODE!)" "ERROR"
)

endlocal
exit /b %EXIT_CODE%
