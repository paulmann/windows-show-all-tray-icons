# Builds dist/TrayIconGuard-<ver>.msix from store/ + dist/TrayIconGuard.exe
# Requires Windows 10 SDK tools (makeappx.exe, signtool.exe) - part of the free
# "Windows SDK" or "Windows App SDK" install; NO other dependencies.
param(
    [string]$Version = "8.3.0"
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $env:TEMP "msix-stage"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
Copy-Item (Join-Path $root 'store') $stage -Recurse
Copy-Item (Join-Path $root 'dist\TrayIconGuard.exe') (Join-Path $stage 'TrayIconGuard.exe')

$makeappx = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\makeappx.exe" |
            Select-Object -Last 1 -ExpandProperty FullName
if (-not $makeappx) { throw 'makeappx.exe not found - install the Windows 10/11 SDK' }

$out = Join-Path $root "dist\TrayIconGuard-$Version.msix"
& $makeappx pack /h SHA256 /d $stage /p $out /o
Write-Host "MSIX: $out"

# Signing: for Store submission Partner Center signs for you (upload unsigned MSIX).
# For sideloading tests sign with a trusted/self-signed cert:
#   $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=TrayIconGuardDev"
#   signtool sign /fd SHA256 /a /f ... or:
#   Set-AuthenticodeSignature -Certificate $cert -FilePath $out
Write-Host 'For sideload testing:'
Write-Host '  $c = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=TrayIconGuardDev" -CertStoreLocation "Cert:\CurrentUser\My"'
Write-Host "  signtool sign /fd SHA256 /a /n TrayIconGuardDev `"$out`""
Remove-Item $stage -Recurse -Force
