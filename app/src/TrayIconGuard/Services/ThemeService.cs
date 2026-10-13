using System.Windows;
using Microsoft.Win32;

namespace TrayIconGuard.Services;

/// <summary>
/// Light/Dark theming. "System" follows
/// HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\AppsUseLightTheme.
/// Theme dictionaries are swapped at runtime; all controls use DynamicResource.
/// </summary>
public static class ThemeService
{
    public static bool IsSystemLight()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            var value = key?.GetValue("AppsUseLightTheme");
            return value is null || Convert.ToInt32(value) != 0;
        }
        catch (Exception)
        {
            return true;
        }
    }

    public static void Apply(string theme)
    {
        var app = Application.Current;
        if (app is null)
        {
            return;
        }

        var light = theme switch
        {
            "Light" => true,
            "Dark" => false,
            _ => IsSystemLight(),
        };

        app.Dispatcher.Invoke(() =>
        {
            var merged = app.Resources.MergedDictionaries;
            merged.Clear();
            merged.Add(new ResourceDictionary
            {
                Source = new Uri($"Themes/{(light ? "Light" : "Dark")}.xaml", UriKind.Relative),
            });
            merged.Add(new ResourceDictionary
            {
                Source = new Uri("Themes/Controls.xaml", UriKind.Relative),
            });
        });
    }
}
