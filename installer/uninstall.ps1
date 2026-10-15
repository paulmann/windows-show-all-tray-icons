# TrayIconGuard v8 per-user uninstaller.
$ErrorActionPreference = 'SilentlyContinue'
$root = Join-Path $env:LOCALAPPDATA 'Programs\TrayIconGuard'

& (Join-Path $root 'TrayIconGuard.exe') --uninstall-autostart | Out-Null
Get-Process TrayIconGuard -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500

$menu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\TrayIconGuard'
Remove-Item $menu -Recurse -Force
Remove-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TrayIconGuard' -Recurse -Force
Remove-Item $root -Recurse -Force

$keepData = $env:TRAYICONGUARD_KEEP_DATA
if (-not $keepData) {
    Remove-Item (Join-Path $env:APPDATA 'TrayIconGuard') -Recurse -Force
    Remove-Item (Join-Path $env:LOCALAPPDATA 'TrayIconGuard') -Recurse -Force
    Write-Host 'TrayIconGuard removed (settings and logs deleted). Set TRAYICONGUARD_KEEP_DATA=1 to keep them.'
} else {
    Write-Host 'TrayIconGuard removed (settings and logs kept).'
}
