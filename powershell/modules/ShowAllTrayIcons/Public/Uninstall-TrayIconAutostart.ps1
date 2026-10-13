function Uninstall-TrayIconAutostart {
    <#
    .SYNOPSIS
        Removes the TrayIconGuard autostart entry from the HKCU Run key.

    .DESCRIPTION
        Deletes the 'TrayIconGuard' Run value installed by Install-TrayIconAutostart
        (GUI or headless watcher -- both share the same value name). Safe to run when
        nothing is installed.

    .EXAMPLE
        Uninstall-TrayIconAutostart

    .OUTPUTS
        System.Management.Automation.PSCustomObject

    .LINK
        https://github.com/paulmann/windows-show-all-tray-icons/blob/main/docs/CLI-REFERENCE.md
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param()

    script:Assert-WindowsPlatform | Out-Null

    $removed = $false
    $previousCommand = $null

    $runKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey([TrayPolicy]::RunKey, $true)
    if ($runKey) {
        try {
            $previousCommand = $runKey.GetValue([TrayPolicy]::AutostartValue)
            if ($null -ne $previousCommand) {
                if ($PSCmdlet.ShouldProcess("HKCU Run value '$([TrayPolicy]::AutostartValue)'", 'Remove autostart entry')) {
                    $runKey.DeleteValue([TrayPolicy]::AutostartValue, $false)
                    $removed = $true
                    script:Write-TraceLog 'Autostart entry removed.'
                }
            }
        }
        finally {
            $runKey.Dispose()
        }
    }

    if (-not $removed -and -not $previousCommand) {
        Write-Verbose 'No autostart entry was installed; nothing to remove.'
    }

    [pscustomobject]@{
        Removed         = $removed
        ValueName       = [TrayPolicy]::AutostartValue
        PreviousCommand = if ($previousCommand) { [string] $previousCommand } else { $null }
    }
}
