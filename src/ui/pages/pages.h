// TrayIconGuard v8 — page factories + shared dialogs.
#pragma once
#include <memory>
#include <string>
#include <windows.h>

#include "ui/mainwindow.h"

namespace tig::ui {

std::unique_ptr<Page> MakeDashboardPage();
std::unique_ptr<Page> MakeIconsPage();
std::unique_ptr<Page> MakeGuardPage();
std::unique_ptr<Page> MakeAppearancePage();
std::unique_ptr<Page> MakeBackupsPage();
std::unique_ptr<Page> MakeActivityPage();
std::unique_ptr<Page> MakeAboutPage();

namespace dialogs {
// Yes/No confirmation with shield icon; follows app theme via system dialog.
bool Confirm(HWND parent, const std::wstring& title, const std::wstring& text);
void Info(HWND parent, const std::wstring& title, const std::wstring& text);
bool SaveFile(HWND parent, const wchar_t* defName, const wchar_t* filter, std::wstring& out);
}  // namespace dialogs

}  // namespace tig::ui
