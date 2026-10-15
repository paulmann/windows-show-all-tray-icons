// TrayIconGuard v8 — application bootstrap: single instance, init order,
// guard wiring, IPC server, message loop (agent A3).
#pragma once
#include <string>
#include <windows.h>

#include "core/cli.h"

namespace tig::app {

int Run(HINSTANCE hinst, const cli::ParsedArgs& args);

}  // namespace tig::app
