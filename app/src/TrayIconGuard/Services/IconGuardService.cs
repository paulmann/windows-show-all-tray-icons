using TrayIconGuard.Models;

namespace TrayIconGuard.Services;

/// <summary>Outcome of one guard scan.</summary>
public sealed record ScanResult(
    IReadOnlyList<TrayIconEntry> Entries,
    int PromotedNow,
    int Failed,
    int NewlyDiscovered)
{
    public int Total => Entries.Count;
    public int Visible => Entries.Count(e => e.IsPromoted);
    public int Excluded => Entries.Count(e => e.IsExcluded);
    public int Hidden => Total - Visible;
}

/// <summary>
/// The product core: combines the registry service with the event-driven
/// monitor. Every time Explorer touches NotifyIconSettings (apps registering,
/// re-registering, or Windows resetting IsPromoted to 0), the guard rescans
/// and instantly re-promotes hidden icons. Thread-safe; events fire on
/// background threads (the UI layer marshals to the dispatcher).
/// </summary>
public sealed class IconGuardService : IDisposable
{
    private readonly TrayRegistryService _registry = new();
    private readonly RegistryMonitor _monitor = new(TrayRegistryService.NotifyIconSettingsPath);
    private readonly HashSet<string> _knownIds = new(StringComparer.OrdinalIgnoreCase);

    private AppSettings _settings = new();
    private int _scanning; // reentrancy guard (0 = idle, 1 = scan in flight)
    private int _totalPromoted;
    private DateTime _lastExplorerRestartUtc = DateTime.MinValue;
    private bool _disposed;

    public event Action<TrayIconEntry>? IconPromoted;
    public event Action<TrayIconEntry>? IconDiscovered;
    public event Action<ScanResult>? ScanCompleted;
    public event Action<string>? StatusMessage;

    public bool IsRunning { get; private set; }
    public bool IsPaused { get; private set; }
    public int TotalPromotedThisSession => Volatile.Read(ref _totalPromoted);

    public IconGuardService()
    {
        _monitor.Changed += () => _ = Task.Run(() => ScanOnce(promote: true));
    }

    public void ApplySettings(AppSettings settings)
    {
        _settings = settings.Clone();
        _monitor.UseEvents = _settings.UseEventDrivenMonitor;
        _monitor.PollIntervalSeconds = _settings.PollIntervalSeconds;
        _monitor.DebounceMilliseconds = _settings.DebounceMilliseconds;
    }

    public void Start()
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        if (IsRunning)
        {
            return;
        }

        IsRunning = true;
        IsPaused = false;

        // Initial pass: promote what is already hidden, seed known ids quietly.
        ScanOnce(promote: true, force: true, fireDiscovered: false);
        _monitor.Start();

        StatusMessage?.Invoke("Guard running");
        LogService.Instance.Info("Icon guard started.");
    }

    public void Stop()
    {
        _monitor.Stop();
        IsRunning = false;
        StatusMessage?.Invoke("Guard stopped");
        LogService.Instance.Info("Icon guard stopped.");
    }

    public void Pause()
    {
        IsPaused = true;
        StatusMessage?.Invoke("Guard paused (monitoring continues, promotion suspended)");
        LogService.Instance.Info("Guard paused.");
    }

    public void Resume()
    {
        IsPaused = false;
        StatusMessage?.Invoke("Guard running");
        LogService.Instance.Info("Guard resumed.");
        _ = Task.Run(() => ScanOnce(promote: true, force: true));
    }

    /// <summary>Manual "Show All Now": applies legacy switches and force-promotes.</summary>
    public ScanResult ShowAllNow()
    {
        _registry.SetLegacyAutoTray(showAll: true);
        _registry.ClearHidePolicies();
        var result = ScanOnce(promote: true, force: true);
        LogService.Instance.Info(
            $"Show All Now: {result.PromotedNow} promoted, {result.Visible}/{result.Total} visible.");
        return result;
    }

    /// <summary>Restore Windows defaults: demote everything, drop legacy override.</summary>
    public ScanResult RestoreDefaults()
    {
        var (demoted, failed) = _registry.DemoteAll();
        _registry.SetLegacyAutoTray(showAll: false);
        LogService.Instance.Info($"Restore defaults: {demoted} demoted, {failed} failed.");
        return ScanOnce(promote: false, force: true);
    }

    /// <summary>Per-icon toggle from the UI. Rolls the entry back on failure.</summary>
    public bool SetIconPromotion(TrayIconEntry entry, bool promoted)
    {
        var ok = _registry.SetPromoted(entry.Id, promoted);
        if (!ok)
        {
            entry.IsPromoted = !promoted;
        }

        LogService.Instance.Info($"'{entry.DisplayName}' -> {(promoted ? "visible" : "hidden")} (ok={ok})");
        return ok;
    }

    public ScanResult ScanOnce(bool promote, bool force = false, bool fireDiscovered = true)
    {
        if (Interlocked.CompareExchange(ref _scanning, 1, 0) != 0)
        {
            // Another scan is already in flight; skip this cycle.
            return new ScanResult([], 0, 0, 0);
        }

        try
        {
            var entries = _registry.Scan(_settings.ExcludedExecutables);

            int discovered = 0;
            foreach (var entry in entries)
            {
                if (_knownIds.Add(entry.Id))
                {
                    discovered++;
                    if (fireDiscovered)
                    {
                        LogService.Instance.Info($"New tray icon discovered: '{entry.DisplayName}' ({entry.Id})");
                        IconDiscovered?.Invoke(entry);
                    }
                }
            }

            int promotedNow = 0;
            int failed = 0;
            if (promote && (force || (!IsPaused && _settings.AutoPromoteNewIcons)))
            {
                (promotedNow, failed) = _registry.PromoteHidden(entries, onPromoted: entry =>
                {
                    Interlocked.Increment(ref _totalPromoted);
                    LogService.Instance.Info($"Auto-promoted '{entry.DisplayName}' ({entry.Id})");
                    IconPromoted?.Invoke(entry);
                });

                if (promotedNow > 0 && _settings.AutoRestartExplorer &&
                    (DateTime.UtcNow - _lastExplorerRestartUtc).TotalSeconds >= 60)
                {
                    _lastExplorerRestartUtc = DateTime.UtcNow;
                    StatusMessage?.Invoke("Restarting Explorer to apply changes...");
                    _ = Task.Run(async () =>
                    {
                        await ExplorerService.RestartAsync().ConfigureAwait(false);
                        StatusMessage?.Invoke("Guard running");
                    });
                }
            }

            var result = new ScanResult(entries, promotedNow, failed, discovered);
            ScanCompleted?.Invoke(result);
            return result;
        }
        catch (Exception ex)
        {
            LogService.Instance.Error("Scan failed", ex);
            StatusMessage?.Invoke("Scan failed - see Activity Log");
            return new ScanResult([], 0, 0, 0);
        }
        finally
        {
            Interlocked.Exchange(ref _scanning, 0);
        }
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _monitor.Dispose();
        _disposed = true;
    }
}
