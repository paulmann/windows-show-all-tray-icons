# ---------------------------------------------------------------------------
# TrayStatusReport.ps1 -- machine- and human-readable status snapshot returned
# by Get-TrayIconState.
# ---------------------------------------------------------------------------

class TrayStatusReport {
    [datetime] $Timestamp
    [string]   $ComputerName
    [string]   $UserName

    # Windows marketing name, e.g. "Windows 11 Pro" or "Windows Server 2025 Standard".
    [string]   $WindowsEdition
    [string]   $WindowsVersionLabel   # e.g. "24H2"
    [int]      $WindowsBuild
    [string]   $InstallationType      # Client | Server
    [bool]     $PlatformSupported

    [int] $TotalIcons
    [int] $VisibleIcons
    [int] $HiddenIcons
    [int] $ExcludedIcons
    [bool] $AllIconsVisible

    # Legacy switches. $null = value not present (Windows default).
    [Nullable[int]] $EnableAutoTray
    [hashtable]     $SystemIconPolicies

    [bool]   $AutostartInstalled
    [string] $AutostartCommand

    [string] ToString() {
        $sb = [System.Text.StringBuilder]::new()
        [void] $sb.AppendLine('Tray status @ {0:yyyy-MM-dd HH:mm:ss} on {1}' -f $this.Timestamp, $this.ComputerName)
        [void] $sb.AppendLine(('  Windows        : {0} ({1}) build {2} [{3}]' -f $this.WindowsEdition, $this.WindowsVersionLabel, $this.WindowsBuild, $this.InstallationType))
        [void] $sb.AppendLine(('  Icons          : {0} total | {1} visible | {2} hidden | {3} excluded' -f $this.TotalIcons, $this.VisibleIcons, $this.HiddenIcons, $this.ExcludedIcons))
        [void] $sb.AppendLine(('  All visible    : {0}' -f $this.AllIconsVisible))
        [void] $sb.AppendLine(('  EnableAutoTray : {0}' -f $(if ($null -eq $this.EnableAutoTray) { '<default>' } else { $this.EnableAutoTray })))
        [void] $sb.AppendLine(('  Autostart      : {0}' -f $(if ($this.AutostartInstalled) { $this.AutostartCommand } else { 'not installed' })))
        return $sb.ToString().TrimEnd()
    }
}
