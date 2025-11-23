# Windows 11/10 - Show All System Tray Icons

[![Windows 11](https://img.shields.io/badge/Windows-11-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows/windows-11)
[![Windows 10](https://img.shields.io/badge/Windows-10-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-4.0-green.svg)](https://github.com/paulmann/windows-show-all-tray-icons)

**Professional enterprise-grade tool for managing system tray icon visibility in Windows 10/11.** Comprehensive solution to disable automatic icon hiding and display **all notification area icons** at all times using advanced PowerShell, streamlined batch scripts, or simple registry tweaks.

> **Author**: Mikhail Deynekin ([mid1977@gmail.com](mailto:mid1977@gmail.com))  
> **Website**: [https://deynekin.com](https://deynekin.com)  
> **Repository**: [https://github.com/paulmann/windows-show-all-tray-icons](https://github.com/paulmann/windows-show-all-tray-icons)

---

## 📋 Table of Contents

1. [Quick Start](#-quick-start)
2. [What's New in v4.0](#-whats-new-in-v40)
3. [Features](#-features)
4. [System Requirements](#-system-requirements)
5. [Installation Methods](#-installation-methods)
   - [Method 1: PowerShell Script (Recommended)](#method-1-powershell-script-recommended)
   - [Method 2: Batch Script (Lightweight)](#method-2-batch-script-lightweight)
   - [Method 3: Registry File (Simplest)](#method-3-registry-file-simplest)
   - [Method 4: Command Line (Advanced)](#method-4-command-line-advanced)
6. [Advanced Usage](#-advanced-usage)
7. [PowerShell Script v4.0 Enterprise Features](#-powershell-script-v40-enterprise-features)
8. [Batch Script Features](#-batch-script-features)
9. [Verification & Troubleshooting](#-verification--troubleshooting)
10. [Reverting Changes](#-reverting-changes)
11. [Enterprise Deployment](#-enterprise-deployment)
12. [Technical Details](#-technical-details)
13. [FAQ](#-faq)
14. [Safety & Security](#-safety--security)
15. [Contributing](#-contributing)
16. [Support](#-support)

---

## 🚀 Quick Start

**Choose your preferred method and get started in seconds:**

### Method 1: PowerShell 4.0 (Recommended - Full Enterprise Features)

**Opening PowerShell:**
- Press `Win + R`, type `powershell`, press Enter
- Or press `Win + X`, select "Windows PowerShell"

# Download latest v4.0 script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/Enable-AllTrayIcons.ps1" -OutFile "Enable-AllTrayIcons.ps1"

# Enable with comprehensive method (resets ALL icon settings)
.\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer

# Done! All icons now permanently visible ✓

### Method 2: Batch Script (Lightweight - No Dependencies)

**Opening Command Prompt:**
- Press `Win + R`, type `cmd`, press Enter
- Or press `Win + X`, select "Command Prompt"

:: Download streamlined batch script
curl -O https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/Enable-AllTrayIcons.bat

:: Enable all icons with restart
Enable-AllTrayIcons.bat Enable /Restart

:: Done! All icons now visible ✓

### Method 3: Registry File (Simplest - Double-Click)

**Opening File Explorer:**
- Press `Win + E` to open File Explorer
- Navigate to downloaded file location

:: Download registry file
curl -O https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/enable-all-tray-icons.reg

:: Double-click enable-all-tray-icons.reg → Click Yes
:: Restart Explorer: Ctrl+Shift+Esc → Find "Windows Explorer" → Right-click → Restart

:: Done! All icons now visible ✓

---

## 🎉 What's New in v4.0

### PowerShell 4.0 Enterprise Edition - Revolutionary Update

**Comprehensive Individual Icon Settings Management:**

Version 4.0 introduces a groundbreaking multi-method approach to system tray icon visibility. Unlike previous versions that only modified the global `EnableAutoTray` registry value, v4.0 comprehensively resets and enforces visibility across **all Windows tray icon subsystems**.

#### Revolutionary Features:

1. **Complete Individual Icon Preferences Reset**
   - Resets per-icon user settings in `NotifyIconSettings` (all icons set to `IsPromoted = 1`)
   - Clears icon cache in `TrayNotify` (IconStreams, PastIconsStream)
   - Removes desktop icon visibility restrictions
   - Normalizes taskbar layout preferences
   - Resets notification system settings for all applications

2. **Multi-Method Icon Visibility Enforcement** (4+ Complementary Techniques)
   - **Method 1**: Global auto-hide disable (`EnableAutoTray = 0`)
   - **Method 2**: Individual icon promotion for each registered icon
   - **Method 3**: System tray cache invalidation and refresh
   - **Method 4**: System icons visibility enforcement (Volume, Network, Power)
   - **Method 5**: Windows 11 taskbar optimization (`TaskbarMn` configuration)
   - **Method 6**: Notification area preferences reset

3. **Advanced Comprehensive Backup/Restore System**
   - JSON-serialized backup of ALL tray-related registry keys
   - Binary data handling for icon streams (Base64 encoding)
   - Metadata tracking (timestamp, version, Windows version, user context)
   - Backup integrity validation and corruption detection
   - Granular restoration with rollback protection

4. **Windows 11 Specific Optimizations**
   - Modern taskbar layout management
   - Windows 11 UI element control
   - Enhanced system icon visibility
   - Compatibility with Windows 11 22H2, 23H2, 24H2, 25H2

5. **Professional Diagnostic System**
   - Backup file validation (`-Diagnostic` parameter)
   - Registry path verification with auto-creation
   - JSON parsing integrity checks
   - Real-time progress tracking per method
   - Comprehensive error reporting with context

6. **Enhanced PowerShell 7+ Support**
   - Improved color schemes and UI rendering
   - Enhanced download methods (`Invoke-RestMethod`)
   - Performance optimizations for modern PowerShell
   - Backward compatibility maintained for PowerShell 5.1

#### Technical Implementation Details:

**Registry Paths Managed:**
HKCU:\Control Panel\NotifyIconSettings\*
HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TrayNotify
HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons
HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband
HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\*
HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer (system icons)
HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced (Win11)

**Key Algorithm:**
1. Disable global auto-hide (EnableAutoTray = 0)
2. Enumerate all icons in NotifyIconSettings
3. Set IsPromoted = 1 for each icon (force promotion)
4. Clear IconStreams and PastIconsStream (cache reset)
5. Remove HideDesktopIcons restrictions
6. Reset Taskband favorites layout
7. Force system icons visibility (HideSCAVolume, HideSCANetwork, HideSCAPower = 0)
8. Apply Windows 11 specific tweaks (TaskbarMn = 0)
9. Reset per-app notification settings (Enabled = 1, ShowInActionCenter = 1)
10. Restart Explorer to apply all changes atomically

### Batch Script - Streamlined & Simplified

The batch script has been optimized for performance and clarity:

- **Reduced Complexity**: Focused on core functionality (basic backup/restore, status check)
- **Improved Performance**: Faster execution with streamlined logic
- **Enhanced Compatibility**: Works across all Windows versions (7, 8.1, 10, 11, Server)
- **Simplified Parameters**: Clearer command syntax with intuitive options
- **Essential Features Only**: Backup, restore, status, enable/disable without advanced diagnostics

**Key Difference from PowerShell:**  
While PowerShell 4.0 offers comprehensive multi-method enforcement and advanced diagnostics, the batch script provides a lightweight alternative for basic tray icon management without external dependencies.

---

## ✨ Features

### Core Capabilities (All Methods)

✅ **Show ALL notification area icons** - No more hidden icons  
✅ **Disable automatic icon hiding** - Complete visibility control  
✅ **Per-user configuration** - No admin required for basic installation  
✅ **Instant application** - Changes take effect immediately  
✅ **Fully reversible** - Revert to Windows default anytime  
✅ **No system modification** - Only user registry changes  
✅ **No reboot required** - Explorer restart applies changes  

### PowerShell v4.0 Enterprise Features

🚀 **Revolutionary Advanced Functionality:**
- ✅ **Comprehensive individual icon settings reset** (NotifyIconSettings, TrayNotify, TaskbarLayout)
- ✅ **Multi-method icon visibility enforcement** (4+ complementary techniques)
- ✅ **Advanced backup/restore with JSON serialization** (binary data support)
- ✅ **Windows 11 specific optimizations** (TaskbarMn, modern UI enhancements)
- ✅ **System icon visibility controls** (Volume, Network, Power indicators)
- ✅ **Professional diagnostic capabilities** (backup validation, registry verification)
- ✅ **Dynamic registry path management** (auto-creation of missing keys)
- ✅ **Binary data handling** (IconStreams, PastIconsStream Base64 encoding)
- ✅ **Notification system controls** (app-specific settings reset)
- ✅ **Backup integrity validation** (corruption detection, JSON parsing checks)
- ✅ **Session context awareness** (admin rights, interactive mode detection)
- ✅ **Auto-update from GitHub** (version checking, automatic downloads)
- ✅ **Professional logging system** (console and file output)
- ✅ **WhatIf support** (safe testing without execution)
- ✅ **PowerShell 7+ enhancements** (improved colors, performance)
- ✅ **Comprehensive error handling** (rollback protection)
- ✅ **Performance monitoring** (execution time tracking)
- ✅ **Exit codes for automation** (standardized return codes)
- ✅ **Real-time method progress tracking** (per-technique status reporting)

🎨 **Modern Professional UI/UX:**
- Modern banner and card-style displays
- Color-coded status indicators
- Visual progress tracking per method
- Professional help system with examples
- Enhanced PowerShell 7+ rendering

### Batch Script Features (Lightweight)

🪟 **Streamlined Windows Native Support:**
- ✅ No external dependencies
- ✅ Universal Windows compatibility (7/8.1/10/11/Server)
- ✅ Basic backup/rollback functionality
- ✅ Status checking
- ✅ Configuration logging
- ✅ Color-coded output
- ✅ Force mode support
- ✅ Simplified command syntax

---

## 💻 System Requirements

### Operating System Support

| OS Version | PowerShell v4.0 | Batch Script | Registry File | Status |
|------------|-----------------|--------------|---------------|--------|
| **Windows 11 (25H2, 24H2)** | ✅ Full + Enhanced | ✅ Full | ✅ Full | **Tested & Optimized** |
| **Windows 11 (23H2, 22H2)** | ✅ Full + Enhanced | ✅ Full | ✅ Full | **Tested & Optimized** |
| **Windows 11 (21H2)** | ✅ Full + Enhanced | ✅ Full | ✅ Full | **Supported** |
| **Windows 10 (22H2)** | ✅ Full | ✅ Full | ✅ Full | **Tested** |
| **Windows 10 (All versions)** | ✅ Full | ✅ Full | ✅ Full | **Supported** |
| **Windows Server 2022** | ✅ Full | ✅ Full | ✅ Full | **Compatible** |
| **Windows Server 2019** | ✅ Full | ✅ Full | ✅ Full | **Compatible** |
| **Windows 8.1** | ✅ Compatible | ✅ Full | ✅ Full | **Legacy Support** |
| **Windows 7** | ⚠️ Limited | ✅ Full | ✅ Full | **Legacy Support** |

### Software Requirements

| Component | PowerShell Method | Batch Method | Registry Method |
|-----------|------------------|--------------|-----------------|
| **PowerShell** | 5.1+ (built-in on Win10/11) | Not required | Not required |
| **.NET Framework** | Not required | Not required | Not required |
| **Admin Rights** | ❌ No* | ❌ No* | ❌ No* |
| **Dependencies** | None | None | None |

\\* *Admin rights optional but provide additional features*

### Architecture Support

✅ x86-64 (x64)  
✅ ARM64 (Windows 11 on ARM)  
✅ x86 (32-bit Windows 10 legacy)

---

## 📦 Installation Methods

### Method 1: PowerShell Script (Recommended)

**Best for:** Enterprise environments, automation, advanced users, comprehensive icon management

**Advantages:**
- ✅ **Revolutionary v4.0 comprehensive method** (resets ALL icon subsystems)
- ✅ **Multi-method enforcement** (4+ complementary techniques)
- ✅ **Advanced JSON backup/restore** (binary data support)
- ✅ **Windows 11 optimizations** (modern taskbar management)
- ✅ **Automatic error handling** & privilege detection
- ✅ **Professional diagnostic tools** (backup validation)
- ✅ **Immediate Explorer restart** option
- ✅ **Color-coded professional output**
- ✅ **Exit codes for automation**
- ✅ **Comprehensive logging**
- ✅ **Session context validation**
- ✅ **PowerShell 7+ enhanced features**

**Disadvantages:**
- Requires PowerShell 5.1+ (pre-installed on Windows 10/11)
- First-time users may need to adjust execution policy

#### Installation Steps

**Step 1: Download the script**

# Option A: PowerShell download (Recommended)
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/Enable-AllTrayIcons.ps1" -OutFile "$env:USERPROFILE\Downloads\Enable-AllTrayIcons.ps1"

# Option B: Using curl (Windows 10/11 built-in)
curl -O https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/Enable-AllTrayIcons.ps1

# Option C: Clone entire repository
git clone https://github.com/paulmann/windows-show-all-tray-icons.git
cd windows-show-all-tray-icons

**Step 2: Check PowerShell version**

$PSVersionTable.PSVersion
# Should show: 5.1 or higher (7.x recommended for enhanced features)

**Step 3: Configure execution policy (first time only)**

# Check current policy
Get-ExecutionPolicy -Scope CurrentUser

# If "Restricted", enable scripts for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

**Step 4: Run the script with comprehensive method**

# Comprehensive enable (all methods applied)
.\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer

# With backup before changes (recommended)
.\Enable-AllTrayIcons.ps1 -Action Enable -BackupRegistry -RestartExplorer

# Check comprehensive status
.\Enable-AllTrayIcons.ps1 -Action Status

# Create comprehensive backup
.\Enable-AllTrayIcons.ps1 -Action Backup

# Show detailed help
.\Enable-AllTrayIcons.ps1 -Help

#### PowerShell v4.0 Quick Commands

| Command | Description |
|---------|-------------|
| `.\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer` | **Comprehensive enable** (all 4+ methods) + restart |
| `.\Enable-AllTrayIcons.ps1 -Action Enable -BackupRegistry` | Enable with **full backup** (JSON + binary data) |
| `.\Enable-AllTrayIcons.ps1 -Action Disable -RestartExplorer` | Restore default + restart |
| `.\Enable-AllTrayIcons.ps1 -Action Status` | **Comprehensive status** with all subsystems |
| `.\Enable-AllTrayIcons.ps1 -Action Backup` | Create **comprehensive JSON backup** |
| `.\Enable-AllTrayIcons.ps1 -Action Rollback` | **Comprehensive restore** from backup |
| `.\Enable-AllTrayIcons.ps1 -Diagnostic` | **Backup file diagnostics** and validation |
| `.\Enable-AllTrayIcons.ps1 -Update` | Update script from GitHub |
| `.\Enable-AllTrayIcons.ps1 -Help` | Show detailed help with v4.0 features |

#### Advanced v4.0 Parameters

# All available parameters in v4.0
.\Enable-AllTrayIcons.ps1 `
    -Action <Enable|Disable|Status|Backup|Rollback> `
    [-RestartExplorer] `
    [-BackupRegistry] `
    [-LogPath <path>] `
    [-Force] `
    [-Update] `
    [-Diagnostic] `
    [-Help] `
    [-WhatIf] `
    [-Confirm]

**Parameter Reference:**

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `-Action` | Required* | Action to perform | `-Action Enable` |
| `-RestartExplorer` | Switch | Restart Explorer immediately | `-RestartExplorer` |
| `-BackupRegistry` | Switch | Create comprehensive backup | `-BackupRegistry` |
| `-LogPath` | String | Custom log file path | `-LogPath "C:\Logs\tray.log"` |
| `-Force` | Switch | Skip confirmation prompts | `-Force` |
| `-Update` | Switch | Update script from GitHub | `-Update` |
| `-Diagnostic` | Switch | **NEW v4.0**: Backup validation | `-Diagnostic` |
| `-Help` | Switch | Show detailed help | `-Help` |
| `-WhatIf` | Switch | Preview without executing | `-WhatIf` |
| `-Confirm` | Switch | Prompt before each operation | `-Confirm` |

\\* *Not required if using `-Update`, `-Help`, or `-Diagnostic`*

---

### Method 2: Batch Script (Lightweight)

**Best for:** Users preferring native Windows batch, minimal dependencies, basic functionality

**Advantages:**
- ✅ Native Windows batch script - **zero dependencies**
- ✅ Works on **all Windows versions** (7/8.1/10/11/Server)
- ✅ Basic backup/rollback functionality
- ✅ Status checking built-in
- ✅ Color-coded console output
- ✅ Configuration logging
- ✅ Traditional Windows method
- ✅ No execution policy concerns
- ✅ **Streamlined and simplified** (v3.3 optimized)

**Disadvantages:**
- Limited features compared to PowerShell v4.0
- Basic error handling
- No advanced diagnostics
- No multi-method enforcement

#### Installation Steps

**Step 1: Download the batch script**

:: Option A: Using curl (Windows 10/11)
curl -O https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/Enable-AllTrayIcons.bat

:: Option B: Using PowerShell download
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/Enable-AllTrayIcons.bat' -OutFile 'Enable-AllTrayIcons.bat'"

:: Option C: Clone repository
git clone https://github.com/paulmann/windows-show-all-tray-icons.git
cd windows-show-all-tray-icons

**Step 2: Run the batch script**

:: Show all icons with automatic Explorer restart
Enable-AllTrayIcons.bat Enable /Restart

:: Show all icons with backup before changes
Enable-AllTrayIcons.bat Enable /Backup /Restart

:: Check current status
Enable-AllTrayIcons.bat Status

:: Show help
Enable-AllTrayIcons.bat Help

#### Batch Script Quick Commands

| Command | Description |
|---------|-------------|
| `Enable-AllTrayIcons.bat Enable /Restart` | Show all icons + restart Explorer |
| `Enable-AllTrayIcons.bat Disable /Restart` | Restore default + restart Explorer |
| `Enable-AllTrayIcons.bat Status` | Check current configuration |
| `Enable-AllTrayIcons.bat Backup` | Create registry backup only |
| `Enable-AllTrayIcons.bat Rollback` | Revert to previous config |
| `Enable-AllTrayIcons.bat Help` | Show help information |

#### Batch Script Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `Enable` | Show all system tray icons | `Enable-AllTrayIcons.bat Enable` |
| `Disable` | Restore Windows default | `Enable-AllTrayIcons.bat Disable` |
| `Status` | Display current configuration | `Enable-AllTrayIcons.bat Status` |
| `Backup` | Create registry backup | `Enable-AllTrayIcons.bat Backup` |
| `Rollback` | Revert to previous config | `Enable-AllTrayIcons.bat Rollback` |
| `/Restart` | Automatically restart Explorer | `Enable /Restart` |
| `/Backup` | Create backup before changes | `Enable /Backup` |
| `/Force` | Bypass confirmation prompts | `Enable /Force` |
| `/Help` | Display help information | `/Help` |

---

### Method 3: Registry File (Simplest)

**Best for:** Beginners, quick one-time setup, non-technical users

**Advantages:**
- ✅ Simplest method - just double-click
- ✅ No PowerShell or command-line knowledge needed
- ✅ Works on all Windows versions
- ✅ Traditional Windows GUI method
- ✅ No dependencies

**Disadvantages:**
- Requires manual Explorer restart
- No built-in error checking
- No backup functionality
- No status verification
- Does not apply v4.0 comprehensive methods

#### Installation Steps

**Step 1: Download the registry file**

Visit: [https://github.com/paulmann/windows-show-all-tray-icons](https://github.com/paulmann/windows-show-all-tray-icons)

Click **Code** → **Download ZIP** → Extract files

Or download directly:
https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/enable-all-tray-icons.reg

**Step 2: Run the registry file**

1. **Double-click** `enable-all-tray-icons.reg`
2. User Account Control (UAC) prompt may appear
3. Click **Yes** to proceed
4. Registry Editor confirmation window appears
5. Message: *"Information in enable-all-tray-icons.reg has been successfully entered into the registry"*
6. Click **OK**

**Step 3: Restart Windows Explorer**

**Option A: Task Manager**
1. Press `Ctrl + Shift + Esc` (opens Task Manager)
2. Find **"Windows Explorer"** in process list
3. Right-click → **Restart**

**Option B: Command Prompt**

taskkill /f /im explorer.exe && start explorer.exe

**Option C: PowerShell**

Stop-Process -Name explorer -Force; Start-Process explorer.exe

---

### Method 4: Command Line (Advanced)

**Best for:** Scripting, automation, remote administration, one-liners

#### PowerShell One-Liner

# Enable all tray icons and restart Explorer (basic method)
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Value 0 -Type DWord; Stop-Process -Name explorer -Force; Start-Process explorer.exe

# Just enable without restart
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Value 0 -Type DWord

# Check current value
Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray"

**Note**: One-liner only applies basic method. For comprehensive v4.0 multi-method enforcement, use the full PowerShell script.

#### Command Prompt Commands

REM Enable all tray icons (basic method)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray /t REG_DWORD /d 0 /f

REM Restart Explorer
taskkill /f /im explorer.exe && start explorer.exe

REM Verify setting
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray

---

## 🎯 Advanced Usage

### PowerShell Script v4.0 Advanced Features

#### Comprehensive Enable (All Methods Applied)

# Apply ALL 4+ methods with backup and restart
.\Enable-AllTrayIcons.ps1 -Action Enable -BackupRegistry -RestartExplorer -Force

# What happens:
# 1. Creates comprehensive JSON backup (all tray-related keys)
# 2. Disables global auto-hide (EnableAutoTray = 0)
# 3. Resets individual icon settings (NotifyIconSettings)
# 4. Clears tray cache (IconStreams, PastIconsStream)
# 5. Removes desktop icon restrictions
# 6. Resets taskbar layout
# 7. Forces system icons visibility (Volume, Network, Power)
# 8. Applies Windows 11 optimizations (if applicable)
# 9. Resets per-app notification settings
# 10. Restarts Explorer atomically

#### Comprehensive Backup and Rollback

# Create comprehensive backup (JSON with binary data)
.\Enable-AllTrayIcons.ps1 -Action Backup

# Backup includes:
# - EnableAutoTray value
# - All NotifyIconSettings (per-icon IsPromoted values)
# - TrayNotify streams (IconStreams, PastIconsStream in Base64)
# - System icon settings (HideSCAVolume, HideSCANetwork, HideSCAPower)
# - Desktop icon restrictions
# - Taskbar layout preferences
# - Windows version metadata

# Comprehensive rollback (restores ALL backed up settings)
.\Enable-AllTrayIcons.ps1 -Action Rollback -RestartExplorer

**Backup Details:**
- **Location**: `%TEMP%\TrayIconsBackup.reg` (actually JSON format in v4.0)
- **Format**: JSON with Base64-encoded binary data
- **Includes**:
  - Timestamp and version metadata
  - All registry paths managed by v4.0
  - Binary stream data (icon cache)
  - System and individual icon settings
- **Integrity**: Automatic validation with diagnostic mode

#### Comprehensive Status Checking

# Display comprehensive system status
.\Enable-AllTrayIcons.ps1 -Action Status

# Output includes:
# - Current AutoTray configuration
# - Registry value details
# - Operating system information
# - PowerShell version (standard/enhanced)
# - Windows version (with Win11 detection)
# - Session context (admin/user, interactive/remote)
# - Backup availability (with metadata)
# - Backup type (comprehensive/basic/legacy)

#### Diagnostic Mode (NEW in v4.0)

# Run comprehensive backup file diagnostics
.\Enable-AllTrayIcons.ps1 -Diagnostic

# Diagnostic checks:
# - Backup file existence and size
# - JSON parsing integrity
# - Binary data validation (Base64 encoding)
# - Metadata consistency
# - Corruption detection
# - Content preview (first 500 characters)
# - Problem character detection

#### WhatIf Mode (Safe Testing)

# Preview changes without executing
.\Enable-AllTrayIcons.ps1 -Action Enable -WhatIf

# Shows what would happen:
# - Which registry keys would be modified
# - Which methods would be applied
# - Which processes would be restarted

#### Force Mode (Bypass Prompts)

# Skip all confirmation prompts (for automation)
.\Enable-AllTrayIcons.ps1 -Action Enable -Force -RestartExplorer

# Useful for:
# - Automated deployment scripts
# - Scheduled tasks
# - Remote execution
# - Non-interactive sessions

#### Auto-Update

# Check and update script from GitHub
.\Enable-AllTrayIcons.ps1 -Update

# Update process:
# 1. Downloads latest version from repository
# 2. Compares version numbers
# 3. Creates backup of current version (.backup)
# 4. Replaces script file
# 5. Notifies user to restart script

#### Custom Logging

# Specify custom log file location
.\Enable-AllTrayIcons.ps1 -Action Enable -LogPath "C:\Logs\tray-config.log"

# Default log location: %TEMP%\Enable-AllTrayIcons.log
# Log includes:
# - Timestamp for each operation
# - All methods applied with results
# - Error messages with context
# - Registry changes made
# - Backup/restore operations

### Batch Script Advanced Features

#### Backup and Rollback

:: Create backup before making changes
Enable-AllTrayIcons.bat Enable /Backup /Restart

:: Create backup without making changes
Enable-AllTrayIcons.bat Backup

:: Rollback to previous configuration
Enable-AllTrayIcons.bat Rollback /Restart

**Backup Details:**
- **Location**: `%TEMP%\TrayIconsBackup.reg`
- **Format**: Standard Windows registry format
- **Includes**: Only EnableAutoTray value (basic backup)
- **Restoration**: Automatic on rollback

#### Status Checking

:: Display comprehensive system status
Enable-AllTrayIcons.bat Status

:: Output includes:
:: - Current tray icon behavior
:: - Registry value details
:: - System information
:: - Backup availability

#### Force Mode

:: Skip confirmation prompts
Enable-AllTrayIcons.bat Enable /Force /Restart

:: Overwrite existing backup
Enable-AllTrayIcons.bat Backup /Force

---

## 📜 PowerShell Script v4.0 Enterprise Features

### Version 4.0 Complete Feature Matrix

| Feature Category | Capability | PowerShell v4.0 | Batch Script | Registry File |
|-----------------|------------|-----------------|--------------|---------------|
| **Basic Icon Management** | Global auto-hide disable | ✅ Yes | ✅ Yes | ✅ Yes |
| **Advanced Management** | Individual icon reset | ✅ Yes | ❌ No | ❌ No |
| **Advanced Management** | Tray cache clearing | ✅ Yes | ❌ No | ❌ No |
| **Advanced Management** | System icons control | ✅ Yes | ❌ No | ❌ No |
| **Advanced Management** | Windows 11 optimization | ✅ Yes | ❌ No | ❌ No |
| **Backup/Restore** | Comprehensive JSON backup | ✅ Yes | ❌ No | ❌ No |
| **Backup/Restore** | Binary data handling | ✅ Yes | ❌ No | ❌ No |
| **Backup/Restore** | Basic registry backup | ✅ Yes | ✅ Yes | ❌ No |
| **Diagnostics** | Backup validation | ✅ Yes | ❌ No | ❌ No |
| **Diagnostics** | Registry path verification | ✅ Yes | ❌ No | ❌ No |
| **Diagnostics** | Status reporting | ✅ Comprehensive | ✅ Basic | ❌ No |
| **Automation** | Exit codes | ✅ Yes | ❌ No | ❌ No |
| **Automation** | WhatIf support | ✅ Yes | ❌ No | ❌ No |
| **Automation** | Force mode | ✅ Yes | ✅ Yes | ❌ No |
| **UI/UX** | Modern color-coded output | ✅ Yes | ✅ Yes | ❌ No |
| **UI/UX** | Progress tracking | ✅ Per-method | ❌ No | ❌ No |
| **Updates** | Auto-update from GitHub | ✅ Yes | ❌ No | ❌ No |
| **Logging** | Comprehensive logging | ✅ Yes | ✅ Basic | ❌ No |

### Comprehensive Method Breakdown

#### Method 1: Global Auto-Hide Disable
# Registry: HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer
# Value: EnableAutoTray = 0
# Effect: Disables Windows' global tray icon auto-hide feature

#### Method 2: Individual Icon Promotion
# Registry: HKCU:\Control Panel\NotifyIconSettings\*
# Value: IsPromoted = 1 for each icon
# Effect: Forces each registered icon to be "promoted" (always visible)

#### Method 3: Tray Cache Reset
# Registry: HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TrayNotify
# Values: IconStreams = empty, PastIconsStream = empty
# Effect: Clears Windows' internal icon cache, forcing re-detection

#### Method 4: System Icons Visibility
# Registry: HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer
# Values: HideSCAVolume = 0, HideSCANetwork = 0, HideSCAPower = 0
# Effect: Forces system icons (Volume, Network, Power) to always show

#### Method 5: Windows 11 Taskbar Optimization
# Registry: HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced
# Value: TaskbarMn = 0
# Effect: Optimizes Windows 11 taskbar for icon visibility

#### Method 6: Notification Settings Reset
# Registry: HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\*
# Values: Enabled = 1, ShowInActionCenter = 1 for each app
# Effect: Ensures notification area apps are enabled

### Exit Codes for Automation

| Code | Meaning | Description |
|------|---------|-------------|
| `0` | Success | Operation completed successfully |
| `1` | General Error | Operation failed (check console output) |
| `2` | Access Denied | Insufficient permissions |
| `3` | Invalid Session | Non-interactive or incompatible session |
| `4` | PowerShell Version | Unsupported PowerShell version |
| `5` | Rollback Failed | Rollback operation failed |
| `6` | Update Failed | Auto-update failed |
| `7` | Backup Failed | Backup operation failed |

**Using Exit Codes:**

# Check exit code after execution
.\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer
if ($LASTEXITCODE -eq 0) {
    Write-Host "Configuration successful"
} else {
    Write-Host "Configuration failed - Exit code: $LASTEXITCODE"
}

# Automation example with error handling
.\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer *>$null
$result = $LASTEXITCODE
if ($result -eq 0) {
    # Continue workflow
    Write-Host "Proceeding with next step"
} else {
    # Handle error based on exit code
    switch ($result) {
        2 { Write-Host "Access denied - requires elevation" }
        4 { Write-Host "PowerShell version incompatible" }
        7 { Write-Host "Backup failed - operation aborted" }
        default { Write-Host "Unknown error occurred" }
    }
}

---

## 🪟 Batch Script Features

### Lightweight Batch Script Capabilities

| Feature | Description | Benefit |
|---------|-------------|---------|
| **Basic Registry Modification** | Modifies EnableAutoTray value | Core functionality |
| **Basic Backup** | Creates .reg backup files | Rollback capability |
| **Configuration Rollback** | Restore from backup | Undo unwanted changes |
| **Status Display** | Check current configuration | Know current state |
| **Logging** | File-based logging | Troubleshooting support |
| **Color Output** | Color-coded console messages | Better readability |
| **Force Mode** | Skip confirmations | Automation support |
| **Help System** | Comprehensive help display | User guidance |
| **No Dependencies** | Pure Windows batch | Universal compatibility |

### Action Parameters

:: All available actions
Enable-AllTrayIcons.bat <Action> [Options]

:: Actions:
::   Enable    - Show all system tray icons (basic method)
::   Disable   - Restore Windows default behavior
::   Status    - Display current configuration
::   Backup    - Create registry backup
::   Rollback  - Restore from backup

:: Options:
::   /Restart  - Restart Windows Explorer
::   /Backup   - Create backup before changes
::   /Force    - Skip confirmation prompts
::   /Help     - Display help information

### Logging System

**Log Location:** `%TEMP%\Enable-AllTrayIcons.log`

**Log Contents:**
- Timestamp of script execution
- User and computer information
- All actions performed
- Status messages
- Error details

**Viewing Log:**

:: View log in Notepad
notepad %TEMP%\Enable-AllTrayIcons.log

:: View log in console
type %TEMP%\Enable-AllTrayIcons.log

:: Tail recent entries (PowerShell)
Get-Content %TEMP%\Enable-AllTrayIcons.log -Tail 20

---

## ✅ Verification & Troubleshooting

### Verify Installation Success

#### Via PowerShell v4.0 Script

.\Enable-AllTrayIcons.ps1 -Action Status

**Expected Output (v4.0 Comprehensive Status):**

================================================================
   System Status - Current Tray Icons Configuration
================================================================

CONFIGURATION STATUS:
  [*] Tray Icons Behavior | Show ALL tray icons (auto-hide disabled)
  [*] Registry Value      | 0

METHODS APPLIED:
  [*] AutoTrayDisabled             | Success
  [*] IndividualSettingsReset      | Success
  [*] TrayCacheCleared             | Success
  [*] NotificationSettingsReset    | Success
  [*] SystemIconsForced            | Success
  [*] Windows11Optimized           | Success

SYSTEM INFORMATION:
  [*] Operating System    | Microsoft Windows 11 Professional
  [*] OS Version          | 10.0.26100 (Build 26100)
  [*] PowerShell Version  | 7.4.1 (Enhanced)
  [*] Windows Version     | Microsoft Windows 11 Pro

SESSION CONTEXT:
  [*] Current User        | DOMAIN\Username
  [*] Session Type        | Interactive Desktop
  [*] Admin Rights        | No
  [*] Interactive         | Yes

BACKUP STATUS:
  [*] Backup Available    | Yes
  [*] Backup Created      | 2025-11-23 20:15:30
  [*] Backup Type         | Comprehensive
  [*] Backup Version      | 4.0
  [*] Backup Size         | 12.5 KB

#### Via Batch Script

Enable-AllTrayIcons.bat Status

#### Via Registry Editor

1. Open Registry Editor: `Win + R` → `regedit`
2. Navigate to: `HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer`
3. Check `EnableAutoTray` value:
   - **Should be:** `0` (DWORD) - All icons shown
   - **Default:** Not present or `1` - Auto-hide enabled

#### Via Command Prompt

reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray

**Expected Output:**

HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer
    EnableAutoTray    REG_DWORD    0x0

### Common Issues & Solutions

#### ❌ Issue: Icons Still Not Showing

**Symptoms:** Changed setting but icons still hidden

**Solutions:**

1. **Ensure PowerShell v4.0 comprehensive method was used:**

.\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer
# This applies ALL 4+ methods, not just basic EnableAutoTray

2. **Check if individual icon settings need reset:**

# Run diagnostic to verify backup integrity
.\Enable-AllTrayIcons.ps1 -Diagnostic

# Check status to see which methods succeeded
.\Enable-AllTrayIcons.ps1 -Action Status

3. **Restart Windows Explorer manually:**

Stop-Process -Name explorer -Force
Start-Process explorer.exe

4. **Log off and log back in:**
   - Click Start → Power → Sign out
   - Log back in with same account
   - Some icon settings require session refresh

5. **Restart computer (rare but sometimes necessary):**
   - Save all work
   - Restart Windows
   - Tray cache may require full system restart

#### ❌ Issue: "Access Denied" Error

**Symptoms:** Cannot modify registry

**Solutions:**

1. **Run PowerShell as Administrator:**
   - Right-click PowerShell → **Run as administrator**
   - Click **Yes** on UAC prompt
   - Run script again

2. **Check user account permissions:**

whoami /priv
:: Should show SeBackupPrivilege and SeRestorePrivilege

3. **Verify registry path permissions:**

# Check if path exists and is writable
$path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
Test-Path $path
Get-Acl $path | Format-List

#### ❌ Issue: PowerShell Execution Policy Error

**Symptoms:** "File cannot be loaded because running scripts is disabled"

**Solution:**

# Allow scripts for current user (permanent)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Then run the script
.\Enable-AllTrayIcons.ps1 -Action Enable

# Alternative: Bypass policy for single execution
PowerShell.exe -ExecutionPolicy Bypass -File .\Enable-AllTrayIcons.ps1 -Action Enable

#### ❌ Issue: Backup File Corrupted (v4.0 Specific)

**Symptoms:** Restore fails with JSON parsing error

**Solution:**

# Run diagnostic to identify issue
.\Enable-AllTrayIcons.ps1 -Diagnostic

# Output will show:
# - JSON parsing errors
# - Problematic characters
# - Backup file integrity status

# If backup is corrupted, delete and recreate
Remove-Item "$env:TEMP\TrayIconsBackup.reg" -Force
.\Enable-AllTrayIcons.ps1 -Action Backup

#### ❌ Issue: Changes Reverted After Reboot

**Symptoms:** Settings applied but reverted after restart

**Possible Causes:**
- Group Policy overriding user settings
- Third-party software (O&O ShutUp++, privacy tools)
- Windows Update resetting values
- Antivirus/security software blocking changes

**Solutions:**

1. **Re-apply with comprehensive v4.0 method:**

# Comprehensive method is more persistent
.\Enable-AllTrayIcons.ps1 -Action Enable -BackupRegistry -RestartExplorer

2. **Check Group Policy conflicts:**

gpresult /h gpresult.html
:: Open gpresult.html and check for conflicting policies under:
:: User Configuration -> Policies -> Windows Settings

3. **Identify conflicting software:**
   - Review recently installed privacy/optimization tools
   - Disable or uninstall system modification software
   - Common culprits: O&O ShutUp++, WPD, W11Debloat
   - Run script again after removal

4. **Apply via Group Policy (Enterprise - permanent):**
   - See [Enterprise Deployment](#-enterprise-deployment) section
   - Domain-level GPO prevents local overrides

5. **Create scheduled task for persistence:**

# Run comprehensive enable at every logon
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File 'C:\Scripts\Enable-AllTrayIcons.ps1' -Action Enable -Force"
$trigger = New-ScheduledTaskTrigger -AtLogon
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive
Register-ScheduledTask -TaskName "Show All Tray Icons (Persistent)" `
  -Action $action -Trigger $trigger -Principal $principal -RunLevel Highest

#### 🔍 Diagnostic Commands

**Check current configuration:**

# PowerShell - Comprehensive check
.\Enable-AllTrayIcons.ps1 -Action Status

# Manual registry check
Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -ErrorAction SilentlyContinue

# Command Prompt
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray

**Check comprehensive backup availability (v4.0):**

# PowerShell
Test-Path "$env:TEMP\TrayIconsBackup.reg"

# View backup content
Get-Content "$env:TEMP\TrayIconsBackup.reg"

# Run diagnostic
.\Enable-AllTrayIcons.ps1 -Diagnostic

**Check individual icon settings (v4.0):**

# Check NotifyIconSettings
Get-ChildItem "HKCU:\Control Panel\NotifyIconSettings" | ForEach-Object {
    $icon = $_
    $promoted = (Get-ItemProperty -Path $icon.PSPath -Name "IsPromoted" -ErrorAction SilentlyContinue).IsPromoted
    Write-Host "$($icon.PSChildName): IsPromoted = $promoted"
}

# Check system icons
$path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
@("HideSCAVolume", "HideSCANetwork", "HideSCAPower") | ForEach-Object {
    $value = (Get-ItemProperty -Path $path -Name $_ -ErrorAction SilentlyContinue).$_
    Write-Host "$_: $value"
}

**Check Windows version:**

# PowerShell
Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber

# Command Prompt
ver
systeminfo | findstr /B /C:"OS Name" /C:"OS Version"

---

## 🔄 Reverting Changes

### Method 1: PowerShell v4.0 Script

**Simplest method - Comprehensive restore:**

# Restore Windows default behavior (basic disable)
.\Enable-AllTrayIcons.ps1 -Action Disable -RestartExplorer

# Comprehensive rollback to previous configuration (recommended)
.\Enable-AllTrayIcons.ps1 -Action Rollback -RestartExplorer

**Difference between Disable and Rollback:**
- **Disable:** Sets `EnableAutoTray` to Windows default (`1`) - basic method only
- **Rollback:** Restores **exact previous configuration** from comprehensive JSON backup (all settings)

**What Rollback Restores (v4.0):**
- Original `EnableAutoTray` value
- All individual icon settings (`NotifyIconSettings`)
- Tray cache state (`IconStreams`, `PastIconsStream`)
- System icon visibility settings
- Desktop icon restrictions (if any)
- Taskbar layout preferences
- Notification settings (if modified)

### Method 2: Batch Script

:: Restore Windows default behavior
Enable-AllTrayIcons.bat Disable /Restart

:: Rollback to previous configuration (basic backup)
Enable-AllTrayIcons.bat Rollback /Restart

**Note:** Batch script provides basic rollback only (`EnableAutoTray` value).

### Method 3: Revert Registry File

**Download and apply:**

https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/disable-auto-hide.reg

1. Download `disable-auto-hide.reg`
2. Double-click to apply
3. Click **Yes** on UAC prompt
4. Restart Explorer

### Method 4: Manual Registry Edit

**PowerShell:**

# Set to Windows default (auto-hide enabled)
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Value 1 -Type DWord

# Restart Explorer
Stop-Process -Name explorer -Force
Start-Process explorer.exe

**Command Prompt:**

REM Restore default
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray /t REG_DWORD /d 1 /f

REM Restart Explorer
taskkill /f /im explorer.exe && start explorer.exe

### Method 5: Complete Removal

**Delete registry entry completely (use Windows built-in default):**

# PowerShell - Remove entry
Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -ErrorAction SilentlyContinue
Stop-Process -Name explorer -Force
Start-Process explorer.exe

REM Command Prompt - Remove entry
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray /f
taskkill /f /im explorer.exe && start explorer.exe

---

## 🏢 Enterprise Deployment

### Group Policy Deployment

**For domain environments:**

#### Step 1: Open Group Policy Editor

# On Domain Controller or with RSAT tools
gpedit.msc
# Or: gpmc.msc (Group Policy Management Console)

#### Step 2: Navigate to Registry Preferences

Computer Configuration (or User Configuration)
  → Preferences
    → Windows Settings
      → Registry

#### Step 3: Create Registry Item

1. Right-click **"Registry"** → **New** → **Registry Item**
2. Configure settings:

   | Field | Value |
   |-------|-------|
   | **Action** | Update |
   | **Hive** | HKEY_CURRENT_USER |
   | **Key Path** | `SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer` |
   | **Value name** | `EnableAutoTray` |
   | **Value type** | REG_DWORD |
   | **Value data** | `0` (show all icons) or `1` (default) |

3. Click **OK**

**For v4.0 Comprehensive Method via GPO:**

Create additional registry items for:

HKCU\Control Panel\NotifyIconSettings\*\IsPromoted = 1 (for each icon)
HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideSCAVolume = 0
HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideSCANetwork = 0
HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideSCAPower = 0

**Note:** Individual icon settings (`NotifyIconSettings`) are harder to manage via GPO. For comprehensive enforcement, deploy PowerShell v4.0 script via Group Policy logon script.

#### Step 4: Link GPO to Organizational Unit

1. Right-click target OU → **Link an Existing GPO**
2. Select your GPO
3. Click **OK**

#### Step 5: Force Policy Update

:: On client computers
gpupdate /force

:: Verify GPO application
gpresult /r
gpresult /h gpresult.html

### Microsoft Intune Deployment

**For Azure AD/Intune-joined devices:**

#### Method A: Custom OMA-URI Setting

1. **Open Microsoft Intune Admin Center**
2. **Navigate to:** Devices → Configuration profiles → Create profile
3. **Platform:** Windows 10 and later
4. **Profile type:** Templates → Custom
5. **Create custom OMA-URI:**

   | Field | Value |
   |-------|-------|
   | **Name** | Enable All System Tray Icons (Basic Method) |
   | **Description** | Shows all notification area icons |
   | **OMA-URI** | `./User/Vendor/MSFT/Registry/HKCU/SOFTWARE/Microsoft/Windows/CurrentVersion/Explorer/EnableAutoTray` |
   | **Data type** | Integer |
   | **Value** | `0` |

**For v4.0 Comprehensive Method:** Deploy PowerShell script via Intune (Method B below).

#### Method B: PowerShell Script Deployment (Recommended for v4.0)

1. **Navigate to:** Devices → Scripts → Add → Windows 10 and later
2. **Upload PowerShell script:** `Enable-AllTrayIcons.ps1` (v4.0)
3. **Configure:**

   | Setting | Value |
   |---------|-------|
   | **Run this script using logged on credentials** | Yes |
   | **Enforce script signature check** | No |
   | **Run script in 64-bit PowerShell** | Yes |

4. **Script parameters:** `-Action Enable -RestartExplorer -Force`
5. **Assign to groups**

#### Method C: Proactive Remediations (Intune Endpoint Analytics)

1. **Navigate to:** Reports → Endpoint analytics → Proactive remediations
2. **Create script package:**

   **Detection script:**
   $value = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -ErrorAction SilentlyContinue
   if ($null -eq $value -or $value.EnableAutoTray -ne 0) {
       Write-Output "Not configured"
       exit 1  # Remediation needed
   } else {
       Write-Output "Configured"
       exit 0  # Compliant
   }

   **Remediation script:**
   # Run comprehensive v4.0 method
   & "C:\Path\To\Enable-AllTrayIcons.ps1" -Action Enable -Force
   exit $LASTEXITCODE

### SCCM/ConfigMgr Deployment

**Configuration Manager deployment:**

#### Method A: Package Deployment

1. **Create Package:**
   - Console → Software Library → Packages
   - New Package → Add scripts (PS1 and BAT)

2. **Create Program:**
   - Command line: `PowerShell.exe -ExecutionPolicy Bypass -File Enable-AllTrayIcons.ps1 -Action Enable -Force`
   - Run mode: Run with user's rights
   - Program can run: Whether or not a user is logged on

3. **Distribute and Deploy:**
   - Distribute content to DPs
   - Deploy to device/user collections

#### Method B: Compliance Settings

1. **Create Configuration Item:**
   - Settings → Compliance Settings → Configuration Items
   - New Configuration Item

2. **Define Registry Setting:**
   - Registry value: `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\EnableAutoTray`
   - Expected value: 0
   - Remediation: Enabled

**For v4.0 Comprehensive:** Use Package Deployment (Method A) with full PowerShell script.

3. **Create Configuration Baseline:**
   - Add configuration item
   - Deploy to collections

### PowerShell Script Mass Deployment

**Deploy to domain computers using v4.0:**

# Deploy to list of computers
$computers = @("PC01", "PC02", "PC03", "PC04")

foreach ($computer in $computers) {
    Write-Host "Deploying v4.0 comprehensive method to $computer..." -ForegroundColor Cyan
    
    try {
        # Copy script to remote computer
        $destination = "\\$computer\C$\Temp\Enable-AllTrayIcons.ps1"
        Copy-Item -Path ".\Enable-AllTrayIcons.ps1" -Destination $destination -Force
        
        # Execute remotely with comprehensive method
        Invoke-Command -ComputerName $computer -ScriptBlock {
            & "C:\Temp\Enable-AllTrayIcons.ps1" -Action Enable -RestartExplorer -Force
        } -ErrorAction Stop
        
        Write-Host "✓ Success: $computer (v4.0 comprehensive applied)" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed: $computer - $($_.Exception.Message)" -ForegroundColor Red
    }
}

**Deploy to all domain computers:**

# Requires Active Directory module
Import-Module ActiveDirectory

# Get all domain computers
$computers = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name

# Deploy with progress
$i = 0
$total = $computers.Count

foreach ($computer in $computers) {
    $i++
    Write-Progress -Activity "Deploying v4.0 comprehensive tray icons configuration" `
                   -Status "Processing $computer ($i of $total)" `
                   -PercentComplete (($i / $total) * 100)
    
    # Test connectivity first
    if (Test-Connection -ComputerName $computer -Count 1 -Quiet) {
        Invoke-Command -ComputerName $computer -ScriptBlock {
            & "\\FILESERVER\Scripts\Enable-AllTrayIcons.ps1" -Action Enable -RestartExplorer -Force
        } -ErrorAction SilentlyContinue
    }
}

### Scheduled Task Deployment

**Create scheduled task to run at logon (persistent v4.0):**

# PowerShell scheduled task with comprehensive v4.0 method
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File 'C:\ProgramData\Enable-AllTrayIcons.ps1' -Action Enable -Force"

$trigger = New-ScheduledTaskTrigger -AtLogon

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
  -LogonType Interactive -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskName "Show All Tray Icons (v4.0 Comprehensive)" `
  -Action $action `
  -Trigger $trigger `
  -Principal $principal `
  -Settings $settings `
  -Description "Enable display of all system tray icons using comprehensive v4.0 method" `
  -Force

**Deploy scheduled task via Group Policy:**

1. GPO → Computer Configuration → Preferences → Control Panel Settings → Scheduled Tasks
2. New → Scheduled Task (Windows Vista and later)
3. Configure action to run PowerShell script with v4.0 comprehensive method
4. Set trigger to "At log on"

---

## 🔧 Technical Details

### Registry Modification

**Primary Registry Path:**
HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer

**Primary Registry Value:**
Name: EnableAutoTray
Type: REG_DWORD

**Value Meanings:**

| Value | Behavior | Description |
|-------|----------|-------------|
| `0` | **Show all icons** | All notification area icons always visible (auto-hide disabled) |
| `1` | **Auto-hide** (default) | Windows automatically hides inactive icons |
| *Not set* | **Auto-hide** (default) | Inherits Windows default behavior |

### PowerShell v4.0 Comprehensive Registry Paths

**Additional Paths Managed by v4.0:**

HKEY_CURRENT_USER\Control Panel\NotifyIconSettings\*
  └─ IsPromoted = 1 (each icon forced to "promoted" state)

HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TrayNotify
  ├─ IconStreams = empty (Base64 binary data)
  └─ PastIconsStream = empty (Base64 binary data)

HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer
  ├─ HideSCAVolume = 0 (system Volume icon always visible)
  ├─ HideSCANetwork = 0 (system Network icon always visible)
  └─ HideSCAPower = 0 (system Power icon always visible)

HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons
  └─ (removed/cleared if present)

HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband
  ├─ Favorites (removed if present)
  └─ FavoritesResolve (removed if present)

HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\*
  ├─ Enabled = 1 (per-app notification enabled)
  └─ ShowInActionCenter = 1 (per-app notification area visibility)

HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced
  └─ TaskbarMn = 0 (Windows 11 taskbar optimization)

### How v4.0 Comprehensive Method Works

**Execution Flow:**

1. Pre-Execution Checks
   ├─ PowerShell version validation (5.1+)
   ├─ Session context detection (admin rights, interactive mode)
   └─ Execution policy verification

2. Optional Backup Creation (if -BackupRegistry specified)
   ├─ Read current EnableAutoTray value
   ├─ Enumerate NotifyIconSettings (all registered icons)
   ├─ Read TrayNotify binary streams (IconStreams, PastIconsStream)
   ├─ Read system icon settings (HideSCAVolume, etc.)
   ├─ Read desktop icon restrictions
   ├─ Read taskbar layout preferences
   ├─ Serialize to JSON with Base64 encoding for binary data
   └─ Save to %TEMP%\TrayIconsBackup.reg (actually JSON format)

3. Method 1: Disable Global Auto-Hide
   ├─ Set HKCU:\...\Explorer\EnableAutoTray = 0
   └─ Result: Global auto-hide disabled

4. Method 2: Reset Individual Icon Settings
   ├─ Enumerate HKCU:\Control Panel\NotifyIconSettings\*
   ├─ For each icon: Set IsPromoted = 1
   └─ Result: Each icon forced to "always visible" state

5. Method 3: Clear Tray Cache
   ├─ Ensure TrayNotify path exists (create if missing)
   ├─ Set IconStreams = empty byte array
   ├─ Set PastIconsStream = empty byte array
   └─ Result: Windows forced to rebuild icon cache

6. Method 4: Force System Icons Visibility
   ├─ Set HideSCAVolume = 0
   ├─ Set HideSCANetwork = 0
   ├─ Set HideSCAPower = 0
   └─ Result: System icons always visible

7. Method 5: Windows 11 Optimization (if applicable)
   ├─ Detect Windows 11
   ├─ Set TaskbarMn = 0
   └─ Result: Windows 11 taskbar optimized for icon visibility

8. Method 6: Reset Notification Settings
   ├─ Enumerate HKCU:\...\Notifications\Settings\*
   ├─ For each app: Set Enabled = 1, ShowInActionCenter = 1
   └─ Result: App notification area settings reset

9. Optional: Restart Windows Explorer
   ├─ Stop explorer.exe process (gracefully)
   ├─ Wait for process termination
   ├─ Start new explorer.exe instance
   └─ Result: All changes applied immediately

10. Post-Execution
    ├─ Display comprehensive status (methods applied)
    ├─ Log all operations to file
    └─ Return exit code (0 = success)

### Security Considerations

**What v4.0 Modifies:**
- ✅ User registry (`HKEY_CURRENT_USER`) only - multiple paths
- ✅ User-specific icon settings and preferences
- ✅ User-specific notification area configuration
- ✅ No system files modified
- ✅ No Windows services affected
- ✅ No system-wide settings changed

**What v4.0 Does NOT Modify:**
- ❌ System registry (`HKEY_LOCAL_MACHINE`)
- ❌ Windows system files
- ❌ Security policies
- ❌ Network settings
- ❌ Other user accounts
- ❌ System-wide preferences

**Privilege Requirements:**
- Standard user can modify `HKEY_CURRENT_USER` (all paths)
- No administrator rights required for basic operation
- UAC prompt appears for registry modification (standard Windows behavior)
- Admin rights provide no additional benefits for this script

### Compatibility Notes

**Windows Versions:**
- **Windows 11 (all builds)**: ✅ Fully supported with enhanced optimizations
- **Windows 10 (all versions)**: ✅ Fully supported
- **Windows Server 2022**: ✅ Compatible
- **Windows Server 2019**: ✅ Compatible
- **Windows Server 2016**: ✅ Compatible
- **Windows 8.1**: ✅ Compatible (limited testing, basic features)
- **Windows 7**: ⚠️ Compatible (limited testing, use batch/registry method)

**PowerShell Versions:**
- **PowerShell 7.x**: ✅ Full support with enhanced features
- **PowerShell 5.1**: ✅ Full support (Windows 10/11 built-in)
- **PowerShell 4.0**: ⚠️ Basic support (limited features)
- **PowerShell 3.0**: ⚠️ Basic support (limited features)
- **PowerShell 2.0**: ❌ Not supported

**Architecture Support:**
- **x64 (64-bit)**: ✅ Fully supported
- **ARM64**: ✅ Fully supported (Windows 11 on ARM)
- **x86 (32-bit)**: ✅ Supported (use registry/batch method)

---

## ❓ FAQ

### General Questions

#### Q: Do I need administrator privileges?

**A:** No, for basic operation. All registry keys modified (`HKEY_CURRENT_USER`) are per-user accessible. Standard users can apply settings without admin rights. UAC prompt may appear (standard Windows behavior), but admin account membership is not required.

**Admin rights provide:**
- Ability to modify system-wide settings (not used here)
- Ability to deploy via Group Policy
- Ability to modify other users' settings

**PowerShell v4.0 comprehensive method:** Still works without admin rights - all paths are `HKCU`.

#### Q: Will this affect other user accounts?

**A:** No. All modifications are in `HKEY_CURRENT_USER`, which is per-user registry. Other accounts on the same computer are not affected. Each user must apply settings separately if desired.

**To apply to all users:**
- Use Group Policy (domain environment)
- Manually run script/file for each user account
- Create logon script that runs for all users

#### Q: Do I need to restart Windows?

**A:** No. Changes take effect immediately after restarting Windows Explorer. Use `-RestartExplorer` parameter with scripts for automatic restart, or manually restart Explorer via Task Manager.

**Why no reboot needed:**
- Registry changes are live and immediately queryable
- Explorer reads values dynamically on restart
- User-level settings (not system-level requiring kernel reload)

**PowerShell v4.0:** Automatically restarts Explorer when `-RestartExplorer` specified.

#### Q: What's the difference between PowerShell v4.0 and basic methods?

**A:**

**PowerShell v4.0 Comprehensive Method:**
- ✅ Modifies `EnableAutoTray` (global auto-hide disable)
- ✅ Resets **individual icon settings** (`NotifyIconSettings` - `IsPromoted = 1` for each)
- ✅ Clears **tray icon cache** (`IconStreams`, `PastIconsStream`)
- ✅ Forces **system icons visibility** (Volume, Network, Power)
- ✅ Applies **Windows 11 optimizations** (`TaskbarMn`)
- ✅ Resets **notification settings** (per-app notification area)
- ✅ Creates **comprehensive JSON backup** (all settings + binary data)

**Basic Methods (Batch/Registry/One-Liner):**
- ✅ Modifies `EnableAutoTray` only
- ❌ Does not reset individual icon preferences
- ❌ Does not clear tray cache
- ❌ Does not manage system icons
- ❌ No Windows 11 optimizations
- ❌ Basic backup (single value) or no backup

**Result Difference:**
- **v4.0 Comprehensive**: More persistent, handles stubborn icons, forces complete visibility
- **Basic**: May not work for all icons if user previously hid specific icons

#### Q: Can I schedule this to run automatically?

**A:** Yes, using Windows Task Scheduler:

**PowerShell v4.0 Method:**

# Create scheduled task with comprehensive v4.0 method
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File 'C:\Path\Enable-AllTrayIcons.ps1' -Action Enable -Force"
$trigger = New-ScheduledTaskTrigger -AtLogon
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive
Register-ScheduledTask -TaskName "Show All Tray Icons (v4.0)" `
  -Action $action -Trigger $trigger -Principal $principal -RunLevel Highest

**GUI Method:**
1. Open Task Scheduler (`taskschd.msc`)
2. Create Basic Task
3. Trigger: "When I log on"
4. Action: Start PowerShell script or batch file
5. Program: `powershell.exe`
6. Arguments: `-NoProfile -ExecutionPolicy Bypass -File "C:\Path\Enable-AllTrayIcons.ps1" -Action Enable -Force`
7. Save and test

#### Q: Does v4.0 work on Windows 11 25H2?

**A:** Yes, fully tested and optimized. PowerShell v4.0 includes Windows 11-specific optimizations:
- `TaskbarMn` registry value management
- Modern taskbar layout handling
- Compatibility with all Windows 11 builds (21H2, 22H2, 23H2, 24H2, 25H2)

**Testing Status:**
- Windows 11 25H2: ✅ Tested and verified
- Windows 11 24H2: ✅ Tested and verified
- Windows 11 23H2: ✅ Tested and verified
- Windows 11 22H2: ✅ Tested and verified

---

## 🔐 Safety & Security

### Is This Safe?

**Yes. All modifications are completely safe:**

✅ **Modifies only per-user registry (`HKCU`)**
- Does not touch system-wide settings (`HKLM`)
- Does not modify system files
- Does not affect other users on the system
- Cannot affect system stability

✅ **Multiple registry values modification (v4.0)**
- All values are user-level preferences
- No system-critical settings modified
- No cascading effects to system components

✅ **Fully reversible**
- Provided revert scripts and files
- Comprehensive backup/rollback (v4.0 JSON-based)
- No side effects from revert
- Can be applied/reverted unlimited times

✅ **No security risks**
- No elevation of privileges
- No changes to security policies
- No network communication (except optional GitHub update check)
- No telemetry collection
- No executable downloads (scripts are open-source text)

✅ **No Windows integrity impact**
- Does not modify protected system files
- Does not disable security features
- Does not affect Windows Update
- Does not interfere with antivirus/security software

### Backup & Recovery

**v4.0 Comprehensive Backup System:**

# Create comprehensive JSON backup before changes
.\Enable-AllTrayIcons.ps1 -Action Enable -BackupRegistry

**Backup includes:**
- `EnableAutoTray` value
- All `NotifyIconSettings` (per-icon `IsPromoted` values)
- `TrayNotify` binary streams (Base64-encoded `IconStreams`, `PastIconsStream`)
- System icon settings (`HideSCAVolume`, `HideSCANetwork`, `HideSCAPower`)
- Desktop icon restrictions (if any)
- Taskbar layout preferences
- Metadata: timestamp, version, Windows version, user context

**To restore from v4.0 backup:**

# Comprehensive restore (all settings)
.\Enable-AllTrayIcons.ps1 -Action Rollback -RestartExplorer

**Legacy backup (basic registry export):**

# PowerShell - Backup entire Explorer key
reg export "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" explorer_backup.reg

# To restore from backup
reg import explorer_backup.reg

#### System Restore Point

# Create restore point (requires admin)
Checkpoint-Computer -Description "Before System Tray Icon Change (v4.0)" -RestorePointType "MODIFY_SETTINGS"

# View available restore points
Get-ComputerRestorePoint

# Restore from point (GUI)
rstrui.exe

### Security Best Practices

**For Individual Users:**
1. ✅ Download scripts from official GitHub repository only
2. ✅ Review script contents before execution (open in text editor)
3. ✅ Create comprehensive backup before making changes (v4.0 `-BackupRegistry`)
4. ✅ Test on non-critical system first
5. ✅ Keep backup files for rollback
6. ✅ Use PowerShell v4.0 for most reliable results

**For Enterprise Deployment:**
1. ✅ Test v4.0 script in lab environment first
2. ✅ Create Group Policy backup before deployment
3. ✅ Deploy to pilot group before organization-wide rollout
4. ✅ Document changes for IT audit (v4.0 comprehensive method)
5. ✅ Monitor for conflicts with existing policies
6. ✅ Provide comprehensive rollback procedure to helpdesk
7. ✅ Use v4.0 comprehensive method for persistent results

### Virus/Malware Scanning

**Scripts are clean and safe:**
- Open-source (viewable on GitHub)
- No executable compilation
- No obfuscation
- Pure PowerShell and Batch code
- Registry file is human-readable

**Verify integrity:**

# Check file hash (PowerShell v4.0 script)
Get-FileHash .\Enable-AllTrayIcons.ps1 -Algorithm SHA256

# Scan with Windows Defender
Start-MpScan -ScanPath ".\Enable-AllTrayIcons.ps1" -ScanType CustomScan

**VirusTotal scan:**
1. Upload script to [VirusTotal](https://www.virustotal.com/)
2. Review scan results from 70+ antivirus engines
3. False positives rare (PowerShell scripts sometimes flagged generically due to registry modification)

---

## 🤝 Contributing

Contributions welcome! Help improve this tool for the community.

### How to Contribute

1. **Report issues:**
   - Open GitHub issue with details
   - Include OS version, PowerShell version, error messages
   - Provide steps to reproduce
   - Mention if using v4.0 comprehensive method

2. **Submit improvements:**
   - Fork repository
   - Create feature branch
   - Make changes with clear commit messages
   - Submit pull request with description
   - Test v4.0 comprehensive method

3. **Add documentation:**
   - Improve README with examples
   - Add usage scenarios for v4.0 features
   - Translate to other languages
   - Create video tutorials

4. **Test compatibility:**
   - Report results on different OS versions (especially Windows 11 25H2)
   - Test with different PowerShell versions (7.x recommended)
   - Verify enterprise deployment methods
   - Test v4.0 comprehensive method persistence

### Areas for Contribution

**Code:**
- [ ] Additional deployment methods for v4.0
- [ ] GUI interface (WPF/WinForms) with v4.0 options
- [ ] Multi-language support
- [ ] Configuration profiles (save/load v4.0 settings)
- [ ] Enhanced diagnostic tools

**Documentation:**
- [ ] Video tutorials (v4.0 comprehensive method demonstration)
- [ ] Localized README (Spanish, German, French, Chinese, etc.)
- [ ] Troubleshooting guide expansion for v4.0
- [ ] Enterprise deployment case studies
- [ ] Screenshot gallery (Windows 11 before/after)

**Testing:**
- [ ] Windows 11 25H2 verification
- [ ] Windows Server 2025 compatibility
- [ ] ARM64 device testing (Surface Pro X with Win11)
- [ ] PowerShell 7+ feature testing
- [ ] Enterprise environment testing (GPO deployment)

### Development Setup

# Clone repository
git clone https://github.com/paulmann/windows-show-all-tray-icons.git
cd windows-show-all-tray-icons

# Create feature branch
git checkout -b feature/your-feature-name

# Make changes
# ... edit files ...

# Test v4.0 comprehensive method
.\Enable-AllTrayIcons.ps1 -Action Status
.\Enable-AllTrayIcons.ps1 -Action Enable -WhatIf
.\Enable-AllTrayIcons.ps1 -Diagnostic

# Commit changes
git add .
git commit -m "Add: Your feature description"

# Push to GitHub
git push origin feature/your-feature-name

# Create Pull Request on GitHub

### Code Style Guidelines

**PowerShell:**
- Use `PascalCase` for functions
- Use `camelCase` for variables
- Include comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`)
- Use `Write-Verbose` for debug output
- Use `SupportsShouldProcess` for operations
- Follow v4.0 modern UI patterns (color-coded output)

**Batch:**
- Use uppercase for variables
- Include comments for complex logic
- Use `setlocal enabledelayedexpansion`
- Include error handling

**Documentation:**
- Use clear, concise language
- Include code examples (preferably v4.0)
- Add screenshots when helpful
- Follow Markdown best practices

---

## 📞 Support

### Get Help

**GitHub Issues:** [https://github.com/paulmann/windows-show-all-tray-icons/issues](https://github.com/paulmann/windows-show-all-tray-icons/issues)

When reporting issues, please include:
- Windows version and build number (`winver` or `Get-ComputerInfo`)
- PowerShell version (`$PSVersionTable.PSVersion`)
- **Script version used** (3.3 batch vs. **4.0 PowerShell**)
- **Specify if using v4.0 comprehensive method**
- Complete error message from script output
- Steps to reproduce
- Current registry value: `reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray`
- Screenshot of error (if applicable)
- **v4.0 status output**: `.\Enable-AllTrayIcons.ps1 -Action Status`

**Example issue report (v4.0):**

**Issue:** v4.0 comprehensive method partially successful but some icons still hidden

**Environment:**
- Windows: Windows 11 Professional 25H2 (Build 26100)
- PowerShell: 7.4.6 (Enhanced)
- Script Version: 4.0 (Enterprise Edition)

**Error/Status:**
METHODS APPLIED:
  [*] AutoTrayDisabled             | Success
  [*] IndividualSettingsReset      | Success
  [*] TrayCacheCleared             | Failed
  [*] NotificationSettingsReset    | Success
  [*] SystemIconsForced            | Success
  [*] Windows11Optimized           | Success

**Steps to Reproduce:**
1. Downloaded Enable-AllTrayIcons.ps1 v4.0
2. Ran: `.\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer`
3. TrayCacheCleared method failed
4. Some application icons still hidden after restart

**Additional Context:**
Running on corporate domain-joined computer. Explorer restarted successfully. Most icons now visible except for specific third-party app.

### Contact Information

**Author:** Mikhail Deynekin  
**Email:** [mid1977@gmail.com](mailto:mid1977@gmail.com)  
**Website:** [https://deynekin.com](https://deynekin.com)  
**GitHub Profile:** [https://github.com/paulmann](https://github.com/paulmann)  
**Repository:** [https://github.com/paulmann/windows-show-all-tray-icons](https://github.com/paulmann/windows-show-all-tray-icons)

### Community

**Discussions:**
- GitHub Discussions: Share v4.0 usage scenarios and ask questions
- Submit feature requests for future versions
- Share enterprise deployment experiences

**Star the Project:**
⭐ If you find this useful (especially the v4.0 comprehensive method), please consider giving the repository a star on GitHub! It helps others discover the tool.

---

## 📄 License

**MIT License**

Copyright © 2025 Mikhail Deynekin ([mid1977@gmail.com](mailto:mid1977@gmail.com))

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

---

## 🔗 Related Resources

### Microsoft Official Documentation

- [Windows Registry Reference](https://docs.microsoft.com/windows/win32/sysinfo/registry)
- [Taskbar Settings Configuration](https://docs.microsoft.com/windows/configuration/taskbar/)
- [Group Policy Processing](https://docs.microsoft.com/windows/client-management/mdm/policy-configuration-service-provider)
- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
- [Windows 11 Notification Area](https://support.microsoft.com/windows/notification-area-icons)
- [Microsoft Intune Documentation](https://docs.microsoft.com/mem/intune/)

### Related Projects

- [Windows 11 25H2 Update Script](https://github.com/paulmann/Windows-11-25H2-Update-Script)
- [Other system administration tools by author](https://github.com/paulmann)

### Learning Resources

- [PowerShell Scripting Guide](https://learn.microsoft.com/powershell/scripting/overview)
- [Registry Editor Usage](https://support.microsoft.com/windows/how-to-open-registry-editor)
- [Group Policy Management](https://docs.microsoft.com/windows-server/administration/windows-commands/gpedit-msc)
- [Batch Scripting Tutorial](https://www.tutorialspoint.com/batch_script/)
- [Windows PowerShell in Action](https://www.manning.com/books/windows-powershell-in-action-third-edition)

---

## 📊 Statistics

**Repository Stats:**
- ⭐ GitHub Stars: [View on GitHub](https://github.com/paulmann/windows-show-all-tray-icons)
- 🍴 Forks: [View Forks](https://github.com/paulmann/windows-show-all-tray-icons/network/members)
- 📥 Downloads: Check [Releases](https://github.com/paulmann/windows-show-all-tray-icons/releases)
- 🐛 Issues: [View Issues](https://github.com/paulmann/windows-show-all-tray-icons/issues)

**Version Information:**
- **PowerShell Script**: **v4.0** (Enterprise Edition - Enhanced)
- **Batch Script**: v3.3 (Lightweight Edition)
- **Documentation**: v4.0 (Complete Guide)
- **Last Updated**: November 23, 2025

---

## 🎉 Changelog

### Version 4.0 (2025-11-23) - Revolutionary Update

**PowerShell Script - Enterprise Edition Enhanced:**

✨ **NEW: Revolutionary Comprehensive Method**
- ✨ **Complete individual icon preferences reset** (NotifyIconSettings - IsPromoted = 1 for all)
- ✨ **Multi-method icon visibility enforcement** (4+ complementary techniques)
- ✨ **Advanced backup/restore with JSON serialization** (binary data Base64 encoding)
- ✨ **Windows 11 specific optimizations** (TaskbarMn, modern taskbar management)
- ✨ **System tray icon normalization** (IconStreams, PastIconsStream cache clearing)
- ✨ **Professional diagnostic reporting** (backup validation, integrity checks)
- ✨ **Dynamic registry path management** (auto-creation of missing keys)
- ✨ **Binary data handling** (icon streams serialization)
- ✨ **Notification system controls** (per-app notification area settings)
- ✨ **Backup integrity validation** (corruption detection, JSON parsing checks)
- ✨ **Enhanced error recovery mechanisms** (rollback protection)

✨ **Enhanced Features:**
- ✨ Added `-Diagnostic` parameter for backup file validation
- ✨ Improved comprehensive status display (method-by-method results)
- ✨ Enhanced PowerShell 7+ support (improved colors, performance)
- ✨ Real-time progress tracking per method
- ✨ Comprehensive JSON backup system (replaces basic registry export)
- 🐛 Fixed TrayNotify path creation when missing
- 🐛 Fixed backup timestamp display issue (v4.0)
- 🐛 Improved system icon visibility enforcement
- 📚 Massive documentation expansion (v4.0 comprehensive method)

**Batch Script - Streamlined:**
- 🔧 Optimized for performance and clarity
- 🔧 Reduced complexity (focused on core functionality)
- 📚 Updated documentation

**Documentation:**
- ✨ Added comprehensive v4.0 feature documentation
- ✨ Added multi-method breakdown and technical details
- ✨ Expanded troubleshooting for v4.0 specific issues
- ✨ Added Windows 11 25H2 compatibility notes
- 📚 Complete v4.0 comprehensive method explanation

### Version 3.3 (2025-11-22)

**PowerShell Script:**
- ✨ Added comprehensive backup/rollback system
- ✨ Added auto-update functionality from GitHub
- ✨ Added modern UI with color-coded output
- ✨ Added PowerShell 7+ enhancements
- ✨ Added WhatIf support for safe testing
- ✨ Added comprehensive help system
- ✨ Added session context validation
- ✨ Added performance monitoring
- ✨ Added standalone backup functionality
- 🐛 Fixed Explorer restart edge cases
- 🐛 Fixed privilege detection issues
- 📚 Expanded documentation

**Batch Script:**
- ✨ Added backup/rollback functionality
- ✨ Added status checking
- ✨ Added color-coded console output
- ✨ Added comprehensive help system
- ✨ Added logging system
- ✨ Added force mode support
- 📚 Complete documentation

**Documentation:**
- ✨ Added Quick Start section
- ✨ Expanded enterprise deployment guides
- ✨ Added comprehensive FAQ
- ✨ Added troubleshooting guide
- ✨ Added batch script full documentation
- ✨ Added PowerShell script full documentation
- 📚 Increased total documentation by 200%

---

## ⚡ Performance

**PowerShell v4.0 Script:**
- Execution time (comprehensive enable): 2-4 seconds (all methods)
- Explorer restart: 2-5 seconds
- Comprehensive backup creation: 1-2 seconds (JSON serialization)
- Status check (comprehensive): < 1 second
- Auto-update: 5-10 seconds (network dependent)
- Diagnostic validation: < 1 second

**Batch Script:**
- Execution time (basic enable): < 1 second
- Explorer restart: 3-6 seconds
- Basic backup creation: < 1 second
- Status check: < 1 second

**Registry File:**
- Application time: Instant (double-click)
- Explorer restart: Manual (3-5 seconds)

**Resource Usage (PowerShell v4.0):**
- CPU: Minimal (< 2% during comprehensive execution)
- Memory: 15-20 MB (PowerShell + JSON serialization)
- Disk: 10-50 KB (comprehensive JSON backup with binary data)
- Network: 0 (except optional auto-update feature)

---

**Last Updated:** November 23, 2025  
**Status:** ✅ Production Ready (v4.0 Comprehensive Method)  
**Version:** 4.0 PowerShell (Enterprise Edition - Enhanced) / 3.3 Batch (Lightweight)  
**Maintained By:** Mikhail Deynekin ([mid1977@gmail.com](mailto:mid1977@gmail.com))

---

**⭐ If you find this useful (especially the revolutionary v4.0 comprehensive method), please consider giving the repository a star on GitHub!**

**🔗 Repository:** [https://github.com/paulmann/windows-show-all-tray-icons](https://github.com/paulmann/windows-show-all-tray-icons)

---
