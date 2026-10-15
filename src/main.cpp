// TrayIconGuard v8 — entry point.
#include <windows.h>
#include <shellapi.h>

#include <string>
#include <vector>

#include "app/app.h"
#include "core/cli.h"
#include "core/win_compat.h"

int WINAPI wWinMain(HINSTANCE hinst, HINSTANCE, LPWSTR cmdLine, int) {
    (void)cmdLine;
    SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);

    int argc = 0;
    LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    std::vector<std::wstring> args;
    for (int i = 1; i < argc; ++i) args.emplace_back(argv[i]);
    LocalFree(argv);

    tig::cli::ParsedArgs parsed;
    std::wstring err;
    if (!tig::cli::Parse(args, parsed, err)) {
        tig::cli::SendToRunningInstance(L"show");
        return 1;
    }
    if (parsed.mode == tig::cli::Mode::Gui || parsed.mode == tig::cli::Mode::UiTest) {
        return tig::app::Run(hinst, parsed);
    }
    return tig::cli::ExecuteHeadless(parsed);
}
