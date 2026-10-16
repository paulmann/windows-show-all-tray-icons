// TrayIconGuard v8 — embedded, dependency-free installer engine.
// Per-user install: copy exe, .lnk shortcuts (IShellLink), HKCU uninstall entry,
// autostart Run key, self-uninstall with delayed self-delete. No MSI, no runtimes.
// Machine (all-users) install (8.4): same flow elevated once via UAC — Program Files,
// common Desktop/Start-Menu shortcuts, HKLM Run + HKLM uninstall entry.
#pragma once
#include <string>

namespace tig::installer {

enum class Scope { User, Machine };

struct Options {
    std::wstring dir;  // install folder; empty => DefaultDir()/DefaultMachineDir()
    Scope scope = Scope::User;
    bool autostart = true;
    bool desktopIcon = true;
    bool startMenuIcon = true;
};

std::wstring DefaultDir();         // %LOCALAPPDATA%\Programs\TrayIconGuard
std::wstring DefaultMachineDir();  // %ProgramFiles%\TrayIconGuard
bool IsElevated();                 // process token has elevated privileges
bool IsInstalledHere();            // module path == registered install dir
// True when the running exe is not the installed one (caller should relaunch).
bool NeedsRelaunch();

// Performs the install for opt.scope. Machine scope requires elevation: if the current
// process is not elevated, re-launches itself elevated via UAC (--install-machine) and
// waits; if the user declines UAC, falls back to a per-user install (logged).
bool Install(const Options& opt, std::wstring& err);
// Full removal: shortcuts, autostart, uninstall key, delayed self-delete of folder.
// Auto-elevates once when removing a machine install from a non-elevated process.
bool Uninstall(std::wstring& err);

std::wstring DesktopLnkPath();
std::wstring StartMenuLnkPath();
std::wstring StartMenuUninstallLnkPath();
std::wstring CommonDesktopLnkPath();
std::wstring CommonStartMenuLnkPath();
std::wstring CommonStartMenuUninstallLnkPath();

}  // namespace tig::installer
