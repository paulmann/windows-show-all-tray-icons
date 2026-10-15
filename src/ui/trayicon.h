// TrayIconGuard v8 — own notification-area icon + context menu + balloons.
#pragma once
#include <string>
#include <windows.h>

namespace tig::ui::tray {

bool Init(HWND owner);
void UpdateIcon();  // refresh overlay dot from guard state
void Balloon(const std::wstring& title, const std::wstring& text, bool info);
void Remove();
bool HandleCommand(WORD menuId);            // true when handled
void OnGuardEvent(int kind, const std::wstring& detail);
void OnTaskbarCreated();                    // re-add icon after Explorer restart

}  // namespace tig::ui::tray
