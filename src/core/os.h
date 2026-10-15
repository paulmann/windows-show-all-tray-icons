// TrayIconGuard v8 — OS / environment detection (agent A1).
#pragma once
#include <string>
#include <windows.h>

namespace tig::os {

struct Info {
    DWORD build = 0;
    DWORD major = 0;
    DWORD minor = 0;
    bool isWindows11 = false;   // build >= 22000
    bool supportsNotifyIconSettings = false;  // build >= 15063 (Win10 1703+)
    std::wstring caption;       // e.g. "Windows 11 Pro 24H2 (build 26100)"
};

const Info& Get();

// HKCU\...\Themes\Personalize\AppsUseLightTheme (default: light).
bool SystemUsesLightTheme();
// Windows accent color as 0x00BBGGRR (COLORREF). Fallback #0F6CBD.
COLORREF SystemAccentColor();
// Primary UI language: "ru", "en", ...
std::wstring UiLanguage();

int DpiFor(HWND hwnd);                 // 96-based
double Scale(HWND hwnd);               // dpi / 96.0
int Px(HWND hwnd, int logical96);      // scale a 96-dpi design px

std::wstring EditionName();            // from registry ProductName etc.
std::wstring DisplayVersion();         // e.g. "24H2"

}  // namespace tig::os
