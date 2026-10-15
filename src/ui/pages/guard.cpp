// TrayIconGuard v8 — Guard page: watcher config, repairs, stats, exclusions.
#include <algorithm>

#include "core/backup.h"
#include "core/explorer.h"
#include "core/guard.h"
#include "core/legacy.h"
#include "core/log.h"
#include "core/settings.h"
#include "core/trayicons.h"
#include "pages.h"
#include "ui/trayicon.h"
#include "ui/theme.h"
#include "util/str.h"

namespace tig::ui {

namespace {

constexpr int kRowH = 56;

class GuardPage : public Page {
public:
    l10n::S TitleId() const override { return l10n::S::GuardTitle; }
    l10n::S SubId() const override { return l10n::S::GuardSub; }
    wchar_t Glyph() const override { return 0xE72E; }

    Toggle* tgRun = nullptr;
    Segmented* segDebounce = nullptr;
    Segmented* segPoll = nullptr;
    Toggle* tgAutoRestart = nullptr;
    Segmented* segCooldown = nullptr;
    Toggle* tgBalloons = nullptr;
    Toggle* tgLegacyBelt = nullptr;
    Button* btnSca = nullptr;
    Button* btnCache = nullptr;
    SearchBox* exclAdd = nullptr;
    Button* btnAdd = nullptr;
    Button* btnRemove = nullptr;
    int exclSelected = -1;

    void Build(HWND hwnd) override {
        auto t = std::make_unique<Toggle>();
        t->on = settings::Get().guardEnabled;
        t->onChange = [](bool v) {
            settings::Get().guardEnabled = v;
            settings::Save();
            if (v)
                guard::Start();
            else
                guard::Stop();
            tray::UpdateIcon();
        };
        tgRun = t.get();
        widgets.push_back(std::move(t));

        segDebounce = AddSeg({200, 400, 800, 1500}, settings::Get().debounceMs,
                             [](int v) {
                                 settings::Get().debounceMs = v;
                                 settings::Save();
                             });
        segPoll = AddSeg({0, 2000, 5000, 15000}, settings::Get().pollMs, [](int v) {
            settings::Get().pollMs = v;
            settings::Save();
        });
        segCooldown = AddSeg({30, 60, 120, 300}, settings::Get().explorerCooldownSec, [](int v) {
            settings::Get().explorerCooldownSec = v;
            settings::Save();
        });

        auto tar = std::make_unique<Toggle>();
        tar->on = settings::Get().autoRestartExplorer;
        tar->onChange = [](bool v) {
            settings::Get().autoRestartExplorer = v;
            settings::Save();
        };
        tgAutoRestart = tar.get();
        widgets.push_back(std::move(tar));

        auto tb = std::make_unique<Toggle>();
        tb->on = settings::Get().notifications;
        tb->onChange = [](bool v) {
            settings::Get().notifications = v;
            settings::Save();
        };
        tgBalloons = tb.get();
        widgets.push_back(std::move(tb));

        auto tlb = std::make_unique<Toggle>();
        tlb->on = settings::Get().legacyBelt;
        tlb->onChange = [](bool v) {
            settings::Get().legacyBelt = v;
            settings::Save();
            if (v)
                legacy::ApplyEnableAutoTray();
            else
                legacy::RemoveEnableAutoTray();
        };
        tgLegacyBelt = tlb.get();
        widgets.push_back(std::move(tlb));

        auto bs = std::make_unique<Button>();
        bs->style = Button::Style::Outline;
        bs->label = l10n::t(l10n::S::RemoveSca);
        bs->onClick = [] {
            const int n = legacy::RemoveHideScaPolicies();
            log::Event(str::Format(L"HideSCA* removed: %d", n));
            MainWindow::Instance().NotifyDataChanged();
        };
        btnSca = bs.get();
        widgets.push_back(std::move(bs));

        auto bc = std::make_unique<Button>();
        bc->style = Button::Style::Danger;
        bc->label = l10n::t(l10n::S::ResetCache);
        bc->onClick = [] {
            if (!dialogs::Confirm(MainWindow::Instance().Hwnd(),
                                  l10n::t(l10n::S::ResetCacheTitle),
                                  l10n::t(l10n::S::ResetCacheText)))
                return;
            const bool any = legacy::ResetTrayCache();
            log::Event(any ? L"legacy tray cache reset" : L"legacy tray cache: nothing to reset");
        };
        btnCache = bc.get();
        widgets.push_back(std::move(bc));

        auto ea = std::make_unique<SearchBox>();
        ea->Create(hwnd);
        exclAdd = ea.get();
        widgets.push_back(std::move(ea));

        auto ba = std::make_unique<Button>();
        ba->style = Button::Style::Accent;
        ba->glyph = 0xE710;
        ba->label = l10n::t(l10n::S::Add);
        ba->onClick = [this] {
            const std::wstring pat = str::Trim(exclAdd ? exclAdd->Text() : L"");
            if (pat.empty()) return;
            auto& ex = settings::Get().exclusions;
            if (std::find(ex.begin(), ex.end(), pat) == ex.end()) ex.push_back(pat);
            settings::Save();
            if (exclAdd) exclAdd->SetText(L"");
            store::Rescan();
            MainWindow::Instance().NotifyDataChanged();
        };
        btnAdd = ba.get();
        widgets.push_back(std::move(ba));

        auto br = std::make_unique<Button>();
        br->style = Button::Style::Danger;
        br->glyph = 0xE74D;
        br->label = l10n::t(l10n::S::Remove);
        br->onClick = [this] {
            auto& ex = settings::Get().exclusions;
            if (exclSelected >= 0 && exclSelected < static_cast<int>(ex.size())) {
                ex.erase(ex.begin() + exclSelected);
                exclSelected = -1;
                settings::Save();
                store::Rescan();
                MainWindow::Instance().NotifyDataChanged();
            }
        };
        btnRemove = br.get();
        widgets.push_back(std::move(br));
    }

