<#
.SYNOPSIS
    Enable or disable automatic hiding of system tray icons in Windows 11/10.

.DESCRIPTION
    Enterprise-grade PowerShell script for managing system tray icon visibility.
    Features comprehensive error handling, logging, session validation, and rollback support.
    
    Author: Mikhail Deynekin (mid1977@gmail.com)
    Website: https://deynekin.com
    Repository: https://github.com/paulmann/windows-show-all-tray-icons
    Version: 3.0 (Enterprise Edition)

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

.NOTES
    Version:        3.0 (Enterprise Edition)
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

.LINK
    GitHub Repository: https://github.com/paulmann/windows-show-all-tray-icons
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('Enable', 'Disable', 'Status', 'Rollback')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [switch]$RestartExplorer,

    [Parameter(Mandatory = $false)]
    [switch]$BackupRegistry,

    [Parameter(Mandatory = $false)]
    [string]$LogPath,

    [Parameter(Mandatory = $false)]
    [switch]$Force
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
    ScriptVersion = "3.0"
    ScriptAuthor = "Mikhail Deynekin (mid1977@gmail.com)"
    ScriptName = "Enable-AllTrayIcons.ps1"
    
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
    }
}

# ============================================================================
# COLOR & LOGGING CONFIGURATION
# ============================================================================

$Script:ColorScheme = @{
    Success   = "Green"
    Error     = "Red"
    Warning   = "Yellow"
    Info      = "Cyan"
    Header    = "Cyan"
    Separator = "Gray"
    Highlight = "White"
    Timestamp = "Gray"
    Debug     = "Magenta"
}

$Script:ExecutionState = @{
    StartTime = Get-Date
    OriginalConfig = $null
    BackupCreated = $false
    ChangesMade = $false
    ExplorerRestarted = $false
}

# ============================================================================
# ENTERPRISE LOGGING SYSTEM
# ============================================================================

function Write-EnterpriseLog {
    <#
    .SYNOPSIS
        Enterprise-grade logging with console and file output.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Success', 'Error', 'Warning', 'Info', 'Header', 'Separator', 'Debug')]
        [string]$Type = "Info",
        
        [Parameter(Mandatory = $false)]
        [switch]$NoConsoleOutput
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Type] $Message"
    $color = $Script:ColorScheme[$Type]
    
    # Console Output
    if (-not $NoConsoleOutput) {
        switch ($Type) {
            "Success" {
                Write-Host "[$timestamp] " -NoNewline -ForegroundColor $Script:ColorScheme.Timestamp
                Write-Host "[SUCCESS] " -NoNewline -ForegroundColor $color
                Write-Host $Message -ForegroundColor $Script:ColorScheme.Highlight
            }
            "Error" {
                Write-Host "[$timestamp] " -NoNewline -ForegroundColor $Script:ColorScheme.Timestamp
                Write-Host "[ERROR] " -NoNewline -ForegroundColor $color
                Write-Host $Message -ForegroundColor $Script:ColorScheme.Highlight
            }
            "Warning" {
                Write-Host "[$timestamp] " -NoNewline -ForegroundColor $Script:ColorScheme.Timestamp
                Write-Host "[WARNING] " -NoNewline -ForegroundColor $color
                Write-Host $Message -ForegroundColor $Script:ColorScheme.Highlight
            }
            "Info" {
                Write-Host "[$timestamp] " -NoNewline -ForegroundColor $Script:ColorScheme.Timestamp
                Write-Host "[INFO] " -NoNewline -ForegroundColor $color
                Write-Host $Message -ForegroundColor $Script:ColorScheme.Highlight
            }
            "Header" {
                Write-Host ""
                Write-Host ("=" * 80) -ForegroundColor $color
                Write-Host $Message -ForegroundColor $color
                Write-Host ("=" * 80) -ForegroundColor $color
                Write-Host ""
            }
            "Separator" {
                Write-Host ("-" * 80) -ForegroundColor $color
            }
            "Debug" {
                if ($VerbosePreference -ne 'SilentlyContinue') {
                    Write-Host "[$timestamp] " -NoNewline -ForegroundColor $Script:ColorScheme.Timestamp
                    Write-Host "[DEBUG] " -NoNewline -ForegroundColor $color
                    Write-Host $Message -ForegroundColor $Script:ColorScheme.Highlight
                }
            }
        }
    }
    
    # File Logging
    $logFile = if ($LogPath) { $LogPath } else { $Script:Configuration.DefaultLogPath }
    try {
        $logEntry | Out-File -FilePath $logFile -Append -Encoding UTF8
    }
    catch {
        # If file logging fails, continue without it
    }
}

