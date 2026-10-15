// TrayIconGuard v8 — Appearance page: theme switcher (Light/Dark/System),
// accent presets, language, effects.
#include "core/os.h"
#include "core/settings.h"
#include "pages.h"
#include "ui/theme.h"
#include "util/str.h"

namespace tig::ui {

namespace {
constexpr int kRowH = 56;

class SwatchGrid : public Widget {
public:
    std::function<void(const std::wstring&)> onPick;
    int hoverIdx = -1;

    int IdxAt(POINT p) const {
        const int cell = 34;
        const int x = p.x - rc.left - 4;
        const int y = p.y - rc.top;
        if (x < 0 || y < 0 || y > cell) return -1;
        const int idx = x / cell;
        return idx < static_cast<int>(theme::AccentPresets().size()) ? idx : -1;
    }
    void Paint(PaintCtx& pc) override {
        const auto& presets = theme::AccentPresets();
        const std::wstring cur = settings::Get().accent;
        int x = rc.left + 4;
        for (size_t i = 0; i < presets.size(); ++i) {
            const COLORREF c = theme::ParseHex(presets[i].hex, RGB(0, 0, 0));
            Gdiplus::RectF r(static_cast<float>(x) + 3.f, static_cast<float>(rc.top) + 3.f, 28.f,
                             28.f);
            gfx::FillRoundRect(pc.g, r, 14.f, gfx::C(c));
            const bool sel = str::IEquals(cur, presets[i].hex);
            if (sel)
                gfx::StrokeRoundRect(pc.g, Gdiplus::RectF(r.X - 3, r.Y - 3, r.Width + 6, r.Height + 6),
                                     17.f, gfx::C(theme::Pal().textPrimary), 2.f);
            else if (static_cast<int>(i) == hoverIdx)
                gfx::StrokeRoundRect(pc.g, Gdiplus::RectF(r.X - 2, r.Y - 2, r.Width + 4, r.Height + 4),
                                     16.f, gfx::C(theme::Pal().textSecondary, 160), 1.5f);
            x += 34;
        }
    }
    bool OnMouse(ME e, POINT p) override {
        if (e == ME::Move) {
            hoverIdx = IdxAt(p);
            return true;
        }
        if (e == ME::Leave) {
            hoverIdx = -1;
            return true;
        }
        if (e == ME::Click) {
            const int idx = IdxAt(p);
            if (idx >= 0 && onPick) onPick(theme::AccentPresets()[idx].hex);
            return true;
        }
        return Widget::OnMouse(e, p);
    }
};

class LangList : public Widget {
public:
    std::function<void(const std::wstring&)> onChange;
    int scroll = 0;
    int hover = -1;
    ScrollBar sbar;

