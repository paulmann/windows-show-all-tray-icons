# ---------------------------------------------------------------------------
# TrayIconInfo.ps1 -- one registered notification-area icon.
# ---------------------------------------------------------------------------

class TrayIconInfo {
    # Subkey name under HKCU\Control Panel\NotifyIconSettings (usually a GUID).
    [string] $Id

    # Friendly name derived from the executable (or the Id when unknown).
    [string] $DisplayName

    # Full path of the executable that owns the icon ($null for some system entries).
    [string] $ExecutablePath

    # Icon resource string, e.g. "C:\App\app.exe,-101" (may be $null).
    [string] $IconResource

    # $true = always visible on the taskbar; $false = hidden in the overflow flyout.
    [bool] $IsPromoted

    # When Explorer last saw a notification from this icon (UTC; $null if never).
    [Nullable[datetime]] $LastNotification

    # $true when Explorer stored a rendered bitmap snapshot of the icon.
    [bool] $HasSnapshot

    # $true when the icon matches the user's exclusion list.
    [bool] $IsExcluded

    TrayIconInfo() { }

    [string] GetVisibilityText() {
        if ($this.IsPromoted) { return 'Visible' }
        if ($this.IsExcluded) { return 'Hidden (excluded)' }
        return 'Hidden'
    }

    [string] ToString() {
        return ('{0,-28} {1,-8} {2}' -f $this.DisplayName, $this.GetVisibilityText(), $this.Id)
    }
}
