// TrayIconGuard v8 — persisted settings (%APPDATA%\TrayIconGuard\settings.json).
// Crash-safe atomic writes; missing keys fall back to defaults; first-run detection.
#pragma once
#include <string>
#include <vector>

namespace tig {

enum class ThemeMode { System = 0, Light = 1, Dark = 2 };

struct Settings {
    // appearance
    ThemeMode theme = ThemeMode::System;
    std::wstring accent = L"system";  // "system" or "#RRGGBB"
    std::wstring language = L"auto";  // "auto" | "en" | "ru"
    bool animations = true;
    bool compactRows = false;
    // behavior
    bool startMinimized = false;
    bool closeToTray = true;
    bool autoStart = false;
    bool notifications = true;
    bool confirmExplorerRestart = true;
    bool autoBackup = true;
    // guard
    bool guardEnabled = true;
    int debounceMs = 400;
    int pollMs = 0;  // 0 = event-driven only
    bool autoRestartExplorer = false;
    int explorerCooldownSec = 60;
    bool legacyBelt = true;  // keep EnableAutoTray=0 belt-and-suspenders
    // icons
    std::vector<std::wstring> exclusions;
    std::vector<std::wstring> userHidden;   // ids the user explicitly hid (custom mode)
    std::vector<std::wstring> iconsOrder;   // drag-reorder persistence (ids, top-first)
    // display mode: full | custom | compact
    std::wstring displayMode = L"custom";
    // updates
    bool updateCheckEnabled = false;
    std::wstring updateFeedUrl;             // empty = default git raw feed
    unsigned long long updateLastCheck = 0; // epoch seconds of last check
    // install state (embedded installer)
    std::wstring installMode = L"unknown";  // unknown | installed | portable
    std::wstring installDir;
    std::wstring installScope = L"user";    // user | machine (8.4 install scope)
    // ui state
    bool firstRunDone = false;
    std::wstring lastPage = L"dashboard";
    int winX = -1, winY = -1, winW = 0, winH = 0;
    bool winMax = false;
};

namespace settings {

Settings& Get();
void Load();           // idempotent
void Reload();         // re-read from disk (after elevated child wrote settings)
bool Save();           // atomic
bool IsFirstRun();     // true until first successful Save after Load
std::wstring FilePath();

}  // namespace settings
}  // namespace tig
