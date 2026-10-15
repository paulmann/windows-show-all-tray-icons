// TrayIconGuard v8 — Backups page: snapshot list with restore/delete/export.
#include <windows.h>
#include <shellapi.h>

#include "core/backup.h"
#include "core/log.h"
#include "core/settings.h"
#include "core/trayicons.h"
#include "pages.h"
#include "ui/theme.h"
#include "util/fs.h"
#include "util/str.h"

namespace tig::ui {

namespace {
constexpr int kRowH = 44;

class BackupsPage : public Page {
public:
    l10n::S TitleId() const override { return l10n::S::BackTitle; }
    l10n::S SubId() const override { return l10n::S::BackSub; }
    wchar_t Glyph() const override { return 0xE74E; }

    Toggle* tgAuto = nullptr;
    Button* btnCreate = nullptr;
    Button* btnLatest = nullptr;
    Button* btnFolder = nullptr;
    std::vector<backup::Info> items;
    int scrollList = 0;
    int hoverIdx = -1;
    RECT listRc{};
    ScrollBar sbar;

    void Build(HWND) override {
        auto ta = std::make_unique<Toggle>();
        ta->on = settings::Get().autoBackup;
        ta->onChange = [](bool v) {
            settings::Get().autoBackup = v;
            settings::Save();
        };
        tgAuto = ta.get();
        widgets.push_back(std::move(ta));

        auto bc = std::make_unique<Button>();
        bc->style = Button::Style::Accent;
        bc->glyph = 0xE74E;
        bc->label = l10n::t(l10n::S::CreateSnapshot);
        bc->onClick = [this] {
            std::wstring path, err;
            const bool ok = backup::Create(path, err, L"manual");
            log::Info(ok ? L"snapshot created from UI" : L"snapshot failed: " + err);
            Reload();
        };
        btnCreate = bc.get();
        widgets.push_back(std::move(bc));

        auto bl = std::make_unique<Button>();
        bl->style = Button::Style::Outline;
        bl->glyph = 0xE823;
        bl->label = l10n::t(l10n::S::RestoreLatest);
        bl->onClick = [this] {
            if (items.empty()) return;
            DoRestore(items.front().fileName);
        };
        btnLatest = bl.get();
        widgets.push_back(std::move(bl));

        auto bf = std::make_unique<Button>();
        bf->style = Button::Style::Subtle;
        bf->glyph = 0xE838;
        bf->label = l10n::t(l10n::S::OpenFolder);
        bf->onClick = [] {
            ShellExecuteW(nullptr, L"open", fs::BackupsDir().c_str(), nullptr, nullptr,
                          SW_SHOWNORMAL);
        };
        btnFolder = bf.get();
        widgets.push_back(std::move(bf));
        Reload();
    }

    void Reload() {
        items = backup::List();
        if (hwndRef) InvalidateRect(hwndRef, nullptr, FALSE);
    }

    void OnShow(HWND) override { Reload(); }
    void OnDataChanged() override { Reload(); }

    void Refresh() override {
        Page::Refresh();
        if (btnCreate) btnCreate->label = l10n::t(l10n::S::CreateSnapshot);
        if (btnLatest) btnLatest->label = l10n::t(l10n::S::RestoreLatest);
        if (btnFolder) btnFolder->label = l10n::t(l10n::S::OpenFolder);
    }

    void DoRestore(const std::wstring& fileName) {
        if (!dialogs::Confirm(hwndRef, l10n::t(l10n::S::RestoreTitle),
                              l10n::t(l10n::S::RestoreText)))
            return;
        std::wstring err;
        const int applied = backup::Restore(fileName, err);
        store::Rescan();
        MainWindow::Instance().NotifyDataChanged();
        log::Event(str::Format(L"snapshot %s restored (%d)", fileName.c_str(), applied));
    }

