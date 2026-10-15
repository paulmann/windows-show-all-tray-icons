#include "core/os.h"

#include <dwmapi.h>

#include <cmath>

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wcast-function-type"

#include "core/registry.h"
#include "util/str.h"

namespace tig::os {

namespace {
Info Build() {
    Info info;
    using RtlGetVersionFn = LONG(WINAPI*)(LPOSVERSIONINFOW);
    const auto fn = reinterpret_cast<RtlGetVersionFn>(
        GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion"));
    OSVERSIONINFOW vi{};
    vi.dwOSVersionInfoSize = sizeof(vi);
    if (fn) {
        fn(&vi);
        info.major = vi.dwMajorVersion;
        info.minor = vi.dwMinorVersion;
        info.build = vi.dwBuildNumber;
    } else {
        // RtlGetVersion is always present; defensive fallback.
        info.major = 10;
        info.build = 0;
    }
    info.isWindows11 = info.build >= 22000;
    info.supportsNotifyIconSettings = info.build >= 15063;
    info.caption = str::Format(L"%s %s (build %lu)",
                               info.isWindows11 ? L"Windows 11" : L"Windows 10",
                               EditionName().c_str(), info.build);
    return info;
}
}  // namespace

const Info& Get() {
    static const Info info = Build();
    return info;
}

bool SystemUsesLightTheme() {
    DWORD v = 1;
    if (!reg::GetDword(HKEY_CURRENT_USER,
                       L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
                       L"AppsUseLightTheme", v))
        v = 1;
    return v != 0;
}

COLORREF SystemAccentColor() {
    DWORD argb = 0;
    if (reg::GetDword(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\DWM",
                      L"ColorizationColor", argb) && argb) {
        return RGB((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);
    }
    BOOL opaque = FALSE;
    DWORD color = 0;
    if (SUCCEEDED(DwmGetColorizationColor(&color, &opaque))) {
        return RGB((color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF);
    }
    return RGB(0x0F, 0x6C, 0xBD);  // Windows 11 default accent
}

std::wstring UiLanguage() {
    const LANGID lang = GetUserDefaultUILanguage();
    switch (PRIMARYLANGID(lang)) {
        case LANG_CHINESE: return L"zh";
        case LANG_HINDI: return L"hi";
        case LANG_SPANISH: return L"es";
        case LANG_ARABIC: return L"ar";
        case LANG_FRENCH: return L"fr";
        case LANG_BENGALI: return L"bn";
        case LANG_RUSSIAN: return L"ru";
        case LANG_PORTUGUESE: return L"pt";
        case LANG_URDU: return L"ur";
        case LANG_INDONESIAN: return L"id";
        case LANG_GERMAN: return L"de";
        case LANG_JAPANESE: return L"ja";
        case LANG_TURKISH: return L"tr";
        case LANG_KOREAN: return L"ko";
        case LANG_VIETNAMESE: return L"vi";
        case LANG_ITALIAN: return L"it";
        case LANG_THAI: return L"th";
        case LANG_POLISH: return L"pl";
        case LANG_DUTCH: return L"nl";
        case LANG_UKRAINIAN: return L"uk";
        case LANG_PERSIAN: return L"fa";
        case LANG_GREEK: return L"el";
        case LANG_CZECH: return L"cs";
        case LANG_SWEDISH: return L"sv";
        case LANG_HUNGARIAN: return L"hu";
        case LANG_ROMANIAN: return L"ro";
        case LANG_HEBREW: return L"he";
        case LANG_FINNISH: return L"fi";
        case LANG_DANISH: return L"da";
        default: return L"en";
    }
}

int DpiFor(HWND hwnd) {
    if (!hwnd) return 96;
    using Fn = UINT(WINAPI*)(HWND);
    static Fn fn = reinterpret_cast<Fn>(
        GetProcAddress(GetModuleHandleW(L"user32.dll"), "GetDpiForWindow"));
    if (fn) {
        const UINT d = fn(hwnd);
        if (d) return static_cast<int>(d);
    }
    HDC dc = GetDC(nullptr);
    const int d = GetDeviceCaps(dc, LOGPIXELSY);
    ReleaseDC(nullptr, dc);
    return d ? d : 96;
}

double Scale(HWND hwnd) { return DpiFor(hwnd) / 96.0; }

int Px(HWND hwnd, int logical96) {
    return static_cast<int>(lround(logical96 * Scale(hwnd)));
}

std::wstring EditionName() {
    std::wstring name;
    if (!reg::GetString(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
                        L"EditionID", name))
        name = L"";
    return name;
}

std::wstring DisplayVersion() {
    std::wstring v;
    if (!reg::GetString(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
                        L"DisplayVersion", v)) {
        reg::GetString(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
                       L"ReleaseId", v);
    }
    return v;
}

}  // namespace tig::os
#pragma GCC diagnostic pop