    static int Rows() { return static_cast<int>(l10n::Languages().size()) + 1; }
    std::wstring CodeAt(int i) const {
        if (i == 0) return L"auto";
        return l10n::Languages()[i - 1].code;
    }
    int RowH() const { return 34; }
    int IdxAt(POINT p) const {
        if (!PtInRect(&rc, p)) return -1;
        const int i = (p.y - rc.top + scroll) / RowH();
        return i >= 0 && i < Rows() ? i : -1;
    }
    void SyncScroll() {
        sbar.SetRange(Rows() * RowH(), Height());
        sbar.pos = scroll;
        // keep selection visible
        const std::wstring cur = l10n::ConfiguredLanguage();
        int sel = 0;
        for (int i = 0; i < Rows(); ++i)
            if (CodeAt(i) == cur) sel = i;
        if (scroll > sel * RowH()) scroll = sel * RowH();
        sbar.pos = scroll;
    }
    void Paint(PaintCtx& pc) override {
        const Palette& P = theme::Pal();
        gfx::FillRoundRect(pc.g, gfx::RectFOf(rc), 6.f, gfx::C(P.searchBg));
        gfx::StrokeRoundRect(pc.g, gfx::RectFOf(rc), 6.f, gfx::C(P.searchBorder), 1.f);
        Gdiplus::GraphicsState st = pc.g.Save();
        pc.g.SetClip(gfx::RectFOf(rc));
        const std::wstring cur = l10n::ConfiguredLanguage();
        const int first = scroll / RowH();
        const int last = std::min(Rows() - 1, (scroll + Height()) / RowH());
        for (int i = first; i <= last; ++i) {
            const int y = rc.top + i * RowH() - scroll;
            if (i == hover)
                gfx::FillRect(pc.g, Gdiplus::RectF(static_cast<float>(rc.left) + 1,
                                                   static_cast<float>(y),
                                                   static_cast<float>(Width()) - 2,
                                                   static_cast<float>(RowH())),
                              gfx::C(P.hoverOverlay, 160));
            const bool sel = CodeAt(i) == cur;
            std::wstring native, second;
            if (i == 0) {
                native = l10n::t(l10n::S::LangAuto);
                second = L"OS";
            } else {
                const auto& lt = l10n::Languages()[i - 1];
                native = lt.native;
                second = std::wstring(lt.english) + L"  ·  " + lt.code;
            }
            Gdiplus::RectF nr(rc.left + 14.f, static_cast<float>(y), 220.f,
                              static_cast<float>(RowH()));
            gfx::DrawString(pc.g, native, gfx::Font(pc.hwnd, 13.f, FontStyle::Medium), nr,
                            gfx::C(sel ? P.accent : P.textPrimary), Gdiplus::StringAlignmentNear);
            Gdiplus::RectF sr(rc.left + 250.f, static_cast<float>(y),
                              static_cast<float>(Width()) - 290.f, static_cast<float>(RowH()));
            gfx::DrawString(pc.g, second, gfx::Font(pc.hwnd, 11.f), sr,
                            gfx::C(P.textSecondary), Gdiplus::StringAlignmentNear);
            if (sel)
                gfx::DrawGlyph(pc.g, 0xE73E, gfx::GlyphFont(pc.hwnd, 14.f),
                               Gdiplus::RectF(static_cast<float>(rc.right) - 30.f,
                                              static_cast<float>(y), 20.f,
                                              static_cast<float>(RowH())),
                               gfx::C(P.accent));
        }
        pc.g.Restore(st);
        sbar.rc = {rc.right - 9, rc.top + 3, rc.right - 3, rc.bottom - 3};
        sbar.Paint(pc);
    }
    bool OnMouse(ME e, POINT p) override {
        switch (e) {
            case ME::Move:
                hover = IdxAt(p);
                if (sbar.Needed()) sbar.OnMouse(e, p);
                return true;
            case ME::Leave:
                hover = -1;
                return true;
            case ME::Down:
            case ME::Up:
                if (sbar.Needed() && sbar.HitTest(p)) return sbar.OnMouse(e, p);
                return true;
            case ME::Click: {
                if (sbar.Needed() && sbar.HitTest(p)) return sbar.OnMouse(e, p);
                const int i = IdxAt(p);
                if (i >= 0 && onChange) onChange(CodeAt(i));
                return true;
            }
            default:
                return Widget::OnMouse(e, p);
        }
    }
    bool Wheel(int delta) {
        if (!sbar.Needed()) return false;
        const int before = sbar.pos;
        sbar.ScrollBy(-delta / 120 * 40);
        scroll = sbar.pos;
        return sbar.pos != before;
    }
};

class AppearancePage : public Page {
public:
    l10n::S TitleId() const override { return l10n::S::AppTitle; }
    l10n::S SubId() const override { return l10n::S::AppSub; }
    wchar_t Glyph() const override { return 0xE771; }

    Segmented* segTheme = nullptr;
    Toggle* tgSystemAccent = nullptr;
    SwatchGrid* swatches = nullptr;
    class LangList* langList = nullptr;
    Toggle* tgAnim = nullptr;
    Toggle* tgCompact = nullptr;
    Button* btnReset = nullptr;

