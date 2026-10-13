using Microsoft.Win32;

namespace TrayIconGuard.Services;

/// <summary>
/// "Start with Windows" via the per-user Run key. Same value name the
/// PowerShell edition uses (Install-TrayIconAutostart), so both editions
/// stay consistent: HKCU\...\Run -> TrayIconGuard.
/// </summary>
public static class AutostartService
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    public const string ValueName = "TrayIconGuard";

    public static bool IsEnabled()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: false);
            return key?.GetValue(ValueName) is string command
                && command.Contains("TrayIconGuard", StringComparison.OrdinalIgnoreCase);
        }
        catch (Exception ex)
        {
            LogService.Instance.Warn($"Autostart probe failed: {ex.Message}");
            return false;
        }
    }

    public static bool Enable(bool startMinimized = true)
    {
        try
        {
            var exe = Environment.ProcessPath;
            if (string.IsNullOrEmpty(exe))
            {
                LogService.Instance.Warn("Autostart: cannot resolve the current executable path.");
                return false;
            }

            var args = startMinimized ? " --minimized" : string.Empty;
            var command = $"\"{exe}\"{args}";

            using var key = Registry.CurrentUser.CreateSubKey(RunKeyPath);
            if (key is null)
            {
                return false;
            }

            key.SetValue(ValueName, command, RegistryValueKind.String);
            LogService.Instance.Info($"Autostart enabled: {command}");
            return true;
        }
        catch (Exception ex)
        {
            LogService.Instance.Error("Failed to enable autostart", ex);
            return false;
        }
    }

    public static void Disable()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: true);
            if (key?.GetValue(ValueName) is not null)
            {
                key.DeleteValue(ValueName, throwOnMissingValue: false);
                LogService.Instance.Info("Autostart disabled.");
            }
        }
        catch (Exception ex)
        {
            LogService.Instance.Warn($"Failed to disable autostart: {ex.Message}");
        }
    }
}
