# ---------------------------------------------------------------------------
# Enums.ps1 -- shared enumerations for the ShowAllTrayIcons module.
# Loaded FIRST by ShowAllTrayIcons.psm1 (other classes depend on it).
# ---------------------------------------------------------------------------

[Flags()]
enum TrayFixComponents {
    # Nothing (opt-out sentinel).
    None               = 0
    # Promote every registered notification-area icon (IsPromoted = 1).
    PromoteIcons       = 1
    # Legacy compatibility switch EnableAutoTray = 0 (Win7-era "hide inactive icons").
    LegacyAutoTray     = 2
    # Remove stale HideSCAVolume / HideSCANetwork / HideSCAPower policy values
    # that force system icons to be hidden.
    SystemIconPolicies = 4
    # Everything above (default).
    All                = 7
}

enum TrayWatcherEventType {
    # Registry change notification fired (event-driven mode).
    RegistryChanged = 0
    # A scan completed (poll mode, debounce settle, or periodic re-arm).
    ScanCompleted   = 1
    # A hidden icon was promoted to visible.
    IconPromoted    = 2
    # A brand-new icon registration (new subkey) was observed.
    IconDiscovered  = 3
    # An error occurred but the watcher continues.
    Error           = 4
    # The watcher stopped (timeout, Ctrl+C, disposal).
    Stopped         = 5
}

enum TrayEdition {
    Bat        = 0
    PowerShell = 1
    Gui        = 2
}
