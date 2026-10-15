// TrayIconGuard v8 — registry helpers (agent A1). HKCU-first by design (D9).
#pragma once
#include <string>
#include <vector>
#include <windows.h>

namespace tig::reg {

bool GetDword(HKEY root, const std::wstring& path, const std::wstring& name, DWORD& out);
bool SetDword(HKEY root, const std::wstring& path, const std::wstring& name, DWORD value);
bool GetString(HKEY root, const std::wstring& path, const std::wstring& name, std::wstring& out);
bool SetString(HKEY root, const std::wstring& path, const std::wstring& name, const std::wstring& value);
bool DeleteValue(HKEY root, const std::wstring& path, const std::wstring& name);
bool KeyExists(HKEY root, const std::wstring& path);
bool CreateKey(HKEY root, const std::wstring& path);
std::vector<std::wstring> EnumSubkeys(HKEY root, const std::wstring& path);
// Deletes all values+subkeys under path but keeps path itself.
bool ClearSubtree(HKEY root, const std::wstring& path);

}  // namespace tig::reg
