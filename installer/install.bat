@echo off
rem TrayIconGuard v8 installer launcher (calls install.ps1).
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
endlocal
