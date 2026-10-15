#include "core/legacy.h"

#include "core/log.h"
#include "core/registry.h"
#include "util/str.h"

namespace tig::legacy {

namespace {
const wchar_t* kExplorerPath = L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer";
const wchar_t* kPoliciesPath = L"Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer";
const wchar_t* kTrayNotifyPath =
    L"Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\CurrentVersion\\TrayNotify";
const wchar_t* kScaValues[] = {L"HideSCAVolume", L"HideSCANetwork", L"HideSCAPower"};
}  // namespace

bool ApplyEnableAutoTray() {
    const bool ok = reg::SetDword(HKEY_CURRENT_USER, kExplorerPath, L"EnableAutoTray", 0);
    if (ok) log::Info(L"legacy belt: EnableAutoTray=0 applied");
    return ok;
}

bool RemoveEnableAutoTray() {
    return reg::DeleteValue(HKEY_CURRENT_USER, kExplorerPath, L"EnableAutoTray");
}

bool GetEnableAutoTray(DWORD& out) {
    return reg::GetDword(HKEY_CURRENT_USER, kExplorerPath, L"EnableAutoTray", out);
}

int RemoveHideScaPolicies() {
    int removed = 0;
    for (const wchar_t* name : kScaValues) {
        DWORD v = 0;
        if (reg::GetDword(HKEY_CURRENT_USER, kPoliciesPath, name, v) && v == 1 &&
            reg::DeleteValue(HKEY_CURRENT_USER, kPoliciesPath, name)) {
            ++removed;
            log::Event(str::Format(L"removed policy %s=1", name));
        }
    }
    return removed;
}

int CountHideScaPolicies() {
    int count = 0;
    for (const wchar_t* name : kScaValues) {
        DWORD v = 0;
        if (reg::GetDword(HKEY_CURRENT_USER, kPoliciesPath, name, v) && v == 1) ++count;
    }
    return count;
}

bool ResetTrayCache() {
    bool any = false;
    for (const wchar_t* name : {L"IconStreams", L"PastIconsStream"}) {
        if (reg::DeleteValue(HKEY_CURRENT_USER, kTrayNotifyPath, name)) {
            any = true;
            log::Event(str::Format(L"legacy cache: deleted %s", name));
        }
    }
    return any;
}

}  // namespace tig::legacy
