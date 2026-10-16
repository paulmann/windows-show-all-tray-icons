// TrayIconGuard v8 — Tray icons page: search, filters, per-icon toggles,
// context menu, promote-all / restore-defaults.
#include <windows.h>
#include <shellapi.h>

#include <algorithm>

#include "core/backup.h"
#include "core/guard.h"
#include "core/legacy.h"
#include "core/os.h"
#include "core/log.h"
#include "core/settings.h"
#include "core/trayicons.h"
#include "pages.h"
#include "ui/theme.h"
#include "util/str.h"

namespace tig::ui {

namespace {

void CopyToClipboard(HWND hwnd, const std::wstring& text) {
    if (!OpenClipboard(hwnd)) return;
    EmptyClipboard();
    const HGLOBAL h = GlobalAlloc(GMEM_MOVEABLE, (text.size() + 1) * sizeof(wchar_t));
    if (h) {
        auto* p = static_cast<wchar_t*>(GlobalLock(h));
        if (p) {
            wcscpy_s(p, text.size() + 1, text.c_str());
            GlobalUnlock(h);
            SetClipboardData(CF_UNICODETEXT, h);
        }
    }
    CloseClipboard();
}

class IconList : public Widget {
public:
    std::vector<TrayIconEntry> view;
    int scroll = 0;
    int hoverIdx = -1;
    int dragIdx = -1;        // row being dragged
    int dragOverIdx = -1;    // insertion index while dragging
    bool suppressClick = false;
    ScrollBar sbar;
    std::function<void()> onChanged;   // repaint only (hover/scroll)
    std::function<void()> onData;      // store/order changed: resync view + repaint

    int RowH(HWND h) const {
        const int base = settings::Get().compactRows ? 40 : 56;
        return base * os::DpiFor(h) / 96;
    }

    void Resync(const std::wstring& query, int filter) {
        view.clear();
        const std::wstring q = str::ToLower(str::Trim(query));
        (void)q;
        for (const auto& e : store::Current()) {
            if (filter == 1 && !e.promoted) continue;
            if (filter == 2 && e.promoted) continue;
            if (filter == 3 && !e.excluded) continue;
            if (!q.empty()) {
                const std::wstring hay = str::ToLower(e.friendly + L" " + e.exePath + L" " + e.id);
                if (hay.find(q) == std::wstring::npos) continue;
            }
            view.push_back(e);
        }
        // apply user drag-order: ordered ids first, then alphabetical remainder
        const auto& order = settings::Get().iconsOrder;
        std::stable_sort(view.begin(), view.end(),
                         [&order](const TrayIconEntry& a, const TrayIconEntry& b) {
                             auto pos = [&order](const std::wstring& id) {
                                 for (size_t i = 0; i < order.size(); ++i)
                                     if (order[i] == id) return static_cast<int>(i);
                                 return INT_MAX;
                             };
                             const int pa = pos(a.id), pb = pos(b.id);
                             if (pa != pb) return pa < pb;
                             return false;  // keep alphabetical from Rescan
                         });
        if (hoverIdx >= static_cast<int>(view.size())) hoverIdx = -1;
    }

    void CommitDrag() {
        if (dragIdx < 0 || dragOverIdx < 0 || dragIdx >= static_cast<int>(view.size())) {
            dragIdx = dragOverIdx = -1;
            return;
        }
        int target = dragOverIdx;
        std::vector<std::wstring> ids;
        for (const auto& e : view) ids.push_back(e.id);
        const std::wstring moved = ids[dragIdx];
        ids.erase(ids.begin() + dragIdx);
        if (target > dragIdx) --target;
        if (target < 0) target = 0;
        if (target > static_cast<int>(ids.size())) target = static_cast<int>(ids.size());
        ids.insert(ids.begin() + target, moved);
        // merge: view order first, then previously-ordered ids absent from the view
        auto& order = settings::Get().iconsOrder;
        std::vector<std::wstring> merged = ids;
        for (const auto& old : order) {
            if (std::find(merged.begin(), merged.end(), old) == merged.end()) {
                bool inView = false;
                for (const auto& e : view)
                    if (e.id == old) inView = true;
                if (!inView) merged.push_back(old);
            }
        }
        order = merged;
        settings::Save();
        log::Info(L"icon order updated by user");
        dragIdx = dragOverIdx = -1;
    }

    int IdxAt(HWND h, POINT p) const {
        if (!PtInRect(&rc, p)) return -1;
        const int rh = RowH(h);
        const int idx = (p.y - rc.top + scroll) / rh;
        if (idx < 0 || idx >= static_cast<int>(view.size())) return -1;
        return idx;
    }