    void LayoutContent(HWND hwnd, int width) override {
        const int pad = 28;
        const int W = width - pad * 2;
        int y = 12;
        const int optH = 40 + 56 + 52;
        RECT opt{pad, y, pad + W, y + optH};
        y += optH + 12;
        const int listH = Height() > 0 ? (Height() - 12) - y : 300;
        listRc = ToWindow(RECT{pad, y, pad + W, y + (listH > 80 ? listH : 300)});
        y = listRc.bottom + 16;

        tgAuto->Layout({opt.left, opt.top + 40, opt.right - 16, opt.top + 40 + 56});
        const int bw1 = btnCreate->PreferredWidth(hwnd);
        const int bw2 = btnLatest->PreferredWidth(hwnd);
        const int bw3 = btnFolder->PreferredWidth(hwnd);
        btnCreate->Layout({opt.left + 16, opt.top + 40 + 56 + 4, opt.left + 16 + bw1,
                           opt.top + 40 + 56 + 36});
        btnLatest->Layout({btnCreate->rc.right + 8, btnCreate->rc.top, btnCreate->rc.right + 8 + bw2,
                           btnCreate->rc.bottom});
        btnFolder->Layout({btnLatest->rc.right + 8, btnCreate->rc.top, btnLatest->rc.right + 8 + bw3,
                           btnCreate->rc.bottom});
        geoOpt = ToWindow(opt);
        const int content = static_cast<int>(items.size()) * kRowH;
        sbar.SetRange(content, listRc.bottom - listRc.top - 2);
        sbar.pos = scrollList;
        contentH = Height();  // no page scroll
    }

    bool Wheel(HWND hwnd, int delta) override {
        if (!sbar.Needed()) return false;
        const int before = sbar.pos;
        sbar.ScrollBy(-delta / 120 * 60);
        scrollList = sbar.pos;
        if (sbar.pos != before) {
            InvalidateRect(hwnd, nullptr, FALSE);
            return true;
        }
        return false;
    }

    int RowAt(POINT p) const {
        if (!PtInRect(&listRc, p)) return -1;
        const int idx = (p.y - listRc.top - 1 + scrollList) / kRowH;
        return idx >= 0 && idx < static_cast<int>(items.size()) ? idx : -1;
    }

    RECT ActionRect(int idx, int which) const {
        const int y = listRc.top + 1 + idx * kRowH - scrollList;
        const int w = 76;
        const int x0 = listRc.right - 12 - w * 3 - 16;
        return {x0 + which * w, y + 8, x0 + which * w + w - 6, y + kRowH - 8};
    }

    bool OnBackgroundClick(POINT p) override {
        const int idx = RowAt(p);
        if (idx < 0) return false;
        for (int which = 0; which < 3; ++which) {
            const RECT ar = ActionRect(idx, which);
            if (PtInRect(&ar, p)) {
                const backup::Info& it = items[idx];
                if (which == 0) {
                    DoRestore(it.fileName);
                } else if (which == 1) {
                    if (dialogs::Confirm(hwndRef, l10n::t(l10n::S::DeleteTitle),
                                         l10n::t(l10n::S::DeleteText))) {
                        backup::Remove(it.fileName);
                        Reload();
                    }
                } else {
                    std::wstring dest;
                    if (dialogs::SaveFile(hwndRef, it.fileName.c_str(),
                                          L"JSON\0*.json\0All files\0*.*\0", dest)) {
                        std::wstring err;
                        backup::Export(it.fileName, dest, err);
                    }
                }
                return true;
            }
        }
        return false;
    }

    void PaintBackground(PaintCtx& pc) override {
        DrawCard(pc, geoOpt, l10n::t(l10n::S::BackSub));
        DrawSettingRow(pc, {geoOpt.left, geoOpt.top + 40, geoOpt.right, geoOpt.top + 96},
                       l10n::t(l10n::S::AutoBackup), l10n::t(l10n::S::AutoBackupDesc), true);
    }

