function script:Find-TrayIconGuardExecutable {
    <#
    .SYNOPSIS
        Internal: locates TrayIconGuard.exe in well-known build/install locations.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\TrayIconGuard\TrayIconGuard.exe')   # Inno Setup per-user default
        (Join-Path $env:ProgramFiles 'TrayIconGuard\TrayIconGuard.exe')             # machine-wide install
        (Join-Path $env:ProgramFiles 'ShowAllTrayIcons\TrayIconGuard.exe')
    )

    # Repo build outputs relative to the module directory (...\powershell\modules\ShowAllTrayIcons).
    $appBin = Join-Path $script:ModuleRoot '..\..\..\app\src\TrayIconGuard\bin'
    if (Test-Path -LiteralPath $appBin) {
        $candidates += @(
            Get-ChildItem -LiteralPath $appBin -Recurse -Filter 'TrayIconGuard.exe' -File -ErrorAction SilentlyContinue |
                Sort-Object -Property LastWriteTime -Descending |
                Select-Object -ExpandProperty FullName
        )
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    $null
}

function Install-TrayIconAutostart {
    <#
    .SYNOPSIS
        Installs "start with Windows" for the GUI or the headless watcher.

    .DESCRIPTION
        Writes the HKCU Run value 'TrayIconGuard' so protection survives reboots:

        * -Target Gui     -> launches TrayIconGuard.exe (optionally --minimized).
        * -Target Watcher -> launches the current pwsh.exe hidden, running
          Start-TrayIconWatcher via -EncodedCommand (no console window, no quoting issues).

        Remove again with Uninstall-TrayIconAutostart. The GUI manages the same value
        through its Settings tab.

    .PARAMETER Target
        What to start at logon: the GUI (default) or the headless PowerShell watcher.

    .PARAMETER GuiExecutablePath
        Explicit path to TrayIconGuard.exe. When omitted, well-known locations are probed
        (installer dir, repo build output).

    .PARAMETER StartMinimized
        GUI target: start minimized to the notification area.

    .PARAMETER WatcherIntervalSec
        Watcher target: polling/heartbeat interval passed to Start-TrayIconWatcher.

    .PARAMETER ExcludeExecutable
        Watcher target: exclusions baked into the encoded command.

    .EXAMPLE
        Install-TrayIconAutostart -Target Gui -StartMinimized

    .EXAMPLE
        Install-TrayIconAutostart -Target Watcher -ExcludeExecutable onedrive.exe

    .OUTPUTS
        System.Management.Automation.PSCustomObject

    .LINK
        https://github.com/paulmann/windows-show-all-tray-icons/blob/main/docs/CLI-REFERENCE.md
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [ValidateSet('Gui', 'Watcher')]
        [string] $Target = 'Gui',

        [string] $GuiExecutablePath,

        [switch] $StartMinimized,

        [ValidateRange(1, 3600)]
        [int] $WatcherIntervalSec = 3,

        [string[]] $ExcludeExecutable
    )

    script:Assert-WindowsPlatform | Out-Null

    $command = switch ($Target) {
        'Gui' {
            $exe = $GuiExecutablePath
            if (-not $exe) { $exe = script:Find-TrayIconGuardExecutable }
            if (-not $exe) {
                throw [System.IO.FileNotFoundException]::new(
                    'TrayIconGuard.exe not found. Build it (dotnet publish app/src/TrayIconGuard) or run the ' +
                    'installer, then pass -GuiExecutablePath. Use -Target Watcher for the headless PowerShell watcher.')
            }
            $exe = (Resolve-Path -LiteralPath $exe).Path
            $suffix = if ($StartMinimized) { ' --minimized' } else { '' }
            '"{0}"{1}' -f $exe, $suffix
        }
        'Watcher' {
            $pwshPath = (Get-Process -Id $PID).Path
            $manifestPath = Join-Path $script:ModuleRoot 'ShowAllTrayIcons.psd1'
            $watcherCommand = "Import-Module -LiteralPath '$manifestPath' -Force; Start-TrayIconWatcher -IntervalSec $WatcherIntervalSec"
            if ($ExcludeExecutable -and $ExcludeExecutable.Count -gt 0) {
                $quoted = ($ExcludeExecutable | ForEach-Object { "'$($_.Replace("'", "''"))'" }) -join ', '
                $watcherCommand += " -ExcludeExecutable $quoted"
            }
            $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($watcherCommand))
            '"{0}" -NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand {1}' -f $pwshPath, $encoded
        }
    }

    if ($PSCmdlet.ShouldProcess("HKCU Run value '$([TrayPolicy]::AutostartValue)'", "Install autostart ($Target)")) {
        $runKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey([TrayPolicy]::RunKey)
        try {
            $runKey.SetValue([TrayPolicy]::AutostartValue, $command, [Microsoft.Win32.RegistryValueKind]::String)
        }
        finally {
            $runKey.Dispose()
        }
        script:Write-TraceLog "Autostart installed ($Target): $command"
    }

    [pscustomobject]@{
        Target    = $Target
        ValueName = [TrayPolicy]::AutostartValue
        Command   = $command
    }
}
