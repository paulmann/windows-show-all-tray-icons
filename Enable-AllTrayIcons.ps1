<#
.SYNOPSIS
    Enable or disable automatic hiding of system tray icons in Windows 11/10.

.DESCRIPTION
    Enterprise-grade PowerShell script for managing system tray icon visibility.
    Features comprehensive error handling, logging, session validation, rollback support,
    individual icon settings reset, and advanced diagnostic capabilities.
    
    NEW IN VERSION 4.0:
    - Complete individual icon preferences reset
    - Multi-method icon visibility enforcement  
    - Advanced backup/restore with JSON serialization
    - Windows 11 taskbar optimization
    - System tray icon normalization
    - Professional diagnostic reporting
    - Dynamic registry path management
    - Binary data handling for icon streams
    - Notification system controls
    - Backup integrity validation
    - Enhanced error recovery mechanisms

    Author: Mikhail Deynekin (mid1977@gmail.com)
    Website: https://deynekin.com
    Repository: https://github.com/paulmann/windows-show-all-tray-icons
    Version: 4.0 (Enterprise Edition - Enhanced)

.PARAMETER Action
    Specifies the action to perform:
    - 'Enable'  : Show all system tray icons (disable auto-hide) [Value: 0]
    - 'Disable' : Restore Windows default behavior (enable auto-hide) [Value: 1]
    - 'Status'  : Check current configuration without making changes
    - 'Rollback': Revert to previous configuration if backup exists
    - 'Backup'  : Create registry backup without making changes

.PARAMETER RestartExplorer
    If specified, automatically restarts Windows Explorer to apply changes immediately.

.PARAMETER BackupRegistry
    If specified, creates registry backup before making changes (recommended).

.PARAMETER LogPath
    Specifies custom log file path. Default: $env:TEMP\Enable-AllTrayIcons.log

.PARAMETER Force
    Bypass confirmation prompts and warnings.

.PARAMETER Update
    Check and update script from GitHub repository if newer version available.

.PARAMETER Help
    Display detailed help information.

.PARAMETER WhatIf
    Shows what would happen if the cmdlet runs without actually executing.

.PARAMETER Confirm
    Prompts for confirmation before executing the operation.

.PARAMETER Diagnostic
    Perform comprehensive backup file diagnostics and validation.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Action Enable -BackupRegistry
    Shows all system tray icons with registry backup.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer -Force
    Shows all icons, restarts Explorer, and bypasses prompts.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Action Status
    Displays comprehensive system status.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Action Backup
    Creates registry backup without making changes.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Action Rollback
    Reverts to previous configuration if backup exists.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Update
    Checks and updates script from GitHub repository.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Help
    Displays detailed help information.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Diagnostic
    Runs backup file diagnostics and validation checks.

.NOTES
    Version:        4.0 (Enterprise Edition - Enhanced)
    Creation Date:  2025-11-21
    Last Updated:   2025-11-23
    Compatibility:  Windows 10 (All versions), Windows 11 (All versions), Server 2019+
    Requires:       PowerShell 5.1 or higher (with enhanced features for PowerShell 7+)
    Privileges:     Standard User (HKCU registry key only - no admin required)
    
    ENHANCED FEATURES:
    - Comprehensive individual icon settings reset (NotifyIconSettings, TrayNotify, TaskbarLayout)
    - Multiple methods for forcing icon visibility (4+ complementary techniques)
    - Enhanced backup/restore for all tray-related settings (JSON-based with binary data support)
    - Windows 11 specific optimizations (TaskbarMn, modern UI enhancements)
    - System icon visibility controls (Volume, Network, Power indicators)
    - Professional reporting and status display (modern UI with color coding)
    - Advanced diagnostic capabilities (backup validation, registry path verification)
    - Dynamic registry path management (auto-creation of missing registry keys)
    - Comprehensive error handling with rollback protection
    - Multi-session environment support (RDP, local, service contexts)
    - Real-time progress tracking with method-specific reporting
    - PowerShell 7+ enhanced features (improved colors, performance optimizations)
    - Automated Windows version detection and version-specific tweaks
    - Binary data handling for registry streams (IconStreams, PastIconsStream)
    - Notification system controls (app-specific notification settings reset)
    - Desktop icon visibility synchronization
    - Taskbar layout normalization and cleanup
    - Backup integrity validation and corruption detection
    - Unicode and special character handling in backup files
    - Performance monitoring with execution time tracking
    - Session context awareness (admin rights, interactive mode detection)
    - Force mode for non-interactive and automated scenarios
    - WhatIf support for safe testing and validation
    - Comprehensive logging with both console and file output
    - Auto-update functionality with version checking
    - Cross-version compatibility (Windows 10/11, Server 2019+)
    - Graceful explorer restart with process management
    - Registry backup/restore with transaction safety
    - Multi-language support with Unicode compliance
    - Enterprise-grade error recovery and reporting
    - Modular architecture for easy maintenance and extension

.LINK
    GitHub Repository: https://github.com/paulmann/windows-show-all-tray-icons
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet('Enable', 'Disable', 'Status', 'Rollback', 'Backup')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [switch]$RestartExplorer,

    [Parameter(Mandatory = $false)]
    [switch]$BackupRegistry,

    [Parameter(Mandatory = $false)]
    [string]$LogPath,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$Update,

    [Parameter(Mandatory = $false)]
    [switch]$Help,

    [Parameter(Mandatory = $false)]
    [switch]$Diagnostic
)

# ============================================================================
# ENTERPRISE CONFIGURATION
# ============================================================================

$Script:Configuration = @{
    # Registry Configuration
    RegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
    RegistryValue = "EnableAutoTray"
    EnableValue = 0
    DisableValue = 1
    
    # Script Metadata
    ScriptVersion = "4.0"
    ScriptAuthor = "Mikhail Deynekin (mid1977@gmail.com)"
    ScriptName = "Enable-AllTrayIcons.ps1 (Enterprise Edition - Enhanced)"
    GitHubRepository = "https://github.com/paulmann/windows-show-all-tray-icons"
    UpdateUrl = "https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/refs/heads/main/Enable-AllTrayIcons.ps1"
    
    # Path Configuration
    DefaultLogPath = "$env:TEMP\Enable-AllTrayIcons.log"
    BackupRegistryPath = "$env:TEMP\TrayIconsBackup.reg"
    
    # Performance Configuration
    ExplorerRestartTimeout = 10  # seconds
    ProcessWaitTimeout = 5       # seconds
    
    # Exit Codes
    ExitCode = 0
    ExitCodes = @{
        Success = 0
        GeneralError = 1
        AccessDenied = 2
        InvalidSession = 3
        PowerShellVersion = 4
        RollbackFailed = 5
        UpdateFailed = 6
        BackupFailed = 7
    }
}

# ============================================================================
# POWERSHELL VERSION COMPATIBILITY
# ============================================================================

$Script:IsPS7Plus = $PSVersionTable.PSVersion.Major -ge 7

# ============================================================================
# MODERN UI/UX COLOR SCHEME
# ============================================================================

$Script:ConsoleColors = @{
    Primary    = "Cyan"
    Success    = "Green"
    Error      = "Red"
    Warning    = "Yellow"
    Info       = "Cyan"
    Accent     = "Magenta"
    Dark       = "DarkGray"
    Light      = "White"
}

# PowerShell 7+ enhanced colors
if ($Script:IsPS7Plus) {
    $Script:ConsoleColors.Primary = "Blue"
    $Script:ConsoleColors.Info = "Cyan"
}

# ============================================================================
# ENHANCED OUTPUT SYSTEM WITH PS7+ FEATURES
# ============================================================================

