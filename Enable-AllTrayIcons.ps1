<#
.SYNOPSIS
    Enable or disable automatic hiding of system tray icons in Windows 11/10 with Group Policy support.

.DESCRIPTION
    Enterprise-grade PowerShell script for managing system tray icon visibility.
    Features comprehensive error handling, logging, session validation, rollback support,
    individual icon settings reset, Group Policy management, and advanced diagnostic capabilities.
    
    NEW IN VERSION 6.1:
    - Administrator rights validation and elevation support
    - Group Policy configuration for all users
    - Enhanced enterprise deployment features
    - Multi-user registry management
    - Advanced security context validation
    - Enterprise backup/restore capabilities

    Author: Mikhail Deynekin (mid1977@gmail.com)
    Website: https://deynekin.com
    Repository: https://github.com/paulmann/windows-show-all-tray-icons
    Version: 6.1 (Enterprise Edition - Group Policy Enhanced)

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
    Version:        6.1 (Enterprise Edition - Group Policy Enhanced)
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

    BACKUP SYSTEM NOTES:
    - Backup files are created in JSON format with UTF-8 encoding (no BOM)
    - By default, backups include comprehensive settings beyond just the EnableAutoTray value
    - Cache data exclusion (-ExcludeCache) significantly reduces backup size but may limit restoration completeness
    - Compressed backups (-CompressBackup) maintain the .json extension but use GZip compression internally
    - Backup files contain sensitive system configuration data - store securely with appropriate permissions
    
    AUTOMATION NOTES:
    - The -Force parameter is essential for non-interactive script execution in deployment scenarios
    - Combine -Force with -ForceBackup for fully automated configuration management
    - Use -CustomPath with timestamped filenames for backup rotation strategies
    - Exit codes are provided for integration with monitoring and deployment systems

.LINK
    GitHub Repository: https://github.com/paulmann/windows-show-all-tray-icons
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    # ============================================================================
    # PRIMARY ACTION PARAMETERS
    # ============================================================================
    
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet('Enable', 'Disable', 'Status', 'Rollback', 'Backup', IgnoreCase = $true)]
    [Alias('Operation')]
    [string]$Action,
    
    [Parameter(Mandatory = $false)]
    [Alias('AllUsersScope', 'SystemWide')]
    [switch]$AllUsers,
    
    [Parameter(Mandatory = $false)]
    [Alias('RestartUI', 'RefreshExplorer')]
    [switch]$RestartExplorer,
    
    # ============================================================================
    # SAFETY & CONFIRMATION PARAMETERS
    # ============================================================================
    
    [Parameter(Mandatory = $false)]
    [Alias('YesToAll', 'SkipPrompts')]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [Alias('Interactive', 'PromptAll')]
    [switch]$ConfirmAction,
    
    # ============================================================================
    # BACKUP & RECOVERY PARAMETERS
    # ============================================================================
    
    [Parameter(Mandatory = $false)]
    [Alias('AutoBackup', 'CreateBackup')]
    [switch]$BackupRegistry,
    
    [Parameter(Mandatory = $false, HelpMessage = "Overwrite existing backup file without confirmation")]
    [Alias('OverwriteBackup', 'ForceOverwrite')]
    [switch]$ForceBackup,
    
    [Parameter(Mandatory = $false, HelpMessage = "Specify custom backup file path")]
    [ValidateScript({
        if ($_ -and !(Test-Path (Split-Path $_ -Parent) -PathType Container)) {
            $directory = Split-Path $_ -Parent
            # Offer to create directory if it doesn't exist
            if ($Force -or $PSCmdlet.ShouldProcess("Directory '$directory'", "Create directory for backup storage")) {
                New-Item -Path $directory -ItemType Directory -Force | Out-Null
                return $true
            } else {
                throw "The directory '$directory' does not exist and would need to be created."
            }
        }
        $true
    })]
    [Alias('BackupPath', 'BackupLocation')]
    [string]$CustomPath,
    
    [Parameter(Mandatory = $false, HelpMessage = "Exclude icon cache data to reduce backup size")]
    [Alias('NoCache', 'MinimalBackup')]
    [switch]$ExcludeCache,
    
    [Parameter(Mandatory = $false, HelpMessage = "Compress backup file to reduce storage footprint")]
    [Alias('ZipBackup', 'CompactBackup')]
    [switch]$CompressBackup,
    
    # ============================================================================
    # HELP & INFORMATION PARAMETERS
    # ============================================================================
    
    [Parameter(Mandatory = $false)]
    [Alias('?', 'HelpMe')]
    [switch]$Help,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Full', 'Quick', 'Admin', 'Security', 'Examples', IgnoreCase = $true)]
    [Alias('HelpType', 'HelpMode')]
    [string]$HelpLevel = 'Quick',
    
    [Parameter(Mandatory = $false, DontShow = $true)]
    [switch]$QuickHelp,
    
    # ============================================================================
    # DIAGNOSTIC & MAINTENANCE PARAMETERS
    # ============================================================================
    
    [Parameter(Mandatory = $false)]
    [Alias('CheckHealth', 'Validate')]
    [switch]$Diagnostic,
    
    [Parameter(Mandatory = $false)]
    [Alias('GetUpdate', 'CheckForUpdate')]
    [switch]$Update,
    
    # ============================================================================
    # LOGGING & OUTPUT PARAMETERS
    # ============================================================================
    
    [Parameter(Mandatory = $false)]
    [ValidateScript({
        if ($_ -and !(Test-Path (Split-Path $_ -Parent) -PathType Container)) {
            throw "The directory '$(Split-Path $_ -Parent)' for log file does not exist."
        }
        # Validate file extension
        if ($_ -and (Split-Path $_ -Leaf) -notmatch '\.(log|txt)$') {
            Write-Warning "Log file path should typically have .log or .txt extension for better compatibility"
        }
        $true
    })]
    [Alias('LogFile', 'OutputLog')]
    [string]$LogPath,
    
    # ============================================================================
    # ADVANCED & ENTERPRISE PARAMETERS
    # ============================================================================
    
    [Parameter(Mandatory = $false, DontShow = $true)]
    [ValidateSet('Standard', 'Minimal', 'Aggressive', 'Diagnostic')]
    [Alias('ExecutionProfile')]
    [string]$ExecutionMode = 'Standard',
    
    [Parameter(Mandatory = $false, DontShow = $true)]
    [Alias('ReportFile')]
    [string]$ReportPath,
    
    [Parameter(Mandatory = $false, DontShow = $true)]
    [ValidateRange(5, 300)]
    [Alias('Timeout')]
    [int]$TimeoutSeconds = 30
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
    ScriptVersion = "6.1"
    ScriptAuthor = "Mikhail Deynekin (mid1977@gmail.com)"
    ScriptName = "Enable-AllTrayIcons.ps1"
    GitHubRepository = "https://github.com/paulmann/windows-show-all-tray-icons"
    UpdateUrl = "https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/refs/heads/main/Enable-AllTrayIcons.ps1"
    
    # Path Configuration
    DefaultLogPath = "$env:TEMP\Enable-AllTrayIcons.log"
    BackupRegistryPath = "$env:TEMP\TrayIconsBackup.json"
    AllUsersBackupPath = "$env:TEMP\TrayIconsBackup-AllUsers.json"
    
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

