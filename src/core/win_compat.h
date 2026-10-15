// TrayIconGuard v8 — Windows API compatibility shims for older mingw-w64 headers.
// Only defines what may be missing; never redefines existing symbols.
#pragma once
#include <windows.h>
#include <dwmapi.h>

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif
#ifndef DWMWA_SYSTEMBACKDROP_TYPE
#define DWMWA_SYSTEMBACKDROP_TYPE 38
#endif
#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif
#ifndef DWMSBT_AUTO
#define DWMSBT_AUTO 0
#endif
#ifndef DWMSBT_NONE
#define DWMSBT_NONE 1
#endif
#ifndef DWMSBT_MAINWINDOW
#define DWMSBT_MAINWINDOW 2
#endif
#ifndef DWMWCP_ROUND
#define DWMWCP_ROUND 2
#endif

#ifndef DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
DECLARE_HANDLE(DPI_AWARENESS_CONTEXT);
#define DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 ((DPI_AWARENESS_CONTEXT)-4)
#endif

// Undocumented but stable (Win10 1809+): sets caret color for dark themed edits.
typedef BOOL(WINAPI* PFN_SetCaretColor)(COLORREF);

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wcast-function-type"
namespace tig::compat {
inline PFN_SetCaretColor SetCaretColorFn() {
    static PFN_SetCaretColor fn = reinterpret_cast<PFN_SetCaretColor>(
        GetProcAddress(GetModuleHandleW(L"user32.dll"), "SetCaretColor"));
    return fn;
}
inline void SetProcessDpiPerMonitorV2() {
    using Fn = BOOL(WINAPI*)(DPI_AWARENESS_CONTEXT);
    auto fn = reinterpret_cast<Fn>(
        GetProcAddress(GetModuleHandleW(L"user32.dll"), "SetProcessDpiAwarenessContext"));
    if (fn) fn(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
}
}  // namespace tig::compat
#pragma GCC diagnostic pop