    Segmented* AddSeg(std::vector<int> values, int current, std::function<void(int)> apply) {
        auto seg = std::make_unique<Segmented>();
        for (int v : values) {
            Segmented::Item it;
            it.label = v == 0 ? l10n::t(l10n::S::PollOff)
                              : (v < 1000 ? str::Format(l10n::t(l10n::S::MsFmt), v)
                                          : str::Format(L"%d s", v / 1000));
            it.glyph = 0;
            seg->items.push_back(it);
        }
        int idx = 0;
        for (size_t i = 0; i < values.size(); ++i)
            if (values[i] == current) idx = static_cast<int>(i);
        seg->selected = idx;
        seg->selAnim = static_cast<float>(idx);
        seg->onChange = [values, apply](int i) {
            if (i >= 0 && i < static_cast<int>(values.size())) apply(values[i]);
        };
        Segmented* raw = seg.get();
        widgets.push_back(std::move(seg));
        return raw;
    }

    void Refresh() override {
        Page::Refresh();
        if (btnSca) btnSca->label = l10n::t(l10n::S::RemoveSca);
        if (btnCache) btnCache->label = l10n::t(l10n::S::ResetCache);
        if (btnAdd) btnAdd->label = l10n::t(l10n::S::Add);
        if (btnRemove) btnRemove->label = l10n::t(l10n::S::Remove);
        if (exclAdd) exclAdd->Refresh();
    }

    void OnShow(HWND) override {
        if (tgRun) tgRun->on = guard::GetStats().running;
    }

