// TrayIconGuard v8 — the notification-area icon store (agent A1).
// Primary store: HKCU\Control Panel\NotifyIconSettings\{id} -> IsPromoted.
// See docs/HOW-IT-WORKS.md (v8) for the mechanics and decay problem.
#pragma once
#include <string>
#include <vector>
#include <windows.h>

namespace tig {

struct TrayIconEntry {
    std::wstring id;            // subkey name (usually a GUID)
    std::wstring exePath;       // ExecutablePath value (may be empty for shell icons)
    std::wstring iconResource;  // IconResource value, e.g. "C:\app.exe,-101"
    std::wstring friendly;      // FileDescription, fallback: file name or id
    bool promoted = false;      // IsPromoted == 1
    bool excluded = false;      // matches an exclusion pattern (user wants it hidden)
    unsigned long long lastNotif = 0;  // LastNotificationAddedTime FILETIME
};

namespace store {

constexpr wchar_t kStorePath[] = L"Control Panel\\NotifyIconSettings";

bool Supported();  // NotifyIconSettings exists (Win10 1703+ / Win11)

// Rescans the store and returns a fresh snapshot; also caches it in Current().
std::vector<TrayIconEntry> Rescan();
const std::vector<TrayIconEntry>& Current();

struct Counts {
    int total = 0;
    int promoted = 0;
    int hidden = 0;
    int excluded = 0;
};
Counts GetCounts(const std::vector<TrayIconEntry>& v);

bool SetPromoted(const std::wstring& id, bool promoted);
// Sets IsPromoted=1 on every non-excluded icon. Returns number changed.
int PromoteAll(const std::vector<std::wstring>& exclusions);
// Deletes IsPromoted values entirely (hands control back to Windows).
int RestoreDefaults();

bool IsExcluded(const std::wstring& exePath, const std::vector<std::wstring>& exclusions);

// Extracted small icon for an exe path (cached; freed at Shutdown).
HICON IconFor(const std::wstring& exePath);
void Shutdown();  // frees icon cache

}  // namespace store
}  // namespace tig
