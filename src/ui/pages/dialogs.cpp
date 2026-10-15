#include "pages.h"

#include <commctrl.h>
#include <commdlg.h>

#include "ui/theme.h"

namespace tig::ui::dialogs {

namespace {
HRESULT Task(HWND parent, const std::wstring& title, const std::wstring& text,
             TASKDIALOG_COMMON_BUTTON_FLAGS buttons, int& outButton) {
    TASKDIALOGCONFIG cfg{};
    cfg.cbSize = sizeof(cfg);
    cfg.hwndParent = parent;
    cfg.hInstance = GetModuleHandleW(nullptr);
    cfg.dwFlags = TDF_ALLOW_DIALOG_CANCELLATION | TDF_POSITION_RELATIVE_TO_WINDOW;
    cfg.dwCommonButtons = buttons;
    cfg.pszWindowTitle = L"TrayIconGuard";
    cfg.pszMainInstruction = title.c_str();
    cfg.pszContent = text.c_str();
    cfg.pszMainIcon = MAKEINTRESOURCEW(1);
    cfg.dwFlags |= TDF_USE_HICON_MAIN;
    cfg.hMainIcon = static_cast<HICON>(
        LoadImageW(cfg.hInstance, MAKEINTRESOURCEW(1), IMAGE_ICON, 64, 64, LR_DEFAULTCOLOR));
    const HRESULT hr = TaskDialogIndirect(&cfg, &outButton, nullptr, nullptr);
    if (cfg.hMainIcon) DestroyIcon(cfg.hMainIcon);
    return hr;
}
}  // namespace

bool Confirm(HWND parent, const std::wstring& title, const std::wstring& text) {
    int btn = IDCANCEL;
    if (FAILED(Task(parent, title, text, IDYES | IDNO, btn))) return false;
    return btn == IDYES;
}

void Info(HWND parent, const std::wstring& title, const std::wstring& text) {
    int btn = 0;
    Task(parent, title, text, IDCLOSE, btn);
}

bool SaveFile(HWND parent, const wchar_t* defName, const wchar_t* filter, std::wstring& out) {
    wchar_t file[MAX_PATH] = {};
    wcsncpy_s(file, ARRAYSIZE(file), defName, _TRUNCATE);
    OPENFILENAMEW ofn{};
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = parent;
    ofn.lpstrFilter = filter;
    ofn.lpstrFile = file;
    ofn.nMaxFile = MAX_PATH;
    ofn.Flags = OFN_OVERWRITEPROMPT | OFN_NOCHANGEDIR;
    if (!GetSaveFileNameW(&ofn)) return false;
    out = file;
    return true;
}

}  // namespace tig::ui::dialogs
