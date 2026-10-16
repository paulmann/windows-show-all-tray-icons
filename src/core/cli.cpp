#include "core/cli.h"

#include "core/version.h"

#include <windows.h>

#include <cstdio>

#include "core/autostart.h"
#include "core/backup.h"
#include "core/explorer.h"
#include "core/installer.h"
#include "ui/lang/strings.h"
#include "core/guard.h"
#include "core/json.h"
#include "core/legacy.h"
#include "core/log.h"
#include "core/os.h"
#include "core/settings.h"
#include "core/trayicons.h"
#include "core/update.h"
#include <shellapi.h>
#include "util/fs.h"
#include "util/str.h"

namespace tig::cli {

bool SendExitToRunningInstance();

namespace {

constexpr wchar_t kIpcWindowClass[] = L"TrayIconGuard.Ipc.v8";
constexpr DWORD kIpcMagic = 0x54494738;  // 'TIG8'

void Print(const std::wstring& s) {
    HANDLE con = GetStdHandle(STD_OUTPUT_HANDLE);
    const DWORD type = (con && con != INVALID_HANDLE_VALUE) ? GetFileType(con) : FILE_TYPE_UNKNOWN;
    std::wstring out = s + L"\n";
    if (type == FILE_TYPE_CHAR) {
        DWORD written = 0;
        if (WriteConsoleW(con, out.c_str(), static_cast<DWORD>(out.size()), &written, nullptr)) return;
    }
    // Not a console (pipe, file, or nothing inherited): emit UTF-8 straight through the OS
    // handle. WriteFile is used instead of fwrite(stdout) because a GUI-subsystem process does
    // not necessarily have the CRT stdout bound to the handle it inherited — which is exactly
    // why `TrayIconGuard.exe --status --json > state.json` used to produce an empty file.
    const std::string u8 = str::ToUtf8(out);
    if (con && con != INVALID_HANDLE_VALUE) {
        DWORD written = 0;
        if (WriteFile(con, u8.data(), static_cast<DWORD>(u8.size()), &written, nullptr)) return;
    }
    fwrite(u8.data(), 1, u8.size(), stdout);
    fflush(stdout);
}

void AttachConsoleIfPossible() {
    if (GetConsoleWindow()) return;
    if (!AttachConsole(ATTACH_PARENT_PROCESS)) return;
    // Bind the console streams only for handles that were not inherited. A redirected
    // stdout/stderr (a pipe or a file: `> state.json`, RMM capture, CI logs) MUST stay
    // redirected — rebinding it to CONOUT$ silently throws the CLI output away, which is how
    // the documented `--status --json` automation broke on real Windows.
    auto bindIfUnbound = [](DWORD which, FILE* stream) {
        HANDLE h = GetStdHandle(which);
        if (h && h != INVALID_HANDLE_VALUE) return;
        (void)freopen("CONOUT$", "w", stream);
    };
    bindIfUnbound(STD_OUTPUT_HANDLE, stdout);
    bindIfUnbound(STD_ERROR_HANDLE, stderr);
}

int PrintStatus(bool asJson) {
    const bool supported = store::Supported();
    const std::vector<TrayIconEntry> icons = supported ? store::Rescan() : std::vector<TrayIconEntry>();
    const store::Counts c = store::GetCounts(icons);
    const guard::Stats gs = guard::GetStats();
    DWORD autoTray = 0;
    const bool hasAutoTray = legacy::GetEnableAutoTray(autoTray);
    const int sca = legacy::CountHideScaPolicies();

    if (asJson) {
        json::Value v = json::Value::MakeObject();
        v.Set(L"app", json::Value::MakeString(std::wstring(L"TrayIconGuard ") + kVersion));
        v.Set(L"os", json::Value::MakeString(os::Get().caption));
        v.Set(L"build", json::Value::MakeNumber(static_cast<int>(os::Get().build)));
        v.Set(L"storeSupported", json::Value::MakeBool(supported));
        v.Set(L"total", json::Value::MakeNumber(c.total));
        v.Set(L"promoted", json::Value::MakeNumber(c.promoted));
        v.Set(L"hidden", json::Value::MakeNumber(c.hidden));
        v.Set(L"excluded", json::Value::MakeNumber(c.excluded));
        v.Set(L"enableAutoTray", json::Value::MakeNumber(hasAutoTray ? static_cast<int>(autoTray) : -1));
        v.Set(L"hideScaPolicies", json::Value::MakeNumber(sca));
        v.Set(L"autostart", json::Value::MakeBool(autostart::IsInstalled()));
        json::Value arr = json::Value::MakeArray();
        for (const auto& e : icons) {
            json::Value o = json::Value::MakeObject();
            o.Set(L"id", json::Value::MakeString(e.id));
            o.Set(L"exe", json::Value::MakeString(e.exePath));
            o.Set(L"name", json::Value::MakeString(e.friendly));
            o.Set(L"promoted", json::Value::MakeBool(e.promoted));
            o.Set(L"excluded", json::Value::MakeBool(e.excluded));
            arr.Push(o);
        }
        v.Set(L"icons", arr);
        Print(json::Write(v, true));
        return 0;
    }

    Print(std::wstring(L"TrayIconGuard ") + kVersion + L" \"Aurora\" — status");
    Print(L"  OS:               " + os::Get().caption);
    Print(std::wstring(L"  Icon store:       ") +
          (supported ? L"NotifyIconSettings (per-icon)" : L"NOT SUPPORTED on this build"));
    Print(str::Format(L"  Icons:            %d total, %d promoted, %d hidden, %d excluded",
                      c.total, c.promoted, c.hidden, c.excluded));
    Print(str::Format(L"  EnableAutoTray:   %s",
                      !hasAutoTray ? L"(absent)" : autoTray == 0 ? L"0 (show-all legacy)" : L"1"));
    Print(str::Format(L"  HideSCA* policies: %d active", sca));
    Print(std::wstring(L"  Autostart:        ") + (autostart::IsInstalled() ? L"installed" : L"not installed"));
    Print(L"  Guard (this CLI): n/a (use GUI or --watch)");
    (void)gs;
    return 0;
}

}  // namespace

void PrintLine(const std::wstring& text) { Print(text); }

std::wstring HelpText() {
    return
        L"TrayIconGuard " TIG_VERSION_A " \"Aurora\" — keep every tray icon visible "
        L"(Windows 10/11)\n"
        L"\n"
        L"Usage: TrayIconGuard.exe [options]\n"
        L"\n"
        L"  (no args)            start the tray-resident GUI\n"
        L"  --minimized          start GUI hidden in the notification area\n"
        L"  --show               activate the window of a running instance\n"
        L"  --toggle-guard       pause/resume the guard of a running instance\n"
        L"  --status [--json]    print tray state and exit\n"
        L"  --promote-all        promote every hidden icon, then exit\n"
        L"  --restore-defaults   delete IsPromoted values (hand control to Windows)\n"
        L"  --restart-explorer   safe shell restart, then exit\n"
        L"  --backup             write a JSON snapshot, then exit\n"
        L"  --restore-latest     restore newest snapshot, then exit\n"
        L"  --watch              headless guard loop (event-driven watcher, no GUI)\n"
        L"  --install-autostart  add HKCU Run entry (--minimized)\n"
        L"  --uninstall-autostart remove HKCU Run entry\n"
        L"  --uninstall          remove shortcuts, autostart and the installed copy\n"
        L"  --install-machine <dir> [--autostart] [--desktop] [--menu]\n"
        L"                       all-users install body (must run elevated; UAC child)\n"
        L"  --ui-test [page]     QA mode: render GUI offscreen and exit\n"
        L"  --version            print version and exit\n"
        L"  --help               this text\n"
        L"\n"
        L"Exit codes: 0 ok, 1 invalid arguments, 2 unsupported OS, 3 partial failure.\n";
}

bool Parse(const std::vector<std::wstring>& args, ParsedArgs& out, std::wstring& err) {
    for (size_t i = 0; i < args.size(); ++i) {
        const std::wstring a = str::ToLower(str::Trim(args[i]));
        if (a == L"--help" || a == L"-h" || a == L"/?") out.mode = Mode::Help;
        else if (a == L"--version" || a == L"-v") out.mode = Mode::Version;
        else if (a == L"--status") out.mode = Mode::Status;
        else if (a == L"--json") out.json = true;
        else if (a == L"--force") out.force = true;
        else if (a == L"--minimized" || a == L"-m") out.minimized = true;
        else if (a == L"--promote-all") out.mode = Mode::PromoteAll;
        else if (a == L"--restore-defaults") out.mode = Mode::RestoreDefaults;
        else if (a == L"--restart-explorer") out.mode = Mode::RestartExplorer;
        else if (a == L"--backup") out.mode = Mode::Backup;
        else if (a == L"--restore-latest") out.mode = Mode::RestoreLatest;
        else if (a == L"--watch") out.mode = Mode::Watch;
        else if (a == L"--toggle-guard") out.mode = Mode::ToggleGuard;
        else if (a == L"--show") out.mode = Mode::Show;
        else if (a == L"--install-autostart") out.mode = Mode::InstallAutostart;
        else if (a == L"--uninstall-autostart") out.mode = Mode::UninstallAutostart;
        else if (a == L"--uninstall") out.mode = Mode::Uninstall;
        else if (a == L"--autostart") { out.mAutostart = true; }
        else if (a == L"--desktop") { out.mDesktop = true; }
        else if (a == L"--menu") { out.mMenu = true; }
        else if (a == L"--install-machine") {
            out.mode = Mode::InstallMachine;
            if (i + 1 < args.size()) { out.machineDir = args[i + 1]; ++i; }
            else { err = L"--install-machine requires a folder argument"; return false; }
        }
        else if (a == L"--check-update") out.mode = Mode::CheckUpdate;
        else if (a == L"--update-now") out.mode = Mode::UpdateNow;
        else if (a == L"--mode") {
            out.mode = Mode::SetMode;
            if (i + 1 < args.size()) {
                out.modeValue = str::ToLower(args[i + 1]);
                ++i;
            }
        }
        else if (a == L"--ui-test") {
            out.mode = Mode::UiTest;
            if (i + 1 < args.size() && args[i + 1][0] != L'-') {
                out.uiTestPage = str::ToLower(args[i + 1]);
                ++i;
            }
        } else {
            err = L"unknown argument: " + args[i];
            return false;
        }
    }
    if (out.mode == Mode::InstallMachine && !out.mAutostart && !out.mDesktop && !out.mMenu) {
        out.mAutostart = out.mDesktop = out.mMenu = true;  // sensible defaults
    }
    return true;
}

bool SendExitToRunningInstance() { return SendToRunningInstance(L"exit"); }

bool SendToRunningInstance(const std::wstring& verb) {
    HWND target = FindWindowW(kIpcWindowClass, nullptr);
    if (!target) return false;
    COPYDATASTRUCT cds{};
    cds.dwData = kIpcMagic;
    cds.cbData = static_cast<DWORD>((verb.size() + 1) * sizeof(wchar_t));
    cds.lpData = const_cast<wchar_t*>(verb.c_str());
    DWORD_PTR result = 0;
    return SendMessageTimeoutW(target, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&cds),
                               SMTO_ABORTIFHUNG, 3000, &result) != 0;
}

