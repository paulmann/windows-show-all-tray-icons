#include "ui/mainwindow.h"

#include <commctrl.h>
#include <shellapi.h>

#include <algorithm>

#include "core/backup.h"
#include "core/explorer.h"
#include "core/guard.h"
#include "core/version.h"
#include "core/update.h"
#include "core/win_compat.h"
#include "core/log.h"
#include "core/os.h"
#include "core/settings.h"
#include "core/trayicons.h"
#include "ui/lang/strings.h"
#include "ui/pages/pages.h"
#include "ui/theme.h"
#include "ui/trayicon.h"

#include "util/str.h"

namespace tig::ui {

namespace {
constexpr wchar_t kWndClass[] = L"TrayIconGuard.Main.v8";
constexpr int kNavExpanded = 244;
constexpr int kNavCollapsed = 64;
constexpr int kTopBarH = 92;
constexpr int kStatusH = 30;
constexpr UINT kAnimTimerId = 4001;
constexpr UINT kSecTimerId = 4002;
constexpr UINT kUiTestTimerId = 4003;
UINT WM_TIG_GUARD = 0;  // registered: guard worker -> UI
MainWindow* g_instance = nullptr;

const CLSID* PngClsid() {
    static CLSID clsid{};
    static bool done = false;
    if (!done) {
        done = true;
        UINT num = 0, size = 0;
        Gdiplus::GetImageEncodersSize(&num, &size);
        if (size) {
            std::vector<BYTE> buf(size);
            Gdiplus::GetImageEncoders(num, size,
                                      reinterpret_cast<Gdiplus::ImageCodecInfo*>(buf.data()));
            auto* ci = reinterpret_cast<Gdiplus::ImageCodecInfo*>(buf.data());
            for (UINT i = 0; i < num; ++i) {
                if (wcscmp(ci[i].MimeType, L"image/png") == 0) {
                    clsid = ci[i].Clsid;
                    break;
                }
            }
        }
    }
    return &clsid;
}
}  // namespace

MainWindow& MainWindow::Instance() { return *g_instance; }

// ================= Page =================
void Page::Layout(const RECT& area) {
    rc = area;
    LayoutContent(hwndRef, area.right - area.left);
    for (auto& w : widgets) {
        OffsetRect(&w->rc, area.left, area.top);
        if (w->NativeHwnd()) w->Layout(w->rc);
    }
    sbar.onScroll = [this](int p) { SetScroll(p); };
    sbar.SetRange(contentH, Height());
    sbar.pos = scroll;
}

void Page::SetScroll(int v) {
    const int maxScroll = contentH > Height() ? contentH - Height() : 0;
    if (v < 0) v = 0;
    if (v > maxScroll) v = maxScroll;
    if (v == scroll && !widgets.empty()) return;
    scroll = v;
    if (!rc.right) return;
    Layout(rc);
}

void Page::Paint(PaintCtx& pc) {
    const Palette& P = theme::Pal();
    gfx::FillRect(pc.g, gfx::RectFOf(rc), gfx::C(P.windowBg));
    Gdiplus::RectF clip = gfx::RectFOf(rc);
    Gdiplus::GraphicsState st = pc.g.Save();
    pc.g.SetClip(clip);
    PaintBackground(pc);
    for (auto& w : widgets) {
        if (!w->visible) continue;
        RECT inter{};
        if (!IntersectRect(&inter, &w->rc, &rc)) continue;
        w->Paint(pc);
    }
    pc.g.Restore(st);
    sbar.rc = {rc.right - 12, rc.top + 4, rc.right - 2, rc.bottom - 4};
    sbar.Paint(pc);
}

bool Page::HitTest(POINT p) const { return Widget::HitTest(p); }

Widget* Page::WidgetAt(POINT p) {
    if (sbar.Needed() && sbar.HitTest(p)) return &sbar;
    for (auto it = widgets.rbegin(); it != widgets.rend(); ++it) {
        if ((*it)->HitTest(p)) return it->get();
    }
    return nullptr;
}

bool Page::Wheel(HWND hwnd, int delta) {
    (void)hwnd;
    if (!sbar.Needed()) return false;
    const int before = scroll;
    sbar.ScrollBy(-delta / 120 * 60);
    if (sbar.pos != before) {
        SetScroll(sbar.pos);
        return true;
    }
    return false;
}

bool Page::Tick(float dt) {
    bool active = false;
    for (auto& w : widgets) {
        if (w->visible && w->Tick(dt)) active = true;
    }
    return active;
}

void Page::Refresh() {
    for (auto& w : widgets) w->Refresh();
}

// ================= MainWindow =================
MainWindow::MainWindow() { g_instance = this; }

bool MainWindow::Create(HINSTANCE hi, bool startMinimized, const std::wstring& testPage,
                        int testMs) {
    hinst = hi;
    uiTest = testMs > 0;
    uiTestMs = testMs;
    uiTestPageName = testPage;
    startTick = GetTickCount64();

    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.style = CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS;
    wc.lpfnWndProc = &MainWindow::WndProc;
    wc.hInstance = hi;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hIcon = static_cast<HICON>(LoadImageW(hi, MAKEINTRESOURCEW(1), IMAGE_ICON, 256, 256, LR_DEFAULTCOLOR));
    wc.hIconSm = static_cast<HICON>(LoadImageW(hi, MAKEINTRESOURCEW(1), IMAGE_ICON, 16, 16, LR_DEFAULTCOLOR));
    wc.lpszClassName = kWndClass;
    RegisterClassExW(&wc);

    WM_TIG_GUARD = RegisterWindowMessageW(L"TrayIconGuard.GuardEvent.v8");

    Settings& s = settings::Get();
    const int cw = s.winW > 700 ? s.winW : 1060;
    const int ch = s.winH > 500 ? s.winH : 700;
    int x = s.winX >= 0 ? s.winX : CW_USEDEFAULT;
    int y = s.winY >= 0 ? s.winY : CW_USEDEFAULT;

    hwnd = CreateWindowExW(WS_EX_APPWINDOW, kWndClass, L"TrayIconGuard",
                           WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN | WS_CLIPSIBLINGS, x, y, cw,
                           ch, nullptr, nullptr, hi, this);
    if (!hwnd) return false;

    // pages
    pages.push_back(MakeDashboardPage());
    pages.push_back(MakeIconsPage());
    pages.push_back(MakeGuardPage());
    pages.push_back(MakeAppearancePage());
    pages.push_back(MakeBackupsPage());
    pages.push_back(MakeActivityPage());
    pages.push_back(MakeAboutPage());
    for (size_t i = 0; i < pages.size(); ++i) pages[i]->id = static_cast<PageId>(i);

    // quick actions in the top bar
    themeQuick.glyph = 0xE706;
    themeQuick.tooltip = L"theme";
    themeQuick.onClick = [this] {
        const ThemeMode next = theme::Mode() == ThemeMode::Light   ? ThemeMode::Dark
                               : theme::Mode() == ThemeMode::Dark ? ThemeMode::System
                                                                  : ThemeMode::Light;
        theme::SetMode(next);
        RefreshEverything();
    };
    refreshQuick.glyph = 0xE72C;
    refreshQuick.onClick = [this] {
        store::Rescan();
        NotifyDataChanged();
    };

    // resolve initial page
    PageId initial = PageId::Dashboard;
    const std::wstring want = uiTest ? uiTestPageName : s.lastPage;
    const wchar_t* names[kPageCount] = {L"dashboard", L"icons", L"guard", L"appearance",
                                        L"backups",   L"activity", L"about"};
    for (int i = 0; i < kPageCount; ++i) {
        if (str::IEquals(want, names[i])) initial = static_cast<PageId>(i);
    }
    current = initial;

    ApplyDwmAttributes();
    theme::Subscribe([this] {
        ApplyDwmAttributes();
        RefreshEverything();
    });

    if (uiTest) {
        ShowWindow(hwnd, SW_SHOWNORMAL);
        UpdateWindow(hwnd);
        SetTimer(hwnd, kUiTestTimerId, static_cast<UINT>(uiTestMs), nullptr);
    } else if (startMinimized) {
        // stay hidden; tray icon is the presence
    } else {
        ShowWindow(hwnd, s.winMax ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL);
    }
    UpdateWindow(hwnd);
    SetTimer(hwnd, kSecTimerId, 1000, nullptr);
    return true;
}

void MainWindow::Show(int cmdShow) {
    ShowWindow(hwnd, cmdShow);
    SetForegroundWindow(hwnd);
}

Page* MainWindow::PageById(PageId id) {
    const int i = static_cast<int>(id);
    return i >= 0 && i < static_cast<int>(pages.size()) ? pages[i].get() : nullptr;
}

Page* MainWindow::CurrentPage() { return PageById(current); }

void MainWindow::GoTo(PageId id) {
    if (id == current) return;
    BlurFocus();
    current = id;
    settings::Get().lastPage = std::wstring(
        std::vector<std::wstring>{L"dashboard", L"icons", L"guard", L"appearance", L"backups",
                                  L"activity", L"about"}[static_cast<int>(id)]);
    Page* p = CurrentPage();
    p->EnsureBuilt(hwnd);
    p->OnShow(hwnd);
    LayoutAll();
    InvalidateRect(hwnd, nullptr, FALSE);
}

void MainWindow::RefreshEverything() {
    for (auto& p : pages) {
        if (p->built) p->Refresh();
    }
    LayoutAll();
    InvalidateRect(hwnd, nullptr, FALSE);
}

void MainWindow::NotifyDataChanged() {
    for (auto& p : pages) {
        if (p->built) p->OnDataChanged();
    }
    InvalidateRect(hwnd, nullptr, FALSE);
}

void MainWindow::PostGuardEvent(int kind, const std::wstring& detail) {
    if (!hwnd) return;
    auto* copy = new std::wstring(detail);
    PostMessageW(hwnd, WM_TIG_GUARD ? WM_TIG_GUARD : WM_APP + 1, static_cast<WPARAM>(kind),
                 reinterpret_cast<LPARAM>(copy));
}

// ---------- layout ----------
int MainWindow::NavWidth() const {
    RECT r{};
    GetClientRect(hwnd, &r);
    return (r.right - r.left) < 860 ? kNavCollapsed : kNavExpanded;
}

RECT MainWindow::NavRect() const {
    RECT r{};
    GetClientRect(hwnd, &r);
    r.right = r.left + NavWidth();
    return r;
}

RECT MainWindow::TopBarRect() const {
    RECT r{};
    GetClientRect(hwnd, &r);
    r.left += NavWidth();
    r.bottom = r.top + kTopBarH;
    return r;
}

RECT MainWindow::StatusRect() const {
    RECT r{};
    GetClientRect(hwnd, &r);
    r.top = r.bottom - kStatusH;
    return r;
}

RECT MainWindow::ContentRect() const {
    RECT r{};
    GetClientRect(hwnd, &r);
    r.left += NavWidth();
    r.top += kTopBarH;
    r.bottom -= kStatusH;
    return r;
}

void MainWindow::LayoutAll() {
    if (!hwnd) return;
    RECT tb = TopBarRect();
    themeQuick.Layout({tb.right - 44, tb.top + 28, tb.right - 8, tb.top + 64});
    refreshQuick.Layout({tb.right - 84, tb.top + 28, tb.right - 48, tb.top + 64});
    Page* p = CurrentPage();
    if (p) {
        p->EnsureBuilt(hwnd);
        p->Layout(ContentRect());
    }
}

void MainWindow::OnSize() { LayoutAll(); }

// ---------- painting ----------
void MainWindow::OnPaint() {
    RECT r{};
    GetClientRect(hwnd, &r);
    const int w = r.right - r.left, h = r.bottom - r.top;
    if (w <= 0 || h <= 0) return;
    HDC dc = GetDC(hwnd);
    if (!memDc || memW != w || memH != h) {
        if (memBmp) DeleteObject(memBmp);
        if (memDc) DeleteDC(memDc);
        memDc = CreateCompatibleDC(dc);
        memBmp = CreateCompatibleBitmap(dc, w, h);
        SelectObject(memDc, memBmp);
        memW = w;
        memH = h;
    }
    {
        Gdiplus::Graphics g(memDc);
        gfx::SetupText(g);
        PaintCtx pc{g, hwnd};
        const Palette& P = theme::Pal();
        gfx::FillRect(g, Gdiplus::RectF(0, 0, static_cast<float>(w), static_cast<float>(h)),
                      gfx::C(P.windowBg));
        Page* p = CurrentPage();
        if (p) p->Paint(pc);
        DrawNav(pc);
        DrawTopBar(pc);
        DrawStatus(pc);
        themeQuick.Paint(pc);
        refreshQuick.Paint(pc);
    }
    BitBlt(dc, 0, 0, w, h, memDc, 0, 0, SRCCOPY);
    ReleaseDC(hwnd, dc);
}

void MainWindow::DrawNav(PaintCtx& pc) {
    const Palette& P = theme::Pal();
    const RECT nr = NavRect();
    const bool expanded = NavWidth() == kNavExpanded;
    gfx::FillRect(pc.g, gfx::RectFOf(nr), gfx::C(P.navBg));
    Gdiplus::RectF sep(static_cast<float>(nr.right) - 1.f, 0, 1.f,
                       static_cast<float>(nr.bottom));
    gfx::FillRect(pc.g, sep, gfx::C(P.separator));
    // header
    Gdiplus::Bitmap* icon = gfx::AppIconBitmap(expanded ? 28 : 32);
    if (icon) {
        const float ix = expanded ? 16.f : (nr.right - 32) * 0.5f;
        Gdiplus::RectF ir(ix, 16.f, expanded ? 28.f : 32.f, expanded ? 28.f : 32.f);
        pc.g.DrawImage(icon, ir);
    }
    if (expanded) {
        Gdiplus::RectF tr(52.f, 14.f, static_cast<float>(nr.right) - 60.f, 20.f);
        gfx::DrawString(pc.g, L"TrayIconGuard", gfx::Font(hwnd, 15.f, FontStyle::SemiBold), tr,
                        gfx::C(P.textPrimary));
        Gdiplus::RectF tr2(52.f, 32.f, static_cast<float>(nr.right) - 60.f, 16.f);
        gfx::DrawString(pc.g, l10n::t(l10n::S::Tagline), gfx::Font(hwnd, 11.f), tr2,
                        gfx::C(P.textSecondary));
    }
    // items
    const wchar_t glyphs[kPageCount] = {0xE80F, 0xE71D, 0xE72E, 0xE771, 0xE74E, 0xE9D5, 0xE946};
    const l10n::S labels[kPageCount] = {l10n::S::NavDashboard, l10n::S::NavIcons,
                                        l10n::S::NavGuard,     l10n::S::NavAppearance,
                                        l10n::S::NavBackups,   l10n::S::NavActivity,
                                        l10n::S::NavAbout};
    int y = 64;
    for (int i = 0; i < kPageCount; ++i) {
        const RECT item{nr.left + 8, y, nr.right - 8, y + 40};
        const bool sel = static_cast<int>(current) == i;
        if (sel) {
            Gdiplus::RectF pr = gfx::RectFOf(item);
            gfx::FillRoundRect(pc.g, pr, 5.f, gfx::C(P.navSelected));
            Gdiplus::RectF bar(pr.X, pr.Y + pr.Height * 0.5f - 8.f, 3.f, 16.f);
            gfx::FillRoundRect(pc.g, bar, 1.5f, gfx::C(P.accent));
        } else if (navHover == i) {
            gfx::FillRoundRect(pc.g, gfx::RectFOf(item), 5.f, gfx::C(P.navHover));
        }
        Gdiplus::RectF gr(expanded ? 18.f : (item.left + (item.right - item.left) * 0.5f - 12.f),
                          item.top + 11.f, 18.f, 18.f);
        gfx::DrawGlyph(pc.g, glyphs[i], gfx::GlyphFont(hwnd, 16.f), gr,
                       gfx::C(sel ? P.textPrimary : P.textSecondary),
                       Gdiplus::StringAlignmentNear);
        if (expanded) {
            Gdiplus::RectF lr(48.f, static_cast<float>(item.top),
                              static_cast<float>(item.right) - 56.f, 40.f);
            gfx::DrawString(pc.g, l10n::t(labels[i]),
                            gfx::Font(hwnd, 13.5f, sel ? FontStyle::SemiBold : FontStyle::Regular),
                            lr, gfx::C(sel ? P.textPrimary : P.textSecondary));
        }
        y += 44;
    }
}

int MainWindow::NavItemAt(POINT p) const {
    const RECT nr = NavRect();
    if (!PtInRect(&nr, p)) return -1;
    if (p.y < 64) return -1;
    const int idx = (p.y - 64) / 44;
    if (idx < 0 || idx >= kPageCount) return -1;
    const int yTop = 64 + idx * 44;
    if (p.y > yTop + 40) return -1;
    return idx;
}

void MainWindow::DrawTopBar(PaintCtx& pc) {
    const Palette& P = theme::Pal();
    const RECT tb = TopBarRect();
    Page* p = CurrentPage();
    if (!p) return;
    themeQuick.glyph = theme::Mode() == ThemeMode::Light   ? 0xE706
                       : theme::Mode() == ThemeMode::Dark ? 0xE708
                                                          : 0xE7F4;
    Gdiplus::RectF title(static_cast<float>(tb.left) + 28.f, static_cast<float>(tb.top) + 16.f,
                         static_cast<float>(tb.right - tb.left) - 140.f, 36.f);
    gfx::DrawString(pc.g, l10n::t(p->TitleId()), gfx::Font(hwnd, 26.f, FontStyle::SemiBold),
                    title, gfx::C(P.textPrimary));
    Gdiplus::RectF sub(title.X, title.GetBottom() + 2.f, title.Width, 20.f);
    gfx::DrawString(pc.g, l10n::t(p->SubId()), gfx::Font(hwnd, 12.5f), sub,
                    gfx::C(P.textSecondary));
}

void MainWindow::DrawStatus(PaintCtx& pc) {
    const Palette& P = theme::Pal();
    const RECT sr = StatusRect();
    gfx::FillRect(pc.g, gfx::RectFOf(sr), gfx::C(P.statusBarBg));
    Gdiplus::RectF sep(static_cast<float>(sr.left), static_cast<float>(sr.top),
                       static_cast<float>(sr.right - sr.left), 1.f);
    gfx::FillRect(pc.g, sep, gfx::C(P.separator));

    const guard::Stats gs = guard::GetStats();
    const store::Counts c = store::GetCounts(store::Current());
    const wchar_t* stateName = !gs.running   ? l10n::t(l10n::S::Off)
                               : gs.paused   ? l10n::t(l10n::S::Paused)
                                             : l10n::t(l10n::S::Running);
    const COLORREF dot = !gs.running   ? P.textDisabled
                         : gs.paused   ? P.warning
                                       : P.success;
    Gdiplus::RectF dr(static_cast<float>(sr.left) + 14.f,
                      static_cast<float>(sr.top) + (kStatusH - 8) * 0.5f, 8.f, 8.f);
    gfx::FillRoundRect(pc.g, dr, 4.f, gfx::C(dot));
    const std::wstring text = str::Format(l10n::t(l10n::S::StatusbarFmt), stateName, c.promoted,
                                          c.hidden, os::Get().caption.c_str(), kVersion);
    Gdiplus::RectF tr(dr.GetRight() + 8.f, static_cast<float>(sr.top),
                      static_cast<float>(sr.right - sr.left) - 120.f, static_cast<float>(kStatusH));
    gfx::DrawString(pc.g, text, gfx::Font(hwnd, 11.5f), tr, gfx::C(P.textSecondary),
                    Gdiplus::StringAlignmentNear);
}

// ---------- DWM ----------
void MainWindow::ApplyDwmAttributes() {
    const BOOL dark = theme::IsDark() ? TRUE : FALSE;
    DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark, sizeof(dark));
    const DWORD corner = DWMWCP_ROUND;
    DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &corner, sizeof(corner));
}

