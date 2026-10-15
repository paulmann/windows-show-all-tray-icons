// TrayIconGuard v8 — autostart via HKCU Run (agent A1). No admin rights needed.
#pragma once
#include <string>

namespace tig::autostart {

constexpr wchar_t kRunValue[] = L"TrayIconGuard";

bool IsInstalled();
bool Install();     // current module path --minimized
bool InstallAt(const std::wstring& exePath);
bool Uninstall();
std::wstring CurrentCommand();

}  // namespace tig::autostart
