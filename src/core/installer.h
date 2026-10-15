// TrayIconGuard v8 — embedded, dependency-free installer engine.
// Per-user install: copy exe, .lnk shortcuts (IShellLink), HKCU uninstall entry,
// autostart Run key, self-uninstall with delayed self-delete. No admin, no MSI.
#pragma once
#include <string>

namespace tig::installer {

struct Options {
    std::wstring dir;         // install folder (default %LOCALAPPDATA%\Programs\TrayIconGuard)
    bool autostart = true;
    bool desktopIcon = true;
    bool startMenuIcon = true;
};

std::wstring DefaultDir();
bool IsInstalledHere();            // module path == registered install dir
// Copies exe (when needed), creates shortcuts/uninstall/autostart.
bool Install(const Options& opt, std::wstring& err);
// True when the running exe is not the installed one (caller should relaunch).
bool NeedsRelaunch();
// Full removal: shortcuts, autostart, uninstall key, delayed self-delete of folder.
bool Uninstall(std::wstring& err);
std::wstring DesktopLnkPath();
std::wstring StartMenuLnkPath();
std::wstring StartMenuUninstallLnkPath();

}  // namespace tig::installer
