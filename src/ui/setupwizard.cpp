#include "ui/setupwizard.h"

#include <shobjidl.h>

#include <vector>

#include "core/log.h"
#include "core/win_compat.h"
#include "core/settings.h"
#include "ui/gfx.h"
#include "ui/kit/widget.h"
#include "ui/lang/strings.h"
#include "ui/theme.h"
#include "util/fs.h"
#include "util/str.h"

namespace tig::ui::setup {

namespace {
constexpr wchar_t kWndClass[] = L"TrayIconGuard.Setup.v8";
constexpr int kWinW = 620;
constexpr int kWinH = 640;
constexpr UINT kShotTimer = 777;

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

class SetupWnd {
public:
    Result result;
    bool done = false;
    HWND hwnd = nullptr;
    std::wstring folder;
    Button btnBrowse, btnInstall, btnPortable;
    Toggle tgAutostart, tgDesktop, tgMenu;
    std::vector<Widget*> widgets;
    Widget* hot = nullptr;
    Widget* pressed = nullptr;
    bool captured = false;
    HDC memDc = nullptr;
    HBITMAP memBmp = nullptr;
    int memW = 0, memH = 0;
    UINT_PTR animTimer = 0;

    explicit SetupWnd() {
        folder = installer::DefaultDir();
        btnBrowse.style = Button::Style::Outline;
        btnBrowse.label = l10n::t(l10n::S::SetupBrowse);
        btnBrowse.onClick = [this] { Browse(); };
        btnInstall.style = Button::Style::Accent;
        btnInstall.glyph = 0xE896;
        btnInstall.label = l10n::t(l10n::S::SetupInstall);
        btnInstall.onClick = [this] {
            result.action = Action::Install;
            result.opts.dir = folder;
            result.opts.autostart = tgAutostart.on;
            result.opts.desktopIcon = tgDesktop.on;
            result.opts.startMenuIcon = tgMenu.on;
            done = true;
        };
        btnPortable.style = Button::Style::Subtle;
        btnPortable.label = l10n::t(l10n::S::SetupPortable);
        btnPortable.onClick = [this] {
            result.action = Action::Portable;
            done = true;
        };
        tgAutostart.on = true;
        tgDesktop.on = true;
        tgMenu.on = true;
        widgets = {&btnBrowse, &tgAutostart, &tgDesktop, &tgMenu, &btnPortable, &btnInstall};
    }

    void Browse() {
        IFileOpenDialog* dlg = nullptr;
        if (FAILED(CoCreateInstance(CLSID_FileOpenDialog, nullptr, CLSCTX_INPROC_SERVER,
                                    IID_IFileOpenDialog, reinterpret_cast<void**>(&dlg))))
            return;
        DWORD opts = 0;
        dlg->GetOptions(&opts);
        dlg->SetOptions(opts | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST);
        if (SUCCEEDED(dlg->Show(hwnd))) {
            IShellItem* item = nullptr;
            if (SUCCEEDED(dlg->GetResult(&item))) {
                PWSTR path = nullptr;
                if (SUCCEEDED(item->GetDisplayName(SIGDN_FILESYSPATH, &path))) {
                    folder = path;
                    CoTaskMemFree(path);
                    InvalidateRect(hwnd, nullptr, FALSE);
                }
                item->Release();
            }
        }
        dlg->Release();
    }

    void LayoutAll() {
        RECT r{};
        GetClientRect(hwnd, &r);
        const int W = r.right - r.left;
        const int pad = 28;
        // folder card row
        const int bw = btnBrowse.PreferredWidth(hwnd);
        btnBrowse.Layout({W - pad - bw, 168, W - pad, 200});
        // option rows
        tgAutostart.Layout({pad, 292, W - pad - 16, 348});
        tgDesktop.Layout({pad, 364, W - pad - 16, 420});
        tgMenu.Layout({pad, 436, W - pad - 16, 492});
        // footer buttons
        const int iw = btnInstall.PreferredWidth(hwnd);
        const int pw = btnPortable.PreferredWidth(hwnd);
        btnInstall.Layout({W - pad - iw, r.bottom - 52, W - pad, r.bottom - 20});
        btnPortable.Layout({pad, r.bottom - 52, pad + pw, r.bottom - 20});
    }