    void Build(HWND) override {
        auto st = std::make_unique<Segmented>();
        st->items = {{l10n::t(l10n::S::ThemeLight), 0xE706},
                     {l10n::t(l10n::S::ThemeDark), 0xE708},
                     {l10n::t(l10n::S::ThemeSystem), 0xE7F4}};
        st->selected = static_cast<int>(theme::Mode());
        st->selAnim = static_cast<float>(st->selected);
        st->onChange = [](int i) {
            theme::SetMode(static_cast<ThemeMode>(i));
            MainWindow::Instance().RefreshEverything();
        };
        segTheme = st.get();
        widgets.push_back(std::move(st));

        auto sa = std::make_unique<Toggle>();
        sa->on = settings::Get().accent == L"system";
        sa->onChange = [](bool v) {
            theme::SetAccent(v ? L"system" : settings::Get().accent == L"system"
                                                  ? L"#0F6CBD"
                                                  : settings::Get().accent);
            MainWindow::Instance().RefreshEverything();
        };
        tgSystemAccent = sa.get();
        widgets.push_back(std::move(sa));

        auto sw = std::make_unique<SwatchGrid>();
        sw->onPick = [](const std::wstring& hex) {
            theme::SetAccent(hex);
            MainWindow::Instance().RefreshEverything();
        };
        swatches = sw.get();
        widgets.push_back(std::move(sw));

        auto ll = std::make_unique<LangList>();
        ll->onChange = [](const std::wstring& code) {
            settings::Get().language = code;
            settings::Save();
            l10n::SetLanguage(code);
            MainWindow::Instance().RefreshEverything();
        };
        langList = ll.get();
        widgets.push_back(std::move(ll));

        auto ta = std::make_unique<Toggle>();
        ta->on = settings::Get().animations;
        ta->onChange = [](bool v) {
            settings::Get().animations = v;
            settings::Save();
        };
        tgAnim = ta.get();
        widgets.push_back(std::move(ta));

        auto tc = std::make_unique<Toggle>();
        tc->on = settings::Get().compactRows;
        tc->onChange = [](bool v) {
            settings::Get().compactRows = v;
            settings::Save();
            MainWindow::Instance().NotifyDataChanged();
        };
        tgCompact = tc.get();
        widgets.push_back(std::move(tc));

        auto br = std::make_unique<Button>();
        br->style = Button::Style::Outline;
        br->label = l10n::t(l10n::S::ResetAppearance);
        br->onClick = [] {
            settings::Get().theme = ThemeMode::System;
            settings::Get().accent = L"system";
            settings::Get().animations = true;
            settings::Get().compactRows = false;
            settings::Save();
            theme::SetMode(ThemeMode::System);
            theme::SetAccent(L"system");
            MainWindow::Instance().RefreshEverything();
        };
        btnReset = br.get();
        widgets.push_back(std::move(br));
    }

    void Refresh() override {
        Page::Refresh();
        if (segTheme) {
            segTheme->items[0].label = l10n::t(l10n::S::ThemeLight);
            segTheme->items[1].label = l10n::t(l10n::S::ThemeDark);
            segTheme->items[2].label = l10n::t(l10n::S::ThemeSystem);
            segTheme->selected = static_cast<int>(theme::Mode());
        }
        if (langList) InvalidateRect(hwndRef, nullptr, FALSE);
        if (tgSystemAccent) tgSystemAccent->on = settings::Get().accent == L"system";
        if (tgAnim) tgAnim->on = settings::Get().animations;
        if (tgCompact) tgCompact->on = settings::Get().compactRows;
        if (btnReset) btnReset->label = l10n::t(l10n::S::ResetAppearance);
    }

