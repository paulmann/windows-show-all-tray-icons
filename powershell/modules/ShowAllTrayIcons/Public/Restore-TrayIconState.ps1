function Restore-TrayIconState {
    <#
    .SYNOPSIS
        Restores tray icon visibility from a JSON backup created by Backup-TrayIconState.

    .DESCRIPTION
        Re-applies per-icon IsPromoted values (recreating subkeys for icons that have
        since unregistered) plus the legacy EnableAutoTray value and HideSCA* policies
        captured in the backup. Use -Latest to pick the newest backup automatically.

    .PARAMETER Path
        Backup file to restore. Mutually exclusive with -Latest.

    .PARAMETER Latest
        Restore the newest TrayIconState-*.json from the backup directory.

    .PARAMETER RestartExplorer
        Restart explorer.exe after restoring so changes apply immediately.

    .PARAMETER AsJson
        Emit the summary as JSON on stdout (stdout stays pure: under -WhatIf the
        announcement goes to the information stream, never to stdout).

    .EXAMPLE
        Restore-TrayIconState -Latest -RestartExplorer

    .EXAMPLE
        Restore-TrayIconState -Latest -AsJson -WhatIf | ConvertFrom-Json

    .EXAMPLE
        Restore-TrayIconState -Path .\TrayIconState-20261012-090000.json

    .OUTPUTS
        System.Management.Automation.PSCustomObject

    .LINK
        https://github.com/paulmann/windows-show-all-tray-icons/blob/main/docs/CLI-REFERENCE.md
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByPath')]
    [OutputType([pscustomobject])]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByPath', Position = 0)]
        [string] $Path,

        [Parameter(Mandatory, ParameterSetName = 'Latest')]
        [switch] $Latest,

        [switch] $RestartExplorer,

        [switch] $AsJson
    )

    script:Assert-WindowsPlatform | Out-Null

    if ($Latest) {
        $backupDir = script:Get-BackupDirectory
        $newest = Get-ChildItem -LiteralPath $backupDir -Filter 'TrayIconState-*.json' -File -ErrorAction SilentlyContinue |
            Sort-Object -Property LastWriteTime -Descending |
            Select-Object -First 1
        if (-not $newest) {
            throw [System.IO.FileNotFoundException]::new(
                "No backups found in $backupDir. Create one with Backup-TrayIconState first.")
        }
        $Path = $newest.FullName
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        throw [System.IO.FileNotFoundException]::new("Backup file not found: $Path", $Path)
    }

    $data = Get-Content -LiteralPath $Path -Raw -Encoding utf8NoBOM | ConvertFrom-Json -AsHashtable
    if (-not $data -or -not $data.ContainsKey('schemaVersion')) {
        throw [System.IO.InvalidDataException]::new("'$Path' is not a ShowAllTrayIcons backup (schemaVersion missing).")
    }
    if ([int] $data.schemaVersion -ne [TrayPolicy]::BackupSchemaVersion) {
        Write-Warning ("Backup schema v{0} differs from current v{1}; restoring best-effort." -f `
                $data.schemaVersion, [TrayPolicy]::BackupSchemaVersion)
    }

    $summary = [ordered]@{
        Action          = 'Restore'
        File            = $Path
        IconsRestored   = 0
        IconsFailed     = 0
        LegacyRestored  = $false
        ExplorerRestarted = $null
    }

    if (script:Invoke-ShouldProcess -Cmdlet $PSCmdlet -Target $Path -Action 'Restore tray icon state' -MachineReadable:$AsJson) {
        $root = script:Open-TraySettingsRoot -Writable
        try {
            foreach ($icon in @($data.icons)) {
                if (-not $icon -or -not $icon['id']) { continue }
                try {
                    $sub = $root.CreateSubKey([string] $icon['id'])
                    try {
                        $sub.SetValue([TrayPolicy]::IsPromotedName,
                            [int] ([bool] $icon['isPromoted']),
                            [Microsoft.Win32.RegistryValueKind]::DWord)
                        if ($icon['executablePath']) {
                            $sub.SetValue([TrayPolicy]::ExecutablePathName,
                                [string] $icon['executablePath'],
                                [Microsoft.Win32.RegistryValueKind]::String)
                        }
                        $summary.IconsRestored++
                    }
                    finally { $sub.Dispose() }
                }
                catch {
                    $summary.IconsFailed++
                    script:Write-TraceLog "Restore failed for '$($icon['id'])': $($_.Exception.Message)" 'ERROR'
                }
            }
        }
        finally {
            $root.Dispose()
        }

        if ($data.ContainsKey('legacy') -and $data['legacy']) {
            $legacy = $data['legacy']
            if ($null -ne $legacy['enableAutoTray']) {
                script:Set-ExplorerKeyValue -Name ([TrayPolicy]::EnableAutoTrayName) -Value ([Convert]::ToInt32($legacy['enableAutoTray']))
                $summary.LegacyRestored = $true
            }
            if ($legacy['systemIconPolicies']) {
                $policyKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey([TrayPolicy]::ExplorerPoliciesKey)
                try {
                    foreach ($name in [TrayPolicy]::SystemIconPolicyNames) {
                        if ($legacy['systemIconPolicies'].ContainsKey($name) -and $null -ne $legacy['systemIconPolicies'][$name]) {
                            $policyKey.SetValue($name,
                                [Convert]::ToInt32($legacy['systemIconPolicies'][$name]),
                                [Microsoft.Win32.RegistryValueKind]::DWord)
                        }
                    }
                }
                finally { $policyKey.Dispose() }
                $summary.LegacyRestored = $true
            }
        }
        script:Write-TraceLog "Restored $($summary.IconsRestored) icon(s) from $Path"
    }

    if ($RestartExplorer) {
        if (script:Invoke-ShouldProcess -Cmdlet $PSCmdlet -Target 'explorer.exe' -Action 'Restart to apply restored state' -MachineReadable:$AsJson) {
            $restart = script:Restart-ExplorerCore
            $summary.ExplorerRestarted = $restart.Success
        }
    }

    $result = [pscustomobject] $summary
    if ($AsJson) { return ($result | ConvertTo-Json -Depth 4) }
    $result
}
