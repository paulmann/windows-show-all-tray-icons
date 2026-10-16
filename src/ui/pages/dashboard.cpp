// TrayIconGuard v8 — Dashboard page: hero status, quick actions, hints,
// system card and recent activity feed.
#include "core/autostart.h"
#include "core/explorer.h"
#include "core/guard.h"
#include "core/legacy.h"
#include "core/log.h"
#include "core/os.h"
#include "core/settings.h"
#include "core/trayicons.h"
#include "pages.h"
#include "ui/trayicon.h"
#include "ui/theme.h"
#include "util/str.h"

namespace tig::ui {

namespace {

class DashboardPage : public Page {
public:
    l10n::S TitleId() const override { return l10n::S::DashTitle; }
    l10n::S SubId() const override { return l10n::S::DashSub; }
    wchar_t Glyph() const override { return 0xE80F; }

    Button* btnPromote = nullptr;
    Button* btnPause = nullptr;
    Button* btnRestart = nullptr;
    Button* btnAutostart = nullptr;
    bool showWelcome = false;
    bool showAutostartHint = false;

    void Build(HWND hwnd) override {
        auto promote = std::make_unique<Button>();
        promote->style = Button::Style::Accent;
        promote->glyph = 0xE70E;  // chevron up
        promote->onClick = [this] { MainWindow::Instance().PromoteAllNow(); };
        btnPromote = promote.get();
        widgets.push_back(std::move(promote));

        auto pause = std::make_unique<Button>();
        pause->glyph = 0xE769;
        pause->onClick = [this] {
            const guard::Stats gs = guard::GetStats();
            if (gs.paused)
                guard::Resume();
            else
                guard::Pause();
            tray::UpdateIcon();
            SyncLabels();
            OnDataChanged();
        };
        btnPause = pause.get();
        widgets.push_back(std::move(pause));

        auto restart = std::make_unique<Button>();
        restart->glyph = 0xE72C;
        restart->onClick = [] {
            if (settings::Get().confirmExplorerRestart &&
                !dialogs::Confirm(MainWindow::Instance().Hwnd(),
                                  l10n::t(l10n::S::ExpRestartTitle),
                                  l10n::t(l10n::S::ExpRestartText)))
                return;
            MainWindow::Instance().RestartExplorerNow();
        };
        btnRestart = restart.get();
        widgets.push_back(std::move(restart));

        auto autostart = std::make_unique<Button>();
        autostart->style = Button::Style::Outline;
        autostart->onClick = [this] {
            if (autostart::IsInstalled())
                autostart::Uninstall();
            else
                autostart::Install();
            settings::Get().autoStart = autostart::IsInstalled();
            settings::Save();
            SyncLabels();
            OnDataChanged();
        };
        btnAutostart = autostart.get();
        widgets.push_back(std::move(autostart));

        SyncLabels();
        (void)hwnd;
    }

    void SyncLabels() {
        if (btnPromote) btnPromote->label = l10n::t(l10n::S::PromoteAllNow);
        if (btnPause) {
            const bool paused = guard::GetStats().paused;
            btnPause->label = paused ? l10n::t(l10n::S::ResumeGuard) : l10n::t(l10n::S::PauseGuard);
            btnPause->glyph = paused ? 0xE768 : 0xE769;
        }
        if (btnRestart) btnRestart->label = l10n::t(l10n::S::RestartExplorer);
        if (btnAutostart)
            btnAutostart->label = autostart::IsInstalled()
                                      ? l10n::t(l10n::S::DisableAutostart)
                                      : l10n::t(l10n::S::EnableAutostart);
    }

    void OnShow(HWND) override {
        SyncLabels();
        showWelcome = settings::IsFirstRun() || !settings::Get().firstRunDone;
        showAutostartHint = !autostart::IsInstalled();
    }

    void Refresh() override {
        Page::Refresh();
        SyncLabels();
    }

    void OnDataChanged() override { SyncLabels(); }

    void LayoutContent(HWND hwnd, int width) override {
        const int pad = 28;
        const int W = width - pad * 2;
        int y = 12;
        const float sc = static_cast<float>(os::DpiFor(hwndRef)) / 96.f;
        (void)sc;

        // hero card (8.4 polish: +16 px so tiles keep a 12 px gap to the action row)
        const int heroH = 184;
        RECT hero{pad, y, pad + W, y + heroH};
        // buttons inside hero, right-bottom
        const int bw1 = btnPromote->PreferredWidth(hwnd);
        const int bw2 = btnPause->PreferredWidth(hwnd);
        const int bw3 = btnRestart->PreferredWidth(hwnd);
        btnPromote->Layout({hero.right - 16 - bw1, hero.bottom - 48, hero.right - 16, hero.bottom - 16});
        btnPause->Layout({btnPromote->rc.left - 8 - bw2, hero.bottom - 48, btnPromote->rc.left - 8, hero.bottom - 16});
        btnRestart->Layout({btnPause->rc.left - 8 - bw3, hero.bottom - 48, btnPause->rc.left - 8, hero.bottom - 16});
        y += heroH + 12;

        // hint card
        const bool hint = showWelcome || showAutostartHint;
        RECT hintRc{0, 0, 0, 0};
        if (hint) {
            hintRc = {pad, y, pad + W, y + 84};
            const int bw = btnAutostart->PreferredWidth(hwnd);
            if (showAutostartHint)
                btnAutostart->Layout({hintRc.right - 16 - bw, hintRc.top + 26,
                                      hintRc.right - 16, hintRc.top + 58});
            y += 84 + 12;
        }

        // two columns
        const int leftW = static_cast<int>(W * 0.46);
        const int colGap = 14;
        RECT sysCard{pad, y, pad + leftW, y + 190};
        RECT actCard{pad + leftW + colGap, y, pad + W, y + 190};
        y += 190 + 16;

        contentH = y;
        // store geometry for paint
        geoHero = ToWindow(hero);
        geoHint = ToWindow(hintRc);
        geoHintVisible = hint;
        geoSys = ToWindow(sysCard);
        geoAct = ToWindow(actCard);
        (void)hwnd;
    }

