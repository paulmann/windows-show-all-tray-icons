// TrayIconGuard v8 — safe Explorer (shell) restart (agent A1).
#pragma once
#include <string>
#include <windows.h>

namespace tig::explorer {

bool IsRunning();          // shell window present
DWORD Pid();               // first explorer.exe pid, 0 if none
// kill -> wait up to 8s for auto-restart -> start manually if absent.
// Returns true when a healthy shell is present afterwards.
bool Restart(std::wstring& err);

}  // namespace tig::explorer
