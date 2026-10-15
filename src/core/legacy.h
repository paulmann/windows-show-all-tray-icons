// TrayIconGuard v8 — legacy belt-and-suspenders + system-icon policies (agent A1).
// Mechanics reference: docs/HOW-IT-WORKS.md sections 2-4.
#pragma once
#include <string>
#include <windows.h>

namespace tig::legacy {

// HKCU\...\CurrentVersion\Explorer\EnableAutoTray = 0 (harmless, helps legacy shells).
bool ApplyEnableAutoTray();
bool RemoveEnableAutoTray();
bool GetEnableAutoTray(DWORD& out);  // false when absent

// Removes HideSCAVolume/HideSCANetwork/HideSCAPower (=1) from the CORRECT path
// HKCU\...\CurrentVersion\Policies\Explorer. Returns count removed.
int RemoveHideScaPolicies();
// Counts stale HideSCA*=1 values without removing.
int CountHideScaPolicies();

// Deletes IconStreams / PastIconsStream under ...\TrayNotify (phantom-icon repair).
// Explorer restart recommended afterwards. Returns true if anything was deleted.
bool ResetTrayCache();

}  // namespace tig::legacy