function Initialize-Logging {
    <#
    .SYNOPSIS
        Initializes logging system and creates log header.
    #>
    $logFile = if ($LogPath) { $LogPath } else { $Script:Configuration.DefaultLogPath }
    
    try {
        $header = @"
================================================================================
Windows System Tray Icons Configuration Tool
Version: $($Script:Configuration.ScriptVersion)
Start Time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
User: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
Computer: $env:COMPUTERNAME
PowerShell Version: $($PSVersionTable.PSVersion)
Command Line: $($MyInvocation.Line)
================================================================================
"@
        $header | Out-File -FilePath $logFile -Encoding UTF8
        Write-EnterpriseLog "Logging initialized: $logFile" -Type Info
    }
    catch {
        Write-Warning "Failed to initialize file logging: $($_.Exception.Message)"
    }
}

# ============================================================================
# SESSION & ENVIRONMENT VALIDATION
# ============================================================================

function Test-ExecutionEnvironment {
    <#
    .SYNOPSIS
        Comprehensive environment validation and context analysis.
    #>
    
    Write-EnterpriseLog "Validating execution environment..." -Type Info
    
    # PowerShell Version Check
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-EnterpriseLog "PowerShell 5.1 or higher required. Current version: $($PSVersionTable.PSVersion)" -Type Error
        return $false
    }
    
    # Windows Version Check
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        Write-EnterpriseLog "Windows 10 or higher required. Current version: $($osVersion)" -Type Error
        return $false
    }
    
    # Session Type Analysis
    $sessionContext = Get-SessionContext
    Write-EnterpriseLog "Session Type: $($sessionContext.SessionType)" -Type Debug
    Write-EnterpriseLog "Interactive: $($sessionContext.IsInteractive)" -Type Debug
    Write-EnterpriseLog "Admin Rights: $($sessionContext.IsAdmin)" -Type Debug
    
    if (-not $sessionContext.IsInteractive -and -not $Force) {
        Write-EnterpriseLog "Non-interactive session detected. Use -Force to override." -Type Warning
        return $false
    }
    
    # Registry Access Test
    if (-not (Test-RegistryAccess)) {
        Write-EnterpriseLog "Registry access validation failed." -Type Error
        return $false
    }
    
    Write-EnterpriseLog "Environment validation completed successfully." -Type Success
    return $true
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
        Write-EnterpriseLog "Failed to check admin privileges: $($_.Exception.Message)" -Type Debug
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

function Test-RegistryAccess {
    <#
    .SYNOPSIS
        Tests registry access and permissions.
    #>
    
    try {
        $testPath = $Script:Configuration.RegistryPath
        if (-not (Test-Path $testPath)) {
            Write-EnterpriseLog "Registry path does not exist, testing creation..." -Type Debug
            $null = New-Item -Path $testPath -Force -ErrorAction Stop
            Remove-Item -Path $testPath -Force -ErrorAction SilentlyContinue
        }
        else {
            $null = Get-ItemProperty -Path $testPath -ErrorAction Stop
        }
        return $true
    }
    catch {
        Write-EnterpriseLog "Registry access test failed: $($_.Exception.Message)" -Type Error
        return $false
    }
}