// ---------- input ----------
void MainWindow::SetHot(Widget* w) {
    if (hotWidget == w) return;
    POINT p{};
    GetCursorPos(&p);
    ScreenToClient(hwnd, &p);
    if (hotWidget) hotWidget->OnMouse(ME::Leave, p);
    hotWidget = w;
    if (w) w->OnMouse(ME::Enter, p);
    InvalidateRect(hwnd, nullptr, FALSE);
    StartAnimTimer();
}

void MainWindow::UpdateCursor(POINT p) {
    bool hand = NavItemAt(p) >= 0;
    if (!hand && hotWidget) {
        hand = dynamic_cast<Button*>(hotWidget) || dynamic_cast<IconButton*>(hotWidget) ||
               dynamic_cast<Toggle*>(hotWidget) || dynamic_cast<Segmented*>(hotWidget) ||
               dynamic_cast<SearchBox*>(hotWidget) || hotWidget == &CurrentPage()->sbar;
    }
    SetCursor(LoadCursorW(nullptr, hand ? IDC_HAND : IDC_ARROW));
}

void MainWindow::OnMouseMove(POINT p) {
    const int nav = NavItemAt(p);
    if (nav != navHover) {
        navHover = nav;
        InvalidateRect(hwnd, nullptr, FALSE);
    }
    Widget* target = nullptr;
    if (captured && pressedWidget) {
        target = pressedWidget;
    } else if (InContent(p)) {
        target = CurrentPage()->WidgetAt(p);
    } else if (InTopBar(p)) {
        if (themeQuick.HitTest(p)) target = &themeQuick;
        else if (refreshQuick.HitTest(p)) target = &refreshQuick;
    }
    if (!captured) SetHot(target);
    if (target) target->OnMouse(ME::Move, p);
    else if (InContent(p)) CurrentPage()->OnPageMouseMove(p);
    TRACKMOUSEEVENT tme{sizeof(tme), TME_LEAVE, hwnd, 0};
    TrackMouseEvent(&tme);
    UpdateCursor(p);
}