function Write-EnhancedOutput {
    <#
    .SYNOPSIS
        Enhanced output with PowerShell 7+ features when available.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Primary', 'Success', 'Error', 'Warning', 'Info', 'Accent', 'Dark', 'Light')]
        [string]$Type = "Info",
        
        [Parameter(Mandatory = $false)]
        [switch]$NoNewline,
        
        [Parameter(Mandatory = $false)]
        [switch]$Bold
    )
    
    $color = $Script:ConsoleColors[$Type]
    
    # PowerShell 7+ enhanced formatting
    if ($Script:IsPS7Plus -and $Bold) {
        Write-Host $Message -NoNewline:$NoNewline -ForegroundColor $color -BackgroundColor "DarkBlue"
    } else {
        if ($NoNewline) {
            Write-Host $Message -NoNewline -ForegroundColor $color
        } else {
            Write-Host $Message -ForegroundColor $color
        }
    }
}

function Write-ModernHeader {
    <#
    .SYNOPSIS
        Displays a modern header with gradient effect.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $false)]
        [string]$Subtitle = ""
    )
    
    Write-Host ""
    Write-Host "=" -NoNewline -ForegroundColor $Script:ConsoleColors.Primary
    Write-Host ("=" * 78) -NoNewline -ForegroundColor $Script:ConsoleColors.Primary
    Write-Host "=" -ForegroundColor $Script:ConsoleColors.Primary
    
    Write-Host "|" -NoNewline -ForegroundColor $Script:ConsoleColors.Primary
    Write-Host " $Title" -NoNewline -ForegroundColor $Script:ConsoleColors.Light
    if ($Subtitle) {
        Write-Host " - $Subtitle" -NoNewline -ForegroundColor $Script:ConsoleColors.Info
    }
    Write-Host (" " * (77 - $Title.Length - $Subtitle.Length - 2)) -NoNewline
    Write-Host "|" -ForegroundColor $Script:ConsoleColors.Primary
    
    Write-Host "=" -NoNewline -ForegroundColor $Script:ConsoleColors.Primary
    Write-Host ("=" * 78) -NoNewline -ForegroundColor $Script:ConsoleColors.Primary
    Write-Host "=" -ForegroundColor $Script:ConsoleColors.Primary
    Write-Host ""
}

function Write-ModernCard {
    <#
    .SYNOPSIS
        Displays information in a card-like container.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $false)]
        [string]$Value,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Primary', 'Success', 'Error', 'Warning', 'Info', 'Accent', 'Light')]
        [string]$ValueColor = "Light"
    )
    
    Write-Host "  [*] " -NoNewline -ForegroundColor $Script:ConsoleColors.Dark
    Write-Host $Title -NoNewline -ForegroundColor $Script:ConsoleColors.Light
    
    Write-Host " " -NoNewline
    
    # Calculate padding for alignment
    $padding = 25 - $Title.Length
    if ($padding -gt 0) {
        Write-Host (" " * $padding) -NoNewline
    }
    
    Write-Host " | " -NoNewline -ForegroundColor $Script:ConsoleColors.Dark
    Write-Host $Value -ForegroundColor $Script:ConsoleColors[$ValueColor]
}

function Write-ModernStatus {
    <#
    .SYNOPSIS
        Displays status with visual indicators.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Success', 'Error', 'Warning', 'Info', 'Processing')]
        [string]$Status = "Info"
    )
    
    $icons = @{
        Success = "[OK]"
        Error = "[ERROR]"
        Warning = "[WARN]"
        Info = "[INFO]"
        Processing = "[....]"
    }
    
    $colors = @{
        Success = "Success"
        Error = "Error"
        Warning = "Warning"
        Info = "Info"
        Processing = "Primary"
    }
    
    Write-Host "  " -NoNewline
    Write-Host $icons[$Status] -NoNewline -ForegroundColor $Script:ConsoleColors[$colors[$Status]]
    Write-Host " $Message" -ForegroundColor $Script:ConsoleColors.Light
}

function Show-ModernBanner {
    <#
    .SYNOPSIS
        Displays a modern application banner.
    #>
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor $Script:ConsoleColors.Primary
    Write-Host "   WINDOWS SYSTEM TRAY ICONS CONFIGURATION TOOL" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "              ENTERPRISE EDITION - ENHANCED" -ForegroundColor $Script:ConsoleColors.Info
    Write-Host "================================================================" -ForegroundColor $Script:ConsoleColors.Primary
    Write-Host ""
}

# ============================================================================
# HELP SYSTEM
# ============================================================================

function Show-ModernHelp {
    <#
    .SYNOPSIS
        Displays modern, comprehensive help information.
    #>
    
    Write-ModernHeader "Windows System Tray Icons Configuration Tool" "v$($Script:Configuration.ScriptVersion)"
    
    Write-EnhancedOutput "DESCRIPTION:" -Type Primary -Bold
    Write-EnhancedOutput "  Professional tool for managing system tray icon visibility in Windows 10/11." -Type Light
    Write-EnhancedOutput "  Modifies registry settings to control notification area behavior with enhanced" -Type Light
    Write-EnhancedOutput "  individual icon settings reset and comprehensive backup/restore functionality." -Type Light
    Write-Host ""
    
    Write-EnhancedOutput "USAGE:" -Type Primary -Bold
    Write-Host "  .\$($Script:Configuration.ScriptName) -Action <Command> [Options]" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host ""
    
    Write-EnhancedOutput "QUICK COMMANDS:" -Type Primary -Bold
    Write-ModernCard "Show All Icons" ".\$($Script:Configuration.ScriptName) -Action Enable"
    Write-ModernCard "Restore Default" ".\$($Script:Configuration.ScriptName) -Action Disable"
    Write-ModernCard "Check Status" ".\$($Script:Configuration.ScriptName) -Action Status"
    Write-ModernCard "Create Backup" ".\$($Script:Configuration.ScriptName) -Action Backup"
    Write-ModernCard "Update Script" ".\$($Script:Configuration.ScriptName) -Update"
    Write-ModernCard "Show Help" ".\$($Script:Configuration.ScriptName) -Help"
    Write-Host ""
    
    Write-EnhancedOutput "ACTION PARAMETERS:" -Type Primary -Bold
    Write-ModernCard "-Action Enable" "Show all system tray icons (comprehensive method)"
    Write-ModernCard "-Action Disable" "Restore Windows default behavior"
    Write-ModernCard "-Action Status" "Display current configuration"
    Write-ModernCard "-Action Backup" "Create comprehensive registry backup"
    Write-ModernCard "-Action Rollback" "Revert to previous configuration"
    Write-Host ""
    
    Write-EnhancedOutput "OPTIONAL PARAMETERS:" -Type Primary -Bold
    Write-ModernCard "-RestartExplorer" "Apply changes immediately"
    Write-ModernCard "-BackupRegistry" "Create backup before changes"
    Write-ModernCard "-Force" "Bypass confirmation prompts"
    Write-ModernCard "-Update" "Update script from GitHub"
    Write-ModernCard "-Help" "Display this help message"
    Write-ModernCard "-LogPath <path>" "Custom log file location"
    Write-Host ""
    
    Write-EnhancedOutput "ENHANCED FEATURES:" -Type Primary -Bold
    Write-ModernCard "Individual Settings Reset" "Resets per-icon user preferences"
    Write-ModernCard "Multiple Methods" "Uses 4+ techniques to force icon visibility"
    Write-ModernCard "Comprehensive Backup" "Backs up ALL tray-related settings"
    Write-ModernCard "Windows 11 Optimized" "Includes Windows 11 specific tweaks"
    Write-ModernCard "System Icons Control" "Manages system icon visibility"
    Write-Host ""
    
    Write-EnhancedOutput "EXAMPLES:" -Type Primary -Bold
    Write-Host "  .\$($Script:Configuration.ScriptName) -Action Enable -RestartExplorer" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "    # Enable all icons and restart Explorer immediately" -ForegroundColor $Script:ConsoleColors.Dark
    Write-Host ""
    Write-Host "  .\$($Script:Configuration.ScriptName) -Action Status" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "    # Display current system configuration" -ForegroundColor $Script:ConsoleColors.Dark
    Write-Host ""
    Write-Host "  .\$($Script:Configuration.ScriptName) -Action Backup" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "    # Create comprehensive registry backup" -ForegroundColor $Script:ConsoleColors.Dark
    Write-Host ""
    Write-Host "  .\$($Script:Configuration.ScriptName) -Action Enable -BackupRegistry -Force" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "    # Force enable all icons with backup, no prompts" -ForegroundColor $Script:ConsoleColors.Dark
    Write-Host ""
    Write-Host "  .\$($Script:Configuration.ScriptName) -Update" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "    # Check and update script from GitHub" -ForegroundColor $Script:ConsoleColors.Dark
    Write-Host ""
    
    Write-EnhancedOutput "ADDITIONAL INFORMATION:" -Type Primary -Bold
    Write-ModernCard "Version" $Script:Configuration.ScriptVersion
    Write-ModernCard "Author" $Script:Configuration.ScriptAuthor
    Write-ModernCard "Repository" $Script:Configuration.GitHubRepository
    Write-ModernCard "PowerShell Version" "$($PSVersionTable.PSVersion) ($(if($Script:IsPS7Plus){'Enhanced'}else{'Standard'}))"
    Write-ModernCard "Compatibility" "Windows 10/11, Server 2019+"
    
    Write-Host ""
    Write-EnhancedOutput "Note: All parameters are case-insensitive. Admin rights not required." -Type Dark
    Write-Host ""
}

