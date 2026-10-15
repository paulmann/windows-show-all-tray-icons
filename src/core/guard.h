// TrayIconGuard v8 — event-driven tray guard (the heart of the app, agent A1).
// Watches HKCU\Control Panel\NotifyIconSettings with RegNotifyChangeKeyValue,
// debounces, re-promotes hidden icons, optionally restarts Explorer (cooldown).
// Worker thread posts events to the UI thread through a sink callback.
#pragma once
#include <functional>
#include <string>
#include <windows.h>

namespace tig::guard {

enum class EventKind {
    Started,
    Stopped,
    Paused,
    Resumed,
    Promoted,      // detail: "N icon(s): name1, name2"
    Discovered,    // new icon subkey appeared
    ExplorerRestarted,
    Error,
};

struct Stats {
    bool running = false;
    bool paused = false;
    unsigned long long promotionsSession = 0;
    unsigned long long passes = 0;
    unsigned long long lastChangeTick = 0;  // GetTickCount64 of last promotion
    SYSTEMTIME lastEventTime{};
    bool lastEventValid = false;
    ULONGLONG startTick = 0;  // GetTickCount64 at Start()
};

using EventSink = std::function<void(EventKind, const std::wstring& detail)>;

void SetEventSink(EventSink sink);  // call from UI thread before Start
bool Start();                       // no-op when already running
void Stop();
void Pause();
void Resume();
Stats GetStats();

// Synchronous one-shot used by CLI / dashboard button (safe from any thread).
int PromoteAllNow(std::wstring& detail);

// Visibility modes: "full" (everything promoted), "custom" (per-icon config +
// exclusions + user-hidden), "compact" (hide all except TrayIconGuard's own icon).
void SetDisplayMode(const std::wstring& mode);
std::wstring DisplayMode();
// Id of TrayIconGuard's own tray registration (empty when not registered yet).
std::wstring OwnIconId();

}  // namespace tig::guard