    RECT ToggleRect(HWND h, int idx) const {
        const int rh = RowH(h);
        const int y = rc.top + idx * rh - scroll;
        const int tw = 40 * os::DpiFor(h) / 96;
        return {rc.right - 16 - tw, y + (rh - 20 * os::DpiFor(h) / 96) / 2,
                rc.right - 16, y + (rh - 20 * os::DpiFor(h) / 96) / 2 + 20 * os::DpiFor(h) / 96};
    }

    void Paint(PaintCtx& pc) override {
        const Palette& P = theme::Pal();
        const HWND h = pc.hwnd;
        const int rh = RowH(h);
        gfx::FillRoundRect(pc.g, gfx::RectFOf(rc), 8.f, gfx::C(P.cardBg));
        gfx::StrokeRoundRect(pc.g, gfx::RectFOf(rc), 8.f, gfx::C(P.cardBorder), 1.f);
        Gdiplus::GraphicsState st = pc.g.Save();
        pc.g.SetClip(gfx::RectFOf(rc));
        if (view.empty()) {
            Gdiplus::RectF er(rc.left + 20.f, rc.top + 24.f,
                              static_cast<float>(Width()) - 40.f, 20.f);
            gfx::DrawString(pc.g, l10n::t(l10n::S::EmptyIcons), gfx::Font(h, 12.5f), er,
                            gfx::C(P.textDisabled));
        }
        const int first = scroll / rh;
        const int last = std::min<int>(static_cast<int>(view.size()) - 1,
                                       (scroll + Height()) / rh);
        for (int i = first; i <= last; ++i) {
            const TrayIconEntry& e = view[i];
            const int y = rc.top + i * rh - scroll;
            RECT rowRc{rc.left + 1, y, rc.right - 1, y + rh};
            if (i == hoverIdx)
                gfx::FillRect(pc.g, gfx::RectFOf(rowRc), gfx::C(P.hoverOverlay, 140));
            if (i == dragIdx && dragIdx >= 0)
                gfx::FillRect(pc.g, gfx::RectFOf(rowRc), gfx::C(P.accentSoft, 160));
            // icon
            const int isz = settings::Get().compactRows ? 20 : 24;
            HICON hi = store::IconFor(e.exePath);
            if (hi)
                gfx::DrawIcon(pc.g, hi, Gdiplus::RectF(rc.left + 16.f, y + (rh - isz) * 0.5f,
                                                       static_cast<float>(isz),
                                                       static_cast<float>(isz)));
            else {
                Gdiplus::RectF ph(rc.left + 16.f, y + (rh - isz) * 0.5f, static_cast<float>(isz),
                                  static_cast<float>(isz));
                gfx::FillRoundRect(pc.g, ph, 4.f, gfx::C(P.controlPressed));
            }
            // texts
            const float tx = rc.left + 16.f + isz + 12.f;
            if (settings::Get().compactRows) {
                Gdiplus::RectF nr(tx, static_cast<float>(y), rc.right - tx - 260.f,
                                  static_cast<float>(rh));
                gfx::DrawString(pc.g, e.friendly, gfx::Font(h, 13.f, FontStyle::Medium), nr,
                                gfx::C(P.textPrimary));
            } else {
                Gdiplus::RectF nr(tx, static_cast<float>(y + 7), rc.right - tx - 260.f, 20.f);
                gfx::DrawString(pc.g, e.friendly, gfx::Font(h, 13.5f, FontStyle::Medium), nr,
                                gfx::C(P.textPrimary));
                Gdiplus::RectF pr(tx, static_cast<float>(y + 27), rc.right - tx - 260.f, 18.f);
                gfx::DrawString(pc.g, e.exePath.empty() ? e.id : e.exePath,
                                gfx::Font(h, 11.f), pr, gfx::C(P.textSecondary));
            }
            // chip
            const wchar_t* chipTxt = e.excluded      ? l10n::t(l10n::S::FilterExcluded)
                                     : e.promoted    ? l10n::t(l10n::S::FilterPromoted)
                                                     : l10n::t(l10n::S::FilterHidden);
            const COLORREF chipFg = e.excluded      ? P.textSecondary
                                    : e.promoted    ? P.success
                                                    : P.warning;
            const COLORREF chipBg = e.excluded      ? P.hoverOverlay
                                    : e.promoted    ? P.successSoft
                                                    : P.warningSoft;
            const float chipW = gfx::TextWidth(h, chipTxt, 10.5f, FontStyle::Medium) + 20.f;
            RECT chipRc{static_cast<int>(rc.right - 76 - chipW), y + (rh - 22) / 2,
                        static_cast<int>(rc.right - 76), y + (rh - 22) / 2 + 22};
            DrawStatusChip(pc, chipRc, chipTxt, chipFg, chipBg);
            // toggle
            const RECT tr = ToggleRect(h, i);
            const float s = static_cast<float>(os::DpiFor(h)) / 96.f;
            Gdiplus::RectF track = gfx::RectFOf(tr);
            const Gdiplus::Color onC = gfx::C(P.accent);
            const Gdiplus::Color offC = gfx::C(P.toggleOff);  // dark orange
            const bool on = e.promoted && !e.excluded;
            gfx::FillRoundRect(pc.g, track, track.Height * 0.5f, on ? onC : offC);
            const float kd = (on ? 14.f : 12.f) * s;
            const float kx = on ? track.GetRight() - 3.f * s - kd : track.X + 3.f * s;
            gfx::FillRoundRect(pc.g, Gdiplus::RectF(kx, track.Y + (track.Height - kd) * 0.5f, kd, kd),
                               kd * 0.5f, gfx::C(P.knobOff));
            if (i + 1 < static_cast<int>(view.size())) {
                Gdiplus::RectF sep(rc.left + 16.f, static_cast<float>(rowRc.bottom) - 1.f,
                                   static_cast<float>(rc.right - rc.left) - 32.f, 1.f);
                gfx::FillRect(pc.g, sep, gfx::C(P.separator, 120));
            }
        }
        if (dragIdx >= 0 && dragOverIdx >= 0) {
            const int lineY = rc.top + std::min<int>(dragOverIdx, (int)view.size()) * rh - scroll;
            gfx::FillRoundRect(pc.g, Gdiplus::RectF(rc.left + 12.f, static_cast<float>(lineY) - 1.f,
                                                    static_cast<float>(Width()) - 24.f, 3.f),
                               1.5f, gfx::C(P.accent));
        }
        pc.g.Restore(st);
        sbar.rc = {rc.right - 10, rc.top + 4, rc.right - 3, rc.bottom - 4};
        sbar.Paint(pc);
    }