    void LayoutContent(HWND hwnd, int width) override {
        const int pad = 28;
        const int W = width - pad * 2;
        int y = 12;
        const int themeH = 40 + kRowH;
        RECT themeCard{pad, y, pad + W, y + themeH};
        y += themeH + 12;
        const int accentH = 40 + kRowH + 44;
        RECT accentCard{pad, y, pad + W, y + accentH};
        y += accentH + 12;
        const int langH = 40 + 218;
        RECT langCard{pad, y, pad + W, y + langH};
        y += langH + 12;
        const int fxH = 40 + kRowH * 2 + 52;
        RECT fxCard{pad, y, pad + W, y + fxH};
        y += fxH + 16;

        segTheme->Layout({themeCard.right - 16 - segTheme->PreferredWidth(hwnd),
                          themeCard.top + (themeH - 32) / 2, themeCard.right - 16,
                          themeCard.top + (themeH - 32) / 2 + 32});

        tgSystemAccent->Layout({accentCard.left, accentCard.top + 40, accentCard.right - 16,
                                accentCard.top + 40 + kRowH});
        swatches->Layout({accentCard.left + 16, accentCard.top + 40 + kRowH + 6,
                          accentCard.left + 16 + 34 * 8 + 8, accentCard.top + 40 + kRowH + 40});

        langList->Layout({langCard.left + 16, langCard.top + 40, langCard.right - 16,
                          langCard.top + 40 + 206});

        tgAnim->Layout({fxCard.left, fxCard.top + 40, fxCard.right - 16, fxCard.top + 40 + kRowH});
        tgCompact->Layout({fxCard.left, fxCard.top + 40 + kRowH, fxCard.right - 16,
                           fxCard.top + 40 + kRowH * 2});
        const int bw = btnReset->PreferredWidth(hwnd);
        btnReset->Layout({fxCard.left + 16, fxCard.top + 40 + kRowH * 2 + 8,
                          fxCard.left + 16 + bw, fxCard.top + 40 + kRowH * 2 + 40});

        geoTheme = ToWindow(themeCard);
        geoAccent = ToWindow(accentCard);
        geoLang = ToWindow(langCard);
        geoFx = ToWindow(fxCard);
        contentH = y;
    }

    void PaintBackground(PaintCtx& pc) override {
        const Palette& P = theme::Pal();
        DrawCard(pc, geoTheme, l10n::t(l10n::S::CardTheme));
        DrawSettingRow(pc, {geoTheme.left, geoTheme.top + 40 - 8, geoTheme.right, geoTheme.bottom},
                       l10n::t(l10n::S::ThemeDesc), L"", true);
        DrawCard(pc, geoAccent, l10n::t(l10n::S::CardAccent));
        DrawSettingRow(pc, {geoAccent.left, geoAccent.top + 40, geoAccent.right,
                            geoAccent.top + 40 + kRowH},
                       l10n::t(l10n::S::AccentSystem), L"");
        DrawCard(pc, geoLang, l10n::t(l10n::S::CardLanguage));
        Gdiplus::RectF lh(geoLang.left + 16.f, static_cast<float>(langList->rc.bottom) + 4.f,
                          static_cast<float>(geoLang.right - geoLang.left) - 32.f, 16.f);
        gfx::DrawString(pc.g, l10n::t(l10n::S::LangHint), gfx::Font(pc.hwnd, 10.5f), lh,
                        gfx::C(P.textDisabled), Gdiplus::StringAlignmentNear);
        DrawCard(pc, geoFx, l10n::t(l10n::S::CardEffects));
        DrawSettingRow(pc, {geoFx.left, geoFx.top + 40, geoFx.right, geoFx.top + 40 + kRowH},
                       l10n::t(l10n::S::Animations), l10n::t(l10n::S::AnimationsDesc));
        DrawSettingRow(pc, {geoFx.left, geoFx.top + 40 + kRowH, geoFx.right,
                            geoFx.top + 40 + kRowH * 2},
                       l10n::t(l10n::S::CompactRows), l10n::t(l10n::S::CompactRowsDesc), true);
    }

    bool Wheel(HWND hwnd, int delta) override {
        if (langList && langList->Wheel(delta)) {
            InvalidateRect(hwnd, nullptr, FALSE);
            return true;
        }
        return false;
    }

    RECT geoTheme{}, geoAccent{}, geoLang{}, geoFx{};
};

}  // namespace

std::unique_ptr<Page> MakeAppearancePage() { return std::make_unique<AppearancePage>(); }

}  // namespace tig::ui
