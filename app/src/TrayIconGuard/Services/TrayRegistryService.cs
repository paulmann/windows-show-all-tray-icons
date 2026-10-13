using System.IO;
using System.Text.RegularExpressions;
using Microsoft.Win32;
using TrayIconGuard.Models;

namespace TrayIconGuard.Services;

/// <summary>
/// All raw registry access for tray icon visibility lives here.
/// Store: HKCU\Control Panel\NotifyIconSettings\{id} -> IsPromoted (DWORD).
/// This is exactly what the Windows Settings "select which icons appear on
/// the taskbar" toggle reads and writes.
/// </summary>
public sealed class TrayRegistryService
{
    public const string NotifyIconSettingsPath = @"Control Panel\NotifyIconSettings";

    private const string ExplorerKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Explorer";
    private const string PoliciesKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Policies\Explorer";
    private const string EnableAutoTrayName = "EnableAutoTray";
    private static readonly string[] SystemIconPolicies = ["HideSCAVolume", "HideSCANetwork", "HideSCAPower"];

    /// <summary>Enumerates every registered tray icon.</summary>
    public IReadOnlyList<TrayIconEntry> Scan(IReadOnlyCollection<string>? exclusions = null)
    {
        var result = new List<TrayIconEntry>();

        using var root = Registry.CurrentUser.OpenSubKey(NotifyIconSettingsPath, writable: false)
                         ?? Registry.CurrentUser.CreateSubKey(NotifyIconSettingsPath);
        if (root is null)
        {
            return result;
        }

        foreach (var id in root.GetSubKeyNames())
        {
            try
            {
                using var sub = root.OpenSubKey(id, writable: false);
                if (sub is null)
                {
                    continue;
                }

                var exe = sub.GetValue("ExecutablePath") as string;
                var entry = new TrayIconEntry
                {
                    Id = id,
                    DisplayName = string.IsNullOrEmpty(exe) ? id : Path.GetFileNameWithoutExtension(exe),
                    ExecutablePath = exe,
                    IconResource = sub.GetValue("IconResource") as string,
                    IsPromoted = ToBool(sub.GetValue("IsPromoted")),
                    HasSnapshot = sub.GetValue("IconSnapshot") is byte[] { Length: > 0 },
                    LastNotification = ToFileTime(sub.GetValue("LastNotificationAddedTime")),
                };
                entry.IsExcluded = MatchesExclusion(entry, exclusions);
                result.Add(entry);
            }
            catch (Exception ex)
            {
                LogService.Instance.Warn($"Skipping unreadable icon subkey '{id}': {ex.Message}");
            }
        }

        return result;
    }

    /// <summary>Writes IsPromoted for a single icon. Returns success.</summary>
    public bool SetPromoted(string id, bool promoted)
    {
        try
        {
            using var root = Registry.CurrentUser.CreateSubKey(NotifyIconSettingsPath);
            using var sub = root?.CreateSubKey(id);
            if (sub is null)
            {
                return false;
            }

            sub.SetValue("IsPromoted", promoted ? 1 : 0, RegistryValueKind.DWord);
            return true;
        }
        catch (Exception ex)
        {
            LogService.Instance.Error($"SetPromoted failed for '{id}'", ex);
            return false;
        }
    }

    /// <summary>Promotes every hidden, non-excluded icon. Mutates entries in place.</summary>
    public (int Promoted, int Failed) PromoteHidden(
        IEnumerable<TrayIconEntry> entries,
        Action<TrayIconEntry>? onPromoted = null)
    {
        int promoted = 0;
        int failed = 0;

        try
        {
            using var root = Registry.CurrentUser.CreateSubKey(NotifyIconSettingsPath);
            if (root is null)
            {
                return (0, 0);
            }

            foreach (var entry in entries.Where(e => !e.IsPromoted && !e.IsExcluded).ToList())
            {
                try
                {
                    using var sub = root.CreateSubKey(entry.Id);
                    sub.SetValue("IsPromoted", 1, RegistryValueKind.DWord);
                    entry.IsPromoted = true;
                    promoted++;
                    onPromoted?.Invoke(entry);
                }
                catch (Exception ex)
                {
                    failed++;
                    LogService.Instance.Error($"Failed to promote '{entry.DisplayName}' ({entry.Id})", ex);
                }
            }
        }
        catch (Exception ex)
        {
            LogService.Instance.Error("PromoteHidden could not open the settings root", ex);
        }

        return (promoted, failed);
    }

