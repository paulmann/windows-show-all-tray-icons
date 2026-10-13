# ---------------------------------------------------------------------------
# RegistryCore.ps1 -- all raw registry access for the module lives here.
# Uses Microsoft.Win32.Registry directly (faster and more precise than the
# PSDrive provider for enumeration). Parameters are intentionally untyped so
# the module can be dot-sourced on non-Windows for static analysis/tests;
# every public entry point calls Assert-WindowsPlatform first.
# ---------------------------------------------------------------------------

function script:Get-DataDirectory {
    $base = if ($IsWindows) { $env:LOCALAPPDATA } else { Join-Path $HOME '.local/share' }
    $dir = Join-Path $base ([TrayPolicy]::AppFolderName)
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
    $dir
}

function script:Get-BackupDirectory {
    $dir = Join-Path (script:Get-DataDirectory) ([TrayPolicy]::BackupFolderName)
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
    $dir
}

function script:Open-TraySettingsRoot {
    <#
    .SYNOPSIS
        Opens HKCU\Control Panel\NotifyIconSettings (creates it when missing).
    .PARAMETER Writable
        Open for write access (promotion operations).
    #>
    [CmdletBinding()]
    param([switch] $Writable)

    $base = [Microsoft.Win32.Registry]::CurrentUser
    $root = $base.OpenSubKey([TrayPolicy]::NotifyIconSettings, $Writable.IsPresent)
    if (-not $root) {
        $root = $base.CreateSubKey([TrayPolicy]::NotifyIconSettings)
    }
    if (-not $root) {
        throw [System.UnauthorizedAccessException]::new(
            ('Cannot open HKCU\{0}. The profile hive may be read-only (e.g. mandatory profile).' -f [TrayPolicy]::NotifyIconSettings))
    }
    $root
}

function script:Test-ExecutableExcluded {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()][TrayIconInfo] $Icon,
        [AllowNull()][string[]] $ExcludeExecutable
    )

    if (-not $Icon -or -not $ExcludeExecutable -or $ExcludeExecutable.Count -eq 0) { return $false }

    $fileName = if ($Icon.ExecutablePath) { [System.IO.Path]::GetFileName($Icon.ExecutablePath) } else { $null }
    foreach ($pattern in $ExcludeExecutable) {
        if (-not $pattern) { continue }
        if ($Icon.ExecutablePath -and ($Icon.ExecutablePath -like $pattern)) { return $true }
        if ($fileName -and ($fileName -like $pattern)) { return $true }
        if ($Icon.DisplayName -and ($Icon.DisplayName -like $pattern)) { return $true }
    }
    $false
}

function script:Read-TrayIconEntry {
    <#
    .SYNOPSIS
        Reads one NotifyIconSettings subkey into a [TrayIconInfo].
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Root,      # Microsoft.Win32.RegistryKey
        [Parameter(Mandatory)][string] $Id,
        [AllowNull()][string[]] $ExcludeExecutable
    )

    $sub = $Root.OpenSubKey($Id, $false)
    if (-not $sub) { return $null }
    try {
        $info = [TrayIconInfo]::new()
        $info.Id = $Id

        $promoted = $sub.GetValue([TrayPolicy]::IsPromotedName)
        $info.IsPromoted = ($null -ne $promoted) -and ([Convert]::ToInt32($promoted) -ne 0)

        $exe = $sub.GetValue([TrayPolicy]::ExecutablePathName)
        if ($null -ne $exe) { $info.ExecutablePath = [string] $exe }

        $res = $sub.GetValue([TrayPolicy]::IconResourceName)
        if ($null -ne $res) { $info.IconResource = [string] $res }

        $snapshot = $sub.GetValue([TrayPolicy]::IconSnapshotName)
        $info.HasSnapshot = ($null -ne $snapshot) -and ($snapshot -is [byte[]]) -and ($snapshot.Length -gt 0)

        $last = $sub.GetValue([TrayPolicy]::LastNotificationName)
        if ($null -ne $last) {
            $fileTime = [Convert]::ToInt64($last)
            if ($fileTime -gt 0 -and $fileTime -lt 2650467744000000000) {
                try { $info.LastNotification = [System.DateTime]::FromFileTimeUtc($fileTime) } catch { $info.LastNotification = $null }
            }
        }

        $info.DisplayName = if ($info.ExecutablePath) {
            [System.IO.Path]::GetFileNameWithoutExtension($info.ExecutablePath)
        }
        else { $Id }

        $info.IsExcluded = script:Test-ExecutableExcluded -Icon $info -ExcludeExecutable $ExcludeExecutable
        $info
    }
    finally {
        $sub.Dispose()
    }
}