    void PaintBackground(PaintCtx& pc) override {
        const Palette& P = theme::Pal();
        const HWND hwnd = hwndRef;
        // ---- hero
        DrawCard(pc, geoHero);
        const guard::Stats gs = guard::GetStats();
        const store::Counts c = store::GetCounts(store::Current());
        Gdiplus::Bitmap* icon = gfx::AppIconBitmap(44);
        if (icon) {
            Gdiplus::RectF ir(geoHero.left + 20.f, geoHero.top + 20.f, 44.f, 44.f);
            pc.g.DrawImage(icon, ir);
        }
        const wchar_t* status = !store::Supported()      ? l10n::t(l10n::S::StatusUnsupported)
                                : !gs.running            ? l10n::t(l10n::S::StatusOff)
                                : gs.paused              ? l10n::t(l10n::S::StatusPaused)
                                                         : l10n::t(l10n::S::StatusGuarding);
        const COLORREF statusCol = !store::Supported() ? P.textDisabled
                                   : !gs.running       ? P.textSecondary
                                   : gs.paused         ? P.warning
                                                       : P.success;
        Gdiplus::RectF st(geoHero.left + 76.f, geoHero.top + 28.f,
                          static_cast<float>(geoHero.right - geoHero.left) - 100.f, 30.f);
        gfx::DrawString(pc.g, status, gfx::Font(hwnd, 20.f, FontStyle::SemiBold), st,
                        gfx::C(statusCol));
        Gdiplus::RectF stsub(st.X, st.GetBottom(), st.Width, 18.f);
        gfx::DrawString(pc.g, l10n::t(l10n::S::Tagline), gfx::Font(hwnd, 12.f), stsub,
                        gfx::C(P.textSecondary));
        // stat tiles
        const struct {
            int value;
            const wchar_t* label;
        } tiles[4] = {{c.total, l10n::t(l10n::S::StatTotal)},
                      {c.promoted, l10n::t(l10n::S::StatPromoted)},
                      {c.hidden, l10n::t(l10n::S::StatHidden)},
                      {c.excluded, l10n::t(l10n::S::StatExcluded)}};
        const int tileGap = 10;
        const int heroInner = geoHero.right - geoHero.left - 40;
        int tileW = (heroInner - 3 * tileGap) / 4;  // responsive width
        if (tileW > 168) tileW = 168;
        if (tileW < 112) tileW = 112;
        int tx = geoHero.left + 20;
        const int ty = geoHero.top + 80;
        for (const auto& t : tiles) {
            Gdiplus::RectF tr(static_cast<float>(tx), static_cast<float>(ty),
                              static_cast<float>(tileW), 44.f);
            gfx::FillRoundRect(pc.g, tr, 6.f,
                               gfx::C(theme::Mix(P.cardBg, P.windowBg, 0.5)));
            gfx::StrokeRoundRect(pc.g, tr, 6.f, gfx::C(P.cardBorder), 1.f);
            Gdiplus::RectF vr(tr.X + 12.f, tr.Y + 6.f, tr.Width - 24.f, 24.f);
            gfx::DrawString(pc.g, str::Format(L"%d", t.value),
                            gfx::Font(hwnd, 18.f, FontStyle::SemiBold), vr,
                            gfx::C(P.textPrimary), Gdiplus::StringAlignmentNear);
            Gdiplus::RectF lr(tr.X + 12.f, vr.GetBottom() - 2.f, tr.Width - 24.f, 16.f);
            gfx::DrawString(pc.g, t.label, gfx::Font(hwnd, 10.5f), lr, gfx::C(P.textSecondary),
                            Gdiplus::StringAlignmentNear);
            tx += tileW + tileGap;
        }

        // ---- hint card
        if (geoHintVisible) {
            DrawCard(pc, geoHint);
            const std::wstring title =
                showWelcome ? l10n::t(l10n::S::WelcomeTitle) : l10n::t(l10n::S::HintAutostartTitle);
            const std::wstring text =
                showWelcome ? l10n::t(l10n::S::WelcomeText) : l10n::t(l10n::S::HintAutostartText);
            Gdiplus::RectF tr(geoHint.left + 16.f, geoHint.top + 14.f,
                              static_cast<float>(geoHint.right - geoHint.left) - 220.f, 20.f);
            gfx::DrawGlyph(pc.g, showWelcome ? 0xE946 : 0xE7BA, gfx::GlyphFont(hwnd, 15.f),
                           Gdiplus::RectF(tr.X, tr.Y + 1.f, 20.f, 18.f),
                           gfx::C(showWelcome ? P.accent : P.warning),
                           Gdiplus::StringAlignmentNear);
            tr.X += 26.f;
            tr.Width -= 26.f;
            gfx::DrawString(pc.g, title, gfx::Font(hwnd, 14.f, FontStyle::SemiBold), tr,
                            gfx::C(P.textPrimary));
            Gdiplus::RectF xr(tr.X, tr.GetBottom() + 2.f, tr.Width, 40.f);
            gfx::DrawString(pc.g, text, gfx::Font(hwnd, 11.5f), xr, gfx::C(P.textSecondary));
            if (showAutostartHint) btnAutostart->Paint(pc);
        }

        // ---- system card
        DrawCard(pc, geoSys, l10n::t(l10n::S::CardSystem));
        DWORD autoTray = 0;
        const bool hasAt = legacy::GetEnableAutoTray(autoTray);
        const int sca = legacy::CountHideScaPolicies();
        std::wstring legacyTxt = l10n::t(l10n::S::LegacyNone);
        {
            std::vector<std::wstring> parts;
            if (hasAt && autoTray == 0) parts.push_back(l10n::t(l10n::S::LegacyAutoTray));
            if (sca > 0) parts.push_back(str::Format(L"%s: %d", l10n::t(l10n::S::LegacySca), sca));
            if (!parts.empty()) legacyTxt = str::Join(parts, L", ");
        }
        const struct {
            const wchar_t* k;
            std::wstring v;
        } rows[4] = {
            {l10n::t(l10n::S::RowOs), os::Get().caption},
            {l10n::t(l10n::S::RowStore),
             store::Supported() ? l10n::t(l10n::S::RowStoreOk) : l10n::t(l10n::S::RowStoreNo)},
            {l10n::t(l10n::S::RowExplorer),
             str::Format(L"pid %lu", explorer::Pid())},
            {l10n::t(l10n::S::RowLegacy), legacyTxt},
        };
        int ry = geoSys.top + 44;
        for (const auto& r : rows) {
            const float keyW = std::max(110.f, std::min(150.f,
                static_cast<float>(geoSys.right - geoSys.left) * 0.36f - 16.f));
            Gdiplus::RectF kr(geoSys.left + 16.f, static_cast<float>(ry), keyW, 20.f);
            gfx::DrawString(pc.g, r.k, gfx::Font(hwnd, 12.f), kr, gfx::C(P.textSecondary));
            Gdiplus::RectF vr(kr.GetRight() + 8.f, static_cast<float>(ry),
                              static_cast<float>(geoSys.right) - kr.GetRight() - 24.f, 20.f);
            gfx::DrawString(pc.g, r.v, gfx::Font(hwnd, 12.f, FontStyle::Medium), vr,
                            gfx::C(P.textPrimary));
            ry += 34;
        }

        // ---- activity card
        DrawCard(pc, geoAct, l10n::t(l10n::S::CardRecent));
        const auto entries = log::Tail(6);
        if (entries.empty()) {
            Gdiplus::RectF er(geoAct.left + 16.f, geoAct.top + 52.f,
                              static_cast<float>(geoAct.right - geoAct.left) - 32.f, 20.f);
            gfx::DrawString(pc.g, l10n::t(l10n::S::NoRecent), gfx::Font(hwnd, 12.f), er,
                            gfx::C(P.textDisabled));
        } else {
            int ey = geoAct.top + 44;
            for (auto it = entries.rbegin(); it != entries.rend(); ++it) {
                const COLORREF lc = it->level == log::Level::Error   ? P.danger
                                    : it->level == log::Level::Warn   ? P.warning
                                    : it->level == log::Level::Event ? P.success
                                                                     : P.textSecondary;
                Gdiplus::RectF tr(geoAct.left + 16.f, static_cast<float>(ey),
                                  static_cast<float>(geoAct.right - geoAct.left) - 32.f, 22.f);
                const std::wstring line = str::Format(
                    L"%02d:%02d:%02d  %s", it->time.wHour, it->time.wMinute, it->time.wSecond,
                    it->msg.c_str());
                gfx::DrawString(pc.g, line, gfx::MonoFont(hwnd, 11.5f), tr, gfx::C(lc));
                ey += 24;
            }
        }
    }

    RECT geoHero{}, geoHint{}, geoSys{}, geoAct{};
    bool geoHintVisible = false;
};

}  // namespace

std::unique_ptr<Page> MakeDashboardPage() { return std::make_unique<DashboardPage>(); }

}  // namespace tig::ui