int ExecuteHeadless(const ParsedArgs& a) {
    settings::Load();
    log::Init();
    switch (a.mode) {
        case Mode::Help:
            AttachConsoleIfPossible();
            Print(HelpText());
            return 0;
        case Mode::Version:
            AttachConsoleIfPossible();
            Print(std::wstring(L"TrayIconGuard ") + kVersion + L" (native x64, zero dependencies)");
            return 0;
        case Mode::Status:
            AttachConsoleIfPossible();
            return PrintStatus(a.json);
        case Mode::Show:
            return SendToRunningInstance(L"show") ? 0 : 3;
        case Mode::ToggleGuard:
            return SendToRunningInstance(L"toggle-guard") ? 0 : 3;
        case Mode::PromoteAll: {
            if (!store::Supported()) {
                AttachConsoleIfPossible();
                Print(L"error: NotifyIconSettings store not supported on this Windows build");
                return 2;
            }
            std::wstring detail;
            const int n = guard::PromoteAllNow(detail);
            if (settings::Get().legacyBelt) legacy::ApplyEnableAutoTray();
            legacy::RemoveHideScaPolicies();
            if (settings::Get().autoBackup) {
                std::wstring path, err;
                backup::Create(path, err, L"cli");
            }
            AttachConsoleIfPossible();
            Print(str::Format(L"promoted %d icon(s)%s", n,
                              detail.empty() ? L"" : (L": " + detail).c_str()));
            return n >= 0 ? 0 : 3;
        }
        case Mode::RestoreDefaults: {
            if (!store::Supported()) return 2;
            const int n = store::RestoreDefaults();
            legacy::RemoveEnableAutoTray();
            AttachConsoleIfPossible();
            Print(str::Format(L"restored Windows defaults on %d icon(s)", n));
            return n >= 0 ? 0 : 3;
        }
        case Mode::RestartExplorer: {
            std::wstring err;
            const bool ok = explorer::Restart(err);
            AttachConsoleIfPossible();
            Print(ok ? L"Explorer restarted" : L"Explorer restart failed: " + err);
            return ok ? 0 : 3;
        }
        case Mode::Backup: {
            std::wstring path, err;
            const bool ok = backup::Create(path, err, L"cli");
            AttachConsoleIfPossible();
            Print(ok ? L"backup: " + path : L"backup failed: " + err);
            return ok ? 0 : 3;
        }
        case Mode::RestoreLatest: {
            const auto list = backup::List();
            if (list.empty()) {
                AttachConsoleIfPossible();
                Print(L"no snapshots found");
                return 3;
            }
            std::wstring err;
            const int applied = backup::Restore(list.front().fileName, err);
            AttachConsoleIfPossible();
            Print(applied >= 0 ? str::Format(L"restored %s (%d icons)", list.front().fileName.c_str(), applied)
                               : L"restore failed: " + err);
            return applied >= 0 ? 0 : 3;
        }
        case Mode::InstallMachine: {
            AttachConsoleIfPossible();
            if (!installer::IsElevated()) {
                Print(L"error: --install-machine requires elevation (UAC)");
                return 1;
            }
            installer::Options opt;
            opt.dir = a.machineDir;
            opt.scope = installer::Scope::Machine;
            opt.autostart = a.mAutostart;
            opt.desktopIcon = a.mDesktop;
            opt.startMenuIcon = a.mMenu;
            std::wstring err;
            const bool ok = installer::Install(opt, err);
            Print(ok ? L"machine install ok" : L"machine install failed: " + err);
            return ok ? 0 : 3;
        }
        case Mode::InstallAutostart:
            return autostart::Install() ? 0 : 3;
        case Mode::UninstallAutostart:
            return autostart::Uninstall() ? 0 : 3;
        case Mode::Uninstall: {
            AttachConsoleIfPossible();
            std::wstring err;
            const bool ok = installer::Uninstall(err);
            Print(ok ? l10n::t(l10n::S::UninstallDone) : L"uninstall failed: " + err);
            return ok ? 0 : 3;
        }
        case Mode::CheckUpdate: {
            AttachConsoleIfPossible();
            const update::FeedInfo fi = update::FetchFeed(update::EffectiveFeedUrl());
            if (!fi.ok) {
                Print(L"update check failed: " + fi.err);
                return 3;
            }
            Print(str::Format(L"feed: %s  latest=%s  newer=%s", update::EffectiveFeedUrl().c_str(),
                              fi.version.c_str(),
                              str::CompareVersions(fi.version, kVersion) > 0 ? L"yes" : L"no"));
            return 0;
        }
        case Mode::UpdateNow: {
            AttachConsoleIfPossible();
            const update::FeedInfo fi = update::FetchFeed(update::EffectiveFeedUrl());
            if (!fi.ok) {
                Print(L"update check failed: " + fi.err);
                return 3;
            }
            if (str::CompareVersions(fi.version, kVersion) <= 0) {
                Print(L"already up to date (" + fi.version + L")");
                return 0;
            }
            wchar_t tmp[MAX_PATH] = {};
            GetTempPathW(MAX_PATH, tmp);
            const std::wstring dest = std::wstring(tmp) + L"TrayIconGuard-update.exe";
            std::wstring err;
            Print(L"downloading " + fi.url);
            if (!update::DownloadFile(fi.url, dest, err)) {
                Print(L"download failed: " + err);
                return 3;
            }
            std::wstring sha;
            if (!update::Sha256File(dest, sha) || sha != fi.sha256) {
                Print(L"sha256 mismatch (feed=" + fi.sha256 + L" file=" + sha + L")");
                DeleteFileW(dest.c_str());
                return 3;
            }
            if (!update::ApplyUpdate(dest, err)) {
                Print(L"apply failed: " + err);
                return 3;
            }
            DeleteFileW(dest.c_str());
            Print(L"updated to " + fi.version + L"; relaunching…");
            wchar_t self[MAX_PATH] = {};
            GetModuleFileNameW(nullptr, self, MAX_PATH);
            ShellExecuteW(nullptr, L"open", self, nullptr, nullptr, SW_SHOWNORMAL);
            return 0;
        }
        case Mode::SetMode: {
            AttachConsoleIfPossible();
            guard::SetDisplayMode(a.modeValue);
            Print(L"display mode: " + guard::DisplayMode());
            return 0;
        }
        case Mode::Watch: {
            if (!store::Supported()) return 2;
            AttachConsoleIfPossible();
            Print(L"guard active (Ctrl+C to stop)...");
            guard::SetEventSink([](guard::EventKind kind, const std::wstring& detail) {
                switch (kind) {
                    case guard::EventKind::Promoted:
                        Print(L"[event] promoted " + detail);
                        break;
                    case guard::EventKind::Started:
                        Print(L"[event] watcher armed");
                        break;
                    case guard::EventKind::ExplorerRestarted:
                        Print(L"[event] Explorer restarted");
                        break;
                    default:
                        break;
                }
            });
            if (!guard::Start()) return 2;
            SetConsoleCtrlHandler([](DWORD) -> BOOL {
                guard::Stop();
                ExitProcess(0);
                return TRUE;
            }, TRUE);
            for (;;) Sleep(1000);
        }
        default:
            return 1;
    }
}

}  // namespace tig::cli