function script:Get-AllTrayIconEntries {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Internal helper returning a collection by design.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Root,      # Microsoft.Win32.RegistryKey
        [AllowNull()][string[]] $ExcludeExecutable
    )

    $list = [System.Collections.Generic.List[TrayIconInfo]]::new()
    foreach ($id in $Root.GetSubKeyNames()) {
        $entry = script:Read-TrayIconEntry -Root $Root -Id $id -ExcludeExecutable $ExcludeExecutable
        if ($entry) { $list.Add($entry) }
    }
    $list
}

function script:Set-TrayIconPromotionCore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Root,      # writable Microsoft.Win32.RegistryKey
        [Parameter(Mandatory)][string] $Id,
        [Parameter(Mandatory)][bool] $Promoted
    )

    $sub = $Root.CreateSubKey($Id)
    if (-not $sub) {
        throw [System.UnauthorizedAccessException]::new("Cannot open HKCU\$([TrayPolicy]::NotifyIconSettings)\$Id for writing.")
    }
    try {
        $sub.SetValue([TrayPolicy]::IsPromotedName, [int] $Promoted, [Microsoft.Win32.RegistryValueKind]::DWord)
    }
    finally {
        $sub.Dispose()
    }
}

function script:Get-ExplorerKeyValue {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Name)

    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey([TrayPolicy]::ExplorerKey, $false)
    if (-not $key) { return $null }
    try { $key.GetValue($Name) } finally { $key.Dispose() }
}

function script:Set-ExplorerKeyValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][int] $Value
    )

    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey([TrayPolicy]::ExplorerKey)
    try { $key.SetValue($Name, $Value, [Microsoft.Win32.RegistryValueKind]::DWord) }
    finally { $key.Dispose() }
}

function script:Remove-ExplorerKeyValue {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Name)

    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey([TrayPolicy]::ExplorerKey, $true)
    if (-not $key) { return $false }
    try {
        if ($null -ne $key.GetValue($Name)) {
            $key.DeleteValue($Name, $false)
            return $true
        }
        return $false
    }
    finally { $key.Dispose() }
}

function script:Get-SystemIconPolicies {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Internal helper returning a collection by design.')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $result = @{}
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey([TrayPolicy]::ExplorerPoliciesKey, $false)
    if (-not $key) {
        foreach ($name in [TrayPolicy]::SystemIconPolicyNames) { $result[$name] = $null }
        return $result
    }
    try {
        foreach ($name in [TrayPolicy]::SystemIconPolicyNames) { $result[$name] = $key.GetValue($name) }
    }
    finally { $key.Dispose() }
    $result
}

function script:Clear-SystemIconPolicies {
    <#
    .SYNOPSIS
        Removes HideSCAVolume / HideSCANetwork / HideSCAPower values that are
        set to 1 (hide). Returns the names actually removed.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Internal helper operating on a collection by design.')]
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    $removed = [System.Collections.Generic.List[string]]::new()
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey([TrayPolicy]::ExplorerPoliciesKey, $true)
    if (-not $key) { return , [string[]] @() }
    try {
        foreach ($name in [TrayPolicy]::SystemIconPolicyNames) {
            $value = $key.GetValue($name)
            if ($null -ne $value -and [Convert]::ToInt32($value) -ne 0) {
                $key.DeleteValue($name, $false)
                $removed.Add($name)
            }
        }
    }
    finally { $key.Dispose() }
    , [string[]] $removed.ToArray()
}

function script:Get-WindowsProductInfo {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $info = @{
        ProductName      = 'Windows'
        DisplayVersion   = ''
        CurrentBuild     = [System.Environment]::OSVersion.Version.Build
        InstallationType = 'Client'
    }
    try {
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\Microsoft\Windows NT\CurrentVersion', $false)
        if ($key) {
            try {
                $productName = $key.GetValue('ProductName')
                if ($productName) { $info.ProductName = [string] $productName }
                $displayVersion = $key.GetValue('DisplayVersion')
                if ($displayVersion) { $info.DisplayVersion = [string] $displayVersion }
                $build = $key.GetValue('CurrentBuildNumber')
                if ($build) { $info.CurrentBuild = [Convert]::ToInt32($build) }
                $installType = $key.GetValue('InstallationType')
                if ($installType) { $info.InstallationType = [string] $installType }
            }
            finally { $key.Dispose() }
        }
        # Windows 11 reports ProductName as "Windows 10 Pro" in CurrentVersion; correct it via build number.
        if ($info.CurrentBuild -ge 22000 -and $info.ProductName -like 'Windows 10*') {
            $info.ProductName = $info.ProductName -replace '^Windows 10', 'Windows 11'
        }
    }
    catch {
        script:Write-TraceLog "Could not read Windows product info: $($_.Exception.Message)" 'WARN'
    }
    $info
}
