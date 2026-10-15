#include "ui/theme.h"

#include "core/log.h"
#include "core/os.h"
#include "util/str.h"

namespace tig::ui::theme {

namespace {
Palette g_pal;
std::vector<std::function<void()>> g_subs;

void ResolveAccent() {
    const std::wstring& spec = settings::Get().accent;
    COLORREF accent = spec == L"system" || spec.empty() ? os::SystemAccentColor()
                                                        : ParseHex(spec, RGB(0x0F, 0x6C, 0xBD));
    // Ensure the accent is not too close to the background for contrast.
    g_pal.accent = accent;
    g_pal.accentHover = Mix(accent, g_pal.dark ? RGB(255, 255, 255) : RGB(0, 0, 0), 0.10);
    g_pal.accentPressed = Mix(accent, g_pal.dark ? RGB(255, 255, 255) : RGB(0, 0, 0), 0.20);
    g_pal.accentText = RGB(255, 255, 255);
    g_pal.accentSoft = Mix(accent, g_pal.dark ? RGB(0x20, 0x20, 0x20) : RGB(0xF3, 0xF3, 0xF3),
                           g_pal.dark ? 0.28 : 0.14);
}

void Resolve() {
    const bool dark = Mode() == ThemeMode::Dark ||
                      (Mode() == ThemeMode::System && !os::SystemUsesLightTheme());
    g_pal.dark = dark;
    if (dark) {
        g_pal.windowBg = RGB(0x20, 0x20, 0x20);
        g_pal.cardBg = RGB(0x2B, 0x2B, 0x2B);
        g_pal.cardBorder = RGB(0x3A, 0x3A, 0x3A);
        g_pal.navBg = RGB(0x20, 0x20, 0x20);
        g_pal.navHover = RGB(0x2A, 0x2A, 0x2A);
        g_pal.navSelected = RGB(0x2B, 0x2B, 0x2B);
        g_pal.textPrimary = RGB(0xFF, 0xFF, 0xFF);
        g_pal.textSecondary = RGB(0xC5, 0xC5, 0xC5);
        g_pal.textDisabled = RGB(0x8A, 0x8A, 0x8A);
        g_pal.controlBg = RGB(0x2B, 0x2B, 0x2B);
        g_pal.controlBorder = RGB(0x45, 0x45, 0x45);
        g_pal.controlHover = RGB(0x33, 0x33, 0x33);
        g_pal.controlPressed = RGB(0x3A, 0x3A, 0x3A);
        g_pal.toggleOff = RGB(0xA8, 0x4A, 0x00);  // dark orange, mirrors ON state rotated 180
        g_pal.toggleOffBorder = RGB(0xA8, 0x4A, 0x00);
        g_pal.knobOff = RGB(0xFF, 0xFF, 0xFF);
        g_pal.success = RGB(0x6C, 0xCB, 0x5F);
        g_pal.successSoft = RGB(0x2A, 0x3B, 0x2A);
        g_pal.warning = RGB(0xFC, 0xE1, 0x00);
        g_pal.warningSoft = RGB(0x3E, 0x3A, 0x24);
        g_pal.danger = RGB(0xFF, 0x99, 0xA4);
        g_pal.dangerSoft = RGB(0x44, 0x2A, 0x2C);
        g_pal.hoverOverlay = RGB(0x2E, 0x2E, 0x2E);
        g_pal.pressOverlay = RGB(0x35, 0x35, 0x35);
        g_pal.separator = RGB(0x3A, 0x3A, 0x3A);
        g_pal.scrollbar = RGB(0x5A, 0x5A, 0x5A);
        g_pal.scrollbarHot = RGB(0x76, 0x76, 0x76);
        g_pal.searchBg = RGB(0x2B, 0x2B, 0x2B);
        g_pal.searchBorder = RGB(0x45, 0x45, 0x45);
        g_pal.statusBarBg = RGB(0x1B, 0x1B, 0x1B);
    } else {
        g_pal.windowBg = RGB(0xF3, 0xF3, 0xF3);
        g_pal.cardBg = RGB(0xFB, 0xFB, 0xFB);
        g_pal.cardBorder = RGB(0xE5, 0xE5, 0xE5);
        g_pal.navBg = RGB(0xF3, 0xF3, 0xF3);
        g_pal.navHover = RGB(0xEA, 0xEA, 0xEA);
        g_pal.navSelected = RGB(0xFB, 0xFB, 0xFB);
        g_pal.textPrimary = RGB(0x1B, 0x1B, 0x1B);
        g_pal.textSecondary = RGB(0x5D, 0x5D, 0x5D);
        g_pal.textDisabled = RGB(0x9E, 0x9E, 0x9E);
        g_pal.controlBg = RGB(0xFB, 0xFB, 0xFB);
        g_pal.controlBorder = RGB(0xD1, 0xD1, 0xD1);
        g_pal.controlHover = RGB(0xF2, 0xF2, 0xF2);
        g_pal.controlPressed = RGB(0xE8, 0xE8, 0xE8);
        g_pal.toggleOff = RGB(0x9D, 0x4A, 0x00);  // dark orange, mirrors ON state rotated 180
        g_pal.toggleOffBorder = RGB(0x9D, 0x4A, 0x00);
        g_pal.knobOff = RGB(0xFF, 0xFF, 0xFF);
        g_pal.success = RGB(0x0F, 0x7B, 0x0F);
        g_pal.successSoft = RGB(0xDF, 0xF0, 0xDF);
        g_pal.warning = RGB(0x9D, 0x5D, 0x00);
        g_pal.warningSoft = RGB(0xFB, 0xEE, 0xD8);
        g_pal.danger = RGB(0xC4, 0x2B, 0x1C);
        g_pal.dangerSoft = RGB(0xF9, 0xE2, 0xE0);
        g_pal.hoverOverlay = RGB(0xEC, 0xEC, 0xEC);
        g_pal.pressOverlay = RGB(0xE3, 0xE3, 0xE3);
        g_pal.separator = RGB(0xE0, 0xE0, 0xE0);
        g_pal.scrollbar = RGB(0xC4, 0xC4, 0xC4);
        g_pal.scrollbarHot = RGB(0xA8, 0xA8, 0xA8);
        g_pal.searchBg = RGB(0xFB, 0xFB, 0xFB);
        g_pal.searchBorder = RGB(0xD1, 0xD1, 0xD1);
        g_pal.statusBarBg = RGB(0xEB, 0xEB, 0xEB);
    }
    ResolveAccent();
}

void Notify() {
    for (const auto& cb : g_subs) cb();
}
}  // namespace

COLORREF ParseHex(const std::wstring& hex, COLORREF fallback) {
    std::wstring h = hex;
    if (!h.empty() && h[0] == L'#') h.erase(0, 1);
    if (h.size() != 6) return fallback;
    const int v = wcstol(h.c_str(), nullptr, 16);
    if (v == 0 && h != L"000000") return fallback;
    return RGB((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
}

COLORREF Mix(COLORREF a, COLORREF b, double t) {
    const auto lerp = [](int x, int y, double tt) {
        return static_cast<BYTE>(x + (y - x) * tt);
    };
    return RGB(lerp(GetRValue(a), GetRValue(b), t), lerp(GetGValue(a), GetGValue(b), t),
               lerp(GetBValue(a), GetBValue(b), t));
}

void Init() {
    Resolve();
    log::Info(str::Format(L"theme initialized: mode=%d dark=%d", static_cast<int>(Mode()),
                          IsDark() ? 1 : 0));
}

ThemeMode Mode() { return settings::Get().theme; }

bool IsDark() { return g_pal.dark; }

const Palette& Pal() { return g_pal; }

COLORREF Accent() { return g_pal.accent; }

void SetMode(ThemeMode mode) {
    settings::Get().theme = mode;
    settings::Save();
    Resolve();
    Notify();
}

void SetAccent(const std::wstring& spec) {
    settings::Get().accent = spec;
    settings::Save();
    Resolve();
    Notify();
}

void OnSystemThemeChanged() {
    if (Mode() != ThemeMode::System) return;
    Resolve();
    Notify();
}

void Subscribe(const std::function<void()>& cb) { g_subs.push_back(cb); }

const std::vector<AccentPreset>& AccentPresets() {
    static const std::vector<AccentPreset> presets = {
        {L"#0F6CBD", L"Windows blue", L"Синий Windows"},
        {L"#744DA9", L"Violet", L"Фиолетовый"},
        {L"#0E7070", L"Teal", L"Бирюзовый"},
        {L"#0F7B0F", L"Green", L"Зелёный"},
        {L"#98450C", L"Rust", L"Терракота"},
        {L"#C239B3", L"Orchid", L"Орхидея"},
        {L"#9A0021", L"Crimson", L"Багровый"},
        {L"#4C5B66", L"Graphite", L"Графит"},
    };
    return presets;
}

}  // namespace tig::ui::theme
