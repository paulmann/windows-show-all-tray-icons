using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace TrayIconGuard.Interop;

/// <summary>
/// Minimal Win32 surface. Kept dependency-free on purpose (no NuGet).
/// </summary>
internal static class NativeMethods
{
    // ---- Registry change notification ------------------------------------
    internal const int REG_NOTIFY_CHANGE_NAME = 0x00000001;     // subkey added/deleted
    internal const int REG_NOTIFY_CHANGE_LAST_SET = 0x00000004; // value changed
    internal const int ERROR_KEY_DELETED = 1018;                // watched key went away

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    internal static extern int RegNotifyChangeKeyValue(
        SafeRegistryHandle hKey,
        bool bWatchSubtree,
        int dwNotifyFilter,
        SafeWaitHandle hEvent,
        bool fAsynchronous);

    // ---- Window activation (single-instance hand-off) ---------------------
    internal const int SW_HIDE = 0;
    internal const int SW_RESTORE = 9;

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool SetForegroundWindow(IntPtr hWnd);
}
