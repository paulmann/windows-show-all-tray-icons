# ---------------------------------------------------------------------------
# Assert-WindowsPlatform.ps1 -- internal platform guard.
# ---------------------------------------------------------------------------

function script:Assert-WindowsPlatform {
    <#
    .SYNOPSIS
        Internal guard: throws unless running on a supported Windows SKU.
    .OUTPUTS
        System.Management.Automation.PSCustomObject (Build, Version)
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    if (-not $IsWindows) {
        throw [System.PlatformNotSupportedException]::new(
            'ShowAllTrayIcons requires Windows 10 1703+, Windows 11, or Windows Server 2019+. ' +
            'The per-icon tray store it manages (HKCU\Control Panel\NotifyIconSettings) does not exist on this platform.')
    }

    $os = [System.Environment]::OSVersion.Version
    if ($os.Build -lt [TrayPolicy]::MinWindowsBuild) {
        $message = 'Windows build {0} is older than the minimum supported build {1} (Windows 10 1703). NotifyIconSettings is unavailable; upgrade Windows.' -f $os.Build, [TrayPolicy]::MinWindowsBuild
        throw [System.PlatformNotSupportedException]::new($message)
    }

    [pscustomobject]@{
        Build   = $os.Build
        Version = $os
    }
}
