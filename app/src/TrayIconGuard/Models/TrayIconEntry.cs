using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace TrayIconGuard.Models;

/// <summary>
/// One notification-area icon registered under HKCU\Control Panel\NotifyIconSettings.
/// Implements INotifyPropertyChanged so the icon list updates live while the guard runs.
/// </summary>
public sealed class TrayIconEntry : INotifyPropertyChanged
{
    /// <summary>NotifyIconSettings subkey name (usually a GUID).</summary>
    public required string Id { get; init; }

    /// <summary>Friendly name derived from the owning executable (fallback: Id).</summary>
    public required string DisplayName { get; init; }

    /// <summary>Executable that registered the icon (may be null for system entries).</summary>
    public string? ExecutablePath { get; init; }

    /// <summary>Icon resource string, e.g. "C:\App\app.exe,-101".</summary>
    public string? IconResource { get; init; }

    /// <summary>When Explorer last saw a notification from this icon (UTC).</summary>
    public DateTime? LastNotification { get; init; }

    /// <summary>True when Explorer stored a rendered bitmap snapshot.</summary>
    public bool HasSnapshot { get; init; }

    /// <summary>True when the icon matches the user's exclusion list.</summary>
    public bool IsExcluded { get; set; }

    private bool _isPromoted;

    /// <summary>True = always visible on the taskbar; false = hidden in the overflow flyout.</summary>
    public bool IsPromoted
    {
        get => _isPromoted;
        set
        {
            if (_isPromoted == value)
            {
                return;
            }

            _isPromoted = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(StatusText));
        }
    }

    public string StatusText =>
        IsPromoted ? "Visible" : IsExcluded ? "Hidden (excluded)" : "Hidden";

    public string LastSeenText =>
        LastNotification is { } t ? t.ToLocalTime().ToString("yyyy-MM-dd HH:mm") : "never";

    public event PropertyChangedEventHandler? PropertyChanged;

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}
