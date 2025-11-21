<#
.SYNOPSIS
    Enable or disable automatic hiding of system tray icons in Windows 11/10.

.DESCRIPTION
    Professional PowerShell script for managing system tray icon visibility.
    Modifies Windows registry to control notification area icon display.
    Includes automatic privilege detection, session validation, and error handling.
    
    Author: Mikhail Deynekin (mid1977@gmail.com)
    Website: https://deynekin.com
    Repository: https://github.com/paulmann/windows-show-all-tray-icons
    Version: 2.2 (Enhanced with Session & Privilege Checks)

.PARAMETER Action
    Specifies the action to perform:
    - 'Enable'  : Show all system tray icons (disable auto-hide) [Value: 0]
    - 'Disable' : Restore Windows default behavior (enable auto-hide) [Value: 1]
    - 'Status'  : Check current configuration without making changes

.PARAMETER RestartExplorer
    If specified, automatically restarts Windows Explorer to apply changes immediately.
    Use with -Action Enable or -Action Disable for immediate effect.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Action Enable
    Shows all system tray icons. Explorer restart required for effect.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer
    Shows all icons and restarts Explorer immediately.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Action Status
    Displays current system tray icon configuration.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Action Disable -RestartExplorer
    Restores Windows default auto-hide behavior.

.NOTES
    Version:        2.2
    Creation Date:  2025-11-21
    Last Updated:   2025-11-21
    Compatibility:  Windows 10 (All versions), Windows 11 (All versions), Server 2019+
    Requires:       PowerShell 5.1 or higher
    Privileges:     Standard User (HKCU registry key only - no admin required)
    
    Session Types Supported:
    - Interactive Desktop (Full support)
    - Administrator (Full support)
    - PowerShell Remote/WinRM (Limited - warns about non-interactive)
    - SSH/WSL (Partial support if HKCU accessible)
    - SYSTEM/Service Account (Not supported - script detects and warns)

.LINK
    GitHub Repository: https://github.com/paulmann/windows-show-all-tray-icons

#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('Enable', 'Disable', 'Status')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [switch]$RestartExplorer
)

#Requires -Version 5.1

# ============================================================================
# GLOBAL CONFIGURATION
# ============================================================================

$script:RegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
$script:RegistryValue = "EnableAutoTray"
$script:RegistryValueTypeEnable = 0
$script:RegistryValueTypeDisable = 1
$script:ExitCode = 0
$script:ScriptVersion = "2.2"
$script:ScriptAuthor = "Mikhail Deynekin (mid1977@gmail.com)"

# ============================================================================
# COLOR & FORMATTING CONFIGURATION
# ============================================================================

$script:ColorScheme = @{
    Success  = "Green"
    Error    = "Red"
    Warning  = "Yellow"
    Info     = "Cyan"
    Header   = "Cyan"
    Separator = "Gray"
    Highlight = "White"
}

# ============================================================================
# FUNCTIONS - OUTPUT & LOGGING
# ============================================================================

