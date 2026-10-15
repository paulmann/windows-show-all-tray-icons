// TrayIconGuard v8 — first-run setup wizard (embedded installer UI).
// Modal custom-drawn window: install folder + autostart/desktop/menu options,
// or "just run once" portable mode.
#pragma once
#include <string>
#include <windows.h>

#include "core/installer.h"

namespace tig::ui::setup {

enum class Action { Cancel, Install, Portable };

struct Result {
    Action action = Action::Cancel;
    installer::Options opts;
};

// Runs the modal wizard; returns when the user chooses.
Result RunWizard(HINSTANCE hinst);

}  // namespace tig::ui::setup
