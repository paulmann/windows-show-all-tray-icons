#include "ui/trayicon.h"

#include "util/str.h"

namespace tig::ui::tray {
bool HandleCommand(WORD menuId);
void OnTaskbarCreated();
}  // namespace tig::ui::tray

#include <shellapi.h>

#include "core/guard.h"
#include "core/log.h"
#include "core/settings.h"
#include "ui/gfx.h"
#include "ui/lang/strings.h"
#include "ui/mainwindow.h"

namespace tig::ui::tray {

namespace {
constexpr UINT kTrayId = 1001;
constexpr UINT WM_TRAYCB = WM_APP + 50;
constexpr WORD kCmdShow = 9001;
constexpr WORD kCmdPromote = 9002;
constexpr WORD kCmdPause = 9003;
constexpr WORD kCmdRestart = 9004;
constexpr WORD kCmdExit = 9005;
constexpr WORD kCmdModeFull = 9006;
constexpr WORD kCmdModeCustom = 9007;
constexpr WORD kCmdModeCompact = 9008;
constexpr WORD kCmdSite = 9009;
HWND g_owner = nullptr;
HWND g_msgHwnd = nullptr;
bool g_added = false;
UINT WM_TASKBARCREATED = 0;

HICON BuildIcon(bool paused, bool off) {
    Gdiplus::Bitmap* base = gfx::AppIconBitmap(GetSystemMetrics(SM_CXSMICON));
    if (!base) return nullptr;
    Gdiplus::Bitmap bmp(base->GetWidth(), base->GetHeight(), PixelFormat32bppARGB);
    {
        Gdiplus::Graphics g(&bmp);
        g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
        g.DrawImage(base, 0, 0);
        if (!off) {
            const float s = static_cast<float>(bmp.GetWidth());
            const Gdiplus::Color dot = paused ? Gdiplus::Color(255, 0xF7, 0xB5, 0x00)
                                              : Gdiplus::Color(255, 0x6C, 0xCB, 0x5F);
            Gdiplus::SolidBrush halo(Gdiplus::Color(255, 0x20, 0x20, 0x20));
            const float d = s * 0.42f;
            g.FillEllipse(&halo, s - d - 1, s - d - 1, d + 1, d + 1);
            Gdiplus::SolidBrush br(dot);
            g.FillEllipse(&br, s - d + 1, s - d + 1, d - 3, d - 3);
        }
    }
    HICON hi = nullptr;
    bmp.GetHICON(&hi);
    return hi;
}

void Fill(NOTIFYICONDATAW& nid) {
    ZeroMemory(&nid, sizeof(nid));
    nid.cbSize = sizeof(nid);
    nid.hWnd = g_msgHwnd;
    nid.uID = kTrayId;
    nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
    nid.uCallbackMessage = WM_TRAYCB;
    wcsncpy_s(nid.szTip, ARRAYSIZE(nid.szTip), L"TrayIconGuard", _TRUNCATE);
}

LRESULT CALLBACK MsgWndProc(HWND h, UINT m, WPARAM w, LPARAM l) {
    switch (m) {
        case WM_TRAYCB:
            if (l == WM_RBUTTONUP || l == NIN_KEYSELECT || l == WM_CONTEXTMENU) {
                HMENU menu = CreatePopupMenu();
                const guard::Stats gs = guard::GetStats();
                const std::wstring mode = guard::DisplayMode();
                AppendMenuW(menu, MF_STRING, kCmdShow, l10n::t(l10n::S::TrayShow));
                SetMenuDefaultItem(menu, kCmdShow, FALSE);
                AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
                AppendMenuW(menu, MF_STRING | (mode == L"full" ? MF_CHECKED : 0), kCmdModeFull,
                            l10n::t(l10n::S::ModeFull));
                AppendMenuW(menu, MF_STRING | (mode == L"custom" ? MF_CHECKED : 0), kCmdModeCustom,
                            l10n::t(l10n::S::ModeCustom));
                AppendMenuW(menu, MF_STRING | (mode == L"compact" ? MF_CHECKED : 0),
                            kCmdModeCompact, l10n::t(l10n::S::ModeCompact));
                AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
                AppendMenuW(menu, MF_STRING, kCmdPromote, l10n::t(l10n::S::TrayPromote));
                AppendMenuW(menu, MF_STRING, kCmdPause,
                            gs.paused ? l10n::t(l10n::S::TrayResume)
                                      : l10n::t(l10n::S::TrayPause));
                AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
                AppendMenuW(menu, MF_STRING, kCmdSite, l10n::t(l10n::S::TrayAuthorSite));
                AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
                AppendMenuW(menu, MF_STRING, kCmdExit, l10n::t(l10n::S::TrayExit));
                SetForegroundWindow(h);
                POINT p{};
                GetCursorPos(&p);
                TrackPopupMenu(menu, TPM_RIGHTBUTTON, p.x, p.y, 0, h, nullptr);
                DestroyMenu(menu);
                return 0;
            }
            if (l == WM_LBUTTONDBLCLK || l == NIN_BALLOONTIMEOUT) {
                if (l == WM_LBUTTONDBLCLK) HandleCommand(kCmdShow);
                return 0;
            }
            return 0;
        case WM_COMMAND:
            if (HandleCommand(LOWORD(w))) return 0;
            break;
        default:
            break;
    }
    if (WM_TASKBARCREATED && m == WM_TASKBARCREATED) {
        OnTaskbarCreated();
        return 0;
    }
    return DefWindowProcW(h, m, w, l);
}
}  // namespace

bool Init(HWND owner) {
    g_owner = owner;
    WM_TASKBARCREATED = RegisterWindowMessageW(L"TaskbarCreated");
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = &MsgWndProc;
    wc.hInstance = GetModuleHandleW(nullptr);
    wc.lpszClassName = L"TrayIconGuard.TrayMsg.v8";
    RegisterClassExW(&wc);
    g_msgHwnd = CreateWindowExW(0, L"TrayIconGuard.TrayMsg.v8", L"", 0, 0, 0, 0, 0,
                                HWND_MESSAGE, nullptr, GetModuleHandleW(nullptr), nullptr);
    if (!g_msgHwnd) return false;
    NOTIFYICONDATAW nid{};
    Fill(nid);
    nid.hIcon = BuildIcon(false, false);
    // NOTE: legacy callback version (0) on purpose — NOTIFYICON_VERSION_4 changes
    // the callback contract and broke WM_RBUTTONUP delivery on Windows 11.
    g_added = Shell_NotifyIconW(NIM_ADD, &nid) != FALSE;
    return g_added;
}

void UpdateIcon() {
    if (!g_added) return;
    const guard::Stats gs = guard::GetStats();
    NOTIFYICONDATAW nid{};
    Fill(nid);
    nid.uFlags = NIF_ICON | NIF_TIP | NIF_SHOWTIP;
    nid.hIcon = BuildIcon(gs.paused, !gs.running);
    const wchar_t* tip = !gs.running   ? l10n::t(l10n::S::StatusOff)
                         : gs.paused   ? l10n::t(l10n::S::StatusPaused)
                                       : l10n::t(l10n::S::StatusGuarding);
    wcsncpy_s(nid.szTip, ARRAYSIZE(nid.szTip), tip, _TRUNCATE);
    Shell_NotifyIconW(NIM_MODIFY, &nid);
}

void Balloon(const std::wstring& title, const std::wstring& text, bool info) {
    if (!g_added) return;
    NOTIFYICONDATAW nid{};
    Fill(nid);
    nid.uFlags = NIF_INFO;
    nid.dwInfoFlags = info ? NIIF_INFO : NIIF_WARNING;
    wcsncpy_s(nid.szInfoTitle, ARRAYSIZE(nid.szInfoTitle), title.c_str(), _TRUNCATE);
    wcsncpy_s(nid.szInfo, ARRAYSIZE(nid.szInfo), text.c_str(), _TRUNCATE);
    Shell_NotifyIconW(NIM_MODIFY, &nid);
}

void Remove() {
    if (!g_added) return;
    NOTIFYICONDATAW nid{};
    Fill(nid);
    Shell_NotifyIconW(NIM_DELETE, &nid);
    g_added = false;
}

bool HandleCommand(WORD menuId) {
    switch (menuId) {
        case kCmdShow:
            ShowWindow(g_owner, SW_SHOWNORMAL);
            SetForegroundWindow(g_owner);
            return true;
        case kCmdPromote:
            MainWindow::Instance().PromoteAllNow();
            return true;
        case kCmdPause: {
            const guard::Stats gs = guard::GetStats();
            if (gs.paused)
                guard::Resume();
            else
                guard::Pause();
            UpdateIcon();
            MainWindow::Instance().NotifyDataChanged();
            return true;
        }
        case kCmdRestart:
            MainWindow::Instance().RestartExplorerNow();
            return true;
        case kCmdModeFull:
            guard::SetDisplayMode(L"full");
            MainWindow::Instance().NotifyDataChanged();
            return true;
        case kCmdModeCustom:
            guard::SetDisplayMode(L"custom");
            MainWindow::Instance().NotifyDataChanged();
            return true;
        case kCmdModeCompact:
            guard::SetDisplayMode(L"compact");
            MainWindow::Instance().NotifyDataChanged();
            return true;
        case kCmdSite:
            ShellExecuteW(nullptr, L"open", L"https://Deynekin.com", nullptr, nullptr,
                          SW_SHOWNORMAL);
            return true;
        case kCmdExit:
            Remove();
            DestroyWindow(g_owner);
            return true;
        default:
            return false;
    }
}

void OnGuardEvent(int kind, const std::wstring& detail) {
    UpdateIcon();
    if (kind == static_cast<int>(guard::EventKind::Promoted) && settings::Get().notifications) {
        int count = 0;
        std::wstring names = detail;
        const size_t bar = detail.find(L'|');
        if (bar != std::wstring::npos) {
            count = _wtoi(detail.substr(0, bar).c_str());
            names = detail.substr(bar + 1);
        }
        Balloon(l10n::t(l10n::S::BalloonPromotedTitle),
                str::Format(l10n::t(l10n::S::BalloonPromotedText), count) +
                    (names.empty() ? L"" : L": " + names),
                true);
    }
}

void OnTaskbarCreated() {
    if (!g_msgHwnd) return;
    NOTIFYICONDATAW nid{};
    Fill(nid);
    nid.hIcon = BuildIcon(false, false);
    g_added = Shell_NotifyIconW(NIM_ADD, &nid) != FALSE;
}

}  // namespace tig::ui::tray
