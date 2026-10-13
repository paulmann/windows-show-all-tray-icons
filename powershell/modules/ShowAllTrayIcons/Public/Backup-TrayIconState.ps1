function Backup-TrayIconState {
    <#
    .SYNOPSIS
        Saves the complete tray visibility state to a JSON file.

    .DESCRIPTION
        Records every NotifyIconSettings entry (id, IsPromoted, executable, icon
        resource), the legacy EnableAutoTray value, and the HideSCA* policies into a
        schema-v7 JSON document under
        %LOCALAPPDATA%\ShowAllTrayIcons\backups\TrayIconState-yyyyMMdd-HHmmss.json
        (or a custom -Path). Restore with Restore-TrayIconState -Latest.

    .PARAMETER Path
        Custom destination file path (*.json). Parent directory is created on demand.

    .EXAMPLE
        Backup-TrayIconState

    .EXAMPLE
        Backup-TrayIconState -Path "$HOME\Desktop\tray-before-upgrade.json"

    .OUTPUTS
        System.IO.FileInfo

    .LINK
        https://github.com/paulmann/windows-show-all-tray-icons/blob/main/docs/CLI-REFERENCE.md
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [string] $Path
    )

    script:Assert-WindowsPlatform | Out-Null

    if (-not $Path) {
        $Path = Join-Path (script:Get-BackupDirectory) ('TrayIconState-{0:yyyyMMdd-HHmmss}.json' -f (Get-Date))
    }
    $parent = Split-Path -Path $Path -Parent
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }

    $root = script:Open-TraySettingsRoot
    try {
        $icons = @(script:Get-AllTrayIconEntries -Root $root)
    }
    finally {
        $root.Dispose()
    }

    $autoTray = script:Get-ExplorerKeyValue -Name ([TrayPolicy]::EnableAutoTrayName)

    $data = [ordered]@{
        schemaVersion = [TrayPolicy]::BackupSchemaVersion
        createdAt     = (Get-Date).ToUniversalTime().ToString('o')
        tool          = 'ShowAllTrayIcons/7.0.3'
        computer      = $env:COMPUTERNAME
        user          = $env:USERNAME
        windowsBuild  = [System.Environment]::OSVersion.Version.Build
        icons         = @(foreach ($icon in $icons) {
                [ordered]@{
                    id             = $icon.Id
                    displayName    = $icon.DisplayName
                    isPromoted     = $icon.IsPromoted
                    executablePath = $icon.ExecutablePath
                    iconResource   = $icon.IconResource
                }
            })
        legacy        = [ordered]@{
            enableAutoTray     = $(if ($null -ne $autoTray) { [Convert]::ToInt32($autoTray) } else { $null })
            systemIconPolicies = (script:Get-SystemIconPolicies)
        }
    }

    $json = $data | ConvertTo-Json -Depth 6
    Set-Content -LiteralPath $Path -Value $json -Encoding utf8NoBOM -Force
    script:Write-TraceLog "Backup written: $Path ($($icons.Count) icons)"

    Get-Item -LiteralPath $Path
}
