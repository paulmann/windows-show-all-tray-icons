#include "app/app.h"

#include <ole2.h>
#include <shellapi.h>

#include "core/win_compat.h"
#include "core/installer.h"
#include "core/version.h"
#include "core/update.h"
#include <ctime>

#include "core/autostart.h"
#include "core/guard.h"
#include "core/log.h"
#include "core/os.h"
#include "core/settings.h"
#include "core/trayicons.h"
#include "ui/gfx.h"
#include "ui/lang/strings.h"
#include "ui/mainwindow.h"
#include "ui/setupwizard.h"
#include "ui/theme.h"
#include "ui/trayicon.h"
#include "util/fs.h"
#include "util/str.h"

namespace tig::app {

namespace {
constexpr wchar_t kMutexName[] = L"TrayIconGuard.SingleInstance.v8";
constexpr wchar_t kIpcClass[] = L"TrayIconGuard.Ipc.v8";
HANDLE g_mutex = nullptr;
HWND g_ipcHwnd = nullptr;
ui::MainWindow g_mainWindow;

LRESULT CALLBACK IpcWndProc(HWND h, UINT m, WPARAM w, LPARAM l) {
    if (m == WM_COPYDATA) {
        auto* cds = reinterpret_cast<COPYDATASTRUCT*>(l);
        if (cds->dwData == 0x54494738 && cds->lpData) {
            const std::wstring verb(static_cast<const wchar_t*>(cds->lpData));
            if (verb == L"show") {
                ShowWindow(g_mainWindow.Hwnd(), SW_SHOWNORMAL);
                SetForegroundWindow(g_mainWindow.Hwnd());
            } else if (verb == L"toggle-guard") {
                const guard::Stats gs = guard::GetStats();
                if (gs.paused)
                    guard::Resume();
                else
                    guard::Pause();
                ui::tray::UpdateIcon();
                g_mainWindow.NotifyDataChanged();
            } else if (verb == L"exit") {
                PostMessageW(g_mainWindow.Hwnd(), WM_CLOSE, 0, 0);
            }
            return 1;
        }
        return 0;
    }
    return DefWindowProcW(h, m, w, l);
}

void CreateIpcWindow() {
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = &IpcWndProc;
    wc.hInstance = GetModuleHandleW(nullptr);
    wc.lpszClassName = kIpcClass;
    RegisterClassExW(&wc);
    g_ipcHwnd = CreateWindowExW(0, kIpcClass, L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr,
                                GetModuleHandleW(nullptr), nullptr);
}
}  // namespace

int Run(HINSTANCE hinst, const cli::ParsedArgs& args) {
    // single instance
    g_mutex = CreateMutexW(nullptr, TRUE, kMutexName);
    const bool already = GetLastError() == ERROR_ALREADY_EXISTS;
    if (already) {
        const std::wstring verb = args.minimized ? L"" : L"show";
        if (!verb.empty()) cli::SendToRunningInstance(verb);
        return 0;
    }

    compat::SetProcessDpiPerMonitorV2();
    OleInitialize(nullptr);
    if (!gfx::Init()) return 3;

    settings::Load();
    l10n::SetLanguage(settings::Get().language);
    log::Init();
    log::Info(std::wstring(L"=== TrayIconGuard ") + kVersion + L" starting ===");
    log::Info(L"OS: " + os::Get().caption);
    ui::theme::Init();

    // embedded first-run installer wizard (dependency-free, per-user)
    if (args.mode == cli::Mode::Gui && settings::Get().installMode == L"unknown") {
        const ui::setup::Result wr = ui::setup::RunWizard(hinst);
        if (wr.action == ui::setup::Action::Cancel) {
            log::Info(L"setup cancelled by user");
            ReleaseMutex(g_mutex);
            CloseHandle(g_mutex);
            return 0;
        }
        if (wr.action == ui::setup::Action::Install) {
            std::wstring err;
            if (installer::Install(wr.opts, err)) {
                if (installer::NeedsRelaunch()) {
                    const std::wstring dest =
                        settings::Get().installDir + L"\\TrayIconGuard.exe";
                    settings::Save();
                    log::Info(L"relaunching from " + dest);
                    ReleaseMutex(g_mutex);
                    CloseHandle(g_mutex);
                    ShellExecuteW(nullptr, L"open", dest.c_str(),
                                  args.minimized ? L"--minimized" : L"", nullptr,
                                  SW_SHOWNORMAL);
                    return 0;
                }
            } else {
                log::Error(L"install failed: " + err);
                settings::Get().installMode = L"portable";
                settings::Save();
            }
        } else {
            settings::Get().installMode = L"portable";
            settings::Save();
            log::Info(L"portable mode chosen");
        }
    }

    store::Rescan();
    const auto counts = store::GetCounts(store::Current());
    log::Info(str::Format(L"tray store: %d icons (%d promoted, %d hidden)", counts.total,
                          counts.promoted, counts.hidden));

    if (!ui::MainWindow::Instance().Create(hinst, args.minimized || settings::Get().startMinimized,
                                           args.mode == cli::Mode::UiTest ? args.uiTestPage
                                                                          : std::wstring(),
                                           args.mode == cli::Mode::UiTest ? 1500 : 0)) {
        log::Error(L"main window creation failed");
        return 3;
    }
    CreateIpcWindow();
    ui::tray::Init(ui::MainWindow::Instance().Hwnd());

    // guard wiring: worker thread -> UI thread
    guard::SetEventSink([](guard::EventKind kind, const std::wstring& detail) {
        ui::MainWindow::Instance().PostGuardEvent(static_cast<int>(kind), detail);
    });

    const bool firstRun = settings::IsFirstRun();
    if (firstRun) {
        // first-run defaults: guard on, promote everything now
        settings::Get().guardEnabled = true;
        settings::Save();
        std::wstring detail;
        const int n = guard::PromoteAllNow(detail);
        log::Event(str::Format(L"first run: promoted %d icon(s)", n));
        store::Rescan();
    }

    if (settings::Get().guardEnabled) guard::Start();
    ui::tray::UpdateIcon();

    if (firstRun) {
        ui::tray::Balloon(l10n::t(l10n::S::BalloonWelcomeTitle),
                          l10n::t(l10n::S::BalloonWelcomeText), true);
    }

    // silent update auto-check (opt-in, at most once per 24 h)
    if (settings::Get().updateCheckEnabled) {
        const unsigned long long nowEpoch =
            static_cast<unsigned long long>(time(nullptr));
        if (nowEpoch - settings::Get().updateLastCheck > 86400) {
            settings::Get().updateLastCheck = nowEpoch;
            settings::Save();
            CreateThread(nullptr, 0,
                         [](LPVOID) -> DWORD {
                             const update::FeedInfo fi =
                                 update::FetchFeed(update::EffectiveFeedUrl());
                             if (fi.ok && str::CompareVersions(fi.version, kVersion) > 0) {
                                 auto* copy = new std::wstring(fi.version);
                                 PostMessageW(ui::MainWindow::Instance().Hwnd(), WM_APP + 61, 0,
                                              reinterpret_cast<LPARAM>(copy));
                             }
                             return 0;
                         },
                         nullptr, 0, nullptr);
        }
    }

    // autostart consistency (settings vs registry)
    if (settings::Get().autoStart && !autostart::IsInstalled()) autostart::Install();

    MSG msg{};
    while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    guard::Stop();
    store::Shutdown();
    settings::Save();
    log::Info(L"=== TrayIconGuard exiting ===");
    gfx::Shutdown();
    OleUninitialize();
    ReleaseMutex(g_mutex);
    CloseHandle(g_mutex);
    return static_cast<int>(msg.wParam);
}

}  // namespace tig::app
