#include "core/trayicons.h"

#include <algorithm>
#include <shellapi.h>
#include <shlwapi.h>

#include <map>

#include "core/log.h"
#include "core/registry.h"
#include "core/settings.h"
#include "util/fs.h"
#include "util/str.h"

namespace tig::store {

namespace {
std::vector<TrayIconEntry> g_current;
std::map<std::wstring, std::wstring> g_friendlyCache;
std::map<std::wstring, HICON> g_iconCache;
SRWLOCK g_cacheLock = SRWLOCK_INIT;

std::wstring FriendlyName(const std::wstring& exePath, const std::wstring& id) {
    if (exePath.empty()) return id;
    {
        AcquireSRWLockShared(&g_cacheLock);
        const auto it = g_friendlyCache.find(exePath);
        if (it != g_friendlyCache.end()) {
            const std::wstring cached = it->second;
            ReleaseSRWLockShared(&g_cacheLock);
            return cached;
        }
        ReleaseSRWLockShared(&g_cacheLock);
    }
    std::wstring name;
    const std::wstring expanded = [] (std::wstring p) {
        wchar_t buf[MAX_PATH + 1] = {};
        const DWORD n = ExpandEnvironmentStringsW(p.c_str(), buf, MAX_PATH);
        return n ? std::wstring(buf, n) : p;
    }(exePath);
    const DWORD size = GetFileVersionInfoSizeW(expanded.c_str(), nullptr);
    if (size) {
        std::vector<BYTE> buf(size);
        if (GetFileVersionInfoW(expanded.c_str(), 0, size, buf.data())) {
            wchar_t* desc = nullptr;
            UINT len = 0;
            if (VerQueryValueW(buf.data(), L"\\StringFileInfo\\040904B0\\FileDescription",
                               reinterpret_cast<LPVOID*>(&desc), &len) &&
                desc && len) {
                name.assign(desc, len);
                name = str::Trim(name);
            }
            if (name.empty() &&
                VerQueryValueW(buf.data(), L"\\StringFileInfo\\041904B0\\FileDescription",
                               reinterpret_cast<LPVOID*>(&desc), &len) &&
                desc && len) {
                name.assign(desc, len);
                name = str::Trim(name);
            }
        }
    }
    if (name.empty()) name = str::FileNameOf(expanded);
    AcquireSRWLockExclusive(&g_cacheLock);
    g_friendlyCache[exePath] = name;
    ReleaseSRWLockExclusive(&g_cacheLock);
    return name;
}

bool ReadIconEntry(const std::wstring& id, TrayIconEntry& out) {
    const std::wstring path = std::wstring(kStorePath) + L"\\" + id;
    out.id = id;
    reg::GetString(HKEY_CURRENT_USER, path, L"ExecutablePath", out.exePath);
    reg::GetString(HKEY_CURRENT_USER, path, L"IconResource", out.iconResource);
    DWORD promoted = 0;
    if (reg::GetDword(HKEY_CURRENT_USER, path, L"IsPromoted", promoted))
        out.promoted = promoted != 0;
    HKEY key = nullptr;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, path.c_str(), 0, KEY_READ, &key) == ERROR_SUCCESS) {
        DWORD type = 0;
        ULONGLONG v = 0;
        DWORD sz = sizeof(v);
        if (RegQueryValueExW(key, L"LastNotificationAddedTime", nullptr, &type,
                             reinterpret_cast<LPBYTE>(&v), &sz) == ERROR_SUCCESS &&
            type == REG_QWORD)
            out.lastNotif = v;
        RegCloseKey(key);
    }
    out.friendly = FriendlyName(out.exePath, id);
    return true;
}
}  // namespace

bool Supported() { return reg::KeyExists(HKEY_CURRENT_USER, kStorePath); }

std::vector<TrayIconEntry> Rescan() {
    std::vector<TrayIconEntry> out;
    for (const auto& id : reg::EnumSubkeys(HKEY_CURRENT_USER, kStorePath)) {
        TrayIconEntry e;
        if (ReadIconEntry(id, e)) {
            e.excluded = IsExcluded(e.exePath, settings::Get().exclusions);
            out.push_back(std::move(e));
        }
    }
    std::sort(out.begin(), out.end(), [](const TrayIconEntry& a, const TrayIconEntry& b) {
        return _wcsicmp(a.friendly.c_str(), b.friendly.c_str()) < 0;
    });
    g_current = out;
    return out;
}

