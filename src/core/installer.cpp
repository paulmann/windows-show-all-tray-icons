#include "core/installer.h"

#include <windows.h>

#include <initguid.h>
#include <knownfolders.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shobjidl.h>

#include "core/autostart.h"
#include "core/cli.h"
#include "core/log.h"
#include "core/registry.h"
#include "core/settings.h"
#include "core/version.h"
#include "util/fs.h"
#include "util/str.h"

namespace tig::installer {

namespace {
const wchar_t* kUninstallPath =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\TrayIconGuard";
const wchar_t* kRunPath = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";

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

// Re-launches this exe elevated (UAC) with the given arguments and waits for it.
bool RunElevated(const std::wstring& args, DWORD& exitCode, std::wstring& err) {
    const std::wstring self = fs::ModulePath();
    SHELLEXECUTEINFOW sei{};
    sei.cbSize = sizeof(sei);
    sei.fMask = SEE_MASK_NOCLOSEPROCESS | SEE_MASK_NOASYNC;
    sei.lpVerb = L"runas";
    sei.lpFile = self.c_str();
    sei.lpParameters = args.c_str();
    sei.nShow = SW_HIDE;
    if (!ShellExecuteExW(&sei)) {
        const DWORD e = GetLastError();
        err = (e == ERROR_ACCESS_DENIED || e == ERROR_CANCELLED) ? L"elevation declined"
                                                                 : L"elevation required";
        return false;
    }
    WaitForSingleObject(sei.hProcess, 300000);  // 5 min cap
    DWORD code = 1;
    GetExitCodeProcess(sei.hProcess, &code);
    CloseHandle(sei.hProcess);
    exitCode = code;
    return true;
}

std::wstring MachineArgs(const Options& opt) {
    std::wstring a = L"--install-machine \"" + opt.dir + L"\"";
    if (opt.autostart) a += L" --autostart";
    if (opt.desktopIcon) a += L" --desktop";
    if (opt.startMenuIcon) a += L" --menu";
    return a;
}

// Writes the uninstall entry (Apps & Features) for the given scope root.
void WriteUninstallEntry(HKEY root, const std::wstring& dir, const std::wstring& dest) {
    reg::SetString(root, kUninstallPath, L"DisplayName", L"TrayIconGuard");
    reg::SetString(root, kUninstallPath, L"DisplayVersion", tig::kVersion);
    reg::SetString(root, kUninstallPath, L"Publisher", L"Mikhail Deynekin");
    reg::SetString(root, kUninstallPath, L"InstallLocation", dir + L"\\");
    reg::SetString(root, kUninstallPath, L"UninstallString", L"\"" + dest + L"\" --uninstall");
    reg::SetString(root, kUninstallPath, L"DisplayIcon", dest + L",0");
    reg::SetDword(root, kUninstallPath, L"NoModify", 1);
    reg::SetDword(root, kUninstallPath, L"NoRepair", 1);
    if (root == HKEY_LOCAL_MACHINE) reg::SetDword(root, kUninstallPath, L"AllUsers", 1);
}

// Machine-scope install body; runs inside the elevated child process.
bool InstallMachineInProc(const Options& opt, std::wstring& err) {
    const std::wstring dir = opt.dir.empty() ? DefaultMachineDir() : opt.dir;
    log::Info(L"machine install to " + dir);
    if (!fs::EnsureDir(dir)) {
        err = L"cannot create " + dir;
        log::Warn(L"machine install failed: " + err);
        return false;
    }
    const std::wstring dest = dir + L"\\TrayIconGuard.exe";
    const std::wstring self = fs::ModulePath();
    if (!str::IEquals(self, dest)) {
        if (!CopyFileW(self.c_str(), dest.c_str(), FALSE)) {
            err = L"cannot copy to " + dest + L" (error " + std::to_wstring(GetLastError()) +
                  L")";
            log::Warn(L"machine install failed: " + err);
            return false;
        }
    }
    Settings& s = settings::Get();
    s.installMode = L"installed";
    s.installDir = dir;
    s.installScope = L"machine";

    if (opt.desktopIcon) {
        if (!CreateShortcut(CommonDesktopLnkPath(), dest, L"", L"Keep every tray icon visible"))
            log::Warn(L"common desktop shortcut failed");
    }
    if (opt.startMenuIcon) {
        CreateShortcut(CommonStartMenuLnkPath(), dest, L"", L"Keep every tray icon visible");
        CreateShortcut(CommonStartMenuUninstallLnkPath(), dest, L"--uninstall",
                       L"Uninstall TrayIconGuard");
    }
    if (opt.autostart) {
        if (reg::SetString(HKEY_LOCAL_MACHINE, kRunPath, autostart::kRunValue,
                           L"\"" + dest + L"\" --minimized")) {
            log::Info(L"machine autostart installed");
            s.autoStart = true;
        } else {
            log::Warn(L"machine autostart FAILED");
            s.autoStart = false;
        }
    } else {
        reg::DeleteValue(HKEY_LOCAL_MACHINE, kRunPath, autostart::kRunValue);
        s.autoStart = false;
    }
    WriteUninstallEntry(HKEY_LOCAL_MACHINE, dir, dest);
    settings::Save();
    log::Info(L"machine install ok");
    return true;
}

// Classic per-user install body.
bool InstallUser(const Options& opt, std::wstring& err) {
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
    s.installScope = L"user";

    if (opt.desktopIcon) {
        if (!CreateShortcut(DesktopLnkPath(), dest, L"", L"Keep every tray icon visible"))
            log::Warn(L"desktop shortcut failed");
    }
    if (opt.startMenuIcon) {
        CreateShortcut(StartMenuLnkPath(), dest, L"", L"Keep every tray icon visible");
        CreateShortcut(StartMenuUninstallLnkPath(), dest, L"--uninstall",
                       L"Uninstall TrayIconGuard");
    }
    if (opt.autostart) {
        autostart::InstallAt(dest);
        s.autoStart = true;
    } else {
        autostart::Uninstall();
        s.autoStart = false;
    }
    WriteUninstallEntry(HKEY_CURRENT_USER, dir, dest);
    settings::Save();
    log::Info(L"installed to " + dir);
    return true;
}

// Delayed self-delete: detached cmd waits, then removes exe + folder.
bool ScheduleSelfDelete(const std::wstring& dir, const std::wstring& dest) {
    std::wstring cmd = L"/c ping 127.0.0.1 -n 3 >nul & del /f /q \"" + dest + L"\" & rd /s /q \"" +
                       dir + L"\"";
    STARTUPINFOW si{};
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;
    PROCESS_INFORMATION pi{};
    if (!CreateProcessW(nullptr, cmd.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr,
                        nullptr, &si, &pi))
        return false;
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return true;
}

}  // namespace

std::wstring DefaultDir() {
    std::wstring base = KnownFolder(FOLDERID_LocalAppData);
    if (base.empty()) base = KnownFolder(FOLDERID_Profile);
    return base + L"\\Programs\\TrayIconGuard";
}

std::wstring DefaultMachineDir() {
    std::wstring base = KnownFolder(FOLDERID_ProgramFiles);
    if (base.empty()) base = L"C:\\Program Files";
    return base + L"\\TrayIconGuard";
}

bool IsElevated() {
    HANDLE tok = nullptr;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &tok)) return false;
    TOKEN_ELEVATION te{};
    DWORD got = 0;
    const BOOL ok =
        GetTokenInformation(tok, TokenElevation, &te, sizeof(te), &got) && te.TokenIsElevated;
    CloseHandle(tok);
    return ok != FALSE;
}

