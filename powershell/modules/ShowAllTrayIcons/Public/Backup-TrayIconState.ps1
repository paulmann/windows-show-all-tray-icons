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
    # .NET instead of New-Item/Set-Content (audit R4-1): both implement
    # SupportsShouldProcess, so under -WhatIf they print "What if: ..." to the
    # host -- in a redirected child process that lands on STDOUT and breaks the
    # documented -AsJson contract. A backup is a real file write, so it is done
    # with .NET APIs and is deliberately NOT gated by -WhatIf: -WhatIf protects
    # the REGISTRY (the user-visible tray state), while the backup is the safety
    # net that makes the change reversible.
    if ($parent -and -not [System.IO.Directory]::Exists($parent)) {
        $null = [System.IO.Directory]::CreateDirectory($parent)
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
    # .NET write with explicit UTF-8 without BOM (no Set-Content: it announces
    # itself under -WhatIf; see the note above).
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
    script:Write-TraceLog "Backup written: $Path ($($icons.Count) icons)"

    Get-Item -LiteralPath $Path
}
