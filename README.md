# Windows 11 - Show All System Tray Icons

[![Windows 11](https://img.shields.io/badge/Windows-11-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows/windows-11)
[![Windows 10](https://img.shields.io/badge/Windows-10-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A simple registry tweak to display **all notification area icons** in the Windows 11 system tray, disabling the automatic icon hiding feature.

## 📋 Table of Contents

- [Overview](#overview)
- [The Problem](#the-problem)
- [The Solution](#the-solution)
- [Installation](#installation)
- [Reverting Changes](#reverting-changes)
- [Technical Details](#technical-details)
- [Compatibility](#compatibility)
- [Safety](#safety)
- [Manual Configuration](#manual-configuration)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

By default, Windows 11 automatically hides system tray icons to keep the taskbar clean. This repository provides a registry modification that forces Windows to display **all** notification area icons at all times.

## ❓ The Problem

Windows 11 (and Windows 10) automatically hide system tray icons based on usage patterns and system settings. This means:

- ❌ Important application icons disappear from the tray
- ❌ You have to click the chevron (^) to access hidden icons
- ❌ Monitoring tools and utilities become less visible
- ❌ Frequent clicking to reveal hidden icons is tedious

## ✅ The Solution

This registry modification disables the auto-hide feature by setting `EnableAutoTray` to `0`, ensuring:

- ✅ All system tray icons remain visible at all times
- ✅ No need to click the chevron to access hidden icons
- ✅ Immediate visibility of all running applications
- ✅ Better monitoring and control over background processes

## 🚀 Installation

### Method 1: Using the REG File (Recommended)

1. **Download** the registry file:
   ```bash
   curl -O https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/enable-all-tray-icons.reg
   ```

2. **Double-click** `enable-all-tray-icons.reg`

3. **Confirm** the User Account Control (UAC) prompt if it appears

4. **Click "Yes"** when Windows asks if you want to add the information to the registry

5. **Restart Windows Explorer** (optional, but recommended):
   - Press `Ctrl + Shift + Esc` to open Task Manager
   - Find **"Windows Explorer"** in the process list
   - Right-click → **"Restart"**

### Method 2: PowerShell (One-Liner)

```powershell
# Run as Administrator
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Value 0 -Type DWord
Stop-Process -Name explorer -Force
```

### Method 3: Command Prompt (CMD)

```cmd
REM Run as Administrator
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray /t REG_DWORD /d 0 /f
taskkill /f /im explorer.exe && start explorer.exe
```

## ⏪ Reverting Changes

If you want to restore Windows default behavior (auto-hide icons):

### Option 1: Use the Revert Script

1. Download and run `disable-auto-hide.reg`
2. Restart Windows Explorer

### Option 2: Manual Registry Edit

1. Press `Win + R`, type `regedit`, press Enter
2. Navigate to: `HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer`
3. Double-click `EnableAutoTray`
4. Change the value to `1`
5. Click OK and restart Windows Explorer

### Option 3: PowerShell Revert

```powershell
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Value 1 -Type DWord
Stop-Process -Name explorer -Force
```

## 🔧 Technical Details

### Registry Key Modified

```ini
[HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer]
"EnableAutoTray"=dword:00000000
```

### Value Explanation

| Value | Behavior | Description |
|-------|----------|-------------|
| `0` | **Show All Icons** | Disables auto-hide, displays all tray icons |
| `1` | **Auto-Hide** (Default) | Windows automatically hides inactive icons |

### Registry Hive

- **HKEY_CURRENT_USER (HKCU)**: Per-user setting
- Changes apply only to the current user profile
- Does not require administrator privileges
- Safe and easily reversible

### Effect Timing

- Changes take effect **immediately** in most cases
- Some users may need to restart Windows Explorer
- No system reboot required

## 🖥️ Compatibility

| Operating System | Supported | Tested |
|------------------|-----------|--------|
| Windows 11 (23H2, 24H2) | ✅ Yes | ✅ Yes |
| Windows 11 (21H2, 22H2) | ✅ Yes | ✅ Yes |
| Windows 10 (All versions) | ✅ Yes | ✅ Yes |
| Windows Server 2022 | ✅ Yes | ⚠️ Not tested |
| Windows Server 2019 | ✅ Yes | ⚠️ Not tested |

## 🛡️ Safety

### Is This Safe?

**Yes, absolutely!** This modification:

- ✅ Only modifies a **user-specific** registry key (HKCU)
- ✅ Does not affect system files or critical Windows components
- ✅ Can be **easily reverted** at any time
- ✅ Does not require administrator privileges
- ✅ No risk of system instability

### Best Practices

1. **Backup First** (optional but recommended):
   ```cmd
   reg export "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" explorer_backup.reg
   ```

2. **Test on One User**: Apply to a test user account first

3. **Document Changes**: Keep track of registry modifications for audit purposes

## ⚙️ Manual Configuration

### Via Registry Editor (regedit)

1. Press `Win + R`, type `regedit`, press Enter
2. Navigate to:
   ```
   HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer
   ```
3. Find or create a **DWORD (32-bit) Value** named `EnableAutoTray`
4. Set its value to `0` (zero)
5. Click OK
6. Restart Windows Explorer

### Via Group Policy (Enterprise)

For enterprise deployments:

1. Open **Group Policy Editor** (`gpedit.msc`)
2. Navigate to:
   ```
   User Configuration → Preferences → Windows Settings → Registry
   ```
3. Create a new **Registry Item**:
   - **Action**: Update
   - **Hive**: HKEY_CURRENT_USER
   - **Key Path**: SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer
   - **Value Name**: EnableAutoTray
   - **Value Type**: REG_DWORD
   - **Value Data**: 0

## 🐛 Troubleshooting

### Icons Still Hidden After Applying

**Solution**: Restart Windows Explorer or log off/log on

```powershell
# PowerShell method
Stop-Process -Name explorer -Force
```

### Changes Don't Persist After Reboot

**Possible Causes**:
- Group Policy is overriding the setting
- Third-party taskbar customization software is interfering

**Solution**: Check Group Policy settings or disable conflicting software

### Some Icons Still Don't Appear

**Cause**: Individual applications may have their own visibility settings

**Solution**: Configure per-application settings:
1. Right-click the taskbar
2. Select **Taskbar settings**
3. Click **Other system tray icons**
4. Toggle specific application icons to **On**

### Registry Key Not Found

**Solution**: The key exists by default. If missing, create it:

```powershell
New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Value 0 -PropertyType DWord -Force
```

## 📊 Additional Configuration

### Show/Hide Specific System Icons

To configure visibility of specific system icons (Clock, Volume, Network, etc.):

1. Open **Settings** → **Personalization** → **Taskbar**
2. Expand **Taskbar corner icons**
3. Toggle individual system icons on/off

Or via registry:

```ini
[HKEY_CURRENT_USER\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify]
"SystemTrayChevronVisibility"=dword:00000000
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Ideas for Contributions

- Additional registry tweaks for taskbar customization
- PowerShell module for automated configuration
- Batch scripts for enterprise deployment
- Documentation improvements

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Mikhail Deynekin**

- 🌐 Website: [deynekin.com](https://deynekin.com)
- 📧 Email: mid1977@gmail.com
- 🐙 GitHub: [@paulmann](https://github.com/paulmann)

## 🌟 Acknowledgments

- Microsoft Windows documentation
- Windows system administration community
- Contributors and testers

---

**Note**: This repository is not affiliated with or endorsed by Microsoft Corporation. Windows is a registered trademark of Microsoft Corporation.

## 📚 Related Resources

- [Microsoft Docs - Taskbar Configuration](https://docs.microsoft.com/windows/configuration/taskbar/)
- [Windows Registry Reference](https://docs.microsoft.com/windows/win32/sysinfo/registry)
- [Group Policy Settings Reference](https://docs.microsoft.com/windows/client-management/mdm/policy-configuration-service-provider)

---

**⭐ If you find this useful, please consider giving the repository a star!**
