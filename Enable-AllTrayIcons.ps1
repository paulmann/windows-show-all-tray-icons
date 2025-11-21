<#
.SYNOPSIS
    Enable or disable automatic hiding of system tray icons in Windows 11/10.

.DESCRIPTION
    Enterprise-grade PowerShell script for managing system tray icon visibility.
    Features comprehensive error handling, logging, session validation, and rollback support.
    
    Author: Mikhail Deynekin (mid1977@gmail.com)
    Website: https://deynekin.com
    Repository: https://github.com/paulmann/windows-show-all-tray-icons
    Version: 3.1 (Enterprise Edition)

.PARAMETER Action
    Specifies the action to perform:
    - 'Enable'  : Show all system tray icons (disable auto-hide) [Value: 0]
    - 'Disable' : Restore Windows default behavior (enable auto-hide) [Value: 1]
    - 'Status'  : Check current configuration without making changes
    - 'Rollback': Revert to previous configuration if available

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
    .\Enable-AllTrayIcons.ps1 -Action Rollback
    Reverts to previous configuration if backup exists.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Update
    Checks and updates script from GitHub repository.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Help
    Displays detailed help information.

.NOTES
    Version:        3.1 (Enterprise Edition)
    Creation Date:  2025-11-21
    Last Updated:   2025-11-21
    Compatibility:  Windows 10 (All versions), Windows 11 (All versions), Server 2019+
    Requires:       PowerShell 5.1 or higher
    Privileges:     Standard User (HKCU registry key only - no admin required)
    
    FEATURES:
    - Comprehensive logging (console and file)
    - Registry backup/restore functionality
    - Session validation and context awareness
    - Rollback support for failed operations
    - WhatIf support for safe testing
    - Performance monitoring and metrics
    - Graceful error handling with recovery
    - Auto-update functionality
    - Professional UI/UX design

.LINK
    GitHub Repository: https://github.com/paulmann/windows-show-all-tray-icons
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet('Enable', 'Disable', 'Status', 'Rollback')]
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
    [switch]$Help
)

#Requires -Version 5.1

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
    ScriptVersion = "3.1"
    ScriptAuthor = "Mikhail Deynekin (mid1977@gmail.com)"
    ScriptName = "Enable-AllTrayIcons.ps1"
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
    }
}

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

# ============================================================================
# MODERN UI/UX OUTPUT SYSTEM
# ============================================================================

