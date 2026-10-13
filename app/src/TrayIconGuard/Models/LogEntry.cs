namespace TrayIconGuard.Models;

public enum LogLevel
{
    Debug,
    Info,
    Warn,
    Error,
}

/// <summary>One line in the activity log (in-memory ring buffer + daily file).</summary>
public sealed record LogEntry(DateTime Timestamp, LogLevel Level, string Message)
{
    public string TimeText => Timestamp.ToString("HH:mm:ss");
}
