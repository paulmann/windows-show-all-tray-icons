namespace TrayIconGuard.Models;

/// <summary>
/// Persisted user settings (%APPDATA%\TrayIconGuard\settings.json).
/// Defaults reflect the recommended "set and forget" configuration.
/// </summary>
public sealed class AppSettings
{
    /// <summary>Automatically promote icons that Explorer hides (the core feature).</summary>
    public bool AutoPromoteNewIcons { get; set; } = true;

    /// <summary>Start the app minimized to the notification area.</summary>
    public bool StartMinimized { get; set; } = true;

    /// <summary>Close/minimize button hides to tray instead of exiting.</summary>
    public bool MinimizeToTray { get; set; } = true;

    /// <summary>Run at logon via the HKCU Run key.</summary>
    public bool StartWithWindows { get; set; }

    /// <summary>Restart explorer.exe after promotions (disruptive; off by default).</summary>
    public bool AutoRestartExplorer { get; set; }

    /// <summary>Show a balloon notification when icons are auto-promoted.</summary>
    public bool ShowBalloonOnPromote { get; set; } = true;

    /// <summary>Use RegNotifyChangeKeyValue events; otherwise poll.</summary>
    public bool UseEventDrivenMonitor { get; set; } = true;

    /// <summary>Poll interval / notification re-arm window (seconds).</summary>
    public int PollIntervalSeconds { get; set; } = 3;

    /// <summary>Quiet period after a registry event before scanning (ms).</summary>
    public int DebounceMilliseconds { get; set; } = 400;

    /// <summary>"System" | "Light" | "Dark".</summary>
    public string Theme { get; set; } = "System";

    /// <summary>Executables never promoted (file name, full path, or * wildcard).</summary>
    public List<string> ExcludedExecutables { get; set; } = [];

    public AppSettings Clone()
    {
        var clone = (AppSettings)MemberwiseClone();
        clone.ExcludedExecutables = [.. ExcludedExecutables];
        return clone;
    }

    /// <summary>Clamps ranges and normalizes values after load or edit.</summary>
    public void Sanitize()
    {
        PollIntervalSeconds = Math.Clamp(PollIntervalSeconds, 1, 3600);
        DebounceMilliseconds = Math.Clamp(DebounceMilliseconds, 100, 10_000);
        if (Theme is not ("System" or "Light" or "Dark"))
        {
            Theme = "System";
        }

        ExcludedExecutables = ExcludedExecutables
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .Select(s => s.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }
}
