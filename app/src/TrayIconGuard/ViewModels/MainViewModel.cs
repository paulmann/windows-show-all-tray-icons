using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows;
using System.Windows.Data;
using System.Windows.Threading;
using TrayIconGuard.Models;
using TrayIconGuard.Services;

namespace TrayIconGuard.ViewModels;

/// <summary>
/// Single view-model for the main window: icon list, live guard state,
/// settings proxies (auto-persisted) and the activity log feed.
/// All guard/log events arrive on background threads and are marshalled
/// to the UI dispatcher here.
/// </summary>
public sealed class MainViewModel : ViewModelBase
{
    private readonly IconGuardService _guard;
    private readonly Dispatcher _dispatcher;
    private readonly DateTime _sessionStart = DateTime.Now;
    private readonly DispatcherTimer _uptimeTimer;
    private readonly TimeSpan _balloonCooldown = TimeSpan.FromSeconds(10);

    private DateTime _lastBalloonUtc = DateTime.MinValue;
    private string _statusText = "Starting...";
    private string _watcherStateText = string.Empty;
    private string _searchText = string.Empty;
    private string _excludedExecutablesText;
    private int _totalCount;
    private int _visibleCount;
    private int _hiddenCount;
    private int _excludedCount;
    private int _sessionPromoted;
    private string _lastScanText = "last scan: -";

    public MainViewModel(AppSettings settings, IconGuardService guard, Dispatcher dispatcher)
    {
        Settings = settings;
        _guard = guard;
        _dispatcher = dispatcher;
        _excludedExecutablesText = string.Join(Environment.NewLine, settings.ExcludedExecutables);

        Icons = [];
        Logs = [];
        IconsView = CollectionViewSource.GetDefaultView(Icons);
        IconsView.SortDescriptions.Add(
            new SortDescription(nameof(TrayIconEntry.DisplayName), ListSortDirection.Ascending));
        IconsView.Filter = FilterIcon;

        var version = Assembly.GetEntryAssembly()?.GetName().Version?.ToString(3) ?? "7.0.3";
        VersionText = $"v{version} - .NET {Environment.Version.Major} - Windows 10/11";

        _uptimeTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(5) };
        _uptimeTimer.Tick += (_, _) =>
        {
            OnPropertyChanged(nameof(UptimeText));
            UpdateWatcherState();
        };

        RefreshCommand = new RelayCommand(() => RunScan(promote: false));
        ShowAllNowCommand = new RelayCommand(() =>
            RunGuardAction(() => _guard.ShowAllNow(), "Show All Now"));
        RestoreDefaultsCommand = new RelayCommand(() =>
            RunGuardAction(() => _guard.RestoreDefaults(), "Restore defaults"));
        RestartExplorerCommand = new RelayCommand(() =>
        {
            StatusText = "Restarting Explorer...";
            _ = Task.Run(async () =>
            {
                var (success, _, ms) = await ExplorerService.RestartAsync().ConfigureAwait(false);
                _ = _dispatcher.BeginInvoke(() =>
                    StatusText = success ? $"Explorer restarted in {ms} ms" : "Explorer restart FAILED - see log");
            });
        });
        ToggleGuardCommand = new RelayCommand(ToggleGuard);
        ToggleIconCommand = new RelayCommand(ToggleIcon);
        ClearLogCommand = new RelayCommand(() => Logs.Clear());
        OpenLogsFolderCommand = new RelayCommand(OpenLogsFolder);
        SaveSettingsCommand = new RelayCommand(SaveSettings);

        _guard.IconPromoted += OnIconPromoted;
        _guard.IconDiscovered += OnIconDiscovered;
        _guard.ScanCompleted += OnScanCompleted;
        _guard.StatusMessage += message => _dispatcher.BeginInvoke(() => StatusText = message);

        LogService.Instance.EntryAdded += entry => _dispatcher.BeginInvoke(() => AddLogEntry(entry));
        foreach (var entry in LogService.Instance.Snapshot())
        {
            AddLogEntry(entry);
        }