    void Paint(PaintCtx& pc) override {
        Page::Paint(pc);
        const Palette& P = theme::Pal();
        const HWND hwnd = hwndRef;
        // list card
        gfx::FillRoundRect(pc.g, gfx::RectFOf(listRc), 8.f, gfx::C(P.cardBg));
        gfx::StrokeRoundRect(pc.g, gfx::RectFOf(listRc), 8.f, gfx::C(P.cardBorder), 1.f);
        Gdiplus::GraphicsState st = pc.g.Save();
        pc.g.SetClip(gfx::RectFOf(listRc));
        if (items.empty()) {
            Gdiplus::RectF er(listRc.left + 16.f, listRc.top + 20.f,
                              static_cast<float>(listRc.right - listRc.left) - 32.f, 20.f);
            gfx::DrawString(pc.g, l10n::t(l10n::S::EmptyBackups), gfx::Font(hwnd, 12.5f), er,
                            gfx::C(P.textDisabled));
        }
        const int first = scrollList / kRowH;
        const int last = std::min<int>(static_cast<int>(items.size()) - 1,
                                       (scrollList + (listRc.bottom - listRc.top)) / kRowH);
        for (int i = first; i <= last; ++i) {
            const backup::Info& it = items[i];
            const int y = listRc.top + 1 + i * kRowH - scrollList;
            if (i == hoverIdx)
                gfx::FillRect(pc.g, Gdiplus::RectF(static_cast<float>(listRc.left) + 1,
                                                   static_cast<float>(y),
                                                   static_cast<float>(listRc.right - listRc.left) - 2,
                                                   static_cast<float>(kRowH)),
                              gfx::C(P.hoverOverlay, 140));
            Gdiplus::RectF nr(listRc.left + 16.f, static_cast<float>(y + 5), 300.f, 20.f);
            gfx::DrawString(pc.g, it.fileName, gfx::MonoFont(hwnd, 12.f), nr,
                            gfx::C(P.textPrimary), Gdiplus::StringAlignmentNear);
            Gdiplus::RectF dr(listRc.left + 330.f, static_cast<float>(y + 6), 150.f, 18.f);
            gfx::DrawString(pc.g, fs::FormatFileTime(it.writeTime), gfx::Font(hwnd, 11.5f), dr,
                            gfx::C(P.textSecondary), Gdiplus::StringAlignmentNear);
            Gdiplus::RectF cr(listRc.left + 490.f, static_cast<float>(y + 6), 120.f, 18.f);
            gfx::DrawString(pc.g,
                            it.iconCount >= 0
                                ? str::Format(L"%d (%d \u2191)", it.iconCount, it.promoted)
                                : std::wstring(L"—"),
                            gfx::Font(hwnd, 11.5f), cr, gfx::C(P.textSecondary),
                            Gdiplus::StringAlignmentNear);
            const wchar_t* acts[3] = {l10n::t(l10n::S::Restore), l10n::t(l10n::S::Delete),
                                      l10n::t(l10n::S::Export)};
            for (int which = 0; which < 3; ++which) {
                const RECT ar = ActionRect(i, which);
                const bool hotAct = hoverIdx == i && false;
                (void)hotAct;
                const COLORREF fg = which == 1 ? P.danger : P.accent;
                Gdiplus::RectF arf = gfx::RectFOf(ar);
                gfx::FillRoundRect(pc.g, arf, 4.f,
                                   gfx::C(theme::Mix(P.cardBg, P.controlHover, 0.5)));
                gfx::DrawString(pc.g, acts[which], gfx::Font(hwnd, 11.5f, FontStyle::Medium),
                                arf, gfx::C(fg), Gdiplus::StringAlignmentCenter);
            }
            Gdiplus::RectF sep(listRc.left + 12.f, static_cast<float>(y + kRowH) - 1.f,
                               static_cast<float>(listRc.right - listRc.left) - 24.f, 1.f);
            gfx::FillRect(pc.g, sep, gfx::C(P.separator, 120));
        }
        pc.g.Restore(st);
        sbar.rc = {listRc.right - 10, listRc.top + 4, listRc.right - 3, listRc.bottom - 4};
        sbar.Paint(pc);
    }

    RECT geoOpt{};
};

}  // namespace

std::unique_ptr<Page> MakeBackupsPage() { return std::make_unique<BackupsPage>(); }

}  // namespace tig::ui
