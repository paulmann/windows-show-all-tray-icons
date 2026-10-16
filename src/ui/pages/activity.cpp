// TrayIconGuard v8 — Activity page: live log viewer with filters and export.
#include "core/log.h"
#include "core/settings.h"
#include "pages.h"
#include "ui/theme.h"
#include "util/fs.h"
#include "util/str.h"

namespace tig::ui {

namespace {

class ActivityPage : public Page {
public:
    l10n::S TitleId() const override { return l10n::S::ActTitle; }
    l10n::S SubId() const override { return l10n::S::ActSub; }
    wchar_t Glyph() const override { return 0xE9D5; }

    Segmented* segFilter = nullptr;
    Toggle* tgFollow = nullptr;
    Button* btnExport = nullptr;
    int scrollList = 0;
    ScrollBar listBar;
    RECT listRc{};
    std::deque<log::Entry> entries;

    void Build(HWND) override {
        auto sf = std::make_unique<Segmented>();
        sf->items = {{l10n::t(l10n::S::FilterAllLv), 0}, {l10n::t(l10n::S::FilterEvents), 0},
                     {l10n::t(l10n::S::FilterIssues), 0}};
        sf->onChange = [this](int) {
            Reload();
        };
        segFilter = sf.get();
        widgets.push_back(std::move(sf));

        auto tf = std::make_unique<Toggle>();
        tf->on = true;
        tgFollow = tf.get();
        widgets.push_back(std::move(tf));

        auto be = std::make_unique<Button>();
        be->style = Button::Style::Outline;
        be->glyph = 0xE896;
        be->label = l10n::t(l10n::S::ExportLog);
        be->onClick = [this] {
            std::wstring dest;
            if (dialogs::SaveFile(hwndRef, L"TrayIconGuard-log.txt",
                                  L"Text\0*.txt\0All files\0*.*\0", dest)) {
                std::string raw;
                if (fs::ReadTextFile(log::CurrentFilePath(), raw)) {
                    fs::WriteTextFileAtomic(dest, raw);
                    log::Info(L"log exported: " + dest);
                }
            }
        };
        btnExport = be.get();
        widgets.push_back(std::move(be));
        Reload();
    }

    void Reload() {
        entries = log::Tail(500);
        const int f = segFilter ? segFilter->selected : 0;
        if (f == 1) {
            std::deque<log::Entry> kept;
            for (const auto& e : entries)
                if (e.level == log::Level::Event) kept.push_back(e);
            entries = kept;
        } else if (f == 2) {
            std::deque<log::Entry> kept;
            for (const auto& e : entries)
                if (e.level == log::Level::Warn || e.level == log::Level::Error) kept.push_back(e);
            entries = kept;
        }
        if (tgFollow && tgFollow->on) {
            const int view = listRc.bottom - listRc.top;
            const int content = static_cast<int>(entries.size()) * 22;
            scrollList = content > view ? content - view : 0;
        }
        if (hwndRef) InvalidateRect(hwndRef, nullptr, FALSE);
    }

    void OnShow(HWND) override { Reload(); }
    void OnDataChanged() override { Reload(); }
    void OnSecondTick() override {
        const size_t before = entries.size();
        auto now = log::Tail(500);
        if (now.size() != before) Reload();
    }

    void Refresh() override {
        Page::Refresh();
        if (segFilter) {
            segFilter->items[0].label = l10n::t(l10n::S::FilterAllLv);
            segFilter->items[1].label = l10n::t(l10n::S::FilterEvents);
            segFilter->items[2].label = l10n::t(l10n::S::FilterIssues);
        }
        if (btnExport) btnExport->label = l10n::t(l10n::S::ExportLog);
    }

