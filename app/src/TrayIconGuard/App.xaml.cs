using System.Diagnostics;
using System.Reflection;
using System.Windows;
using System.Windows.Threading;
using TrayIconGuard.Interop;
using TrayIconGuard.Services;
using TrayIconGuard.ViewModels;
using TrayIconGuard.Views;

namespace TrayIconGuard;

/// <summary>
/// Application entry: single-instance mutex, CLI one-shot modes for
/// unattended deployment, theme bootstrap, global exception handling,
/// and the tray-resident main window lifecycle.
/// </summary>
public partial class App : Application
{
    private const string SingleInstanceMutexName = "TrayIconGuard_v7_SingleInstance";

    private const string HelpText =
        """
        TrayIconGuard 7.0.3 - keeps every Windows 10/11 tray icon visible.

        Usage: TrayIconGuard.exe [options]

          (no options)        Start with GUI; lives in the notification area.
          --minimized         Start hidden in the notification area.
          --promote-all       Headless: promote every hidden icon, then exit.
                              Exit codes: 0 ok, 3 partial failure.
          --restore-defaults  Headless: return icons to Windows defaults, exit.
          --help              Show this help.

        Settings: %APPDATA%\TrayIconGuard\settings.json
        Logs:     %LOCALAPPDATA%\TrayIconGuard\logs
        """;

    private Mutex? _singleInstanceMutex;
    private MainViewModel? _viewModel;
    private MainWindow? _mainWindow;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        DispatcherUnhandledException += OnDispatcherUnhandledException;
        AppDomain.CurrentDomain.UnhandledException += OnDomainUnhandledException;
        TaskScheduler.UnobservedTaskException += OnUnobservedTaskException;

        var args = e.Args ?? [];

        bool HasFlag(string name) =>
            args.Any(a => string.Equals(a, name, StringComparison.OrdinalIgnoreCase));

        if (HasFlag("--help") || HasFlag("-h") || HasFlag("/?"))
        {
            MessageBox.Show(HelpText, "TrayIconGuard", MessageBoxButton.OK, MessageBoxImage.Information);
            Environment.Exit(0);
            return;
        }

        var version = Assembly.GetEntryAssembly()?.GetName().Version?.ToString(3) ?? "7.0.3";
        LogService.Instance.Info($"TrayIconGuard v{version} starting. Args: [{string.Join(' ', args)}]");

        _singleInstanceMutex = new Mutex(initiallyOwned: true, SingleInstanceMutexName, out var createdNew);
        if (!createdNew)
        {
            LogService.Instance.Info("Second instance detected; activating the running instance and exiting.");
            ActivateExistingInstance();
            Environment.Exit(0);
            return;
        }

        var settings = SettingsService.Instance.Load();
        ThemeService.Apply(settings.Theme);

        // ---- Headless one-shot modes (deployment friendly) --------------------
        if (HasFlag("--promote-all"))
        {
            using var guard = new IconGuardService();
            guard.ApplySettings(settings);
            var result = guard.ShowAllNow();
            LogService.Instance.Info($"--promote-all: {result.PromotedNow} promoted, {result.Visible}/{result.Total} visible, {result.Failed} failed.");
            Environment.Exit(result.Failed > 0 ? 3 : 0);
            return;
        }

        if (HasFlag("--restore-defaults"))
        {
            using var guard = new IconGuardService();
            guard.ApplySettings(settings);
            var result = guard.RestoreDefaults();
            LogService.Instance.Info($"--restore-defaults: {result.Total - result.Visible} icon(s) returned to defaults, {result.Failed} failed.");
            Environment.Exit(result.Failed > 0 ? 3 : 0);
            return;
        }

        // ---- Full GUI ----------------------------------------------------------
        var guardService = new IconGuardService();
        guardService.ApplySettings(settings);

        _viewModel = new MainViewModel(settings, guardService, Dispatcher);
        _mainWindow = new MainWindow(_viewModel);
        MainWindow = _mainWindow;

        _viewModel.Start();

        if (HasFlag("--minimized") || settings.StartMinimized)
        {
            LogService.Instance.Info("Running minimized in the notification area.");
        }
        else
        {
            _mainWindow.Show();
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        try
        {
            _viewModel?.Shutdown();
            _mainWindow?.DisposeTrayIcon();
        }
        catch (Exception ex)
        {
            LogService.Instance.Error("Error during shutdown", ex);
        }
        finally
        {
            _singleInstanceMutex?.Dispose();
        }

        LogService.Instance.Info($"TrayIconGuard exited (code {e.ApplicationExitCode}).");
        base.OnExit(e);
    }

    private static void ActivateExistingInstance()
    {
        try
        {
            var currentPid = Environment.ProcessId;
            foreach (var process in Process.GetProcessesByName("TrayIconGuard"))
            {
                using (process)
                {
                    if (process.Id == currentPid)
                    {
                        continue;
                    }

                    var hwnd = process.MainWindowHandle;
                    if (hwnd != IntPtr.Zero)
                    {
                        NativeMethods.ShowWindow(hwnd, NativeMethods.SW_RESTORE);
                        NativeMethods.SetForegroundWindow(hwnd);
                        return;
                    }
                }
            }
        }
        catch (Exception ex)
        {
            LogService.Instance.Warn($"Could not activate the running instance: {ex.Message}");
        }
    }

    private void OnDispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        LogService.Instance.Error("Unhandled UI exception", e.Exception);
        MessageBox.Show(
            $"TrayIconGuard hit an unexpected error and recovered:\n\n{e.Exception.Message}\n\nDetails: Activity Log tab / {LogService.LogDirectory}",
            "TrayIconGuard",
            MessageBoxButton.OK,
            MessageBoxImage.Error);
        e.Handled = true; // keep guarding
    }

    private static void OnDomainUnhandledException(object sender, UnhandledExceptionEventArgs e)
    {
        if (e.ExceptionObject is Exception ex)
        {
            LogService.Instance.Error("Unhandled AppDomain exception", ex);
        }
    }

    private static void OnUnobservedTaskException(object? sender, UnobservedTaskExceptionEventArgs e)
    {
        LogService.Instance.Error("Unobserved task exception", e.Exception);
        e.SetObserved();
    }
}