function Write-ColorOutput {
    <#
    .SYNOPSIS
        Writes colored output to console with ISO 8601 timestamp.
    .DESCRIPTION
        Formats output with consistent timestamp and color coding.
        Types: Success, Error, Warning, Info, Header, Separator
    #>
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Success', 'Error', 'Warning', 'Info', 'Header', 'Separator')]
        [string]$Type = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = $script:ColorScheme[$Type]
    
    switch ($Type) {
        "Success" {
            Write-Host "[$timestamp] " -NoNewline -ForegroundColor Gray
            Write-Host "[OK SUCCESS] " -NoNewline -ForegroundColor $color
            Write-Host $Message -ForegroundColor White
        }
        "Error" {
            Write-Host "[$timestamp] " -NoNewline -ForegroundColor Gray
            Write-Host "[XX ERROR] " -NoNewline -ForegroundColor $color
            Write-Host $Message -ForegroundColor White
        }
        "Warning" {
            Write-Host "[$timestamp] " -NoNewline -ForegroundColor Gray
            Write-Host "[!! WARNING] " -NoNewline -ForegroundColor $color
            Write-Host $Message -ForegroundColor White
        }
        "Info" {
            Write-Host "[$timestamp] " -NoNewline -ForegroundColor Gray
            Write-Host "[ii INFO] " -NoNewline -ForegroundColor $color
            Write-Host $Message -ForegroundColor White
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
    }
}

function Write-Section {
    <#
    .SYNOPSIS
        Writes a section header with visual formatting.
    #>
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================================
# FUNCTIONS - SESSION & PRIVILEGE VALIDATION
# ============================================================================

function Test-AdminPrivileges {
    <#
    .SYNOPSIS
        Checks if script is running with administrator privileges.
    .RETURNS
        Boolean: $true if running as admin, $false otherwise
    #>
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')
}

function Test-InteractiveSession {
    <#
    .SYNOPSIS
        Checks if running in interactive desktop session.
    .DESCRIPTION
        Validates that script is not running in WinRM, SSH, or service context.
    .RETURNS
        Boolean: $true if interactive, $false otherwise
    #>
    try {
        # Check if running in interactive mode
        $isInteractive = [Environment]::UserInteractive
        
        # Additional check for WinRM sessions
        $isWinRM = $null -ne $env:WINRM_PROCESS
        
        # Check for SYSTEM account (service context)
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $isSystem = $currentUser.User.Value -eq "S-1-5-18"
        
        if ($isSystem) {
            return $false
        }
        
        if ($isWinRM -and -not $isInteractive) {
            return $false
        }
        
        return $isInteractive
    }
    catch {
        return $true  # Assume interactive if check fails
    }
}

function Test-SessionContext {
    <#
    .SYNOPSIS
        Performs comprehensive session context validation.
    .DESCRIPTION
        Checks for interactive session, admin privileges, and special contexts.
        Returns detailed context information.
    .RETURNS
        PSCustomObject with context details
    #>
    $context = @{
        IsAdmin = Test-AdminPrivileges
        IsInteractive = Test-InteractiveSession
        SessionType = Get-SessionType
        CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        ProcessName = $script:MyInvocation.MyCommand.Name
    }
    
    return [PSCustomObject]$context
}

function Get-SessionType {
    <#
    .SYNOPSIS
        Determines the type of PowerShell session.
    .RETURNS
        String describing session type
    #>
    if ($null -ne $env:WINRM_PROCESS) {
        return "WinRM Remote"
    }
    elseif ($PSVersionTable.PSVersion.Major -ge 6 -and $env:SSH_CONNECTION) {
        return "SSH/Remote"
    }
    elseif ([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value -eq "S-1-5-18") {
        return "SYSTEM/Service Account"
    }
    elseif (-not [Environment]::UserInteractive) {
        return "Non-Interactive (Scheduled Task/Service)"
    }
    else {
        return "Interactive Desktop"
    }
}

# ============================================================================
# FUNCTIONS - REGISTRY OPERATIONS
# ============================================================================

function Test-RegistryKeyExists {
    <#
    .SYNOPSIS
        Checks if a registry key exists and is accessible.
    #>
    param([string]$Path)
    
    try {
        $null = Get-Item -Path $Path -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Test-RegistryValueExists {
    <#
    .SYNOPSIS
        Checks if a specific registry value exists.
    #>
    param(
        [string]$Path,
        [string]$Name
    )
    
    try {
        $value = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        return $null -ne $value -and $value.$Name -ne $null
    }
    catch {
        return $false
    }
}

function Get-CurrentConfiguration {
    <#
    .SYNOPSIS
        Retrieves the current EnableAutoTray value from registry.
    .DESCRIPTION
        Gets the current setting, handling cases where value doesn't exist.
    .RETURNS
        Integer (0, 1) or $null if not set
    #>
    try {
        if (-not (Test-RegistryKeyExists -Path $script:RegistryPath)) {
            Write-ColorOutput "Registry key does not exist: $script:RegistryPath" -Type Warning
            return $null
        }
        
        $value = Get-ItemProperty -Path $script:RegistryPath -Name $script:RegistryValue -ErrorAction SilentlyContinue
        
        if ($null -eq $value) {
            Write-ColorOutput "Registry value '$script:RegistryValue' not set (using Windows default)" -Type Info
            return $null
        }
        
        return $value.$script:RegistryValue
    }
    catch {
        Write-ColorOutput "Error reading registry: $($_.Exception.Message)" -Type Error
        return $null
    }
}

function Set-TrayIconConfiguration {
    <#
    .SYNOPSIS
        Sets the EnableAutoTray registry value.
    .DESCRIPTION
        Modifies HKCU registry to enable/disable tray icon auto-hide.
        Creates registry key if it doesn't exist.
    .PARAMETER Value
        Registry value (0 = show all, 1 = auto-hide)
    .RETURNS
        Boolean: $true on success, $false on failure
    #>
    param(
        [Parameter(Mandatory = $true)]
        [int]$Value,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )
    
    try {
        Write-ColorOutput "Attempting to set registry value: $script:RegistryValue = $Value" -Type Info
        
        # Ensure the registry path exists
        if (-not (Test-RegistryKeyExists -Path $script:RegistryPath)) {
            Write-ColorOutput "Creating registry key: $script:RegistryPath" -Type Info
            $null = New-Item -Path $script:RegistryPath -Force -ErrorAction Stop
        }
        
        # Set the registry value
        Set-ItemProperty -Path $script:RegistryPath `
                         -Name $script:RegistryValue `
                         -Value $Value `
                         -Type DWord `
                         -Force `
                         -ErrorAction Stop
        
        $status = if ($Value -eq 0) { "Show ALL icons" } else { "Auto-hide icons (default)" }
        Write-ColorOutput "Registry configured successfully: $status" -Type Success
        return $true
    }
    catch {
        Write-ColorOutput "Failed to set registry value: $($_.Exception.Message)" -Type Error
        
        # Provide helpful guidance
        if ($_.Exception.Message -match "Access Denied") {
            Write-ColorOutput "Try running PowerShell as Administrator" -Type Warning
        }
        
        return $false
    }
}

# ============================================================================
# FUNCTIONS - EXPLORER MANAGEMENT
# ============================================================================

function Restart-WindowsExplorer {
    <#
    .SYNOPSIS
        Restarts Windows Explorer process to apply changes.
    .DESCRIPTION
        Gracefully stops and restarts Windows Explorer.
        Waits for process to fully terminate before restarting.
    .RETURNS
        Boolean: $true on success, $false on failure
    #>
    try {
        Write-ColorOutput "Restarting Windows Explorer..." -Type Info
        
        # Get current Explorer process count
        $explorerCount = (Get-Process -Name explorer -ErrorAction SilentlyContinue | Measure-Object).Count
        
        if ($explorerCount -eq 0) {
            Write-ColorOutput "Windows Explorer not running, starting it..." -Type Warning
            Start-Process explorer.exe
            Start-Sleep -Milliseconds 1000
            Write-ColorOutput "Windows Explorer started" -Type Success
            return $true
        }
        
        # Stop Explorer process(es)
        Write-ColorOutput "Stopping Windows Explorer processes..." -Type Info
        Stop-Process -Name explorer -Force -ErrorAction Stop
        
        # Wait for process to fully terminate
        Start-Sleep -Milliseconds 1500
        
        # Verify Explorer stopped
        $explorerRunning = Get-Process -Name explorer -ErrorAction SilentlyContinue
        if ($null -ne $explorerRunning) {
            Write-ColorOutput "Explorer process still running, force killing..." -Type Warning
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 1000
        }
        
        # Start Explorer again
        Write-ColorOutput "Starting Windows Explorer..." -Type Info
        Start-Process explorer.exe
        
        # Wait for Explorer to fully start
        Start-Sleep -Milliseconds 2000
        
        # Verify Explorer started
        $explorerRestarted = Get-Process -Name explorer -ErrorAction SilentlyContinue
        if ($null -ne $explorerRestarted) {
            Write-ColorOutput "Windows Explorer restarted successfully" -Type Success
            return $true
        }
        else {
            Write-ColorOutput "Explorer did not restart properly" -Type Warning
            return $false
        }
    }
    catch {
        Write-ColorOutput "Failed to restart Windows Explorer: $($_.Exception.Message)" -Type Error
        Write-ColorOutput "You may need to restart Explorer manually or log off/on" -Type Warning
        return $false
    }
}

# ============================================================================
# FUNCTIONS - STATUS & REPORTING
# ============================================================================

function Show-CurrentStatus {
    <#
    .SYNOPSIS
        Displays comprehensive system configuration status.
    .DESCRIPTION
        Shows current registry settings, system info, and configuration details.
    #>
    Write-Section "System Tray Icon Configuration Status"
    
    Write-ColorOutput "Checking current configuration..." -Type Info
    Write-Host ""
    
    # System Information
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $currentValue = Get-CurrentConfiguration
    
    # Registry Information
    Write-Host "Registry Configuration:" -ForegroundColor Cyan
    Write-Host "  Registry Path  : " -NoNewline
    Write-Host $script:RegistryPath -ForegroundColor Yellow
    Write-Host "  Registry Value : " -NoNewline
    Write-Host $script:RegistryValue -ForegroundColor Yellow
    
    # Current Value Display
    Write-Host "  Current Value  : " -NoNewline
    if ($null -eq $currentValue) {
        Write-Host "NOT SET (using Windows default)" -ForegroundColor Yellow
    }
    else {
        Write-Host $currentValue -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Current Behavior:" -ForegroundColor Cyan
    if ($null -eq $currentValue) {
        Write-Host "  Status         : " -NoNewline
        Write-Host "Auto-hide inactive icons (Windows default)" -ForegroundColor Green
    }
    else {
        Write-Host "  Status         : " -NoNewline
        switch ($currentValue) {
            0 {
                Write-Host "Show ALL system tray icons (auto-hide DISABLED)" -ForegroundColor Green
            }
            1 {
                Write-Host "Auto-hide inactive icons (Windows default)" -ForegroundColor Green
            }
            default {
                Write-Host "Unknown value: $currentValue" -ForegroundColor Red
            }
        }
    }
    
    Write-Host ""
    Write-Host "System Information:" -ForegroundColor Cyan
    if ($osInfo) {
        Write-Host "  Windows OS     : " -NoNewline
        Write-Host "$($osInfo.Caption)" -ForegroundColor Yellow
        Write-Host "  Build Number   : " -NoNewline
        Write-Host "$($osInfo.BuildNumber)" -ForegroundColor Yellow
        Write-Host "  OS Version     : " -NoNewline
        Write-Host "$($osInfo.Version)" -ForegroundColor Yellow
    }
    
    Write-Host "  PowerShell Ver : " -NoNewline
    Write-Host "$($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    
    # Session Information
    $context = Test-SessionContext
    Write-Host ""
    Write-Host "Execution Context:" -ForegroundColor Cyan
    Write-Host "  Session Type   : " -NoNewline
    Write-Host $context.SessionType -ForegroundColor Yellow
    Write-Host "  Current User   : " -NoNewline
    Write-Host $context.CurrentUser -ForegroundColor Yellow
    Write-Host "  Admin Rights   : " -NoNewline
    $adminStatus = if ($context.IsAdmin) { "Yes" } else { "No" }
    $adminColor = if ($context.IsAdmin) { "Yellow" } else { "Cyan" }
    Write-Host $adminStatus -ForegroundColor $adminColor
    Write-Host "  Interactive    : " -NoNewline
    $interactiveStatus = if ($context.IsInteractive) { "Yes" } else { "No" }
    $interactiveColor = if ($context.IsInteractive) { "Green" } else { "Red" }
    Write-Host $interactiveStatus -ForegroundColor $interactiveColor
    
    Write-Host ""
    Write-ColorOutput "" -Type Separator
    Write-Host ""
}

# ============================================================================
# MAIN EXECUTION LOGIC
# ============================================================================

function Main {
    <#
    .SYNOPSIS
        Main execution function with action routing.
    #>
    
    # Header
    Write-Section "Windows 11/10 - System Tray Icon Configuration"
    
    Write-Host "Script Version : " -NoNewline -ForegroundColor Cyan
    Write-Host $script:ScriptVersion -ForegroundColor Yellow
    Write-Host "Author         : " -NoNewline -ForegroundColor Cyan
    Write-Host $script:ScriptAuthor -ForegroundColor Yellow
    Write-Host "Repository     : " -NoNewline -ForegroundColor Cyan
    Write-Host "https://github.com/paulmann/windows-show-all-tray-icons" -ForegroundColor Yellow
    Write-Host ""
    
    # Session validation
    Write-ColorOutput "Validating execution context..." -Type Info
    $context = Test-SessionContext
    
    if (-not $context.IsInteractive) {
        Write-ColorOutput "WARNING: Non-interactive session detected" -Type Warning
        Write-ColorOutput "Session Type: $($context.SessionType)" -Type Warning
        Write-ColorOutput "Changes may not apply to user desktop" -Type Warning
        Write-ColorOutput "This script requires an interactive desktop session" -Type Warning
        Write-Host ""
    }
    
    # Admin check (informational only, not required)
    if (-not $context.IsAdmin) {
        Write-ColorOutput "Running as Standard User - UAC prompt will appear if needed" -Type Info
    }
    else {
        Write-ColorOutput "Running with Administrator privileges" -Type Info
    }
    
    Write-Host ""
    
    # Process action
    switch ($Action) {
        'Status' {
            Show-CurrentStatus
        }
        
        'Enable' {
            Write-Section "Enabling All System Tray Icons"
            Write-ColorOutput "Configuring Windows to display all system tray icons..." -Type Info
            
            if ($PSCmdlet.ShouldProcess(
                "Registry: $script:RegistryPath\$script:RegistryValue",
                "Set value to 0 (show all icons)"
            )) {
                $success = Set-TrayIconConfiguration -Value $script:RegistryValueTypeEnable
                
                if ($success) {
                    Write-ColorOutput "All system tray icons are now set to be visible" -Type Success
                    Write-Host ""
                    
                    if ($RestartExplorer) {
                        Write-ColorOutput "Restarting Windows Explorer to apply changes..." -Type Info
                        $explorerRestarted = Restart-WindowsExplorer
                        
                        if ($explorerRestarted) {
                            Write-ColorOutput "Changes applied successfully and are now active" -Type Success
                        }
                        else {
                            Write-ColorOutput "Changes saved but Explorer restart had issues" -Type Warning
                            Write-ColorOutput "Try restarting Explorer manually or logging off/on" -Type Warning
                        }
                    }
                    else {
                        Write-ColorOutput "To apply changes immediately, restart Windows Explorer:" -Type Warning
                        Write-Host "  - Press Ctrl + Shift + Esc (Task Manager)"
                        Write-Host "  - Find 'Windows Explorer' -> Right-click -> Restart"
                        Write-Host "  - Or use: taskkill /f /im explorer.exe && start explorer.exe"
                        Write-Host ""
                        Write-ColorOutput "Use -RestartExplorer parameter to restart automatically" -Type Info
                    }
                }
                else {
                    $script:ExitCode = 1
                    Write-ColorOutput "Failed to configure system tray icons" -Type Error
                }
            }
        }
        
        'Disable' {
            Write-Section "Restoring Windows Default (Auto-Hide Icons)"
            Write-ColorOutput "Configuring Windows to auto-hide system tray icons..." -Type Info
            
            if ($PSCmdlet.ShouldProcess(
                "Registry: $script:RegistryPath\$script:RegistryValue",
                "Set value to 1 (auto-hide icons)"
            )) {
                $success = Set-TrayIconConfiguration -Value $script:RegistryValueTypeDisable
                
                if ($success) {
                    Write-ColorOutput "Windows default behavior restored (auto-hide enabled)" -Type Success
                    Write-Host ""
                    
                    if ($RestartExplorer) {
                        Write-ColorOutput "Restarting Windows Explorer to apply changes..." -Type Info
                        $explorerRestarted = Restart-WindowsExplorer
                        
                        if ($explorerRestarted) {
                            Write-ColorOutput "Changes applied successfully and are now active" -Type Success
                        }
                        else {
                            Write-ColorOutput "Changes saved but Explorer restart had issues" -Type Warning
                            Write-ColorOutput "Try restarting Explorer manually or logging off/on" -Type Warning
                        }
                    }
                    else {
                        Write-ColorOutput "To apply changes immediately, restart Windows Explorer:" -Type Warning
                        Write-Host "  - Press Ctrl + Shift + Esc (Task Manager)"
                        Write-Host "  - Find 'Windows Explorer' -> Right-click -> Restart"
                        Write-Host "  - Or use: taskkill /f /im explorer.exe && start explorer.exe"
                        Write-Host ""
                        Write-ColorOutput "Use -RestartExplorer parameter to restart automatically" -Type Info
                    }
                }
                else {
                    $script:ExitCode = 1
                    Write-ColorOutput "Failed to restore default settings" -Type Error
                }
            }
        }
    }
    
    Write-Host ""
    Write-ColorOutput "Operation completed with exit code: $script:ExitCode" -Type Info
    Write-Host ""
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

try {
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-ColorOutput "ERROR: PowerShell 5.1 or higher required" -Type Error
        Write-ColorOutput "Current version: $($PSVersionTable.PSVersion)" -Type Error
        exit 3
    }
    
    # Execute main function
    Main
}
catch {
    Write-ColorOutput "Unexpected error: $($_.Exception.Message)" -Type Error
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" -Type Error
    $script:ExitCode = 1
}
finally {
    exit $script:ExitCode
}