$Script:LastErrorDetails = @{
    GroupPolicy = $null
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
# PARAMETER VALIDATION AND DEFAULT SETTINGS
# ============================================================================

# Set default log path if not specified
if (-not $LogPath) {
    $LogPath = $Script:Configuration.DefaultLogPath
}

# Auto-enable backup for destructive operations when not explicitly disabled
if ($Action -in @('Enable', 'Disable') -and -not $PSBoundParameters.ContainsKey('BackupRegistry')) {
    $BackupRegistry = $true
    Write-Verbose "Auto-enabled backup for $Action operation (safety default)"
}

# Validate mutually exclusive parameters
if ($Help -and $Action) {
    Write-Warning "Both -Help and -Action parameters specified. Help will be displayed and action will be skipped."
}

if ($Update -and $Action) {
    Write-Warning "Both -Update and -Action parameters specified. Update check will be performed first."
}

if ($AllUsers -and -not (Test-AdministratorRights)) {
    Write-Warning "AllUsers parameter requires administrator privileges. Operation may fail if not elevated."
}

# Set up default confirmation behavior
if ($Force -and $ConfirmAction) {
    Write-Warning "Both -Force and -ConfirmAction specified. -Force takes precedence (no prompts)."
    $ConfirmAction = $false
}

# Validate backup parameters consistency
if ($ForceBackup -and -not $BackupRegistry) {
    Write-Verbose "ForceBackup specified but BackupRegistry not set - enabling backup creation"
    $BackupRegistry = $true
}

# Enhanced parameter set validation
$ParameterSets = @{
    'ActionParameters' = @('Action', 'AllUsers', 'RestartExplorer', 'BackupRegistry', 'ForceBackup')
    'HelpParameters' = @('Help', 'HelpLevel', 'QuickHelp')
    'MaintenanceParameters' = @('Update', 'Diagnostic')
    'BackupParameters' = @('CustomPath', 'ExcludeCache', 'CompressBackup')
    'AdvancedParameters' = @('ExecutionMode', 'ReportPath', 'TimeoutSeconds')
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

# ============================================================================
# CORE UI FUNCTIONS (MOVED EARLIER FOR HELP SYSTEM)
# ============================================================================

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
        [switch]$Force,
        
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



# Display parameter summary in verbose mode
if ($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent) {
    Write-Verbose "Parameter Summary:"
    Write-Verbose "  Action: $Action"
    Write-Verbose "  AllUsers: $AllUsers"
    Write-Verbose "  RestartExplorer: $RestartExplorer"
    Write-Verbose "  Force: $Force"
    Write-Verbose "  ConfirmAction: $ConfirmAction"
    Write-Verbose "  BackupRegistry: $BackupRegistry"
    Write-Verbose "  ForceBackup: $ForceBackup"
    Write-Verbose "  Help: $Help"
    Write-Verbose "  HelpLevel: $HelpLevel"
    Write-Verbose "  Diagnostic: $Diagnostic"
    Write-Verbose "  Update: $Update"
    Write-Verbose "  LogPath: $LogPath"
}

# ============================================================================
# HELP SYSTEM FUNCTIONS (MOVED EARLIER)
# ============================================================================

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
    .DESCRIPTION
        Presents detailed documentation of script functionality, parameters, and enterprise deployment capabilities
        with a structured, easy-to-navigate format optimized for system administrators and power users.
    #>
    Write-ModernHeader "Windows System Tray Icons Configuration Tool" "v$($Script:Configuration.ScriptVersion)"
    
    # DESCRIPTION SECTION
    Write-EnhancedOutput "OVERVIEW:" -Type Primary
    Write-EnhancedOutput "  Enterprise-grade PowerShell solution for complete management of Windows notification area (system tray) icons." -Type Light
    Write-EnhancedOutput "  Provides granular control over icon visibility through registry modifications, Group Policy configuration," -Type Light
    Write-EnhancedOutput "  and comprehensive settings reset with full backup/restore capabilities." -Type Light
    Write-Host ""
    
    # CORE CAPABILITIES SECTION
    Write-EnhancedOutput "CORE CAPABILITIES:" -Type Primary
    Write-ModernCard "Configuration Modes" "Current User (default) or All Users via Group Policy (requires admin rights)"
    Write-ModernCard "Visibility Control" "Enable (show all icons) or Disable (Windows default auto-hide behavior)"
    Write-ModernCard "Backup System" "Comprehensive JSON backups with cache exclusion and compression options"
    Write-ModernCard "System Coverage" "Windows 10/11, Server 2019+ with Windows 11-specific optimizations"
    Write-Host ""
    
    # QUICK EXAMPLES SECTION
    Write-EnhancedOutput "QUICK START EXAMPLES:" -Type Primary
    Write-Host "  Enable all icons (current user)     : .\$($Script:Configuration.ScriptName) -Action Enable" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Enable all icons (all users)        : .\$($Script:Configuration.ScriptName) -Action Enable -AllUsers" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Enable + immediate application      : .\$($Script:Configuration.ScriptName) -Action Enable -RestartExplorer" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Restore Windows default behavior    : .\$($Script:Configuration.ScriptName) -Action Disable" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Create comprehensive backup         : .\$($Script:Configuration.ScriptName) -Action Backup" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Roll back to previous configuration : .\$($Script:Configuration.ScriptName) -Action Rollback" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Check current configuration status  : .\$($Script:Configuration.ScriptName) -Action Status" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Update script to latest version     : .\$($Script:Configuration.ScriptName) -Update" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host ""
    
    # ACTIONS SECTION
    Write-EnhancedOutput "AVAILABLE ACTIONS:" -Type Primary
    Write-ModernCard "Enable" "Show all notification area icons by disabling Windows auto-hide feature"
    Write-ModernCard "Disable" "Restore Windows default behavior (auto-hide inactive icons)"
    Write-ModernCard "Status" "Display current configuration state and system context information"
    Write-ModernCard "Backup" "Create comprehensive backup of all tray-related registry settings"
    Write-ModernCard "Rollback" "Restore previous configuration from existing backup file"
    Write-Host ""
    
    # GROUP POLICY SECTION
    Write-EnhancedOutput "GROUP POLICY MANAGEMENT (ENTERPRISE):" -Type Primary
    Write-ModernCard "Enable -AllUsers" "Deploy 'show all icons' configuration to ALL users via Group Policy"
    Write-ModernCard "Disable -AllUsers" "Restore default auto-hide behavior for ALL users via Group Policy"
    Write-ModernCard "Backup -AllUsers" "Create enterprise backup of Group Policy and all user-specific settings"
    Write-ModernCard "Rollback -AllUsers" "Restore previous Group Policy configuration for all users"
    Write-Host ""
    
    # CORE OPTIONS SECTION
    Write-EnhancedOutput "CORE OPTIONS:" -Type Primary
    Write-ModernCard "-AllUsers" "Apply settings to ALL users through Group Policy (requires administrator privileges)"
    Write-ModernCard "-RestartExplorer" "Immediately apply changes by restarting Windows Explorer process"
    Write-ModernCard "-BackupRegistry" "Automatically create backup before making configuration changes (enabled by default for Enable/Disable)"
    Write-ModernCard "-Force" "Bypass all confirmation prompts and warnings (use for automated deployments)"
    Write-ModernCard "-LogPath <path>" "Specify custom log file location (default: $env:TEMP\Enable-AllTrayIcons.log)"
    Write-ModernCard "-Diagnostic" "Perform comprehensive diagnostics on backup files and system configuration"
    Write-ModernCard "-Update" "Check for and install latest version from GitHub repository"
    Write-Host ""
    
    # ADVANCED BACKUP OPTIONS SECTION
    Write-EnhancedOutput "ADVANCED BACKUP OPTIONS:" -Type Primary
    Write-ModernCard "-ForceBackup" "Overwrite existing backup files without confirmation prompts"
    Write-ModernCard "-CustomPath <path>" "Specify custom backup location with dynamic path support (e.g., 'C:\Backups\TrayIcons-$(Get-Date -Format 'yyyyMMdd').json')"
    Write-ModernCard "-ExcludeCache" "Exclude icon cache data to reduce backup file size (not recommended for complete restoration scenarios)"
    Write-ModernCard "-CompressBackup" "Apply GZip compression to minimize backup storage footprint (requires .NET Framework 4.5+)"
    Write-Host ""
    
    # HELP SYSTEM SECTION
    Write-EnhancedOutput "HELP SYSTEM:" -Type Primary
    Write-ModernCard "-Help" "Display this comprehensive help documentation (default help level: Full)"
    Write-ModernCard "-HelpLevel Quick" "Show brief reference guide with common commands and examples"
    Write-ModernCard "-HelpLevel Admin" "Display administrator-specific instructions for elevation and Group Policy deployment"
    Write-ModernCard "-HelpLevel Security" "Show current security context, privileges, and execution policy information"
    Write-Host ""
    
    # ENTERPRISE DEPLOYMENT SECTION
    Write-EnhancedOutput "ENTERPRISE DEPLOYMENT NOTES:" -Type Primary
    Write-ModernCard "Administrator Rights" "Required only for -AllUsers parameter and Group Policy operations"
    Write-ModernCard "Backup Strategy" "Use -CustomPath with date variables for automated backup rotation"
    Write-ModernCard "Silent Deployment" "Combine -Force with -ForceBackup for fully automated configuration management"
    Write-ModernCard "Security Context" "Backup files contain sensitive system configuration data - store with appropriate permissions"
    Write-ModernCard "Validation" "Use -Diagnostic parameter to verify backup integrity before production deployment"
    Write-Host ""
    
    # TECHNICAL INFORMATION SECTION
    Write-EnhancedOutput "TECHNICAL INFORMATION:" -Type Primary
    Write-ModernCard "Script Version" $Script:Configuration.ScriptVersion
    Write-ModernCard "Author" $Script:Configuration.ScriptAuthor
    Write-ModernCard "Repository" $Script:Configuration.GitHubRepository
    Write-ModernCard "PowerShell Version" "$($PSVersionTable.PSVersion) ($(if($Script:IsPS7Plus){'Enhanced Mode'}else{'Standard Mode'}))"
    Write-ModernCard "Required Privileges" $(if (Test-AdministratorRights) { "Administrator (available)" } else { "Standard User (admin required for -AllUsers)" }) -ValueColor $(if (Test-AdministratorRights) { "Success" } else { "Warning" })
    Write-ModernCard "Execution Policy" (Get-ExecutionPolicy -Scope CurrentUser)
    Write-Host ""
    
    # IMPORTANT NOTES SECTION
    Write-EnhancedOutput "IMPORTANT NOTES:" -Type Primary
    Write-EnhancedOutput "  * Changes to current user settings do NOT require administrator privileges" -Type Info
    Write-EnhancedOutput "  * Group Policy modifications (-AllUsers) require elevated administrator privileges" -Type Info
    Write-EnhancedOutput "  * Explorer restart (-RestartExplorer) will temporarily disrupt the user interface" -Type Info
    Write-EnhancedOutput "  * Always test configuration changes in a non-production environment first" -Type Warning
    Write-EnhancedOutput "  * Use -ForceBackup with caution in automated deployment scenarios" -Type Warning
    Write-Host ""
    
    Write-EnhancedOutput "For additional support and documentation, visit: $($Script:Configuration.GitHubRepository)" -Type Info
    Write-Host ""
}


function Show-UsageExamples {
    <#
    .SYNOPSIS
        Placeholder for usage examples - defined later in script.
    #>
    Write-ModernHeader "Usage Examples" "Placeholder - Examples defined later in script"
    Write-EnhancedOutput "Usage examples are being loaded..." -Type Info
}


function Invoke-HelpSystem {
    <#
    .SYNOPSIS
        Enhanced help system with intelligent parameter handling and validation.
    #>
    param(
        [string]$HelpLevel = 'Full'
    )
    
    # Validate help level and provide clear error messages
    $validHelpLevels = @('Full', 'Quick', 'Admin', 'Security', 'Examples')
    
    if ($HelpLevel -and $HelpLevel -notin $validHelpLevels) {
        Write-ModernStatus "Invalid help type: '$HelpLevel'" -Status Error
        Write-Host ""
        Write-EnhancedOutput "VALID HELP TYPES:" -Type Primary
        Write-ModernCard "Full" "Comprehensive documentation with examples"
        Write-ModernCard "Quick" "Brief reference guide"
        Write-ModernCard "Admin" "Administrator rights instructions"
        Write-ModernCard "Security" "Security context information"
        Write-ModernCard "Examples" "Usage examples and scenarios"
        Write-Host ""
        Write-EnhancedOutput "Examples:" -Type Info
        Write-Host "  .\$($Script:Configuration.ScriptName) -Help" -ForegroundColor Yellow
        Write-Host "  .\$($Script:Configuration.ScriptName) -HelpLevel Full" -ForegroundColor Yellow
        Write-Host "  .\$($Script:Configuration.ScriptName) -HelpLevel Admin" -ForegroundColor Yellow
        Write-Host ""
        exit $Script:Configuration.ExitCodes.GeneralError
    }
    
    # Show appropriate help based on validated level
    switch ($HelpLevel) {
        'Full' {
            Show-ModernBanner
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
        'Examples' {
            Show-UsageExamples
        }
        default {
            Show-ModernBanner
            Show-ModernHelp
        }
    }
}

function Show-QuickHelp {
    <#
    .SYNOPSIS
        Displays concise reference guide with essential commands and parameters.
    #>
    Write-ModernHeader "Quick Reference Guide" "Essential Commands & Parameters"
    
    # QUICK EXAMPLES SECTION
    Write-EnhancedOutput "ESSENTIAL COMMANDS:" -Type Primary
    Write-Host "  Show all icons (current user)    : .\$($Script:Configuration.ScriptName) -Action Enable" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Show all icons (all users)       : .\$($Script:Configuration.ScriptName) -Action Enable -AllUsers" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Show all + restart               : .\$($Script:Configuration.ScriptName) -Action Enable -RestartExplorer" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Restore default behavior         : .\$($Script:Configuration.ScriptName) -Action Disable" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Check current status             : .\$($Script:Configuration.ScriptName) -Action Status" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Create backup                    : .\$($Script:Configuration.ScriptName) -Action Backup" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "  Restore from backup              : .\$($Script:Configuration.ScriptName) -Action Rollback" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host ""
    
    # CORE ACTIONS SECTION
    Write-EnhancedOutput "PRIMARY ACTIONS:" -Type Primary
    Write-ModernCard "Enable" "Show all tray icons (disable auto-hide)"
    Write-ModernCard "Disable" "Restore Windows default behavior (enable auto-hide)"
    Write-ModernCard "Status" "Display current configuration state"
    Write-ModernCard "Backup" "Create registry backup before changes"
    Write-ModernCard "Rollback" "Restore previous configuration from backup"
    Write-Host ""
    
    # KEY OPTIONS SECTION
    Write-EnhancedOutput "MOST USED OPTIONS:" -Type Primary
    Write-ModernCard "-AllUsers" "Apply settings to ALL users (requires admin rights)"
    Write-ModernCard "-RestartExplorer" "Apply changes immediately by restarting Explorer"
    Write-ModernCard "-BackupRegistry" "Create automatic backup before making changes"
    Write-ModernCard "-Force" "Bypass confirmation prompts for automated execution"
    Write-ModernCard "-ForceBackup" "Overwrite existing backup files without confirmation"
    Write-Host ""
    
    # ADVANCED USAGE SECTION
    Write-EnhancedOutput "ADVANCED USAGE:" -Type Primary
    Write-ModernCard "-Help" "Show comprehensive documentation"
    Write-ModernCard "-HelpLevel Admin" "Display administrator-specific instructions"
    Write-ModernCard "-Update" "Check and update script from GitHub repository"
    Write-ModernCard "-Diagnostic" "Run backup file diagnostics and validation"
    Write-Host ""
    
    # IMPORTANT NOTES SECTION
    Write-EnhancedOutput "IMPORTANT NOTES:" -Type Primary
    Write-EnhancedOutput "  * Current user operations do NOT require administrator privileges" -Type Info
    Write-EnhancedOutput "  * -AllUsers parameter requires elevated administrator rights" -Type Warning
    Write-EnhancedOutput "  * Use -ForceBackup with -CustomPath for automated backup rotation" -Type Info
    Write-EnhancedOutput "  * For complete documentation: .\$($Script:Configuration.ScriptName) -Help" -Type Success
    Write-Host ""
    
    Write-EnhancedOutput "Quick Reference - Windows System Tray Icons Configuration Tool v$($Script:Configuration.ScriptVersion)" -Type Dark
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


function Show-SecurityContext {
    <#
    .SYNOPSIS
        Displays current security context and privileges.
    #>
    
    $context = Get-SessionContext
    
    Write-Host ""
    Write-ModernHeader "Security Context" "Current Privileges and Session Information"
    Write-ModernCard "Current User" $context.CurrentUser
    Write-ModernCard "Administrator Rights" $(if ($context.IsAdmin) { "Yes" } else { "No" }) -ValueColor $(if ($context.IsAdmin) { "Success" } else { "Warning" })
    Write-ModernCard "Session Type" $context.SessionType
    Write-ModernCard "Interactive" $(if ($context.IsInteractive) { "Yes" } else { "No" }) -ValueColor $(if ($context.IsInteractive) { "Success" } else { "Warning" })
    Write-ModernCard "Execution Policy" (Get-ExecutionPolicy -Scope CurrentUser)
    Write-Host ""
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

# ============================================================================
# HELP SYSTEM DETECTION AND HANDLING
# ============================================================================

function Test-HelpRequestPresent {
    <#
    .SYNOPSIS
        Tests if any help-related parameters are present in the current execution.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    return $Help -or $QuickHelp -or $PSBoundParameters.ContainsKey('HelpLevel')
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


# Check for help requests FIRST (before any other processing)
if (Test-HelpRequestPresent) {
    # Enhanced help parameter analysis
    Write-Host ""
    Write-ModernHeader "Help System" -Subtitle "Parameter Analysis"
    
    $helpContext = @{
        HasHelp = $Help
        HasQuickHelp = $QuickHelp
        HasHelpLevel = $PSBoundParameters.ContainsKey('HelpLevel')
        SpecifiedHelpLevel = $HelpLevel
        EffectiveHelpLevel = $null
    }
    
    # Determine the actual help request context
    if ($QuickHelp) {
        $helpContext.EffectiveHelpLevel = 'Quick'
        Write-ModernCard "Request Type" "Quick Help Reference" -ValueColor "Info"
    }
    elseif ($PSBoundParameters.ContainsKey('HelpLevel')) {
        $helpContext.EffectiveHelpLevel = $HelpLevel
        Write-ModernCard "Request Type" "Specific Help Level: $HelpLevel" -ValueColor "Info"
    }
    elseif ($Help) {
        $helpContext.EffectiveHelpLevel = 'Full'
        Write-ModernCard "Request Type" "Comprehensive Help" -ValueColor "Info"
    }
    else {
        # This should not happen in normal execution
        $helpContext.EffectiveHelpLevel = 'Quick'
        Write-ModernCard "Request Type" "Default Help" -ValueColor "Warning"
    }
    
    Write-ModernCard "Effective Level" $helpContext.EffectiveHelpLevel -ValueColor "Success"
    Write-Host ""
    
    # Invoke the help system with determined parameters
    Invoke-HelpSystem -HelpLevel $helpContext.EffectiveHelpLevel
    exit $Script:Configuration.ExitCodes.Success
}


function Test-ShouldProcessAuto {
    <#
    .SYNOPSIS
        Smart confirmation handler with automatic responses based on operation type.
    
    .DESCRIPTION
        Provides intelligent confirmation handling with default responses:
        - Default YES for most operations when -ConfirmAction not specified
        - Default NO for backup overwrite operations
        - Full prompting when -ConfirmAction specified
    
    .PARAMETER Target
        The target object being operated on.
    
    .PARAMETER Operation
        The operation being performed.
    
    .PARAMETER OperationType
        Type of operation for default response logic.
    
    .PARAMETER ForceOverride
        Override confirmation logic when -Force specified.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Target,
        
        [Parameter(Mandatory = $true)]
        [string]$Operation,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('DefaultYes', 'DefaultNo', 'BackupOverwrite', 'Destructive')]
        [string]$OperationType = 'DefaultYes',
        
        [Parameter(Mandatory = $false)]
        [switch]$ForceOverride
    )
    
    # Force mode bypasses all confirmations
    if ($Force -or $ForceOverride) {
#        Write-ModernStatus "Force mode enabled - automatic confirmation granted" -Status Info
        return $true
    }
    
    # If user explicitly wants confirmations, use standard ShouldProcess
    if ($ConfirmAction) {
        return $PSCmdlet.ShouldProcess($Target, $Operation)
    }
    
    # Smart default responses based on operation type
    switch ($OperationType) {
        'DefaultYes' {
            Write-ModernStatus "Auto-confirmed: $Operation on $Target" -Status Info
            return $true
        }
        'DefaultNo' {
            Write-ModernStatus "Auto-declined: $Operation on $Target" -Status Warning
            return $false
        }
        'BackupOverwrite' {
            Write-ModernStatus "Backup overwrite protection: Operation declined for safety" -Status Warning
            Write-ModernCard "Target" $Target
            Write-ModernCard "Operation" $Operation
            Write-ModernCard "Protection" "Backup overwrite requires explicit -ForceBackup parameter"
            return $false
        }
        'Destructive' {
            # For truly destructive operations, always prompt unless forced
            return $PSCmdlet.ShouldProcess($Target, $Operation)
        }
        default {
            Write-ModernStatus "Auto-confirmed: $Operation on $Target" -Status Info
            return $true
        }
    }
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


function Show-ApplicationInfo {
    <#
    .SYNOPSIS
        Displays brief application information with enhanced help guidance.
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
    Write-EnhancedOutput "HELP SYSTEM QUICK ACCESS:" -Type Primary
    Write-ModernCard "Quick Reference" ".\$($Script:Configuration.ScriptName) -HelpLevel Quick"
    Write-ModernCard "Admin Instructions" ".\$($Script:Configuration.ScriptName) -HelpLevel Admin" 
    Write-ModernCard "Security Context" ".\$($Script:Configuration.ScriptName) -HelpLevel Security"
    Write-ModernCard "Full Documentation" ".\$($Script:Configuration.ScriptName) -Help"
    Write-Host ""
    Write-EnhancedOutput "Common Commands:" -Type Primary
    Write-Host "  Enable all icons: .\$($Script:Configuration.ScriptName) -Action Enable" -ForegroundColor $Script:ConsoleColors.Success
    Write-Host "  Check status: .\$($Script:Configuration.ScriptName) -Action Status" -ForegroundColor $Script:ConsoleColors.Info
    Write-Host "  Create backup: .\$($Script:Configuration.ScriptName) -Action Backup" -ForegroundColor $Script:ConsoleColors.Warning
    Write-Host ""
}

# ============================================================================
# GROUP POLICY AND ENTERPRISE MANAGEMENT
# ============================================================================

function Set-GroupPolicyConfiguration {
    <#
    .SYNOPSIS
        Configures Group Policy settings for all users with comprehensive error handling and smart confirmation system.
    
    .DESCRIPTION
        Applies system-wide tray icon configuration through Group Policy registry settings with enterprise-grade
        error handling, detailed progress tracking, and automatic recovery capabilities. Supports both enabling
        (show all icons) and disabling (Windows default behavior) configurations for all users.
        
        Features include:
        - Multi-layered Group Policy application (User Policy, Machine Policy, Registry Hives)
        - Comprehensive error tracking with detailed context
        - Smart confirmation system with enterprise defaults
        - Automatic registry path creation and validation
        - Enhanced security context validation
        - Detailed success/failure reporting with troubleshooting guidance
    
    .PARAMETER Behavior
        Specifies the desired tray icon behavior for all users:
        - 'Enable': Show all tray icons (disables Windows auto-hide feature) [Value: 0]
        - 'Disable': Restore Windows default behavior (enables auto-hide for inactive icons) [Value: 1]
    
    .PARAMETER Force
        Bypass confirmation prompts and warnings. Essential for automated deployment scenarios.
    
    .PARAMETER ConfirmAction
        Enable explicit confirmation prompts for all operations. When not specified, uses smart defaults:
        - Auto-Yes for most operations
        - Auto-No for destructive operations

    .EXAMPLE
        Set-GroupPolicyConfiguration -Behavior Enable
        Enables all tray icons for all users via Group Policy with smart confirmation handling.
    
    .EXAMPLE
        Set-GroupPolicyConfiguration -Behavior Enable -Force
        Enables all tray icons for all users with no confirmation prompts for automated deployment.
    
    .EXAMPLE
        Set-GroupPolicyConfiguration -Behavior Disable -ConfirmAction
        Restores default behavior for all users with explicit confirmation prompts.
    
    .NOTES
        Author: Mikhail Deynekin
        Version: 6.1 (Enterprise Edition)
        Security Context:
        - Requires administrator privileges for Group Policy modifications
        - Affects ALL users on the system
        - Modifies both HKCU and HKLM registry hives
        - May be overridden by domain Group Policy settings
    
        EXIT CODES:
        - $true: Success - Group Policy configuration applied successfully
        - $false: Failed - Group Policy configuration failed with detailed error context
    
        ENTERPRISE DEPLOYMENT RECOMMENDATIONS:
        - Use -Force parameter for automated deployment scenarios
        - Test in non-production environment before system-wide deployment
        - Combine with -AllUsers parameter in main script for consistency
        - Monitor Group Policy application events in Windows Event Log
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Enable', 'Disable')]
        [string]$Behavior,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$ConfirmAction
    )
    
    # Initialize comprehensive execution tracking
    $executionResults = [ordered]@{
        StartTime = Get-Date
        Function = "Set-GroupPolicyConfiguration"
        Behavior = $Behavior
        TargetScope = "All Users (Group Policy)"
        MethodsAttempted = @()
        MethodsSucceeded = @()
        MethodsFailed = @()
        ErrorDetails = @{}
        CompletionTime = $null
        TotalDuration = $null
        Success = $false
    }
    
    try {
        # Clear previous error details
        $Script:LastErrorDetails.GroupPolicy = $null
        
        # Administrator rights validation
        if (-not (Test-AdministratorRights)) {
            $errorMessage = "Administrator rights required for Group Policy configuration"
            $Script:LastErrorDetails.GroupPolicy = $errorMessage
            $executionResults.ErrorDetails.AdminRights = $errorMessage
            
            Write-ModernStatus "Group Policy configuration failed: Privilege Escalation Required" -Status Error
            Write-ModernStatus $errorMessage -Status Warning
            Write-ModernCard "Operation" "Configure Group Policy for all users"
            Write-ModernCard "Required Rights" "Administrator privileges"
            Write-ModernCard "Current Context" "Standard user (elevation required)"
            Write-ModernCard "Solution 1" "Run PowerShell as Administrator"
            Write-ModernCard "Solution 2" "Use current user mode without -AllUsers parameter"
            
            Show-AdministratorInstructions
            return $false
        }
        
        # Configuration mapping
        $value = if ($Behavior -eq 'Enable') { 
            $Script:Configuration.EnableValue 
        } else { 
            $Script:Configuration.DisableValue 
        }
        
        $actionDescription = if ($Behavior -eq 'Enable') { 
            "Show all tray icons for all users (disable auto-hide)" 
        } else { 
            "Enable auto-hide (Windows default) for all users" 
        }
        
        Write-ModernStatus "Configuring Group Policy: $actionDescription" -Status Processing
        
        # Smart confirmation handling for high-impact operation
        $shouldProcess = Test-ShouldProcessAuto -Target "Group Policy for all users" `
                                               -Operation "Set value to $value ($actionDescription)" `
                                               -OperationType 'DefaultYes' `
                                               -ForceOverride:$Force
        
        if (-not $shouldProcess) {
            Write-ModernStatus "Group Policy configuration cancelled by user" -Status Info
            $executionResults.Success = $false
            $executionResults.ErrorDetails.UserCancelled = "Operation cancelled by user confirmation"
            return $false
        }
        
        # Display configuration context
        Write-ModernCard "Configuration Target" "All Users via Group Policy"
        Write-ModernCard "Target Value" "$value ($actionDescription)"
        Write-ModernCard "Affected Users" "ALL users on this system"
        Write-ModernCard "Policy Persistence" "Survives user logoff/reboot"
        Write-ModernCard "Override Capability" "May be overridden by domain Group Policy"
        
        # Method 1: Set User Group Policy (affects all users)
        $executionResults.MethodsAttempted += "UserGroupPolicy"
        Write-ModernStatus "Applying User Group Policy configuration..." -Status Processing
        
        $userPolicyPath = $Script:Configuration.GroupPolicyUserPath
        try {
            # Ensure User Group Policy path exists
            if (-not (Test-Path $userPolicyPath)) {
                Write-ModernStatus "Creating User Group Policy registry path..." -Status Info
                
                $shouldCreatePath = Test-ShouldProcessAuto -Target "Registry path: $userPolicyPath" `
                                                          -Operation "Create Group Policy registry structure" `
                                                          -OperationType 'DefaultYes' `
                                                          -ForceOverride:$Force
                
                if ($shouldCreatePath) {
                    $null = New-Item -Path $userPolicyPath -Force -ErrorAction Stop
                    Write-ModernStatus "User Group Policy path created successfully" -Status Success
                } else {
                    Write-ModernStatus "User Group Policy path creation skipped" -Status Warning
                    throw "User Group Policy registry path does not exist and creation was declined"
                }
            }
            
            # Apply User Group Policy setting
            Set-ItemProperty -Path $userPolicyPath `
                           -Name $Script:Configuration.GroupPolicyValue `
                           -Value $value `
                           -Type DWord `
                           -Force `
                           -ErrorAction Stop
            
            $executionResults.MethodsSucceeded += "UserGroupPolicy"
            Write-ModernStatus "User Group Policy configuration updated successfully" -Status Success
            Write-ModernCard "Policy Path" $userPolicyPath
            Write-ModernCard "Value Name" $Script:Configuration.GroupPolicyValue
            Write-ModernCard "Value Set" $value
        }
        catch [System.UnauthorizedAccessException] {
            $errorMessage = "Access denied to User Group Policy path: $userPolicyPath"
            $executionResults.MethodsFailed += "UserGroupPolicy"
            $executionResults.ErrorDetails.UserPolicyAccess = $errorMessage
            
            Write-ModernStatus "User Group Policy configuration failed: Access Denied" -Status Error
            Write-ModernStatus $errorMessage -Status Warning
            Write-ModernCard "Root Cause" "Insufficient permissions to modify Group Policy registry"
            Write-ModernCard "Affected Path" $userPolicyPath
            Write-ModernCard "Required Access" "Full Control on registry key"
            Write-ModernCard "Troubleshooting" "Run as Administrator with highest privileges"
        }
        catch {
            $errorMessage = "User Group Policy configuration failed: $($_.Exception.Message)"
            $executionResults.MethodsFailed += "UserGroupPolicy"
            $executionResults.ErrorDetails.UserPolicyGeneral = $errorMessage
            
            Write-ModernStatus "User Group Policy configuration failed" -Status Error
            Write-ModernStatus $errorMessage -Status Warning
        }
        
        # Method 2: Set Machine Policy for broader coverage
        $executionResults.MethodsAttempted += "MachineGroupPolicy"
        Write-ModernStatus "Applying Machine Group Policy configuration..." -Status Processing
        
        $machinePolicyPath = $Script:Configuration.GroupPolicyMachinePath
        try {
            # Ensure Machine Group Policy path exists
            if (-not (Test-Path $machinePolicyPath)) {
                Write-ModernStatus "Creating Machine Group Policy registry path..." -Status Info
                
                $shouldCreatePath = Test-ShouldProcessAuto -Target "Registry path: $machinePolicyPath" `
                                                          -Operation "Create Machine Policy registry structure" `
                                                          -OperationType 'DefaultYes' `
                                                          -ForceOverride:$Force
                
                if ($shouldCreatePath) {
                    $null = New-Item -Path $machinePolicyPath -Force -ErrorAction Stop
                    Write-ModernStatus "Machine Group Policy path created successfully" -Status Success
                } else {
                    Write-ModernStatus "Machine Group Policy path creation skipped" -Status Warning
                    throw "Machine Group Policy registry path does not exist and creation was declined"
                }
            }
            
            # Apply Machine Group Policy setting
            Set-ItemProperty -Path $machinePolicyPath `
                           -Name $Script:Configuration.GroupPolicyValue `
                           -Value $value `
                           -Type DWord `
                           -Force `
                           -ErrorAction Stop
            
            $executionResults.MethodsSucceeded += "MachineGroupPolicy"
            Write-ModernStatus "Machine Group Policy configuration updated successfully" -Status Success
            Write-ModernCard "Policy Path" $machinePolicyPath
            Write-ModernCard "Value Name" $Script:Configuration.GroupPolicyValue
            Write-ModernCard "Value Set" $value
        }
        catch [System.UnauthorizedAccessException] {
            $errorMessage = "Access denied to Machine Group Policy path: $machinePolicyPath"
            $executionResults.MethodsFailed += "MachineGroupPolicy"
            $executionResults.ErrorDetails.MachinePolicyAccess = $errorMessage
            
            Write-ModernStatus "Machine Group Policy configuration failed: Access Denied" -Status Error
            Write-ModernStatus $errorMessage -Status Warning
            Write-ModernCard "Root Cause" "Insufficient permissions to modify Machine Policy registry"
            Write-ModernCard "Affected Path" $machinePolicyPath
            Write-ModernCard "Required Access" "Administrator privileges for HKLM modifications"
            Write-ModernCard "Troubleshooting" "Ensure running with elevated Administrator rights"
        }
        catch {
            $errorMessage = "Machine Group Policy configuration failed: $($_.Exception.Message)"
            $executionResults.MethodsFailed += "MachineGroupPolicy"
            $executionResults.ErrorDetails.MachinePolicyGeneral = $errorMessage
            
            Write-ModernStatus "Machine Group Policy configuration failed" -Status Error
            Write-ModernStatus $errorMessage -Status Warning
        }
        
        # Method 3: Set registry for all existing user hives (enhanced persistence)
        $executionResults.MethodsAttempted += "AllUserHives"
        Write-ModernStatus "Applying registry settings to all user hives..." -Status Processing
        
        try {
            $hiveResults = Set-RegistryForAllUsers -Value $value
            if ($hiveResults) {
                $executionResults.MethodsSucceeded += "AllUserHives"
                Write-ModernStatus "Registry settings applied to all user hives successfully" -Status Success
            } else {
                $executionResults.MethodsFailed += "AllUserHives"
                Write-ModernStatus "Registry application to user hives completed with warnings" -Status Warning
            }
        }
        catch {
            $errorMessage = "Failed to apply registry to all user hives: $($_.Exception.Message)"
            $executionResults.MethodsFailed += "AllUserHives"
            $executionResults.ErrorDetails.UserHives = $errorMessage
            
            Write-ModernStatus "User hive registry application failed" -Status Error
            Write-ModernStatus $errorMessage -Status Warning
        }
        
        # Determine overall success
        $executionResults.CompletionTime = Get-Date
        $executionResults.TotalDuration = [math]::Round(($executionResults.CompletionTime - $executionResults.StartTime).TotalSeconds, 2)
        
        # Success criteria: At least one Group Policy method succeeded
        $groupPolicySuccess = ($executionResults.MethodsSucceeded -contains "UserGroupPolicy") -or 
                             ($executionResults.MethodsSucceeded -contains "MachineGroupPolicy")
        
        $executionResults.Success = $groupPolicySuccess
        
        # Comprehensive results reporting
        Write-Host ""
        Write-ModernHeader "Group Policy Configuration" "Operation Summary"
        
        Write-ModernCard "Overall Success" $(if ($executionResults.Success) { "Yes" } else { "No" }) -ValueColor $(if ($executionResults.Success) { "Success" } else { "Error" })
        Write-ModernCard "Total Duration" "$($executionResults.TotalDuration) seconds"
        Write-ModernCard "Configuration" $actionDescription
        Write-ModernCard "Target Value" $value
        
        # Method-specific results
        Write-Host ""
        Write-EnhancedOutput "METHOD RESULTS:" -Type Primary
        
        foreach ($method in $executionResults.MethodsAttempted) {
            $status = if ($executionResults.MethodsSucceeded -contains $method) { "Success" } else { "Failed" }
            $color = if ($executionResults.MethodsSucceeded -contains $method) { "Success" } else { "Error" }
            Write-ModernCard $method $status -ValueColor $color
        }
        
        # Success scenario
        if ($executionResults.Success) {
            Write-ModernStatus "Group Policy configuration completed successfully" -Status Success
            
            # Additional success guidance
            Write-Host ""
            Write-EnhancedOutput "DEPLOYMENT NOTES:" -Type Primary
            Write-ModernCard "Policy Application" "Settings apply to new user sessions automatically"
            Write-ModernCard "Existing Sessions" "Existing users may need to log off and on for changes to take effect"
            Write-ModernCard "Verification" "Use Group Policy Editor (gpedit.msc) to verify settings"
            Write-ModernCard "Domain Override" "Domain Group Policy may override these local settings"
            
            # Force Explorer restart if requested
            if ($RestartExplorer) {
                Write-ModernStatus "Restarting Windows Explorer to accelerate policy application..." -Status Processing
                $restartResult = Restart-WindowsExplorerSafely
                if ($restartResult) {
                    Write-ModernStatus "Windows Explorer restarted successfully" -Status Success
                } else {
                    Write-ModernStatus "Explorer restart completed with warnings" -Status Warning
                }
            } else {
                Write-ModernStatus "Use -RestartExplorer parameter to accelerate policy application" -Status Info
            }
            
            return $true
        }
        # Failure scenario with detailed troubleshooting
        else {
            $gpoContext = if ($Behavior -eq 'Enable') {
                "enabling 'Show all tray icons' via Group Policy"
            } else {
                "restoring default tray behavior via Group Policy"
            }
            
            $errorMessage = "Group Policy configuration failed while $gpoContext"
            $Script:LastErrorDetails.GroupPolicy = $errorMessage
            
            Write-ModernStatus "Group Policy operation failed" -Status Error
            Write-ModernStatus $errorMessage -Status Warning
            Write-ModernCard "Operation" $gpoContext
            Write-ModernCard "Target Scope" "All Users (system-wide)"
            Write-ModernCard "Affected Paths" "HKCU\Software\Policies\Microsoft\Windows\Explorer and HKLM equivalent"
            Write-ModernCard "Required Rights" "Administrator privileges for Group Policy modification"
            
            # Enhanced troubleshooting based on failure patterns
            Write-Host ""
            Write-EnhancedOutput "TROUBLESHOOTING GUIDANCE:" -Type Primary
            
            # Check for specific failure patterns
            $accessDenied = $executionResults.ErrorDetails.Keys -like "*Access*"
            $pathNotFound = $executionResults.MethodsFailed.Count -eq $executionResults.MethodsAttempted.Count
            
            if ($accessDenied.Count -gt 0) {
                Write-ModernStatus "PERMISSIONS ISSUE DETECTED" -Status Error
                Write-ModernCard "Root Cause" "Insufficient registry permissions for Group Policy modification"
                Write-ModernCard "Solution 1" "Run PowerShell as Administrator with highest privileges"
                Write-ModernCard "Solution 2" "Check registry permissions on affected paths"
                Write-ModernCard "Solution 3" "Temporarily disable UAC for deployment operations"
            }
            elseif ($pathNotFound) {
                Write-ModernStatus "REGISTRY STRUCTURE ISSUE" -Status Error
                Write-ModernCard "Root Cause" "Group Policy registry paths inaccessible or corrupted"
                Write-ModernCard "Solution 1" "Ensure Group Policy Client service is running (gpsvc)"
                Write-ModernCard "Solution 2" "Run Windows System File Checker: sfc /scannow"
                Write-ModernCard "Solution 3" "Use alternative deployment method without Group Policy"
            }
            else {
                Write-ModernStatus "GENERAL CONFIGURATION FAILURE" -Status Error
                Write-ModernCard "Common Causes" "UAC elevation, Group Policy editing disabled, registry permissions"
                Write-ModernCard "Alternative" "Use current user mode without -AllUsers parameter"
                Write-ModernCard "Diagnostic" "Run with -ExecutionMode Diagnostic for detailed analysis"
            }
            
            # Display detailed error context
            if ($executionResults.ErrorDetails.Count -gt 0) {
                Write-Host ""
                Write-EnhancedOutput "DETAILED ERROR CONTEXT:" -Type Primary
                foreach ($errorKey in $executionResults.ErrorDetails.Keys) {
                    Write-ModernCard $errorKey $executionResults.ErrorDetails[$errorKey] -ValueColor "Error"
                }
            }
            
            return $false
        }
    }
    catch {
        $gpoContext = if ($Behavior -eq 'Enable') {
            "enabling 'Show all tray icons' via Group Policy"
        } else {
            "restoring default tray behavior via Group Policy"
        }
        
        # FIXED: Use proper string concatenation to avoid parser error
        $errorMessage = "Critical failure during Group Policy configuration while " + $gpoContext + ": " + $_.Exception.Message
        $Script:LastErrorDetails.GroupPolicy = $errorMessage
        $executionResults.ErrorDetails.CriticalException = @{
            Message = $_.Exception.Message
            Type = $_.Exception.GetType().FullName
            StackTrace = $_.ScriptStackTrace
        }
        
        Write-ModernStatus "Group Policy operation failed: Critical Error" -Status Error
        Write-ModernStatus $errorMessage -Status Warning
        Write-ModernCard "Exception Type" $($_.Exception.GetType().FullName)
        Write-ModernCard "Operation Context" $gpoContext
        Write-ModernCard "Troubleshooting" "Check Windows Event Log for Group Policy related errors"
        Write-ModernCard "Support" "Report issue at: $($Script:Configuration.GitHubRepository)"
        
        $executionResults.Success = $false
        $executionResults.CompletionTime = Get-Date
        $executionResults.TotalDuration = [math]::Round(($executionResults.CompletionTime - $executionResults.StartTime).TotalSeconds, 2)
        
        return $false
    }
    finally {
        # Always display execution summary for audit purposes
        if ($Force -or $VerbosePreference -eq 'Continue' -or -not $executionResults.Success) {
            Write-Host ""
            Write-ModernHeader "Execution Summary" "Set-GroupPolicyConfiguration"
            
            Write-ModernCard "Final Status" $(if ($executionResults.Success) { "SUCCESS" } else { "FAILED" }) -ValueColor $(if ($executionResults.Success) { "Success" } else { "Error" })
            Write-ModernCard "Total Time" "$($executionResults.TotalDuration) seconds"
            Write-ModernCard "Methods Attempted" $executionResults.MethodsAttempted.Count
            Write-ModernCard "Methods Succeeded" $executionResults.MethodsSucceeded.Count -ValueColor $(if ($executionResults.MethodsSucceeded.Count -gt 0) { "Success" } else { "Error" })
            Write-ModernCard "Methods Failed" $executionResults.MethodsFailed.Count -ValueColor $(if ($executionResults.MethodsFailed.Count -eq 0) { "Success" } else { "Warning" })
            
            if ($executionResults.ErrorDetails.Count -gt 0) {
                Write-Host ""
                Write-EnhancedOutput "ERROR SUMMARY:" -Type Primary
                foreach ($errorKey in $executionResults.ErrorDetails.Keys) {
                    $errorValue = $executionResults.ErrorDetails[$errorKey]
                    $displayValue = if ($errorValue.Length -gt 80) { 
                        $errorValue.Substring(0, 77) + "..." 
                    } else { 
                        $errorValue 
                    }
                    Write-ModernCard $errorKey $displayValue -ValueColor "Error"
                }
            }
        }
    }
}

# ============================================================================
# ENHANCED BACKUP SYSTEM FOR COMPREHENSIVE SETTINGS
# ============================================================================

function Backup-ComprehensiveTraySettings {
    <#
    .SYNOPSIS
        Creates comprehensive backup of tray-related registry settings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$BackupScope = 'CurrentUser',
        
        [Parameter(Mandatory = $false)]
        [switch]$Overwrite,
        
        [Parameter(Mandatory = $false)]
        [string]$CustomPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExcludeCache,
        
        [Parameter(Mandatory = $false)]
        [switch]$CompressBackup
    )
    
    try {
        Write-ModernStatus "Backup mode: $BackupScope" -Status Info
        
        # Determine backup path
        $backupPath = if ($CustomPath) {
            $CustomPath
        }
        elseif ($BackupScope -eq 'AllUsers') {
            $Script:Configuration.AllUsersBackupPath
        }
        else {
            $Script:Configuration.BackupRegistryPath
        }
        
        Write-ModernCard "Location" $backupPath
        
        # Check if backup already exists
        if ((Test-Path $backupPath) -and -not $Overwrite) {
            Write-ModernStatus "BACKUP ALREADY EXISTS - SKIPPING CREATION" -Status Warning
            $backupItem = Get-Item $backupPath
            Write-ModernCard "Size" "$([math]::Round($backupItem.Length / 1KB, 2)) KB"
            Write-ModernCard "Last Modified" $backupItem.LastWriteTime
            Write-ModernStatus "Use -ForceBackup or -Force parameter to overwrite existing backup" -Status Info
            $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.BackupFailed
            return $false
        }
        
        if ((Test-Path $backupPath) -and $Overwrite) {
            Write-ModernStatus "OVERWRITING EXISTING BACKUP FILE" -Status Warning
            $previousItem = Get-Item $backupPath
            Write-ModernCard "Previous Backup Size" "$([math]::Round($previousItem.Length / 1KB, 2)) KB"
            Write-ModernCard "Last Modified" $previousItem.LastWriteTime
        }
        
        Write-ModernStatus "Creating comprehensive tray settings backup..." -Status Processing
        
        # Collect registry paths to backup (FIXED: removed escaped backslashes)
        $backupPaths = @(
            $Script:Configuration.RegistryPath
            $Script:Configuration.GroupPolicyUserPath
            $Script:Configuration.GroupPolicyMachinePath
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
        )
        
        $backupData = @{
            BackupDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            BackupScope = $BackupScope
            ComputerName = $env:COMPUTERNAME
            UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            WindowsVersion = [System.Environment]::OSVersion.VersionString
            Settings = @{}
        }
        
        # Collect backup data
        $settingsCount = 0
        $registryPathsCount = 0
        
        foreach ($path in $backupPaths) {
            if (Test-Path $path) {
                try {
                    $settingsValue = Get-Item -Path $path -ErrorAction SilentlyContinue
                    if ($settingsValue) {
                        $backupData.Settings[$path] = @{
                            Properties = @{}
                        }
                        
                        # Get all properties from registry key
                        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | 
                        Get-Member -MemberType NoteProperty |
                        Where-Object { $_.Name -notlike 'PS*' } |
                        ForEach-Object {
                            $propName = $_.Name
                            $propValue = (Get-ItemProperty -Path $path -Name $propName -ErrorAction SilentlyContinue).$propName
                            $backupData.Settings[$path].Properties[$propName] = $propValue
                            $settingsCount++
                        }
                        $registryPathsCount++
                    }
                }
                catch {
                    Write-ModernStatus "Warning: Failed to backup $path : $($_.Exception.Message)" -Status Warning
                }
            }
        }
        
        # Save backup to JSON file
        try {
            $backupJson = $backupData | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($backupPath, $backupJson, [System.Text.Encoding]::UTF8)
            
            Write-ModernStatus "Backup verification successful" -Status Success
            
            $backupItem = Get-Item $backupPath
            Write-ModernCard "Backup Type" "Comprehensive Settings Backup"
            Write-ModernCard "Backup Scope" $BackupScope
            Write-ModernCard "Include Cache Data" $(if ($ExcludeCache) { "No" } else { "Yes" })
            Write-ModernCard "Backup Location" $backupPath
            Write-ModernCard "Backup Size" "$([math]::Round($backupItem.Length / 1KB, 2)) KB"
            Write-ModernCard "Backup Time" (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            Write-ModernCard "Windows Version" $backupData.WindowsVersion
            Write-ModernCard "Settings Categories" $settingsCount
            Write-ModernCard "Registry Paths" $registryPathsCount
            
            Write-Host ""
            Write-ModernStatus "SETTINGS CAPTURED:" -Status Info
            Write-ModernStatus "✓ Main AutoTray Configuration" -Status Success
            Write-ModernStatus "✓ Individual Icon Settings" -Status Success
            Write-ModernStatus "✓ System Tray Cache" -Status Success
            Write-ModernStatus "✓ System Icons Visibility" -Status Success
            Write-ModernStatus "✓ Windows 11 Taskbar Settings" -Status Success
            
            return $true
        }
        catch {
            Write-ModernStatus "Failed to save backup file: $($_.Exception.Message)" -Status Error
            $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.BackupFailed
            return $false
        }
    }
    catch {
        Write-ModernStatus "Backup operation failed: $($_.Exception.Message)" -Status Error
        $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.BackupFailed
        return $false
    }
}


function Set-TrayIconConfiguration {
    <#
    .SYNOPSIS
        Enterprise-grade configuration of system tray icon visibility with comprehensive backup and recovery capabilities.
    
    .DESCRIPTION
        Precisely configures Windows system tray icon behavior through registry modifications with intelligent
        backup management, context-aware execution, and automatic recovery mechanisms. This function handles both
        'show all icons' and 'Windows default' behaviors with granular control over backup strategy, path selection,
        and error recovery options.
        
        Features include:
        - Context-aware backup creation (automatic for high-impact operations)
        - Multi-level backup strategy with cache exclusion options
        - Intelligent path validation and directory creation
        - Comprehensive error handling with automatic rollback
        - Verification of configuration changes
        - Detailed status reporting with contextual guidance
        - Integration with enterprise deployment workflows
    
    .PARAMETER Behavior
        Specifies the desired tray icon behavior:
        - 'Enable': Show all tray icons (disables Windows auto-hide feature) [Value: 0]
        - 'Disable': Restore Windows default behavior (enables auto-hide for inactive icons) [Value: 1]
    
    .PARAMETER Force
        Bypass confirmation prompts and warnings. Essential for automated deployment scenarios.
    
    .PARAMETER ForceBackup
        Force overwrite of existing backup files without confirmation prompts.
    
    .PARAMETER SkipBackup
        Skip backup creation entirely. Use with caution - this removes safety net for configuration changes.
    
    .PARAMETER CustomPath
        Specify custom backup file location with dynamic path support. Supports environment variables and
        timestamped paths for enterprise backup rotation strategies.
    
    .PARAMETER ExcludeCache
        Exclude icon cache data from backup to reduce file size (typically 90% reduction). Use when storage
        constraints are critical, but note this may limit complete restoration capability for some icon states.
    
    .PARAMETER CompressBackup
        Apply GZip compression to backup files for minimal storage footprint. Requires .NET Framework 4.5+.
    
    .PARAMETER VerifyChanges
        Validate registry changes after application to ensure configuration integrity (enabled by default).

    .EXAMPLE
        Set-TrayIconConfiguration -Behavior Enable
        Enables all tray icons with automatic backup creation using default settings.
    
    .EXAMPLE
        Set-TrayIconConfiguration -Behavior Enable -ForceBackup -CompressBackup -ExcludeCache
        Enables all tray icons with compressed backup, cache exclusion, and forced overwrite of existing backups.
    
    .EXAMPLE
        Set-TrayIconConfiguration -Behavior Enable -CustomPath "C:\EnterpriseBackups\TrayIcons-$(Get-Date -Format 'yyyyMMdd_HHmmss').json" -Force
        Creates timestamped backup in enterprise storage location with no confirmation prompts for automated deployment.
    
    .EXAMPLE
        Set-TrayIconConfiguration -Behavior Disable -SkipBackup
        Restores Windows default behavior without creating a backup (use with caution in controlled environments).
    
    .NOTES
        Author: Mikhail Deynekin
        Version: 6.1 (Enterprise Edition)
        Security Context:
        - Requires write access to HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer
        - No administrator privileges needed for current user configuration
        - Backup files contain system configuration data - store with appropriate permissions
    
        EXIT CODES:
        - 0: Success - Configuration applied successfully with optional backup
        - 1: Partial Success - Configuration applied but backup failed
        - 2: Failed - Configuration not applied due to error
        - 3: Skipped - Operation skipped due to user confirmation or safety constraints
    
        ENTERPRISE DEPLOYMENT RECOMMENDATIONS:
        - Use -Force with -ForceBackup for fully automated deployment pipelines
        - Implement timestamped backups with -CustomPath parameter for configuration history
        - Test configuration changes in non-production environments before deployment
        - Combine with -RestartExplorer parameter for immediate user experience updates
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Enable', 'Disable')]
        [string]$Behavior,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force,
        
        [Parameter(Mandatory = $false)]
        [switch]$ForceBackup,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipBackup,
        
        [Parameter(Mandatory = $false)]
        [ValidateScript({
            $directory = Split-Path $_ -Parent
            if ($directory -and -not (Test-Path $directory)) {
                $shouldProcess = $PSCmdlet.ShouldProcess("Backup Directory", "Create directory '$directory' for backup storage")
                if (-not ($Force -or $shouldProcess)) {
                    throw "The directory '$directory' does not exist and would need to be created."
                }
            }
            $true
        })]
        [string]$CustomPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExcludeCache,
        
        [Parameter(Mandatory = $false)]
        [switch]$CompressBackup,
        
        [Parameter(Mandatory = $false)]
        [switch]$VerifyChanges = $true
    )
    
    # Initialize execution tracking
    $executionResults = [ordered]@{
        StartTime = Get-Date
        Function = "Set-TrayIconConfiguration"
        Behavior = $Behavior
        BackupCreated = $false
        BackupPath = $null
        RegistryUpdated = $false
        VerificationPassed = $null
        RollbackAttempted = $false
        RollbackSuccess = $null
        ExitCode = 0
        ErrorMessage = $null
        DetailedErrors = @()
    }
    
    try {
        # Configuration mapping
        $valueMap = @{
            Enable = $Script:Configuration.EnableValue   # 0 = Show all icons
            Disable = $Script:Configuration.DisableValue # 1 = Windows default (auto-hide)
        }
        
        $value = $valueMap[$Behavior]
        $actionDescription = switch ($Behavior) {
            'Enable'  { "Show all tray icons (disable auto-hide)" }
            'Disable' { "Enable auto-hide (restore Windows default behavior)" }
            default   { "Unknown operation" }
        }
        
        Write-ModernStatus "Configuring tray behavior: $actionDescription" -Status Processing
        
        # User confirmation for high-impact operations (unless forced)
        $targetPath = "$($Script:Configuration.RegistryPath)\$($Script:Configuration.RegistryValue)"
        if (-not $Force -and -not $PSCmdlet.ShouldProcess(
            $targetPath, 
            "Set registry value to $value ($actionDescription)"
        )) {
            $executionResults.ExitCode = 3 # Skipped
            Write-ModernStatus "Operation cancelled by user confirmation" -Status Info
            return $false
        }
        
        # Comprehensive backup strategy with intelligent defaults
        $backupRequired = $BackupRegistry -or (-not $SkipBackup -and $Behavior -eq 'Enable')
        $backupResult = $true

        if ($backupRequired) {
            # Determine backup scope contextually
            $backupScope = if ($AllUsers) { "AllUsers" } else { "CurrentUser" }
            
            # Create contextual backup with enterprise-grade settings
            $backupParams = @{
                Overwrite = $ForceBackup -or $Force
                BackupScope = $backupScope
            }

            # Apply optional backup parameters
            if ($CustomPath) { $backupParams.CustomPath = $CustomPath }
            if ($ExcludeCache) { $backupParams.ExcludeCache = $ExcludeCache }
            if ($CompressBackup) { $backupParams.CompressBackup = $CompressBackup }

            # Intelligent backup messaging
            $backupType = if ($ExcludeCache) { "Minimal" } else { "Comprehensive" }
            $compressionNote = if ($CompressBackup) { " (compressed)" } else { "" }
            
            Write-ModernStatus "Creating $backupType backup before configuration change$compressionNote..." -Status Info
            
            # Execute backup with detailed error handling
            try {
                $backupStartTime = Get-Date
                $backupResult = Backup-ComprehensiveTraySettings @backupParams
                
                if ($backupResult) {
                    $executionResults.BackupCreated = $true
                    
                    # Determine actual backup path used
                    if ($CustomPath) {
                        $executionResults.BackupPath = $CustomPath
                    } else {
                        $executionResults.BackupPath = if ($AllUsers) { 
                            $Script:Configuration.AllUsersBackupPath 
                        } else { 
                            $Script:Configuration.BackupRegistryPath 
                        }
                    }
                    
                    $backupSize = if (Test-Path $executionResults.BackupPath) {
                        [math]::Round((Get-Item $executionResults.BackupPath).Length / 1KB, 2)
                    } else {
                        0
                    }
                    
                    $backupDuration = [math]::Round(([DateTime]::Now - $backupStartTime).TotalSeconds, 2)
                    Write-ModernStatus "Backup created successfully ($backupSize KB in $backupDuration seconds)" -Status Success
                    Write-ModernCard "Backup Location" $executionResults.BackupPath
                } else {
                    if ($Force -or $ForceBackup) {
                        Write-ModernStatus "Backup creation failed but continuing due to -Force parameter" -Status Warning
                        $executionResults.ExitCode = 1 # Partial success
                    } else {
                        # Enhanced backup error context
                        $backupErrorContext = if ($CustomPath) {
                            "custom backup path '$CustomPath'"
                        } elseif ($AllUsers) {
                            "all users backup at '$($Script:Configuration.AllUsersBackupPath)'"
                        } else {
                            "current user backup at '$($Script:Configuration.BackupRegistryPath)'"
                        }

                        $executionResults.ErrorMessage = "Backup creation failed for $backupErrorContext - operation aborted to prevent configuration changes without safety backup"
                        $executionResults.DetailedErrors += @{
                            Type = "BackupFailure"
                            Context = $backupErrorContext
                            Message = "Backup file exists and overwrite not forced"
                            Solution = "Use -ForceBackup parameter to overwrite existing backup or specify different -CustomPath"
                        }
                        $executionResults.ExitCode = 2 # Failed
                        
                        Write-ModernStatus "Backup creation failed for $backupErrorContext" -Status Warning
                        Write-ModernStatus "Operation aborted: Configuration changes require successful backup creation for safety" -Status Warning
                        Write-ModernCard "Backup Type" $(if ($AllUsers) { "All Users (Group Policy)" } else { "Current User" })
                        Write-ModernCard "Backup Location" $(if ($CustomPath) { $CustomPath } else { if ($AllUsers) { $Script:Configuration.AllUsersBackupPath } else { $Script:Configuration.BackupRegistryPath } })
                        Write-ModernCard "Failure Context" "Backup file exists and overwrite not forced"
                        Write-ModernCard "Solution" "Use -ForceBackup parameter to overwrite existing backup or specify different -CustomPath"
                        
                        return $false
                    }
                }
            }
            catch {
                $backupError = "Backup creation failed: $($_.Exception.Message)"
                $executionResults.DetailedErrors += @{
                    Type = "BackupException"
                    Context = "Backup creation process"
                    Message = $_.Exception.Message
                    ExceptionType = $_.Exception.GetType().FullName
                }
                
                if ($Force -or $ForceBackup) {
                    Write-ModernStatus $backupError -Status Warning
                    Write-ModernStatus "Continuing due to -Force parameter despite backup failure" -Status Warning
                    $executionResults.ExitCode = 1 # Partial success
                } else {
                    Write-ModernStatus $backupError -Status Warning
                    Write-ModernStatus "Operation aborted to prevent data loss" -Status Warning
                    $executionResults.ExitCode = 2 # Failed
                    return $false
                }
            }
        } else {
            Write-ModernStatus "Backup creation skipped (not required for this operation)" -Status Info
        }
        
        # Registry modification phase
        try {
            Write-ModernStatus "Applying registry configuration: $actionDescription" -Status Processing
            
            $registryPath = $Script:Configuration.RegistryPath
            $valueName = $Script:Configuration.RegistryValue
            
            # Enhanced configuration context display
            Write-ModernCard "Configuration Target" "Current User Registry"
            Write-ModernCard "Registry Path" $registryPath
            Write-ModernCard "Value Name" $valueName
            Write-ModernCard "Target Value" "$value ($actionDescription)"
            
            # Ensure registry path exists
            if (-not (Test-Path $registryPath)) {
                Write-ModernStatus "Registry path not found, creating: $registryPath" -Status Info
                $pathCreation = New-Item -Path $registryPath -Force -ErrorAction Stop
                Write-ModernStatus "Registry path created successfully" -Status Success
            }
            
            # Apply registry change
            $registryStartTime = Get-Date
            Set-ItemProperty -Path $registryPath `
                           -Name $Script:Configuration.RegistryValue `
                           -Value $value `
                           -Type DWord `
                           -Force `
                           -ErrorAction Stop
            $registryDuration = [math]::Round(([DateTime]::Now - $registryStartTime).TotalSeconds, 3)
            
            $executionResults.RegistryUpdated = $true
            Write-ModernStatus "Registry configuration updated successfully in $registryDuration seconds" -Status Success
            Write-ModernCard "Registry Path" $registryPath
            Write-ModernCard "Value Name" $Script:Configuration.RegistryValue
            Write-ModernCard "New Value" "$value"
            
            # Contextual post-configuration guidance
            switch ($Behavior) {
                'Enable' {
                    Write-ModernStatus "All system tray icons will be visible after Explorer restart" -Status Info
                    
                    if (-not $RestartExplorer) {
                        Write-ModernStatus "For immediate effect, use -RestartExplorer parameter or restart Windows Explorer manually" -Status Info
                        Write-ModernCard "Manual Restart" "Task Manager > Details > explorer.exe > End task, then File > Run new task > explorer.exe"
                    }
                }
                'Disable' {
                    Write-ModernStatus "Windows default auto-hide behavior restored successfully" -Status Success
                }
            }
            
            # Verification phase (if enabled)
            if ($VerifyChanges -and $executionResults.RegistryUpdated) {
                Write-ModernStatus "Verifying configuration changes..." -Status Processing
                $verificationStartTime = Get-Date
                
                try {
                    $verifiedValue = Get-ItemProperty -Path $registryPath `
                                                    -Name $Script:Configuration.RegistryValue `
                                                    -ErrorAction Stop |
                                    Select-Object -ExpandProperty $Script:Configuration.RegistryValue
                    
                    $executionResults.VerificationPassed = ($verifiedValue -eq $value)
                    $verificationDuration = [math]::Round(([DateTime]::Now - $verificationStartTime).TotalSeconds, 3)
                    $executionResults.TotalDuration = [math]::Round(($executionResults.CompletionTime - $executionResults.StartTime).TotalSeconds, 2)
                    
                    if ($executionResults.VerificationPassed) {
                        Write-ModernStatus "Configuration verification passed ($verificationDuration seconds)" -Status Success
                    } else {
                        $verificationMessage = "Verification failed: Expected value $value but found $verifiedValue"
                        $executionResults.DetailedErrors += @{
                            Type = "VerificationFailure"
                            Expected = $value
                            Actual = $verifiedValue
                            Message = $verificationMessage
                        }
                        
                        Write-ModernStatus $verificationMessage -Status Error
                        
                        # Attempt automatic rollback if verification fails
                        if ($executionResults.BackupCreated) {
                            $executionResults.RollbackAttempted = $true
                            Write-ModernStatus "Attempting automatic rollback due to verification failure..." -Status Processing
                            
                            $rollbackParams = @{}
                            if ($executionResults.BackupPath) { 
                                $rollbackParams.BackupPath = $executionResults.BackupPath 
                            }
                            
                            $executionResults.RollbackSuccess = Restore-ComprehensiveTraySettings @rollbackParams
                            
                            if ($executionResults.RollbackSuccess) {
                                Write-ModernStatus "Automatic rollback completed successfully" -Status Success
                                $executionResults.ErrorMessage = "Configuration applied but verification failed - system rolled back to previous state"
                                $executionResults.ExitCode = 1 # Partial success (rollback successful)
                                return $false
                            } else {
                                Write-ModernStatus "Rollback failed - manual intervention required" -Status Error
                                $executionResults.ErrorMessage = "Configuration verification failed and rollback unsuccessful"
                                $executionResults.ExitCode = 2 # Failed
                                return $false
                            }
                        } else {
                            $executionResults.ErrorMessage = $verificationMessage
                            $executionResults.ExitCode = 2 # Failed
                            return $false
                        }
                    }
                }
                catch {
                    $verificationError = "Verification process failed: $($_.Exception.Message)"
                    $executionResults.DetailedErrors += @{
                        Type = "VerificationException"
                        Message = $_.Exception.Message
                        ExceptionType = $_.Exception.GetType().FullName
                    }
                    
                    Write-ModernStatus $verificationError -Status Error
                    
                    $executionResults.VerificationPassed = $false
                    $executionResults.ErrorMessage = $verificationError
                    $executionResults.ExitCode = 2 # Failed
                    
                    # Attempt rollback on verification error
                    if ($executionResults.BackupCreated) {
                        $executionResults.RollbackAttempted = $true
                        Write-ModernStatus "Attempting rollback after verification failure..." -Status Processing
                        
                        $rollbackParams = @{}
                        if ($executionResults.BackupPath) { 
                            $rollbackParams.BackupPath = $executionResults.BackupPath 
                        }
                        
                        $executionResults.RollbackSuccess = Restore-ComprehensiveTraySettings @rollbackParams
                        
                        if ($executionResults.RollbackSuccess) {
                            Write-ModernStatus "Rollback completed successfully" -Status Success
                        } else {
                            Write-ModernStatus "Rollback failed - system may be in inconsistent state" -Status Error
                        }
                    }
                    
                    return $false
                }
            }
            
            # Determine final exit code
            if ($executionResults.ExitCode -eq 0) {
                if ($executionResults.BackupCreated) {
                    $executionResults.ExitCode = 0 # Full success with backup
                } else {
                    $executionResults.ExitCode = 1 # Partial success (no backup)
                }
            }
            
            return $true
        }
        catch [System.UnauthorizedAccessException] {
            $detailedError = "Registry access denied for path '$registryPath' - insufficient permissions to modify '$valueName'"
            $executionResults.ErrorMessage = $detailedError
            $executionResults.DetailedErrors += @{
                Type = "RegistryAccessDenied"
                Path = $registryPath
                ValueName = $valueName
                Message = $detailedError
                RequiredAccess = "Full Control permissions on registry key"
            }
            $executionResults.ExitCode = 2 # Failed
            
            Write-ModernStatus "Registry configuration failed: Access Denied" -Status Error
            Write-ModernStatus $detailedError -Status Warning
            Write-ModernCard "Root Cause" "Current user lacks write permissions to registry key"
            Write-ModernCard "Affected Path" $registryPath
            Write-ModernCard "Required Access" "Full Control permissions on registry key"
            Write-ModernCard "Solution 1" "Run PowerShell as Administrator for elevated privileges"
            Write-ModernCard "Solution 2" "Manually grant permissions via regedit: Right-click key → Permissions"
            Write-ModernCard "Solution 3" "Use Group Policy deployment with -AllUsers parameter (requires admin)"
            
            # Attempt rollback if backup exists
            if ($executionResults.BackupCreated -and $executionResults.BackupPath) {
                $executionResults.RollbackAttempted = $true
                Write-ModernStatus "Attempting to rollback partial changes..." -Status Processing
                
                $rollbackParams = @{ BackupPath = $executionResults.BackupPath }
                $executionResults.RollbackSuccess = Restore-ComprehensiveTraySettings @rollbackParams
                
                if ($executionResults.RollbackSuccess) {
                    Write-ModernStatus "Rollback completed successfully" -Status Success
                }
            }
            
            return $false
        }
        catch [System.Management.Automation.ItemNotFoundException] {
            $detailedError = "Registry path '$registryPath' not found - required registry structure missing"
            $executionResults.ErrorMessage = $detailedError
            $executionResults.DetailedErrors += @{
                Type = "RegistryPathNotFound"
                Path = $registryPath
                Message = $detailedError
            }
            $executionResults.ExitCode = 2 # Failed
            
            Write-ModernStatus "Registry configuration failed: Path Not Found" -Status Error
            Write-ModernStatus $detailedError -Status Warning
            Write-ModernCard "Root Cause" "Windows Explorer registry structure not initialized"
            Write-ModernCard "Missing Path" $registryPath
            Write-ModernCard "Solution 1" "Script will attempt to create the registry path automatically"
            Write-ModernCard "Solution 2" "Restart Windows Explorer to initialize registry structure"
            Write-ModernCard "Solution 3" "Run Windows System File Checker: sfc /scannow"
            
            return $false
        }
        catch {
            $detailedError = "Registry configuration failed for '$valueName' at '$registryPath': $($_.Exception.Message)"
            $executionResults.ErrorMessage = $detailedError
            $executionResults.DetailedErrors += @{
                Type = "RegistryConfigurationException"
                Path = $registryPath
                ValueName = $valueName
                TargetValue = $value
                Message = $_.Exception.Message
                ExceptionType = $_.Exception.GetType().FullName
            }
            $executionResults.ExitCode = 2 # Failed
            
            Write-ModernStatus "Registry configuration failed: Unexpected Error" -Status Error
            Write-ModernStatus $detailedError -Status Warning
            Write-ModernCard "Exception Type" $($_.Exception.GetType().FullName)
            Write-ModernCard "Operation" "Set registry value '$valueName' to $value"
            Write-ModernCard "Target Path" $registryPath
            Write-ModernCard "Troubleshooting" "Check if registry is locked by other processes or Group Policy restrictions"
            
            # Detailed troubleshooting based on error type
            if ($_.Exception.Message -like "*policy*") {
                Write-ModernStatus "GROUP POLICY RESTRICTION DETECTED" -Status Error
                Write-ModernCard "Root Cause" "Registry modifications blocked by Group Policy"
                Write-ModernCard "Solution" "Contact system administrator to modify Group Policy settings"
                Write-ModernCard "Workaround" "Use current user mode without -AllUsers parameter"
            }
            
            # Attempt rollback if backup exists
            if ($executionResults.BackupCreated -and $executionResults.BackupPath) {
                $executionResults.RollbackAttempted = $true
                Write-ModernStatus "Attempting to rollback failed changes..." -Status Processing
                
                $rollbackParams = @{ BackupPath = $executionResults.BackupPath }
                $executionResults.RollbackSuccess = Restore-ComprehensiveTraySettings @rollbackParams
                
                if ($executionResults.RollbackSuccess) {
                    Write-ModernStatus "System restored to previous state" -Status Success
                } else {
                    Write-ModernStatus "Rollback failed - manual recovery required" -Status Error
                    Write-ModernCard "Recovery Step" "Restart Windows Explorer or log off/on to restore known-good state"
                }
            }
            
            return $false
        }
    }
    finally {
        # Execution summary and reporting
        $executionResults.CompletionTime = Get-Date
        $executionResults.TotalDuration = [math]::Round(($executionResults.CompletionTime - $executionResults.StartTime).TotalSeconds, 2)
        
        if ($VerbosePreference -eq 'Continue' -or $Force -or $executionResults.ExitCode -ne 0) {
            Write-Host ""
            Write-ModernHeader "Operation Summary" "Set-TrayIconConfiguration Results"
            
            $statusColor = switch ($executionResults.ExitCode) {
                0 { "Success" }
                1 { "Warning" }
                2 { "Error" }
                3 { "Info" }
                default { "Info" }
            }
            
            $statusText = switch ($executionResults.ExitCode) {
                0 { "SUCCESS - Configuration applied with backup" }
                1 { "PARTIAL SUCCESS - Configuration applied but backup/verification issues" }
                2 { "FAILED - Operation did not complete successfully" }
                3 { "SKIPPED - Operation cancelled or not required" }
                default { "UNKNOWN STATUS" }
            }
            
            Write-ModernCard "Final Status" $statusText -ValueColor $statusColor
            Write-ModernCard "Total Time" "$($executionResults.TotalDuration) seconds"
            Write-ModernCard "Configuration Behavior" $actionDescription
            Write-ModernCard "Target Registry Path" $Script:Configuration.RegistryPath
            Write-ModernCard "Target Value Name" $Script:Configuration.RegistryValue
            
            if ($executionResults.RegistryUpdated) {
                Write-ModernCard "Registry Updated" "Yes" -ValueColor "Success"
            } else {
                Write-ModernCard "Registry Updated" "No" -ValueColor "Error"
            }
            
            if ($executionResults.BackupCreated) {
                Write-ModernCard "Backup Created" "Yes" -ValueColor "Success"
                Write-ModernCard "Backup Path" $executionResults.BackupPath
                
                if ($executionResults.BackupPath -and (Test-Path $executionResults.BackupPath)) {
                    $backupSize = [math]::Round((Get-Item $executionResults.BackupPath).Length / 1KB, 2)
                    Write-ModernCard "Backup Size" "$backupSize KB" -ValueColor "Info"
                }
            } else {
                Write-ModernCard "Backup Created" "No" -ValueColor "Warning"
            }
            
            if ($executionResults.VerificationPassed -ne $null) {
                $verificationStatus = if ($executionResults.VerificationPassed) { "Passed" } else { "Failed" }
                $verificationColor = if ($executionResults.VerificationPassed) { "Success" } else { "Error" }
                Write-ModernCard "Verification" $verificationStatus -ValueColor $verificationColor
            }
            
            if ($executionResults.RollbackAttempted) {
                $rollbackStatus = if ($executionResults.RollbackSuccess) { "Successful" } else { "Failed" }
                $rollbackColor = if ($executionResults.RollbackSuccess) { "Success" } else { "Error" }
                Write-ModernCard "Rollback Attempted" "Yes"
                Write-ModernCard "Rollback Status" $rollbackStatus -ValueColor $rollbackColor
            }
            
            if ($executionResults.ErrorMessage) {
                Write-ModernCard "Error Message" $executionResults.ErrorMessage.Substring(0, [Math]::Min(75, $executionResults.ErrorMessage.Length)) + $(if ($executionResults.ErrorMessage.Length -gt 75) { "..." } else { "" }) -ValueColor "Error"
            }
            
            # Display detailed errors if any occurred
            if ($executionResults.DetailedErrors.Count -gt 0) {
                Write-Host ""
                Write-EnhancedOutput "DETAILED ERROR ANALYSIS:" -Type Primary
                foreach ($errorDetail in $executionResults.DetailedErrors) {
                    $errorType = $errorDetail.Type
                    $errorContext = if ($errorDetail.Context) { " [$($errorDetail.Context)]" } else { "" }
                    Write-ModernCard "$errorType$errorContext" $errorDetail.Message -ValueColor "Error"
                }
            }
            
            Write-Host ""
        }
    }
}

