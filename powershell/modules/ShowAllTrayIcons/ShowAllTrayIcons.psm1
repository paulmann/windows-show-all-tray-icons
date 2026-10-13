# ---------------------------------------------------------------------------
# ShowAllTrayIcons.psm1 -- module loader.
#
# Architecture (v7 "Phoenix", PowerShell 7.6+ only, Windows only):
#   Classes/  enums + data classes (loaded first, order-sensitive)
#   Private/  internal helpers (logging, registry core, explorer core, native P/Invoke)
#   Public/   one exported function per file
# ---------------------------------------------------------------------------

#Requires -Version 7.6

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$script:ModuleRoot = $PSScriptRoot

# --- 1. Classes (explicit order: dependencies first) -----------------------
$classLoadOrder = @(
    'Enums.ps1'
    'TrayPolicy.ps1'
    'TrayIconInfo.ps1'
    'TrayStatusReport.ps1'
)
foreach ($file in $classLoadOrder) {
    . (Join-Path $script:ModuleRoot (Join-Path 'Classes' $file))
}

# --- 2. Private helpers (alphabetical; no interdependencies at load time) --
foreach ($file in (Get-ChildItem -Path (Join-Path $script:ModuleRoot 'Private') -Filter '*.ps1' -File | Sort-Object Name)) {
    . $file.FullName
}

# --- 3. Public functions ----------------------------------------------------
$publicFiles = Get-ChildItem -Path (Join-Path $script:ModuleRoot 'Public') -Filter '*.ps1' -File | Sort-Object Name
foreach ($file in $publicFiles) {
    . $file.FullName
}

# --- 4. Exports -------------------------------------------------------------
Export-ModuleMember -Function ($publicFiles.BaseName)
