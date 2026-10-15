// TrayIconGuard v8 — theme manager: Light / Dark / System with persistence,
// first-run auto-detection and live switching (user requirement #1).
#pragma once
#include <functional>
#include <string>
#include <vector>
#include <windows.h>

#include "core/settings.h"

namespace tig::ui {

struct Palette {
    bool dark = false;
    COLORREF windowBg = 0, cardBg = 0, cardBorder = 0;
    COLORREF navBg = 0, navHover = 0, navSelected = 0;
    COLORREF textPrimary = 0, textSecondary = 0, textDisabled = 0;
    COLORREF accent = 0, accentHover = 0, accentPressed = 0, accentText = 0, accentSoft = 0;
    COLORREF controlBg = 0, controlBorder = 0, controlHover = 0, controlPressed = 0;
    COLORREF toggleOff = 0, toggleOffBorder = 0, knobOff = 0;  // off track = dark orange (no border)
    COLORREF success = 0, successSoft = 0, warning = 0, warningSoft = 0;
    COLORREF danger = 0, dangerSoft = 0;
    COLORREF hoverOverlay = 0, pressOverlay = 0, separator = 0;
    COLORREF scrollbar = 0, scrollbarHot = 0;
    COLORREF searchBg = 0, searchBorder = 0;
    COLORREF statusBarBg = 0;
};

namespace theme {

void Init();                                  // resolve once at startup
void SetMode(ThemeMode mode);                 // persist + re-resolve + notify
ThemeMode Mode();
bool IsDark();
const Palette& Pal();
COLORREF Accent();                            // resolved accent color
void SetAccent(const std::wstring& spec);     // "system" | "#RRGGBB"
void OnSystemThemeChanged();                  // WM_SETTINGCHANGE("ImmersiveColorSet")
void Subscribe(const std::function<void()>& cb);

COLORREF Mix(COLORREF a, COLORREF b, double t);
COLORREF ParseHex(const std::wstring& hex, COLORREF fallback);

// Preset accent swatches shown on the Appearance page.
struct AccentPreset { const wchar_t* hex; const wchar_t* nameEn; const wchar_t* nameRu; };
const std::vector<AccentPreset>& AccentPresets();

}  // namespace theme
}  // namespace tig::ui
