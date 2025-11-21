<#
.SYNOPSIS
    Enable or disable automatic hiding of system tray icons in Windows 11.

.DESCRIPTION
    This PowerShell script modifies the Windows registry to control the visibility
    of notification area (system tray) icons. It can be used for individual
    workstations or deployed via Group Policy for enterprise environments.
    
    Author: Mikhail Deynekin (mid1977@gmail.com)
    Website: https://deynekin.com
    Repository: https://github.com/paulmann/windows-show-all-tray-icons

.PARAMETER Action
    Specifies the action to perform:
    - 'Enable' : Show all system tray icons (disable auto-hide)
    - 'Disable': Restore Windows default behavior (enable auto-hide)
    - 'Status' : Check current configuration

.PARAMETER RestartExplorer
    If specified, automatically restarts Windows Explorer to apply changes immediately.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Action Enable
    Enables display of all system tray icons.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer
    Enables all tray icons and restarts Explorer to apply changes immediately.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Action Status
    Displays current configuration status.

.EXAMPLE
    .\Enable-AllTrayIcons.ps1 -Action Disable -RestartExplorer
    Restores Windows default behavior and restarts Explorer.

.NOTES
    Version:        1.0
    Creation Date:  2025-11-21
    Compatibility:  Windows 10, Windows 11, Windows Server 2019+
    Requires:       PowerShell 5.1 or higher
    Privileges:     User-level (HKCU registry hive)
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
# CONFIGURATION
# ============================================================================

$script:RegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
$script:RegistryValue = "EnableAutoTray"
$script:ExitCode = 0

# ============================================================================
# FUNCTIONS
# ============================================================================

function Write-ColorOutput {
    <#
    .SYNOPSIS
        Writes colored output to console with consistent formatting.
    #>
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    switch ($Type) {
        "Success" {
            Write-Host "[$timestamp] " -NoNewline -ForegroundColor Gray
            Write-Host "[SUCCESS] " -NoNewline -ForegroundColor Green
            Write-Host $Message
        }
        "Error" {
            Write-Host "[$timestamp] " -NoNewline -ForegroundColor Gray
            Write-Host "[ERROR] " -NoNewline -ForegroundColor Red
            Write-Host $Message
        }
        "Warning" {
            Write-Host "[$timestamp] " -NoNewline -ForegroundColor Gray
            Write-Host "[WARNING] " -NoNewline -ForegroundColor Yellow
            Write-Host $Message
        }
        "Info" {
            Write-Host "[$timestamp] " -NoNewline -ForegroundColor Gray
            Write-Host "[INFO] " -NoNewline -ForegroundColor Cyan
            Write-Host $Message
        }
    }
}

function Test-RegistryKeyExists {
    <#
    .SYNOPSIS
        Checks if a registry key exists.
    #>
    param([string]$Path)
    
    return Test-Path -Path $Path
}