    void LayoutContent(HWND hwnd, int width) override {
        const int pad = 28;
        const int W = width - pad * 2;
        int y = 12;
        const int barH = 36;
        segFilter->Layout({pad, y, pad + segFilter->PreferredWidth(hwnd), y + barH});
        tgFollow->Layout({pad + 300, y, pad + 560, y + barH});
        const int bw = btnExport->PreferredWidth(hwnd);
        btnExport->Layout({pad + W - bw, y, pad + W, y + barH});
        y += barH + 12;
        listRc = ToWindow(RECT{pad, y, pad + W, Height() > 0 ? Height() - 12 : y + 400});
        listBar.SetRange(static_cast<int>(entries.size()) * 22,
                      listRc.bottom - listRc.top - 2);
        listBar.pos = scrollList;
        contentH = Height();
    }

    bool Wheel(HWND hwnd, int delta) override {
        if (!listBar.Needed()) return false;
        const int before = listBar.pos;
        listBar.ScrollBy(-delta / 120 * 44);
        scrollList = listBar.pos;
        if (listBar.pos != before) {
            InvalidateRect(hwnd, nullptr, FALSE);
            return true;
        }
        return false;
    }

    void Paint(PaintCtx& pc) override {
        Page::Paint(pc);
        const Palette& P = theme::Pal();
        const HWND hwnd = hwndRef;
        // follow label next to toggle
        Gdiplus::RectF fl(padLabelX(), static_cast<float>(listRc.top) - 36.f - 8.f, 200.f, 36.f);
        gfx::DrawString(pc.g, l10n::t(l10n::S::FollowNew), gfx::Font(hwnd, 12.5f), fl,
                        gfx::C(P.textSecondary), Gdiplus::StringAlignmentNear);
        gfx::FillRoundRect(pc.g, gfx::RectFOf(listRc), 8.f, gfx::C(P.cardBg));
        gfx::StrokeRoundRect(pc.g, gfx::RectFOf(listRc), 8.f, gfx::C(P.cardBorder), 1.f);
        Gdiplus::GraphicsState st = pc.g.Save();
        pc.g.SetClip(gfx::RectFOf(listRc));
        if (entries.empty()) {
            Gdiplus::RectF er(listRc.left + 16.f, listRc.top + 20.f,
                              static_cast<float>(listRc.right - listRc.left) - 32.f, 20.f);
            gfx::DrawString(pc.g, l10n::t(l10n::S::EmptyLog), gfx::Font(hwnd, 12.5f), er,
                            gfx::C(P.textDisabled));
        }
        const int first = scrollList / 22;
        const int last = std::min<int>(static_cast<int>(entries.size()) - 1,
                                       (scrollList + (listRc.bottom - listRc.top)) / 22);
        for (int i = first; i <= last; ++i) {
            const log::Entry& e = entries[i];
            const int y = listRc.top + 1 + i * 22 - scrollList;
            const COLORREF lc = e.level == log::Level::Error   ? P.danger
                                : e.level == log::Level::Warn   ? P.warning
                                : e.level == log::Level::Event ? P.success
                                                               : P.textSecondary;
            Gdiplus::RectF tr(listRc.left + 14.f, static_cast<float>(y),
                              static_cast<float>(listRc.right - listRc.left) - 28.f, 22.f);
            const std::wstring line =
                str::Format(L"%02d:%02d:%02d  %-5s  %s", e.time.wHour, e.time.wMinute,
                            e.time.wSecond, log::LevelName(e.level).c_str(), e.msg.c_str());
            gfx::DrawString(pc.g, line, gfx::MonoFont(hwnd, 11.5f), tr, gfx::C(lc),
                            Gdiplus::StringAlignmentNear);
        }
        pc.g.Restore(st);
        listBar.rc = {listRc.right - 10, listRc.top + 4, listRc.right - 3, listRc.bottom - 4};
        listBar.Paint(pc);
    }

    float padLabelX() const { return static_cast<float>(listRc.left) + 300.f + 46.f; }
};

}  // namespace

std::unique_ptr<Page> MakeActivityPage() { return std::make_unique<ActivityPage>(); }

}  // namespace tig::ui
