#include "core/installer.h"

#include <windows.h>

#include <initguid.h>
#include <knownfolders.h>
#include <shlobj.h>
#include <shobjidl.h>

#include "core/autostart.h"
#include "core/cli.h"
#include "core/log.h"
#include "core/registry.h"
#include "core/settings.h"
#include "util/fs.h"
#include "util/str.h"

namespace tig::installer {

namespace {
const wchar_t* kUninstallPath = L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\TrayIconGuard";

std::wstring KnownFolder(REFKNOWNFOLDERID id) {
    PWSTR raw = nullptr;
    if (FAILED(SHGetKnownFolderPath(id, KF_FLAG_CREATE, nullptr, &raw))) return {};
    std::wstring out(raw);
    CoTaskMemFree(raw);
    return out;
}

bool CreateShortcut(const std::wstring& lnk, const std::wstring& target,
                    const std::wstring& args, const std::wstring& desc) {
    IShellLinkW* link = nullptr;
    if (FAILED(CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER, IID_IShellLinkW,
                                reinterpret_cast<void**>(&link))))
        return false;
    link->SetPath(target.c_str());
    if (!args.empty()) link->SetArguments(args.c_str());
    link->SetIconLocation(target.c_str(), 0);
    link->SetDescription(desc.c_str());
    link->SetWorkingDirectory(str::DirNameOf(target).c_str());
    IPersistFile* pf = nullptr;
    bool ok = false;
    if (SUCCEEDED(link->QueryInterface(IID_IPersistFile, reinterpret_cast<void**>(&pf)))) {
        ok = SUCCEEDED(pf->Save(lnk.c_str(), TRUE));
        pf->Release();
    }
    link->Release();
    return ok;
}
}  // namespace

std::wstring DefaultDir() {
    std::wstring base = KnownFolder(FOLDERID_LocalAppData);
    if (base.empty()) base = KnownFolder(FOLDERID_Profile);
    return base + L"\\Programs\\TrayIconGuard";
}

std::wstring DesktopLnkPath() { return KnownFolder(FOLDERID_Desktop) + L"\\TrayIconGuard.lnk"; }
std::wstring StartMenuLnkPath() { return KnownFolder(FOLDERID_Programs) + L"\\TrayIconGuard.lnk"; }
std::wstring StartMenuUninstallLnkPath() {
    return KnownFolder(FOLDERID_Programs) + L"\\Uninstall TrayIconGuard.lnk";
}

bool IsInstalledHere() {
    const std::wstring dir = settings::Get().installDir;
    return settings::Get().installMode == L"installed" && !dir.empty() &&
           str::IEquals(fs::ModuleDir(), dir);
}

bool NeedsRelaunch() {
    const std::wstring dir = settings::Get().installDir;
    return !dir.empty() && !str::IEquals(fs::ModuleDir(), dir);
}

bool Install(const Options& opt, std::wstring& err) {
    const std::wstring dir = opt.dir.empty() ? DefaultDir() : opt.dir;
    if (!fs::EnsureDir(dir)) {
        err = L"cannot create folder " + dir;
        return false;
    }
    const std::wstring dest = dir + L"\\TrayIconGuard.exe";
    const std::wstring self = fs::ModulePath();
    if (!str::IEquals(self, dest)) {
        if (!CopyFileW(self.c_str(), dest.c_str(), FALSE)) {
            err = L"cannot copy exe to " + dest + L" (error " +
                  std::to_wstring(GetLastError()) + L")";
            return false;
        }
    }
    Settings& s = settings::Get();
    s.installMode = L"installed";
    s.installDir = dir;

    if (opt.desktopIcon) {
        if (!CreateShortcut(DesktopLnkPath(), dest, L"", L"Keep every tray icon visible"))
            log::Warn(L"desktop shortcut failed");
    }
    if (opt.startMenuIcon) {
        CreateShortcut(StartMenuLnkPath(), dest, L"", L"Keep every tray icon visible");
        CreateShortcut(StartMenuUninstallLnkPath(), dest, L"--uninstall", L"Uninstall TrayIconGuard");
    }
    if (opt.autostart) {
        autostart::InstallAt(dest);
        s.autoStart = true;
    } else {
        autostart::Uninstall();
        s.autoStart = false;
    }
    // Apps & Features uninstall entry
    reg::SetString(HKEY_CURRENT_USER, kUninstallPath, L"DisplayName", L"TrayIconGuard");
    reg::SetString(HKEY_CURRENT_USER, kUninstallPath, L"DisplayVersion", L"8.3.0");
    reg::SetString(HKEY_CURRENT_USER, kUninstallPath, L"Publisher", L"TrayIconGuard Project");
    reg::SetString(HKEY_CURRENT_USER, kUninstallPath, L"InstallLocation", dir);
    reg::SetString(HKEY_CURRENT_USER, kUninstallPath, L"UninstallString",
                   L"\"" + dest + L"\" --uninstall");
    reg::SetString(HKEY_CURRENT_USER, kUninstallPath, L"DisplayIcon", dest + L",0");
    reg::SetDword(HKEY_CURRENT_USER, kUninstallPath, L"NoModify", 1);
    reg::SetDword(HKEY_CURRENT_USER, kUninstallPath, L"NoRepair", 1);
    settings::Save();
    log::Info(L"installed to " + dir);
    return true;
}

bool Uninstall(std::wstring& err) {
    // ask a running GUI instance to exit first
    cli::SendExitToRunningInstance();
    Sleep(1200);

    const std::wstring dir = settings::Get().installDir.empty() ? DefaultDir()
                                                                : settings::Get().installDir;
    const std::wstring dest = dir + L"\\TrayIconGuard.exe";
    DeleteFileW(DesktopLnkPath().c_str());
    DeleteFileW(StartMenuLnkPath().c_str());
    DeleteFileW(StartMenuUninstallLnkPath().c_str());
    autostart::Uninstall();
    RegDeleteTreeW(HKEY_CURRENT_USER, kUninstallPath);
    settings::Get().installMode = L"portable";
    settings::Get().installDir.clear();
    settings::Save();

    const std::wstring self = fs::ModulePath();
    if (str::IEquals(self, dest)) {
        // delayed self-delete: detached cmd waits, then removes exe + folder
        std::wstring cmd = L"/c ping 127.0.0.1 -n 3 >nul & del /f /q \"" + dest + L"\" & rd /s /q \"" +
                           dir + L"\"";
        STARTUPINFOW si{};
        si.cb = sizeof(si);
        si.dwFlags = STARTF_USESHOWWINDOW;
        si.wShowWindow = SW_HIDE;
        PROCESS_INFORMATION pi{};
        if (!CreateProcessW(nullptr, cmd.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW,
                            nullptr, nullptr, &si, &pi)) {
            err = L"cannot schedule self-delete";
            return false;
        }
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
    } else {
        DeleteFileW(dest.c_str());
        RemoveDirectoryW(dir.c_str());
    }
    log::Info(L"uninstalled from " + dir);
    return true;
}

}  // namespace tig::installer
