# TrayIconGuard v8 per-user installer (no admin, zero dependencies).
# Installs to %LOCALAPPDATA%\Programs\TrayIconGuard, Start Menu shortcut,
# Apps&Features uninstall entry, optional autostart.
param(
    [switch]$Autostart
)
$ErrorActionPreference = 'Stop'
$version = '8.0.0'
$root = Join-Path $env:LOCALAPPDATA 'Programs\TrayIconGuard'
New-Item -ItemType Directory -Force -Path $root | Out-Null

$src = Join-Path $PSScriptRoot '..\dist\TrayIconGuard.exe'
if (-not (Test-Path $src)) { $src = Join-Path $PSScriptRoot '..\TrayIconGuard.exe' }
if (-not (Test-Path $src)) { throw 'TrayIconGuard.exe not found: build it (scripts/build.sh) or place next to installer/' }
Copy-Item $src (Join-Path $root 'TrayIconGuard.exe') -Force

# Start Menu shortcut
$menu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\TrayIconGuard'
New-Item -ItemType Directory -Force -Path $menu | Out-Null
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut((Join-Path $menu 'TrayIconGuard.lnk'))
$lnk.TargetPath = (Join-Path $root 'TrayIconGuard.exe')
$lnk.WorkingDirectory = $root
$lnk.IconLocation = (Join-Path $root 'TrayIconGuard.exe') + ',0'
$lnk.Description = 'Keep every tray icon visible'
$lnk.Save()

# Uninstall entry (Apps & Features)
$uninst = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TrayIconGuard'
New-Item -Path $uninst -Force | Out-Null
$ps = Join-Path $root 'uninstall.ps1'
Copy-Item (Join-Path $PSScriptRoot 'uninstall.ps1') $ps -Force
Set-ItemProperty $uninst 'DisplayName' 'TrayIconGuard'
Set-ItemProperty $uninst 'DisplayVersion' $version
Set-ItemProperty $uninst 'Publisher' 'TrayIconGuard Project'
Set-ItemProperty $uninst 'InstallLocation' $root
Set-ItemProperty $uninst 'UninstallString' "powershell.exe -ExecutionPolicy Bypass -File `"$ps`""
Set-ItemProperty $uninst 'NoModify' 1 -Type DWord
Set-ItemProperty $uninst 'NoRepair' 1 -Type DWord

if ($Autostart) { & (Join-Path $root 'TrayIconGuard.exe') --install-autostart | Out-Null }

Write-Host "TrayIconGuard $version installed to $root"
Write-Host 'Start it from the Start Menu or run:' (Join-Path $root 'TrayIconGuard.exe')