    void OnPaint() {
        RECT r{};
        GetClientRect(hwnd, &r);
        const int w = r.right - r.left, h = r.bottom - r.top;
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
            // header
            Gdiplus::Bitmap* icon = gfx::AppIconBitmap(48);
            if (icon) g.DrawImage(icon, Gdiplus::RectF(28.f, 24.f, 48.f, 48.f));
            Gdiplus::RectF title(90.f, 26.f, static_cast<float>(w) - 120.f, 30.f);
            gfx::DrawString(g, l10n::t(l10n::S::SetupTitle),
                            gfx::Font(hwnd, 22.f, FontStyle::SemiBold), title,
                            gfx::C(P.textPrimary));
            Gdiplus::RectF sub(90.f, 56.f, static_cast<float>(w) - 120.f, 18.f);
            gfx::DrawString(g, l10n::t(l10n::S::SetupSub), gfx::Font(hwnd, 12.f), sub,
                            gfx::C(P.textSecondary));
            // folder card
            RECT card1{28, 96, w - 28, 232};
            DrawCard(pc, card1, l10n::t(l10n::S::SetupWhere));
            Gdiplus::RectF fh(44.f, 132.f, static_cast<float>(w) - 88.f, 18.f);
            gfx::DrawString(g, l10n::t(l10n::S::SetupWhereHint), gfx::Font(hwnd, 11.5f), fh,
                            gfx::C(P.textSecondary));
            Gdiplus::RectF fv(44.f, 156.f, static_cast<float>(btnBrowse.rc.left) - 56.f, 32.f);
            gfx::FillRoundRect(g, Gdiplus::RectF(fv.X, fv.Y + 2, fv.Width, 28.f), 4.f,
                               gfx::C(P.searchBg));
            gfx::StrokeRoundRect(g, Gdiplus::RectF(fv.X, fv.Y + 2, fv.Width, 28.f), 4.f,
                                 gfx::C(P.searchBorder), 1.f);
            gfx::DrawString(g, folder, gfx::MonoFont(hwnd, 11.5f),
                            Gdiplus::RectF(fv.X + 8.f, fv.Y + 2.f, fv.Width - 16.f, 28.f),
                            gfx::C(P.textPrimary), Gdiplus::StringAlignmentNear);
            btnBrowse.Paint(pc);
            // options card
            RECT card2{28, 248, w - 28, 500};
            DrawCard(pc, card2, l10n::t(l10n::S::SetupOptions));
            // reuse card title = shortcuts group; draw three rows
            const struct {
                Toggle* t;
                l10n::S label;
                l10n::S desc;
                int y;
            } rows[3] = {
                {&tgAutostart, l10n::S::SetupAutostart, l10n::S::SetupAutostartDesc, 292},
                {&tgDesktop, l10n::S::SetupDesktop, l10n::S::SetupDesktopDesc, 364},
                {&tgMenu, l10n::S::SetupMenu, l10n::S::SetupMenuDesc, 436},
            };
            for (const auto& row : rows) {
                RECT rowRc{28, row.y, w - 28, row.y + 56};
                DrawSettingRow(pc, rowRc, l10n::t(row.label), l10n::t(row.desc),
                               row.y == 436);
                row.t->Paint(pc);
            }
            // note
            Gdiplus::RectF note(28.f, 506.f, static_cast<float>(w) - 56.f, 40.f);
            Gdiplus::StringFormat wrap;
            wrap.SetAlignment(Gdiplus::StringAlignmentNear);
            wrap.SetLineAlignment(Gdiplus::StringAlignmentNear);
            Gdiplus::SolidBrush nbrush(gfx::C(P.textSecondary));
            g.DrawString(l10n::t(l10n::S::SetupNote), -1, gfx::Font(hwnd, 11.f), note, &wrap,
                         &nbrush);
            btnPortable.Paint(pc);
            btnInstall.Paint(pc);
        }
        BitBlt(dc, 0, 0, w, h, memDc, 0, 0, SRCCOPY);
        ReleaseDC(hwnd, dc);
    }

    Widget* WidgetAt(POINT p) {
        for (auto* wdt : widgets) {
            if (wdt->visible && wdt->HitTest(p)) return wdt;
        }
        return nullptr;
    }

    void SetHot(Widget* w) {
        if (hot == w) return;
        POINT p{};
        GetCursorPos(&p);
        ScreenToClient(hwnd, &p);
        if (hot) hot->OnMouse(ME::Leave, p);
        hot = w;
        if (w) w->OnMouse(ME::Enter, p);
        InvalidateRect(hwnd, nullptr, FALSE);
        if (!animTimer) animTimer = SetTimer(hwnd, 4001, 16, nullptr);
    }