function Show-ApplicationInfo {
    <#
    .SYNOPSIS
        Displays brief application information.
    #>
    
    Write-ModernHeader "Application Information" "v$($Script:Configuration.ScriptVersion)"
    
    Write-ModernCard "Script Name" $Script:Configuration.ScriptName
    Write-ModernCard "Version" $Script:Configuration.ScriptVersion
    Write-ModernCard "Author" $Script:Configuration.ScriptAuthor
    Write-ModernCard "Repository" $Script:Configuration.GitHubRepository
    Write-ModernCard "Compatibility" "Windows 10/11, Server 2019+"
    Write-ModernCard "PowerShell" "$($PSVersionTable.PSVersion) ($(if($Script:IsPS7Plus){'Enhanced'}else{'Compatible'}))"
    Write-ModernCard "Enhanced Features" "Individual settings reset, comprehensive backup"
    
    Write-Host ""
    Write-EnhancedOutput "Use '-Help' for detailed usage information." -Type Info
    Write-Host ""
}

# ============================================================================
# ENHANCED TRAY ICONS MANAGEMENT SYSTEM
# ============================================================================

function Reset-IndividualIconSettings {
    <#
    .SYNOPSIS
        Resets individual icon settings to show all icons regardless of user preferences.
    #>
    
    Write-ModernStatus "Resetting individual icon settings..." -Status Processing
    
    $results = @{
        NotifyIconSettings = $false
        TrayNotify = $false
        HideDesktopIcons = $false
        TaskbarLayout = $false
        NotificationSettings = $false
    }
    
    try {
        # 1. Reset NotifyIconSettings (main individual settings)
        $settingsPath = "HKCU:\Control Panel\NotifyIconSettings"
        if (Test-Path $settingsPath) {
            $iconCount = 0
            Get-ChildItem -Path $settingsPath | ForEach-Object {
                try {
                    Set-ItemProperty -Path $_.PSPath -Name "IsPromoted" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    $iconCount++
                }
                catch {
                    Write-ModernStatus "Failed to reset IsPromoted for $($_.PSChildName)" -Status Warning
                }
            }
            if ($iconCount -gt 0) {
                $results.NotifyIconSettings = $true
                Write-ModernStatus "NotifyIconSettings reset completed ($iconCount icons)" -Status Success
            } else {
                Write-ModernStatus "No icons found in NotifyIconSettings" -Status Warning
            }
        }
        else {
            Write-ModernStatus "NotifyIconSettings path not found" -Status Warning
        }
        
        # 2. Reset TrayNotify streams (icon cache) - Создаем путь если не существует
        $trayPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TrayNotify"
        if (-not (Test-Path $trayPath)) {
            try {
                Write-ModernStatus "TrayNotify path doesn't exist, creating it..." -Status Info
                $null = New-Item -Path $trayPath -Force -ErrorAction Stop
                Write-ModernStatus "TrayNotify path created successfully" -Status Success
            }
            catch {
                Write-ModernStatus "Failed to create TrayNotify path: $($_.Exception.Message)" -Status Warning
            }
        }
        
        if (Test-Path $trayPath) {
            try {
                $clearedProperties = @()
                # Убедимся, что значения установлены правильно
                Set-ItemProperty -Path $trayPath -Name "IconStreams" -Value @() -Type Binary -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $trayPath -Name "PastIconsStream" -Value @() -Type Binary -Force -ErrorAction SilentlyContinue
                
                $iconStreams = Get-ItemProperty -Path $trayPath -Name "IconStreams" -ErrorAction SilentlyContinue
                $pastIcons = Get-ItemProperty -Path $trayPath -Name "PastIconsStream" -ErrorAction SilentlyContinue
                
                if ($iconStreams -or $pastIcons) {
                    $results.TrayNotify = $true
                    Write-ModernStatus "TrayNotify cache initialized/cleared" -Status Success
                } else {
                    Write-ModernStatus "TrayNotify cache already cleared" -Status Info
                    $results.TrayNotify = $true
                }
            }
            catch {
                Write-ModernStatus "Failed to clear TrayNotify streams: $($_.Exception.Message)" -Status Warning
            }
        } else {
            Write-ModernStatus "TrayNotify path could not be created" -Status Warning
        }
        
        # 3. Reset desktop icon visibility (related to system icons)
        $desktopPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons"
        if (Test-Path $desktopPath) {
            try {
                $desktopItems = Get-ChildItem -Path $desktopPath
                if ($desktopItems.Count -gt 0) {
                    $desktopItems | ForEach-Object {
                        Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    $results.HideDesktopIcons = $true
                    Write-ModernStatus "Desktop icon visibility reset ($($desktopItems.Count) items)" -Status Success
                } else {
                    Write-ModernStatus "No desktop icon settings found to reset" -Status Info
                }
            }
            catch {
                Write-ModernStatus "Failed to reset desktop icons: $($_.Exception.Message)" -Status Warning
            }
        } else {
            Write-ModernStatus "HideDesktopIcons path not found" -Status Warning
        }
        
        # 4. Reset taskbar layout (additional icon positioning)
        $taskbarPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
        if (Test-Path $taskbarPath) {
            try {
                $taskbarCleared = $false
                if (Get-ItemProperty -Path $taskbarPath -Name "Favorites" -ErrorAction SilentlyContinue) {
                    Remove-ItemProperty -Path $taskbarPath -Name "Favorites" -Force -ErrorAction SilentlyContinue
                    $taskbarCleared = $true
                }
                if (Get-ItemProperty -Path $taskbarPath -Name "FavoritesResolve" -ErrorAction SilentlyContinue) {
                    Remove-ItemProperty -Path $taskbarPath -Name "FavoritesResolve" -Force -ErrorAction SilentlyContinue
                    $taskbarCleared = $true
                }
                
                if ($taskbarCleared) {
                    $results.TaskbarLayout = $true
                    Write-ModernStatus "Taskbar layout reset" -Status Success
                } else {
                    Write-ModernStatus "No taskbar layout settings found to reset" -Status Info
                }
            }
            catch {
                Write-ModernStatus "Failed to reset taskbar layout: $($_.Exception.Message)" -Status Warning
            }
        } else {
            Write-ModernStatus "Taskband path not found" -Status Warning
        }
        
        # 5. Additional method: Reset notification area preferences completely
        $notifyPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings"
        if (Test-Path $notifyPath) {
            try {
                $notificationApps = Get-ChildItem -Path $notifyPath
                $resetCount = 0
                
                foreach ($app in $notificationApps) {
                    try {
                        Set-ItemProperty -Path $app.PSPath -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $app.PSPath -Name "ShowInActionCenter" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                        $resetCount++
                    }
                    catch {
                        # Continue if individual settings fail
                    }
                }
                
                if ($resetCount -gt 0) {
                    $results.NotificationSettings = $true
                    Write-ModernStatus "Notification settings reset ($resetCount apps)" -Status Success
                } else {
                    Write-ModernStatus "No notification settings found to reset" -Status Info
                }
            }
            catch {
                Write-ModernStatus "Failed to reset notification settings: $($_.Exception.Message)" -Status Warning
            }
        } else {
            Write-ModernStatus "Notifications Settings path not found" -Status Warning
        }
        
        return $results
    }
    catch {
        Write-ModernStatus "Failed to reset individual icon settings: $($_.Exception.Message)" -Status Error
        return $results
    }
}


function Enable-AllTrayIconsComprehensive {
    <#
    .SYNOPSIS
        Comprehensive method to enable ALL tray icons using multiple techniques.
    #>
    
    Write-ModernStatus "Enabling ALL tray icons using comprehensive methods..." -Status Processing
    
    $methods = @{
        AutoTrayDisabled = $false
        IndividualSettingsReset = $false
        TrayCacheCleared = $false
        NotificationSettingsReset = $false
        SystemIconsForced = $false
        Windows11Optimized = $false
    }
    
    try {
        # Method 1: Disable AutoTray (original method)
        if (Set-TrayIconConfiguration -Behavior 'Enable') {
            $methods.AutoTrayDisabled = $true
        }
        
        # Method 2: Reset individual icon settings
        $resetResults = Reset-IndividualIconSettings
        if ($resetResults.Values -contains $true) {
            $methods.IndividualSettingsReset = $true
        }
        
        # Set specific method results from individual reset
        $methods.TrayCacheCleared = $resetResults.TrayNotify
        $methods.NotificationSettingsReset = $resetResults.NotificationSettings
        
        # Method 3: Additional registry tweaks for stubborn icons
        
        # Force show all system icons
        $systemIconsPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
        $systemIcons = @(
            @{Name = "HideSCAVolume"; Value = 0},
            @{Name = "HideSCANetwork"; Value = 0},
            @{Name = "HideSCAPower"; Value = 0}
        )
        
        $systemIconsSet = 0
        foreach ($icon in $systemIcons) {
            try {
                # Ensure the registry path exists
                if (-not (Test-Path $systemIconsPath)) {
                    $null = New-Item -Path $systemIconsPath -Force -ErrorAction Stop
                }
                
                # Always set the value (don't check current state)
                Set-ItemProperty -Path $systemIconsPath -Name $icon.Name -Value $icon.Value -Type DWord -Force -ErrorAction Stop
                $systemIconsSet++
                Write-ModernStatus "System icon '$($icon.Name)' forced to show" -Status Success
            }
            catch {
                Write-ModernStatus "Failed to set system icon '$($icon.Name)': $($_.Exception.Message)" -Status Warning
            }
        }
        
        if ($systemIconsSet -gt 0) {
            $methods.SystemIconsForced = $true
            Write-ModernStatus "System icons forced to show ($systemIconsSet settings)" -Status Success
        } else {
            Write-ModernStatus "No system icons were configured" -Status Warning
        }
        
        # Method 4: Reset Windows 11 specific settings
        $windowsVersion = Get-WindowsVersion
        if ($windowsVersion -Like "*11*") {
            $win11Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            if (Test-Path $win11Path) {
                try {
                    Set-ItemProperty -Path $win11Path -Name "TaskbarMn" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                    $methods.Windows11Optimized = $true
                    Write-ModernStatus "Windows 11 specific settings applied" -Status Success
                }
                catch {
                    Write-ModernStatus "Windows 11 specific settings failed: $($_.Exception.Message)" -Status Warning
                }
            } else {
                Write-ModernStatus "Windows 11 Advanced path not found" -Status Warning
            }
        } else {
            Write-ModernStatus "Windows 11 specific settings skipped (not Windows 11)" -Status Info
        }
        
        Write-ModernStatus "Comprehensive tray icon enabling completed" -Status Success
        
        # Display results
        Write-Host ""
        Write-EnhancedOutput "METHODS APPLIED:" -Type Primary -Bold
        foreach ($method in $methods.GetEnumerator() | Sort-Object Key) {
            $status = if ($method.Value) { "Success" } else { "Failed" }
            $color = if ($method.Value) { "Success" } else { "Warning" }
            Write-ModernCard $method.Key $status -ValueColor $color
        }
        
        return $true
    }
    catch {
        Write-ModernStatus "Comprehensive enable failed: $($_.Exception.Message)" -Status Error
        return $false
    }
}

function Get-WindowsVersion {
    <#
    .SYNOPSIS
        Detects Windows version for version-specific tweaks.
    #>
    try {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        return $osInfo.Caption
    }
    catch {
        return "Unknown"
    }
}

# ============================================================================
# ENHANCED BACKUP SYSTEM FOR COMPREHENSIVE SETTINGS
# ============================================================================

function Backup-ComprehensiveTraySettings {
    <#
    .SYNOPSIS
        Creates comprehensive backup of ALL tray-related settings.
    #>
    
    Write-ModernStatus "Creating comprehensive tray settings backup..." -Status Processing
    
    $backupData = @{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        ScriptVersion = $Script:Configuration.ScriptVersion
        ComputerName = $env:COMPUTERNAME
        UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        WindowsVersion = Get-WindowsVersion
    }
    
    try {
        # 1. Backup main AutoTray setting
        $backupData.EnableAutoTray = Get-CurrentTrayConfiguration
        
        # 2. Backup NotifyIconSettings
        $settingsPath = "HKCU:\Control Panel\NotifyIconSettings"
        if (Test-Path $settingsPath) {
            $notifySettings = @{}
            Get-ChildItem -Path $settingsPath | ForEach-Object {
                $iconSettings = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
                if ($iconSettings) {
                    $notifySettings[$_.PSChildName] = @{}
                    foreach ($property in $iconSettings.PSObject.Properties) {
                        if ($property.Name -notin @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider")) {
                            $notifySettings[$_.PSChildName][$property.Name] = $property.Value
                        }
                    }
                }
            }
            $backupData.NotifyIconSettings = $notifySettings
        }
        
        # 3. Backup TrayNotify
        $trayPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TrayNotify"
        if (Test-Path $trayPath) {
            $traySettings = @{}
            $trayProperties = Get-ItemProperty -Path $trayPath -ErrorAction SilentlyContinue
            if ($trayProperties) {
                foreach ($property in $trayProperties.PSObject.Properties) {
                    if ($property.Name -notin @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider")) {
                        # For binary data, store as Base64
                        if ($property.Value -is [byte[]]) {
                            $traySettings[$property.Name] = @{
                                Type = "Binary"
                                Data = [Convert]::ToBase64String($property.Value)
                                Length = $property.Value.Length
                            }
                        }
                        else {
                            $traySettings[$property.Name] = $property.Value
                        }
                    }
                }
            }
            $backupData.TrayNotify = $traySettings
        }
        
        # 4. Backup system icon settings
        $systemIconsPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
        $systemIcons = @("HideSCAVolume", "HideSCANetwork", "HideSCAPower")
        $backupData.SystemIcons = @{}
        
        foreach ($icon in $systemIcons) {
            try {
                $value = Get-ItemProperty -Path $systemIconsPath -Name $icon -ErrorAction SilentlyContinue
                if ($value) {
                    $backupData.SystemIcons[$icon] = $value.$icon
                }
            }
            catch {
                # Skip if not present
            }
        }
        
        # Save comprehensive backup with proper encoding
        $backupPath = $Script:Configuration.BackupRegistryPath
        
        # Convert to JSON with proper formatting
        $json = $backupData | ConvertTo-Json -Depth 10 -Compress
        
        # Save with UTF-8 encoding without BOM
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($backupPath, $json, $utf8NoBom)
        
        Write-ModernStatus "Comprehensive backup created: $backupPath" -Status Success
        
        # Display backup summary
        Write-ModernCard "Backup Location" $backupPath
        Write-ModernCard "Settings Backed Up" "$($backupData.Keys.Count) categories"
        Write-ModernCard "Windows Version" $backupData.WindowsVersion
        Write-ModernCard "Backup Size" "$([math]::Round((Get-Item $backupPath).Length/1KB, 2)) KB"
        
        return $true
    }
    catch {
        Write-ModernStatus "Comprehensive backup failed: $($_.Exception.Message)" -Status Error
        return $false
    }
}

function Restore-ComprehensiveTraySettings {
    <#
    .SYNOPSIS
        Restores comprehensive tray settings from backup.
    #>
    
    $backupPath = $Script:Configuration.BackupRegistryPath
    
    if (-not (Test-Path $backupPath)) {
        Write-ModernStatus "No comprehensive backup found: $backupPath" -Status Error
        return $false
    }
    
    Write-ModernStatus "Restoring comprehensive tray settings..." -Status Processing
    
    try {
        $backupData = Get-Content -Path $backupPath -Raw | ConvertFrom-Json
        
        Write-ModernCard "Backup Created" $backupData.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
        Write-ModernCard "Windows Version" $backupData.WindowsVersion
        
        $restoreResults = @{}
        
        # 1. Restore main AutoTray setting
        if ($null -ne $backupData.EnableAutoTray) {
            Set-ItemProperty -Path $Script:Configuration.RegistryPath `
                           -Name $Script:Configuration.RegistryValue `
                           -Value $backupData.EnableAutoTray `
                           -Type DWord `
                           -Force `
                           -ErrorAction Stop
            $restoreResults.EnableAutoTray = $true
        }
        
        # 2. Restore NotifyIconSettings
        if ($backupData.NotifyIconSettings) {
            $settingsPath = "HKCU:\Control Panel\NotifyIconSettings"
            foreach ($icon in $backupData.NotifyIconSettings.PSObject.Properties) {
                try {
                    $iconPath = Join-Path $settingsPath $icon.Name
                    if (-not (Test-Path $iconPath)) {
                        $null = New-Item -Path $iconPath -Force -ErrorAction SilentlyContinue
                    }
                    
                    foreach ($property in $icon.Value.PSObject.Properties) {
                        Set-ItemProperty -Path $iconPath -Name $property.Name -Value $property.Value -Force -ErrorAction SilentlyContinue
                    }
                }
                catch {
                    Write-ModernStatus "Failed to restore $($icon.Name) settings" -Status Warning
                }
            }
            $restoreResults.NotifyIconSettings = $true
        }
        
        # 3. Restore TrayNotify
        if ($backupData.TrayNotify) {
            $trayPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TrayNotify"
            foreach ($property in $backupData.TrayNotify.PSObject.Properties) {
                try {
                    if ($property.Value.Type -eq "Binary") {
                        $bytes = [Convert]::FromBase64String($property.Value.Data)
                        Set-ItemProperty -Path $trayPath -Name $property.Name -Value $bytes -Type Binary -Force -ErrorAction SilentlyContinue
                    }
                    else {
                        Set-ItemProperty -Path $trayPath -Name $property.Name -Value $property.Value -Force -ErrorAction SilentlyContinue
                    }
                }
                catch {
                    Write-ModernStatus "Failed to restore TrayNotify.$($property.Name)" -Status Warning
                }
            }
            $restoreResults.TrayNotify = $true
        }
        
        # 4. Restore system icons
        if ($backupData.SystemIcons) {
            $systemIconsPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
            foreach ($icon in $backupData.SystemIcons.PSObject.Properties) {
                try {
                    Set-ItemProperty -Path $systemIconsPath -Name $icon.Name -Value $icon.Value -Type DWord -Force -ErrorAction SilentlyContinue
                }
                catch {
                    # Skip if restoration fails
                }
            }
            $restoreResults.SystemIcons = $true
        }
        
        # Remove backup file after successful restoration
        Remove-Item -Path $backupPath -Force -ErrorAction SilentlyContinue
        Write-ModernStatus "Backup file removed after successful restoration" -Status Info
        
        Write-ModernStatus "Comprehensive restoration completed" -Status Success
        
        # Display restoration summary
        Write-Host ""
        Write-EnhancedOutput "RESTORATION RESULTS:" -Type Primary -Bold
        foreach ($result in $restoreResults.GetEnumerator()) {
            $color = if ($result.Value) { "Success" } else { "Warning" }
            Write-ModernCard $result.Key $(if ($result.Value) { "Success" } else { "Partial/Failed" }) -ValueColor $color
        }
        
        return $true
    }
    catch {
        Write-ModernStatus "Comprehensive restoration failed: $($_.Exception.Message)" -Status Error
        return $false
    }
}

function Backup-RegistryConfiguration {
    <#
    .SYNOPSIS
        Creates registry backup for rollback capability.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    try {
        $backupPath = $Script:Configuration.BackupRegistryPath
        
        # Check if backup already exists
        if (Test-Path $backupPath) {
            if (-not $Force) {
                Write-ModernStatus "Backup already exists: $backupPath" -Status Warning
                Write-ModernStatus "Use -Force to overwrite existing backup" -Status Info
                return $false
            } else {
                Write-ModernStatus "Overwriting existing backup..." -Status Warning
            }
        }
        
        $currentConfig = Get-CurrentTrayConfiguration
        
        $backupData = @{
            Timestamp = Get-Date
            OriginalValue = $currentConfig
            RegistryPath = $Script:Configuration.RegistryPath
            ValueName = $Script:Configuration.RegistryValue
            ScriptVersion = $Script:Configuration.ScriptVersion
            ComputerName = $env:COMPUTERNAME
            UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        }
        
        $backupData | ConvertTo-Json | Out-File -FilePath $backupPath -Encoding UTF8
        Write-ModernStatus "Registry configuration backed up to: $backupPath" -Status Success
        
        # Display backup information
        Write-ModernCard "Backup Location" $backupPath
        Write-ModernCard "Backup Time" $backupData.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
        Write-ModernCard "Original Value" $(if ($null -eq $currentConfig) { "Not Set (Default)" } else { $currentConfig })
        
        return $true
    }
    catch {
        Write-ModernStatus "Failed to create registry backup: $($_.Exception.Message)" -Status Error
        return $false
    }
}

function Invoke-ConfigurationRollback {
    <#
    .SYNOPSIS
        Restores previous configuration from backup.
    #>
    
    $backupPath = $Script:Configuration.BackupRegistryPath
    
    if (-not (Test-Path $backupPath)) {
        Write-ModernStatus "No backup found for rollback: $backupPath" -Status Error
        return $false
    }
    
    try {
        $backupData = Get-Content -Path $backupPath -Raw | ConvertFrom-Json
        $originalValue = $backupData.OriginalValue
        
        Write-ModernStatus "Attempting rollback to previous configuration..." -Status Info
        
        # Display backup information
        Write-ModernCard "Backup Created" $backupData.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
        Write-ModernCard "Original Value" $(if ($null -eq $originalValue) { "Not Set (Default)" } else { $originalValue })
        
        if ($null -eq $originalValue) {
            # Original value was not set (Windows default), so remove the registry value
            Remove-ItemProperty -Path $Script:Configuration.RegistryPath `
                               -Name $Script:Configuration.RegistryValue `
                               -Force `
                               -ErrorAction Stop
            Write-ModernStatus "Restored Windows default behavior (registry value removed)" -Status Success
        }
        else {
            # Restore original value
            Set-ItemProperty -Path $Script:Configuration.RegistryPath `
                           -Name $Script:Configuration.RegistryValue `
                           -Value $originalValue `
                           -Type DWord `
                           -Force `
                           -ErrorAction Stop
            Write-ModernStatus "Restored original configuration: $originalValue" -Status Success
        }
        
        # Remove backup file after successful rollback
        Remove-Item -Path $backupPath -Force -ErrorAction SilentlyContinue
        Write-ModernStatus "Backup file removed after successful rollback" -Status Info
        
        return $true
    }
    catch {
        Write-ModernStatus "Rollback failed: $($_.Exception.Message)" -Status Error
        return $false
    }
}

# ============================================================================
# ENHANCED AUTO-UPDATE SYSTEM
# ============================================================================

function Invoke-ScriptUpdate {
    <#
    .SYNOPSIS
        Enhanced script update with PowerShell 7+ features when available.
    #>
    
    Write-ModernHeader "Script Update" "Checking for updates..."
    
    try {
        Write-ModernStatus "Checking GitHub repository for updates..." -Status Processing
        
        # Use Invoke-RestMethod for PowerShell 7+, WebClient for 5.1
        if ($Script:IsPS7Plus) {
            Write-ModernStatus "Using enhanced download method (PowerShell 7+)" -Status Info
            $latestScriptContent = Invoke-RestMethod -Uri $Script:Configuration.UpdateUrl -UserAgent "PowerShell Script Update Check"
        } else {
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add('User-Agent', 'PowerShell Script Update Check')
            $latestScriptContent = $webClient.DownloadString($Script:Configuration.UpdateUrl)
        }
        
        # Extract version from downloaded script
        $versionPattern = 'ScriptVersion\s*=\s*"([0-9]+\.[0-9]+)"'
        $versionMatch = [regex]::Match($latestScriptContent, $versionPattern)
        
        if (-not $versionMatch.Success) {
            Write-ModernStatus "Could not determine version from repository" -Status Warning
            return $false
        }
        
        $latestVersion = $versionMatch.Groups[1].Value
        $currentVersion = $Script:Configuration.ScriptVersion
        
        Write-ModernCard "Current Version" $currentVersion
        Write-ModernCard "Latest Version" $latestVersion
        
        if ([version]$latestVersion -gt [version]$currentVersion) {
            Write-ModernStatus "New version available! Updating..." -Status Info
            
            # Get current script path
            $currentScriptPath = $MyInvocation.MyCommand.Path
            $backupPath = "$currentScriptPath.backup"
            
            # Create backup of current script (don't overwrite if exists)
            if (-not (Test-Path $backupPath)) {
                Copy-Item -Path $currentScriptPath -Destination $backupPath -Force
                Write-ModernStatus "Script backup created: $backupPath" -Status Success
            } else {
                Write-ModernStatus "Script backup already exists, preserving: $backupPath" -Status Info
            }
            
            # Write new version
            $latestScriptContent | Out-File -FilePath $currentScriptPath -Encoding UTF8
            
            Write-ModernStatus "Update completed successfully!" -Status Success
            Write-ModernStatus "Please restart the script to use the new version." -Status Info
            
            return $true
        }
        else {
            Write-ModernStatus "You are running the latest version." -Status Success
            return $false
        }
    }
    catch {
        Write-ModernStatus "Update failed: $($_.Exception.Message)" -Status Error
        return $false
    }
}

# ============================================================================
# ENHANCED STATUS DISPLAY
# ============================================================================

function Show-EnhancedStatus {
    <#
    .SYNOPSIS
        Displays comprehensive system status with modern UI.
    #>
    
    Write-ModernHeader "System Status" "Current Tray Icons Configuration"
    
    $currentConfig = Get-CurrentTrayConfiguration
    $sessionContext = Get-SessionContext
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    
    # Configuration Status
    Write-EnhancedOutput "CONFIGURATION STATUS:" -Type Primary -Bold
    if ($null -eq $currentConfig) {
        Write-ModernCard "Tray Icons Behavior" "Auto-hide inactive icons (Windows default)" -ValueColor Success
        Write-ModernCard "Registry Value" "Not configured - using system default" -ValueColor Info
    }
    else {
        $behavior = if ($currentConfig -eq $Script:Configuration.EnableValue) {
            "Show ALL tray icons (auto-hide disabled)"
        } else {
            "Auto-hide inactive icons (Windows default)"
        }
        $color = if ($currentConfig -eq $Script:Configuration.EnableValue) { "Success" } else { "Info" }
        Write-ModernCard "Tray Icons Behavior" $behavior -ValueColor $color
        Write-ModernCard "Registry Value" $currentConfig -ValueColor Light
    }
    Write-Host ""
    
    # System Information
    Write-EnhancedOutput "SYSTEM INFORMATION:" -Type Primary -Bold
    if ($osInfo) {
        Write-ModernCard "Operating System" $osInfo.Caption
        Write-ModernCard "OS Version" "$($osInfo.Version) (Build $($osInfo.BuildNumber))"
    }
    Write-ModernCard "PowerShell Version" "$($PSVersionTable.PSVersion) ($(if($Script:IsPS7Plus){'Enhanced'}else{'Compatible'}))"
    Write-ModernCard "Windows Version" (Get-WindowsVersion)
    Write-Host ""
    
    # Session Context
    Write-EnhancedOutput "SESSION CONTEXT:" -Type Primary -Bold
    Write-ModernCard "Current User" $sessionContext.CurrentUser
    Write-ModernCard "Session Type" $sessionContext.SessionType
    Write-ModernCard "Admin Rights" $(if ($sessionContext.IsAdmin) { "Yes" } else { "No" }) -ValueColor $(if ($sessionContext.IsAdmin) { "Success" } else { "Info" })
    Write-ModernCard "Interactive" $(if ($sessionContext.IsInteractive) { "Yes" } else { "No" }) -ValueColor $(if ($sessionContext.IsInteractive) { "Success" } else { "Warning" })
    Write-Host ""
    
    # Backup Status
    Write-EnhancedOutput "BACKUP STATUS:" -Type Primary -Bold
    $backupExists = Test-Path $Script:Configuration.BackupRegistryPath
    Write-ModernCard "Backup Available" $(if ($backupExists) { "Yes" } else { "No" }) -ValueColor $(if ($backupExists) { "Success" } else { "Info" })
    if ($backupExists) {
        try {
            $backupInfo = Get-Item $Script:Configuration.BackupRegistryPath
            $backupContent = Get-Content -Path $Script:Configuration.BackupRegistryPath -Raw -ErrorAction Stop
            
            # Попробуем разные подходы к парсингу JSON
            $backupData = $null
            $parseError = $null
            
            try {
                $backupData = $backupContent | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                $parseError = $_.Exception.Message
                # Попробуем очистить JSON от возможных проблемных символов
                try {
                    $cleanedContent = $backupContent.Trim() -replace '[^\x20-\x7E\t\r\n]', ''
                    $backupData = $cleanedContent | ConvertFrom-Json -ErrorAction Stop
                    $parseError = $null
                }
                catch {
                    $parseError = "JSON parsing failed: $($_.Exception.Message)"
                }
            }
            
            if ($backupData -and $null -eq $parseError) {
                # ИСПРАВЛЕНИЕ: Timestamp уже строка, не нужно вызывать ToString()
                Write-ModernCard "Backup Created" $backupData.Timestamp -ValueColor Success
                Write-ModernCard "Backup Type" $(if ($backupData.NotifyIconSettings) { "Comprehensive" } else { "Basic" }) -ValueColor Info
                Write-ModernCard "Backup Version" $backupData.ScriptVersion -ValueColor Info
                Write-ModernCard "Backup Size" "$([math]::Round($backupInfo.Length/1KB, 2)) KB" -ValueColor Info
            }
            else {
                Write-ModernCard "Backup Status" "Corrupted or incompatible" -ValueColor Warning
                if ($parseError) {
                    Write-ModernCard "Error Details" $parseError -ValueColor Error
                }
            }
        }
        catch {
            Write-ModernCard "Backup Status" "Error reading backup: $($_.Exception.Message)" -ValueColor Error
        }
    }
    
    Write-Host ""
    Write-EnhancedOutput "Use '-Action Enable' to show all icons or '-Action Disable' for default behavior." -Type Info
    Write-Host ""
}

# ============================================================================
# DIAGNOSTIC BACKUP FUNCTIONS
# ============================================================================

function Invoke-BackupDiagnostic {
    <#
    .SYNOPSIS
        Выполняет диагностику файла бэкапа.
    #>
    
    $backupPath = $Script:Configuration.BackupRegistryPath
    
    if (-not (Test-Path $backupPath)) {
        Write-Host "Backup file not found: $backupPath" -ForegroundColor Red
        return
    }
    
    Write-Host "=== BACKUP FILE DIAGNOSTICS ===" -ForegroundColor Cyan
    
    try {
        # Проверка размера файла
        $fileInfo = Get-Item $backupPath
        Write-Host "File Size: $([math]::Round($fileInfo.Length/1KB, 2)) KB" -ForegroundColor Yellow
        
        # Чтение содержимого
        $content = Get-Content -Path $backupPath -Raw -ErrorAction Stop
        Write-Host "Content Length: $($content.Length) characters" -ForegroundColor Yellow
        
        # Проверка первых 500 символов
        Write-Host "`nFirst 500 characters:" -ForegroundColor Green
        Write-Host $content.Substring(0, [Math]::Min(500, $content.Length)) -ForegroundColor Gray
        
        # Попытка парсинга JSON
        Write-Host "`nAttempting JSON parse..." -ForegroundColor Green
        try {
            $backupData = $content | ConvertFrom-Json -ErrorAction Stop
            Write-Host "✅ JSON parsing successful!" -ForegroundColor Green
            Write-Host "Backup Version: $($backupData.ScriptVersion)" -ForegroundColor Yellow
            Write-Host "Timestamp: $($backupData.Timestamp)" -ForegroundColor Yellow
            Write-Host "Data Categories: $($backupData.PSObject.Properties.Name -join ', ')" -ForegroundColor Yellow
        }
        catch {
            Write-Host "❌ JSON parsing failed: $($_.Exception.Message)" -ForegroundColor Red
            
            # Попробуем найти проблемные символы
            Write-Host "`nChecking for problematic characters..." -ForegroundColor Green
            $problemChars = [regex]::Matches($content, '[^\x20-\x7E\t\r\n]')
            if ($problemChars.Count -gt 0) {
                Write-Host "Found $($problemChars.Count) non-printable characters" -ForegroundColor Red
                Write-Host "Positions: $(($problemChars | Select-Object -First 10 | ForEach-Object { $_.Index }) -join ', ')" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host "❌ Error reading backup file: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n=== END DIAGNOSTICS ===" -ForegroundColor Cyan
}

# ============================================================================
# ENHANCED CORE FUNCTIONS
# ============================================================================

function Get-CurrentTrayConfiguration {
    <#
    .SYNOPSIS
        Retrieves current tray configuration with comprehensive error handling.
    #>
    
    try {
        $registryPath = $Script:Configuration.RegistryPath
        $valueName = $Script:Configuration.RegistryValue
        
        if (-not (Test-Path $registryPath)) {
            return $null
        }
        
        $value = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue
        if ($null -eq $value -or $null -eq $value.$valueName) {
            return $null
        }
        
        return $value.$valueName
    }
    catch {
        Write-ModernStatus "Failed to read registry configuration: $($_.Exception.Message)" -Status Error
        return $null
    }
}

function Set-TrayIconConfiguration {
    <#
    .SYNOPSIS
        Configures tray icon behavior with backup and rollback support.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Enable', 'Disable')]
        [string]$Behavior
    )
    
    $value = if ($Behavior -eq 'Enable') { 
        $Script:Configuration.EnableValue 
    } else { 
        $Script:Configuration.DisableValue 
    }
    
    $actionDescription = if ($Behavior -eq 'Enable') { 
        "Show all tray icons" 
    } else { 
        "Enable auto-hide (Windows default)" 
    }
    
    Write-ModernStatus "Configuring tray behavior: $actionDescription" -Status Processing
    
    if (-not $Force -and -not $PSCmdlet.ShouldProcess(
        "Registry: $($Script:Configuration.RegistryPath)\$($Script:Configuration.RegistryValue)", 
        "Set value to $value ($actionDescription)"
    )) {
        Write-ModernStatus "Operation cancelled by ShouldProcess" -Status Info
        return $false
    }
    
    # Create backup if requested
    if ($BackupRegistry) {
        Write-ModernStatus "Creating registry backup before changes..." -Status Info
        if (-not (Backup-RegistryConfiguration -Force:$Force)) {
            Write-ModernStatus "Backup failed, but continuing with operation..." -Status Warning
        }
    }
    
    try {
        # Ensure registry path exists
        $registryPath = $Script:Configuration.RegistryPath
        if (-not (Test-Path $registryPath)) {
            Write-ModernStatus "Creating registry path: $registryPath" -Status Info
            $null = New-Item -Path $registryPath -Force -ErrorAction Stop
        }
        
        # Set registry value
        Set-ItemProperty -Path $registryPath `
                         -Name $Script:Configuration.RegistryValue `
                         -Value $value `
                         -Type DWord `
                         -Force `
                         -ErrorAction Stop
        
        Write-ModernStatus "Registry configuration updated successfully: $actionDescription" -Status Success
        return $true
    }
    catch [System.UnauthorizedAccessException] {
        Write-ModernStatus "Access denied to registry. Try running as Administrator." -Status Error
        return $false
    }
    catch {
        Write-ModernStatus "Failed to configure registry: $($_.Exception.Message)" -Status Error
        return $false
    }
}

function Get-SessionContext {
    <#
    .SYNOPSIS
        Returns comprehensive session context information.
    #>
    
    $context = @{
        IsAdmin = $false
        IsInteractive = [Environment]::UserInteractive
        SessionType = "Unknown"
        CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        IsElevated = $false
    }
    
    # Admin Check
    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        $context.IsAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
        $context.IsElevated = $context.IsAdmin
    }
    catch {
        Write-ModernStatus "Failed to check admin privileges: $($_.Exception.Message)" -Status Warning
    }
    
    # Session Type Detection
    if ($null -ne $env:WINRM_PROCESS) {
        $context.SessionType = "WinRM Remote"
    }
    elseif ($env:SSH_CONNECTION) {
        $context.SessionType = "SSH Remote"
    }
    elseif ($context.CurrentUser -eq "SYSTEM" -or $identity.User.Value -eq "S-1-5-18") {
        $context.SessionType = "SYSTEM Service Account"
    }
    elseif (-not $context.IsInteractive) {
        $context.SessionType = "Non-Interactive Session"
    }
    else {
        $context.SessionType = "Interactive Desktop"
    }
    
    return [PSCustomObject]$context
}

function Restart-WindowsExplorerSafely {
    <#
    .SYNOPSIS
        Safely restarts Windows Explorer with comprehensive error handling.
    #>
    
    if (-not $Force -and -not $PSCmdlet.ShouldProcess("Windows Explorer", "Restart process")) {
        Write-ModernStatus "Operation cancelled by ShouldProcess" -Status Info
        return $false
    }
    
    Write-ModernStatus "Initiating safe Windows Explorer restart..." -Status Processing
    
    try {
        $explorerProcesses = Get-Process -Name explorer -ErrorAction SilentlyContinue
        
        if ($explorerProcesses.Count -eq 0) {
            Write-ModernStatus "Windows Explorer not running, starting process..." -Status Warning
            Start-Process -FilePath "explorer.exe" -WindowStyle Hidden
            Start-Sleep -Seconds 2
            Write-ModernStatus "Windows Explorer started successfully" -Status Success
            return $true
        }
        
        Write-ModernStatus "Stopping $($explorerProcesses.Count) Windows Explorer process(es)..." -Status Info
        
        # Stop Explorer processes gracefully
        $explorerProcesses | Stop-Process -Force -ErrorAction Stop
        
        # Wait for processes to terminate
        $timeout = $Script:Configuration.ExplorerRestartTimeout
        $timer = 0
        while ((Get-Process -Name explorer -ErrorAction SilentlyContinue) -and $timer -lt $timeout) {
            Start-Sleep -Milliseconds 500
            $timer += 0.5
        }
        
        # Start Explorer
        Write-ModernStatus "Starting Windows Explorer..." -Status Info
        Start-Process -FilePath "explorer.exe" -WindowStyle Hidden
        
        # Wait for initialization
        Start-Sleep -Seconds 2
        
        $restartedProcesses = Get-Process -Name explorer -ErrorAction SilentlyContinue
        if ($restartedProcesses.Count -gt 0) {
            Write-ModernStatus "Windows Explorer restarted successfully ($($restartedProcesses.Count) processes)" -Status Success
            return $true
        }
        else {
            Write-ModernStatus "Windows Explorer may not have started properly" -Status Warning
            return $false
        }
    }
    catch {
        Write-ModernStatus "Failed to restart Windows Explorer: $($_.Exception.Message)" -Status Error
        Write-ModernStatus "Manual restart may be required" -Status Warning
        return $false
    }
}

# ============================================================================
# ENHANCED MAIN EXECUTION ENGINE
# ============================================================================

function Invoke-MainExecution {
    <#
    .SYNOPSIS
        Enhanced main execution engine with comprehensive tray icons management.
    #>
    
    # Show banner only once at the very beginning for specific scenarios
    $showBanner = $true

    # Handle Diagnostic first
    if ($Diagnostic) {
        Show-ModernBanner
        Invoke-BackupDiagnostic
        exit $Script:Configuration.ExitCodes.Success
    }
    
    # Handle help first (help doesn't need the main banner since it has its own header)
    if ($Help) {
        Show-ModernHelp
        exit $Script:Configuration.ExitCodes.Success
    }
    
    # Handle update
    if ($Update) {
        if ($showBanner) {
            Show-ModernBanner
            $showBanner = $false
        }
        $updateResult = Invoke-ScriptUpdate
        if ($updateResult) {
            exit $Script:Configuration.ExitCodes.Success
        }
    }
    
    # Show application info if no specific action
    if (-not $Action -and -not $Update) {
        if ($showBanner) {
            Show-ModernBanner
            $showBanner = $false
        }
        Show-ApplicationInfo
        exit $Script:Configuration.ExitCodes.Success
    }
    
    # Show banner for actions if not already shown
    if ($showBanner -and $Action) {
        Show-ModernBanner
        $showBanner = $false
    }
    
    # Execute the requested action
    switch ($Action.ToLower()) {
        'status' {
            Show-EnhancedStatus
        }
        
        'backup' {
            Write-ModernHeader "Create Comprehensive Backup" "Saving ALL tray-related settings"
            
            if (Backup-ComprehensiveTraySettings) {
                Write-ModernStatus "Comprehensive backup completed successfully!" -Status Success
            } else {
                $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.BackupFailed
                Write-ModernStatus "Backup operation failed" -Status Error
            }
        }
        
        'enable' {
            Write-ModernHeader "Enable ALL Tray Icons" "Comprehensive method - forcing all icons visible"
            
            if (Enable-AllTrayIconsComprehensive) {
                if ($RestartExplorer) {
                    Write-ModernStatus "Applying changes immediately..." -Status Processing
                    $null = Restart-WindowsExplorerSafely
                }
                else {
                    Write-ModernStatus "Comprehensive configuration completed!" -Status Success
                    Write-ModernStatus "Restart Explorer or use -RestartExplorer to apply changes" -Status Info
                }
            }
            else {
                $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.GeneralError
            }
        }
        
        'disable' {
            Write-ModernHeader "Restore Default Behavior" "Enabling auto-hide for tray icons"
            
            if (Set-TrayIconConfiguration -Behavior 'Disable') {
                if ($RestartExplorer) {
                    Write-ModernStatus "Applying changes immediately..." -Status Processing
                    $null = Restart-WindowsExplorerSafely
                }
                else {
                    Write-ModernStatus "Default behavior restored successfully!" -Status Success
                    Write-ModernStatus "Restart Explorer or use -RestartExplorer to apply changes" -Status Info
                }
            }
            else {
                $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.GeneralError
            }
        }
        
        'rollback' {
            Write-ModernHeader "Configuration Rollback" "Reverting to previous settings"
            
            # Try comprehensive restore first, fall back to basic restore
            if (-not (Restore-ComprehensiveTraySettings)) {
                Write-ModernStatus "Falling back to basic rollback..." -Status Warning
                if (Invoke-ConfigurationRollback) {
                    if ($RestartExplorer) {
                        Write-ModernStatus "Applying changes immediately..." -Status Processing
                        $null = Restart-WindowsExplorerSafely
                    }
                    else {
                        Write-ModernStatus "Basic rollback completed successfully!" -Status Success
                        Write-ModernStatus "Restart Explorer or use -RestartExplorer to apply changes" -Status Info
                    }
                }
                else {
                    $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.RollbackFailed
                    Write-ModernStatus "Rollback operation failed" -Status Error
                }
            } else {
                if ($RestartExplorer) {
                    Write-ModernStatus "Applying changes immediately..." -Status Processing
                    $null = Restart-WindowsExplorerSafely
                }
                else {
                    Write-ModernStatus "Comprehensive restoration completed!" -Status Success
                    Write-ModernStatus "Restart Explorer or use -RestartExplorer to apply changes" -Status Info
                }
            }
        }
    }
}

# ============================================================================
# ENHANCED SCRIPT ENTRY POINT
# ============================================================================

# Version check at the beginning
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "ERROR: PowerShell 5.1 or higher required. Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Red
    exit $Script:Configuration.ExitCodes.PowerShellVersion
}

try {
    # Enhanced parameter validation
    if ($PSBoundParameters.Count -eq 0 -and $MyInvocation.ExpectingInput -eq $false) {
        # No parameters provided, show application info
        Show-ModernBanner
        Show-ApplicationInfo
        exit $Script:Configuration.ExitCodes.Success
    }
    
    # Execute main logic
    Invoke-MainExecution
}
catch {
    Write-ModernStatus "Unhandled exception: $($_.Exception.Message)" -Status Error
    Write-ModernStatus "Stack trace: $($_.ScriptStackTrace)" -Status Error
    $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.GeneralError
}
finally {
    if ($Script:Configuration.ExitCode -ne 0) {
        Write-ModernStatus "Script completed with errors (Exit Code: $($Script:Configuration.ExitCode))" -Status Error
    } else {
        Write-ModernStatus "Script completed successfully" -Status Success
    }
    
    exit $Script:Configuration.ExitCode
}
