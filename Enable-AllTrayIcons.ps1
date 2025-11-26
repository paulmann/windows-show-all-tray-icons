<#
.SYNOPSIS
    Enable or disable automatic hiding of system tray icons in Windows 11/10 with Group Policy support.

.DESCRIPTION
    Enterprise-grade PowerShell script for managing system tray icon visibility.
    Features comprehensive error handling, logging, session validation, rollback support,
    individual icon settings reset, Group Policy management, and advanced diagnostic capabilities.
    
    NEW IN VERSION 5.7:
    - Administrator rights validation and elevation support
    - Group Policy configuration for all users
    - Enhanced enterprise deployment features
    - Multi-user registry management
    - Advanced security context validation
    - Enterprise backup/restore capabilities

    Author: Mikhail Deynekin (mid1977@gmail.com)
    Website: https://deynekin.com
    Repository: https://github.com/paulmann/windows-show-all-tray-icons
    Version: 5.7 (Enterprise Edition - Group Policy Enhanced)

.PARAMETER Action
    Specifies the action to perform:
    - 'Enable'  : Show all system tray icons (disable auto-hide) [Value: 0]
    - 'Disable' : Restore Windows default behavior (enable auto-hide) [Value: 1]
    - 'Status'  : Check current configuration without making changes
    - 'Rollback': Revert to previous configuration if backup exists
    - 'Backup'  : Create registry backup without making changes

.PARAMETER AllUsers
    Apply settings to all users via Group Policy (requires administrator rights).

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
    .\Enable-AllTrayIcons.ps1 -Action Enable -AllUsers -RestartExplorer -Force
    Shows all icons for all users via Group Policy, restarts Explorer, and bypasses prompts.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Action Status
    Displays comprehensive system status.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Action Backup -AllUsers
    Creates registry backup for all users configuration.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Action Rollback -AllUsers
    Reverts to previous configuration for all users if backup exists.

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
    Version:        5.7 (Enterprise Edition - Group Policy Enhanced)
    Creation Date:  2025-11-21
    Last Updated:   2025-11-23
    Compatibility:  Windows 10 (All versions), Windows 11 (All versions), Server 2019+
    Requires:       PowerShell 5.1 or higher (with enhanced features for PowerShell 7+)
    Privileges:     Standard User (HKCU) or Administrator (AllUsers/Group Policy)
    
    ENHANCED FEATURES:
    - Administrator rights validation and elevation instructions
    - Group Policy configuration for all users
    - Multi-user registry management
    - Enterprise deployment support
    - Enhanced security context validation
    - Comprehensive individual icon settings reset
    - Multiple methods for forcing icon visibility
    - Enhanced backup/restore for all tray-related settings
    - Windows 11 specific optimizations
    - Professional reporting and status display
    - Advanced diagnostic capabilities
    - Dynamic registry path management
    - Comprehensive error handling with rollback protection

.LINK
    GitHub Repository: https://github.com/paulmann/windows-show-all-tray-icons
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet('Enable', 'Disable', 'Status', 'Rollback', 'Backup', IgnoreCase = $true)]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [switch]$AllUsers,

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
[ValidateSet('Full', 'Quick', 'Admin', 'Security', IgnoreCase = $true)]
[string]$HelpLevel = 'Quick',

    [Parameter(Mandatory = $false)]
    [switch]$Diagnostic,

    # Hidden parameter for internal help functions
    [Parameter(Mandatory = $false, DontShow = $true)]
    [switch]$QuickHelp

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
    
    # Group Policy Configuration
    GroupPolicyUserPath = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
    GroupPolicyMachinePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
    GroupPolicyValue = "EnableAutoTray"
    
    # Script Metadata
    ScriptVersion = "5.7"
    ScriptAuthor = "Mikhail Deynekin (mid1977@gmail.com)"
    ScriptName = "Enable-AllTrayIcons.ps1"
    GitHubRepository = "https://github.com/paulmann/windows-show-all-tray-icons"
    UpdateUrl = "https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/refs/heads/main/Enable-AllTrayIcons.ps1"
    
    # Path Configuration
    DefaultLogPath = "$env:TEMP\Enable-AllTrayIcons.log"
    BackupRegistryPath = "$env:TEMP\TrayIconsBackup.reg"
    AllUsersBackupPath = "$env:TEMP\TrayIconsBackup-AllUsers.reg"
    
    # Performance Configuration
    ExplorerRestartTimeout = 10  # seconds
    ProcessWaitTimeout = 5       # seconds
    
    # Security Configuration
    RequiredPSVersion = "5.1"
    
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
        AdminRightsRequired = 8
        GroupPolicyFailed = 9
    }
}

# ============================================================================
# SECURITY AND ADMINISTRATOR VALIDATION
# ============================================================================

function Test-AdministratorRights {
    <#
    .SYNOPSIS
        Validates if the current user has administrator privileges.
    #>
    try {
        $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-ModernStatus "Failed to check administrator rights: $($_.Exception.Message)" -Status Error
        return $false
    }
}

function Test-PowerShellVersion {
    <#
    .SYNOPSIS
        Validates if the current PowerShell version meets requirements.
    #>
    $currentVersion = $PSVersionTable.PSVersion
    if ($currentVersion -lt [version]$Script:Configuration.RequiredPSVersion) {
        Write-ModernStatus "PowerShell version $currentVersion is below required $($Script:Configuration.RequiredPSVersion)" -Status Error
        return $false
    }
    return $true
}