    /// <summary>Sets IsPromoted=0 for every icon (restore Windows-managed hiding).</summary>
    public (int Demoted, int Failed) DemoteAll()
    {
        int demoted = 0;
        int failed = 0;

        try
        {
            using var root = Registry.CurrentUser.OpenSubKey(NotifyIconSettingsPath, writable: true);
            if (root is null)
            {
                return (0, 0);
            }

            foreach (var id in root.GetSubKeyNames())
            {
                try
                {
                    using var sub = root.OpenSubKey(id, writable: true);
                    if (sub is null)
                    {
                        continue;
                    }

                    if (ToBool(sub.GetValue("IsPromoted")))
                    {
                        sub.SetValue("IsPromoted", 0, RegistryValueKind.DWord);
                        demoted++;
                    }
                }
                catch (Exception ex)
                {
                    failed++;
                    LogService.Instance.Warn($"Demote failed for '{id}': {ex.Message}");
                }
            }
        }
        catch (Exception ex)
        {
            LogService.Instance.Error("DemoteAll could not open the settings root", ex);
        }

        return (demoted, failed);
    }

    /// <summary>
    /// Legacy belt-and-suspenders switch. showAll=true writes EnableAutoTray=0;
    /// showAll=false removes the value (Windows default).
    /// </summary>
    public void SetLegacyAutoTray(bool showAll)
    {
        try
        {
            using var key = Registry.CurrentUser.CreateSubKey(ExplorerKeyPath);
            if (key is null)
            {
                return;
            }

            if (showAll)
            {
                key.SetValue(EnableAutoTrayName, 0, RegistryValueKind.DWord);
            }
            else if (key.GetValue(EnableAutoTrayName) is not null)
            {
                key.DeleteValue(EnableAutoTrayName, throwOnMissingValue: false);
            }
        }
        catch (Exception ex)
        {
            LogService.Instance.Warn($"Legacy EnableAutoTray update failed: {ex.Message}");
        }
    }

    /// <summary>Removes stale HideSCA* policies from their correct location.</summary>
    public IReadOnlyList<string> ClearHidePolicies()
    {
        var removed = new List<string>();
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(PoliciesKeyPath, writable: true);
            if (key is null)
            {
                return removed;
            }

            foreach (var name in SystemIconPolicies)
            {
                var value = key.GetValue(name);
                if (value is not null && Convert.ToInt32(value) != 0)
                {
                    key.DeleteValue(name, throwOnMissingValue: false);
                    removed.Add(name);
                }
            }
        }
        catch (Exception ex)
        {
            LogService.Instance.Warn($"HideSCA* policy cleanup failed: {ex.Message}");
        }

        if (removed.Count > 0)
        {
            LogService.Instance.Info($"Removed stale hide policies: {string.Join(", ", removed)}");
        }

        return removed;
    }

    /// <summary>File name / full path match with optional * wildcards.</summary>
    public static bool MatchesExclusion(TrayIconEntry entry, IReadOnlyCollection<string>? patterns)
    {
        if (patterns is null || patterns.Count == 0)
        {
            return false;
        }

        var fileName = string.IsNullOrEmpty(entry.ExecutablePath)
            ? null
            : Path.GetFileName(entry.ExecutablePath);

        foreach (var raw in patterns)
        {
            var pattern = raw.Trim();
            if (pattern.Length == 0)
            {
                continue;
            }

            if (fileName is not null)
            {
                if (WildMatch(pattern, fileName) ||
                    (entry.ExecutablePath is not null && WildMatch(pattern, entry.ExecutablePath)))
                {
                    return true;
                }
            }

            if (WildMatch(pattern, entry.DisplayName))
            {
                return true;
            }
        }

        return false;
    }

    private static bool WildMatch(string pattern, string value)
    {
        if (!pattern.Contains('*'))
        {
            return string.Equals(pattern, value, StringComparison.OrdinalIgnoreCase);
        }

        var regexText = "^" + Regex.Escape(pattern).Replace(@"\*", ".*") + "$";
        return Regex.IsMatch(
            value,
            regexText,
            RegexOptions.IgnoreCase | RegexOptions.CultureInvariant,
            TimeSpan.FromMilliseconds(200));
    }

    private static bool ToBool(object? value)
    {
        try
        {
            return value is not null && Convert.ToInt32(value) != 0;
        }
        catch (Exception)
        {
            return false;
        }
    }

    private static DateTime? ToFileTime(object? value)
    {
        try
        {
            if (value is null)
            {
                return null;
            }

            var ft = Convert.ToInt64(value);
            return ft is > 0 and < 2650467744000000000L ? DateTime.FromFileTimeUtc(ft) : null;
        }
        catch (Exception)
        {
            return null;
        }
    }
}