void MainWindow::OnLDown(POINT p) {
    const int nav = NavItemAt(p);
    if (nav >= 0) return;  // handled on click
    Widget* target = nullptr;
    if (InContent(p)) target = CurrentPage()->WidgetAt(p);
    else if (themeQuick.HitTest(p)) target = &themeQuick;
    else if (refreshQuick.HitTest(p)) target = &refreshQuick;
    if (target) {
        pressedWidget = target;
        captured = true;
        SetCapture(hwnd);
        target->OnMouse(ME::Down, p);
        if (target->focusable) SetFocusWidget(target);
        StartAnimTimer();
        InvalidateRect(hwnd, nullptr, FALSE);
    } else {
        BlurFocus();
    }
}

void MainWindow::OnLUp(POINT p) {
    const int nav = NavItemAt(p);
    if (captured) {
        ReleaseCapture();
        captured = false;
        Widget* w = pressedWidget;
        pressedWidget = nullptr;
        if (w) {
            w->OnMouse(ME::Up, p);
            if (w->HitTest(p)) w->OnMouse(ME::Click, p);
            StartAnimTimer();
            InvalidateRect(hwnd, nullptr, FALSE);
        }
        return;
    }
    if (nav >= 0) {
        GoTo(static_cast<PageId>(nav));
        return;
    }
    if (InContent(p) && CurrentPage()->OnBackgroundClick(p)) {
        InvalidateRect(hwnd, nullptr, FALSE);
        return;
    }
    if (themeQuick.HitTest(p)) themeQuick.OnMouse(ME::Click, p);
    if (refreshQuick.HitTest(p)) refreshQuick.OnMouse(ME::Click, p);
}