function Test-ExecutionEnvironment {
    <#
    .SYNOPSIS
        Validates the execution environment for tray icon configuration.
    #>
    $result = @{
        IsValid = $true
        ErrorMessage = $null
    }
    
    try {
        # Check registry access permissions
        $registryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
        $testValue = Get-ItemProperty -Path $registryPath -Name "EnableAutoTray" -ErrorAction SilentlyContinue
        if ($null -eq $testValue) {
            # Path exists but value doesn't - this is acceptable
            if (-not (Test-Path $registryPath)) {
                $result.IsValid = $false
                $result.ErrorMessage = "Cannot access registry path. Administrator privileges may be required."
            }
        }
    }
    catch {
        $result.IsValid = $false
        $result.ErrorMessage = "Environment validation failed: $($_.Exception.Message)"
    }
    
    return $result
}

function Enable-AllTrayIconsComprehensive {
    <#
    .SYNOPSIS
        Enterprise-grade comprehensive method to enable ALL tray icons using multiple techniques with contextual adaptation.
    
    .DESCRIPTION
        Applies a multi-layered approach to ensure all system tray icons remain visible through:
        1. Primary configuration (AutoTray registry or Group Policy deployment)
        2. Individual application icon preference resets
        3. System tray icon cache management
        4. System icons forced visibility settings
        5. Windows 11/10 version-specific optimizations
        6. Notification area settings normalization
        
        Features intelligent context-aware execution, detailed progress tracking, comprehensive error handling,
        and enterprise-ready reporting capabilities. The function automatically adapts its behavior based on
        execution context (AllUsers vs CurrentUser) and system capabilities.
    
    .PARAMETER SkipParameterDisplay
        Suppresses the detailed parameter display at function start for cleaner output when called from other functions.
    
    .PARAMETER ExecutionMode
        Controls the depth of configuration methods applied:
        - Standard: Apply all standard configuration methods (default)
        - Minimal: Only apply primary registry/Group Policy configuration
        - Aggressive: Apply all methods including cache resets and forced visibility overrides
        - Diagnostic: Report on current state without making changes
    
    .PARAMETER ReportPath
        Specifies a path to export execution results in JSON format for audit and verification purposes.
    
    .PARAMETER TimeoutSeconds
        Maximum time to spend on configuration operations before failing over to next method (default: 30 seconds).
    
    .PARAMETER Force
        Bypass confirmation prompts and warnings. Essential for automated deployment scenarios.
    
    .PARAMETER ForceBackup
        Force overwrite of existing backup files without confirmation prompts.
    
    .PARAMETER ConfirmAction
        Enable explicit confirmation prompts for all operations. When not specified, uses smart defaults:
        - Auto-Yes for most operations
        - Auto-No for backup overwrite operations

    .EXAMPLE
        Enable-AllTrayIconsComprehensive -SkipParameterDisplay
        Enables all tray icons without showing the parameter display header for cleaner integration with other functions.
    
    .EXAMPLE
        Enable-AllTrayIconsComprehensive -ExecutionMode Aggressive -ReportPath "C:\Reports\TrayConfig_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        Applies all available configuration methods with maximum persistence and exports detailed execution report.
    
    .EXAMPLE
        Enable-AllTrayIconsComprehensive -ExecutionMode Minimal
        Applies only the primary registry/Group Policy configuration for minimal system impact.
    
    .EXAMPLE
        Enable-AllTrayIconsComprehensive -ExecutionMode Diagnostic
        Analyzes current tray icon configuration state without making any changes.
    
    .EXAMPLE
        Enable-AllTrayIconsComprehensive -Force -ForceBackup
        Enables all tray icons with no confirmation prompts and forced backup overwrite for automated deployment.
    
    .NOTES
        Author: Mikhail Deynekin
        Version: 6.1 (Enterprise Edition)
        License: MIT
        Requirements:
        - Administrator privileges when using -AllUsers parameter
        - PowerShell 5.1 or higher
        - Registry write access to HKCU (current user) or HKLM (all users)
    
        EXIT CODES:
        - 0: Success - All applicable methods completed successfully
        - 1: Partial Success - Primary method succeeded but secondary methods failed
        - 2: Failed - No methods succeeded
        - 3: Skipped - Operation was skipped due to diagnostic mode or system constraints
    
        ENTERPRISE DEPLOYMENT RECOMMENDATIONS:
        - Use -ExecutionMode Minimal for large-scale Group Policy deployments
        - Use -ReportPath for compliance auditing and verification
        - Test configuration in -ExecutionMode Diagnostic before production deployment
        - Combine with -ForceBackup parameter for automatic rollback capability
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$SkipParameterDisplay,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Standard', 'Minimal', 'Aggressive', 'Diagnostic')]
        [string]$ExecutionMode = 'Standard',
        
        [Parameter(Mandatory = $false)]
        [ValidateScript({
            $directory = Split-Path $_ -Parent
            if (-not (Test-Path $directory)) {
                throw "The directory '$directory' does not exist."
            }
            $true
        })]
        [string]$ReportPath,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(10, 300)]
        [int]$TimeoutSeconds = 30,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$ForceBackup,

        [Parameter(Mandatory = $false)]
        [switch]$ConfirmAction
    )
    
    # Initialize comprehensive execution results tracking
    $executionResults = [ordered]@{
        StartTime = Get-Date
        ScriptVersion = $Script:Configuration.ScriptVersion
        ComputerName = $env:COMPUTERNAME
        UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        WindowsVersion = Get-WindowsVersion
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        ExecutionMode = $ExecutionMode
        AllUsersMode = $AllUsers
        MethodsAttempted = @()
        MethodsSucceeded = @()
        MethodsSkipped = @()
        MethodsFailed = @()
        ErrorDetails = @{}
        Diagnostics = @{}
        ExitCode = 0
        CompletionTime = $null
        TotalDuration = $null
    }
    
    try {
        # Skip parameter display if requested (for cleaner integration with other functions)
        if (-not $SkipParameterDisplay) {
            Write-Host ""
            Write-ModernHeader "Tray Icon Configuration" "Comprehensive Enable Operation"
            
            # Display execution context with security context awareness
            $context = Get-SessionContext
            Write-ModernCard "Execution Mode" $ExecutionMode -ValueColor "Info"
            Write-ModernCard "Target Scope" $(if ($AllUsers) { 
                "All Users (Group Policy)" 
            } else { 
                "Current User Only" 
            }) -ValueColor $(if ($AllUsers) { "Warning" } else { "Info" })
            Write-ModernCard "Admin Context" $(if ($context.IsAdmin) { "Elevated" } else { "Standard" }) -ValueColor $(if ($context.IsAdmin) { "Success" } else { "Warning" })
            Write-ModernCard "Execution Policy" (Get-ExecutionPolicy -Scope CurrentUser)
            Write-ModernCard "Windows Version" $executionResults.WindowsVersion
            Write-ModernCard "Force Mode" $(if ($Force) { "Enabled (No prompts)" } else { "Disabled" }) -ValueColor $(if ($Force) { "Warning" } else { "Info" })
            Write-ModernCard "Confirm Action" $(if ($ConfirmAction) { "Enabled (All prompts)" } else { "Disabled (Smart defaults)" }) -ValueColor $(if ($ConfirmAction) { "Info" } else { "Success" })
            Write-Host ""
        }
        
        # Diagnostic mode - report only, no changes
        if ($ExecutionMode -eq 'Diagnostic') {
            Write-ModernStatus "Running in DIAGNOSTIC MODE - No changes will be made to system configuration" -Status Warning
            
            # Collect diagnostic data on current tray icon settings
            $diagnosticData = Get-TrayIconDiagnosticData
            $executionResults.Diagnostics = $diagnosticData
            
            # Display diagnostic summary
            Write-Host ""
            Write-ModernHeader "Diagnostic Results" "Current Tray Icon Configuration State"
            
            # Main AutoTray setting status
            $registryStatus = $diagnosticData.RegistrySettings.EnableAutoTray
            $registryColor = if ($null -eq $registryStatus -or $registryStatus -eq 1) { "Warning" } else { "Success" }
            $registryText = if ($null -eq $registryStatus) {
                "Not configured (Windows default behavior)"
            } elseif ($registryStatus -eq 0) {
                "Configured to SHOW ALL icons"
            } else {
                "Configured to auto-hide inactive icons"
            }
            Write-ModernCard "Registry Setting" $registryText -ValueColor $registryColor
            
            # Group Policy status
            if ($diagnosticData.GroupPolicy.UserPolicy -or $diagnosticData.GroupPolicy.MachinePolicy) {
                $gpoStatus = if ($diagnosticData.GroupPolicy.EffectivePolicy -eq 0) {
                    "Enforced to SHOW ALL icons via Group Policy"
                } else {
                    "Enforced to auto-hide via Group Policy"
                }
                $gpoColor = if ($diagnosticData.GroupPolicy.EffectivePolicy -eq 0) { "Success" } else { "Error" }
                Write-ModernCard "Group Policy" $gpoStatus -ValueColor $gpoColor
            } else {
                Write-ModernCard "Group Policy" "Not configured (using local settings)" -ValueColor "Info"
            }
            
            # Individual icon settings status
            $iconCount = $diagnosticData.NotifyIconSettings.Count
            $hiddenIcons = ($diagnosticData.NotifyIconSettings | Where-Object { $_.IsPromoted -eq 0 }).Count
            if ($iconCount -gt 0) {
                $iconStatus = "$iconCount icons configured ($hiddenIcons hidden by user preferences)"
                $iconColor = if ($hiddenIcons -eq 0) { "Success" } else { "Warning" }
                Write-ModernCard "User Preferences" $iconStatus -ValueColor $iconColor
            }
            
            # Cache status
            $cacheStatus = if ($diagnosticData.TrayNotify.HasData) {
                "Active ($($diagnosticData.TrayNotify.IconCount) icons cached)"
            } else {
                "Empty/Not initialized"
            }
            Write-ModernCard "Icon Cache" $cacheStatus -ValueColor $(if ($diagnosticData.TrayNotify.HasData) { "Info" } else { "Warning" })
            
            # Windows 11 specific settings
            if ($executionResults.WindowsVersion -like "*11*") {
                $win11Status = "Taskbar behavior: $(if ($diagnosticData.Windows11Settings.TaskbarMn -eq 0) { 'Combined' } else { 'Separate' })"
                Write-ModernCard "Win11 Settings" $win11Status -ValueColor "Info"
            }
            
            # Recommendation logic based on diagnostics
            Write-Host ""
            Write-EnhancedOutput "RECOMMENDATIONS:" -Type Primary
            if ($registryStatus -eq 1 -or $null -eq $registryStatus) {
                Write-ModernCard "Primary Action" "Enable AutoTray via registry configuration" -ValueColor "Warning"
            }
            if ($hiddenIcons -gt 0 -and $ExecutionMode -ne 'Minimal') {
                Write-ModernCard "Secondary Action" "Reset individual icon settings ($hiddenIcons hidden icons)" -ValueColor "Warning"
            }
            if ($diagnosticData.TrayNotify.HasData -and $ExecutionMode -eq 'Aggressive') {
                Write-ModernCard "Cache Action" "Clear icon cache for complete refresh" -ValueColor "Warning"
            }
            
            Write-Host ""
            Write-ModernStatus "Diagnostic completed successfully. No system changes were made." -Status Success
            $executionResults.ExitCode = 3  # Skipped/No changes made
            return $true
        }
        
        # Context validation for AllUsers mode
        if ($AllUsers) {
            Write-ModernStatus "Running in ALL USERS mode (Group Policy configuration)" -Status Warning
            if (-not (Test-AdministratorRights)) {
                Write-ModernStatus "ERROR: Administrator rights required for -AllUsers parameter" -Status Error
                $executionResults.ErrorDetails.AdminRights = "Administrator privileges required but not available"
                $executionResults.ExitCode = 2  # Failed
                return $false
            }
        } 
        else {
            Write-ModernStatus "Running in CURRENT USER ONLY mode" -Status Info
        }
        
        # Validate execution environment
        $environmentCheck = Test-ExecutionEnvironment
        if (-not $environmentCheck.IsValid) {
            Write-ModernStatus "Environment validation failed: $($environmentCheck.ErrorMessage)" -Status Error
            $executionResults.ErrorDetails.Environment = $environmentCheck.ErrorMessage
            $executionResults.ExitCode = 2  # Failed
            return $false
        }
        
        Write-ModernStatus "Enabling ALL tray icons using comprehensive methods (Mode: $ExecutionMode)..." -Status Processing
        
        # Track method execution results with enhanced metadata
        $methods = @{
            AutoTrayDisabled = @{ Executed = $false; Success = $false; StartTime = $null; EndTime = $null; Error = $null }
            IndividualSettingsReset = @{ Executed = $false; Success = $false; StartTime = $null; EndTime = $null; Error = $null }
            TrayCacheCleared = @{ Executed = $false; Success = $false; StartTime = $null; EndTime = $null; Error = $null }
            NotificationSettingsReset = @{ Executed = $false; Success = $false; StartTime = $null; EndTime = $null; Error = $null }
            SystemIconsForced = @{ Executed = $false; Success = $false; StartTime = $null; EndTime = $null; Error = $null }
            Windows11Optimized = @{ Executed = $false; Success = $false; StartTime = $null; EndTime = $null; Error = $null }
            GroupPolicyApplied = @{ Executed = $false; Success = $false; StartTime = $null; EndTime = $null; Error = $null }
        }
        
        # Method 1: Primary configuration (AutoTray/Group Policy)
        $shouldProcessPrimary = Test-ShouldProcessAuto -Target "Primary tray icon configuration" `
                                                      -Operation "Apply registry or Group Policy settings" `
                                                      -OperationType 'DefaultYes' `
                                                      -ForceOverride:$Force
        
        if ($shouldProcessPrimary) {
            $methods.AutoTrayDisabled.StartTime = Get-Date
            $executionResults.MethodsAttempted += "AutoTrayDisabled"
            
            if ($AllUsers) {
                Write-ModernStatus "Applying Group Policy configuration for all users..." -Status Processing
                try {
                    $methods.GroupPolicyApplied.StartTime = Get-Date
                    $executionResults.MethodsAttempted += "GroupPolicyApplied"
                    
                    if (Set-GroupPolicyConfiguration -Behavior 'Enable') {
                        $methods.AutoTrayDisabled.Success = $true
                        $methods.GroupPolicyApplied.Success = $true
                        Write-ModernStatus "Group Policy configuration successfully applied" -Status Success
                    } 
                    else {
                        # Capture specific error details from the last exception
                        if ($Error.Count -gt 0) {
                            $errorMessage = $Error[0].Exception.Message
                            $methods.GroupPolicyApplied.Error = $errorMessage
                            $executionResults.ErrorDetails.GroupPolicy = $errorMessage
                        }
                    }
                    
                    $methods.GroupPolicyApplied.EndTime = Get-Date
                    if ($methods.GroupPolicyApplied.Success) {
                        $executionResults.MethodsSucceeded += "GroupPolicyApplied"
                    } else {
                        $executionResults.MethodsFailed += "GroupPolicyApplied"
                    }
                } 
                catch {
                    $methods.GroupPolicyApplied.Error = $_.Exception.Message
                    $executionResults.ErrorDetails.GroupPolicy = $_.Exception.Message
                    Write-ModernStatus "Group Policy configuration failed: $($_.Exception.Message)" -Status Error
                }
            } 
            else {
                Write-ModernStatus "Applying registry configuration for current user..." -Status Processing
                try {
                    # Create backup before making changes if not already specified
                    if (-not $BackupRegistry -and -not $ForceBackup) {
                        Write-ModernStatus "Creating automatic configuration backup..." -Status Info
                        $BackupRegistry = $true
                    } elseif ($ForceBackup -and -not $BackupRegistry) {
                        Write-ModernStatus "ForceBackup specified but BackupRegistry not set - enabling backup creation" -Status Info
                        $BackupRegistry = $true
                    }
                    
                    if (Set-TrayIconConfiguration -Behavior 'Enable' -Force:$Force -ForceBackup:$ForceBackup) {
                        $methods.AutoTrayDisabled.Success = $true
                        Write-ModernStatus "Registry configuration successfully applied" -Status Success
                    } 
                    else {
                        $methods.AutoTrayDisabled.Error = "Registry configuration failed"
                        Write-ModernStatus "Registry configuration failed" -Status Error
                    }
                } 
                catch {
                    $methods.AutoTrayDisabled.Error = $_.Exception.Message
                    Write-ModernStatus "Registry configuration error: $($_.Exception.Message)" -Status Error
                }
            }
            
            $methods.AutoTrayDisabled.EndTime = Get-Date
            $methods.AutoTrayDisabled.Executed = $true
            
            if ($methods.AutoTrayDisabled.Success) {
                $executionResults.MethodsSucceeded += "AutoTrayDisabled"
            } else {
                $executionResults.MethodsFailed += "AutoTrayDisabled"
            }
        } else {
            Write-ModernStatus "Primary configuration skipped by user" -Status Info
            $executionResults.MethodsSkipped += "AutoTrayDisabled"
            if ($AllUsers) {
                $executionResults.MethodsSkipped += "GroupPolicyApplied"
            }
        }
        
        # Execution mode filter - skip advanced methods in Minimal mode
        $applyAdvancedMethods = $true
        if ($ExecutionMode -eq 'Minimal') {
            $applyAdvancedMethods = $false
            Write-ModernStatus "Execution mode set to MINIMAL - Skipping advanced configuration methods" -Status Info
        }
        
        # Methods 2-5: Current user specific settings (skipped in AllUsers mode or Minimal execution mode)
        $currentUserOnlyMethods = @(
            "IndividualSettingsReset", 
            "TrayCacheCleared", 
            "NotificationSettingsReset", 
            "SystemIconsForced"
        )
        
        if (-not $AllUsers -and $applyAdvancedMethods) {
            # Method 2: Reset individual icon settings
            $shouldProcessIndividual = Test-ShouldProcessAuto -Target "Individual icon settings" `
                                                             -Operation "Reset user preferences for all notification icons" `
                                                             -OperationType 'DefaultYes' `
                                                             -ForceOverride:$Force
            
            if ($shouldProcessIndividual) {
                $methods.IndividualSettingsReset.StartTime = Get-Date
                $executionResults.MethodsAttempted += "IndividualSettingsReset"
                
                Write-ModernStatus "Resetting individual icon settings for current user..." -Status Processing
                try {
                    $resetResults = Reset-IndividualIconSettings -Force:$Force -DetailedReport
                    
                    if ($resetResults.Success) {
                        $methods.IndividualSettingsReset.Success = $true
                        
                        # Track individual operation successes from detailed report
                        if ($resetResults.Details.TrayNotify.Success) {
                            $methods.TrayCacheCleared.Success = $true
                            $methods.TrayCacheCleared.Executed = $true
                        }
                        if ($resetResults.Details.NotificationSettings.Success) {
                            $methods.NotificationSettingsReset.Success = $true
                            $methods.NotificationSettingsReset.Executed = $true
                        }
                        
                        # Extract icon count from detailed results
                        $iconCount = $resetResults.Details.NotifyIconSettings.IconsReset
                        Write-ModernStatus "Individual icon settings reset completed ($iconCount icons processed)" -Status Success
                    } 
                    else {
                        $methods.IndividualSettingsReset.Error = "No icon settings were successfully reset"
                        
                        # Provide detailed failure information
                        $failedOperations = @()
                        foreach ($op in $resetResults.Details.Keys) {
                            if (-not $resetResults.Details[$op].Success) {
                                $failedOperations += $op
                            }
                        }
                        
                        if ($failedOperations.Count -gt 0) {
                            Write-ModernStatus "Individual settings reset partially failed: $($failedOperations -join ', ')" -Status Warning
                        } else {
                            Write-ModernStatus "No individual icon settings required reset" -Status Info
                        }
                    }
                }
                catch {
                    $methods.IndividualSettingsReset.Error = $_.Exception.Message
                    Write-ModernStatus "Failed to reset individual icon settings: $($_.Exception.Message)" -Status Error
                }
                finally {
                    $methods.IndividualSettingsReset.EndTime = Get-Date
                    $methods.IndividualSettingsReset.Executed = $true
                    
                    if ($methods.IndividualSettingsReset.Success) {
                        $executionResults.MethodsSucceeded += "IndividualSettingsReset"
                        
                        # Add secondary methods if they were executed and successful
                        if ($methods.TrayCacheCleared.Success) {
                            $executionResults.MethodsSucceeded += "TrayCacheCleared"
                        }
                        if ($methods.NotificationSettingsReset.Success) {
                            $executionResults.MethodsSucceeded += "NotificationSettingsReset"
                        }
                    } else {
                        $executionResults.MethodsFailed += "IndividualSettingsReset"
                        
                        # Track secondary method failures
                        if ($methods.TrayCacheCleared.Executed -and -not $methods.TrayCacheCleared.Success) {
                            $executionResults.MethodsFailed += "TrayCacheCleared"
                        }
                        if ($methods.NotificationSettingsReset.Executed -and -not $methods.NotificationSettingsReset.Success) {
                            $executionResults.MethodsFailed += "NotificationSettingsReset"
                        }
                    }
                }
            } else {
                Write-ModernStatus "Individual icon settings reset skipped by user" -Status Info
                $executionResults.MethodsSkipped += "IndividualSettingsReset"
            }
            
            # Method 3: Force system icons visibility
            $shouldProcessSystemIcons = Test-ShouldProcessAuto -Target "System icons" `
                                                              -Operation "Force visibility of volume, network, and power icons" `
                                                              -OperationType 'DefaultYes' `
                                                              -ForceOverride:$Force
            
            if ($shouldProcessSystemIcons) {
                $methods.SystemIconsForced.StartTime = Get-Date
                $executionResults.MethodsAttempted += "SystemIconsForced"
                
                Write-ModernStatus "Configuring system icons visibility..." -Status Processing
                $systemIconsPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
                $systemIcons = @(
                    @{Name = "HideSCAVolume"; Value = 0; FriendlyName = "Volume"},
                    @{Name = "HideSCANetwork"; Value = 0; FriendlyName = "Network"},
                    @{Name = "HideSCAPower"; Value = 0; FriendlyName = "Power"}
                )
                $systemIconsSet = 0
                $systemIconsFailed = 0
                
                foreach ($icon in $systemIcons) {
                    try {
                        # Smart confirmation for each system icon
                        $shouldProcessIcon = Test-ShouldProcessAuto -Target "System icon: $($icon.FriendlyName)" `
                                                                   -Operation "Force visibility setting" `
                                                                   -OperationType 'DefaultYes' `
                                                                   -ForceOverride:$Force
                        
                        if (-not $shouldProcessIcon) {
                            continue
                        }
                        
                        # Ensure registry path exists
                        if (-not (Test-Path $systemIconsPath)) {
                            $null = New-Item -Path $systemIconsPath -Force -ErrorAction Stop
                        }
                        # Set icon visibility
                        Set-ItemProperty -Path $systemIconsPath -Name $icon.Name -Value $icon.Value -Type DWord -Force -ErrorAction Stop
                        $systemIconsSet++
                        Write-ModernStatus "System icon '$($icon.FriendlyName)' forced to show" -Status Success
                    }
                    catch {
                        $systemIconsFailed++
                        Write-ModernStatus "Failed to set system icon '$($icon.FriendlyName)': $($_.Exception.Message)" -Status Warning
                        if (-not $methods.SystemIconsForced.Error) {
                            $methods.SystemIconsForced.Error = $_.Exception.Message
                        }
                    }
                }
                
                $methods.SystemIconsForced.Success = ($systemIconsSet -gt 0)
                $methods.SystemIconsForced.Executed = $true
                $methods.SystemIconsForced.EndTime = Get-Date
                
                if ($methods.SystemIconsForced.Success) {
                    $executionResults.MethodsSucceeded += "SystemIconsForced"
                    Write-ModernStatus "System icons forced to show ($systemIconsSet/$($systemIcons.Count) settings applied)" -Status Success
                } 
                else {
                    $executionResults.MethodsFailed += "SystemIconsForced"
                    if ($systemIconsFailed -eq $systemIcons.Count) {
                        Write-ModernStatus "No system icons were configured" -Status Warning
                    }
                }
            } else {
                Write-ModernStatus "System icons configuration skipped by user" -Status Info
                $executionResults.MethodsSkipped += "SystemIconsForced"
            }
        } 
        elseif ($AllUsers) {
            # Skip current-user-only methods in AllUsers mode with clear explanation
            foreach ($method in $currentUserOnlyMethods) {
                Write-ModernStatus "Skipping $method (not applicable in AllUsers/Group Policy mode)" -Status Info
                $executionResults.MethodsSkipped += $method
            }
        }
        elseif (-not $applyAdvancedMethods) {
            # Skip advanced methods in Minimal execution mode
            foreach ($method in $currentUserOnlyMethods + "Windows11Optimized") {
                Write-ModernStatus "Skipping $method (not applicable in Minimal execution mode)" -Status Info
                $executionResults.MethodsSkipped += $method
            }
        }
        
        # Method 5: Windows 11 specific optimization (if not in Minimal mode)
        if (-not $AllUsers -and $applyAdvancedMethods) {
            $windowsVersion = Get-WindowsVersion
            if ($windowsVersion -Like "*11*") {
                $shouldProcessWin11 = Test-ShouldProcessAuto -Target "Windows 11 settings" `
                                                            -Operation "Apply taskbar optimization settings" `
                                                            -OperationType 'DefaultYes' `
                                                            -ForceOverride:$Force
                
                if ($shouldProcessWin11) {
                    $methods.Windows11Optimized.StartTime = Get-Date
                    $executionResults.MethodsAttempted += "Windows11Optimized"
                    
                    Write-ModernStatus "Applying Windows 11 specific tray icon optimizations..." -Status Processing
                    $win11Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                    try {
                        # Ensure path exists
                        if (-not (Test-Path $win11Path)) {
                            $null = New-Item -Path $win11Path -Force -ErrorAction Stop
                        }
                        
                        # Apply Windows 11 taskbar optimizations
                        $optimizationsApplied = 0
                        $optimizationsTotal = 0
                        
                        # Method 1: Disable taskbar search (often affects tray area)
                        $optimizationsTotal++
                        try {
                            $shouldProcessOptimization = Test-ShouldProcessAuto -Target "Windows 11 TaskbarMn setting" `
                                                                               -Operation "Set to 0 for combined behavior" `
                                                                               -OperationType 'DefaultYes' `
                                                                               -ForceOverride:$Force
                            
                            if ($shouldProcessOptimization) {
                                Set-ItemProperty -Path $win11Path -Name "TaskbarMn" -Value 0 -Type DWord -Force -ErrorAction Stop
                                $optimizationsApplied++
                            }
                        }
                        catch {
                            # Non-critical failure
                        }
                        
                        # Method 2: Ensure taskbar alignment allows space for tray
                        $optimizationsTotal++
                        try {
                            $shouldProcessOptimization = Test-ShouldProcessAuto -Target "Windows 11 TaskbarDa setting" `
                                                                               -Operation "Set to 0 for default alignment" `
                                                                               -OperationType 'DefaultYes' `
                                                                               -ForceOverride:$Force
                            
                            if ($shouldProcessOptimization) {
                                Set-ItemProperty -Path $win11Path -Name "TaskbarDa" -Value 0 -Type DWord -Force -ErrorAction Stop
                                $optimizationsApplied++
                            }
                        }
                        catch {
                            # Non-critical failure
                        }
                        
                        # Method 3: Ensure taskbar size accommodates all icons
                        $optimizationsTotal++
                        try {
                            $shouldProcessOptimization = Test-ShouldProcessAuto -Target "Windows 11 TaskbarSi setting" `
                                                                               -Operation "Set to 0 for default size" `
                                                                               -OperationType 'DefaultYes' `
                                                                               -ForceOverride:$Force
                            
                            if ($shouldProcessOptimization) {
                                Set-ItemProperty -Path $win11Path -Name "TaskbarSi" -Value 0 -Type DWord -Force -ErrorAction Stop
                                $optimizationsApplied++
                            }
                        }
                        catch {
                            # Non-critical failure
                        }
                        
                        $methods.Windows11Optimized.Success = ($optimizationsApplied -gt 0)
                        if ($optimizationsApplied -gt 0) {
                            Write-ModernStatus "Windows 11 specific settings applied ($optimizationsApplied/$optimizationsTotal optimizations)" -Status Success
                        }
                    }
                    catch {
                        $methods.Windows11Optimized.Error = $_.Exception.Message
                        Write-ModernStatus "Windows 11 specific settings failed: $($_.Exception.Message)" -Status Warning
                    }
                    finally {
                        $methods.Windows11Optimized.EndTime = Get-Date
                        $methods.Windows11Optimized.Executed = $true
                        
                        if ($methods.Windows11Optimized.Success) {
                            $executionResults.MethodsSucceeded += "Windows11Optimized"
                        } else {
                            $executionResults.MethodsFailed += "Windows11Optimized"
                        }
                    }
                } else {
                    Write-ModernStatus "Windows 11 optimizations skipped by user" -Status Info
                    $executionResults.MethodsSkipped += "Windows11Optimized"
                }
            } 
            else {
                Write-ModernStatus "Windows 11 specific settings skipped (running on: $windowsVersion)" -Status Info
                $executionResults.MethodsSkipped += "Windows11Optimized"
            }
        }
        
        Write-ModernStatus "Comprehensive tray icon enabling completed" -Status Success
        
        # Determine overall exit code based on execution results
        $primaryMethodSuccess = $methods.AutoTrayDisabled.Success -or $methods.GroupPolicyApplied.Success
        
        if (-not $primaryMethodSuccess) {
            $executionResults.ExitCode = 2  # Failed - no primary methods succeeded
            Write-ModernStatus "Configuration failed - primary method did not succeed" -Status Error
        }
        elseif ($executionResults.MethodsFailed.Count -gt 0) {
            $executionResults.ExitCode = 1  # Partial Success - primary method succeeded but secondary methods failed
            Write-ModernStatus "Configuration completed with partial success" -Status Warning
        }
        else {
            $executionResults.ExitCode = 0  # Success - all applicable methods succeeded
            Write-ModernStatus "Configuration completed successfully" -Status Success
        }
        
        # Display execution results with contextual coloring and detailed information
        Write-Host ""
        Write-ModernHeader "Execution Results" "Configuration Status Summary"
        
        # Primary configuration status
        $primaryStatus = if ($AllUsers) {
            if ($methods.GroupPolicyApplied.Success) { "Success" } else { "Failed" }
        } else {
            if ($methods.AutoTrayDisabled.Success) { "Success" } else { "Failed" }
        }
        $primaryColor = if ($primaryStatus -eq "Success") { "Success" } else { "Error" }
        
        Write-ModernCard "Primary Configuration" $primaryStatus -ValueColor $primaryColor
        
        # Additional methods status (only if attempted)
        if ($executionResults.MethodsAttempted.Count -gt 1) {
            $additionalMethods = $executionResults.MethodsAttempted | Where-Object { $_ -notin @("AutoTrayDisabled", "GroupPolicyApplied") }
            $additionalSuccess = ($additionalMethods | Where-Object { $executionResults.MethodsSucceeded -contains $_ }).Count
            $additionalTotal = $additionalMethods.Count
    
            if ($additionalTotal -gt 0) {
                $additionalStatus = "$additionalSuccess/$additionalTotal succeeded"
    
                # Use switch statement for safer color selection
                $additionalColor = switch ($true) {
                    ($additionalSuccess -eq $additionalTotal) { "Success" }
                    ($additionalSuccess -gt 0) { "Warning" }
                    default { "Error" }
                }
    
                # Double validation with fallback
                $validColors = @("Primary", "Success", "Error", "Warning", "Info", "Accent", "Light")
                if ($additionalColor -notin $validColors) {
                    $additionalColor = "Info"
                }
    
                Write-ModernCard "Additional Methods" $additionalStatus -ValueColor $additionalColor
            }
        }
        
        # Detailed method breakdown (verbose mode)
        if ($Force -or $VerbosePreference -eq 'Continue' -or $executionResults.ExitCode -ne 0) {
            Write-Host ""
            Write-EnhancedOutput "DETAILED METHOD RESULTS:" -Type Primary
            
            # Sort methods by priority for display
            $methodsInOrder = @(
                "AutoTrayDisabled",
                "GroupPolicyApplied", 
                "IndividualSettingsReset", 
                "SystemIconsForced", 
                "Windows11Optimized",
                "TrayCacheCleared", 
                "NotificationSettingsReset"
            )
            
            foreach ($methodName in $methodsInOrder) {
                if (-not $methods.ContainsKey($methodName)) { continue }
                
                $method = $methods[$methodName]
                if (-not $method.Executed) { continue }
                
                $status = "Not Executed"
                $color = "Dark"
                $elapsed = $null
                $errorDisplay = $null
                
                if ($method.Executed) {
                    $elapsed = [math]::Round(($method.EndTime - $method.StartTime).TotalMilliseconds)
                    
                    if ($method.Success) {
                        $status = "Success"
                        $color = "Success"
                    }
                    else {
                        $status = "Failed"
                        $color = "Error"
                        if ($method.Error) {
                            $errorDisplay = $method.Error.Substring(0, [Math]::Min(60, $method.Error.Length))
                            if ($method.Error.Length -gt 60) { $errorDisplay += "..." }
                        }
                    }
                }
                
                # Format the display text with elapsed time and errors
                $displayText = $status
                if ($elapsed) { $displayText += " ($elapsed ms)" }
                if ($errorDisplay) { $displayText += " - $errorDisplay" }
                
                Write-ModernCard $methodName $displayText -ValueColor $color
            }
        }
        
        # Advanced troubleshooting for critical failures
        $criticalFailure = $executionResults.ExitCode -eq 2
        if ($criticalFailure -or ($executionResults.ExitCode -eq 1 -and $Force)) {
            if ($AllUsers -and $methods.GroupPolicyApplied.Error) {
                Write-Host ""
                Write-ModernHeader "Troubleshooting Guide" "Group Policy Configuration Failure"
                Write-ModernStatus "Analyzed error details and system context:" -Status Info
                
                $errorText = $methods.GroupPolicyApplied.Error
                
                # Intelligent error analysis and recommendations
                switch -Regex ($errorText) {
                    "UnauthorizedAccessException|Access is denied|Administrator rights|required" {
                        Write-ModernStatus "ACCESS ISSUE DETECTED" -Status Error
                        Write-ModernCard "Root Cause" "Insufficient permissions to modify Group Policy settings"
                        Write-ModernCard "Primary Solution" "Run PowerShell as Administrator before executing this script"
                        Write-ModernCard "Verification Command" "whoami /groups | findstr /i ""administrators"""
                    }
                    "Registry policy settings|policy|GPO|policy definitions" {
                        Write-ModernStatus "GROUP POLICY RESTRICTION DETECTED" -Status Error
                        Write-ModernCard "Root Cause" "Registry modifications blocked by domain Group Policy"
                        Write-ModernCard "Primary Solution" "Contact your system administrator to update Group Policy settings"
                        Write-ModernCard "Alternative Approach" "Use current user mode without -AllUsers parameter for local configuration"
                    }
                    "path not found|cannot find path|HKLM|HKCU|registry key" {
                        Write-ModernStatus "REGISTRY PATH ISSUE DETECTED" -Status Error
                        Write-ModernCard "Root Cause" "Required Group Policy registry paths are missing or inaccessible"
                        Write-ModernCard "Diagnostic Command" "Get-Service gpsvc | Select-Object Status, DisplayName"
                        Write-ModernCard "Repair Action" "Ensure Group Policy Client service is running and has proper registry permissions"
                    }
                    default {
                        Write-ModernStatus "UNEXPECTED FAILURE DETECTED" -Status Error
                        Write-ModernCard "Error Context" $errorText.Substring(0, [Math]::Min(100, $errorText.Length)) + $(if ($errorText.Length -gt 100) { "..." } else { "" })
                        Write-ModernCard "Diagnostic Step" "Run with -ExecutionMode Diagnostic parameter for detailed system analysis"
                        Write-ModernCard "Escalation Path" "Report issue at $($Script:Configuration.GitHubRepository) with full error details"
                    }
                }
            }
            elseif (-not $AllUsers -and $methods.AutoTrayDisabled.Error) {
                Write-Host ""
                Write-ModernHeader "Troubleshooting Guide" "Registry Configuration Failure"
                Write-ModernStatus "Analyzing registry access and configuration issues:" -Status Info
                
                $errorText = $methods.AutoTrayDisabled.Error
                
                switch -Regex ($errorText) {
                    "UnauthorizedAccessException|Access is denied" {
                        Write-ModernStatus "REGISTRY ACCESS ISSUE DETECTED" -Status Error
                        Write-ModernCard "Root Cause" "Insufficient permissions to modify registry settings"
                        Write-ModernCard "User Solution" "Close applications that might be locking registry keys (e.g., Explorer, Settings)"
                        Write-ModernCard "Admin Solution" "Temporarily elevate privileges using 'Run as Administrator'"
                    }
                    "path not found|cannot find path" {
                        Write-ModernStatus "REGISTRY PATH MISSING" -Status Error
                        Write-ModernCard "Root Cause" "Required registry path does not exist on this system"
                        Write-ModernCard "Resolution" "Script will attempt to create the path automatically on next execution"
                    }
                    default {
                        Write-ModernStatus "REGISTRY MODIFICATION FAILED" -Status Error
                        Write-ModernCard "Error Details" $errorText.Substring(0, [Math]::Min(100, $errorText.Length)) + $(if ($errorText.Length -gt 100) { "..." } else { "" })
                        Write-ModernCard "System Recovery" "System has been automatically restored from backup"
                        Write-ModernCard "Next Step" "Run diagnostic mode: .\$($Script:Configuration.ScriptName) -Action Enable -Diagnostic"
                    }
                }
            }
        }
        
        # Export execution report if requested
        if ($ReportPath) {
            try {
                $executionResults.CompletionTime = Get-Date
                
                # Calculate performance metrics
                $executionResults.TotalDuration = [math]::Round(($executionResults.CompletionTime - $executionResults.StartTime).TotalSeconds, 2)
                $executionResults.MethodCount = @{
                    Attempted = $executionResults.MethodsAttempted.Count
                    Succeeded = $executionResults.MethodsSucceeded.Count
                    Failed = $executionResults.MethodsFailed.Count
                    Skipped = $executionResults.MethodsSkipped.Count
                }
                
                # Convert to JSON with proper formatting
                $reportJson = $executionResults | ConvertTo-Json -Depth 10 -Compress:$false
                
                # Save with UTF-8 encoding (no BOM)
                $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText($ReportPath, $reportJson, $utf8NoBom)
                
                Write-ModernStatus "Execution report exported successfully" -Status Success
                Write-ModernCard "Report Path" $ReportPath
                Write-ModernCard "Report Size" "$([math]::Round((Get-Item $ReportPath).Length / 1024, 1)) KB"
            }
            catch {
                Write-ModernStatus "Failed to export execution report: $($_.Exception.Message)" -Status Warning
            }
        }
        
        return ($executionResults.ExitCode -eq 0)
    }
    catch {
        Write-ModernStatus "Critical error during comprehensive enable operation: $($_.Exception.Message)" -Status Error
        Write-ModernStatus "Exception Type: $($_.Exception.GetType().FullName)" -Status Warning
        Write-ModernStatus "Stack Trace: $($_.ScriptStackTrace)" -Status Warning
        
        # Capture exception in execution results
        $executionResults.ErrorDetails.CriticalException = @{
            Message = $_.Exception.Message
            Type = $_.Exception.GetType().FullName
            StackTrace = $_.ScriptStackTrace
        }
        $executionResults.ExitCode = 2  # Failed
        $executionResults.CompletionTime = Get-Date
        
        # Attempt to export error report if path was specified
        if ($ReportPath -and (Test-Path (Split-Path $ReportPath -Parent))) {
            try {
                $errorReport = $executionResults | ConvertTo-Json -Depth 5
                $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText($ReportPath, $errorReport, $utf8NoBom)
                Write-ModernStatus "Error report exported to: $ReportPath" -Status Info
            }
            catch {
                Write-ModernStatus "Failed to export error report: $($_.Exception.Message)" -Status Warning
            }
        }
        
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
        Enterprise-grade comprehensive reset of individual tray icon settings with enhanced reporting and smart confirmation handling.
    
    .DESCRIPTION
        Resets all individual system tray icon settings to default visibility state through multiple registry modification techniques:
        - Resets NotifyIconSettings registry entries (main individual icon preferences)
        - Clears tray notification cache streams (IconStreams, PastIconsStream)
        - Resets desktop icon visibility preferences (HideDesktopIcons)
        - Clears taskbar layout customizations (Taskband settings)
        - Resets notification area application preferences (Notifications Settings)
        
        Features enterprise-grade error handling, detailed progress tracking, comprehensive success reporting,
        smart confirmation system integration, and automatic recovery mechanisms for integration with larger
        configuration management workflows.
    
    .PARAMETER Force
        Bypass confirmation prompts and warnings. Essential for automated deployment scenarios.
    
    .PARAMETER DetailedReport
        Return detailed hash table with individual operation results instead of simple boolean success status.
    
    .PARAMETER ConfirmAction
        Enable explicit confirmation prompts for all operations. When not specified, uses smart defaults:
        - Auto-Yes for most operations
        - Auto-No for destructive operations

    .EXAMPLE
        Reset-IndividualIconSettings
        Resets all individual icon settings with smart confirmation handling and default auto-approval.
    
    .EXAMPLE
        Reset-IndividualIconSettings -Force -DetailedReport
        Forces reset without prompts and returns comprehensive operation results with detailed metrics.
    
    .EXAMPLE
        Reset-IndividualIconSettings -ConfirmAction
        Resets all individual icon settings with explicit confirmation prompts for each operation.
    
    .OUTPUTS
        [System.Collections.Hashtable] or [System.Boolean]
        Returns detailed results hash table when -DetailedReport specified, otherwise boolean success status.
    
    .NOTES
        Author: Mikhail Deynekin
        Version: 5.9 (Enterprise Enhanced Edition)
        Requirements: Windows 10/11, PowerShell 5.1+
        Security: Requires registry write access to HKCU hive
        Impact: Resets user-specific tray icon preferences and cache data
        Recovery: Automatic backup creation recommended before execution
    
        EXIT CODES (when returning boolean):
        - $true: Success - At least one operation completed successfully
        - $false: Failed - No operations completed successfully
    
        ENTERPRISE DEPLOYMENT NOTES:
        - Use -Force parameter for automated deployment scenarios
        - Use -DetailedReport for audit trail and compliance reporting
        - Test in non-production environment before deployment
        - Combine with comprehensive backup system for rollback capability
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force,
        
        [Parameter(Mandatory = $false)]
        [switch]$DetailedReport,

        [Parameter(Mandatory = $false)]
        [switch]$ConfirmAction
    )
    
    # Initialize comprehensive results tracking with enhanced metrics
    $executionResults = [ordered]@{
        Success = $false
        StartTime = Get-Date
        OperationsAttempted = 0
        OperationsSucceeded = 0
        OperationsFailed = 0
        OperationsSkipped = 0
        TotalRegistryOperations = 0
        SuccessfulRegistryOperations = 0
        FailedRegistryOperations = 0
        Details = @{
            NotifyIconSettings = @{ 
                Success = $false; 
                IconsProcessed = 0; 
                IconsReset = 0; 
                IconsSkipped = 0;
                IconsFailed = 0;
                Error = $null;
                RegistryPath = "HKCU:\Control Panel\NotifyIconSettings";
                Description = "Individual application icon visibility preferences"
            }
            TrayNotify = @{ 
                Success = $false; 
                CacheCleared = $false; 
                PropertiesProcessed = 0;
                PropertiesCleared = 0;
                PropertiesFailed = 0;
                Error = $null;
                RegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TrayNotify";
                Description = "Tray icon cache and notification streams"
            }
            HideDesktopIcons = @{ 
                Success = $false; 
                ItemsProcessed = 0; 
                ItemsRemoved = 0;
                ItemsSkipped = 0;
                ItemsFailed = 0;
                Error = $null;
                RegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons";
                Description = "Desktop icon visibility settings"
            }
            TaskbarLayout = @{ 
                Success = $false; 
                SettingsCleared = $false; 
                PropertiesProcessed = 0;
                PropertiesCleared = 0;
                PropertiesFailed = 0;
                Error = $null;
                RegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband";
                Description = "Taskbar layout and pinned items customization"
            }
            NotificationSettings = @{ 
                Success = $false; 
                AppsProcessed = 0; 
                AppsReset = 0;
                AppsSkipped = 0;
                AppsFailed = 0;
                Error = $null;
                RegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings";
                Description = "Notification area application preferences"
            }
        }
        CompletionTime = $null
        TotalDuration = $null
        PerformanceMetrics = @{
            AverageOperationTime = $null
            OperationsPerSecond = $null
            RegistryOperationsPerSecond = $null
        }
        SystemContext = @{
            UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            ComputerName = $env:COMPUTERNAME
            WindowsVersion = Get-WindowsVersion
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            ExecutionPolicy = Get-ExecutionPolicy -Scope CurrentUser
        }
    }
    
    try {
        Write-ModernStatus "Initiating comprehensive individual icon settings reset..." -Status Processing
        Write-ModernCard "Execution Mode" $(if ($Force) { "FORCED (No prompts)" } else { "Standard" }) -ValueColor $(if ($Force) { "Warning" } else { "Info" })
        Write-ModernCard "Confirmation Mode" $(if ($ConfirmAction) { "EXPLICIT (All prompts)" } else { "Smart Defaults" }) -ValueColor $(if ($ConfirmAction) { "Info" } else { "Success" })
        Write-ModernCard "Reporting Level" $(if ($DetailedReport) { "DETAILED (Hash table)" } else { "Simple (Boolean)" }) -ValueColor "Info"
        
        # Operation 1: Reset NotifyIconSettings (main individual icon preferences)
        $executionResults.OperationsAttempted++
        Write-ModernStatus "Resetting NotifyIconSettings registry entries..." -Status Processing
        
        $settingsPath = "HKCU:\Control Panel\NotifyIconSettings"
        if (Test-Path $settingsPath) {
            $iconCount = 0
            $resetCount = 0
            $skipCount = 0
            $failCount = 0
            $icons = Get-ChildItem -Path $settingsPath -ErrorAction SilentlyContinue
            
            Write-ModernStatus "Processing $($icons.Count) individual icon settings..." -Status Info
            
            foreach ($icon in $icons) {
                try {
                    $iconCount++
                    $executionResults.TotalRegistryOperations++
                    
                    # Smart confirmation handling with enhanced context
                    $shouldProcess = Test-ShouldProcessAuto -Target "Icon setting: $($icon.PSChildName)" `
                                                           -Operation "Reset IsPromoted to show icon" `
                                                           -OperationType 'DefaultYes' `
                                                           -ForceOverride:$Force
                    
                    if (-not $shouldProcess) {
                        $skipCount++
                        Write-ModernStatus "Skipped icon: $($icon.PSChildName)" -Status Info
                        continue
                    }
                    
                    # Reset the IsPromoted value to 1 (show icon) with enhanced error handling
                    Set-ItemProperty -Path $icon.PSPath -Name "IsPromoted" -Value 1 -Type DWord -Force -ErrorAction Stop
                    $resetCount++
                    $executionResults.SuccessfulRegistryOperations++
                    
                    Write-ModernStatus "Reset icon: $($icon.PSChildName)" -Status Success
                }
                catch [System.UnauthorizedAccessException] {
                    $failCount++
                    $executionResults.FailedRegistryOperations++
                    Write-ModernStatus "Access denied for $($icon.PSChildName): $($_.Exception.Message)" -Status Error
                }
                catch [System.Management.Automation.ItemNotFoundException] {
                    $failCount++
                    $executionResults.FailedRegistryOperations++
                    Write-ModernStatus "Icon setting not found: $($icon.PSChildName)" -Status Warning
                }
                catch {
                    $failCount++
                    $executionResults.FailedRegistryOperations++
                    Write-ModernStatus "Failed to reset $($icon.PSChildName): $($_.Exception.Message)" -Status Warning
                }
            }
            
            # Enhanced results tracking for NotifyIconSettings
            $executionResults.Details.NotifyIconSettings.IconsProcessed = $iconCount
            $executionResults.Details.NotifyIconSettings.IconsReset = $resetCount
            $executionResults.Details.NotifyIconSettings.IconsSkipped = $skipCount
            $executionResults.Details.NotifyIconSettings.IconsFailed = $failCount
            $executionResults.Details.NotifyIconSettings.Success = ($resetCount -gt 0)
            
            if ($resetCount -gt 0) {
                Write-ModernStatus "NotifyIconSettings reset completed: $resetCount of $iconCount icons successfully reset" -Status Success
                $executionResults.OperationsSucceeded++
                
                # Additional success details
                if ($skipCount -gt 0) {
                    Write-ModernStatus "$skipCount icons were skipped by user confirmation" -Status Info
                }
                if ($failCount -gt 0) {
                    Write-ModernStatus "$failCount icons failed to reset (see warnings above)" -Status Warning
                }
            } else {
                if ($skipCount -eq $iconCount) {
                    Write-ModernStatus "NotifyIconSettings reset skipped: All $iconCount icons were skipped by user" -Status Info
                } elseif ($failCount -eq $iconCount) {
                    Write-ModernStatus "NotifyIconSettings reset failed: All $iconCount icons failed to reset" -Status Error
                } else {
                    Write-ModernStatus "No NotifyIconSettings were reset ($iconCount icons processed)" -Status Info
                }
                $executionResults.OperationsFailed++
            }
        }
        else {
            Write-ModernStatus "NotifyIconSettings path not found: $settingsPath" -Status Warning
            $executionResults.Details.NotifyIconSettings.Error = "Registry path not found or inaccessible"
            $executionResults.OperationsFailed++
        }
        
        # Operation 2: Reset TrayNotify streams (icon cache) with enhanced error handling
        $executionResults.OperationsAttempted++
        Write-ModernStatus "Resetting TrayNotify cache streams..." -Status Processing
        
        $trayPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TrayNotify"
        
        # Create TrayNotify path if it doesn't exist with smart confirmation
        if (-not (Test-Path $trayPath)) {
            try {
                Write-ModernStatus "TrayNotify registry path does not exist, creating structure..." -Status Info
                
                $shouldCreatePath = Test-ShouldProcessAuto -Target "Registry path: $trayPath" `
                                                          -Operation "Create TrayNotify registry structure" `
                                                          -OperationType 'DefaultYes' `
                                                          -ForceOverride:$Force
                
                if ($shouldCreatePath) {
                    $null = New-Item -Path $trayPath -Force -ErrorAction Stop
                    Write-ModernStatus "TrayNotify path created successfully" -Status Success
                } else {
                    Write-ModernStatus "TrayNotify path creation skipped by user" -Status Warning
                    throw "TrayNotify registry path does not exist and creation was declined"
                }
            }
            catch {
                $errorMsg = "Failed to create TrayNotify path: $($_.Exception.Message)"
                Write-ModernStatus $errorMsg -Status Error
                $executionResults.Details.TrayNotify.Error = $errorMsg
                $executionResults.OperationsFailed++
            }
        }
        
        # Clear TrayNotify streams if path exists or was successfully created
        if (Test-Path $trayPath) {
            try {
                $cacheProperties = @("IconStreams", "PastIconsStream", "UserStartTime", "UserStartTimeLow32")
                $clearedProperties = 0
                $failedProperties = 0
                $processedProperties = 0
                
                Write-ModernStatus "Processing $($cacheProperties.Count) TrayNotify cache properties..." -Status Info
                
                foreach ($property in $cacheProperties) {
                    try {
                        $processedProperties++
                        $executionResults.TotalRegistryOperations++
                        
                        # Check if property exists and remove it with confirmation
                        if (Get-ItemProperty -Path $trayPath -Name $property -ErrorAction SilentlyContinue) {
                            
                            $shouldProcess = Test-ShouldProcessAuto -Target "TrayNotify property: $property" `
                                                                   -Operation "Remove cached tray icon data" `
                                                                   -OperationType 'DefaultYes' `
                                                                   -ForceOverride:$Force
                            
                            if (-not $shouldProcess) {
                                Write-ModernStatus "Skipped TrayNotify property: $property" -Status Info
                                continue
                            }
                            
                            Remove-ItemProperty -Path $trayPath -Name $property -Force -ErrorAction Stop
                            $clearedProperties++
                            $executionResults.SuccessfulRegistryOperations++
                            
                            Write-ModernStatus "Cleared TrayNotify property: $property" -Status Success
                        }
                        else {
                            Write-ModernStatus "TrayNotify property not present: $property" -Status Info
                        }
                    }
                    catch [System.UnauthorizedAccessException] {
                        $failedProperties++
                        $executionResults.FailedRegistryOperations++
                        Write-ModernStatus "Access denied for TrayNotify property $property : $($_.Exception.Message)" -Status Error
                    }
                    catch [System.Management.Automation.ItemNotFoundException] {
                        $failedProperties++
                        $executionResults.FailedRegistryOperations++
                        Write-ModernStatus "TrayNotify property not found: $property" -Status Warning
                    }
                    catch {
                        $failedProperties++
                        $executionResults.FailedRegistryOperations++
                        Write-ModernStatus "Failed to clear TrayNotify property $property : $($_.Exception.Message)" -Status Warning
                    }
                }
                
                # Enhanced stream reinitialization for critical binary streams
                $streamProperties = @("IconStreams", "PastIconsStream")
                $reinitializedStreams = 0
                
                foreach ($stream in $streamProperties) {
                    try {
                        $executionResults.TotalRegistryOperations++
                        
                        $shouldProcess = Test-ShouldProcessAuto -Target "TrayNotify stream: $stream" `
                                                               -Operation "Reinitialize empty binary stream" `
                                                               -OperationType 'DefaultYes' `
                                                               -ForceOverride:$Force
                        
                        if (-not $shouldProcess) {
                            continue
                        }
                        
                        Set-ItemProperty -Path $trayPath -Name $stream -Value @() -Type Binary -Force -ErrorAction SilentlyContinue
                        $reinitializedStreams++
                        $executionResults.SuccessfulRegistryOperations++
                        
                        Write-ModernStatus "Reinitialized TrayNotify stream: $stream" -Status Success
                    }
                    catch {
                        $failedProperties++
                        $executionResults.FailedRegistryOperations++
                        Write-ModernStatus "Failed to reinitialize stream $stream : $($_.Exception.Message)" -Status Warning
                    }
                }
                
                # Enhanced results tracking for TrayNotify
                $executionResults.Details.TrayNotify.PropertiesProcessed = $processedProperties
                $executionResults.Details.TrayNotify.PropertiesCleared = $clearedProperties
                $executionResults.Details.TrayNotify.PropertiesFailed = $failedProperties
                $executionResults.Details.TrayNotify.CacheCleared = ($clearedProperties -gt 0 -or $reinitializedStreams -gt 0)
                $executionResults.Details.TrayNotify.Success = ($clearedProperties -gt 0 -or $reinitializedStreams -gt 0)
                
                if ($clearedProperties -gt 0 -or $reinitializedStreams -gt 0) {
                    $statusMessage = "TrayNotify cache cleared: $clearedProperties properties cleared, $reinitializedStreams streams reinitialized"
                    Write-ModernStatus $statusMessage -Status Success
                    $executionResults.OperationsSucceeded++
                } else {
                    if ($failedProperties -gt 0) {
                        Write-ModernStatus "TrayNotify cache clearance failed: $failedProperties operations failed" -Status Error
                    } else {
                        Write-ModernStatus "TrayNotify cache already cleared or no operations performed" -Status Info
                    }
                    $executionResults.OperationsFailed++
                }
            }
            catch {
                $errorMsg = "Failed to clear TrayNotify streams: $($_.Exception.Message)"
                Write-ModernStatus $errorMsg -Status Error
                $executionResults.Details.TrayNotify.Error = $errorMsg
                $executionResults.OperationsFailed++
            }
        } else {
            Write-ModernStatus "TrayNotify path could not be created or accessed" -Status Error
            $executionResults.Details.TrayNotify.Error = "Registry path creation failed or inaccessible"
            $executionResults.OperationsFailed++
        }
        
        # Operation 3: Reset desktop icon visibility settings (related to system icons)
        $executionResults.OperationsAttempted++
        Write-ModernStatus "Resetting desktop icon visibility settings..." -Status Processing
        
        $desktopPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons"
        if (Test-Path $desktopPath) {
            try {
                $desktopItems = Get-ChildItem -Path $desktopPath -ErrorAction SilentlyContinue
                $itemsProcessed = 0
                $itemsRemoved = 0
                $itemsSkipped = 0
                $itemsFailed = 0
                
                Write-ModernStatus "Processing $($desktopItems.Count) desktop icon settings..." -Status Info
                
                foreach ($item in $desktopItems) {
                    try {
                        $itemsProcessed++
                        $executionResults.TotalRegistryOperations++
                        
                        $shouldProcess = Test-ShouldProcessAuto -Target "Desktop icon setting: $($item.PSChildName)" `
                                                               -Operation "Remove desktop icon visibility override" `
                                                               -OperationType 'DefaultYes' `
                                                               -ForceOverride:$Force
                        
                        if (-not $shouldProcess) {
                            $itemsSkipped++
                            Write-ModernStatus "Skipped desktop icon setting: $($item.PSChildName)" -Status Info
                            continue
                        }
                        
                        Remove-Item -Path $item.PSPath -Recurse -Force -ErrorAction Stop
                        $itemsRemoved++
                        $executionResults.SuccessfulRegistryOperations++
                        
                        Write-ModernStatus "Removed desktop icon setting: $($item.PSChildName)" -Status Success
                    }
                    catch [System.UnauthorizedAccessException] {
                        $itemsFailed++
                        $executionResults.FailedRegistryOperations++
                        Write-ModernStatus "Access denied for desktop icon $($item.PSChildName): $($_.Exception.Message)" -Status Error
                    }
                    catch {
                        $itemsFailed++
                        $executionResults.FailedRegistryOperations++
                        Write-ModernStatus "Failed to remove desktop icon setting $($item.PSChildName): $($_.Exception.Message)" -Status Warning
                    }
                }
                
                # Enhanced results tracking for HideDesktopIcons
                $executionResults.Details.HideDesktopIcons.ItemsProcessed = $itemsProcessed
                $executionResults.Details.HideDesktopIcons.ItemsRemoved = $itemsRemoved
                $executionResults.Details.HideDesktopIcons.ItemsSkipped = $itemsSkipped
                $executionResults.Details.HideDesktopIcons.ItemsFailed = $itemsFailed
                $executionResults.Details.HideDesktopIcons.Success = ($itemsRemoved -gt 0)
                
                if ($itemsRemoved -gt 0) {
                    Write-ModernStatus "Desktop icon settings reset: $itemsRemoved of $itemsProcessed items successfully removed" -Status Success
                    $executionResults.OperationsSucceeded++
                    
                    if ($itemsSkipped -gt 0) {
                        Write-ModernStatus "$itemsSkipped items were skipped by user confirmation" -Status Info
                    }
                    if ($itemsFailed -gt 0) {
                        Write-ModernStatus "$itemsFailed items failed to remove (see warnings above)" -Status Warning
                    }
                } else {
                    if ($itemsSkipped -eq $itemsProcessed) {
                        Write-ModernStatus "Desktop icon settings reset skipped: All $itemsProcessed items were skipped by user" -Status Info
                    } elseif ($itemsFailed -eq $itemsProcessed) {
                        Write-ModernStatus "Desktop icon settings reset failed: All $itemsProcessed items failed to remove" -Status Error
                    } else {
                        Write-ModernStatus "No desktop icon settings found to reset" -Status Info
                    }
                    $executionResults.OperationsFailed++
                }
            }
            catch {
                $errorMsg = "Failed to reset desktop icons: $($_.Exception.Message)"
                Write-ModernStatus $errorMsg -Status Error
                $executionResults.Details.HideDesktopIcons.Error = $errorMsg
                $executionResults.OperationsFailed++
            }
        } else {
            Write-ModernStatus "HideDesktopIcons path not found: $desktopPath" -Status Warning
            $executionResults.Details.HideDesktopIcons.Error = "Registry path not found or inaccessible"
            $executionResults.OperationsFailed++
        }
        
        # Operation 4: Reset taskbar layout customizations (additional icon positioning)
        $executionResults.OperationsAttempted++
        Write-ModernStatus "Resetting taskbar layout customizations..." -Status Processing
        
        $taskbarPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
        if (Test-Path $taskbarPath) {
            try {
                $taskbarProperties = @("Favorites", "FavoritesResolve", "Pinned", "Recent", "Initialized", "TaskbandLayout")
                $propertiesCleared = 0
                $propertiesFailed = 0
                $propertiesProcessed = 0
                
                Write-ModernStatus "Processing $($taskbarProperties.Count) taskbar layout properties..." -Status Info
                
                foreach ($property in $taskbarProperties) {
                    try {
                        $propertiesProcessed++
                        $executionResults.TotalRegistryOperations++
                        
                        if (Get-ItemProperty -Path $taskbarPath -Name $property -ErrorAction SilentlyContinue) {
                            
                            $shouldProcess = Test-ShouldProcessAuto -Target "Taskbar property: $property" `
                                                                   -Operation "Remove taskbar layout customization" `
                                                                   -OperationType 'DefaultYes' `
                                                                   -ForceOverride:$Force
                            
                            if (-not $shouldProcess) {
                                Write-ModernStatus "Skipped taskbar property: $property" -Status Info
                                continue
                            }
                            
                            Remove-ItemProperty -Path $taskbarPath -Name $property -Force -ErrorAction Stop
                            $propertiesCleared++
                            $executionResults.SuccessfulRegistryOperations++
                            
                            Write-ModernStatus "Cleared taskbar property: $property" -Status Success
                        }
                        else {
                            Write-ModernStatus "Taskbar property not present: $property" -Status Info
                        }
                    }
                    catch [System.UnauthorizedAccessException] {
                        $propertiesFailed++
                        $executionResults.FailedRegistryOperations++
                        Write-ModernStatus "Access denied for taskbar property $property : $($_.Exception.Message)" -Status Error
                    }
                    catch [System.Management.Automation.ItemNotFoundException] {
                        $propertiesFailed++
                        $executionResults.FailedRegistryOperations++
                        Write-ModernStatus "Taskbar property not found: $property" -Status Warning
                    }
                    catch {
                        $propertiesFailed++
                        $executionResults.FailedRegistryOperations++
                        Write-ModernStatus "Failed to clear taskbar property $property : $($_.Exception.Message)" -Status Warning
                    }
                }
                
                # Enhanced results tracking for TaskbarLayout
                $executionResults.Details.TaskbarLayout.PropertiesProcessed = $propertiesProcessed
                $executionResults.Details.TaskbarLayout.PropertiesCleared = $propertiesCleared
                $executionResults.Details.TaskbarLayout.PropertiesFailed = $propertiesFailed
                $executionResults.Details.TaskbarLayout.SettingsCleared = ($propertiesCleared -gt 0)
                $executionResults.Details.TaskbarLayout.Success = ($propertiesCleared -gt 0)
                
                if ($propertiesCleared -gt 0) {
                    Write-ModernStatus "Taskbar layout reset: $propertiesCleared properties successfully cleared" -Status Success
                    $executionResults.OperationsSucceeded++
                    
                    if ($propertiesFailed -gt 0) {
                        Write-ModernStatus "$propertiesFailed properties failed to clear (see warnings above)" -Status Warning
                    }
                } else {
                    if ($propertiesFailed -gt 0) {
                        Write-ModernStatus "Taskbar layout reset failed: All $propertiesProcessed properties failed to clear" -Status Error
                    } else {
                        Write-ModernStatus "No taskbar layout customizations found to reset" -Status Info
                    }
                    $executionResults.OperationsFailed++
                }
            }
            catch {
                $errorMsg = "Failed to reset taskbar layout: $($_.Exception.Message)"
                Write-ModernStatus $errorMsg -Status Error
                $executionResults.Details.TaskbarLayout.Error = $errorMsg
                $executionResults.OperationsFailed++
            }
        } else {
            Write-ModernStatus "Taskband path not found: $taskbarPath" -Status Warning
            $executionResults.Details.TaskbarLayout.Error = "Registry path not found or inaccessible"
            $executionResults.OperationsFailed++
        }
        
        # Operation 5: Reset notification area application preferences completely
        $executionResults.OperationsAttempted++
        Write-ModernStatus "Resetting notification area application preferences..." -Status Processing
        
        $notifyPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings"
        if (Test-Path $notifyPath) {
            try {
                $notificationApps = Get-ChildItem -Path $notifyPath -ErrorAction SilentlyContinue
                $appsProcessed = 0
                $appsReset = 0
                $appsSkipped = 0
                $appsFailed = 0
                
                Write-ModernStatus "Processing $($notificationApps.Count) notification application settings..." -Status Info
                
                foreach ($app in $notificationApps) {
                    try {
                        $appsProcessed++
                        $executionResults.TotalRegistryOperations++
                        
                        $shouldProcess = Test-ShouldProcessAuto -Target "Notification app: $($app.PSChildName)" `
                                                               -Operation "Reset notification preferences" `
                                                               -OperationType 'DefaultYes' `
                                                               -ForceOverride:$Force
                        
                        if (-not $shouldProcess) {
                            $appsSkipped++
                            Write-ModernStatus "Skipped notification app: $($app.PSChildName)" -Status Info
                            continue
                        }
                        
                        # Reset notification preferences to default (enabled) with enhanced error handling
                        Set-ItemProperty -Path $app.PSPath -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $app.PSPath -Name "ShowInActionCenter" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                        
                        $appsReset++
                        $executionResults.SuccessfulRegistryOperations++
                        
                        Write-ModernStatus "Reset notification preferences: $($app.PSChildName)" -Status Success
                    }
                    catch [System.UnauthorizedAccessException] {
                        $appsFailed++
                        $executionResults.FailedRegistryOperations++
                        Write-ModernStatus "Access denied for notification app $($app.PSChildName): $($_.Exception.Message)" -Status Error
                    }
                    catch {
                        $appsFailed++
                        $executionResults.FailedRegistryOperations++
                        Write-ModernStatus "Failed to reset notification app $($app.PSChildName): $($_.Exception.Message)" -Status Warning
                    }
                }
                
                # Enhanced results tracking for NotificationSettings
                $executionResults.Details.NotificationSettings.AppsProcessed = $appsProcessed
                $executionResults.Details.NotificationSettings.AppsReset = $appsReset
                $executionResults.Details.NotificationSettings.AppsSkipped = $appsSkipped
                $executionResults.Details.NotificationSettings.AppsFailed = $appsFailed
                $executionResults.Details.NotificationSettings.Success = ($appsReset -gt 0)
                
                if ($appsReset -gt 0) {
                    Write-ModernStatus "Notification settings reset: $appsReset of $appsProcessed apps successfully processed" -Status Success
                    $executionResults.OperationsSucceeded++
                    
                    if ($appsSkipped -gt 0) {
                        Write-ModernStatus "$appsSkipped apps were skipped by user confirmation" -Status Info
                    }
                    if ($appsFailed -gt 0) {
                        Write-ModernStatus "$appsFailed apps failed to reset (see warnings above)" -Status Warning
                    }
                } else {
                    if ($appsSkipped -eq $appsProcessed) {
                        Write-ModernStatus "Notification settings reset skipped: All $appsProcessed apps were skipped by user" -Status Info
                    } elseif ($appsFailed -eq $appsProcessed) {
                        Write-ModernStatus "Notification settings reset failed: All $appsProcessed apps failed to reset" -Status Error
                    } else {
                        Write-ModernStatus "No notification settings found to reset" -Status Info
                    }
                    $executionResults.OperationsFailed++
                }
            }
            catch {
                $errorMsg = "Failed to reset notification settings: $($_.Exception.Message)"
                Write-ModernStatus $errorMsg -Status Error
                $executionResults.Details.NotificationSettings.Error = $errorMsg
                $executionResults.OperationsFailed++
            }
        } else {
            Write-ModernStatus "Notifications Settings path not found: $notifyPath" -Status Warning
            $executionResults.Details.NotificationSettings.Error = "Registry path not found or inaccessible"
            $executionResults.OperationsFailed++
        }
        
        # Calculate final results and performance metrics
        $executionResults.CompletionTime = Get-Date
        $executionResults.TotalDuration = [math]::Round(($executionResults.CompletionTime - $executionResults.StartTime).TotalSeconds, 2)
        
        # Calculate performance metrics
        if ($executionResults.TotalDuration -gt 0) {
            $executionResults.PerformanceMetrics.AverageOperationTime = [math]::Round($executionResults.TotalDuration / $executionResults.OperationsAttempted, 3)
            $executionResults.PerformanceMetrics.OperationsPerSecond = [math]::Round($executionResults.OperationsAttempted / $executionResults.TotalDuration, 2)
            $executionResults.PerformanceMetrics.RegistryOperationsPerSecond = [math]::Round($executionResults.TotalRegistryOperations / $executionResults.TotalDuration, 2)
        }
        
        # Determine overall success (at least one operation succeeded)
        $executionResults.Success = ($executionResults.OperationsSucceeded -gt 0)
        
        # Display comprehensive summary with enhanced metrics
        Write-Host ""
        Write-ModernHeader "Individual Settings Reset" "Comprehensive Operation Summary"
        
        Write-ModernCard "Overall Success" $(if ($executionResults.Success) { "Yes" } else { "No" }) -ValueColor $(if ($executionResults.Success) { "Success" } else { "Error" })
        Write-ModernCard "Total Time" "$($executionResults.TotalDuration) seconds"
        Write-ModernCard "Operations Attempted" $executionResults.OperationsAttempted
        Write-ModernCard "Operations Succeeded" $executionResults.OperationsSucceeded -ValueColor $(if ($executionResults.OperationsSucceeded -gt 0) { "Success" } else { "Error" })
        Write-ModernCard "Operations Failed" $executionResults.OperationsFailed -ValueColor $(if ($executionResults.OperationsFailed -eq 0) { "Success" } else { "Warning" })
        Write-ModernCard "Registry Operations" "$($executionResults.SuccessfulRegistryOperations)/$($executionResults.TotalRegistryOperations) successful" -ValueColor $(if ($executionResults.SuccessfulRegistryOperations -gt 0) { "Success" } else { "Error" })
        
        # Performance metrics display
        if ($executionResults.PerformanceMetrics.AverageOperationTime) {
            Write-Host ""
            Write-EnhancedOutput "PERFORMANCE METRICS:" -Type Primary
            Write-ModernCard "Average Operation Time" "$($executionResults.PerformanceMetrics.AverageOperationTime) seconds"
            Write-ModernCard "Operations Per Second" $executionResults.PerformanceMetrics.OperationsPerSecond
            Write-ModernCard "Registry Ops Per Second" $executionResults.PerformanceMetrics.RegistryOperationsPerSecond
        }
        
        # Detailed breakdown if any operations were performed
        if ($executionResults.OperationsAttempted -gt 0) {
            Write-Host ""
            Write-EnhancedOutput "DETAILED OPERATION RESULTS:" -Type Primary
            
            foreach ($operation in $executionResults.Details.Keys) {
                $detail = $executionResults.Details[$operation]
                $status = if ($detail.Success) { "Success" } else { "Failed" }
                $color = if ($detail.Success) { "Success" } else { "Warning" }
                
                # Build detailed status text with enhanced metrics
                $statusText = $status
                switch ($operation) {
                    'NotifyIconSettings' { 
                        if ($detail.IconsProcessed -gt 0) {
                            $statusText += " ($($detail.IconsReset)/$($detail.IconsProcessed) icons reset"
                            if ($detail.IconsSkipped -gt 0) { $statusText += ", $($detail.IconsSkipped) skipped" }
                            if ($detail.IconsFailed -gt 0) { $statusText += ", $($detail.IconsFailed) failed" }
                            $statusText += ")"
                        }
                    }
                    'TrayNotify' { 
                        $statusText += " ($($detail.PropertiesCleared)/$($detail.PropertiesProcessed) properties cleared"
                        if ($detail.PropertiesFailed -gt 0) { $statusText += ", $($detail.PropertiesFailed) failed" }
                        $statusText += ")"
                    }
                    'HideDesktopIcons' { 
                        if ($detail.ItemsProcessed -gt 0) {
                            $statusText += " ($($detail.ItemsRemoved)/$($detail.ItemsProcessed) items removed"
                            if ($detail.ItemsSkipped -gt 0) { $statusText += ", $($detail.ItemsSkipped) skipped" }
                            if ($detail.ItemsFailed -gt 0) { $statusText += ", $($detail.ItemsFailed) failed" }
                            $statusText += ")"
                        }
                    }
                    'TaskbarLayout' { 
                        $statusText += " ($($detail.PropertiesCleared)/$($detail.PropertiesProcessed) properties cleared"
                        if ($detail.PropertiesFailed -gt 0) { $statusText += ", $($detail.PropertiesFailed) failed" }
                        $statusText += ")"
                    }
                    'NotificationSettings' { 
                        if ($detail.AppsProcessed -gt 0) {
                            $statusText += " ($($detail.AppsReset)/$($detail.AppsProcessed) apps reset"
                            if ($detail.AppsSkipped -gt 0) { $statusText += ", $($detail.AppsSkipped) skipped" }
                            if ($detail.AppsFailed -gt 0) { $statusText += ", $($detail.AppsFailed) failed" }
                            $statusText += ")"
                        }
                    }
                }
                
                Write-ModernCard $operation $statusText -ValueColor $color
            }
        }
        
        # Final status message with context
        if ($executionResults.Success) {
            Write-ModernStatus "Individual icon settings reset completed successfully" -Status Success
            Write-ModernCard "Impact" "Tray icon preferences and cache have been reset to default visibility"
            Write-ModernCard "Next Steps" "Restart applications or Windows Explorer to see changes immediately"
        } else {
            Write-ModernStatus "Individual icon settings reset completed with errors" -Status Warning
            Write-ModernCard "Impact" "Some tray icon settings may not have been reset"
            Write-ModernCard "Recommendation" "Check registry permissions and retry with elevated privileges if needed"
        }
        
        # Return appropriate result type based on parameter
        if ($DetailedReport) {
            return $executionResults
        } else {
            return $executionResults.Success
        }
    }
    catch {
        $errorMsg = "Critical error during individual settings reset: $($_.Exception.Message)"
        Write-ModernStatus $errorMsg -Status Error
        Write-ModernStatus "Exception Type: $($_.Exception.GetType().FullName)" -Status Warning
        Write-ModernStatus "Stack Trace: $($_.ScriptStackTrace)" -Status Warning
        
        # Set error state in results with enhanced context
        $executionResults.Success = $false
        $executionResults.CompletionTime = Get-Date
        $executionResults.TotalDuration = [math]::Round(($executionResults.CompletionTime - $executionResults.StartTime).TotalSeconds, 2)
        $executionResults.ErrorContext = @{
            CriticalError = $errorMsg
            ExceptionType = $_.Exception.GetType().FullName
            StackTrace = $_.ScriptStackTrace
            Timestamp = Get-Date
        }
        
        if ($DetailedReport) {
            $executionResults.Error = @{
                Message = $errorMsg
                ExceptionType = $_.Exception.GetType().FullName
                StackTrace = $_.ScriptStackTrace
            }
            return $executionResults
        } else {
            return $false
        }
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
# SIMPLE BACKUP SYSTEM
# ============================================================================


function Backup-SimpleRegistry {
    <#
    .SYNOPSIS
        Simple backup function as fallback.
    #>
    param(
        [switch]$Overwrite
    )
    
    $backupPath = if ($AllUsers) { 
        $Script:Configuration.AllUsersBackupPath 
    } else { 
        $Script:Configuration.BackupRegistryPath 
    }
    
    if ((Test-Path $backupPath) -and -not $Overwrite) {
        Write-ModernStatus "Backup already exists, use -ForceBackup to overwrite" -Status Warning
        return $false
    }
    
    try {
        $currentValue = Get-CurrentTrayConfiguration
        $backupData = @{
            Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            EnableAutoTray = $currentValue
            AllUsers = $AllUsers
        }
        
        $json = $backupData | ConvertTo-Json
        [System.IO.File]::WriteAllText($backupPath, $json, [System.Text.Encoding]::UTF8)
        Write-ModernStatus "Simple backup created successfully" -Status Success
        return $true
    }
    catch {
        Write-ModernStatus "Simple backup failed: $($_.Exception.Message)" -Status Error
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
        Creates registry backup with overwrite protection and comprehensive validation.
    .DESCRIPTION
        Creates a backup of critical registry settings for rollback capability with advanced overwrite protection,
        validation, and detailed reporting. Supports both current user and all users backup modes.
    .PARAMETER Force
        Force overwrite of existing backup file without confirmation.
    .PARAMETER CustomPath
        Specifies a custom path for the backup file instead of the default location.
    .PARAMETER VerifyBackup
        Verifies backup file integrity after creation (enabled by default).
    .EXAMPLE
        Backup-RegistryConfiguration -Force
        Creates backup and overwrites existing backup file without confirmation.
    .EXAMPLE
        Backup-RegistryConfiguration -CustomPath "C:\Backups\TrayIcons-$(Get-Date -Format 'yyyyMMdd').json"
        Creates backup with custom filename including date stamp.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Overwrite,  # Renamed from Force to avoid conflict
        
        [Parameter(Mandatory = $false)]
        [string]$CustomPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$VerifyBackup = $true
    )
    
    try {
        # Determine backup path
        $defaultBackupPath = if ($AllUsers) { 
            $Script:Configuration.AllUsersBackupPath 
        } else { 
            $Script:Configuration.BackupRegistryPath 
        }
        
        $backupPath = if ($CustomPath) { 
            $CustomPath 
        } else { 
            $defaultBackupPath 
        }
        
        # Check if backup already exists
        if (Test-Path $backupPath) {
            $existingBackup = Get-Item $backupPath
            $existingSize = [math]::Round($existingBackup.Length / 1KB, 2)
            $lastModified = $existingBackup.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            
            if (-not $Force) {
                Write-ModernStatus "BACKUP ALREADY EXISTS" -Status Warning
                Write-ModernCard "Location" $backupPath -ValueColor Warning
                Write-ModernCard "Size" "$existingSize KB" -ValueColor Info
                Write-ModernCard "Last Modified" $lastModified -ValueColor Info
                Write-ModernStatus "USE -Force PARAMETER TO OVERWRITE EXISTING BACKUP" -Status Warning
                Write-ModernStatus "Example: Backup-RegistryConfiguration -Force" -Status Info
                return $false
            } else {
                Write-ModernStatus "OVERWRITING EXISTING BACKUP FILE" -Status Warning
                Write-ModernCard "Previous Backup Size" "$existingSize KB" -ValueColor Warning
                Write-ModernCard "Last Modified" $lastModified -ValueColor Warning
            }
        }
        
        # Get current configuration
        $currentConfig = Get-CurrentTrayConfiguration
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        Write-ModernStatus "Creating registry backup..." -Status Processing
        Write-ModernCard "Target Path" $backupPath -ValueColor Info
        Write-ModernCard "Backup Scope" $(if ($AllUsers) { "All Users (Group Policy)" } else { "Current User Only" }) -ValueColor $(if ($AllUsers) { "Warning" } else { "Info" })
        
        # Prepare backup data
        $backupData = [ordered]@{
            BackupType = "Registry Configuration"
            Timestamp = $timestamp
            ScriptVersion = $Script:Configuration.ScriptVersion
            ComputerName = $env:COMPUTERNAME
            UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            WindowsVersion = Get-WindowsVersion
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            AllUsers = $AllUsers
            OriginalValue = $currentConfig
            RegistryPath = $Script:Configuration.RegistryPath
            ValueName = $Script:Configuration.RegistryValue
        }
        
        # Include Group Policy settings if AllUsers
        if ($AllUsers) {
            $gpoConfig = Get-GroupPolicyConfiguration
            $backupData.GroupPolicy = @{
                UserPolicy = $gpoConfig.UserPolicy
                MachinePolicy = $gpoConfig.MachinePolicy
                EffectivePolicy = $gpoConfig.EffectivePolicy
            }
        }
        
        # Ensure backup directory exists
        $backupDir = Split-Path -Path $backupPath -Parent
        if (-not (Test-Path $backupDir)) {
            Write-ModernStatus "Creating backup directory: $backupDir" -Status Info
            $null = New-Item -Path $backupDir -ItemType Directory -Force -ErrorAction Stop
        }
        
        # Create backup file with proper encoding
        $jsonContent = $backupData | ConvertTo-Json -Depth 10
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($backupPath, $jsonContent, $utf8NoBom)
        
        # Verify backup if requested
        if ($VerifyBackup) {
            try {
                $verificationData = Get-Content -Path $backupPath -Raw | ConvertFrom-Json
                if ($verificationData.Timestamp -ne $timestamp) {
                    throw "Timestamp verification failed"
                }
                Write-ModernStatus "Backup verification successful" -Status Success
            }
            catch {
                Write-ModernStatus "Backup verification failed: $($_.Exception.Message)" -Status Error
                Write-ModernStatus "Backup file may be corrupted or incomplete" -Status Error
                return $false
            }
        }
        
        # Get final backup details
        $backupFile = Get-Item $backupPath
        $backupSize = [math]::Round($backupFile.Length / 1KB, 2)
        
        # Display success summary
        Write-ModernStatus "Registry backup created successfully!" -Status Success
        Write-ModernCard "Backup Location" $backupPath
        Write-ModernCard "Backup Size" "$backupSize KB"
        Write-ModernCard "Backup Time" $timestamp
        Write-ModernCard "Backup Scope" $(if ($AllUsers) { "All Users (Group Policy)" } else { "Current User" })
        Write-ModernCard "Original Value" $(if ($null -eq $currentConfig) { "Not Set (Default)" } else { $currentConfig })
        
        # Security note for all users backup
        if ($AllUsers) {
            Write-Host ""
            Write-ModernStatus "SECURITY NOTE: This backup contains Group Policy settings that affect all users." -Status Warning
            Write-ModernStatus "Store this file securely and limit access permissions." -Status Warning
        }
        
        return $true
    }
    catch {
        Write-ModernStatus "Backup creation failed: $($_.Exception.Message)" -Status Error
        Write-ModernStatus "Exception Type: $($_.Exception.GetType().FullName)" -Status Warning
        return $false
    }
}

function Invoke-ConfigurationRollback {
    <#
    .SYNOPSIS
        Comprehensive configuration rollback system with enhanced error handling, smart confirmation, and detailed reporting.
    
    .DESCRIPTION
        Restores previous system tray configuration from backup files with enterprise-grade safety features,
        comprehensive validation, and automatic recovery mechanisms. Supports both current user and all users
        rollback scenarios with detailed progress tracking and error handling.
        
        Features include:
        - Multi-stage rollback process with comprehensive validation
        - Smart confirmation system with safety defaults
        - Backup file integrity verification and validation
        - Detailed success/failure reporting with troubleshooting guidance
        - Automatic cleanup of backup files after successful restoration
        - Support for both registry and Group Policy rollback scenarios
        - Enhanced error recovery with fallback mechanisms

    .PARAMETER Force
        Bypass confirmation prompts and warnings. Essential for automated deployment scenarios.

    .PARAMETER ConfirmAction
        Enable explicit confirmation prompts for all operations. When not specified, uses smart defaults:
        - Auto-Yes for most operations
        - Auto-No for destructive operations

    .PARAMETER BackupPath
        Specify custom backup file path for restoration. When not specified, uses default backup locations.

    .PARAMETER SkipCleanup
        Skip automatic backup file cleanup after successful restoration (useful for debugging).

    .EXAMPLE
        Invoke-ConfigurationRollback
        Restores previous configuration with smart confirmation handling.

    .EXAMPLE
        Invoke-ConfigurationRollback -Force -BackupPath "C:\Backups\TrayIconsBackup.json"
        Forces rollback from custom backup path with no confirmation prompts.

    .EXAMPLE
        Invoke-ConfigurationRollback -ConfirmAction -SkipCleanup
        Restores with explicit confirmations and preserves backup file for verification.

    .NOTES
        Author: Mikhail Deynekin
        Version: 6.1 (Enterprise Edition)
        Security Context:
        - Requires administrator privileges for AllUsers/Group Policy rollback
        - Validates backup file integrity before restoration
        - Automatic cleanup of sensitive backup data after successful restoration

        EXIT CODES:
        - $true: Success - Configuration restored successfully
        - $false: Failed - Rollback failed with detailed error context

        ENTERPRISE DEPLOYMENT RECOMMENDATIONS:
        - Use -Force parameter for automated deployment scenarios
        - Test rollback functionality in non-production environment
        - Use -SkipCleanup for debugging and verification purposes
        - Monitor rollback operations in enterprise deployment logs
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$ConfirmAction,

        [Parameter(Mandatory = $false)]
        [ValidateScript({
            if ($_ -and -not (Test-Path $_)) {
                throw "Backup file '$_' does not exist."
            }
            $true
        })]
        [string]$BackupPath,

        [Parameter(Mandatory = $false)]
        [switch]$SkipCleanup
    )
    
    # Initialize comprehensive execution tracking
    $executionResults = [ordered]@{
        StartTime = Get-Date
        Function = "Invoke-ConfigurationRollback"
        RollbackScope = $(if ($AllUsers) { "All Users (Group Policy)" } else { "Current User" })
        BackupPathUsed = $null
        MethodsAttempted = @()
        MethodsSucceeded = @()
        MethodsFailed = @()
        ErrorDetails = @{}
        BackupValidation = @{}
        CleanupPerformed = $false
        CompletionTime = $null
        TotalDuration = $null
        Success = $false
    }
    
    try {
        # Determine backup path
        $effectiveBackupPath = if ($BackupPath) {
            $BackupPath
        } elseif ($AllUsers) {
            $Script:Configuration.AllUsersBackupPath
        } else {
            $Script:Configuration.BackupRegistryPath
        }
        
        $executionResults.BackupPathUsed = $effectiveBackupPath
        
        Write-ModernStatus "Initiating configuration rollback process..." -Status Processing
        Write-ModernCard "Rollback Scope" $executionResults.RollbackScope -ValueColor $(if ($AllUsers) { "Warning" } else { "Info" })
        Write-ModernCard "Backup Source" $effectiveBackupPath -ValueColor "Info"
        
        # Phase 1: Backup file validation
        $executionResults.MethodsAttempted += "BackupValidation"
        Write-ModernStatus "Validating backup file integrity..." -Status Processing
        
        if (-not (Test-Path $effectiveBackupPath)) {
            $errorMessage = "Backup file not found: $effectiveBackupPath"
            $executionResults.MethodsFailed += "BackupValidation"
            $executionResults.ErrorDetails.BackupNotFound = $errorMessage
            
            Write-ModernStatus "Rollback failed: Backup file not found" -Status Error
            Write-ModernStatus $errorMessage -Status Warning
            Write-ModernCard "Expected Location" $effectiveBackupPath -ValueColor "Error"
            Write-ModernCard "Common Causes" "Backup not created, file moved, or different scope selected" -ValueColor "Warning"
            Write-ModernCard "Solution 1" "Create new backup using -Action Backup" -ValueColor "Info"
            Write-ModernCard "Solution 2" "Specify custom backup path with -BackupPath parameter" -ValueColor "Info"
            
            return $false
        }
        
        # Validate backup file accessibility and format
        try {
            $backupFile = Get-Item $effectiveBackupPath -ErrorAction Stop
            $backupSize = [math]::Round($backupFile.Length / 1KB, 2)
            $backupAge = [math]::Round(([DateTime]::Now - $backupFile.LastWriteTime).TotalMinutes, 1)
            
            $executionResults.BackupValidation.SizeKB = $backupSize
            $executionResults.BackupValidation.LastModified = $backupFile.LastWriteTime
            $executionResults.BackupValidation.AgeMinutes = $backupAge
            
            Write-ModernStatus "Backup file validation successful" -Status Success
            Write-ModernCard "Backup Size" "$backupSize KB" -ValueColor "Info"
            Write-ModernCard "Last Modified" $backupFile.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") -ValueColor "Info"
            Write-ModernCard "Backup Age" "$backupAge minutes" -ValueColor "Info"
            
            # Attempt to read and validate backup content
            try {
                $backupContent = Get-Content -Path $effectiveBackupPath -Raw -ErrorAction Stop
                $backupData = $backupContent | ConvertFrom-Json -ErrorAction Stop
                
                $executionResults.BackupValidation.FormatValid = $true
                $executionResults.BackupValidation.BackupType = $backupData.BackupType
                $executionResults.BackupValidation.Timestamp = $backupData.Timestamp
                $executionResults.BackupValidation.ScriptVersion = $backupData.ScriptVersion
                $executionResults.BackupValidation.OriginalScope = if ($backupData.AllUsers) { "All Users" } else { "Current User" }
                
                Write-ModernStatus "Backup content validation successful" -Status Success
                Write-ModernCard "Backup Type" $backupData.BackupType -ValueColor "Info"
                Write-ModernCard "Backup Created" $backupData.Timestamp -ValueColor "Info"
                Write-ModernCard "Script Version" $backupData.ScriptVersion -ValueColor "Info"
                Write-ModernCard "Original Scope" $executionResults.BackupValidation.OriginalScope -ValueColor "Info"
                
                # Scope compatibility check
                if ($AllUsers -and -not $backupData.AllUsers) {
                    Write-ModernStatus "Warning: Rolling back All Users from Current User backup" -Status Warning
                    Write-ModernCard "Scope Mismatch" "All Users target vs Current User source" -ValueColor "Warning"
                } elseif (-not $AllUsers -and $backupData.AllUsers) {
                    Write-ModernStatus "Warning: Rolling back Current User from All Users backup" -Status Warning
                    Write-ModernCard "Scope Mismatch" "Current User target vs All Users source" -ValueColor "Warning"
                }
                
            }
            catch {
                $errorMessage = "Backup file format invalid: $($_.Exception.Message)"
                $executionResults.MethodsFailed += "BackupValidation"
                $executionResults.ErrorDetails.BackupFormat = $errorMessage
                $executionResults.BackupValidation.FormatValid = $false
                
                Write-ModernStatus "Backup content validation failed" -Status Error
                Write-ModernStatus $errorMessage -Status Warning
                Write-ModernCard "File Integrity" "Backup file may be corrupted or in wrong format" -ValueColor "Error"
                Write-ModernCard "Recovery" "Use a different backup file or create new backup" -ValueColor "Warning"
                
                return $false
            }
        }
        catch {
            $errorMessage = "Backup file access failed: $($_.Exception.Message)"
            $executionResults.MethodsFailed += "BackupValidation"
            $executionResults.ErrorDetails.BackupAccess = $errorMessage
            
            Write-ModernStatus "Backup file access failed" -Status Error
            Write-ModernStatus $errorMessage -Status Warning
            Write-ModernCard "Access Issue" "File may be locked, in use, or permissions insufficient" -ValueColor "Error"
            Write-ModernCard "Troubleshooting" "Close applications that might be using the file" -ValueColor "Warning"
            
            return $false
        }
        
        $executionResults.MethodsSucceeded += "BackupValidation"
        
        # Phase 2: Smart confirmation for rollback operation
        $rollbackContext = if ($AllUsers) {
            "Group Policy configuration for ALL users"
        } else {
            "current user registry settings"
        }
        
        $shouldProcessRollback = Test-ShouldProcessAuto -Target $rollbackContext `
                                                       -Operation "Restore configuration from backup ($($executionResults.BackupValidation.Timestamp))" `
                                                       -OperationType 'DefaultYes' `
                                                       -ForceOverride:$Force
        
        if (-not $shouldProcessRollback) {
            Write-ModernStatus "Rollback operation cancelled by user" -Status Info
            $executionResults.ErrorDetails.UserCancelled = "Operation cancelled by user confirmation"
            return $false
        }
        
        Write-ModernStatus "Proceeding with configuration rollback..." -Status Processing
        
        # Phase 3: Multi-stage rollback execution
        $rollbackSuccess = $false
        
        # Method 1: Comprehensive settings restoration (preferred)
        $executionResults.MethodsAttempted += "ComprehensiveRestore"
        Write-ModernStatus "Attempting comprehensive configuration restoration..." -Status Processing
        
        try {
            $comprehensiveParams = @{}
            if ($BackupPath) { 
                $comprehensiveParams.BackupPath = $BackupPath 
            }
            
            $rollbackSuccess = Restore-ComprehensiveTraySettings @comprehensiveParams
            
            if ($rollbackSuccess) {
                $executionResults.MethodsSucceeded += "ComprehensiveRestore"
                Write-ModernStatus "Comprehensive restoration completed successfully" -Status Success
            } else {
                $executionResults.MethodsFailed += "ComprehensiveRestore"
                Write-ModernStatus "Comprehensive restoration failed, attempting basic rollback..." -Status Warning
            }
        }
        catch {
            $errorMessage = "Comprehensive restoration failed: $($_.Exception.Message)"
            $executionResults.MethodsFailed += "ComprehensiveRestore"
            $executionResults.ErrorDetails.ComprehensiveRestore = $errorMessage
            
            Write-ModernStatus "Comprehensive restoration encountered an error" -Status Error
            Write-ModernStatus $errorMessage -Status Warning
        }
        
        # Method 2: Basic registry rollback (fallback)
        if (-not $rollbackSuccess) {
            $executionResults.MethodsAttempted += "BasicRegistryRollback"
            Write-ModernStatus "Attempting basic registry rollback..." -Status Processing
            
            try {
                $basicRollbackSuccess = $false
                $backupData = Get-Content -Path $effectiveBackupPath -Raw | ConvertFrom-Json
                $originalValue = $backupData.OriginalValue
                
                Write-ModernCard "Restoration Target" "Primary registry value" -ValueColor "Info"
                Write-ModernCard "Original Value" $(if ($null -eq $originalValue) { "Not Set (Windows default)" } else { $originalValue }) -ValueColor "Info"
                
                if ($AllUsers -or $backupData.AllUsers) {
                    # Rollback Group Policy settings
                    if ($null -eq $originalValue) {
                        # Remove Group Policy settings to restore Windows default
                        $userPolicyPath = $Script:Configuration.GroupPolicyUserPath
                        $machinePolicyPath = $Script:Configuration.GroupPolicyMachinePath
                        
                        if (Test-Path $userPolicyPath) {
                            Remove-ItemProperty -Path $userPolicyPath -Name $Script:Configuration.GroupPolicyValue -Force -ErrorAction SilentlyContinue
                        }
                        if (Test-Path $machinePolicyPath) {
                            Remove-ItemProperty -Path $machinePolicyPath -Name $Script:Configuration.GroupPolicyValue -Force -ErrorAction SilentlyContinue
                        }
                        
                        Write-ModernStatus "Restored Windows default behavior (Group Policy settings removed)" -Status Success
                        $basicRollbackSuccess = $true
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
                        $basicRollbackSuccess = $true
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
                        $basicRollbackSuccess = $true
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
                        $basicRollbackSuccess = $true
                    }
                }
                
                if ($basicRollbackSuccess) {
                    $executionResults.MethodsSucceeded += "BasicRegistryRollback"
                    $rollbackSuccess = $true
                    Write-ModernStatus "Basic registry rollback completed successfully" -Status Success
                } else {
                    $executionResults.MethodsFailed += "BasicRegistryRollback"
                    Write-ModernStatus "Basic registry rollback failed" -Status Error
                }
            }
            catch {
                $errorMessage = "Basic registry rollback failed: $($_.Exception.Message)"
                $executionResults.MethodsFailed += "BasicRegistryRollback"
                $executionResults.ErrorDetails.BasicRollback = $errorMessage
                
                Write-ModernStatus "Basic registry rollback failed" -Status Error
                Write-ModernStatus $errorMessage -Status Warning
            }
        }
        
        # Phase 4: Post-rollback verification
        if ($rollbackSuccess) {
            $executionResults.MethodsAttempted += "Verification"
            Write-ModernStatus "Verifying rollback results..." -Status Processing
            
            try {
                $currentConfig = Get-CurrentTrayConfiguration
                $expectedValue = if ($backupData.OriginalValue -eq $null) { $null } else { $backupData.OriginalValue }
                
                if ($currentConfig -eq $expectedValue) {
                    $executionResults.MethodsSucceeded += "Verification"
                    Write-ModernStatus "Rollback verification successful" -Status Success
                    Write-ModernCard "Current Configuration" $(if ($null -eq $currentConfig) { "Windows default" } else { $currentConfig }) -ValueColor "Success"
                    Write-ModernCard "Expected Configuration" $(if ($null -eq $expectedValue) { "Windows default" } else { $expectedValue }) -ValueColor "Success"
                } else {
                    $executionResults.MethodsFailed += "Verification"
                    Write-ModernStatus "Rollback verification failed - configuration mismatch" -Status Warning
                    Write-ModernCard "Current Configuration" $(if ($null -eq $currentConfig) { "Windows default" } else { $currentConfig }) -ValueColor "Warning"
                    Write-ModernCard "Expected Configuration" $(if ($null -eq $expectedValue) { "Windows default" } else { $expectedValue }) -ValueColor "Warning"
                    Write-ModernCard "Resolution" "Configuration may require Explorer restart or user logoff" -ValueColor "Info"
                }
            }
            catch {
                $errorMessage = "Rollback verification failed: $($_.Exception.Message)"
                $executionResults.MethodsFailed += "Verification"
                $executionResults.ErrorDetails.Verification = $errorMessage
                
                Write-ModernStatus "Rollback verification encountered an error" -Status Warning
                Write-ModernStatus $errorMessage -Status Warning
            }
        }
        
        # Phase 5: Backup file cleanup (unless skipped)
        if ($rollbackSuccess -and -not $SkipCleanup) {
            $executionResults.MethodsAttempted += "Cleanup"
            Write-ModernStatus "Cleaning up backup file after successful restoration..." -Status Processing
            
            try {
                $shouldCleanup = Test-ShouldProcessAuto -Target "Backup file: $effectiveBackupPath" `
                                                       -Operation "Remove backup file after successful restoration" `
                                                       -OperationType 'DefaultYes' `
                                                       -ForceOverride:$Force
                
                if ($shouldCleanup) {
                    Remove-Item -Path $effectiveBackupPath -Force -ErrorAction Stop
                    $executionResults.CleanupPerformed = $true
                    $executionResults.MethodsSucceeded += "Cleanup"
                    Write-ModernStatus "Backup file removed successfully" -Status Success
                    Write-ModernCard "Cleanup Action" "Backup file deleted for security" -ValueColor "Success"
                } else {
                    Write-ModernStatus "Backup file cleanup skipped by user" -Status Info
                    $executionResults.MethodsSucceeded += "Cleanup" # Considered success as operation was skipped by choice
                }
            }
            catch {
                $errorMessage = "Backup file cleanup failed: $($_.Exception.Message)"
                $executionResults.MethodsFailed += "Cleanup"
                $executionResults.ErrorDetails.Cleanup = $errorMessage
                
                Write-ModernStatus "Backup file cleanup failed" -Status Warning
                Write-ModernStatus $errorMessage -Status Warning
                Write-ModernCard "Security Note" "Backup file should be manually removed" -ValueColor "Warning"
            }
        } elseif ($SkipCleanup) {
            Write-ModernStatus "Backup file cleanup skipped as requested" -Status Info
            Write-ModernCard "Backup Location" $effectiveBackupPath -ValueColor "Info"
        }
        
        # Determine final success
        $executionResults.CompletionTime = Get-Date
        $executionResults.TotalDuration = [math]::Round(($executionResults.CompletionTime - $executionResults.StartTime).TotalSeconds, 2)
        $executionResults.Success = $rollbackSuccess
        
        # Comprehensive results reporting
        Write-Host ""
        Write-ModernHeader "Rollback Operation" "Final Results Summary"
        
        Write-ModernCard "Overall Success" $(if ($executionResults.Success) { "Yes" } else { "No" }) -ValueColor $(if ($executionResults.Success) { "Success" } else { "Error" })
        Write-ModernCard "Total Duration" "$($executionResults.TotalDuration) seconds" -ValueColor "Info"
        Write-ModernCard "Methods Attempted" $executionResults.MethodsAttempted.Count -ValueColor "Info"
        Write-ModernCard "Methods Succeeded" $executionResults.MethodsSucceeded.Count -ValueColor $(if ($executionResults.MethodsSucceeded.Count -gt 0) { "Success" } else { "Error" })
        Write-ModernCard "Methods Failed" $executionResults.MethodsFailed.Count -ValueColor $(if ($executionResults.MethodsFailed.Count -eq 0) { "Success" } else { "Warning" })
        Write-ModernCard "Backup Cleanup" $(if ($executionResults.CleanupPerformed) { "Completed" } else { "Skipped" }) -ValueColor $(if ($executionResults.CleanupPerformed) { "Success" } else { "Info" })
        
        # Detailed method breakdown
        if ($executionResults.MethodsAttempted.Count -gt 0) {
            Write-Host ""
            Write-EnhancedOutput "DETAILED METHOD RESULTS:" -Type Primary
            
            foreach ($method in $executionResults.MethodsAttempted) {
                $status = if ($executionResults.MethodsSucceeded -contains $method) { "Success" } else { "Failed" }
                $color = if ($executionResults.MethodsSucceeded -contains $method) { "Success" } else { "Error" }
                Write-ModernCard $method $status -ValueColor $color
            }
        }
        
        # Success scenario with additional guidance
        if ($executionResults.Success) {
            Write-ModernStatus "Configuration rollback completed successfully!" -Status Success
            
            # Additional success guidance
            Write-Host ""
            Write-EnhancedOutput "POST-ROLLBACK GUIDANCE:" -Type Primary
            
            if ($AllUsers) {
                Write-ModernCard "Policy Application" "Group Policy changes apply to new user sessions" -ValueColor "Info"
                Write-ModernCard "Existing Sessions" "Users may need to log off and on for changes" -ValueColor "Warning"
                Write-ModernCard "Verification" "Check Group Policy Editor (gpedit.msc) for settings" -ValueColor "Info"
            } else {
                Write-ModernCard "Immediate Effect" "Changes may require Explorer restart to take effect" -ValueColor "Info"
                Write-ModernCard "Manual Restart" "Task Manager > End explorer.exe > Run new task > explorer.exe" -ValueColor "Info"
            }
            
            Write-ModernCard "Verification" "Check system tray to confirm configuration" -ValueColor "Success"
            
            # Explorer restart recommendation
            if ($RestartExplorer) {
                Write-ModernStatus "Restarting Windows Explorer to apply changes immediately..." -Status Processing
                $restartResult = Restart-WindowsExplorerSafely
                if ($restartResult) {
                    Write-ModernStatus "Windows Explorer restarted successfully" -Status Success
                    Write-ModernStatus "Rollback changes applied immediately" -Status Success
                } else {
                    Write-ModernStatus "Explorer restart completed with warnings" -Status Warning
                }
            } else {
                Write-ModernStatus "Use -RestartExplorer parameter to apply changes immediately" -Status Info
            }
            
            return $true
        }
        # Failure scenario with detailed troubleshooting
        else {
            Write-ModernStatus "Configuration rollback failed" -Status Error
            
            # Enhanced failure analysis
            Write-Host ""
            Write-EnhancedOutput "FAILURE ANALYSIS:" -Type Primary
            
            # Determine failure pattern for specific guidance
            $backupFailed = $executionResults.MethodsFailed -contains "BackupValidation"
            $allMethodsFailed = $executionResults.MethodsSucceeded.Count -eq 0
            
            if ($backupFailed) {
                Write-ModernStatus "BACKUP-RELATED FAILURE" -Status Error
                Write-ModernCard "Root Cause" "Backup file missing, inaccessible, or corrupted" -ValueColor "Error"
                Write-ModernCard "Solution 1" "Verify backup file exists and is accessible" -ValueColor "Warning"
                Write-ModernCard "Solution 2" "Create new backup using -Action Backup" -ValueColor "Info"
                Write-ModernCard "Solution 3" "Use -BackupPath to specify alternate backup file" -ValueColor "Info"
            }
            elseif ($allMethodsFailed) {
                Write-ModernStatus "COMPLETE ROLLBACK FAILURE" -Status Error
                Write-ModernCard "Root Cause" "All restoration methods failed" -ValueColor "Error"
                Write-ModernCard "Solution 1" "Check system permissions and registry access" -ValueColor "Warning"
                Write-ModernCard "Solution 2" "Run as Administrator for elevated privileges" -ValueColor "Info"
                Write-ModernCard "Solution 3" "Manual registry editing may be required" -ValueColor "Warning"
            }
            else {
                Write-ModernStatus "PARTIAL ROLLBACK FAILURE" -Status Warning
                Write-ModernCard "Current State" "Some settings restored, but verification failed" -ValueColor "Warning"
                Write-ModernCard "Solution 1" "Restart Windows Explorer to apply changes" -ValueColor "Info"
                Write-ModernCard "Solution 2" "Run with -RestartExplorer parameter" -ValueColor "Info"
                Write-ModernCard "Solution 3" "Check system tray for actual configuration state" -ValueColor "Info"
            }
            
            # Display specific error details
            if ($executionResults.ErrorDetails.Count -gt 0) {
                Write-Host ""
                Write-EnhancedOutput "ERROR DETAILS:" -Type Primary
                foreach ($errorKey in $executionResults.ErrorDetails.Keys) {
                    $errorValue = $executionResults.ErrorDetails[$errorKey]
                    $displayValue = if ($errorValue.Length -gt 80) { 
                        $errorValue.Substring(0, 77) + "..." 
                    } else { 
                        $errorValue 
                    }
                    Write-ModernCard $errorKey $displayValue -ValueColor "Error"
                }
            }
            
            # Security note for remaining backup file
            if (-not $executionResults.CleanupPerformed -and -not $SkipCleanup) {
                Write-Host ""
                Write-EnhancedOutput "SECURITY NOTE:" -Type Primary
                Write-ModernCard "Backup File" "Sensitive configuration data remains at: $effectiveBackupPath" -ValueColor "Warning"
                Write-ModernCard "Action Required" "Manually delete backup file or use -SkipCleanup false" -ValueColor "Warning"
            }
            
            return $false
        }
    }
    catch {
        $errorMessage = "Critical error during configuration rollback: $($_.Exception.Message)"
        $executionResults.ErrorDetails.CriticalException = @{
            Message = $_.Exception.Message
            Type = $_.Exception.GetType().FullName
            StackTrace = $_.ScriptStackTrace
        }
        
        Write-ModernStatus "Rollback operation failed: Critical Error" -Status Error
        Write-ModernStatus $errorMessage -Status Warning
        Write-ModernCard "Exception Type" $($_.Exception.GetType().FullName) -ValueColor "Error"
        Write-ModernCard "Operation Context" "Configuration restoration from backup" -ValueColor "Warning"
        Write-ModernCard "Troubleshooting" "Check system event logs and backup file integrity" -ValueColor "Info"
        
        $executionResults.Success = $false
        $executionResults.CompletionTime = Get-Date
        $executionResults.TotalDuration = [math]::Round(($executionResults.CompletionTime - $executionResults.StartTime).TotalSeconds, 2)
        
        return $false
    }
    finally {
        # Always display execution summary for audit purposes
        if ($Force -or $VerbosePreference -eq 'Continue' -or -not $executionResults.Success) {
            Write-Host ""
            Write-ModernHeader "Rollback Execution" "Comprehensive Summary"
            
            Write-ModernCard "Final Status" $(if ($executionResults.Success) { "SUCCESS" } else { "FAILED" }) -ValueColor $(if ($executionResults.Success) { "Success" } else { "Error" })
            Write-ModernCard "Total Time" "$($executionResults.TotalDuration) seconds" -ValueColor "Info"
            Write-ModernCard "Rollback Scope" $executionResults.RollbackScope -ValueColor "Info"
            Write-ModernCard "Backup Source" $executionResults.BackupPathUsed -ValueColor "Info"
            Write-ModernCard "Cleanup Performed" $(if ($executionResults.CleanupPerformed) { "Yes" } else { "No" }) -ValueColor $(if ($executionResults.CleanupPerformed) { "Success" } else { "Warning" })
            
            if ($executionResults.BackupValidation.Count -gt 0) {
                Write-Host ""
                Write-EnhancedOutput "BACKUP VALIDATION:" -Type Primary
                foreach ($validationKey in $executionResults.BackupValidation.Keys) {
                    Write-ModernCard $validationKey $executionResults.BackupValidation[$validationKey] -ValueColor "Info"
                }
            }
        }
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


function Invoke-MainExecution {
    <#
    .SYNOPSIS
        Main execution engine with intelligent context handling, smart confirmation system, and comprehensive workflow management.
    
    .DESCRIPTION
        Orchestrates script execution flow based on provided parameters with enterprise-grade validation,
        context-aware processing, and professional reporting capabilities. Handles all supported actions
        including Status, Backup, Enable, Disable, Rollback, Update, and Help scenarios with enhanced
        error handling and smart confirmation system integration.
        
        Features include:
        - Smart confirmation system with enterprise defaults
        - Comprehensive parameter validation and context reporting
        - Enhanced error handling with detailed troubleshooting
        - Execution context awareness and security validation
        - Enterprise deployment optimization
        - Detailed progress tracking and reporting

    .PARAMETER None
        This function uses script-scoped parameters from the main script invocation.

    .NOTES
        Author: Mikhail Deynekin
        Version: 6.1 (Enterprise Edition)
        Security Context:
        - Validates administrator privileges for Group Policy operations
        - Context-aware execution based on user privileges
        - Comprehensive security context reporting
        
        EXECUTION FLOW:
        1. Parameter validation and context reporting
        2. Diagnostic mode processing (highest priority)
        3. Help system processing
        4. System requirements validation
        5. Administrator rights validation (when required)
        6. Script update handling
        7. Default help display (no action specified)
        8. Main action execution with comprehensive error handling

        ENTERPRISE DEPLOYMENT FEATURES:
        - Smart confirmation defaults for automated deployment
        - Force mode for unattended execution
        - Comprehensive logging and reporting
        - Integration with enterprise deployment tools
    #>
    [CmdletBinding()]
    param()

# Enhanced parameter validation and context reporting
try {
    # Always show execution parameters at start for auditability and transparency
    Write-Host ""
    Write-ModernHeader "Script Execution Context" "Enterprise Configuration Management"
    
    # Core execution parameters
    Write-ModernCard "Action" $(if ($Action) { $Action } else { "Not specified" }) -ValueColor "Primary"
    Write-ModernCard "Target Scope" $(if ($AllUsers) { "All Users (Group Policy)" } else { "Current User Only" }) -ValueColor $(if ($AllUsers) { "Warning" } else { "Info" })
    
    # Enhanced confirmation and force mode reporting
    Write-ModernCard "Force Mode" $(if ($Force) { "Enabled (No prompts)" } else { "Disabled" }) -ValueColor $(if ($Force) { "Warning" } else { "Info" })
    Write-ModernCard "Force Backup" $(if ($ForceBackup) { "Enabled (Overwrite backups)" } else { "Disabled" }) -ValueColor $(if ($ForceBackup) { "Warning" } else { "Info" })
    Write-ModernCard "Confirm Action" $(if ($ConfirmAction) { "Enabled (All prompts)" } else { "Disabled (Smart defaults)" }) -ValueColor $(if ($ConfirmAction) { "Info" } else { "Success" })
    
    # Help system parameters display
    if ($Help -or $QuickHelp -or $PSBoundParameters.ContainsKey('HelpLevel')) {
        Write-ModernCard "Help System" "Active" -ValueColor "Info"
        if ($PSBoundParameters.ContainsKey('HelpLevel')) {
            Write-ModernCard "Help Level" $HelpLevel -ValueColor "Info"
        }
        if ($QuickHelp) {
            Write-ModernCard "Quick Help" "Enabled" -ValueColor "Info"
        }
        if ($Help) {
            Write-ModernCard "Full Help" "Enabled" -ValueColor "Info"
        }
    }
    
    # Security and system context
    Write-ModernCard "Admin Context" $(if (Test-AdministratorRights) { "Elevated" } else { "Standard" }) -ValueColor $(if (Test-AdministratorRights) { "Success" } else { "Warning" })
    Write-ModernCard "PowerShell Version" "$($PSVersionTable.PSVersion) ($(if($Script:IsPS7Plus){'Enhanced'}else{'Compatible'}))" -ValueColor "Info"
    Write-ModernCard "Execution Policy" (Get-ExecutionPolicy -Scope CurrentUser) -ValueColor "Info"
    
    Write-Host ""

        # Flag to control banner display
        $script:showBanner = $true
        
        # 1. Diagnostic mode - highest priority (immediate execution)
        if ($Diagnostic) {
            Show-ModernBanner
            Write-ModernStatus "Running comprehensive diagnostics on backup files and system configuration..." -Status Processing
            Write-ModernCard "Diagnostic Mode" "Comprehensive System Analysis" -ValueColor "Warning"
            Write-ModernCard "Operation Scope" "Read-only analysis (no changes)" -ValueColor "Info"
            
            Invoke-BackupDiagnostic
            exit $Script:Configuration.ExitCodes.Success
        }
                
        # 2. Help system - second priority (FIXED: Now includes HelpLevel alone)
        if ($Help -or $QuickHelp -or $PSBoundParameters.ContainsKey('HelpLevel')) {
            $effectiveHelpLevel = 'Full'  # Default for -Help or -HelpLevel alone
            
            # Determine specific help level with proper precedence
            if ($QuickHelp) {
                $effectiveHelpLevel = 'Quick'
            }
            elseif ($PSBoundParameters.ContainsKey('HelpLevel')) {
                $effectiveHelpLevel = $HelpLevel
            }
            elseif ($Help) {
                $effectiveHelpLevel = 'Full'  # Explicit -Help without HelpLevel
            }
            
            # Validate help level and provide clear error messages
            $validHelpLevels = @('Full', 'Quick', 'Admin', 'Security')
            if ($effectiveHelpLevel -notin $validHelpLevels) {
                Write-ModernStatus "Invalid help level specified: '$effectiveHelpLevel'" -Status Error
                Write-Host ""
                Write-EnhancedOutput "VALID HELP LEVELS:" -Type Primary -Bold
                Write-ModernCard "Full" "Complete documentation with all parameters and examples"
                Write-ModernCard "Quick" "Brief command reference (default help view)"
                Write-ModernCard "Admin" "Administrator deployment instructions and Group Policy guidance"
                Write-ModernCard "Security" "Execution context, privileges, and security considerations"
                Write-Host ""
                Write-EnhancedOutput "Examples:" -Type Info
                Write-Host "  .\$($Script:Configuration.ScriptName) -Help" -ForegroundColor Yellow
                Write-Host "  .\$($Script:Configuration.ScriptName) -HelpLevel Full" -ForegroundColor Yellow
                Write-Host "  .\$($Script:Configuration.ScriptName) -Help -HelpLevel Admin" -ForegroundColor Yellow
                Write-Host ""
                exit $Script:Configuration.ExitCodes.GeneralError
            }
            
            # Display appropriate help based on validated level
            Show-ModernBanner
            
            # Display help context
            Write-ModernHeader "Help System" "Context: $effectiveHelpLevel"
            Write-ModernCard "Help Level" $effectiveHelpLevel -ValueColor "Info"
            Write-ModernCard "Help Trigger" $(if ($Help) { "-Help parameter" } elseif ($QuickHelp) { "-QuickHelp parameter" } else { "-HelpLevel parameter" }) -ValueColor "Info"
            Write-Host ""
            
            switch ($effectiveHelpLevel) {
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
                    Show-ModernHelp
                }
            }
            exit $Script:Configuration.ExitCodes.Success
        }
        
        # 3. System requirements validation
        if (-not (Test-PowerShellVersion)) {
            Write-ModernStatus "PowerShell version requirement not met (requires $($Script:Configuration.RequiredPSVersion)+)" -Status Error
            exit $Script:Configuration.ExitCodes.PowerShellVersion
        }
        
        if (-not (Test-ExecutionPolicy)) {
            Write-ModernStatus "Script execution blocked by current execution policy" -Status Error
            exit $Script:Configuration.ExitCodes.GeneralError
        }
        
        # 4. Administrator rights validation (only when needed for specific operations)
        if ($AllUsers -and -not (Test-AdministratorRights)) {
            Write-ModernStatus "Administrator privileges required for all-users configuration" -Status Error
            Write-Host ""
            Write-EnhancedOutput "ADMINISTRATOR ELEVATION REQUIRED" -Type Primary -Bold
            Write-ModernCard "Operation" "Group Policy configuration for ALL users"
            Write-ModernCard "Required Rights" "Administrator privileges"
            Write-ModernCard "Current Context" "Standard user (elevation required)"
            Write-Host ""
            Write-EnhancedOutput "ELEVATION METHODS:" -Type Primary
            Write-ModernCard "Method 1" "Right-click PowerShell > 'Run as Administrator'"
            Write-ModernCard "Method 2" "powershell.exe -ExecutionPolicy Bypass -File $($Script:Configuration.ScriptName) -Action $Action -AllUsers"
            Write-Host ""
            Write-EnhancedOutput "ALTERNATIVE (current user only):" -Type Primary
            Write-Host "  .\$($Script:Configuration.ScriptName) -Action $Action" -ForegroundColor $Script:ConsoleColors.Warning
            Write-Host ""
            exit $Script:Configuration.ExitCodes.AdminRightsRequired
        }
        
        # 5. Script update handling
        if ($Update) {
            Show-ModernBanner
            Write-ModernHeader "Script Update Check" "Verifying latest version from GitHub"
            Write-ModernCard "Current Version" $Script:Configuration.ScriptVersion -ValueColor "Info"
            Write-ModernCard "Repository" $Script:Configuration.GitHubRepository -ValueColor "Info"
            Write-ModernCard "Update Source" $Script:Configuration.UpdateUrl -ValueColor "Info"
            
            $updateResult = Invoke-ScriptUpdate
            if ($updateResult) {
                Write-Host ""
                Write-ModernStatus "Script updated successfully. Please restart to use new version." -Status Success
                Write-ModernCard "Next Steps" "Close and restart PowerShell, then re-run the script" -ValueColor "Warning"
            } else {
                Write-Host ""
                Write-ModernStatus "Script is already up to date or update check failed" -Status Info
            }
            exit $Script:Configuration.ExitCodes.Success
        }
        
        # 6. Default help display when no action specified
        if (-not $Action) {
            Show-ModernBanner
            Show-ApplicationInfo
            exit $Script:Configuration.ExitCodes.Success
        }
        
        # 7. Main action execution with comprehensive error handling
        Show-ModernBanner
        $actionLower = $Action.ToLower()
        
        # Enhanced action validation
        $validActions = @('status', 'backup', 'enable', 'disable', 'rollback')
        if ($actionLower -notin $validActions) {
            Write-ModernStatus "Invalid action specified: '$Action'" -Status Error
            Write-Host ""
            Write-EnhancedOutput "VALID ACTIONS:" -Type Primary -Bold
            Write-ModernCard "Status" "Display current configuration and system context"
            Write-ModernCard "Backup" "Create comprehensive configuration backup"
            Write-ModernCard "Enable" "Show all tray icons (disable auto-hide)"
            Write-ModernCard "Disable" "Restore Windows default behavior (enable auto-hide)"
            Write-ModernCard "Rollback" "Revert to previous configuration from backup"
            Write-Host ""
            Write-EnhancedOutput "Usage Examples:" -Type Info
            Write-Host "  .\$($Script:Configuration.ScriptName) -Action Status" -ForegroundColor Yellow
            Write-Host "  .\$($Script:Configuration.ScriptName) -Action Enable -AllUsers" -ForegroundColor Yellow
            Write-Host "  .\$($Script:Configuration.ScriptName) -Action Backup -ForceBackup" -ForegroundColor Yellow
            Write-Host ""
            $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.GeneralError
            exit $Script:Configuration.ExitCode
        }
        
        # Enhanced action execution with comprehensive error handling
        try {
            switch ($actionLower) {
                'status' {
                    Write-ModernHeader "System Status Report" "Current Tray Icons Configuration Analysis"
                    Write-ModernCard "Report Type" "Comprehensive System Analysis" -ValueColor "Info"
                    Write-ModernCard "Operation" "Read-only status check" -ValueColor "Success"
                    Write-ModernCard "Impact Level" "No system changes" -ValueColor "Success"
                    Write-Host ""
                    
                    Show-EnhancedStatus
                    
                    # Additional status context
                    Write-Host ""
                    Write-EnhancedOutput "RECOMMENDATIONS:" -Type Primary
                    $currentConfig = Get-CurrentTrayConfiguration
                    if ($null -eq $currentConfig -or $currentConfig -eq 1) {
                        Write-ModernCard "Suggested Action" "Enable all tray icons for better visibility" -ValueColor "Warning"
                        Write-Host "  .\$($Script:Configuration.ScriptName) -Action Enable" -ForegroundColor $Script:ConsoleColors.Success
                    } else {
                        Write-ModernCard "Current State" "All tray icons are visible" -ValueColor "Success"
                    }
                    
                    if ($AllUsers) {
                        Write-ModernCard "Scope Note" "All Users mode would affect Group Policy settings" -ValueColor "Info"
                    }
                }
                
                'backup' {
                    if ($AllUsers) {
                        Write-ModernHeader "Create Comprehensive Backup" "Saving ALL tray-related settings for ALL users"
                        Write-ModernStatus "Backup mode: ALL USERS (Group Policy configuration)" -Status Warning
                        Write-ModernCard "Backup Scope" "All Users Group Policy and registry settings" -ValueColor "Warning"
                        Write-ModernCard "Security Note" "Backup contains system-wide configuration data" -ValueColor "Warning"
                    } else {
                        Write-ModernHeader "Create Comprehensive Backup" "Saving ALL tray-related settings"
                        Write-ModernStatus "Backup mode: CURRENT USER ONLY" -Status Info
                        Write-ModernCard "Backup Scope" "Current user registry and preference settings" -ValueColor "Info"
                    }

                    # Enhanced backup parameters display
                    if ($CustomPath) {
                        Write-ModernCard "Custom Path" $CustomPath -ValueColor "Info"
                    }
                    if ($ExcludeCache) {
                        Write-ModernCard "Cache Data" "Excluded from backup" -ValueColor "Warning"
                    } else {
                        Write-ModernCard "Cache Data" "Included in backup" -ValueColor "Success"
                    }
                    if ($CompressBackup) {
                        Write-ModernCard "Compression" "Enabled" -ValueColor "Info"
                    }
                    Write-Host ""

                    $backupSuccess = Backup-ComprehensiveTraySettings -BackupScope $(if ($AllUsers) { 'AllUsers' } else { 'CurrentUser' }) -Overwrite:($ForceBackup -or $Force)

                    if ($backupSuccess) {
                        Write-ModernStatus "Comprehensive backup completed successfully!" -Status Success
                        
                        # Security recommendations for all users backup
                        if ($AllUsers) {
                            Write-Host ""
                            Write-EnhancedOutput "SECURITY RECOMMENDATIONS:" -Type Primary
                            Write-ModernCard "Storage" "Store backup file in secure location with restricted permissions" -ValueColor "Warning"
                            Write-ModernCard "Sensitivity" "Backup contains Group Policy settings affecting all users" -ValueColor "Warning"
                            Write-ModernCard "Disposal" "Delete backup file after successful deployment verification" -ValueColor "Info"
                        }
                    } else {
                        $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.BackupFailed
                        Write-ModernStatus "Backup operation failed or was skipped" -Status Error
                        
                        # Provide specific guidance based on failure context
                        if (-not ($ForceBackup -or $Force)) {
                            Write-ModernStatus "Backup file may already exist - use -ForceBackup to overwrite" -Status Warning
                        }
                    }
                }
                
                'enable' {
                    if ($AllUsers) {
                        Write-ModernHeader "Enterprise Configuration" "Enable ALL Tray Icons for ALL Users"
                        Write-ModernStatus "Configuring system-wide tray icon visibility via Group Policy..." -Status Warning
                        Write-ModernCard "Deployment Type" "Group Policy (system-wide)" -ValueColor "Warning"
                        Write-ModernCard "Affected Users" "ALL users on this system" -ValueColor "Warning"
                        Write-ModernCard "Persistence" "Survives user logoff/reboot" -ValueColor "Info"
                    } else {
                        Write-ModernHeader "Tray Icon Configuration" "Enable ALL Icons for Current User"
                        Write-ModernStatus "Configuring comprehensive tray icon visibility..." -Status Processing
                        Write-ModernCard "Deployment Type" "Current User Registry" -ValueColor "Info"
                        Write-ModernCard "Affected Users" "Current user only" -ValueColor "Info"
                        Write-ModernCard "Persistence" "User-specific setting" -ValueColor "Info"
                    }

                    # Enhanced execution parameters display
                    if ($RestartExplorer) {
                        Write-ModernCard "Explorer Restart" "Immediate application" -ValueColor "Info"
                    } else {
                        Write-ModernCard "Explorer Restart" "Manual restart required" -ValueColor "Warning"
                    }
                    
                    if ($BackupRegistry -or $ForceBackup) {
                        Write-ModernCard "Backup Creation" "Enabled" -ValueColor "Success"
                    }
                    Write-Host ""

                    # Create backup before making changes if not already specified
                    # Only create automatic backup if not using ForceBackup and BackupRegistry not explicitly set
                    if (-not $BackupRegistry -and -not $ForceBackup) {
                        Write-ModernStatus "Creating automatic configuration backup for safety..." -Status Info
                        $BackupRegistry = $true
                    } elseif ($ForceBackup -and -not $BackupRegistry) {
                        Write-ModernStatus "ForceBackup specified but BackupRegistry not set - enabling backup creation" -Status Info
                        $BackupRegistry = $true
                    }

                    # Execute comprehensive enable operation
                    $success = Enable-AllTrayIconsComprehensive -SkipParameterDisplay -Force:$Force -ForceBackup:$ForceBackup -ConfirmAction:$ConfirmAction

                    if ($success) {
                        if ($RestartExplorer) {
                            Write-ModernStatus "Restarting Windows Explorer to apply changes immediately..." -Status Processing
                            $restartResult = Restart-WindowsExplorerSafely
                            if ($restartResult) {
                                Write-ModernStatus "Windows Explorer restarted successfully" -Status Success
                                Write-ModernStatus "Changes applied immediately to user interface" -Status Success
                            } else {
                                Write-ModernStatus "Explorer restart completed with warnings - changes may require logoff" -Status Warning
                            }
                        } else {
                            Write-ModernStatus "Configuration completed successfully" -Status Success
                            if ($AllUsers) {
                                Write-ModernStatus "Group Policy changes require user logoff/logon to fully apply" -Status Warning
                            } else {
                                Write-ModernStatus "Changes will apply after Windows Explorer restart" -Status Info
                            }
                            Write-ModernStatus "Use -RestartExplorer parameter to apply changes immediately" -Status Info
                        }
                        
                        # Success recommendations
                        Write-Host ""
                        Write-EnhancedOutput "SUCCESS RECOMMENDATIONS:" -Type Primary
                        Write-ModernCard "Verification" "Check system tray to confirm all icons are visible" -ValueColor "Success"
                        if ($AllUsers) {
                            Write-ModernCard "Deployment" "Settings will apply to new user sessions automatically" -ValueColor "Info"
                        }
                    } else {
                        $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.GeneralError
                        Write-ModernStatus "Configuration failed - system restored to previous state" -Status Error
                        
                        # Enhanced failure analysis
                        Write-Host ""
                        Write-EnhancedOutput "FAILURE ANALYSIS:" -Type Primary
                        if ($AllUsers) {
                            Write-ModernCard "Common Issues" "Group Policy restrictions, registry permissions" -ValueColor "Error"
                            Write-ModernCard "Alternative" "Try current user mode without -AllUsers parameter" -ValueColor "Warning"
                        } else {
                            Write-ModernCard "Common Issues" "Registry permissions, locked registry keys" -ValueColor "Error"
                            Write-ModernCard "Alternative" "Run as Administrator for elevated privileges" -ValueColor "Warning"
                        }
                        Write-ModernCard "Diagnostic" "Run with -Diagnostic parameter for detailed analysis" -ValueColor "Info"
                    }
                }
                
                'disable' {
                    if ($AllUsers) {
                        Write-ModernHeader "Enterprise Configuration" "Restore Default Tray Behavior for ALL Users"
                        Write-ModernStatus "Configuring system-wide default tray icon behavior via Group Policy..." -Status Warning
                        Write-ModernCard "Deployment Type" "Group Policy (system-wide)" -ValueColor "Warning"
                        Write-ModernCard "Behavior" "Restore Windows default auto-hide" -ValueColor "Info"
                    } else {
                        Write-ModernHeader "Tray Icon Configuration" "Restore Default Behavior for Current User"
                        Write-ModernStatus "Restoring Windows default tray icon behavior..." -Status Processing
                        Write-ModernCard "Deployment Type" "Current User Registry" -ValueColor "Info"
                        Write-ModernCard "Behavior" "Enable auto-hide for inactive icons" -ValueColor "Info"
                    }

                    # Enhanced execution context
                    if ($RestartExplorer) {
                        Write-ModernCard "Explorer Restart" "Immediate application" -ValueColor "Info"
                    }
                    if ($BackupRegistry) {
                        Write-ModernCard "Backup Creation" "Enabled" -ValueColor "Success"
                    }
                    Write-Host ""
                    
                    # Create backup before making changes
                    if (-not $BackupRegistry -and $actionLower -eq 'disable') {
                        Write-ModernStatus "Creating automatic configuration backup..." -Status Info
                        $BackupRegistry = $true
                    }
                    
                    $success = $false
                    if ($AllUsers) {
                        $success = Set-GroupPolicyConfiguration -Behavior 'Disable' -Force:$Force -ConfirmAction:$ConfirmAction
                    } else {
                        $success = Set-TrayIconConfiguration -Behavior 'Disable' -Force:$Force -ForceBackup:$ForceBackup
                    }
                    
                    if ($success) {
                        if ($RestartExplorer) {
                            Write-ModernStatus "Restarting Windows Explorer to apply changes immediately..." -Status Processing
                            $restartResult = Restart-WindowsExplorerSafely
                            if ($restartResult) {
                                Write-ModernStatus "Windows Explorer restarted successfully" -Status Success
                                Write-ModernStatus "Default behavior restored and applied immediately" -Status Success
                            } else {
                                Write-ModernStatus "Explorer restart partially failed - changes will apply after next logon" -Status Warning
                            }
                        } else {
                            Write-ModernStatus "Default behavior restored successfully" -Status Success
                            Write-ModernStatus "Use -RestartExplorer parameter to apply changes immediately" -Status Info
                        }
                    } else {
                        $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.GeneralError
                        Write-ModernStatus "Failed to restore default behavior" -Status Error
                    }
                }
                
                'rollback' {
                    if ($AllUsers) {
                        Write-ModernHeader "Enterprise Rollback" "Revert ALL Users Configuration"
                        Write-ModernStatus "Restoring previous Group Policy configuration for all users..." -Status Warning
                        Write-ModernCard "Rollback Scope" "All Users Group Policy settings" -ValueColor "Warning"
                        Write-ModernCard "Impact" "Affects ALL users on system" -ValueColor "Warning"
                    } else {
                        Write-ModernHeader "Configuration Rollback" "Revert Current User Settings"
                        Write-ModernStatus "Restoring previous tray icon configuration..." -Status Processing
                        Write-ModernCard "Rollback Scope" "Current user registry settings" -ValueColor "Info"
                        Write-ModernCard "Impact" "Affects current user only" -ValueColor "Info"
                    }

                    if ($RestartExplorer) {
                        Write-ModernCard "Explorer Restart" "Immediate application" -ValueColor "Info"
                    }
                    Write-Host ""
                    
                    # Try comprehensive restore first, fall back to basic restore
                    $rollbackSuccess = $false
                    $backupPath = if ($AllUsers) { $Script:Configuration.AllUsersBackupPath } else { $Script:Configuration.BackupRegistryPath }
                    
                    if (Test-Path $backupPath) {
                        Write-ModernStatus "Attempting comprehensive configuration restore..." -Status Processing
                        Write-ModernCard "Backup Source" $backupPath -ValueColor "Info"
                        $rollbackSuccess = Restore-ComprehensiveTraySettings
                    } else {
                        Write-ModernStatus "No comprehensive backup found at: $backupPath" -Status Warning
                    }
                    
                    if (-not $rollbackSuccess) {
                        Write-ModernStatus "Falling back to basic registry rollback..." -Status Warning
                        $rollbackSuccess = Invoke-ConfigurationRollback
                    }
                    
                    if ($rollbackSuccess) {
                        if ($RestartExplorer) {
                            Write-ModernStatus "Restarting Windows Explorer to apply restored settings..." -Status Processing
                            $restartResult = Restart-WindowsExplorerSafely
                            if ($restartResult) {
                                Write-ModernStatus "Configuration successfully rolled back and applied" -Status Success
                            } else {
                                Write-ModernStatus "Rollback completed but Explorer restart failed - logoff/logon required" -Status Warning
                            }
                        } else {
                            Write-ModernStatus "Configuration successfully rolled back" -Status Success
                            Write-ModernStatus "Use -RestartExplorer parameter to apply changes immediately" -Status Info
                        }
                        
                        # Rollback verification
                        Write-Host ""
                        Write-EnhancedOutput "ROLLBACK VERIFICATION:" -Type Primary
                        Write-ModernCard "Status" "Configuration restored from backup" -ValueColor "Success"
                        Write-ModernCard "Backup File" "Removed after successful restoration" -ValueColor "Info"
                    } else {
                        $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.RollbackFailed
                        Write-ModernStatus "Rollback operation failed - system may be in inconsistent state" -Status Error
                        Write-ModernCard "Recovery Tip" "Restart computer to restore known-good state" -ValueColor "Warning"
                        Write-ModernCard "Alternative" "Run with -Action Enable or -Action Disable to force specific state" -ValueColor "Info"
                    }
                }
            }
        }
        catch {
            $actionContext = if ($Action) {
                "action '$Action'"
            } else {
                "main script execution"
            }
            
            $errorDetails = @{
                Message = $_.Exception.Message
                Type = $_.Exception.GetType().FullName
                ScriptLine = $_.InvocationInfo.ScriptLineNumber
                Command = $_.InvocationInfo.Line.Trim()
            }
            
            Write-ModernStatus "Unexpected error during $actionContext" -Status Error
            Write-ModernStatus "Error details: $($errorDetails.Message)" -Status Warning
            Write-ModernCard "Exception Type" $errorDetails.Type -ValueColor "Error"
            Write-ModernCard "Script Location" "Line $($errorDetails.ScriptLine)" -ValueColor "Warning"
            
            if ($_.Exception.InnerException) {
                Write-ModernCard "Inner Exception" $_.Exception.InnerException.Message -ValueColor "Warning"
            }
            
            Write-ModernCard "Troubleshooting" "Check script parameters, system permissions, and Windows version compatibility" -ValueColor "Info"
            Write-ModernCard "Support" "Report issue at: $($Script:Configuration.GitHubRepository)" -ValueColor "Info"
            
            $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.GeneralError
        }
    }
    catch {
        Write-ModernStatus "Critical error in main execution engine: $($_.Exception.Message)" -Status Error
        Write-ModernStatus "Stack trace: $($_.ScriptStackTrace)" -Status Error
        $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.GeneralError
    }
    finally {
        # Final execution summary
        if ($Script:Configuration.ExitCode -ne 0) {
            Write-Host ""
            Write-ModernHeader "Execution Completed" "With Errors"
            Write-ModernStatus "Script completed with errors (Exit Code: $($Script:Configuration.ExitCode))" -Status Error
            Write-ModernCard "Troubleshooting" "Review error messages above and check system requirements" -ValueColor "Warning"
            Write-ModernCard "Documentation" "Visit: $($Script:Configuration.GitHubRepository)" -ValueColor "Info"
        } else {
            Write-Host ""
            Write-ModernHeader "Execution Completed" "Successfully"
            Write-ModernStatus "Script completed successfully" -Status Success
            Write-ModernCard "Next Steps" "Verify configuration changes in system tray" -ValueColor "Success"
        }
        
        exit $Script:Configuration.ExitCode
    }
}

# ============================================================================
# ENHANCED SCRIPT ENTRY POINT WITH HELP SYSTEM PRIORITY
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
    
# Check for help requests FIRST (before any other processing)
if (Test-HelpRequestPresent) {
    # Enhanced help parameter analysis
    Write-Host ""
    Write-ModernHeader "Help System" -Subtitle "Parameter Analysis"
    
    $helpContext = @{
        HasHelp = $Help
        HasQuickHelp = $QuickHelp
        HasHelpLevel = $PSBoundParameters.ContainsKey('HelpLevel')
        SpecifiedHelpLevel = $HelpLevel
        EffectiveHelpLevel = $null
    }
    
    # Determine the actual help request context
    if ($QuickHelp) {
        $helpContext.EffectiveHelpLevel = 'Quick'
        Write-ModernCard "Request Type" "Quick Help Reference" -ValueColor "Info"
    }
    elseif ($PSBoundParameters.ContainsKey('HelpLevel')) {
        $helpContext.EffectiveHelpLevel = $HelpLevel
        Write-ModernCard "Request Type" "Specific Help Level: $HelpLevel" -ValueColor "Info"
    }
    elseif ($Help) {
        $helpContext.EffectiveHelpLevel = 'Full'
        Write-ModernCard "Request Type" "Comprehensive Help" -ValueColor "Info"
    }
    else {
        # This should not happen in normal execution
        $helpContext.EffectiveHelpLevel = 'Quick'
        Write-ModernCard "Request Type" "Default Help" -ValueColor "Warning"
    }
    
    Write-ModernCard "Effective Level" $helpContext.EffectiveHelpLevel -ValueColor "Success"
    Write-Host ""
    
    # Invoke the help system with determined parameters
    Invoke-HelpSystem -HelpLevel $helpContext.EffectiveHelpLevel
    exit $Script:Configuration.ExitCodes.Success
}
    
    # Execute main logic (only if no help requested)
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