    void LayoutContent(HWND hwnd, int width) override {
        const int pad = 28;
        const int W = width - pad * 2;
        int y = 12;
        // watcher card: 5 rows
        const int watcherH = 40 + kRowH * 5;
        RECT watcher{pad, y, pad + W, y + watcherH};
        y += watcherH + 12;
        // repairs card: toggle row + buttons row
        const int repairsH = 40 + kRowH + 52;
        RECT repairs{pad, y, pad + W, y + repairsH};
        y += repairsH + 12;
        // stats card
        const int statsH = 40 + 64;
        RECT stats{pad, y, pad + W, y + statsH};
        y += statsH + 12;
        // exclusions card
        const int exclRows = static_cast<int>(settings::Get().exclusions.size());
        const int listH = exclRows ? exclRows * 32 + 8 : 40;
        const int exclH = 40 + 44 + listH + 8;
        RECT excl{pad, y, pad + W, y + exclH};
        y += exclH + 16;

        // place widgets inside watcher card
        int ry = watcher.top + 40;
        RECT row{watcher.left, ry, watcher.right, ry + kRowH};
        tgRun->Layout({row.left, row.top, row.right - 16, row.bottom});
        ry += kRowH;
        row = {watcher.left, ry, watcher.right, ry + kRowH};
        segDebounce->Layout({row.right - 16 - segDebounce->PreferredWidth(hwnd), row.top + 10,
                             row.right - 16, row.top + 42});
        ry += kRowH;
        row = {watcher.left, ry, watcher.right, ry + kRowH};
        segPoll->Layout({row.right - 16 - segPoll->PreferredWidth(hwnd), row.top + 10,
                         row.right - 16, row.top + 42});
        ry += kRowH;
        row = {watcher.left, ry, watcher.right, ry + kRowH};
        tgAutoRestart->Layout({row.left, row.top, row.right - 16, row.bottom});
        segCooldown->Layout({row.right - 16 - segCooldown->PreferredWidth(hwnd) - 60,
                             row.top + 10, row.right - 76, row.top + 42});
        ry += kRowH;
        row = {watcher.left, ry, watcher.right, ry + kRowH};
        tgBalloons->Layout({row.left, row.top, row.right - 16, row.bottom});

        // repairs
        ry = repairs.top + 40;
        tgLegacyBelt->Layout({repairs.left, ry, repairs.right - 16, ry + kRowH});
        ry += kRowH;
        const int bwS = btnSca->PreferredWidth(hwnd);
        const int bwC = btnCache->PreferredWidth(hwnd);
        btnSca->Layout({repairs.left + 16, ry + 8, repairs.left + 16 + bwS, ry + 40});
        btnCache->Layout({btnSca->rc.right + 8, ry + 8, btnSca->rc.right + 8 + bwC, ry + 40});

        // exclusions controls
        const int addW = btnAdd->PreferredWidth(hwnd);
        const int remW = btnRemove->PreferredWidth(hwnd);
        exclAdd->Layout({excl.left + 16, excl.top + 40, excl.left + 16 + 320, excl.top + 76});
        btnAdd->Layout({exclAdd->rc.right + 8, excl.top + 40, exclAdd->rc.right + 8 + addW,
                        excl.top + 76});
        btnRemove->Layout({btnAdd->rc.right + 8, excl.top + 40, btnAdd->rc.right + 8 + remW,
                           excl.top + 76});

        geoWatcher = ToWindow(watcher);
        geoRepairs = ToWindow(repairs);
        geoStats = ToWindow(stats);
        geoExcl = ToWindow(excl);
        exclListTop = geoExcl.top + 84;
        contentH = y;
    }

    bool OnMouseRowSelect(POINT p) {
        if (!PtInRect(&geoExcl, p)) return false;
        if (p.y < exclListTop) return false;
        const int idx = (p.y - exclListTop) / 32;
        const auto& ex = settings::Get().exclusions;
        if (idx >= 0 && idx < static_cast<int>(ex.size())) {
            exclSelected = idx == exclSelected ? -1 : idx;
            return true;
        }
        return false;
    }

    void PaintBackground(PaintCtx& pc) override {
        DrawCard(pc, geoWatcher, l10n::t(l10n::S::CardWatcher));
        DrawCard(pc, geoRepairs, l10n::t(l10n::S::CardRepairs));
        DrawCard(pc, geoStats, l10n::t(l10n::S::CardStats));
        DrawCard(pc, geoExcl, l10n::t(l10n::S::CardExclusions));
        // watcher rows labels
        int ry = geoWatcher.top + 40;
        DrawSettingRow(pc, {geoWatcher.left, ry, geoWatcher.right, ry + kRowH},
                       l10n::t(l10n::S::ToggleGuardRun), l10n::t(l10n::S::ToggleGuardRunDesc));
        ry += kRowH;
        DrawSettingRow(pc, {geoWatcher.left, ry, geoWatcher.right, ry + kRowH},
                       l10n::t(l10n::S::Debounce), L"");
        ry += kRowH;
        DrawSettingRow(pc, {geoWatcher.left, ry, geoWatcher.right, ry + kRowH},
                       l10n::t(l10n::S::Polling), l10n::t(l10n::S::PollingDesc));
        ry += kRowH;
        DrawSettingRow(pc, {geoWatcher.left, ry, geoWatcher.right, ry + kRowH},
                       l10n::t(l10n::S::AutoRestartExp), l10n::t(l10n::S::AutoRestartExpDesc));
        ry += kRowH;
        DrawSettingRow(pc, {geoWatcher.left, ry, geoWatcher.right, ry + kRowH},
                       l10n::t(l10n::S::Balloons), l10n::t(l10n::S::BalloonsDesc), true);

        ry = geoRepairs.top + 40;
        DrawSettingRow(pc, {geoRepairs.left, ry, geoRepairs.right, ry + kRowH},
                       l10n::t(l10n::S::LegacyBelt), l10n::t(l10n::S::LegacyBeltDesc));
    }