function Get-CurrentConfiguration {
    <#
    .SYNOPSIS
        Retrieves the current EnableAutoTray value from registry.
    #>
    try {
        if (-not (Test-RegistryKeyExists -Path $script:RegistryPath)) {
            Write-ColorOutput "Registry key does not exist: $script:RegistryPath" -Type Warning
            return $null
        }
        
        $value = Get-ItemProperty -Path $script:RegistryPath -Name $script:RegistryValue -ErrorAction SilentlyContinue
        
        if ($null -eq $value) {
            Write-ColorOutput "Registry value '$script:RegistryValue' not found" -Type Warning
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
    #>
    param(
        [Parameter(Mandatory = $true)]
        [int]$Value
    )
    
    try {
        # Ensure the registry path exists
        if (-not (Test-RegistryKeyExists -Path $script:RegistryPath)) {
            Write-ColorOutput "Creating registry key: $script:RegistryPath" -Type Info
            New-Item -Path $script:RegistryPath -Force | Out-Null
        }
        
        # Set the registry value
        Set-ItemProperty -Path $script:RegistryPath `
                         -Name $script:RegistryValue `
                         -Value $Value `
                         -Type DWord `
                         -Force
        
        Write-ColorOutput "Registry value set successfully: $script:RegistryValue = $Value" -Type Success
        return $true
    }
    catch {
        Write-ColorOutput "Failed to set registry value: $($_.Exception.Message)" -Type Error
        return $false
    }
}

function Restart-WindowsExplorer {
    <#
    .SYNOPSIS
        Restarts Windows Explorer process to apply changes.
    #>
    try {
        Write-ColorOutput "Restarting Windows Explorer..." -Type Info
        
        # Stop Explorer process
        Stop-Process -Name explorer -Force -ErrorAction Stop
        
        # Wait a moment for process to fully terminate
        Start-Sleep -Milliseconds 500
        
        # Explorer should auto-restart, but start it explicitly if needed
        $explorerProcess = Get-Process -Name explorer -ErrorAction SilentlyContinue
        if (-not $explorerProcess) {
            Start-Process explorer.exe
            Write-ColorOutput "Windows Explorer restarted successfully" -Type Success
        }
        else {
            Write-ColorOutput "Windows Explorer auto-restarted" -Type Success
        }
        
        return $true
    }
    catch {
        Write-ColorOutput "Failed to restart Windows Explorer: $($_.Exception.Message)" -Type Error
        Write-ColorOutput "You may need to manually restart Explorer or log off/on" -Type Warning
        return $false
    }
}

function Show-CurrentStatus {
    <#
    .SYNOPSIS
        Displays the current system tray icon configuration.
    #>
    Write-ColorOutput "Checking current configuration..." -Type Info
    Write-Host "`n" -NoNewline
    Write-Host "=" * 70 -ForegroundColor Gray
    Write-Host "System Tray Icon Configuration Status" -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Gray
    
    $currentValue = Get-CurrentConfiguration
    
    Write-Host "`nRegistry Path  : " -NoNewline
    Write-Host $script:RegistryPath -ForegroundColor Yellow
    Write-Host "Registry Value : " -NoNewline
    Write-Host $script:RegistryValue -ForegroundColor Yellow
    Write-Host "Current Value  : " -NoNewline
    
    if ($null -eq $currentValue) {
        Write-Host "NOT SET (using Windows default)" -ForegroundColor Yellow
        Write-Host "`nBehavior       : " -NoNewline
        Write-Host "Auto-hide inactive icons (Windows default)" -ForegroundColor Cyan
    }
    else {
        Write-Host $currentValue -ForegroundColor Yellow
        Write-Host "`nBehavior       : " -NoNewline
        
        switch ($currentValue) {
            0 {
                Write-Host "Show ALL system tray icons (auto-hide DISABLED)" -ForegroundColor Green
            }
            1 {
                Write-Host "Auto-hide inactive icons (Windows default)" -ForegroundColor Cyan
            }
            default {
                Write-Host "Unknown value: $currentValue" -ForegroundColor Red
            }
        }
    }
    
    Write-Host "`nWindows Version: " -NoNewline
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    Write-Host "$($osInfo.Caption) (Build $($osInfo.BuildNumber))" -ForegroundColor Yellow
    
    Write-Host "PowerShell Ver : " -NoNewline
    Write-Host "$($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    
    Write-Host "`n" -NoNewline
    Write-Host "=" * 70 -ForegroundColor Gray
    Write-Host ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    Write-Host ""
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host "Windows 11 - System Tray Icon Configuration Tool" -ForegroundColor Cyan
    Write-Host "Author: Mikhail Deynekin (mid1977@gmail.com)" -ForegroundColor Gray
    Write-Host "Repository: github.com/paulmann/windows-show-all-tray-icons" -ForegroundColor Gray
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host ""
    
    switch ($Action) {
        'Status' {
            Show-CurrentStatus
        }
        
        'Enable' {
            Write-ColorOutput "Enabling display of all system tray icons..." -Type Info
            
            if ($PSCmdlet.ShouldProcess("Registry: $script:RegistryPath\$script:RegistryValue", "Set value to 0 (show all icons)")) {
                $success = Set-TrayIconConfiguration -Value 0
                
                if ($success) {
                    Write-ColorOutput "All system tray icons are now set to be visible" -Type Success
                    
                    if ($RestartExplorer) {
                        Restart-WindowsExplorer | Out-Null
                    }
                    else {
                        Write-ColorOutput "To apply changes immediately, restart Windows Explorer or log off/on" -Type Info
                        Write-ColorOutput "Use -RestartExplorer parameter to restart Explorer automatically" -Type Info
                    }
                }
                else {
                    $script:ExitCode = 1
                }
            }
        }
        
        'Disable' {
            Write-ColorOutput "Restoring Windows default behavior (auto-hide icons)..." -Type Info
            
            if ($PSCmdlet.ShouldProcess("Registry: $script:RegistryPath\$script:RegistryValue", "Set value to 1 (auto-hide icons)")) {
                $success = Set-TrayIconConfiguration -Value 1
                
                if ($success) {
                    Write-ColorOutput "Windows default behavior restored (auto-hide enabled)" -Type Success
                    
                    if ($RestartExplorer) {
                        Restart-WindowsExplorer | Out-Null
                    }
                    else {
                        Write-ColorOutput "To apply changes immediately, restart Windows Explorer or log off/on" -Type Info
                        Write-ColorOutput "Use -RestartExplorer parameter to restart Explorer automatically" -Type Info
                    }
                }
                else {
                    $script:ExitCode = 1
                }
            }
        }
    }
    
    Write-Host ""
    Write-ColorOutput "Operation completed" -Type Info
    Write-Host ""
}
catch {
    Write-ColorOutput "Unexpected error: $($_.Exception.Message)" -Type Error
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" -Type Error
    $script:ExitCode = 1
}
finally {
    exit $script:ExitCode
}