function Show-AdministratorInstructions {
    <#
    .SYNOPSIS
        Displays instructions for running script as administrator.
    #>
    Write-ModernHeader "Administrator Rights Required" "Elevation Instructions"
    
    Write-EnhancedOutput "This operation requires administrator privileges to continue." -Type Warning
    Write-Host ""
    
    Write-EnhancedOutput "HOW TO RUN AS ADMINISTRATOR:" -Type Primary
    Write-ModernCard "Method 1" "Right-click PowerShell and select 'Run as Administrator'"
    Write-ModernCard "Method 2" "Run from elevated command prompt: 'powershell -ExecutionPolicy Bypass -File Enable-AllTrayIcons.ps1'"
    Write-ModernCard "Method 3" "Use Windows Terminal as Administrator"
    Write-Host ""
    
    Write-EnhancedOutput "ALTERNATIVE OPTIONS:" -Type Primary
    Write-ModernCard "Current User Only" "Remove -AllUsers parameter to apply to current user only"
    Write-ModernCard "Standard Mode" "Run without administrator rights for current user configuration"
    Write-Host ""
    
    Write-EnhancedOutput "NOTE:" -Type Primary
    Write-EnhancedOutput "  - Group Policy modifications require administrator rights" -Type Info
    Write-EnhancedOutput "  - Current user settings work without elevation" -Type Info
    Write-EnhancedOutput "  - Some enterprise features may be limited without admin rights" -Type Info
    Write-Host ""
}

