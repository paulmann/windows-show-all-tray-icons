// TrayIconGuard v8 — command line interface + single-instance IPC (agent A1).
// Exit codes: 0 ok, 1 invalid args, 2 unsupported OS, 3 partial failure.
#pragma once
#include <string>
#include <vector>

namespace tig::cli {

enum class Mode {
    Gui,             // default: tray-resident GUI
    Help,
    Version,
    Status,          // [--json]
    PromoteAll,
    RestoreDefaults,
    RestartExplorer,
    Backup,
    RestoreLatest,
    Watch,           // headless guard (replaces v7 BAT/PS watcher editions)
    ToggleGuard,     // IPC -> running instance
    Show,            // IPC -> running instance (activate window)
    InstallAutostart,
    UninstallAutostart,
    Uninstall,
    InstallMachine,  // elevated machine-scope install body (--install-machine)
    SetMode,
    CheckUpdate,
    UpdateNow,
    UiTest,          // QA: render GUI headless-friendly, auto-exit
};

struct ParsedArgs {
    Mode mode = Mode::Gui;
    std::wstring modeValue;
    bool minimized = false;
    bool json = false;
    bool force = false;
    std::wstring uiTestPage;
    // --install-machine <dir> [--autostart] [--desktop] [--menu]
    std::wstring machineDir;
    bool mAutostart = false, mDesktop = false, mMenu = false;
};

bool Parse(const std::vector<std::wstring>& args, ParsedArgs& out, std::wstring& err);
int ExecuteHeadless(const ParsedArgs& a);

// Sends a verb ("show", "toggle-guard", "exit") to a running TrayIconGuard GUI.
bool SendToRunningInstance(const std::wstring& verb);
bool SendExitToRunningInstance();

std::wstring HelpText();

// Prints one line to the CLI output channel: the console when one is attached, otherwise the
// inherited pipe/file handle, so redirection (`> state.json`) and RMM capture work.
void PrintLine(const std::wstring& text);

}  // namespace tig::cli
