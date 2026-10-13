using System.IO;
using System.Text.Json;
using TrayIconGuard.Models;

namespace TrayIconGuard.Services;

/// <summary>
/// JSON settings persistence with atomic writes and corrupt-file recovery.
/// Location: %APPDATA%\TrayIconGuard\settings.json
/// </summary>
public sealed class SettingsService
{
    public static SettingsService Instance { get; } = new();

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true,
    };

    public static string SettingsDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "TrayIconGuard");

    public static string SettingsFile => Path.Combine(SettingsDirectory, "settings.json");

    public AppSettings Load()
    {
        try
        {
            if (File.Exists(SettingsFile))
            {
                var json = File.ReadAllText(SettingsFile);
                var settings = JsonSerializer.Deserialize<AppSettings>(json, JsonOptions);
                if (settings is not null)
                {
                    settings.Sanitize();
                    return settings;
                }

                LogService.Instance.Warn("settings.json deserialized to null; falling back to defaults.");
            }
        }
        catch (Exception ex)
        {
            LogService.Instance.Error("Failed to load settings; falling back to defaults", ex);
        }

        return new AppSettings();
    }

    public void Save(AppSettings settings)
    {
        try
        {
            settings.Sanitize();
            Directory.CreateDirectory(SettingsDirectory);

            var tmp = SettingsFile + ".tmp";
            File.WriteAllText(tmp, JsonSerializer.Serialize(settings, JsonOptions));

            if (File.Exists(SettingsFile))
            {
                File.Replace(tmp, SettingsFile, destinationBackupFileName: null);
            }
            else
            {
                File.Move(tmp, SettingsFile);
            }

            LogService.Instance.Debug("Settings saved.");
        }
        catch (Exception ex)
        {
            LogService.Instance.Error("Failed to save settings", ex);
        }
    }
}
