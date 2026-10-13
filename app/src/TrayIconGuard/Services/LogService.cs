using System.IO;
using TrayIconGuard.Models;

namespace TrayIconGuard.Services;

/// <summary>
/// File + in-memory logger. Daily file under
/// %LOCALAPPDATA%\TrayIconGuard\logs, 14 files retained, 500-entry UI buffer.
/// Logging never throws: a dead log must not kill the guard.
/// </summary>
public sealed class LogService
{
    public static LogService Instance { get; } = new();

    private const int MaxBufferEntries = 500;
    private const int MaxLogFiles = 14;

    private readonly object _gate = new();
    private readonly List<LogEntry> _buffer = [];

    private string? _currentFile;
    private DateTime _currentDay;

    public static string LogDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "TrayIconGuard",
        "logs");

    /// <summary>Entry added (any thread). The UI marshals to the dispatcher.</summary>
    public event Action<LogEntry>? EntryAdded;

    public IReadOnlyList<LogEntry> Snapshot()
    {
        lock (_gate)
        {
            return _buffer.ToList();
        }
    }

    public void Debug(string message) => Write(LogLevel.Debug, message);
    public void Info(string message) => Write(LogLevel.Info, message);
    public void Warn(string message) => Write(LogLevel.Warn, message);

    public void Error(string message, Exception? ex = null) =>
        Write(LogLevel.Error, ex is null ? message : $"{message}: {ex.GetType().Name}: {ex.Message}");

    private void Write(LogLevel level, string message)
    {
        var entry = new LogEntry(DateTime.Now, level, message);

        lock (_gate)
        {
            _buffer.Add(entry);
            if (_buffer.Count > MaxBufferEntries)
            {
                _buffer.RemoveRange(0, _buffer.Count - MaxBufferEntries);
            }
        }

        try
        {
            var file = EnsureFile();
            File.AppendAllText(file, $"[{entry.Timestamp:yyyy-MM-dd HH:mm:ss.fff}] [{level,-5}] {message}{Environment.NewLine}");
        }
        catch (Exception)
        {
            // Logging must never crash the application.
        }

        try
        {
            EntryAdded?.Invoke(entry);
        }
        catch (Exception)
        {
            // A broken subscriber must not kill logging.
        }
    }

    private string EnsureFile()
    {
        lock (_gate)
        {
            var today = DateTime.Now.Date;
            if (_currentFile is null || today != _currentDay)
            {
                Directory.CreateDirectory(LogDirectory);
                _currentDay = today;
                _currentFile = Path.Combine(LogDirectory, $"TrayIconGuard-{today:yyyyMMdd}.log");

                try
                {
                    var stale = Directory.GetFiles(LogDirectory, "TrayIconGuard-*.log")
                        .Select(f => new FileInfo(f))
                        .OrderByDescending(f => f.LastWriteTime)
                        .Skip(MaxLogFiles);
                    foreach (var f in stale)
                    {
                        try
                        {
                            f.Delete();
                        }
                        catch (Exception)
                        {
                            // Best effort rotation.
                        }
                    }
                }
                catch (Exception)
                {
                    // Rotation is best effort.
                }
            }

            return _currentFile;
        }
    }
}