    void Paint(PaintCtx& pc) override {
        Page::Paint(pc);
        const Palette& P = theme::Pal();
        const HWND hwnd = hwndRef;
        // stats (foreground text over card)
        const guard::Stats gs = guard::GetStats();
        const ULONGLONG upMs = gs.running ? GetTickCount64() - 0 : 0;
        (void)upMs;
        const struct {
            const wchar_t* k;
            std::wstring v;
        } st[4] = {
            {l10n::t(l10n::S::StatPasses), str::Format(L"%llu", gs.passes)},
            {l10n::t(l10n::S::StatPromotions), str::Format(L"%llu", gs.promotionsSession)},
            {l10n::t(l10n::S::StatLastFix),
             gs.lastEventValid ? str::Format(L"%02d:%02d:%02d", gs.lastEventTime.wHour,
                                             gs.lastEventTime.wMinute, gs.lastEventTime.wSecond)
                               : l10n::t(l10n::S::StatNone)},
            {l10n::t(l10n::S::StatUptime), UptimeText()},
        };
        const int colW = (geoStats.right - geoStats.left - 32) / 4;
        for (int i = 0; i < 4; ++i) {
            const float x = static_cast<float>(geoStats.left + 16 + i * colW);
            Gdiplus::RectF vr(x, geoStats.top + 44.f, static_cast<float>(colW) - 12.f, 26.f);
            gfx::DrawString(pc.g, st[i].v, gfx::Font(hwnd, 18.f, FontStyle::SemiBold), vr,
                            gfx::C(P.textPrimary), Gdiplus::StringAlignmentNear);
            Gdiplus::RectF kr(x, vr.GetBottom(), static_cast<float>(colW) - 12.f, 18.f);
            gfx::DrawString(pc.g, st[i].k, gfx::Font(hwnd, 11.f), kr, gfx::C(P.textSecondary),
                            Gdiplus::StringAlignmentNear);
        }

        Gdiplus::RectF dr(geoExcl.left + 16.f, geoExcl.top + 40.f - 26.f,
                          static_cast<float>(geoExcl.right - geoExcl.left) - 32.f, 18.f);
        gfx::DrawString(pc.g, l10n::t(l10n::S::ExclDesc), gfx::Font(hwnd, 11.5f), dr,
                        gfx::C(P.textSecondary));
        const auto& ex = settings::Get().exclusions;
        if (ex.empty()) {
            Gdiplus::RectF er(geoExcl.left + 16.f, static_cast<float>(exclListTop) + 8.f,
                              static_cast<float>(geoExcl.right - geoExcl.left) - 32.f, 20.f);
            gfx::DrawString(pc.g, l10n::t(l10n::S::ExclEmpty), gfx::Font(hwnd, 12.f), er,
                            gfx::C(P.textDisabled));
        } else {
            int ey = exclListTop;
            for (size_t i = 0; i < ex.size(); ++i) {
                RECT rr{geoExcl.left + 16, ey, geoExcl.right - 16, ey + 28};
                if (static_cast<int>(i) == exclSelected)
                    gfx::FillRoundRect(pc.g, gfx::RectFOf(rr), 4.f, gfx::C(P.accentSoft));
                Gdiplus::RectF tr(rr.left + 10.f, static_cast<float>(rr.top),
                                  static_cast<float>(rr.right - rr.left) - 20.f, 28.f);
                gfx::DrawString(pc.g, ex[i], gfx::MonoFont(hwnd, 12.f), tr,
                                gfx::C(static_cast<int>(i) == exclSelected ? P.accent
                                                                           : P.textPrimary),
                                Gdiplus::StringAlignmentNear);
                ey += 32;
            }
        }
    }

    std::wstring UptimeText() const {
        const guard::Stats gs = guard::GetStats();
        if (!gs.running || !gs.startTick) return l10n::t(l10n::S::StatNone);
        const ULONGLONG sec = (GetTickCount64() - gs.startTick) / 1000;
        return str::Format(L"%02llu:%02llu:%02llu", sec / 3600, (sec / 60) % 60, sec % 60);
    }

    bool OnBackgroundClick(POINT p) override {
        if (OnMouseRowSelect(p)) {
            InvalidateRect(hwndRef, nullptr, FALSE);
            return true;
        }
        return false;
    }

    RECT geoWatcher{}, geoRepairs{}, geoStats{}, geoExcl{};
    int exclListTop = 0;
    ULONGLONG startTickPage = 0;

    void OnSecondTick() override {
        if (!startTickPage) startTickPage = GetTickCount64();
        InvalidateRect(hwndRef, &geoStats, FALSE);
    }
};

}  // namespace

std::unique_ptr<Page> MakeGuardPage() { return std::make_unique<GuardPage>(); }

}  // namespace tig::ui
