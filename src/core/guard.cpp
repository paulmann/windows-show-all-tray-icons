#include "core/guard.h"

#include "core/backup.h"
#include "core/explorer.h"
#include "core/legacy.h"
#include "core/log.h"
#include "core/registry.h"
#include "core/settings.h"
#include "util/fs.h"
#include "core/trayicons.h"
#include "util/str.h"

namespace tig::guard {

namespace {
SRWLOCK g_lock = SRWLOCK_INIT;
HANDLE g_thread = nullptr;
HANDLE g_stopEvent = nullptr;
HANDLE g_regEvent = nullptr;
HANDLE g_wakeEvent = nullptr;  // auto-reset: wakes the loop on resume/settings changes
HKEY g_watchKey = nullptr;
EventSink g_sink;
Stats g_stats;
unsigned long long g_lastExplorerRestartTick = 0;
int g_consecutiveFixPasses = 0;

void Emit(EventKind kind, const std::wstring& detail) {
    EventSink sink;
    {
        AcquireSRWLockShared(&g_lock);
        sink = g_sink;
        ReleaseSRWLockShared(&g_lock);
    }
    if (sink) sink(kind, detail);
}

void NoteEvent() {
    GetLocalTime(&g_stats.lastEventTime);
    g_stats.lastEventValid = true;
    g_stats.lastChangeTick = GetTickCount64();
}

bool ArmRegistryWatch() {
    if (g_watchKey) {
        RegCloseKey(g_watchKey);
        g_watchKey = nullptr;
    }
    if (RegOpenKeyExW(HKEY_CURRENT_USER, store::kStorePath, 0, KEY_READ, &g_watchKey) !=
        ERROR_SUCCESS)
        return false;
    return RegNotifyChangeKeyValue(g_watchKey, TRUE,
                                   REG_NOTIFY_CHANGE_NAME | REG_NOTIFY_CHANGE_LAST_SET,
                                   g_regEvent, TRUE) == ERROR_SUCCESS;
}

// One reconciliation pass. Returns number of icons promoted.
namespace {
bool InList(const std::vector<std::wstring>& v, const std::wstring& id) {
    for (const auto& x : v)
        if (x == id) return true;
    return false;
}
}  // namespace

int RunPass(bool notifyUi) {
    if (!store::Supported()) return 0;
    ++g_stats.passes;
    const std::vector<TrayIconEntry> snap = store::Rescan();
    const Settings& st = settings::Get();
    const auto& exclusions = st.exclusions;
    const auto& userHidden = st.userHidden;
    const std::wstring mode = DisplayMode();
    const std::wstring own = OwnIconId();
    int changed = 0;
    std::wstring names;
    for (const auto& e : snap) {
        bool wantPromoted;
        if (mode == L"full") {
            wantPromoted = true;
        } else if (mode == L"compact") {
            wantPromoted = (e.id == own);
        } else {  // custom
            wantPromoted = !store::IsExcluded(e.exePath, exclusions) && !InList(userHidden, e.id);
        }
        if (e.promoted == wantPromoted) continue;
        if (store::SetPromoted(e.id, wantPromoted)) {
            ++changed;
            if (!names.empty()) names += L", ";
            names += e.friendly + (wantPromoted ? L"" : L" (-)");
            if (names.size() > 160) { names += L", ..."; break; }
        }
    }
    if (changed > 0) {
        g_stats.promotionsSession += static_cast<unsigned long long>(changed);
        NoteEvent();
        log::Event(str::Format(L"promoted %d icon(s): %s", changed, names.c_str()));
        if (notifyUi) Emit(EventKind::Promoted,
                           str::Format(L"%d|%s", changed, names.c_str()));
    }
    return changed;
}

// Coalesces a burst of registry writes into one reconciliation pass: keeps waiting while new
// changes arrive inside the window. Returns false when a stop was requested meanwhile.
bool DebounceBurst(DWORD debounceMs) {
    if (debounceMs == 0) return true;
    for (;;) {
        HANDLE waits[2] = {g_stopEvent, g_regEvent};
        const DWORD w = WaitForMultipleObjects(2, waits, FALSE, debounceMs);
        if (w == WAIT_OBJECT_0) return false;  // stop requested
        if (w == WAIT_TIMEOUT) return true;    // quiet period reached
        // another change arrived inside the window: restart the wait
    }
}

DWORD WINAPI ThreadProc(LPVOID) {
    log::Info(L"guard thread started");
    Emit(EventKind::Started, L"");
    ArmRegistryWatch();
    for (;;) {
        const DWORD pollMs = static_cast<DWORD>(settings::Get().pollMs);
        const DWORD timeout = pollMs > 0 ? pollMs : INFINITE;
        // Wait for the stop event, the registry notification and an explicit wake-up.
        // Waiting only on the stop event made event-driven mode (pollMs == 0, the default)
        // block forever, so the guard never reconciled after startup.
        HANDLE waits[3] = {g_stopEvent, g_regEvent, g_wakeEvent};
        const DWORD wait = WaitForMultipleObjects(3, waits, FALSE, timeout);
        if (wait == WAIT_OBJECT_0) break;  // stop requested

        // Coalesce a burst of registry writes into a single pass.
        if (!DebounceBurst(static_cast<DWORD>(settings::Get().debounceMs))) break;

        AcquireSRWLockShared(&g_lock);
        const bool paused = g_stats.paused;
        ReleaseSRWLockShared(&g_lock);
        if (paused) {
            ArmRegistryWatch();
            continue;
        }

        const int changed = RunPass(true);
        if (changed > 0) {
            ++g_consecutiveFixPasses;
            // optional auto Explorer restart with cooldown (flap-safe)
            const Settings& s = settings::Get();
            if (s.autoRestartExplorer && g_consecutiveFixPasses >= 2) {
                const unsigned long long now = GetTickCount64();
                const unsigned long long cooldownMs =
                    static_cast<unsigned long long>(s.explorerCooldownSec) * 1000ull;
                if (now - g_lastExplorerRestartTick >= cooldownMs) {
                    g_lastExplorerRestartTick = now;
                    g_consecutiveFixPasses = 0;
                    std::wstring err;
                    log::Info(L"guard: auto Explorer restart (cooldown elapsed)");
                    if (explorer::Restart(err)) Emit(EventKind::ExplorerRestarted, L"auto");
                }
            }
        } else {
            g_consecutiveFixPasses = 0;
        }
        ArmRegistryWatch();  // one-shot signal: re-arm after every pass
    }
    if (g_watchKey) {
        RegCloseKey(g_watchKey);
        g_watchKey = nullptr;
    }
    log::Info(L"guard thread stopped");
    Emit(EventKind::Stopped, L"");
    return 0;
}
}  // namespace

std::wstring OwnIconId() {
    const std::wstring self = fs::ModulePath();
    for (const auto& e : store::Current()) {
        if (!e.exePath.empty() && str::IEquals(e.exePath, self)) return e.id;
    }
    return {};
}

std::wstring DisplayMode() {
    const std::wstring m = settings::Get().displayMode;
    return (m == L"full" || m == L"compact") ? m : L"custom";
}

void SetDisplayMode(const std::wstring& mode) {
    const std::wstring m = (mode == L"full" || mode == L"compact") ? mode : L"custom";
    if (settings::Get().displayMode == m) return;
    settings::Get().displayMode = m;
    settings::Save();
    log::Event(L"display mode: " + m);
    std::wstring detail;
    PromoteAllNow(detail);  // immediate visible effect via mode-aware pass
    Emit(EventKind::Promoted, L"0|");
}

void SetEventSink(EventSink sink) {
    AcquireSRWLockExclusive(&g_lock);
    g_sink = std::move(sink);
    ReleaseSRWLockExclusive(&g_lock);
}

bool Start() {
    AcquireSRWLockExclusive(&g_lock);
    if (g_thread) {
        ReleaseSRWLockExclusive(&g_lock);
        return true;
    }
    if (!store::Supported()) {
        ReleaseSRWLockExclusive(&g_lock);
        log::Warn(L"guard cannot start: NotifyIconSettings store absent");
        return false;
    }
    if (settings::Get().legacyBelt) legacy::ApplyEnableAutoTray();
    g_stopEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    g_regEvent = CreateEventW(nullptr, FALSE, FALSE, nullptr);
    g_wakeEvent = CreateEventW(nullptr, FALSE, FALSE, nullptr);
    g_stats = Stats{};
    g_stats.running = true;
    g_stats.startTick = GetTickCount64();
    g_thread = CreateThread(nullptr, 0, ThreadProc, nullptr, 0, nullptr);
    if (!g_thread) {
        CloseHandle(g_stopEvent);
        CloseHandle(g_regEvent);
        CloseHandle(g_wakeEvent);
        g_stopEvent = g_regEvent = g_wakeEvent = nullptr;
        g_stats.running = false;
        ReleaseSRWLockExclusive(&g_lock);
        log::Error(L"guard: CreateThread failed");
        return false;
    }
    ReleaseSRWLockExclusive(&g_lock);
    return true;
}

void Stop() {
    AcquireSRWLockExclusive(&g_lock);
    HANDLE thread = g_thread;
    HANDLE stopEv = g_stopEvent;
    HANDLE regEv = g_regEvent;
    HANDLE wakeEv = g_wakeEvent;
    g_thread = nullptr;
    g_stopEvent = nullptr;
    g_regEvent = nullptr;
    g_wakeEvent = nullptr;
    g_stats.running = false;
    ReleaseSRWLockExclusive(&g_lock);
    if (!thread) return;
    SetEvent(stopEv);
    const DWORD waited = WaitForSingleObject(thread, 4000);
    if (waited != WAIT_OBJECT_0) {
        // The thread is still running: closing the handles it waits on would be a
        // use-after-close. Leak them deliberately and say so.
        log::Warn(L"guard: thread did not stop within 4 s; handles left open");
        return;
    }
    CloseHandle(thread);
    CloseHandle(stopEv);
    CloseHandle(regEv);
    CloseHandle(wakeEv);
}

void Pause() {
    AcquireSRWLockExclusive(&g_lock);
    if (g_stats.running && !g_stats.paused) {
        g_stats.paused = true;
        log::Info(L"guard paused");
        Emit(EventKind::Paused, L"");
    }
    ReleaseSRWLockExclusive(&g_lock);
}

void Resume() {
    AcquireSRWLockExclusive(&g_lock);
    if (g_stats.running && g_stats.paused) {
        g_stats.paused = false;
        log::Info(L"guard resumed");
        Emit(EventKind::Resumed, L"");
        if (g_wakeEvent) SetEvent(g_wakeEvent);  // reconcile now instead of waiting for a change
    }
    ReleaseSRWLockExclusive(&g_lock);
}

Stats GetStats() {
    AcquireSRWLockShared(&g_lock);
    const Stats s = g_stats;
    ReleaseSRWLockShared(&g_lock);
    return s;
}

int PromoteAllNow(std::wstring& detail) {
    const int changed = RunPass(false);
    std::wstring names;
    for (const auto& e : store::Current()) {
        if (e.promoted) {
            if (!names.empty()) names += L", ";
            names += e.friendly;
        }
    }
    detail = names;
    log::Event(str::Format(L"manual promote-all (mode=%s): %d change(s)",
                           DisplayMode().c_str(), changed));
    return changed;
}

}  // namespace tig::guard