        _guard.ApplySettings(Settings);
        UpdateWatcherState();
    }

    // ---- Data collections --------------------------------------------------
    public ObservableCollection<TrayIconEntry> Icons { get; }
    public ObservableCollection<LogEntry> Logs { get; }
    public ICollectionView IconsView { get; }

    // ---- Commands ----------------------------------------------------------
    public RelayCommand RefreshCommand { get; }
    public RelayCommand ShowAllNowCommand { get; }
    public RelayCommand RestoreDefaultsCommand { get; }
    public RelayCommand RestartExplorerCommand { get; }
    public RelayCommand ToggleGuardCommand { get; }
    public RelayCommand ToggleIconCommand { get; }
    public RelayCommand ClearLogCommand { get; }
    public RelayCommand OpenLogsFolderCommand { get; }
    public RelayCommand SaveSettingsCommand { get; }

    // ---- View events -------------------------------------------------------
    public event Action<string, string>? RequestBalloon;
    public event Action? RequestExit;

    // ---- Settings ----------------------------------------------------------
    public AppSettings Settings { get; }

    // ---- Status ------------------------------------------------------------
    public string VersionText { get; }

    public string StatusText
    {
        get => _statusText;
        private set => SetProperty(ref _statusText, value);
    }

    public string WatcherStateText
    {
        get => _watcherStateText;
        private set => SetProperty(ref _watcherStateText, value);
    }

    public string UptimeText => $"uptime {(DateTime.Now - _sessionStart):hh\\:mm\\:ss}";

    public string LastScanText
    {
        get => _lastScanText;
        private set => SetProperty(ref _lastScanText, value);
    }

    public int TotalCount { get => _totalCount; private set => SetProperty(ref _totalCount, value); }
    public int VisibleCount { get => _visibleCount; private set => SetProperty(ref _visibleCount, value); }
    public int HiddenCount { get => _hiddenCount; private set => SetProperty(ref _hiddenCount, value); }
    public int ExcludedCount { get => _excludedCount; private set => SetProperty(ref _excludedCount, value); }

    public int SessionPromoted
    {
        get => _sessionPromoted;
        private set => SetProperty(ref _sessionPromoted, value);
    }

    public string CountsText =>
        ExcludedCount > 0
            ? $"{TotalCount} icons | {VisibleCount} visible | {HiddenCount} hidden | {ExcludedCount} excluded | {SessionPromoted} promoted this session"
            : $"{TotalCount} icons | {VisibleCount} visible | {HiddenCount} hidden | {SessionPromoted} promoted this session";

    public bool IsPaused => _guard.IsPaused;

    public string GuardToggleText => IsPaused ? "Resume guard" : "Pause guard";

    public string SearchText
    {
        get => _searchText;
        set
        {
            if (SetProperty(ref _searchText, value))
            {
                IconsView.Refresh();
            }
        }
    }

    // ---- Settings proxies (persist on change) -------------------------------
    public bool AutoPromoteNewIcons
    {
        get => Settings.AutoPromoteNewIcons;
        set { if (Settings.AutoPromoteNewIcons != value) { Settings.AutoPromoteNewIcons = value; OnPropertyChanged(); PersistSettings(); } }
    }

    public bool StartMinimized
    {
        get => Settings.StartMinimized;
        set { if (Settings.StartMinimized != value) { Settings.StartMinimized = value; OnPropertyChanged(); PersistSettings(); } }
    }

    public bool MinimizeToTray
    {
        get => Settings.MinimizeToTray;
        set { if (Settings.MinimizeToTray != value) { Settings.MinimizeToTray = value; OnPropertyChanged(); PersistSettings(); } }
    }

    public bool AutoRestartExplorer
    {
        get => Settings.AutoRestartExplorer;
        set { if (Settings.AutoRestartExplorer != value) { Settings.AutoRestartExplorer = value; OnPropertyChanged(); PersistSettings(); } }
    }

    public bool ShowBalloonOnPromote
    {
        get => Settings.ShowBalloonOnPromote;
        set { if (Settings.ShowBalloonOnPromote != value) { Settings.ShowBalloonOnPromote = value; OnPropertyChanged(); PersistSettings(); } }
    }

    public bool UseEventDrivenMonitor
    {
        get => Settings.UseEventDrivenMonitor;
        set
        {
            if (Settings.UseEventDrivenMonitor != value)
            {
                Settings.UseEventDrivenMonitor = value;
                OnPropertyChanged();
                PersistSettings();
                _guard.ApplySettings(Settings);
            }
        }
    }

    public int PollIntervalSeconds
    {
        get => Settings.PollIntervalSeconds;
        set
        {
            if (Settings.PollIntervalSeconds != value)
            {
                Settings.PollIntervalSeconds = Math.Clamp(value, 1, 3600);
                OnPropertyChanged();
                PersistSettings();
                _guard.ApplySettings(Settings);
            }
        }
    }

    public string Theme
    {
        get => Settings.Theme;
        set
        {
            if (Settings.Theme != value)
            {
                Settings.Theme = value;
                OnPropertyChanged();
                PersistSettings();
                ThemeService.Apply(value);
            }
        }
    }

    public bool StartWithWindows
    {
        get => Settings.StartWithWindows;
        set
        {
            if (Settings.StartWithWindows == value)
            {
                return;
            }

            Settings.StartWithWindows = value;
            OnPropertyChanged();
            if (value)
            {
                var ok = AutostartService.Enable(startMinimized: true);
                if (!ok)
                {
                    Settings.StartWithWindows = false;
                    OnPropertyChanged();
                    StatusText = "Could not enable autostart - see log";
                }
            }
            else
            {
                AutostartService.Disable();
            }

            PersistSettings();
        }
    }

    public string ExcludedExecutablesText
    {
        get => _excludedExecutablesText;
        set => SetProperty(ref _excludedExecutablesText, value);
    }

    // ---- Lifecycle ----------------------------------------------------------
    public void Start()
    {
        _uptimeTimer.Start();
        _guard.Start();
        StatusText = "Guard running - hidden icons are re-promoted automatically";
    }

    public void Shutdown()
    {
        try
        {
            _uptimeTimer.Stop();
            _guard.Stop();
            _guard.Dispose();
        }
        catch (Exception ex)
        {
            LogService.Instance.Error("Shutdown error", ex);
        }
    }

    public void RequestApplicationExit() => RequestExit?.Invoke();

    // ---- Guard event handlers ------------------------------------------------
    private void OnIconPromoted(TrayIconEntry entry) => _dispatcher.BeginInvoke(() =>
    {
        MergeEntry(entry);
        SessionPromoted = _guard.TotalPromotedThisSession;
        RecountFromIcons();

        if (Settings.ShowBalloonOnPromote &&
            DateTime.UtcNow - _lastBalloonUtc >= _balloonCooldown)
        {
            _lastBalloonUtc = DateTime.UtcNow;
            RequestBalloon?.Invoke(
                "Tray icon made visible",
                $"'{entry.DisplayName}' was hidden by Windows and has been promoted back to the taskbar.");
        }
    });

    private void OnIconDiscovered(TrayIconEntry entry) => _dispatcher.BeginInvoke(() => MergeEntry(entry));

    private void OnScanCompleted(ScanResult result) => _dispatcher.BeginInvoke(() =>
    {
        MergeEntries(result.Entries);
        TotalCount = result.Total;
        VisibleCount = result.Visible;
        HiddenCount = result.Hidden;
        ExcludedCount = result.Excluded;
        SessionPromoted = _guard.TotalPromotedThisSession;
        LastScanText = $"last scan: {DateTime.Now:HH:mm:ss}";
        OnPropertyChanged(nameof(CountsText));
    });

    // ---- Collection merging ---------------------------------------------------
    private void MergeEntries(IEnumerable<TrayIconEntry> fresh)
    {
        var byId = new Dictionary<string, TrayIconEntry>(StringComparer.OrdinalIgnoreCase);
        foreach (var existing in Icons)
        {
            byId[existing.Id] = existing;
        }

        var freshIds = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var entry in fresh)
        {
            freshIds.Add(entry.Id);
            if (byId.TryGetValue(entry.Id, out var existing))
            {
                existing.IsPromoted = entry.IsPromoted;
                existing.IsExcluded = entry.IsExcluded;
            }
            else
            {
                Icons.Add(entry);
            }
        }

        for (var i = Icons.Count - 1; i >= 0; i--)
        {
            if (!freshIds.Contains(Icons[i].Id))
            {
                Icons.RemoveAt(i);
            }
        }
    }

    private void MergeEntry(TrayIconEntry entry)
    {
        var existing = Icons.FirstOrDefault(i =>
            string.Equals(i.Id, entry.Id, StringComparison.OrdinalIgnoreCase));
        if (existing is null)
        {
            Icons.Add(entry);
        }
        else
        {
            existing.IsPromoted = entry.IsPromoted;
            existing.IsExcluded = entry.IsExcluded;
        }
    }

    private void RecountFromIcons()
    {
        TotalCount = Icons.Count;
        VisibleCount = Icons.Count(i => i.IsPromoted);
        ExcludedCount = Icons.Count(i => i.IsExcluded);
        HiddenCount = TotalCount - VisibleCount;
        LastScanText = $"last scan: {DateTime.Now:HH:mm:ss}";
        OnPropertyChanged(nameof(CountsText));
    }

    // ---- Command implementations ----------------------------------------------
    private void ToggleGuard()
    {
        if (_guard.IsPaused)
        {
            _guard.Resume();
        }
        else
        {
            _guard.Pause();
        }

        OnPropertyChanged(nameof(IsPaused));
        OnPropertyChanged(nameof(GuardToggleText));
        UpdateWatcherState();
    }

    private void ToggleIcon(object? parameter)
    {
        if (parameter is not TrayIconEntry entry)
        {
            return;
        }

        var desired = entry.IsPromoted; // checkbox binding already flipped the model
        _ = Task.Run(() =>
        {
            var ok = _guard.SetIconPromotion(entry, desired);
            _dispatcher.BeginInvoke(() =>
            {
                RecountFromIcons();
                StatusText = ok
                    ? $"'{entry.DisplayName}' set to {(desired ? "visible" : "hidden")}"
                    : $"Failed to update '{entry.DisplayName}' - see log";
            });
        });
    }

    private void SaveSettings()
    {
        Settings.ExcludedExecutables = (ExcludedExecutablesText ?? string.Empty)
            .Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .ToList();

        Settings.Sanitize();
        SettingsService.Instance.Save(Settings);
        _guard.ApplySettings(Settings);
        ThemeService.Apply(Settings.Theme);

        // Rebuild StartWithWindows to honor the StartMinimized preference.
        if (Settings.StartWithWindows)
        {
            AutostartService.Enable(startMinimized: Settings.StartMinimized);
        }

        StatusText = "Settings saved";
        RunScan(promote: true);
    }

    private void OpenLogsFolder()
    {
        try
        {
            Directory.CreateDirectory(LogService.LogDirectory);
            Process.Start(new ProcessStartInfo(LogService.LogDirectory) { UseShellExecute = true })?.Dispose();
        }
        catch (Exception ex)
        {
            LogService.Instance.Error("Could not open the log folder", ex);
            StatusText = "Could not open the log folder - see Activity Log";
        }
    }

    private void RunScan(bool promote) =>
        _ = Task.Run(() => _guard.ScanOnce(promote));

    private void RunGuardAction(Func<ScanResult> action, string label)
    {
        StatusText = $"{label}...";
        _ = Task.Run(() =>
        {
            var result = action();
            _dispatcher.BeginInvoke(() =>
            {
                StatusText = result.Failed > 0
                    ? $"{label}: {result.PromotedNow} promoted, {result.Failed} FAILED - see log"
                    : $"{label}: {result.PromotedNow} promoted, {result.Visible}/{result.Total} visible";
            });
        });
    }

    private void UpdateWatcherState() =>
        WatcherStateText = _guard.IsRunning
            ? (IsPaused ? "guard PAUSED" : Settings.UseEventDrivenMonitor ? "guard RUNNING (event-driven)" : "guard RUNNING (polling)")
            : "guard STOPPED";

    private void PersistSettings() => SettingsService.Instance.Save(Settings);

    private bool FilterIcon(object item) =>
        item is TrayIconEntry entry &&
        (string.IsNullOrWhiteSpace(SearchText) ||
         entry.DisplayName.Contains(SearchText, StringComparison.OrdinalIgnoreCase) ||
         entry.Id.Contains(SearchText, StringComparison.OrdinalIgnoreCase) ||
         (entry.ExecutablePath?.Contains(SearchText, StringComparison.OrdinalIgnoreCase) ?? false));

    private void AddLogEntry(LogEntry entry)
    {
        Logs.Add(entry);
        while (Logs.Count > 500)
        {
            Logs.RemoveAt(0);
        }
    }
}
