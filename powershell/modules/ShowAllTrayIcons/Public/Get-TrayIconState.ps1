function Get-TrayIconState {
    <#
    .SYNOPSIS
        Returns a full status snapshot of tray icon visibility and related switches.

    .DESCRIPTION
        Builds a [TrayStatusReport] with: Windows edition/build, icon counts (total,
        visible, hidden, excluded), the legacy EnableAutoTray value, HideSCA* system-icon
        policies, and whether TrayIconGuard autostart is installed. Use it for health
        checks, monitoring, and deployment verification.

    .PARAMETER ExcludeExecutable
        Executables treated as intentionally hidden (excluded from "all visible" checks).

    .PARAMETER AsJson
        Emits JSON instead of the report object.

    .EXAMPLE
        Get-TrayIconState

    .EXAMPLE
        (Get-TrayIconState).AllIconsVisible

    .OUTPUTS
        TrayStatusReport
    .OUTPUTS
        System.String

    .LINK
        https://github.com/paulmann/windows-show-all-tray-icons/blob/main/docs/CLI-REFERENCE.md
    #>
    [CmdletBinding()]
    [OutputType('TrayStatusReport')]
    [OutputType([string])]
    param(
        [string[]] $ExcludeExecutable,

        [switch] $AsJson
    )

    script:Assert-WindowsPlatform | Out-Null

    $report = [TrayStatusReport]::new()
    $report.Timestamp    = Get-Date
    $report.ComputerName = $env:COMPUTERNAME
    $report.UserName     = $env:USERNAME

    $product = script:Get-WindowsProductInfo
    $report.WindowsEdition     = $product.ProductName
    $report.WindowsVersionLabel = $product.DisplayVersion
    $report.WindowsBuild       = $product.CurrentBuild
    $report.InstallationType   = $product.InstallationType
    $report.PlatformSupported  = $product.CurrentBuild -ge [TrayPolicy]::MinWindowsBuild

    $root = script:Open-TraySettingsRoot
    try {
        $icons = @(script:Get-AllTrayIconEntries -Root $root -ExcludeExecutable $ExcludeExecutable)
    }
    finally {
        $root.Dispose()
    }

    $report.TotalIcons    = $icons.Count
    $report.VisibleIcons  = @($icons | Where-Object IsPromoted).Count
    $report.ExcludedIcons = @($icons | Where-Object IsExcluded).Count
    $report.HiddenIcons   = $report.TotalIcons - $report.VisibleIcons
    $report.AllIconsVisible = (($report.TotalIcons - $report.VisibleIcons - $report.ExcludedIcons) -le 0)

    $autoTray = script:Get-ExplorerKeyValue -Name ([TrayPolicy]::EnableAutoTrayName)
    $report.EnableAutoTray = if ($null -ne $autoTray) { [Convert]::ToInt32($autoTray) } else { $null }
    $report.SystemIconPolicies = script:Get-SystemIconPolicies

    $runKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey([TrayPolicy]::RunKey, $false)
    if ($runKey) {
        try {
            $command = $runKey.GetValue([TrayPolicy]::AutostartValue)
            if ($command) {
                $report.AutostartInstalled = $true
                $report.AutostartCommand   = [string] $command
            }
        }
        finally { $runKey.Dispose() }
    }

    if ($AsJson) {
        return ($report | ConvertTo-Json -Depth 5)
    }
    $report
}
