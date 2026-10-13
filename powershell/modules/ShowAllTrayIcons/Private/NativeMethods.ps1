# ---------------------------------------------------------------------------
# NativeMethods.ps1 -- P/Invoke surface used by Start-TrayIconWatcher.
#
# Compiled at module import on EVERY platform (the types exist in PowerShell
# 7.6 on Linux/macOS too; only the advapi32 call itself is Windows-only and
# is guarded at runtime by Assert-WindowsPlatform). Compiling unconditionally
# is deliberate: it makes C# compilation errors visible to cross-platform CI
# and tests instead of hiding them behind an `$IsWindows` guard (defect
# P0-1 / CS0105 post-mortem, v7.0.1).
#
# NOTE: do NOT pass -UsingNamespace 'System.Runtime.InteropServices' to
# Add-Type -- Add-Type emits that using directive itself and a duplicate
# fails compilation with CS0105.
# ---------------------------------------------------------------------------

if (-not ('ShowAllTrayIcons.Native.RegistryNotify' -as [type])) {
    $registryNotifyMembers = @'
[DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern int RegNotifyChangeKeyValue(
    Microsoft.Win32.SafeHandles.SafeRegistryHandle hKey,
    bool bWatchSubtree,
    int dwNotifyFilter,
    Microsoft.Win32.SafeHandles.SafeWaitHandle hEvent,
    bool fAsynchronous);

/// <summary>A subkey was added or deleted.</summary>
public const int REG_NOTIFY_CHANGE_NAME     = 0x00000001;
/// <summary>A value was changed.</summary>
public const int REG_NOTIFY_CHANGE_LAST_SET = 0x00000004;
/// <summary>The watched key was deleted; the caller must reopen it.</summary>
public const int ERROR_KEY_DELETED          = 1018;
'@

    Add-Type -Namespace 'ShowAllTrayIcons.Native' -Name 'RegistryNotify' `
        -MemberDefinition $registryNotifyMembers
}