    bool HitTest(POINT p) const override { return Widget::HitTest(p); }

    bool OnMouse(ME e, POINT p) override {
        switch (e) {
            case ME::Move: {
                const int idx = IdxAt(hwndCached, p);
                if (idx != hoverIdx) {
                    hoverIdx = idx;
                    if (onChanged) onChanged();
                }
                if (dragIdx >= 0) {
                    if (idx != dragOverIdx && idx >= 0) suppressClick = true;
                    if (idx >= 0) dragOverIdx = idx;
                    if (onChanged) onChanged();
                }
                if (sbar.Needed()) sbar.OnMouse(ME::Move, p);
                return true;
            }
            case ME::Leave:
                hoverIdx = -1;
                if (onChanged) onChanged();
                return true;
            case ME::Down:
                if (sbar.Needed() && sbar.HitTest(p)) return sbar.OnMouse(e, p);
                dragIdx = IdxAt(hwndCached, p);
                dragOverIdx = dragIdx;
                suppressClick = false;
                return true;
            case ME::Up:
                if (sbar.Needed()) sbar.OnMouse(e, p);
                if (dragIdx >= 0) {
                    const bool moved = dragOverIdx != dragIdx;
                    CommitDrag();
                    dragIdx = -1;
                    if (moved) {
                        if (onData) onData();  // reorder must be visible immediately (8.6)
                        else if (onChanged) onChanged();
                    } else if (onChanged) {
                        onChanged();
                    }
                }
                return true;
            case ME::Click: {
                if (suppressClick) { suppressClick = false; return true; }
                if (sbar.Needed() && sbar.HitTest(p)) return sbar.OnMouse(e, p);
                const int idx = IdxAt(hwndCached, p);
                if (idx < 0) return true;
                const RECT tr = ToggleRect(hwndCached, idx);
                const TrayIconEntry& en = view[idx];
                if (!PtInRect(&tr, p)) return true;
                if (en.excluded) return true;  // excluded icons are user-locked
                const bool nowOn = !en.promoted;
                store::SetPromoted(en.id, nowOn);
                auto& uh = settings::Get().userHidden;
                if (nowOn) {
                    uh.erase(std::remove(uh.begin(), uh.end(), en.id), uh.end());
                } else if (std::find(uh.begin(), uh.end(), en.id) == uh.end()) {
                    uh.push_back(en.id);
                }
                settings::Save();
                store::Rescan();
                log::Event(str::Format(L"user %s: %s", nowOn ? L"promoted" : L"hid",
                                       en.friendly.c_str()));
                if (onData) onData();  // view must pick up the new promoted state (8.6)
                else if (onChanged) onChanged();
                return true;
            }
            default:
                return Widget::OnMouse(e, p);
        }
    }