    void CaptureSelf(const std::wstring& path) {
        if (!memDc) return;
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

    LRESULT Handle(UINT msg, WPARAM wp, LPARAM lp) {
        switch (msg) {
            case WM_CREATE:
                return 0;
            case WM_SIZE:
                LayoutAll();
                InvalidateRect(hwnd, nullptr, FALSE);
                return 0;
            case WM_ERASEBKGND:
                return 1;
            case WM_PAINT: {
                PAINTSTRUCT ps{};
                BeginPaint(hwnd, &ps);
                OnPaint();
                EndPaint(hwnd, &ps);
                return 0;
            }
            case WM_MOUSEMOVE: {
                POINT p{static_cast<short>(LOWORD(lp)), static_cast<short>(HIWORD(lp))};
                Widget* t = captured ? pressed : WidgetAt(p);
                if (!captured) SetHot(t);
                if (t) t->OnMouse(ME::Move, p);
                bool hand = t != nullptr;
                SetCursor(LoadCursorW(nullptr, hand ? IDC_HAND : IDC_ARROW));
                TRACKMOUSEEVENT tme{sizeof(tme), TME_LEAVE, hwnd, 0};
                TrackMouseEvent(&tme);
                return 0;
            }
            case WM_MOUSELEAVE:
                SetHot(nullptr);
                return 0;
            case WM_LBUTTONDOWN: {
                POINT p{static_cast<short>(LOWORD(lp)), static_cast<short>(HIWORD(lp))};
                Widget* t = WidgetAt(p);
                if (t) {
                    pressed = t;
                    captured = true;
                    SetCapture(hwnd);
                    t->OnMouse(ME::Down, p);
                    InvalidateRect(hwnd, nullptr, FALSE);
                }
                return 0;
            }
            case WM_LBUTTONUP: {
                POINT p{static_cast<short>(LOWORD(lp)), static_cast<short>(HIWORD(lp))};
                if (captured) {
                    ReleaseCapture();
                    captured = false;
                    Widget* t = pressed;
                    pressed = nullptr;
                    if (t) {
                        t->OnMouse(ME::Up, p);
                        if (t->HitTest(p)) t->OnMouse(ME::Click, p);
                        InvalidateRect(hwnd, nullptr, FALSE);
                    }
                }
                return 0;
            }
            case WM_KEYDOWN:
                if (wp == VK_ESCAPE) {
                    result.action = Action::Cancel;
                    done = true;
                    return 0;
                }
                if (wp == VK_RETURN) {
                    btnInstall.onClick();
                    return 0;
                }
                return 0;
            case WM_TIMER:
                if (wp == 4001) {
                    static ULONGLONG last = 0;
                    const ULONGLONG now = GetTickCount64();
                    const float dt = last ? static_cast<float>(now - last) : 16.f;
                    last = now;
                    bool active = false;
                    for (auto* wdt : widgets) {
                        if (wdt->Tick(dt)) active = true;
                    }
                    InvalidateRect(hwnd, nullptr, FALSE);
                    if (!active) {
                        KillTimer(hwnd, 4001);
                        animTimer = 0;
                    }
                    return 0;
                }
                if (wp == kShotTimer) {
                    KillTimer(hwnd, kShotTimer);
                    UpdateWindow(hwnd);
                    wchar_t tmp[MAX_PATH] = {};
                    GetTempPathW(MAX_PATH, tmp);
                    CaptureSelf(std::wstring(tmp) + L"tig-setup.png");
                    result.action = Action::Cancel;
                    done = true;
                    return 0;
                }
                return 0;
            case WM_CLOSE:
                result.action = Action::Cancel;
                done = true;
                return 0;
            case WM_DESTROY:
                if (memBmp) DeleteObject(memBmp);
                if (memDc) DeleteDC(memDc);
                memBmp = nullptr;
                memDc = nullptr;
                return 0;
            default:
                break;
        }
        return DefWindowProcW(hwnd, msg, wp, lp);
    }

    static LRESULT CALLBACK WndProc(HWND h, UINT m, WPARAM w, LPARAM l) {
        if (m == WM_NCCREATE) {
            auto* cs = reinterpret_cast<CREATESTRUCTW*>(l);
            SetWindowLongPtrW(h, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(cs->lpCreateParams));
            return TRUE;
        }
        auto* self = reinterpret_cast<SetupWnd*>(GetWindowLongPtrW(h, GWLP_USERDATA));
        if (!self) return DefWindowProcW(h, m, w, l);
        return self->Handle(m, w, l);
    }
};
}  // namespace

Result RunWizard(HINSTANCE hinst) {
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = &SetupWnd::WndProc;
    wc.hInstance = hinst;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hIcon = static_cast<HICON>(
        LoadImageW(hinst, MAKEINTRESOURCEW(1), IMAGE_ICON, 64, 64, LR_DEFAULTCOLOR));
    wc.lpszClassName = kWndClass;
    RegisterClassExW(&wc);

    SetupWnd wnd;
    const int sw = GetSystemMetrics(SM_CXSCREEN);
    const int sh = GetSystemMetrics(SM_CYSCREEN);
    const int x = (sw - kWinW) / 2;
    const int y = (sh - kWinH) / 2 - 20;
    wnd.hwnd = CreateWindowExW(WS_EX_APPWINDOW, kWndClass,
                               L"TrayIconGuard — Setup",
                               WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU, x, y, kWinW, kWinH,
                               nullptr, nullptr, hinst, &wnd);
    if (!wnd.hwnd) {
        Result r;
        r.action = Action::Portable;
        return r;
    }
    const BOOL dark = theme::IsDark() ? TRUE : FALSE;
    DwmSetWindowAttribute(wnd.hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark, sizeof(dark));
    wnd.LayoutAll();
    ShowWindow(wnd.hwnd, SW_SHOWNORMAL);
    UpdateWindow(wnd.hwnd);
    wchar_t shotEnv[MAX_PATH] = {};
    if (GetEnvironmentVariableW(L"TIG_SETUP_SHOT", shotEnv, MAX_PATH))
        SetTimer(wnd.hwnd, kShotTimer, 900, nullptr);

    MSG msg{};
    while (!wnd.done && GetMessageW(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    if (IsWindow(wnd.hwnd)) DestroyWindow(wnd.hwnd);
    return wnd.result;
}

}  // namespace tig::ui::setup