# ============================================================================
# REGISTRY MANAGEMENT WITH BACKUP/RESTORE
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
            Write-EnterpriseLog "Registry path not found: $registryPath" -Type Debug
            return $null
        }
        
        $value = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue
        if ($null -eq $value -or $null -eq $value.$valueName) {
            Write-EnterpriseLog "Registry value not set, using Windows default behavior" -Type Info
            return $null
        }
        
        Write-EnterpriseLog "Current registry value: $($value.$valueName)" -Type Debug
        return $value.$valueName
    }
    catch {
        Write-EnterpriseLog "Failed to read registry configuration: $($_.Exception.Message)" -Type Error
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
    
    Write-EnterpriseLog "Configuring tray behavior: $actionDescription" -Type Info
    
    if (-not $Force -and -not $PSCmdlet.ShouldProcess(
        "Registry: $($Script:Configuration.RegistryPath)\$($Script:Configuration.RegistryValue)", 
        "Set value to $value ($actionDescription)"
    )) {
        return $false
    }
    
    # Create backup if requested
    if ($BackupRegistry -and -not $Script:ExecutionState.BackupCreated) {
        if (-not (Backup-RegistryConfiguration)) {
            Write-EnterpriseLog "Registry backup failed, but continuing with operation..." -Type Warning
        }
    }
    
    try {
        # Ensure registry path exists
        $registryPath = $Script:Configuration.RegistryPath
        if (-not (Test-Path $registryPath)) {
            Write-EnterpriseLog "Creating registry path: $registryPath" -Type Info
            $null = New-Item -Path $registryPath -Force -ErrorAction Stop
        }
        
        # Set registry value
        Set-ItemProperty -Path $registryPath `
                         -Name $Script:Configuration.RegistryValue `
                         -Value $value `
                         -Type DWord `
                         -Force `
                         -ErrorAction Stop
        
        Write-EnterpriseLog "Registry configuration updated successfully: $actionDescription" -Type Success
        $Script:ExecutionState.ChangesMade = $true
        return $true
    }
    catch [System.UnauthorizedAccessException] {
        Write-EnterpriseLog "Access denied to registry. Try running as Administrator." -Type Error
        return $false
    }
    catch {
        Write-EnterpriseLog "Failed to configure registry: $($_.Exception.Message)" -Type Error
        return $false
    }
}

function Backup-RegistryConfiguration {
    <#
    .SYNOPSIS
        Creates registry backup for rollback capability.
    #>
    
    try {
        $backupPath = $Script:Configuration.BackupRegistryPath
        $currentConfig = Get-CurrentTrayConfiguration
        
        $backupData = @{
            Timestamp = Get-Date
            OriginalValue = $currentConfig
            RegistryPath = $Script:Configuration.RegistryPath
            ValueName = $Script:Configuration.RegistryValue
        }
        
        $backupData | ConvertTo-Json | Out-File -FilePath $backupPath -Encoding UTF8
        Write-EnterpriseLog "Registry configuration backed up to: $backupPath" -Type Success
        $Script:ExecutionState.BackupCreated = $true
        $Script:ExecutionState.OriginalConfig = $currentConfig
        return $true
    }
    catch {
        Write-EnterpriseLog "Failed to create registry backup: $($_.Exception.Message)" -Type Warning
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
        Write-EnterpriseLog "No backup found for rollback: $backupPath" -Type Error
        return $false
    }
    
    try {
        $backupData = Get-Content -Path $backupPath -Raw | ConvertFrom-Json
        $originalValue = $backupData.OriginalValue
        
        Write-EnterpriseLog "Attempting rollback to previous configuration..." -Type Info
        
        if ($null -eq $originalValue) {
            # Original value was not set (Windows default), so remove the registry value
            Remove-ItemProperty -Path $Script:Configuration.RegistryPath `
                               -Name $Script:Configuration.RegistryValue `
                               -Force `
                               -ErrorAction Stop
            Write-EnterpriseLog "Restored Windows default behavior (registry value removed)" -Type Success
        }
        else {
            # Restore original value
            Set-ItemProperty -Path $Script:Configuration.RegistryPath `
                           -Name $Script:Configuration.RegistryValue `
                           -Value $originalValue `
                           -Type DWord `
                           -Force `
                           -ErrorAction Stop
            Write-EnterpriseLog "Restored original configuration: $originalValue" -Type Success
        }
        
        # Remove backup file after successful rollback
        Remove-Item -Path $backupPath -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        Write-EnterpriseLog "Rollback failed: $($_.Exception.Message)" -Type Error
        return $false
    }
}

# ============================================================================
# WINDOWS EXPLORER MANAGEMENT
# ============================================================================

function Restart-WindowsExplorerSafely {
    <#
    .SYNOPSIS
        Safely restarts Windows Explorer with comprehensive error handling.
    #>
    
    if (-not $Force -and -not $PSCmdlet.ShouldProcess("Windows Explorer", "Restart process")) {
        return $false
    }
    
    Write-EnterpriseLog "Initiating safe Windows Explorer restart..." -Type Info
    
    try {
        $explorerProcesses = Get-Process -Name explorer -ErrorAction SilentlyContinue
        
        if ($explorerProcesses.Count -eq 0) {
            Write-EnterpriseLog "Windows Explorer not running, starting process..." -Type Warning
            Start-Process -FilePath "explorer.exe" -WindowStyle Hidden
            Start-Sleep -Seconds 2
            Write-EnterpriseLog "Windows Explorer started successfully" -Type Success
            $Script:ExecutionState.ExplorerRestarted = $true
            return $true
        }
        
        Write-EnterpriseLog "Stopping $($explorerProcesses.Count) Windows Explorer process(es)..." -Type Info
        
        # Stop Explorer processes gracefully
        $explorerProcesses | Stop-Process -Force -ErrorAction Stop
        
        # Wait for processes to terminate
        $timeout = $Script:Configuration.ExplorerRestartTimeout
        $timer = 0
        while ((Get-Process -Name explorer -ErrorAction SilentlyContinue) -and $timer -lt $timeout) {
            Start-Sleep -Milliseconds 500
            $timer += 0.5
        }
        
        # Force termination if still running
        if (Get-Process -Name explorer -ErrorAction SilentlyContinue) {
            Write-EnterpriseLog "Explorer processes still running after timeout, forcing termination..." -Type Warning
            Get-Process -Name explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        }
        
        # Start Explorer
        Write-EnterpriseLog "Starting Windows Explorer..." -Type Info
        Start-Process -FilePath "explorer.exe" -WindowStyle Hidden
        
        # Wait for initialization
        Start-Sleep -Seconds 2
        
        $restartedProcesses = Get-Process -Name explorer -ErrorAction SilentlyContinue
        if ($restartedProcesses.Count -gt 0) {
            Write-EnterpriseLog "Windows Explorer restarted successfully ($($restartedProcesses.Count) processes)" -Type Success
            $Script:ExecutionState.ExplorerRestarted = $true
            return $true
        }
        else {
            Write-EnterpriseLog "Windows Explorer may not have started properly" -Type Warning
            return $false
        }
    }
    catch {
        Write-EnterpriseLog "Failed to restart Windows Explorer: $($_.Exception.Message)" -Type Error
        Write-EnterpriseLog "Manual restart may be required" -Type Warning
        return $false
    }
}

# ============================================================================
# STATUS REPORTING & ANALYTICS
# ============================================================================

function Show-ComprehensiveStatus {
    <#
    .SYNOPSIS
        Displays comprehensive system status and configuration details.
    #>
    
    Write-EnterpriseLog "Generating comprehensive system status report..." -Type Header
    
    $currentConfig = Get-CurrentTrayConfiguration
    $sessionContext = Get-SessionContext
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    
    Write-EnterpriseLog "CURRENT CONFIGURATION" -Type Info
    Write-Host "  Registry Path:  " -NoNewline -ForegroundColor Cyan
    Write-Host $Script:Configuration.RegistryPath -ForegroundColor Yellow
    
    Write-Host "  Registry Value: " -NoNewline -ForegroundColor Cyan
    Write-Host $Script:Configuration.RegistryValue -ForegroundColor Yellow
    
    Write-Host "  Current Setting: " -NoNewline -ForegroundColor Cyan
    if ($null -eq $currentConfig) {
        Write-Host "Not Configured (Windows Default)" -ForegroundColor Green
        Write-Host "  Current Behavior: " -NoNewline -ForegroundColor Cyan
        Write-Host "Auto-hide inactive icons" -ForegroundColor Green
    }
    else {
        Write-Host $currentConfig -ForegroundColor Yellow
        Write-Host "  Current Behavior: " -NoNewline -ForegroundColor Cyan
        if ($currentConfig -eq $Script:Configuration.EnableValue) {
            Write-Host "Show ALL tray icons (auto-hide disabled)" -ForegroundColor Green
        }
        else {
            Write-Host "Auto-hide inactive icons (Windows default)" -ForegroundColor Green
        }
    }
    
    Write-Host ""
    Write-EnterpriseLog "SYSTEM INFORMATION" -Type Info
    if ($osInfo) {
        Write-Host "  Operating System: " -NoNewline -ForegroundColor Cyan
        Write-Host "$($osInfo.Caption)" -ForegroundColor Yellow
        
        Write-Host "  Version:         " -NoNewline -ForegroundColor Cyan
        Write-Host "$($osInfo.Version)" -ForegroundColor Yellow
        
        Write-Host "  Build Number:    " -NoNewline -ForegroundColor Cyan
        Write-Host "$($osInfo.BuildNumber)" -ForegroundColor Yellow
    }
    
    Write-Host "  PowerShell:      " -NoNewline -ForegroundColor Cyan
    Write-Host "$($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    
    Write-Host ""
    Write-EnterpriseLog "SESSION CONTEXT" -Type Info
    Write-Host "  User:           " -NoNewline -ForegroundColor Cyan
    Write-Host $sessionContext.CurrentUser -ForegroundColor Yellow
    
    Write-Host "  Session Type:   " -NoNewline -ForegroundColor Cyan
    Write-Host $sessionContext.SessionType -ForegroundColor Yellow
    
    Write-Host "  Admin Rights:   " -NoNewline -ForegroundColor Cyan
    Write-Host $(if ($sessionContext.IsAdmin) { "Yes" } else { "No" }) -ForegroundColor $(if ($sessionContext.IsAdmin) { "Yellow" } else { "Gray" })
    
    Write-Host "  Interactive:    " -NoNewline -ForegroundColor Cyan
    Write-Host $(if ($sessionContext.IsInteractive) { "Yes" } else { "No" }) -ForegroundColor $(if ($sessionContext.IsInteractive) { "Yellow" } else { "Red" })
    
    # Backup Status
    $backupPath = $Script:Configuration.BackupRegistryPath
    Write-Host ""
    Write-EnterpriseLog "BACKUP STATUS" -Type Info
    Write-Host "  Backup File:    " -NoNewline -ForegroundColor Cyan
    Write-Host $backupPath -ForegroundColor Yellow
    
    Write-Host "  Backup Exists:  " -NoNewline -ForegroundColor Cyan
    Write-Host $(if (Test-Path $backupPath) { "Yes" } else { "No" }) -ForegroundColor $(if (Test-Path $backupPath) { "Yellow" } else { "Gray" })
    
    Write-Host ""
    Write-EnterpriseLog "" -Type Separator
}

function Show-PerformanceMetrics {
    <#
    .SYNOPSIS
        Displays script performance metrics and execution summary.
    #>
    
    $endTime = Get-Date
    $duration = $endTime - $Script:ExecutionState.StartTime
    
    Write-EnterpriseLog "PERFORMANCE METRICS" -Type Info
    Write-Host "  Start Time:     " -NoNewline -ForegroundColor Cyan
    Write-Host $($Script:ExecutionState.StartTime.ToString("yyyy-MM-dd HH:mm:ss")) -ForegroundColor Yellow
    
    Write-Host "  End Time:       " -NoNewline -ForegroundColor Cyan
    Write-Host $($endTime.ToString("yyyy-MM-dd HH:mm:ss")) -ForegroundColor Yellow
    
    Write-Host "  Total Duration: " -NoNewline -ForegroundColor Cyan
    Write-Host "$($duration.TotalSeconds.ToString('0.00')) seconds" -ForegroundColor Yellow
    
    Write-Host "  Changes Made:   " -NoNewline -ForegroundColor Cyan
    Write-Host $(if ($Script:ExecutionState.ChangesMade) { "Yes" } else { "No" }) -ForegroundColor $(if ($Script:ExecutionState.ChangesMade) { "Yellow" } else { "Gray" })
    
    Write-Host "  Explorer Restarted: " -NoNewline -ForegroundColor Cyan
    Write-Host $(if ($Script:ExecutionState.ExplorerRestarted) { "Yes" } else { "No" }) -ForegroundColor $(if ($Script:ExecutionState.ExplorerRestarted) { "Yellow" } else { "Gray" })
    
    Write-Host "  Backup Created: " -NoNewline -ForegroundColor Cyan
    Write-Host $(if ($Script:ExecutionState.BackupCreated) { "Yes" } else { "No" }) -ForegroundColor $(if ($Script:ExecutionState.BackupCreated) { "Yellow" } else { "Gray" })
}

# ============================================================================
# MAIN EXECUTION ENGINE
# ============================================================================

function Invoke-MainExecution {
    <#
    .SYNOPSIS
        Main execution engine with comprehensive action routing.
    #>
    
    Write-EnterpriseLog "Windows System Tray Icons Configuration Tool v$($Script:Configuration.ScriptVersion)" -Type Header
    Write-EnterpriseLog "Author: $($Script:Configuration.ScriptAuthor)" -Type Info
    Write-EnterpriseLog "Action: $Action" -Type Info
    Write-EnterpriseLog "Parameters: RestartExplorer=$RestartExplorer, BackupRegistry=$BackupRegistry, Force=$Force" -Type Debug
    
    # Validate environment
    if (-not (Test-ExecutionEnvironment)) {
        $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.InvalidSession
        return
    }
    
    # Route action
    switch ($Action) {
        'Status' {
            Show-ComprehensiveStatus
        }
        
        'Enable' {
            if (Set-TrayIconConfiguration -Behavior 'Enable') {
                if ($RestartExplorer) {
                    Restart-WindowsExplorerSafely
                }
                else {
                    Write-EnterpriseLog "Use -RestartExplorer to apply changes immediately, or restart Explorer manually" -Type Warning
                }
            }
            else {
                $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.GeneralError
            }
        }
        
        'Disable' {
            if (Set-TrayIconConfiguration -Behavior 'Disable') {
                if ($RestartExplorer) {
                    Restart-WindowsExplorerSafely
                }
                else {
                    Write-EnterpriseLog "Use -RestartExplorer to apply changes immediately, or restart Explorer manually" -Type Warning
                }
            }
            else {
                $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.GeneralError
            }
        }
        
        'Rollback' {
            if (Invoke-ConfigurationRollback) {
                if ($RestartExplorer) {
                    Restart-WindowsExplorerSafely
                }
            }
            else {
                Write-EnterpriseLog "Rollback operation failed" -Type Error
                $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.RollbackFailed
            }
        }
    }
    
    # Show performance metrics
    Show-PerformanceMetrics
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

try {
    # Initialize logging
    Initialize-Logging
    
    # Execute main logic
    Invoke-MainExecution
}
catch {
    Write-EnterpriseLog "Unhandled exception: $($_.Exception.Message)" -Type Error
    Write-EnterpriseLog "Stack trace: $($_.ScriptStackTrace)" -Type Debug
    $Script:Configuration.ExitCode = $Script:Configuration.ExitCodes.GeneralError
}
finally {
    Write-EnterpriseLog "Script execution completed with exit code: $($Script:Configuration.ExitCode)" -Type Info
    
    # Log completion
    $logFile = if ($LogPath) { $LogPath } else { $Script:Configuration.DefaultLogPath }
    Write-EnterpriseLog "Detailed log available: $logFile" -Type Info
    
    exit $Script:Configuration.ExitCode
}