std::wstring DesktopLnkPath() { return KnownFolder(FOLDERID_Desktop) + L"\\TrayIconGuard.lnk"; }
std::wstring StartMenuLnkPath() { return KnownFolder(FOLDERID_Programs) + L"\\TrayIconGuard.lnk"; }
std::wstring StartMenuUninstallLnkPath() {
    return KnownFolder(FOLDERID_Programs) + L"\\Uninstall TrayIconGuard.lnk";
}
std::wstring CommonDesktopLnkPath() {
    return KnownFolder(FOLDERID_PublicDesktop) + L"\\TrayIconGuard.lnk";
}
std::wstring CommonStartMenuLnkPath() {
    return KnownFolder(FOLDERID_CommonPrograms) + L"\\TrayIconGuard.lnk";
}
std::wstring CommonStartMenuUninstallLnkPath() {
    return KnownFolder(FOLDERID_CommonPrograms) + L"\\Uninstall TrayIconGuard.lnk";
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
    if (opt.scope == Scope::User) return InstallUser(opt, err);

    if (IsElevated()) return InstallMachineInProc(opt, err);

    // Not elevated: ask UAC once; the elevated child performs the machine install.
    DWORD exitCode = 1;
    std::wstring elevErr;
    if (RunElevated(MachineArgs(opt), exitCode, elevErr) && exitCode == 0) {
        settings::Reload();  // pick up scope/dir written by the elevated child
        return true;
    }
    log::Warn(L"UAC declined for machine install; falling back to per-user");
    log::Warn(elevErr.empty() ? L"elevation declined" : elevErr);
    Options fallback = opt;
    fallback.scope = Scope::User;
    fallback.dir = DefaultDir();  // Program Files is not writable without elevation
    return InstallUser(fallback, err);
}

