#include "core/autostart.h"

#include "core/log.h"
#include "core/registry.h"
#include "util/fs.h"

namespace tig::autostart {

namespace {
const wchar_t* kRunPath = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
}

std::wstring CurrentCommand() {
    std::wstring v;
    reg::GetString(HKEY_CURRENT_USER, kRunPath, kRunValue, v);
    return v;
}

bool IsInstalled() { return !CurrentCommand().empty(); }

bool Install() { return InstallAt(fs::ModulePath()); }

bool InstallAt(const std::wstring& exePath) {
    const std::wstring cmd = L"\"" + exePath + L"\" --minimized";
    const bool ok = reg::SetString(HKEY_CURRENT_USER, kRunPath, kRunValue, cmd);
    log::Info(ok ? L"autostart installed" : L"autostart install FAILED");
    return ok;
}

bool Uninstall() {
    const bool ok = reg::DeleteValue(HKEY_CURRENT_USER, kRunPath, kRunValue);
    log::Info(ok ? L"autostart removed" : L"autostart value was absent");
    return ok;
}

}  // namespace tig::autostart
