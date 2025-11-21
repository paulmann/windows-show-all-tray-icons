# Windows 11 - Show All System Tray Icons

[![Windows 11](https://img.shields.io/badge/Windows-11-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows/windows-11)
[![Windows 10](https://img.shields.io/badge/Windows-10-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A simple registry tweak to display **all notification area icons** in the Windows 11 system tray, disabling the automatic icon hiding feature.

# 📋 Complete Professional Guide

**Status:** ✅ Production Ready  
**Author:** Mikhail Deynekin (mid1977@gmail.com)  
**Repository:** [windows-show-all-tray-icons](https://github.com/paulmann/windows-show-all-tray-icons)  
**Last Updated:** 2025-11-21  
**Version:** 2.1 (Complete with PowerShell Guide)

---

## 📑 Table of Contents

1. [Quick Overview](#quick-overview)
2. [System Requirements](#system-requirements)
3. [Permissions & Privileges](#permissions--privileges)
4. [Installation Methods](#installation-methods)
5. [PowerShell Script Guide](#powershell-script-guide)
6. [Registry File Method](#registry-file-method)
7. [Command-Line Method](#command-line-method)
8. [Verification & Troubleshooting](#verification--troubleshooting)
9. [Reverting Changes](#reverting-changes)
10. [Enterprise Deployment](#enterprise-deployment)
11. [Technical Details](#technical-details)
12. [Safety & Security](#safety--security)
13. [FAQ](#faq)
14. [Contributing](#contributing)

---

## 🎯 Quick Overview

This repository provides **three professional-grade methods** to enable display of all system tray icons in Windows 11/10, with complete automation, error handling, and enterprise-ready features.

**What This Does:**
- ✅ Shows ALL notification area icons at all times
- ✅ Disables automatic icon hiding behavior  
- ✅ Applies per-user (no admin required for basic installation)
- ✅ Takes effect immediately (no reboot needed)
- ✅ Fully reversible with provided revert scripts

**What This Does NOT Do:**
- ❌ Does not modify system files
- ❌ Does not require administrator privileges (except for Group Policy)
- ❌ Does not affect system stability
- ❌ Does not interfere with Windows Update

---

## 💻 System Requirements

### Hardware Requirements
- **Processor:** Any modern x64 or ARM64 processor
- **RAM:** Minimum 4 GB (8 GB recommended)
- **Disk Space:** 50 MB free space
- **Display:** Any resolution (1024x768 minimum)

### Operating System Support
| OS Version | Support | Tested | Notes |
|------------|---------|--------|-------|
| Windows 11 (25H2, 24H2) | ✅ Full | ✅ Yes | All builds supported |
| Windows 11 (23H2, 22H2) | ✅ Full | ✅ Yes | Stable, recommended |
| Windows 11 (21H2) | ✅ Full | ✅ Yes | Legacy support |
| Windows 10 (22H2) | ✅ Full | ✅ Yes | All versions |
| Windows 10 (21H2 or earlier) | ✅ Full | ✅ Yes | All versions |
| Windows Server 2022 | ✅ Full | ⚠️ Limited | Manual testing recommended |
| Windows Server 2019 | ✅ Full | ⚠️ Limited | Manual testing recommended |

### Software Requirements
- **PowerShell:** 5.1 or higher (built-in on Windows 10/11)
- **.NET Framework:** Not required
- **Visual C++ Runtime:** Not required
- **Admin tools:** Optional (depends on method)

### Architecture Support
- ✅ x86-64 (x64)
- ✅ ARM64 (Windows 11 on ARM)
- ✅ x86 (32-bit Windows 10) - via REG file only

---

## 🔐 Permissions & Privileges

### What Privileges Are Needed?

| Method | User Type | UAC Prompt | Admin Required | Session Context | Notes |
|--------|---|---|---|---|---|
| **REG File** | Standard User | ⚠️ Yes | ❌ No | Interactive Desktop | Double-click applies changes |
| **PowerShell** | Standard User | ⚠️ Yes | ❌ No | Interactive Desktop | Full support with UAC handling |
| **PowerShell** | Administrator | ⚠️ Optional | ✅ Yes | Interactive Desktop | Applies without UAC |
| **Command Prompt** | Standard User | ⚠️ Yes | ❌ No | Interactive Desktop | CMD.exe method works |
| **Group Policy** | Domain Admin | N/A | ✅ Yes | Domain Controller | Enterprise GPO deployment |
| **Intune** | Azure Admin | N/A | ✅ Yes | Cloud Service | Modern Management deployment |
| **WinRM Remote** | Any | N/A | ❌ No | Non-Interactive | ⚠️ Script warns, limited effect |
| **Scheduled Task** | SYSTEM | N/A | ⚠️ User Context | Service Account | ⚠️ Requires user desktop session |

### Automatic Privilege Detection

The PowerShell script **automatically detects and handles** your privilege level:

# Script checks current user context
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')

if ($isAdmin) {
    Write-ColorOutput "Running as Administrator" -Type Success
} else {
    Write-ColorOutput "Running as Standard User - UAC will prompt" -Type Warning
}

**Behavior by Context:**

✅ **Standard User (Interactive Desktop)** - RECOMMENDED
- Registry modification: ✅ Works
- Explorer restart: ✅ Works
- UAC prompt: ⚠️ Yes (one-time)
- Status: ✅ Fully Supported

✅ **Administrator (Interactive Desktop)**
- Registry modification: ✅ Works
- Explorer restart: ✅ Works  
- UAC prompt: ⚠️ Optional (depending on UAC settings)
- Status: ✅ Fully Supported

⚠️ **WinRM / PowerShell Remoting** - WARNINGS SHOWN
- Registry modification: ✅ Works (for remote user's HKCU)
- Explorer restart: ❌ Fails (remote explorer not accessible)
- User impact: ⚠️ Limited (changes won't apply until user logs in locally)
- Status: Script warns about non-interactive context

⚠️ **Scheduled Task (SYSTEM Context)** - LIMITED
- Registry modification: ⚠️ Modifies SYSTEM registry (not user's)
- Explorer restart: ❌ No user explorer to restart
- User impact: ❌ None (wrong registry hive)
- Status: Script detects and warns user

❌ **Non-User Service Account** - NOT RECOMMENDED
- Registry modification: ❌ Fails (service account HKCU different)
- Status: Script shows error with guidance

### Permission Requirements Summary

**Minimal Requirements:**
- ✅ Active user session (not service)
- ✅ Access to HKEY_CURRENT_USER registry
- ✅ Permission to modify registry values
- ✅ PowerShell execution enabled

**NOT Required:**
- ❌ Administrator privileges
- ❌ Domain membership
- ❌ Specific group memberships
- ❌ System file access

### Session Context Validation

Script performs session checks:

# Check if running in interactive session
if ([Environment]::UserInteractive -eq $false) {
    Write-ColorOutput "WARNING: Non-interactive session detected" -Type Warning
    Write-ColorOutput "Changes may not apply to user desktop" -Type Warning
}

# Check for remote session (WinRM, SSH, etc.)
if ($env:PROMPT -eq $null) {
    Write-ColorOutput "Possible non-interactive context detected" -Type Warning
}

# Check if running as SYSTEM
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
if ($currentUser.User.Value -eq "S-1-5-18") {
    Write-ColorOutput "ERROR: Running as SYSTEM account - not supported" -Type Error
    exit 2
}

---

## 🚀 Installation Methods

### Method 1: PowerShell Script (Recommended - Enterprise)

**Advantages:**
- ✅ Automatic error handling & privilege detection
- ✅ Status checking built-in
- ✅ Immediate Explorer restart option
- ✅ Color-coded console output
- ✅ Exit codes for automation/scripting
- ✅ Professional logging & warnings
- ✅ Session context validation
- ✅ Execution policy handling

**Disadvantages:**
- Requires PowerShell 5.1+ (built-in on Windows 10/11)

#### Installation Steps

1. **Download the script:**
   # Option A: Using PowerShell (Recommended)
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/Enable-AllTrayIcons.ps1" -OutFile "$env:USERPROFILE\Downloads\Enable-AllTrayIcons.ps1"
   
   # Option B: Using curl
   curl -O https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/Enable-AllTrayIcons.ps1
   
   # Option C: Using wget
   wget -O Enable-AllTrayIcons.ps1 https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/Enable-AllTrayIcons.ps1

2. **Check your PowerShell version:**
   $PSVersionTable.PSVersion
   # Should show: 5.1 or higher

3. **Check Execution Policy** (first time only):
   Get-ExecutionPolicy -Scope CurrentUser
   
   # If result is "Restricted", run:
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

4. **Open PowerShell as Administrator:**
   - **Option A:** Press `Win + X` → Select "**Windows PowerShell (Admin)**" or "**Terminal (Admin)**"
   - **Option B:** Search for "PowerShell" → Right-click → "**Run as administrator**"
   - Click "**Yes**" on UAC prompt if shown

5. **Navigate to script location:**
   cd $env:USERPROFILE\Downloads
   # Or wherever you saved the script

6. **Check script integrity** (optional):
   Get-FileHash .\Enable-AllTrayIcons.ps1
   # Verify you have the correct file from GitHub

7. **Execute the script:**
   # Enable all icons with automatic Explorer restart
   .\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer
   
   # Or without auto-restart (manual restart later)
   .\Enable-AllTrayIcons.ps1 -Action Enable

8. **Verify configuration:**
   .\Enable-AllTrayIcons.ps1 -Action Status

#### Script Execution Policy Notes

- **RemoteSigned** (recommended): Allows local scripts to run, but downloaded scripts must be signed
- **Unrestricted**: Allows all scripts (less secure)
- **CurrentUser scope**: Only affects current user, doesn't require admin privileges
- **LocalMachine scope**: Affects all users (requires admin)

If you get "cannot be loaded because running scripts is disabled" error, run:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

#### PowerShell Script Features

**Available Actions:**

# Show all icons
.\Enable-AllTrayIcons.ps1 -Action Enable

# Show all icons AND restart Explorer immediately
.\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer

# Restore Windows default (auto-hide icons)
.\Enable-AllTrayIcons.ps1 -Action Disable

# Restore AND restart Explorer
.\Enable-AllTrayIcons.ps1 -Action Disable -RestartExplorer

# Check current status
.\Enable-AllTrayIcons.ps1 -Action Status

# Preview changes without applying (WhatIf mode)
.\Enable-AllTrayIcons.ps1 -Action Enable -WhatIf

**Script Output Examples:**

✅ Success scenario:
[2025-11-21 21:30:45] [SUCCESS] Registry value set successfully: EnableAutoTray = 0
[2025-11-21 21:30:45] [INFO] Restarting Windows Explorer...
[2025-11-21 21:30:46] [SUCCESS] Windows Explorer restarted successfully

⚠️ Non-admin user (standard user will still work):
[2025-11-21 21:31:00] [INFO] Checking current privileges...
[2025-11-21 21:31:00] [INFO] Running as Standard User - UAC will prompt
[2025-11-21 21:31:02] [SUCCESS] Registry value set successfully: EnableAutoTray = 0

❌ Session context warning:
[2025-11-21 21:32:15] [WARNING] Non-interactive session detected
[2025-11-21 21:32:15] [WARNING] Changes will not apply to desktop - requires user interactive session
[2025-11-21 21:32:15] [INFO] This script must run in user desktop context, not WinRM/SSH/SYSTEM

**Automatic Privilege & Session Checks:**

| Context | Behavior | Status |
|---------|----------|--------|
| Standard User (Interactive Desktop) | Works, UAC prompts once | ✅ Full Support |
| Administrator (Interactive Desktop) | Works silently, no UAC | ✅ Full Support |
| PowerShell Remote (WinRM) | Works but warns (no effect) | ⚠️ Limited |
| Scheduled Task (SYSTEM) | Checks context, warns user | ⚠️ Limited |
| SSH/WSL Console | Works if HKCU accessible | ✅ Partial Support |

**Exit Codes** (for automation/scripting):

| Code | Meaning | Description |
|------|---------|-------------|
| 0 | Success | Operation completed successfully |
| 1 | Error | Operation failed (check console output) |
| 2 | Warning | Executed but with warnings (session context, etc.) |

**Automation Examples:**

# Check exit code after execution
.\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer
if ($LASTEXITCODE -eq 0) {
    Write-Host "Configuration successful"
} else {
    Write-Host "Configuration failed - check output above"
}

# Suppress output and capture exit code
.\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer *>$null
$result = $LASTEXITCODE

# Log results to file
.\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer | Tee-Object -FilePath "C:\Logs\tray-config.log"

---

### Method 2: Registry File (Simplest - Windows GUI)

**Advantages:**
- ✅ Simplest method - just double-click
- ✅ No PowerShell knowledge needed
- ✅ Works on all Windows versions
- ✅ Traditional Windows method

**Disadvantages:**
- Requires manual restart of Explorer
- No error checking

#### Installation Steps

1. **Download the registry file:**
   - Visit: https://github.com/paulmann/windows-show-all-tray-icons
   - Click **Code** → **Download ZIP**
   - Or download directly: https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/enable-all-tray-icons.reg

2. **Run the registry file:**
   - Double-click `enable-all-tray-icons.reg`
   - User Account Control (UAC) prompt may appear
   - Click **Yes** to proceed

3. **Confirm the changes:**
   - Registry Editor confirmation window appears
   - Message: "Information in enable-all-tray-icons.reg has been successfully entered into the registry"
   - Click **OK**

4. **Restart Windows Explorer** (to see changes immediately):
   - Press `Ctrl + Shift + Esc` (opens Task Manager)
   - Find **"Windows Explorer"** in process list
   - Right-click → **Restart**
   - Or: Right-click taskbar → **Task Manager** → Find Explorer → **Restart**

**Alternative: Restart via Command Prompt**

taskkill /f /im explorer.exe && start explorer.exe

---

### Method 3: Command Prompt (Fast - CLI)

**Advantages:**
- ✅ Very fast
- ✅ No UI dialogs
- ✅ Can be scripted

**Disadvantages:**
- Requires Command Prompt
- Requires manual Explorer restart

#### Installation Steps

1. **Open Command Prompt as Administrator:**
   - Press `Win + R`
   - Type: `cmd`
   - Press `Ctrl + Shift + Enter` (Run as Administrator)
   - Click **Yes** on UAC prompt

2. **Run the command:**
   REM Enable all tray icons
   reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray /t REG_DWORD /d 0 /f
   
   REM Restart Explorer
   taskkill /f /im explorer.exe && start explorer.exe

3. **Verify:**
   reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray
   REM Should show: EnableAutoTray    REG_DWORD    0x0

---

### Method 4: PowerShell One-Liner (Advanced)

For advanced users who want to bypass file downloads:

# Run as Administrator
& {Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Value 0 -Type DWord; Stop-Process -Name explorer -Force; Start-Sleep -Milliseconds 500; Start-Process explorer.exe}

Or as a single command for terminal:

Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Value 0 -Type DWord; Stop-Process -Name explorer -Force; Start-Process explorer.exe

---

## 📜 PowerShell Script Guide

### Script Features in Detail

#### ✅ Automatic Privilege Detection

The script automatically detects your privilege level:

[INFO] Checking current privileges...
[INFO] Running as Standard User - UAC will prompt

#### ✅ Registry Path Validation

Script ensures registry path exists before modification:

[INFO] Validating registry key: HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer
[SUCCESS] Registry key validated

#### ✅ Error Handling

Comprehensive error messages for troubleshooting:

[ERROR] Failed to set registry value: Access Denied
[INFO] Try running as Administrator

#### ✅ Status Checking

Built-in status verification:

[INFO] Checking current configuration...
=========================================================================
System Tray Icon Configuration Status
=========================================================================

Registry Path  : HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer
Registry Value : EnableAutoTray
Current Value  : 0

Behavior       : Show ALL system tray icons (auto-hide DISABLED)

Windows Version: Microsoft Windows 11 Professional (Build 26100)
PowerShell Ver : 5.1.26100.0

=========================================================================

#### ✅ Automatic Explorer Restart

Optional parameter to apply changes immediately:

.\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer

# Output:
# [INFO] Restarting Windows Explorer...
# [SUCCESS] Windows Explorer restarted successfully

### Real-World Usage Scenarios

**Scenario 1: First-time setup on personal computer**
# Download
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/Enable-AllTrayIcons.ps1" -OutFile "Enable-AllTrayIcons.ps1"

# Check status first
.\Enable-AllTrayIcons.ps1 -Action Status
# Output: Shows current config

# Enable with restart
.\Enable-AllTrayIcons.ps1 -Action Enable -RestartExplorer
# Immediately effective

**Scenario 2: Enterprise deployment verification**
# Verify setting on remote computer
$computerName = "WORKSTATION01"
$scriptBlock = {
    .\Enable-AllTrayIcons.ps1 -Action Status
}
Invoke-Command -ComputerName $computerName -ScriptBlock $scriptBlock

**Scenario 3: Batch deployment to multiple machines**
# Deploy to list of computers
$computers = @("PC01", "PC02", "PC03", "PC04")
foreach ($computer in $computers) {
    Write-Host "Deploying to $computer..."
    Copy-Item -Path ".\Enable-AllTrayIcons.ps1" -Destination "\\$computer\c$\temp\"
    Invoke-Command -ComputerName $computer -ScriptBlock {
        & "C:\temp\Enable-AllTrayIcons.ps1" -Action Enable -RestartExplorer
    } -ErrorAction Continue
}

**Scenario 4: Revert across domain**
# Revert setting on all domain computers
$computers = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name
foreach ($computer in $computers) {
    Invoke-Command -ComputerName $computer -ScriptBlock {
        & "\\FILESERVER\Scripts\Enable-AllTrayIcons.ps1" -Action Disable -RestartExplorer
    } -ErrorAction SilentlyContinue
}

**Scenario 5: Scheduled task deployment**
# Create scheduled task to run at user logon
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -File 'C:\ProgramData\Enable-AllTrayIcons.ps1' -Action Enable"
$trigger = New-ScheduledTaskTrigger -AtLogon
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
Register-ScheduledTask -TaskName "Show All Tray Icons" `
  -Action $action `
  -Trigger $trigger `
  -Principal $principal `
  -Description "Enable display of all system tray icons" `
  -Force

**Scenario 6: Error handling in automation**
function Deploy-TrayIconConfig {
    param([string]$ComputerName)
    
    try {
        $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            & ".\Enable-AllTrayIcons.ps1" -Action Enable -RestartExplorer
        } -ErrorAction Stop
        
        Write-Host "✅ Deployment successful on $ComputerName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Deployment failed on $ComputerName : $_" -ForegroundColor Red
        return $false
    }
}

# Usage
$computers = @("PC01", "PC02", "PC03")
$results = @()
foreach ($computer in $computers) {
    $results += @{
        Computer = $computer
        Success = Deploy-TrayIconConfig -ComputerName $computer
    }
}

# Summary report
$results | Format-Table -AutoSize

**Scenario 7: Status report generation**
# Generate configuration report
$report = @()
$computers = @("PC01", "PC02", "PC03")

foreach ($computer in $computers) {
    $status = Invoke-Command -ComputerName $computer -ScriptBlock {
        .\Enable-AllTrayIcons.ps1 -Action Status
    } -ErrorAction SilentlyContinue
    
    $report += [PSCustomObject]@{
        Computer = $computer
        Status = if ($status -match "0") { "All Icons Shown" } else { "Default (Auto-Hide)" }
        Timestamp = Get-Date
    }
}

# Export report
$report | Export-Csv -Path "C:\Reports\tray-icons-config.csv" -NoTypeInformation

---

## ✅ Verification & Troubleshooting

### Verify Installation Success

**Via PowerShell:**
.\Enable-AllTrayIcons.ps1 -Action Status

**Via Registry Editor:**
1. Open Registry Editor (`Win + R` → `regedit`)
2. Navigate to: `HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer`
3. Check `EnableAutoTray` value:
   - Should be: `0` (DWORD)
   - If set correctly: ✅ Configuration successful

**Via Command Prompt:**
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray

Expected output:
    EnableAutoTray    REG_DWORD    0x0

### Common Issues & Solutions

#### ❌ Icons Still Not Showing

**Issue:** Changed setting but icons still hidden

**Solutions:**
1. **Restart Windows Explorer:**
   Stop-Process -Name explorer -Force
   Start-Process explorer.exe

2. **Log off and log back on:**
   - Click Start → Power → Sign out
   - Log back in

3. **Restart computer:**
   - Some cases may require full restart
   - Save work and restart

#### ❌ "Access Denied" Error

**Issue:** Cannot modify registry

**Solution:**
1. Run PowerShell as Administrator:
   - Right-click PowerShell → **Run as administrator**
   - Click **Yes** on UAC prompt

2. Check file permissions:
   icacls "$env:USERPROFILE\NTUSER.DAT"

3. If user account is locked:
   - Log in with different admin account
   - Run script from that account

#### ❌ PowerShell Execution Policy Error

**Issue:** "File cannot be loaded because running scripts is disabled"

**Solution:**
# Permanently allow scripts for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Then run the script
.\Enable-AllTrayIcons.ps1 -Action Enable

#### ❌ Script File Not Found

**Issue:** "Enable-AllTrayIcons.ps1 : The term is not recognized"

**Solution:**
1. Ensure you're in the correct directory:
   cd C:\Users\YourUsername\Downloads

2. Or use full path:
   C:\Users\YourUsername\Downloads\Enable-AllTrayIcons.ps1 -Action Enable

#### ❌ Changes Reverted After Reboot

**Issue:** Settings applied but reverted after restart

**Possible Causes:**
- Group Policy overriding user settings
- Third-party software (e.g., O&O ShutUp++, W11Debloat)
- Windows Update resetting values

**Solution:**
1. Check Group Policy:
   gpresult /h gpresult.html

2. Check for conflicting software:
   - Uninstall system modification tools
   - Run script again

3. Permanently apply via Group Policy:
   - See Enterprise Deployment section below

---

## 🔄 Reverting Changes

### Method 1: PowerShell Script

**Simplest method:**
.\Enable-AllTrayIcons.ps1 -Action Disable -RestartExplorer

### Method 2: Revert Registry File

**File:** `disable-auto-hide.reg`

1. Download from repository
2. Double-click to apply
3. Click **Yes** on UAC prompt
4. Restart Explorer

### Method 3: Manual Registry Edit

Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Value 1 -Type DWord
Stop-Process -Name explorer -Force
Start-Process explorer.exe

### Method 4: Command Prompt

reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray /t REG_DWORD /d 1 /f
taskkill /f /im explorer.exe && start explorer.exe

### Method 5: Delete Registry Entry

To completely remove the setting and use Windows default:

Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -ErrorAction SilentlyContinue
Stop-Process -Name explorer -Force
Start-Process explorer.exe

---

## 🏢 Enterprise Deployment

### Group Policy Deployment

For domain environments:

1. **Open Group Policy Editor:**
   Press Win + R → type: gpedit.msc → Enter

2. **Navigate to:**
   User Configuration 
   → Preferences 
   → Windows Settings 
   → Registry

3. **Create new Registry Item:**
   - Right-click "Registry" → **New** → **Registry Item**
   - **Action:** Update
   - **Hive:** HKEY_CURRENT_USER
   - **Key Path:** SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer
   - **Value name:** EnableAutoTray
   - **Value type:** REG_DWORD
   - **Value data:** 0
   - Click **OK**

4. **Apply Group Policy:**
   gpupdate /force

### Intune Deployment

For Azure AD/Intune-joined devices:

1. **Create OMA-URI Setting:**
   - Name: "Enable All System Tray Icons"
   - Description: "Shows all notification area icons"
   - OMA-URI: `./User/Vendor/MSFT/Policy/Config/ADMX_MUI/LanguagePackManagement`
   - Data type: String
   - Value: 0

2. **Alternative - Registry CSP:**
   <Add>
     <Item>
       <Target>Registry</Target>
       <TargetVersion>1</TargetVersion>
       <Channel>User</Channel>
       <RegistryOp>
         <Key>HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer</Key>
         <Value>EnableAutoTray</Value>
         <Type>REG_DWORD</Type>
         <Data>0</Data>
       </RegistryOp>
     </Item>
   </Add>

### SCCM/ConfigMgr Deployment

Use Configuration Manager to deploy via script package:

# Deploy as Run Once script
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" `
                 -Name "EnableAutoTray" -Value 0 -Type DWord -Force

# Log the change
Add-Content -Path "$env:ProgramData\EnableTrayIcons.log" -Value "$(Get-Date): Settings applied to $(whoami)"

### Batch Deployment Script

@echo off
REM Deploy to multiple machines
setlocal enabledelayedexpansion

for /f "usebackq tokens=*" %%A in (computers.txt) do (
    echo Deploying to %%A
    psexec \\%%A -s cmd /c reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray /t REG_DWORD /d 0 /f
    if !errorlevel! equ 0 (
        echo [OK] %%A
    ) else (
        echo [ERROR] %%A
    )
)

---

## ❓ FAQ

### Q: Do I need administrator privileges?

**A:** No. The registry key being modified is per-user accessible. Standard users can apply this setting. UAC prompt will appear, but you don't need admin privileges to proceed.

### Q: Will this affect other user accounts?

**A:** No. This modifies `HKEY_CURRENT_USER`, which is per-user. Other accounts on the same computer are not affected. Each user must apply separately if desired.

### Q: Do I need to restart Windows?

**A:** No. Changes take effect immediately after restarting Windows Explorer (automatic with -RestartExplorer parameter).

### Q: Can I apply this to multiple computers?

**A:** Yes. Three deployment options:
1. **Manual:** Deploy registry file to each computer
2. **Enterprise:** Use Group Policy for domain-joined computers
3. **Intune:** Use OMA-URI for Azure AD-joined devices
4. **SCCM:** Use ConfigMgr for enterprise deployment

### Q: What's the difference between the REG file and PowerShell methods?

**A:** 
- **REG file:** Simple double-click, no dependencies, no status checking
- **PowerShell:** Automated, error handling, status verification, reversible in one command

### Q: Can I schedule this to run automatically?

**A:** Yes. Use Task Scheduler:

# Create scheduled task
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -File 'C:\Path\Enable-AllTrayIcons.ps1' -Action Enable"
$trigger = New-ScheduledTaskTrigger -AtLogon
Register-ScheduledTask -TaskName "Show All Tray Icons" -Action $action -Trigger $trigger -RunLevel Highest

### Q: What if the script doesn't work?

**A:** 
1. Run PowerShell as Administrator
2. Check execution policy: `Get-ExecutionPolicy`
3. If "Restricted": `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force`
4. Check registry manually: `reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray`

### Q: Can I revert this change?

**A:** Absolutely. Three methods:
1. Run: `.\Enable-AllTrayIcons.ps1 -Action Disable -RestartExplorer`
2. Apply `disable-auto-hide.reg`
3. Manually set registry value back to 1

### Q: Is this the same as using Settings?

**A:** No. Windows Settings → Personalization → Taskbar → "Other system tray icons" controls which SPECIFIC apps show. This registry setting controls the AUTO-HIDE behavior globally.

### Q: Will Windows Update revert this?

**A:** Unlikely. Windows Updates don't modify this user-specific registry value. However, if you use system optimization tools that claim to "clean registry," they might reset it.

### Q: Does this work on Windows 10?

**A:** Yes. This works on all Windows 10 and Windows 11 versions.

### Q: Can I deploy this with Intune?

**A:** Yes. See Enterprise Deployment section for OMA-URI and Registry CSP methods.

---

## 🔐 Safety & Security

### Is This Safe?

**Yes.** This modification:

✅ **Modifies only HKCU (per-user registry)**
- Does not touch system-wide settings
- Does not modify system files
- Does not affect other users on the system
- Cannot affect system stability

✅ **Fully reversible**
- Provided revert scripts
- No side effects from revert
- Can be applied/reverted multiple times

✅ **No security risks**
- No elevation of privileges
- No changes to security policies
- No network communication
- No telemetry collection

### Backup & Recovery

**Before applying, create a backup:**

# PowerShell backup
reg export "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" explorer_backup.reg

# Command Prompt backup
reg export "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" explorer_backup.reg /y

# To restore from backup
reg import explorer_backup.reg

### System Restore Point

Create a restore point (optional):

# Create restore point
Checkpoint-Computer -Description "Before System Tray Icon Change" -RestorePointType "MODIFY_SETTINGS"

# If you need to restore
Restore-Computer -RestorePoint <RestorePointNumber> -Confirm

---

## 🤝 Contributing

Contributions welcome! Please:

1. **Report issues:** Open GitHub issue with details
2. **Submit improvements:** Fork → modify → pull request
3. **Add documentation:** Improve README with examples
4. **Test compatibility:** Report results on different OS versions

### Areas for Contribution

- [ ] Additional deployment methods
- [ ] Localized documentation
- [ ] Video tutorials
- [ ] Automation scripts
- [ ] Mobile/ARM device testing

---

## 📝 License

MIT License - See LICENSE file for details

**Copyright © 2025 Mikhail Deynekin (mid1977@gmail.com)**

---

## 📞 Support & Feedback

### Report Issues

**GitHub Issues:** https://github.com/paulmann/windows-show-all-tray-icons/issues

When reporting issues, please include:
- Windows version and build number
- PowerShell version (`$PSVersionTable.PSVersion`)
- Error message from script output
- Steps to reproduce
- Current registry value: `reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray`

### Contact Information

- **Email:** mid1977@gmail.com
- **Website:** https://deynekin.com
- **GitHub Profile:** https://github.com/paulmann
- **Repository:** https://github.com/paulmann/windows-show-all-tray-icons

### Community Contributions

- Found a bug? Open GitHub issue
- Have improvement? Submit pull request
- Documentation ideas? Suggest in discussions
- Tested on new OS build? Share results

---

## 🔗 Related Resources

### Microsoft Official Documentation
- [Registry Reference](https://docs.microsoft.com/windows/win32/sysinfo/registry)
- [Taskbar Settings Configuration](https://docs.microsoft.com/windows/configuration/taskbar/)
- [Group Policy Processing](https://docs.microsoft.com/windows/client-management/mdm/policy-configuration-service-provider)
- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
- [Windows 11 Notification Area](https://support.microsoft.com/windows/notification-area-icons)

### Related Projects
- [Windows 11 25H2 Update Script](https://github.com/paulmann/Windows-11-25H2-Update-Script)
- [Other system administration tools](https://github.com/paulmann)

### Learning Resources
- PowerShell Scripting: https://learn.microsoft.com/powershell/
- Registry Editor Guide: https://support.microsoft.com/windows/how-to-open-registry-editor
- Group Policy: https://docs.microsoft.com/windows-server/administration/windows-commands/gpedit-msc

---

**Last Updated:** November 21, 2025  
**Status:** ✅ Complete & Production Ready  
**Version:** 2.1 (Complete PowerShell Documentation with Enterprise Examples)  
**Maintained By:** Mikhail Deynekin (mid1977@gmail.com)

---

**⭐ If you find this useful, please consider giving the repository a star!**