bool Uninstall(std::wstring& err) {
    const bool machine = settings::Get().installScope == L"machine";
    if (machine && !IsElevated()) {
        DWORD exitCode = 1;
        std::wstring elevErr;
        if (!RunElevated(L"--uninstall", exitCode, elevErr)) {
            err = elevErr.empty() ? L"elevation required" : elevErr;
            return false;
        }
        if (exitCode != 0) {
            err = L"elevated uninstall failed (code " + std::to_wstring(exitCode) + L")";
            return false;
        }
        settings::Reload();
        return true;
    }

    // ask a running GUI instance to exit first
    cli::SendExitToRunningInstance();
    Sleep(1200);

    const std::wstring dir =
        settings::Get().installDir.empty() ? DefaultDir() : settings::Get().installDir;
    const std::wstring dest = dir + L"\\TrayIconGuard.exe";
    log::Info(std::wstring(machine ? L"machine uninstall from " : L"uninstall from ") + dir);

    DeleteFileW(DesktopLnkPath().c_str());
    DeleteFileW(StartMenuLnkPath().c_str());
    DeleteFileW(StartMenuUninstallLnkPath().c_str());
    DeleteFileW(CommonDesktopLnkPath().c_str());
    DeleteFileW(CommonStartMenuLnkPath().c_str());
    DeleteFileW(CommonStartMenuUninstallLnkPath().c_str());
    autostart::Uninstall();
    reg::DeleteValue(HKEY_LOCAL_MACHINE, kRunPath, autostart::kRunValue);
    RegDeleteTreeW(HKEY_CURRENT_USER, kUninstallPath);
    if (machine) RegDeleteTreeW(HKEY_LOCAL_MACHINE, kUninstallPath);
    settings::Get().installMode = L"portable";
    settings::Get().installDir.clear();
    settings::Get().installScope = L"user";
    settings::Save();

    const std::wstring self = fs::ModulePath();
    if (str::IEquals(self, dest)) {
        if (!ScheduleSelfDelete(dir, dest)) {
            err = L"cannot schedule self-delete";
            return false;
        }
    } else {
        DeleteFileW(dest.c_str());
        RemoveDirectoryW(dir.c_str());
    }
    log::Info(L"uninstalled from " + dir);
    return true;
}

}  // namespace tig::installer
