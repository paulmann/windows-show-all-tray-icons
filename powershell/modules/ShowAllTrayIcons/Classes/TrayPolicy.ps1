# ---------------------------------------------------------------------------
# TrayPolicy.ps1 -- single source of truth for every registry location and
# constant used by the module. NOTE: paths below are the *correct* modern
# locations; the pre-7.0 versions of this project wrote several of them to
# invalid keys (see docs/HOW-IT-WORKS.md).
# ---------------------------------------------------------------------------

class TrayPolicy {
    # Per-icon visibility store (Windows 10 1703+ / Windows 11 / Server 2019+).
    # Subkey name is the icon id (usually a GUID); DWORD 'IsPromoted' 1 = always
    # visible on the taskbar, 0 = collapsed into the overflow flyout.
    static [string] $NotifyIconSettings = 'Control Panel\NotifyIconSettings'

    # Legacy "hide inactive icons" switch (kept for belt-and-suspenders).
    static [string] $ExplorerKey        = 'Software\Microsoft\Windows\CurrentVersion\Explorer'
    static [string] $EnableAutoTrayName = 'EnableAutoTray'

    # Correct home of the system-icon policies (NOT under ...\CurrentVersion\Explorer!).
    static [string] $ExplorerPoliciesKey = 'Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    static [string[]] $SystemIconPolicyNames = @(
        'HideSCAVolume'
        'HideSCANetwork'
        'HideSCAPower'
    )

    # Pre-1703 icon cache (only touched by Reset-TrayIconCache).
    static [string] $LegacyTrayNotifyKey = 'Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify'
    static [string[]] $LegacyCacheValues = @('IconStreams', 'PastIconsStream')

    # Autostart (HKCU Run key).
    static [string] $RunKey           = 'Software\Microsoft\Windows\CurrentVersion\Run'
    static [string] $AutostartValue   = 'TrayIconGuard'

    # Value names inside a NotifyIconSettings subkey.
    static [string] $IsPromotedName   = 'IsPromoted'
    static [string] $ExecutablePathName = 'ExecutablePath'
    static [string] $IconResourceName = 'IconResource'
    static [string] $IconSnapshotName = 'IconSnapshot'
    static [string] $LastNotificationName = 'LastNotificationAddedTime'

    # Minimum supported Windows build: 1703 / RS2 (NotifyIconSettings exists).
    static [int] $MinWindowsBuild = 15063

    # Default directories (populated lazily by Get-DataDirectory).
    static [string] $AppFolderName  = 'ShowAllTrayIcons'
    static [string] $BackupFolderName = 'backups'
    static [string] $LogFolderName  = 'logs'

    # Backup JSON schema version produced by Backup-TrayIconState.
    static [int] $BackupSchemaVersion = 7
}