    bool Wheel(int delta) {
        if (!sbar.Needed()) return false;
        const int before = sbar.pos;
        sbar.ScrollBy(-delta / 120 * 60);
        scroll = sbar.pos;
        return sbar.pos != before;
    }

    void SyncScroll(HWND h) {
        const int content = static_cast<int>(view.size()) * RowH(h);
        sbar.SetRange(content, Height());
        scroll = sbar.pos;
    }

    HWND hwndCached = nullptr;
};

class IconsPage : public Page {
public:
    l10n::S TitleId() const override { return l10n::S::IconsTitle; }
    l10n::S SubId() const override { return l10n::S::IconsSub; }
    wchar_t Glyph() const override { return 0xE71D; }

    SearchBox* search = nullptr;
    RECT hintRc{};
    Segmented* filter = nullptr;
    Button* promoteAll = nullptr;
    Button* restore = nullptr;
    IconList* list = nullptr;

    void Build(HWND hwnd) override {
        auto sb = std::make_unique<SearchBox>();
        sb->Create(hwnd);
        sb->onChange = [this](const std::wstring&) { Refilter(); };
        search = sb.get();
        widgets.push_back(std::move(sb));

        auto seg = std::make_unique<Segmented>();
        seg->items = {{l10n::t(l10n::S::FilterAll), 0}, {l10n::t(l10n::S::FilterPromoted), 0},
                      {l10n::t(l10n::S::FilterHidden), 0}, {l10n::t(l10n::S::FilterExcluded), 0}};
        seg->onChange = [this](int) { Refilter(); };
        filter = seg.get();
        widgets.push_back(std::move(seg));

        auto pa = std::make_unique<Button>();
        pa->style = Button::Style::Accent;
        pa->glyph = 0xE70E;
        pa->label = l10n::t(l10n::S::PromoteAll);
        pa->onClick = [] { MainWindow::Instance().PromoteAllNow(); };
        promoteAll = pa.get();
        widgets.push_back(std::move(pa));

        auto rd = std::make_unique<Button>();
        rd->style = Button::Style::Danger;
        rd->glyph = 0xE777;
        rd->label = l10n::t(l10n::S::RestoreDefaults);
        rd->onClick = [this] {
            if (!dialogs::Confirm(hwndRef, l10n::t(l10n::S::RestoreDefaultsTitle),
                                  l10n::t(l10n::S::RestoreDefaultsText)))
                return;
            if (settings::Get().autoBackup) {
                std::wstring p, e;
                backup::Create(p, e, L"auto");
            }
            store::RestoreDefaults();
            legacy::RemoveEnableAutoTray();
            MainWindow::Instance().NotifyDataChanged();
        };
        restore = rd.get();
        widgets.push_back(std::move(rd));

        auto lv = std::make_unique<IconList>();
        lv->onChanged = [this] {
            list->SyncScroll(hwndRef);
            InvalidateRect(hwndRef, nullptr, FALSE);
        };
        lv->onData = [this] { Refilter(); };
        list = lv.get();
        widgets.push_back(std::move(lv));

        Refilter();
    }

    void Paint(PaintCtx& pc) override {
        Page::Paint(pc);
        gfx::DrawString(pc.g, l10n::t(l10n::S::DragHint), gfx::Font(pc.hwnd, 10.5f),
                        gfx::RectFOf(hintRc), gfx::C(theme::Pal().textDisabled),
                        Gdiplus::StringAlignmentFar);
    }

    void Refilter() {
        if (list) {
            list->Resync(search ? search->Text() : L"", filter ? filter->selected : 0);
            if (hwndRef) {
                list->SyncScroll(hwndRef);
                InvalidateRect(hwndRef, nullptr, FALSE);
            }
        }
    }

    void OnShow(HWND) override { Refilter(); }
    void OnDataChanged() override { Refilter(); }

    void Refresh() override {
        Page::Refresh();
        if (filter) {
            filter->items[0].label = l10n::t(l10n::S::FilterAll);
            filter->items[1].label = l10n::t(l10n::S::FilterPromoted);
            filter->items[2].label = l10n::t(l10n::S::FilterHidden);
            filter->items[3].label = l10n::t(l10n::S::FilterExcluded);
        }
        if (promoteAll) promoteAll->label = l10n::t(l10n::S::PromoteAll);
        if (restore) restore->label = l10n::t(l10n::S::RestoreDefaults);
        if (search) search->Refresh();
        Refilter();
    }

