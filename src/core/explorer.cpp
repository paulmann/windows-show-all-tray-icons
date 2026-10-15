#include "core/explorer.h"

#include <shellapi.h>
#include <tlhelp32.h>

#include "core/log.h"
#include "util/str.h"

namespace tig::explorer {

namespace {
std::vector<DWORD> ExplorerPids() {
    std::vector<DWORD> pids;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return pids;
    PROCESSENTRY32W pe{};
    pe.dwSize = sizeof(pe);
    if (Process32FirstW(snap, &pe)) {
        do {
            if (_wcsicmp(pe.szExeFile, L"explorer.exe") == 0) pids.push_back(pe.th32ProcessID);
        } while (Process32NextW(snap, &pe));
    }
    CloseHandle(snap);
    return pids;
}
}  // namespace

bool IsRunning() { return GetShellWindow() != nullptr || !ExplorerPids().empty(); }

DWORD Pid() {
    const auto pids = ExplorerPids();
    return pids.empty() ? 0 : pids.front();
}

bool Restart(std::wstring& err) {
    log::Info(L"Explorer restart requested");
    for (DWORD pid : ExplorerPids()) {
        HANDLE h = OpenProcess(PROCESS_TERMINATE | SYNCHRONIZE, FALSE, pid);
        if (!h) continue;
        TerminateProcess(h, 1);
        WaitForSingleObject(h, 2000);
        CloseHandle(h);
    }
    // wait for Windows to auto-restart the shell
    for (int i = 0; i < 40; ++i) {  // 8 s max
        Sleep(200);
        if (GetShellWindow()) {
            log::Info(L"Explorer auto-restarted");
            return true;
        }
    }
    // manual start
    HINSTANCE hi = ShellExecuteW(nullptr, L"open", L"explorer.exe", nullptr, nullptr,
                                 SW_SHOWNORMAL);
    if (reinterpret_cast<INT_PTR>(hi) <= 32) {
        err = str::Format(L"ShellExecute failed (code %d)", static_cast<int>(reinterpret_cast<INT_PTR>(hi)));
        log::Error(L"Explorer manual start failed: " + err);
        return false;
    }
    for (int i = 0; i < 20; ++i) {
        Sleep(200);
        if (GetShellWindow()) return true;
    }
    err = L"shell window did not appear within 4 s";
    log::Warn(L"Explorer restart: " + err);
    return false;
}

}  // namespace tig::explorer