void MainWindow::OnWheel(int delta, POINT p) {
    if (InContent(p)) {
        if (CurrentPage()->Wheel(hwnd, delta)) InvalidateRect(hwnd, nullptr, FALSE);
    }
}

void MainWindow::SetFocusWidget(Widget* w) {
    if (focusW == w) return;
    if (focusW) focusW->focused = false;
    focusW = w;
    if (w) {
        w->focused = true;
        if (HWND nh = w->NativeHwnd()) SetFocus(nh);
    }
    InvalidateRect(hwnd, nullptr, FALSE);
}

void MainWindow::BlurFocus() { SetFocusWidget(nullptr); }

bool MainWindow::OnKeyDown(UINT vk) {
    if (vk == VK_TAB) {
        Page* p = CurrentPage();
        std::vector<Widget*> chain;
        for (auto& w : p->widgets) {
            if (w->visible && w->focusable && w->enabled) chain.push_back(w.get());
        }
        if (chain.empty()) return true;
        size_t idx = chain.size();
        for (size_t i = 0; i < chain.size(); ++i) {
            if (chain[i] == focusW) {
                idx = i;
                break;
            }
        }
        const bool shift = GetAsyncKeyState(VK_SHIFT) & 0x8000;
        idx = idx >= chain.size() ? (shift ? chain.size() - 1 : 0)
              : shift             ? (idx == 0 ? chain.size() - 1 : idx - 1)
                                  : (idx + 1) % chain.size();
        SetFocusWidget(chain[idx]);
        return true;
    }
    if (vk == VK_ESCAPE) {
        BlurFocus();
        return true;
    }
    if (vk == VK_F5) {
        store::Rescan();
        NotifyDataChanged();
        return true;
    }
    if (GetAsyncKeyState(VK_CONTROL) & 0x8000) {
        if (vk >= '1' && vk <= '7') {
            GoTo(static_cast<PageId>(vk - '1'));
            return true;
        }
        if (vk == 'F') {
            Page* p = CurrentPage();
            for (auto& w : p->widgets) {
                if (auto* sb = dynamic_cast<SearchBox*>(w.get())) {
                    GoTo(PageId::Icons);
                    SetFocusWidget(sb);
                    return true;
                }
            }
        }
    }
    if (focusW && focusW->OnKey(vk, true)) {
        StartAnimTimer();
        InvalidateRect(hwnd, nullptr, FALSE);
        return true;
    }
    return false;
}

