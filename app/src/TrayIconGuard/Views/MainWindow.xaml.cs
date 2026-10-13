using System.ComponentModel;
using System.Windows;
using Drawing = System.Drawing;
using TrayIconGuard.Services;
using TrayIconGuard.ViewModels;
using WinForms = System.Windows.Forms;

namespace TrayIconGuard.Views;

/// <summary>
/// Main window: hosts the icon list / settings / log tabs and owns the
/// notification-area presence (NotifyIcon). Closing or minimizing hides the
/// window into the tray while the guard keeps running; "Exit" (tray menu)
/// shuts the application down.
/// </summary>
public partial class MainWindow : Window
{
    private readonly MainViewModel _viewModel;
    private WinForms.NotifyIcon? _notifyIcon;
    private Drawing.Icon? _trayIconHandle; // kept alive for NotifyIcon.Icon
    private bool _exiting;
    private bool _trayHintShown;

    public MainWindow(MainViewModel viewModel)
    {
        InitializeComponent();
        _viewModel = viewModel;
        DataContext = viewModel;

        _viewModel.RequestBalloon += ShowBalloon;
        _viewModel.RequestExit += ExitApplication;

        InitializeTrayIcon();
        StateChanged += OnStateChanged;
    }

    // ---- Notification area presence -----------------------------------------
    private void InitializeTrayIcon()
    {
        var menu = new WinForms.ContextMenuStrip();
        menu.Items.Add("Open TrayIconGuard", null, (_, _) => ShowAndActivate());
        menu.Items.Add(new WinForms.ToolStripSeparator());
        menu.Items.Add("Show all icons now", null, (_, _) => _viewModel.ShowAllNowCommand.Execute(null));
        menu.Items.Add("Pause / resume guard", null, (_, _) => _viewModel.ToggleGuardCommand.Execute(null));
        menu.Items.Add("Restart Explorer", null, (_, _) => ConfirmAndRestartExplorer());
        menu.Items.Add(new WinForms.ToolStripSeparator());
        menu.Items.Add("Exit", null, (_, _) => ExitApplication());

        _trayIconHandle = LoadIconFromResources();
        _notifyIcon = new WinForms.NotifyIcon
        {
            Icon = _trayIconHandle,
            Visible = true,
            Text = "TrayIconGuard - keeping all tray icons visible",
            ContextMenuStrip = menu,
        };
        _notifyIcon.DoubleClick += (_, _) => ShowAndActivate();
    }

    private static Drawing.Icon LoadIconFromResources()
    {
        try
        {
            var uri = new Uri("pack://application:,,,/Assets/app.ico", UriKind.Absolute);
            var stream = Application.GetResourceStream(uri)?.Stream;
            if (stream is not null)
            {
                return new Drawing.Icon(stream);
            }
        }
        catch (Exception ex)
        {
            LogService.Instance.Warn($"Could not load the tray icon resource: {ex.Message}");
        }

        return Drawing.SystemIcons.Application;
    }

    private void ShowBalloon(string title, string text) => Dispatcher.Invoke(() =>
    {
        if (_notifyIcon is { Visible: true })
        {
            _notifyIcon.ShowBalloonTip(3000, title, text, WinForms.ToolTipIcon.Info);
        }
    });

    public void ShowAndActivate() => Dispatcher.Invoke(() =>
    {
        Show();
        WindowState = WindowState.Normal;
        Activate();
    });

    // ---- Minimize / close to tray --------------------------------------------
    private void OnStateChanged(object? sender, EventArgs e)
    {
        if (WindowState == WindowState.Minimized && _viewModel.Settings.MinimizeToTray)
        {
            Hide();
        }
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        if (!_exiting && _viewModel.Settings.MinimizeToTray)
        {
            e.Cancel = true;
            Hide();
            if (!_trayHintShown)
            {
                _trayHintShown = true;
                ShowBalloon(
                    "TrayIconGuard",
                    "Still guarding your tray icons. Right-click the tray icon to open or exit.");
            }

            return;
        }

        base.OnClosing(e);
    }

    // ---- Confirmation dialogs for disruptive actions --------------------------
    private void OnRestoreDefaultsClick(object sender, RoutedEventArgs e)
    {
        var answer = MessageBox.Show(
            "Return ALL icons to Windows default behavior?\nIcons may hide in the overflow flyout again.",
            "Restore defaults",
            MessageBoxButton.YesNo,
            MessageBoxImage.Question);
        if (answer == MessageBoxResult.Yes)
        {
            _viewModel.RestoreDefaultsCommand.Execute(null);
        }
    }

    private void OnRestartExplorerClick(object sender, RoutedEventArgs e) => ConfirmAndRestartExplorer();

    private void ConfirmAndRestartExplorer()
    {
        var answer = MessageBox.Show(
            "Restart Windows Explorer now?\nThe taskbar will disappear for a few seconds.",
            "Restart Explorer",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);
        if (answer == MessageBoxResult.Yes)
        {
            _viewModel.RestartExplorerCommand.Execute(null);
        }
    }

    // ---- Shutdown --------------------------------------------------------------
    public void ExitApplication() => Dispatcher.Invoke(() =>
    {
        _exiting = true;
        DisposeTrayIcon();
        Close();
        Application.Current.Shutdown();
    });

    public void DisposeTrayIcon()
    {
        if (_notifyIcon is not null)
        {
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
            _notifyIcon = null;
        }

        _trayIconHandle?.Dispose();
        _trayIconHandle = null;
    }

    protected override void OnClosed(EventArgs e)
    {
        DisposeTrayIcon();
        base.OnClosed(e);
    }
}