function Test-ExecutionPolicy {
    <#
    .SYNOPSIS
        Validates execution policy and provides instructions if blocked.
    #>
    try {
        $executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
        if ($executionPolicy -eq "Restricted") {
            Write-ModernStatus "Execution Policy is Restricted - script execution blocked" -Status Error
            Write-EnhancedOutput "To fix this issue, run:" -Type Warning
            Write-Host "  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Yellow
            Write-Host "  Or use: powershell -ExecutionPolicy Bypass -File Enable-AllTrayIcons.ps1" -ForegroundColor Yellow
            return $false
        }
        return $true
    }
    catch {
        Write-ModernStatus "Could not verify execution policy: $($_.Exception.Message)" -Status Warning
        return $true
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

# ============================================================================
# CORE SESSION CONTEXT FUNCTION (MOVED BEFORE USE)
# ============================================================================

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
        Write-Host "Failed to check admin privileges: $($_.Exception.Message)" -ForegroundColor Yellow
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

function Show-ModernBanner {
    <#
    .SYNOPSIS
        Displays a modern application banner.
    #>
    
    # Используем script-scope переменную для отслеживания состояния баннера
    if ($script:showBanner -eq $true) {
        Write-Host ""
        Write-Host "================================================================" -ForegroundColor $Script:ConsoleColors.Primary
        Write-Host "   WINDOWS SYSTEM TRAY ICONS CONFIGURATION TOOL" -ForegroundColor $Script:ConsoleColors.Light
        Write-Host "       ENTERPRISE EDITION - GROUP POLICY ENHANCED" -ForegroundColor $Script:ConsoleColors.Info
        Write-Host "================================================================" -ForegroundColor $Script:ConsoleColors.Primary
        Write-Host ""
        $script:showBanner = $false
    }
}

# ============================================================================
# HELP SYSTEM
# ============================================================================

function Show-ModernHelp {
    <#
    .SYNOPSIS
        Displays comprehensive help information with enhanced Group Policy features.
    #>
    Write-ModernHeader "Windows System Tray Icons Configuration Tool" "v$($Script:Configuration.ScriptVersion)"
    Write-EnhancedOutput "DESCRIPTION:" -Type Primary
    Write-EnhancedOutput "  Professional tool for managing system tray icon visibility in Windows 10/11." -Type Light
    Write-EnhancedOutput "  Modifies registry and Group Policy settings to control notification area behavior" -Type Light
    Write-EnhancedOutput "  with comprehensive individual icon settings reset and enterprise deployment support." -Type Light
    Write-Host ""
    Write-EnhancedOutput "QUICK EXAMPLES:" -Type Primary
    Write-Host "  Show all icons (current user)    : .\$($Script:Configuration.ScriptName) -Action Enable" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Show all icons (all users)       : .\$($Script:Configuration.ScriptName) -Action Enable -AllUsers" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Show all + restart               : .\$($Script:Configuration.ScriptName) -Action Enable -RestartExplorer" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Restore default                  : .\$($Script:Configuration.ScriptName) -Action Disable" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Check status                     : .\$($Script:Configuration.ScriptName) -Action Status" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Create backup                    : .\$($Script:Configuration.ScriptName) -Action Backup" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Restore backup                   : .\$($Script:Configuration.ScriptName) -Action Rollback" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host ""
    Write-EnhancedOutput "ACTIONS:" -Type Primary
    Write-ModernCard "Enable" "Show all tray icons (disable auto-hide)"
    Write-ModernCard "Disable" "Restore Windows default (enable auto-hide)"
    Write-ModernCard "Status" "Show current configuration and Group Policy status"
    Write-ModernCard "Backup" "Create comprehensive registry backup"
    Write-ModernCard "Rollback" "Restore from previous backup"
    Write-Host ""
    Write-EnhancedOutput "GROUP POLICY ACTIONS (REQUIRES ADMIN RIGHTS):" -Type Primary
    Write-ModernCard "Enable -AllUsers" "Apply settings to ALL users via Group Policy"
    Write-ModernCard "Disable -AllUsers" "Restore default for ALL users via Group Policy"
    Write-ModernCard "Backup -AllUsers" "Backup Group Policy and all user settings"
    Write-ModernCard "Rollback -AllUsers" "Restore Group Policy and all user settings"
    Write-Host ""
    Write-EnhancedOutput "OPTIONS:" -Type Primary
    Write-ModernCard "-AllUsers" "Apply to ALL users (requires administrator rights)"
    Write-ModernCard "-RestartExplorer" "Apply changes immediately by restarting Windows Explorer"
    Write-ModernCard "-BackupRegistry" "Create automatic backup before making changes"
    Write-ModernCard "-Force" "Bypass all confirmation prompts and warnings"
    Write-ModernCard "-LogPath <path>" "Specify custom log file location"
    Write-ModernCard "-Update" "Check and update script from GitHub repository"
    Write-ModernCard "-Diagnostic" "Run backup file diagnostics and validation"
    Write-ModernCard "-HelpLevel <type>" "Specify help type: Full, Quick, Admin, or Security" -ValueColor Info
    Write-Host ""
    Write-EnhancedOutput "HELP LEVELS:" -Type Primary
    Write-ModernCard "Full" "Complete documentation with all parameters, examples and enterprise deployment details" -ValueColor Light
    Write-ModernCard "Quick" "Brief overview of common commands (default when using -Help)" -ValueColor Light
    Write-ModernCard "Admin" "Detailed administrator instructions including elevation requirements and Group Policy deployment" -ValueColor Light
    Write-ModernCard "Security" "Security context information including privileges, execution policies and session details" -ValueColor Light
    Write-Host ""
    Write-EnhancedOutput "HELP LEVEL EXAMPLES:" -Type Primary
    Write-Host "  Show full documentation           : .\$($Script:Configuration.ScriptName) -Help" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Show quick reference              : .\$($Script:Configuration.ScriptName) -Help -HelpLevel Quick" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Show admin instructions           : .\$($Script:Configuration.ScriptName) -Help -HelpLevel Admin" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Show security context             : .\$($Script:Configuration.ScriptName) -Help -HelpLevel Security" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host ""
    Write-EnhancedOutput "ADVANCED FEATURES:" -Type Primary
    Write-ModernCard "Administrator Rights Check" "Automatic validation for Group Policy operations"
    Write-ModernCard "Group Policy Deployment" "Enterprise-wide settings via User/Machine policies"
    Write-ModernCard "Multi-User Registry Management" "Apply settings to all user hives"
    Write-ModernCard "Comprehensive Backup System" "Backup registry, Group Policy, and individual settings"
    Write-ModernCard "Individual Icon Reset" "Reset per-application notification settings"
    Write-ModernCard "Windows 11 Optimization" "Special optimizations for Windows 11 taskbar"
    Write-ModernCard "System Icons Control" "Manage volume, network, power indicators"
    Write-Host ""
    Write-EnhancedOutput "NOTES:" -Type Primary
    Write-EnhancedOutput "  - All parameters are case-insensitive" -Type Info
    Write-EnhancedOutput "  - Admin rights required only for -AllUsers parameter" -Type Info
    Write-EnhancedOutput "  - Works on Windows 10/11, Server 2019+" -Type Info
    Write-EnhancedOutput "  - When -Help is specified without -HelpLevel, Full help is shown by default" -Type Info
    Write-Host ""
    Write-EnhancedOutput "ADDITIONAL INFORMATION:" -Type Primary
    Write-ModernCard "Version" $Script:Configuration.ScriptVersion
    Write-ModernCard "Author" $Script:Configuration.ScriptAuthor
    Write-ModernCard "Repository" $Script:Configuration.GitHubRepository
    Write-ModernCard "PowerShell Version" "$($PSVersionTable.PSVersion) ($(if($Script:IsPS7Plus){'Enhanced'}else{'Compatible'}))"
    Write-ModernCard "Admin Rights" $(if (Test-AdministratorRights) { "Available" } else { "Not Available" }) -ValueColor $(if (Test-AdministratorRights) { "Success" } else { "Info" })
    Write-ModernCard "Execution Policy" (Get-ExecutionPolicy -Scope CurrentUser)
    Write-Host ""
    Write-EnhancedOutput "Note: -AllUsers parameter requires administrator rights. All other operations work without elevation." -Type Dark
    Write-EnhancedOutput "Use -Force to bypass confirmation prompts in automated scripts." -Type Dark
    Write-Host ""
}

function Show-QuickHelp {
    <#
    .SYNOPSIS
        Displays brief help information for quick reference.
    #>
    
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "   WINDOWS SYSTEM TRAY ICONS CONFIGURATION TOOL" -ForegroundColor White
    Write-Host "       ENTERPRISE EDITION - GROUP POLICY ENHANCED" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "QUICK EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  Show all icons (current user)    : .\$($Script:Configuration.ScriptName) -Action Enable" -ForegroundColor Gray
    Write-Host "  Show all icons (all users)       : .\$($Script:Configuration.ScriptName) -Action Enable -AllUsers" -ForegroundColor Gray
    Write-Host "  Show all + restart               : .\$($Script:Configuration.ScriptName) -Action Enable -RestartExplorer" -ForegroundColor Gray
    Write-Host "  Restore default                  : .\$($Script:Configuration.ScriptName) -Action Disable" -ForegroundColor Gray
    Write-Host "  Check status                     : .\$($Script:Configuration.ScriptName) -Action Status" -ForegroundColor Gray
    Write-Host "  Create backup                    : .\$($Script:Configuration.ScriptName) -Action Backup" -ForegroundColor Gray
    Write-Host "  Restore backup                   : .\$($Script:Configuration.ScriptName) -Action Rollback" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "ACTIONS:" -ForegroundColor Yellow
    Write-Host "  Enable    : Show all tray icons (disable auto-hide)" -ForegroundColor Gray
    Write-Host "  Disable   : Restore Windows default (enable auto-hide)" -ForegroundColor Gray
    Write-Host "  Status    : Show current configuration and Group Policy status" -ForegroundColor Gray
    Write-Host "  Backup    : Create comprehensive registry backup" -ForegroundColor Gray
    Write-Host "  Rollback  : Restore from previous backup" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "GROUP POLICY ACTIONS (REQUIRES ADMIN RIGHTS):" -ForegroundColor Yellow
    Write-Host "  Enable -AllUsers  : Apply settings to ALL users via Group Policy" -ForegroundColor Gray
    Write-Host "  Disable -AllUsers : Restore default for ALL users via Group Policy" -ForegroundColor Gray
    Write-Host "  Backup -AllUsers  : Backup Group Policy and all user settings" -ForegroundColor Gray
    Write-Host "  Rollback -AllUsers: Restore Group Policy and all user settings" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "OPTIONS:" -ForegroundColor Yellow
    Write-Host "  -AllUsers        : Apply to ALL users (requires administrator rights)" -ForegroundColor Gray
    Write-Host "  -RestartExplorer : Apply changes immediately" -ForegroundColor Gray
    Write-Host "  -BackupRegistry  : Create backup before changes" -ForegroundColor Gray
    Write-Host "  -Force           : Bypass confirmation prompts" -ForegroundColor Gray
    Write-Host ""

    Write-Host "HELP OPTIONS:" -ForegroundColor Yellow
    Write-Host "  -Help                  : Show full comprehensive help" -ForegroundColor Gray
    Write-Host "  -Help Quick            : Show brief quick reference" -ForegroundColor Gray
    Write-Host "  -Help Admin            : Show administrator instructions" -ForegroundColor Gray
    Write-Host "  -Help Security         : Show security context information" -ForegroundColor Gray
    Write-Host "  -QuickHelp             : Alternative quick help (hidden)" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "NOTES:" -ForegroundColor Yellow
    Write-Host "  - All parameters are case-insensitive" -ForegroundColor DarkGray
    Write-Host "  - Admin rights required only for -AllUsers parameter" -ForegroundColor DarkGray
    Write-Host "  - Works on Windows 10/11, Server 2019+" -ForegroundColor DarkGray
    Write-Host "  - Use -Help for detailed information and examples" -ForegroundColor DarkGray
    Write-Host ""
    
    Write-Host "  [OK] Use -Help for complete documentation and enterprise deployment examples" -ForegroundColor Green
    Write-Host ""
}

function Show-SecurityContext {
    <#
    .SYNOPSIS
        Displays current security context and privileges.
    #>
    
    $context = Get-SessionContext
    
    Write-Host ""
    Write-Host "=== SECURITY CONTEXT ===" -ForegroundColor Cyan
    Write-ModernCard "Current User" $context.CurrentUser
    Write-ModernCard "Administrator Rights" $(if ($context.IsAdmin) { "Yes" } else { "No" }) -ValueColor $(if ($context.IsAdmin) { "Success" } else { "Warning" })
    Write-ModernCard "Session Type" $context.SessionType
    Write-ModernCard "Interactive" $(if ($context.IsInteractive) { "Yes" } else { "No" }) -ValueColor $(if ($context.IsInteractive) { "Success" } else { "Warning" })
    Write-ModernCard "Execution Policy" (Get-ExecutionPolicy -Scope CurrentUser)
    Write-Host ""
}

# ============================================================================
# ENHANCED HELP SYSTEM
# ============================================================================

function Invoke-HelpSystem {
    <#
    .SYNOPSIS
        Enhanced help system with intelligent parameter handling and validation.
    
    .DESCRIPTION
        Handles help requests with comprehensive validation and fallback behavior.
        Supports multiple help levels and provides clear error messages for invalid parameters.
    #>
    param(
        [string]$HelpLevel = 'Quick'
    )
    
    # Validate help level and provide clear error messages
    $validHelpLevels = @('Full', 'Quick', 'Admin', 'Security')
    
    if ($HelpLevel -and $HelpLevel -notin $validHelpLevels) {
        Write-ModernStatus "Invalid help type: '$HelpLevel'" -Status Error
        Write-Host ""
        Write-EnhancedOutput "VALID HELP TYPES:" -Type Primary
        Write-ModernCard "Full" "Comprehensive documentation with examples"
        Write-ModernCard "Quick" "Brief reference guide (default)"
        Write-ModernCard "Admin" "Administrator rights instructions"
        Write-ModernCard "Security" "Security context information"
        Write-Host ""
        Write-EnhancedOutput "Examples:" -Type Info
        Write-Host "  .\$($Script:Configuration.ScriptName) -Help" -ForegroundColor Yellow
        Write-Host "  .\$($Script:Configuration.ScriptName) -Help Full" -ForegroundColor Yellow
        Write-Host "  .\$($Script:Configuration.ScriptName) -Help Admin" -ForegroundColor Yellow
        Write-Host ""
        exit $Script:Configuration.ExitCodes.GeneralError
    }
    
    # Show appropriate help based on validated level
    switch ($HelpLevel) {
        'Full' {
            Show-ModernHelp
        }
        'Quick' {
            Show-QuickHelp
        }
        'Admin' {
            Show-AdministratorInstructions
        }
        'Security' {
            Show-SecurityContext
        }
        default {
            Show-QuickHelp
        }
    }
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
    Write-ModernCard "Admin Rights" $(if (Test-AdministratorRights) { "Yes" } else { "No" }) -ValueColor $(if (Test-AdministratorRights) { "Success" } else { "Info" })
    Write-ModernCard "Enhanced Features" "Group Policy support, individual settings reset"
    
    Write-Host ""
    Write-EnhancedOutput "Use '-Help' for detailed usage information." -Type Info
    Write-Host ""
}

# ============================================================================
# GROUP POLICY AND ENTERPRISE MANAGEMENT
# ============================================================================

function Set-GroupPolicyConfiguration {
    <#
    .SYNOPSIS
        Configures Group Policy settings for all users.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Enable', 'Disable')]
        [string]$Behavior
    )
    
    if (-not (Test-AdministratorRights)) {
        Write-ModernStatus "Administrator rights required for Group Policy configuration" -Status Error
        Show-AdministratorInstructions
        return $false
    }
    
    $value = if ($Behavior -eq 'Enable') { 
        $Script:Configuration.EnableValue 
    } else { 
        $Script:Configuration.DisableValue 
    }
    
    $actionDescription = if ($Behavior -eq 'Enable') { 
        "Show all tray icons for all users" 
    } else { 
        "Enable auto-hide (Windows default) for all users" 
    }
    
    Write-ModernStatus "Configuring Group Policy: $actionDescription" -Status Processing
    
    if (-not $Force -and -not $PSCmdlet.ShouldProcess(
        "Group Policy for all users", 
        "Set value to $value ($actionDescription)"
    )) {
        Write-ModernStatus "Operation cancelled by ShouldProcess" -Status Info
        return $false
    }
    
    try {
        # Method 1: Set User Group Policy (affects all users)
        $userPolicyPath = $Script:Configuration.GroupPolicyUserPath
        if (-not (Test-Path $userPolicyPath)) {
            Write-ModernStatus "Creating Group Policy user path: $userPolicyPath" -Status Info
            $null = New-Item -Path $userPolicyPath -Force -ErrorAction Stop
        }
        
        Set-ItemProperty -Path $userPolicyPath `
                         -Name $Script:Configuration.GroupPolicyValue `
                         -Value $value `
                         -Type DWord `
                         -Force `
                         -ErrorAction Stop
        
        Write-ModernStatus "Group Policy user configuration updated" -Status Success
        
        # Method 2: Also set machine policy for broader coverage
        $machinePolicyPath = $Script:Configuration.GroupPolicyMachinePath
        if (-not (Test-Path $machinePolicyPath)) {
            Write-ModernStatus "Creating Group Policy machine path: $machinePolicyPath" -Status Info
            $null = New-Item -Path $machinePolicyPath -Force -ErrorAction Stop
        }
        
        Set-ItemProperty -Path $machinePolicyPath `
                         -Name $Script:Configuration.GroupPolicyValue `
                         -Value $value `
                         -Type DWord `
                         -Force `
                         -ErrorAction Stop
        
        Write-ModernStatus "Group Policy machine configuration updated" -Status Success
        
        # Method 3: Set registry for all existing user hives
        if (Set-RegistryForAllUsers -Value $value) {
            Write-ModernStatus "Registry settings applied to all user hives" -Status Success
        }
        
        Write-ModernStatus "Group Policy configuration completed: $actionDescription" -Status Success
        return $true
    }
    catch {
        Write-ModernStatus "Failed to configure Group Policy: $($_.Exception.Message)" -Status Error
        return $false
    }
}

function Set-RegistryForAllUsers {
    <#
    .SYNOPSIS
        Applies registry settings to all user hives for enterprise deployment.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [int]$Value
    )
    
    Write-ModernStatus "Applying settings to all user hives..." -Status Processing
    
    try {
        $userHives = Get-ChildItem -Path "HKU:\" -ErrorAction SilentlyContinue | Where-Object {
            $_.PSChildName -notin @("S-1-5-18", "S-1-5-19", "S-1-5-20") -and
            $_.PSChildName -notlike "*_Classes"
        }
        
        $successCount = 0
        $totalCount = $userHives.Count
        
        foreach ($hive in $userHives) {
            try {
                $userPath = "HKU:\$($hive.PSChildName)\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
                
                # Ensure the path exists
                if (-not (Test-Path $userPath)) {
                    $null = New-Item -Path $userPath -Force -ErrorAction SilentlyContinue
                }
                
                # Set the registry value
                Set-ItemProperty -Path $userPath `
                                 -Name $Script:Configuration.RegistryValue `
                                 -Value $Value `
                                 -Type DWord `
                                 -Force `
                                 -ErrorAction Stop
                
                $successCount++
                Write-ModernStatus "Applied to user hive: $($hive.PSChildName)" -Status Info
            }
            catch {
                Write-ModernStatus "Failed for user hive: $($hive.PSChildName)" -Status Warning
            }
        }
        
        Write-ModernStatus "Registry settings applied to $successCount of $totalCount user hives" -Status Success
        return $true
    }
    catch {
        Write-ModernStatus "Failed to apply registry to all users: $($_.Exception.Message)" -Status Error
        return $false
    }
}

function Get-GroupPolicyConfiguration {
    <#
    .SYNOPSIS
        Retrieves current Group Policy configuration.
    #>
    
    $gpoConfig = @{
        UserPolicy = $null
        MachinePolicy = $null
        EffectivePolicy = $null
    }
    
    try {
        # Check User Policy
        $userPolicyPath = $Script:Configuration.GroupPolicyUserPath
        if (Test-Path $userPolicyPath) {
            $userValue = Get-ItemProperty -Path $userPolicyPath -Name $Script:Configuration.GroupPolicyValue -ErrorAction SilentlyContinue
            if ($userValue) {
                $gpoConfig.UserPolicy = $userValue.$($Script:Configuration.GroupPolicyValue)
            }
        }
        
        # Check Machine Policy
        $machinePolicyPath = $Script:Configuration.GroupPolicyMachinePath
        if (Test-Path $machinePolicyPath) {
            $machineValue = Get-ItemProperty -Path $machinePolicyPath -Name $Script:Configuration.GroupPolicyValue -ErrorAction SilentlyContinue
            if ($machineValue) {
                $gpoConfig.MachinePolicy = $machineValue.$($Script:Configuration.GroupPolicyValue)
            }
        }
        
        # Determine effective policy (machine policy takes precedence)
        if ($null -ne $gpoConfig.MachinePolicy) {
            $gpoConfig.EffectivePolicy = $gpoConfig.MachinePolicy
        } elseif ($null -ne $gpoConfig.UserPolicy) {
            $gpoConfig.EffectivePolicy = $gpoConfig.UserPolicy
        }
        
        return $gpoConfig
    }
    catch {
        Write-ModernStatus "Failed to read Group Policy configuration: $($_.Exception.Message)" -Status Error
        return $gpoConfig
    }
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
        
        # 2. Reset TrayNotify streams (icon cache) - Create path if doesn't exist
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
                # Ensure values are properly set
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
        if ($AllUsers) {
            if (Set-GroupPolicyConfiguration -Behavior 'Enable') {
                $methods.AutoTrayDisabled = $true
            }
        } else {
            if (Set-TrayIconConfiguration -Behavior 'Enable') {
                $methods.AutoTrayDisabled = $true
            }
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
        Write-EnhancedOutput "METHODS APPLIED:" -Type Primary
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
        AllUsers = $AllUsers
    }
    
    try {
        # 1. Backup main AutoTray setting
        $backupData.EnableAutoTray = Get-CurrentTrayConfiguration
        
        # 2. Backup Group Policy settings if AllUsers
        if ($AllUsers) {
            $gpoConfig = Get-GroupPolicyConfiguration
            $backupData.GroupPolicy = $gpoConfig
        }
        
        # 3. Backup NotifyIconSettings
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
        
        # 4. Backup TrayNotify
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
        
        # 5. Backup system icon settings
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
        
        # Determine backup path based on scope
        $backupPath = if ($AllUsers) { 
            $Script:Configuration.AllUsersBackupPath 
        } else { 
            $Script:Configuration.BackupRegistryPath 
        }
        
        # Convert to JSON with proper formatting
        $json = $backupData | ConvertTo-Json -Depth 10 -Compress
        
        # Save with UTF-8 encoding without BOM
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($backupPath, $json, $utf8NoBom)
        
        Write-ModernStatus "Comprehensive backup created: $backupPath" -Status Success
        
        # Display backup summary
        Write-ModernCard "Backup Location" $backupPath
        Write-ModernCard "Backup Scope" $(if ($AllUsers) { "All Users" } else { "Current User" })
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
    
    $backupPath = if ($AllUsers) { 
        $Script:Configuration.AllUsersBackupPath 
    } else { 
        $Script:Configuration.BackupRegistryPath 
    }
    
    if (-not (Test-Path $backupPath)) {
        Write-ModernStatus "No comprehensive backup found: $backupPath" -Status Error
        return $false
    }
    
    Write-ModernStatus "Restoring comprehensive tray settings..." -Status Processing
    
    try {
        $backupData = Get-Content -Path $backupPath -Raw | ConvertFrom-Json
        
        Write-ModernCard "Backup Created" $backupData.Timestamp
        Write-ModernCard "Windows Version" $backupData.WindowsVersion
        Write-ModernCard "Backup Scope" $(if ($backupData.AllUsers) { "All Users" } else { "Current User" })
        
        $restoreResults = @{}
        
        # 1. Restore main AutoTray setting
        if ($null -ne $backupData.EnableAutoTray) {
            if ($AllUsers -or $backupData.AllUsers) {
                # Restore Group Policy settings
                if ($backupData.GroupPolicy) {
                    $userPolicyPath = $Script:Configuration.GroupPolicyUserPath
                    $machinePolicyPath = $Script:Configuration.GroupPolicyMachinePath
                    
                    if (-not (Test-Path $userPolicyPath)) {
                        $null = New-Item -Path $userPolicyPath -Force
                    }
                    if (-not (Test-Path $machinePolicyPath)) {
                        $null = New-Item -Path $machinePolicyPath -Force
                    }
                    
                    Set-ItemProperty -Path $userPolicyPath -Name $Script:Configuration.GroupPolicyValue -Value $backupData.EnableAutoTray -Type DWord -Force
                    Set-ItemProperty -Path $machinePolicyPath -Name $Script:Configuration.GroupPolicyValue -Value $backupData.EnableAutoTray -Type DWord -Force
                    
                    $restoreResults.GroupPolicy = $true
                }
            } else {
                # Restore current user settings
                Set-ItemProperty -Path $Script:Configuration.RegistryPath `
                               -Name $Script:Configuration.RegistryValue `
                               -Value $backupData.EnableAutoTray `
                               -Type DWord `
                               -Force `
                               -ErrorAction Stop
                $restoreResults.EnableAutoTray = $true
            }
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
        Write-EnhancedOutput "RESTORATION RESULTS:" -Type Primary
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
        $backupPath = if ($AllUsers) { 
            $Script:Configuration.AllUsersBackupPath 
        } else { 
            $Script:Configuration.BackupRegistryPath 
        }
        
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
            AllUsers = $AllUsers
        }
        
        # Include Group Policy settings if AllUsers
        if ($AllUsers) {
            $backupData.GroupPolicy = Get-GroupPolicyConfiguration
        }
        
        $backupData | ConvertTo-Json | Out-File -FilePath $backupPath -Encoding UTF8
        Write-ModernStatus "Registry configuration backed up to: $backupPath" -Status Success
        
        # Display backup information
        Write-ModernCard "Backup Location" $backupPath
        Write-ModernCard "Backup Time" $backupData.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
        Write-ModernCard "Backup Scope" $(if ($AllUsers) { "All Users" } else { "Current User" })
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
    
    $backupPath = if ($AllUsers) { 
        $Script:Configuration.AllUsersBackupPath 
    } else { 
        $Script:Configuration.BackupRegistryPath 
    }
    
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
        Write-ModernCard "Backup Scope" $(if ($backupData.AllUsers) { "All Users" } else { "Current User" })
        
        if ($AllUsers -or $backupData.AllUsers) {
            # Rollback Group Policy settings
            if ($null -eq $originalValue) {
                # Remove Group Policy settings
                $userPolicyPath = $Script:Configuration.GroupPolicyUserPath
                $machinePolicyPath = $Script:Configuration.GroupPolicyMachinePath
                
                if (Test-Path $userPolicyPath) {
                    Remove-ItemProperty -Path $userPolicyPath -Name $Script:Configuration.GroupPolicyValue -Force -ErrorAction SilentlyContinue
                }
                if (Test-Path $machinePolicyPath) {
                    Remove-ItemProperty -Path $machinePolicyPath -Name $Script:Configuration.GroupPolicyValue -Force -ErrorAction SilentlyContinue
                }
                
                Write-ModernStatus "Restored Windows default behavior (Group Policy settings removed)" -Status Success
            }
            else {
                # Restore Group Policy settings
                $userPolicyPath = $Script:Configuration.GroupPolicyUserPath
                $machinePolicyPath = $Script:Configuration.GroupPolicyMachinePath
                
                if (-not (Test-Path $userPolicyPath)) {
                    $null = New-Item -Path $userPolicyPath -Force
                }
                if (-not (Test-Path $machinePolicyPath)) {
                    $null = New-Item -Path $machinePolicyPath -Force
                }
                
                Set-ItemProperty -Path $userPolicyPath -Name $Script:Configuration.GroupPolicyValue -Value $originalValue -Type DWord -Force
                Set-ItemProperty -Path $machinePolicyPath -Name $Script:Configuration.GroupPolicyValue -Value $originalValue -Type DWord -Force
                
                Write-ModernStatus "Restored Group Policy configuration: $originalValue" -Status Success
            }
        } else {
            # Rollback current user settings
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
        
        # Use Invoke-RestMethod for PowerShell 7+, WebClient for 5.0
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
    $gpoConfig = Get-GroupPolicyConfiguration
    
    # Configuration Status
    Write-EnhancedOutput "CONFIGURATION STATUS:" -Type Primary
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
    
    # Group Policy Status
    Write-EnhancedOutput "GROUP POLICY STATUS:" -Type Primary
    if ($null -ne $gpoConfig.EffectivePolicy) {
        $gpoBehavior = if ($gpoConfig.EffectivePolicy -eq $Script:Configuration.EnableValue) {
            "Show ALL tray icons (Group Policy enforced)"
        } else {
            "Auto-hide inactive icons (Group Policy enforced)"
        }
        $gpoColor = if ($gpoConfig.EffectivePolicy -eq $Script:Configuration.EnableValue) { "Success" } else { "Warning" }
        Write-ModernCard "Effective Policy" $gpoBehavior -ValueColor $gpoColor
        Write-ModernCard "User Policy" $(if ($null -ne $gpoConfig.UserPolicy) { $gpoConfig.UserPolicy } else { "Not Configured" })
        Write-ModernCard "Machine Policy" $(if ($null -ne $gpoConfig.MachinePolicy) { $gpoConfig.MachinePolicy } else { "Not Configured" })
    } else {
        Write-ModernCard "Group Policy" "Not configured - using local settings" -ValueColor Info
    }
    Write-Host ""
    
    # System Information
    Write-EnhancedOutput "SYSTEM INFORMATION:" -Type Primary
    if ($osInfo) {
        Write-ModernCard "Operating System" $osInfo.Caption
        Write-ModernCard "OS Version" "$($osInfo.Version) (Build $($osInfo.BuildNumber))"
    }
    Write-ModernCard "PowerShell Version" "$($PSVersionTable.PSVersion) ($(if($Script:IsPS7Plus){'Enhanced'}else{'Compatible'}))"
    Write-ModernCard "Windows Version" (Get-WindowsVersion)
    Write-Host ""
    
    # Session Context
    Write-EnhancedOutput "SESSION CONTEXT:" -Type Primary
    Write-ModernCard "Current User" $sessionContext.CurrentUser
    Write-ModernCard "Session Type" $sessionContext.SessionType
    Write-ModernCard "Admin Rights" $(if ($sessionContext.IsAdmin) { "Yes" } else { "No" }) -ValueColor $(if ($sessionContext.IsAdmin) { "Success" } else { "Info" })
    Write-ModernCard "Interactive" $(if ($sessionContext.IsInteractive) { "Yes" } else { "No" }) -ValueColor $(if ($sessionContext.IsInteractive) { "Success" } else { "Warning" })
    Write-Host ""
    
    # Backup Status
    Write-EnhancedOutput "BACKUP STATUS:" -Type Primary
    $currentUserBackup = Test-Path $Script:Configuration.BackupRegistryPath
    $allUsersBackup = Test-Path $Script:Configuration.AllUsersBackupPath
    Write-ModernCard "Current User Backup" $(if ($currentUserBackup) { "Available" } else { "Not Available" }) -ValueColor $(if ($currentUserBackup) { "Success" } else { "Info" })
    Write-ModernCard "All Users Backup" $(if ($allUsersBackup) { "Available" } else { "Not Available" }) -ValueColor $(if ($allUsersBackup) { "Success" } else { "Info" })
    
    if ($currentUserBackup -or $allUsersBackup) {
        try {
            if ($currentUserBackup) {
                $backupInfo = Get-Item $Script:Configuration.BackupRegistryPath
                Write-ModernCard "Current User Backup Size" "$([math]::Round($backupInfo.Length/1KB, 2)) KB" -ValueColor Info
            }
            if ($allUsersBackup) {
                $backupInfo = Get-Item $Script:Configuration.AllUsersBackupPath
                Write-ModernCard "All Users Backup Size" "$([math]::Round($backupInfo.Length/1KB, 2)) KB" -ValueColor Info
            }
        }
        catch {
            Write-ModernCard "Backup Status" "Error reading backup information" -ValueColor Warning
        }
    }
    
    Write-Host ""
    Write-EnhancedOutput "Use '-Action Enable' to show all icons or '-Action Disable' for default behavior." -Type Info
    Write-EnhancedOutput "Use '-AllUsers' for Group Policy deployment (requires administrator rights)." -Type Info
    Write-Host ""
}

# ============================================================================
# DIAGNOSTIC BACKUP FUNCTIONS
# ============================================================================

function Invoke-BackupDiagnostic {
    <#
    .SYNOPSIS
        Performs comprehensive backup file diagnostics and validation.
    #>
    
    $currentUserBackup = $Script:Configuration.BackupRegistryPath
    $allUsersBackup = $Script:Configuration.AllUsersBackupPath
    
    Write-Host "=== BACKUP FILE DIAGNOSTICS ===" -ForegroundColor Cyan
    
    # Check current user backup
    if (Test-Path $currentUserBackup) {
        Write-Host "`nCURRENT USER BACKUP:" -ForegroundColor Green
        try {
            $fileInfo = Get-Item $currentUserBackup
            Write-Host "File Size: $([math]::Round($fileInfo.Length/1KB, 2)) KB" -ForegroundColor Yellow
            
            $content = Get-Content -Path $currentUserBackup -Raw -ErrorAction Stop
            Write-Host "Content Length: $($content.Length) characters" -ForegroundColor Yellow
            
            try {
                $backupData = $content | ConvertFrom-Json -ErrorAction Stop
                Write-Host "✅ JSON parsing successful!" -ForegroundColor Green
                Write-Host "Backup Version: $($backupData.ScriptVersion)" -ForegroundColor Yellow
                Write-Host "Timestamp: $($backupData.Timestamp)" -ForegroundColor Yellow
                Write-Host "Scope: $(if ($backupData.AllUsers) { 'All Users' } else { 'Current User' })" -ForegroundColor Yellow
                Write-Host "Data Categories: $($backupData.PSObject.Properties.Name -join ', ')" -ForegroundColor Yellow
            }
            catch {
                Write-Host "❌ JSON parsing failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "❌ Error reading backup file: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "`nCURRENT USER BACKUP: Not Found" -ForegroundColor Red
    }
    
    # Check all users backup
    if (Test-Path $allUsersBackup) {
        Write-Host "`nALL USERS BACKUP:" -ForegroundColor Green
        try {
            $fileInfo = Get-Item $allUsersBackup
            Write-Host "File Size: $([math]::Round($fileInfo.Length/1KB, 2)) KB" -ForegroundColor Yellow
            
            $content = Get-Content -Path $allUsersBackup -Raw -ErrorAction Stop
            Write-Host "Content Length: $($content.Length) characters" -ForegroundColor Yellow
            
            try {
                $backupData = $content | ConvertFrom-Json -ErrorAction Stop
                Write-Host "✅ JSON parsing successful!" -ForegroundColor Green
                Write-Host "Backup Version: $($backupData.ScriptVersion)" -ForegroundColor Yellow
                Write-Host "Timestamp: $($backupData.Timestamp)" -ForegroundColor Yellow
                Write-Host "Scope: $(if ($backupData.AllUsers) { 'All Users' } else { 'Current User' })" -ForegroundColor Yellow
                Write-Host "Data Categories: $($backupData.PSObject.Properties.Name -join ', ')" -ForegroundColor Yellow
            }
            catch {
                Write-Host "❌ JSON parsing failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "❌ Error reading backup file: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "`nALL USERS BACKUP: Not Found" -ForegroundColor Red
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

    # Handle help types
    if ($QuickHelp) {
        Show-QuickHelp
        exit $Script:Configuration.ExitCodes.Success
    }
    
# Handle help parameter - works with or without value
if ($Help -or $QuickHelp) {
    # Determine help level with intelligent fallback
    $effectiveHelpLevel = if ($QuickHelp) {
        'Quick'
    } else {
        if ($PSBoundParameters.ContainsKey('HelpLevel')) {
            $HelpLevel
        } else {
            'Full'  # Show full help by default when -Help is specified without explicit -HelpLevel
        }
    }
    # Show banner only for full help (others have their own headers)
    if ($effectiveHelpLevel -eq 'Full') {
        Show-ModernBanner
    }
    # Display appropriate help based on level
    switch ($effectiveHelpLevel) {
        'Full'     { Show-ModernHelp }
        'Quick'    { Show-QuickHelp }
        'Admin'    { Show-AdministratorInstructions }
        'Security' { Show-SecurityContext }
    }
    exit $Script:Configuration.ExitCodes.Success
}
    
    # Validate PowerShell version
    if (-not (Test-PowerShellVersion)) {
        Write-ModernStatus "PowerShell version requirement not met" -Status Error
        exit $Script:Configuration.ExitCodes.PowerShellVersion
    }
    
    # Validate execution policy
    if (-not (Test-ExecutionPolicy)) {
        Write-ModernStatus "Execution policy blocks script execution" -Status Error
        exit $Script:Configuration.ExitCodes.GeneralError
    }

    # Check administrator rights ONLY if -AllUsers and -Action specified together
    if ($AllUsers -and -not (Test-AdministratorRights)) {
        Write-ModernStatus "Administrator rights required for -AllUsers parameter" -Status Error
        Write-Host ""
        Write-EnhancedOutput "To run with administrator rights, use one of these methods:" -Type Warning
        Write-Host "  1. Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
        Write-Host "  2. powershell -ExecutionPolicy Bypass -File Enable-AllTrayIcons.ps1 -Action Enable -AllUsers" -ForegroundColor Yellow
        Write-Host ""
        Write-EnhancedOutput "For current user only (no admin needed):" -Type Info
        Write-Host "  .\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer" -ForegroundColor Yellow
        Write-Host ""
        exit $Script:Configuration.ExitCodes.AdminRightsRequired
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
    
    # Show quick help if no specific action (REPLACED THE ORIGINAL BLOCK)
    if (-not $Action -and -not $Update) {
        if ($showBanner) {
            Show-ModernBanner
            $showBanner = $false
        }
        Show-QuickHelp
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
            if ($AllUsers) {
                Write-ModernHeader "Create Comprehensive Backup" "Saving ALL tray-related settings for ALL users"
            } else {
                Write-ModernHeader "Create Comprehensive Backup" "Saving ALL tray-related settings"
            }
            
            if (Backup-ComprehensiveTraySettings) {
                Write-ModernStatus "Comprehensive backup completed successfully!" -Status Success
            } else {
                $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.BackupFailed
                Write-ModernStatus "Backup operation failed" -Status Error
            }
        }
        
        'enable' {
            if ($AllUsers) {
                Write-ModernHeader "Enable ALL Tray Icons" "Group Policy method - applying to ALL users"
            } else {
                Write-ModernHeader "Enable ALL Tray Icons" "Comprehensive method - forcing all icons visible"
            }
            
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
            if ($AllUsers) {
                Write-ModernHeader "Restore Default Behavior" "Group Policy method - enabling auto-hide for ALL users"
            } else {
                Write-ModernHeader "Restore Default Behavior" "Enabling auto-hide for tray icons"
            }
            
            if ($AllUsers) {
                $success = Set-GroupPolicyConfiguration -Behavior 'Disable'
            } else {
                $success = Set-TrayIconConfiguration -Behavior 'Disable'
            }
            
            if ($success) {
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
            if ($AllUsers) {
                Write-ModernHeader "Configuration Rollback" "Reverting Group Policy settings for ALL users"
            } else {
                Write-ModernHeader "Configuration Rollback" "Reverting to previous settings"
            }
            
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