const std::vector<TrayIconEntry>& Current() { return g_current; }

Counts GetCounts(const std::vector<TrayIconEntry>& v) {
    Counts c;
    c.total = static_cast<int>(v.size());
    for (const auto& e : v) {
        if (e.excluded) ++c.excluded;
        if (e.promoted) ++c.promoted;
        else ++c.hidden;
    }
    return c;
}

bool SetPromoted(const std::wstring& id, bool promoted) {
    const std::wstring path = std::wstring(kStorePath) + L"\\" + id;
    const bool ok = reg::SetDword(HKEY_CURRENT_USER, path, L"IsPromoted", promoted ? 1 : 0);
    if (ok) {
        for (auto& e : g_current)
            if (e.id == id) e.promoted = promoted;
    }
    return ok;
}

bool IsExcluded(const std::wstring& exePath, const std::vector<std::wstring>& exclusions) {
    if (exclusions.empty() || exePath.empty()) return false;
    const std::wstring name = str::ToLower(str::FileNameOf(exePath));
    const std::wstring full = str::ToLower(exePath);
    for (const auto& pattern : exclusions) {
        const std::wstring p = str::ToLower(str::Trim(pattern));
        if (p.empty()) continue;
        if (str::WildcardMatch(name, p) || str::WildcardMatch(full, p)) return true;
    }
    return false;
}

int PromoteAll(const std::vector<std::wstring>& exclusions) {
    if (!Supported()) return -1;
    const std::vector<TrayIconEntry> snap = Rescan();
    int changed = 0;
    for (const auto& e : snap) {
        if (e.excluded || IsExcluded(e.exePath, exclusions)) continue;
        if (!e.promoted && SetPromoted(e.id, true)) ++changed;
    }
    return changed;
}

int RestoreDefaults() {
    if (!Supported()) return -1;
    int removed = 0;
    for (const auto& id : reg::EnumSubkeys(HKEY_CURRENT_USER, kStorePath)) {
        if (reg::DeleteValue(HKEY_CURRENT_USER, std::wstring(kStorePath) + L"\\" + id,
                             L"IsPromoted"))
            ++removed;
    }
    Rescan();
    return removed;
}

HICON IconFor(const std::wstring& exePath) {
    if (exePath.empty()) return nullptr;
    AcquireSRWLockShared(&g_cacheLock);
    const auto it = g_iconCache.find(exePath);
    if (it != g_iconCache.end()) {
        const HICON h = it->second;
        ReleaseSRWLockShared(&g_cacheLock);
        return h;
    }
    ReleaseSRWLockShared(&g_cacheLock);

    wchar_t buf[MAX_PATH + 1] = {};
    const DWORD n = ExpandEnvironmentStringsW(exePath.c_str(), buf, MAX_PATH);
    const std::wstring expanded = n ? std::wstring(buf, n) : exePath;
    SHFILEINFOW sfi{};
    HICON icon = nullptr;
    if (SHGetFileInfoW(expanded.c_str(), 0, &sfi, sizeof(sfi),
                       SHGFI_ICON | SHGFI_SMALLICON | SHGFI_USEFILEATTRIBUTES) &&
        sfi.hIcon) {
        icon = sfi.hIcon;
    }
    AcquireSRWLockExclusive(&g_cacheLock);
    if (icon && g_iconCache.count(exePath)) {
        DestroyIcon(icon);
        icon = g_iconCache[exePath];
    } else if (icon) {
        g_iconCache[exePath] = icon;
    }
    ReleaseSRWLockExclusive(&g_cacheLock);
    return icon;
}

void Shutdown() {
    AcquireSRWLockExclusive(&g_cacheLock);
    for (auto& kv : g_iconCache)
        if (kv.second) DestroyIcon(kv.second);
    g_iconCache.clear();
    ReleaseSRWLockExclusive(&g_cacheLock);
}

}  // namespace tig::store