// ---------- timers / anims ----------
void MainWindow::StartAnimTimer() {
    if (!animTimer) animTimer = SetTimer(hwnd, kAnimTimerId, 16, nullptr);
}

void MainWindow::StopAnimTimerIfNeeded() {
    if (animTimer) {
        KillTimer(hwnd, kAnimTimerId);
        animTimer = 0;
    }
}

// ---------- QA self-screenshot ----------
void MainWindow::CaptureSelfPng(const std::wstring& path) {
    if (!memDc || !memW || !memH) return;
    HDC screen = GetDC(hwnd);
    HBITMAP hb = CreateCompatibleBitmap(screen, memW, memH);
    HDC copy = CreateCompatibleDC(screen);
    HGDIOBJ old = SelectObject(copy, hb);
    BitBlt(copy, 0, 0, memW, memH, memDc, 0, 0, SRCCOPY);
    SelectObject(copy, old);
    ReleaseDC(hwnd, screen);
    Gdiplus::Bitmap bmp(hb, nullptr);
    bmp.Save(path.c_str(), PngClsid(), nullptr);
    DeleteDC(copy);
    DeleteObject(hb);
}

// ---------- wndproc ----------
LRESULT CALLBACK MainWindow::WndProc(HWND h, UINT m, WPARAM w, LPARAM l) {
    if (m == WM_NCCREATE) {
        auto* cs = reinterpret_cast<CREATESTRUCTW*>(l);
        auto* self = static_cast<MainWindow*>(cs->lpCreateParams);
        SetWindowLongPtrW(h, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
        self->hwnd = h;
        return TRUE;
    }
    auto* self = reinterpret_cast<MainWindow*>(GetWindowLongPtrW(h, GWLP_USERDATA));
    if (!self) return DefWindowProcW(h, m, w, l);
    return self->Handle(m, w, l);
}

LRESULT MainWindow::Handle(UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
        case WM_CREATE:
            return 0;
        case WM_SIZE:
            OnSize();
            InvalidateRect(hwnd, nullptr, FALSE);
            return 0;
        case WM_GETMINMAXINFO: {
            auto* mmi = reinterpret_cast<MINMAXINFO*>(lp);
            mmi->ptMinTrackSize = {720, 520};
            return 0;
        }
        case WM_ERASEBKGND:
            return 1;
        case WM_PAINT: {
            PAINTSTRUCT ps{};
            BeginPaint(hwnd, &ps);
            OnPaint();
            EndPaint(hwnd, &ps);
            return 0;
        }
        case WM_MOUSEMOVE:
            OnMouseMove({static_cast<short>(LOWORD(lp)), static_cast<short>(HIWORD(lp))});
            return 0;
        case WM_LBUTTONDOWN:
            OnLDown({static_cast<short>(LOWORD(lp)), static_cast<short>(HIWORD(lp))});
            return 0;
        case WM_LBUTTONUP:
            OnLUp({static_cast<short>(LOWORD(lp)), static_cast<short>(HIWORD(lp))});
            return 0;
        case WM_LBUTTONDBLCLK:
            return 0;
        case WM_MOUSEWHEEL:
            OnWheel(static_cast<short>(HIWORD(wp)),
                    {static_cast<short>(LOWORD(lp)), static_cast<short>(HIWORD(lp))});
            return 0;
        case WM_MOUSELEAVE:
            SetHot(nullptr);
            navHover = -1;
            InvalidateRect(hwnd, nullptr, FALSE);
            return 0;
        case WM_KEYDOWN:
            if (OnKeyDown(static_cast<UINT>(wp))) return 0;
            break;
        case WM_COMMAND: {
            const int code = HIWORD(wp);
            if (code == EN_CHANGE || code == EN_SETFOCUS || code == EN_KILLFOCUS) {
                Page* p = CurrentPage();
                for (auto& w : p->widgets) {
                    if (auto* sb = dynamic_cast<SearchBox*>(w.get())) {
                        if (sb->NativeHwnd() == reinterpret_cast<HWND>(lp)) {
                            if (code == EN_SETFOCUS) SetFocusWidget(sb);
                            if (code == EN_KILLFOCUS && focusW == sb) {
                                focusW->focused = false;
                                focusW = nullptr;
                            }
                            if (code == EN_CHANGE && sb->onChange) sb->onChange(sb->Text());
                            InvalidateRect(hwnd, nullptr, FALSE);
                        }
                    }
                }
                return 0;
            }
            // tray menu commands
            if (tray::HandleCommand(LOWORD(wp))) return 0;
            return 0;
        }
        case WM_CONTEXTMENU: {
            POINT p{static_cast<short>(LOWORD(lp)), static_cast<short>(HIWORD(lp))};
            if (p.x == -1 && p.y == -1) {  // keyboard: use cursor position
                GetCursorPos(&p);
            }
            POINT pc = p;
            ScreenToClient(hwnd, &pc);
            if (InContent(pc) && CurrentPage()->OnContextMenu(p)) return 0;
            return 0;
        }
        case WM_APP + 61: {  // silent auto-check: update available
            auto* ver = reinterpret_cast<std::wstring*>(lp);
            tray::Balloon(l10n::t(l10n::S::UpdateAvailTitle),
                          str::Format(l10n::t(l10n::S::UpdateNew),
                                      ver ? ver->c_str() : L""),
                          true);
            delete ver;
            return 0;
        }
        case WM_APP + 63: {  // feed fetch result -> About page
            PageById(PageId::About)->OnFeedMessage(lp);
            return 0;
        }
        case WM_APP + 64: {  // download/apply error -> About page
            PageById(PageId::About)->OnDownloadError(lp);
            return 0;
        }
        case WM_APP + 62: {  // update applied: relaunch new exe and exit
            tray::Remove();
            wchar_t self[MAX_PATH] = {};
            GetModuleFileNameW(nullptr, self, MAX_PATH);
            ShellExecuteW(nullptr, L"open", self, nullptr, nullptr, SW_SHOWNORMAL);
            ExitProcess(0);
        }
        case WM_APP + 60: {  // update check result
            auto* r = reinterpret_cast<update::Result*>(lp);
            PageById(PageId::About)->OnUpdateMessage(wp, lp);
            delete r;
            return 0;
        }
        case WM_APP + 40:  // ESC inside search edit
            BlurFocus();
            return 0;
        case WM_CTLCOLOREDIT: {
            HDC dc = reinterpret_cast<HDC>(wp);
            const Palette& P = theme::Pal();
            SetTextColor(dc, P.textPrimary);
            SetBkMode(dc, TRANSPARENT);
            SetBkColor(dc, P.searchBg);
            return reinterpret_cast<LRESULT>(GetStockObject(NULL_BRUSH));
        }
        case WM_SETTINGCHANGE:
            if (lp && wcscmp(reinterpret_cast<const wchar_t*>(lp), L"ImmersiveColorSet") == 0) {
                theme::OnSystemThemeChanged();
            }
            return 0;
        case WM_DPICHANGED:
            LayoutAll();
            InvalidateRect(hwnd, nullptr, FALSE);
            return 0;
        case WM_TIMER:
            if (wp == kAnimTimerId) {
                static ULONGLONG last = 0;
                const ULONGLONG now = GetTickCount64();
                const float dt = last ? static_cast<float>(now - last) : 16.f;
                last = now;
                bool active = false;
                if (CurrentPage()->Tick(dt)) active = true;
                if (themeQuick.Tick(dt)) active = true;
                if (refreshQuick.Tick(dt)) active = true;
                InvalidateRect(hwnd, nullptr, FALSE);
                if (!active) StopAnimTimerIfNeeded();
                return 0;
            }
            if (wp == kSecTimerId) {
                CurrentPage()->OnSecondTick();
                const RECT sr = StatusRect();
                InvalidateRect(hwnd, &sr, FALSE);
                return 0;
            }
            if (wp == kUiTestTimerId) {
                KillTimer(hwnd, kUiTestTimerId);
                UpdateWindow(hwnd);
                wchar_t tmp[MAX_PATH] = {};
                GetTempPathW(MAX_PATH, tmp);
                const std::wstring page = uiTestPageName.empty() ? L"dashboard" : uiTestPageName;
                CaptureSelfPng(std::wstring(tmp) + L"tig-uitest-" + page + L".png");
                PostQuitMessage(0);
                return 0;
            }
            return 0;
        case WM_CLOSE:
            if (!uiTest && settings::Get().closeToTray && !(GetAsyncKeyState(VK_SHIFT) & 0x8000)) {
                ShowWindow(hwnd, SW_HIDE);
                if (!closeHintShown) {
                    closeHintShown = true;
                    tray::Balloon(l10n::t(l10n::S::BalloonCloseTitle),
                                  l10n::t(l10n::S::BalloonCloseText), false);
                }
                return 0;
            }
            DestroyWindow(hwnd);
            return 0;
        case WM_DESTROY:
            if (memBmp) DeleteObject(memBmp);
            if (memDc) DeleteDC(memDc);
            memBmp = nullptr;
            memDc = nullptr;
            tray::Remove();
            PostQuitMessage(0);
            return 0;
        default:
            if (msg == WM_TIG_GUARD) {
                auto* detail = reinterpret_cast<std::wstring*>(lp);
                const int kind = static_cast<int>(wp);
                CurrentPage()->OnDataChanged();
                InvalidateRect(hwnd, nullptr, FALSE);
                tray::OnGuardEvent(kind, detail ? *detail : std::wstring());
                delete detail;
                return 0;
            }
            break;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

// ---------- high-level actions ----------
void MainWindow::PromoteAllNow() {
    if (settings::Get().autoBackup) {
        std::wstring path, err;
        backup::Create(path, err, L"auto");
    }
    std::wstring detail;
    const int n = guard::PromoteAllNow(detail);
    log::Event(str::Format(L"manual promote-all from UI: %d", n));
    store::Rescan();
    NotifyDataChanged();
    tray::Balloon(l10n::t(l10n::S::BalloonPromotedTitle),
                  str::Format(l10n::t(l10n::S::BalloonPromotedText), n), true);
}

void MainWindow::RestartExplorerNow() {
    std::wstring err;
    const bool ok = explorer::Restart(err);
    log::Info(ok ? L"Explorer restarted from UI" : L"Explorer restart failed: " + err);
    store::Rescan();
    NotifyDataChanged();
}

}  // namespace tig::ui