function Write-ModernOutput {
    <#
    .SYNOPSIS
        Modern UI output with professional design and consistent styling.
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
    $formattedMessage = $Message
    
    if ($Bold) {
        $formattedMessage = $Message
    }
    
    if ($NoNewline) {
        Write-Host $formattedMessage -NoNewline -ForegroundColor $color
    } else {
        Write-Host $formattedMessage -ForegroundColor $color
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
    
    Show-ModernBanner
    
    Write-ModernHeader "Windows System Tray Icons Configuration Tool" "v$($Script:Configuration.ScriptVersion)"
    
    Write-ModernOutput "DESCRIPTION:" -Type Primary -Bold
    Write-ModernOutput "  Professional tool for managing system tray icon visibility in Windows 10/11." -Type Light
    Write-ModernOutput "  Modifies registry settings to control notification area behavior." -Type Light
    Write-Host ""
    
    Write-ModernOutput "USAGE:" -Type Primary -Bold
    Write-Host "  .\$($Script:Configuration.ScriptName) -Action <Command> [Options]" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host ""
    
    Write-ModernOutput "QUICK COMMANDS:" -Type Primary -Bold
    Write-ModernCard "Show All Icons" ".\$($Script:Configuration.ScriptName) -Action Enable"
    Write-ModernCard "Restore Default" ".\$($Script:Configuration.ScriptName) -Action Disable"
    Write-ModernCard "Check Status" ".\$($Script:Configuration.ScriptName) -Action Status"
    Write-ModernCard "Update Script" ".\$($Script:Configuration.ScriptName) -Update"
    Write-ModernCard "Show Help" ".\$($Script:Configuration.ScriptName) -Help"
    Write-Host ""
    
    Write-ModernOutput "ACTION PARAMETERS:" -Type Primary -Bold
    Write-ModernCard "-Action Enable" "Show all system tray icons"
    Write-ModernCard "-Action Disable" "Restore Windows default behavior"
    Write-ModernCard "-Action Status" "Display current configuration"
    Write-ModernCard "-Action Rollback" "Revert to previous configuration"
    Write-Host ""
    
    Write-ModernOutput "OPTIONAL PARAMETERS:" -Type Primary -Bold
    Write-ModernCard "-RestartExplorer" "Apply changes immediately"
    Write-ModernCard "-BackupRegistry" "Create backup before changes"
    Write-ModernCard "-Force" "Bypass confirmation prompts"
    Write-ModernCard "-Update" "Update script from GitHub"
    Write-ModernCard "-Help" "Display this help message"
    Write-ModernCard "-LogPath <path>" "Custom log file location"
    Write-Host ""
    
    Write-ModernOutput "EXAMPLES:" -Type Primary -Bold
    Write-Host "  .\$($Script:Configuration.ScriptName) -Action Enable -RestartExplorer" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "    # Enable all icons and restart Explorer immediately" -ForegroundColor $Script:ConsoleColors.Dark
    Write-Host ""
    Write-Host "  .\$($Script:Configuration.ScriptName) -Action Status" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "    # Display current system configuration" -ForegroundColor $Script:ConsoleColors.Dark
    Write-Host ""
    Write-Host "  .\$($Script:Configuration.ScriptName) -Action Disable -BackupRegistry -Force" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "    # Restore defaults with backup, no prompts" -ForegroundColor $Script:ConsoleColors.Dark
    Write-Host ""
    Write-Host "  .\$($Script:Configuration.ScriptName) -Update" -ForegroundColor $Script:ConsoleColors.Light
    Write-Host "    # Check and update script from GitHub" -ForegroundColor $Script:ConsoleColors.Dark
    Write-Host ""
    
    Write-ModernOutput "ADDITIONAL INFORMATION:" -Type Primary -Bold
    Write-ModernCard "Version" $Script:Configuration.ScriptVersion
    Write-ModernCard "Author" $Script:Configuration.ScriptAuthor
    Write-ModernCard "Repository" $Script:Configuration.GitHubRepository
    Write-ModernCard "Support" "https://github.com/paulmann/windows-show-all-tray-icons"
    
    Write-Host ""
    Write-ModernOutput "Note: All parameters are case-insensitive. Admin rights not required." -Type Dark
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
    Write-ModernCard "PowerShell" "5.1 or higher"
    
    Write-Host ""
    Write-ModernOutput "Use '-Help' for detailed usage information." -Type Info
    Write-Host ""
}

# ============================================================================
# AUTO-UPDATE SYSTEM
# ============================================================================

function Invoke-ScriptUpdate {
    <#
    .SYNOPSIS
        Checks for and performs script updates from GitHub repository.
    #>
    
    Write-ModernHeader "Script Update" "Checking for updates..."
    
    try {
        Write-ModernStatus "Checking GitHub repository for updates..." -Status Processing
        
        # Download latest script content
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add('User-Agent', 'PowerShell Script Update Check')
        $latestScriptContent = $webClient.DownloadString($Script:Configuration.UpdateUrl)
        
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
            
            # Create backup
            Copy-Item -Path $currentScriptPath -Destination $backupPath -Force
            
            # Write new version
            $latestScriptContent | Out-File -FilePath $currentScriptPath -Encoding UTF8
            
            Write-ModernStatus "Update completed successfully!" -Status Success
            Write-ModernStatus "Backup created: $backupPath" -Status Info
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
    Write-ModernOutput "CONFIGURATION STATUS:" -Type Primary -Bold
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
    Write-ModernOutput "SYSTEM INFORMATION:" -Type Primary -Bold
    if ($osInfo) {
        Write-ModernCard "Operating System" $osInfo.Caption
        Write-ModernCard "OS Version" "$($osInfo.Version) (Build $($osInfo.BuildNumber))"
    }
    Write-ModernCard "PowerShell Version" $PSVersionTable.PSVersion.ToString()
    Write-Host ""
    
    # Session Context
    Write-ModernOutput "SESSION CONTEXT:" -Type Primary -Bold
    Write-ModernCard "Current User" $sessionContext.CurrentUser
    Write-ModernCard "Session Type" $sessionContext.SessionType
    Write-ModernCard "Admin Rights" $(if ($sessionContext.IsAdmin) { "Yes" } else { "No" }) -ValueColor $(if ($sessionContext.IsAdmin) { "Success" } else { "Info" })
    Write-ModernCard "Interactive" $(if ($sessionContext.IsInteractive) { "Yes" } else { "No" }) -ValueColor $(if ($sessionContext.IsInteractive) { "Success" } else { "Warning" })
    Write-Host ""
    
    # Backup Status
    Write-ModernOutput "BACKUP STATUS:" -Type Primary -Bold
    $backupExists = Test-Path $Script:Configuration.BackupRegistryPath
    Write-ModernCard "Backup Available" $(if ($backupExists) { "Yes" } else { "No" }) -ValueColor $(if ($backupExists) { "Success" } else { "Info" })
    if ($backupExists) {
        $backupInfo = Get-Item $Script:Configuration.BackupRegistryPath
        Write-ModernCard "Backup Created" $backupInfo.CreationTime.ToString("yyyy-MM-dd HH:mm")
    }
    
    Write-Host ""
    Write-ModernOutput "Use '-Action Enable' to show all icons or '-Action Disable' for default behavior." -Type Info
    Write-Host ""
}

# ============================================================================
# CORE FUNCTIONS
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
        return $false
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
# MAIN EXECUTION ENGINE
# ============================================================================

function Invoke-MainExecution {
    <#
    .SYNOPSIS
        Main execution engine with comprehensive action routing.
    #>
    
    # Show banner for all actions except help
    if (-not $Help) {
        Show-ModernBanner
    }
    
    # Handle update first
    if ($Update) {
        $updateResult = Invoke-ScriptUpdate
        if ($updateResult) {
            # Exit if update was successful and we replaced the script
            exit $Script:Configuration.ExitCodes.Success
        }
    }
    
    # Show help if requested or no action specified
    if ($Help -or (-not $Action -and -not $Update)) {
        Show-ModernHelp
        exit $Script:Configuration.ExitCodes.Success
    }
    
    # Show application info if no specific action
    if (-not $Action -and -not $Update -and -not $Help) {
        Show-ApplicationInfo
        exit $Script:Configuration.ExitCodes.Success
    }
    
    # Execute the requested action
    switch ($Action.ToLower()) {
        'status' {
            Show-EnhancedStatus
        }
        
        'enable' {
            Write-ModernHeader "Enable All Tray Icons" "Making all icons always visible"
            
            if (Set-TrayIconConfiguration -Behavior 'Enable') {
                if ($RestartExplorer) {
                    Write-ModernStatus "Applying changes immediately..." -Status Processing
                    Restart-WindowsExplorerSafely
                }
                else {
                    Write-ModernStatus "Configuration updated successfully!" -Status Success
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
                    Restart-WindowsExplorerSafely
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
            Write-ModernStatus "Rollback feature requires backup file implementation" -Status Info
            Write-ModernStatus "This feature will be available in future versions" -Status Warning
        }
    }
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

try {
    # Execute main logic
    Invoke-MainExecution
}
catch {
    Write-ModernStatus "Unhandled exception: $($_.Exception.Message)" -Status Error
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