    void LayoutContent(HWND hwnd, int width) override {
        const int pad = 28;
        int y = 12;
        const int barH = 36;
        search->Layout({pad, y, pad + 340, y + barH});
        const int fw = filter->PreferredWidth(hwnd);
        filter->Layout({pad + 356, y, pad + 356 + fw, y + barH});
        const int bw1 = promoteAll->PreferredWidth(hwnd);
        const int bw2 = restore->PreferredWidth(hwnd);
        // responsive toolbar: action buttons wrap to a second row when narrow (8.4.1)
        const bool twoRows = (pad + 356 + fw + 8 + bw1 + 8 + bw2) > (width - pad);
        if (twoRows) y += barH + 8;
        restore->Layout({width - pad - bw2, y, width - pad, y + barH});
        promoteAll->Layout({restore->rc.left - 8 - bw1, y, restore->rc.left - 8, y + barH});
        y += barH + 6;
        hintRc = ToWindow(RECT{pad, y, pad + width - pad * 2, y + 16});
        y += 18;
        list->hwndCached = hwnd;
        list->Layout({pad, y, pad + width - pad * 2, Height() > 0 ? Height() - 12 : y + 400});
        list->SyncScroll(hwnd);
        contentH = Height();  // no page-level scroll on this page
    }

    bool Wheel(HWND hwnd, int delta) override {
        if (list && list->Wheel(delta)) {
            InvalidateRect(hwnd, nullptr, FALSE);
            return true;
        }
        return false;
    }

    bool OnContextMenu(POINT p) override {
        if (!list) return false;
        const int idx = list->IdxAt(hwndRef, p);
        if (idx < 0) return false;
        const TrayIconEntry e = list->view[idx];
        HMENU menu = CreatePopupMenu();
        AppendMenuW(menu, MF_STRING, 1, e.promoted ? l10n::t(l10n::S::MenuHide) : l10n::t(l10n::S::MenuPromote));
        if (e.promoted) EnableMenuItem(menu, 1, MF_BYCOMMAND | (e.excluded ? MF_DISABLED : MF_ENABLED));
        AppendMenuW(menu, MF_STRING, 2,
                    e.excluded ? l10n::t(l10n::S::MenuUnexclude) : l10n::t(l10n::S::MenuExclude));
        AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
        AppendMenuW(menu, MF_STRING, 3, l10n::t(l10n::S::MenuOpenLocation));
        AppendMenuW(menu, MF_STRING, 4, l10n::t(l10n::S::MenuCopyPath));
        AppendMenuW(menu, MF_STRING, 5, l10n::t(l10n::S::MenuCopyId));
        const int cmd = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON, p.x, p.y, 0,
                                       hwndRef, nullptr);
        DestroyMenu(menu);
        switch (cmd) {
            case 1:
                if (!e.excluded) {
                    store::SetPromoted(e.id, !e.promoted);
                    store::Rescan();
                    MainWindow::Instance().NotifyDataChanged();
                }
                break;
            case 2: {
                auto& ex = settings::Get().exclusions;
                const std::wstring pattern = str::ToLower(str::FileNameOf(e.exePath));
                if (e.excluded) {
                    ex.erase(std::remove_if(ex.begin(), ex.end(),
                                            [&](const std::wstring& x) {
                                                return str::IEquals(x, pattern) ||
                                                       str::IEquals(x, e.exePath);
                                            }),
                             ex.end());
                } else if (!pattern.empty()) {
                    ex.push_back(pattern);
                }
                settings::Save();
                store::Rescan();
                MainWindow::Instance().NotifyDataChanged();
                break;
            }
            case 3:
                if (!e.exePath.empty()) {
                    SHELLEXECUTEINFOW sei{};
                    sei.cbSize = sizeof(sei);
                    sei.lpVerb = L"open";
                    sei.lpFile = L"explorer.exe";
                    const std::wstring args = L"/select,\"" + e.exePath + L"\"";
                    sei.lpParameters = args.c_str();
                    sei.nShow = SW_SHOWNORMAL;
                    ShellExecuteExW(&sei);
                }
                break;
            case 4:
                CopyToClipboard(hwndRef, e.exePath);
                break;
            case 5:
                CopyToClipboard(hwndRef, e.id);
                break;
            default:
                break;
        }
        return true;
    }
};

}  // namespace

std::unique_ptr<Page> MakeIconsPage() { return std::make_unique<IconsPage>(); }

}  // namespace tig::ui
