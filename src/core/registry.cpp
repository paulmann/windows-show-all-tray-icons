#include "core/registry.h"

#include <shlwapi.h>

namespace tig::reg {

bool GetDword(HKEY root, const std::wstring& path, const std::wstring& name, DWORD& out) {
    HKEY key = nullptr;
    if (RegOpenKeyExW(root, path.c_str(), 0, KEY_READ, &key) != ERROR_SUCCESS) return false;
    DWORD type = 0, value = 0, size = sizeof(value);
    const LSTATUS st = RegQueryValueExW(key, name.c_str(), nullptr, &type,
                                        reinterpret_cast<LPBYTE>(&value), &size);
    RegCloseKey(key);
    if (st != ERROR_SUCCESS || (type != REG_DWORD && type != REG_SZ)) return false;
    out = value;
    return true;
}

bool SetDword(HKEY root, const std::wstring& path, const std::wstring& name, DWORD value) {
    HKEY key = nullptr;
    if (RegCreateKeyExW(root, path.c_str(), 0, nullptr, 0, KEY_WRITE, nullptr, &key, nullptr) !=
        ERROR_SUCCESS)
        return false;
    const LSTATUS st =
        RegSetValueExW(key, name.c_str(), 0, REG_DWORD, reinterpret_cast<const BYTE*>(&value),
                       sizeof(value));
    RegCloseKey(key);
    return st == ERROR_SUCCESS;
}

bool GetString(HKEY root, const std::wstring& path, const std::wstring& name, std::wstring& out) {
    HKEY key = nullptr;
    if (RegOpenKeyExW(root, path.c_str(), 0, KEY_READ, &key) != ERROR_SUCCESS) return false;
    DWORD type = 0, size = 0;
    LSTATUS st = RegQueryValueExW(key, name.c_str(), nullptr, &type, nullptr, &size);
    if (st != ERROR_SUCCESS || (type != REG_SZ && type != REG_EXPAND_SZ)) {
        RegCloseKey(key);
        return false;
    }
    std::wstring buf(size / sizeof(wchar_t) + 1, L'\0');
    st = RegQueryValueExW(key, name.c_str(), nullptr, &type,
                          reinterpret_cast<LPBYTE>(buf.data()), &size);
    RegCloseKey(key);
    if (st != ERROR_SUCCESS) return false;
    // strip trailing NULs
    while (!buf.empty() && buf.back() == L'\0') buf.pop_back();
    out = buf;
    return true;
}

bool SetString(HKEY root, const std::wstring& path, const std::wstring& name,
               const std::wstring& value) {
    HKEY key = nullptr;
    if (RegCreateKeyExW(root, path.c_str(), 0, nullptr, 0, KEY_WRITE, nullptr, &key, nullptr) !=
        ERROR_SUCCESS)
        return false;
    const LSTATUS st = RegSetValueExW(key, name.c_str(), 0, REG_SZ,
                                      reinterpret_cast<const BYTE*>(value.c_str()),
                                      static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
    RegCloseKey(key);
    return st == ERROR_SUCCESS;
}

bool DeleteValue(HKEY root, const std::wstring& path, const std::wstring& name) {
    HKEY key = nullptr;
    if (RegOpenKeyExW(root, path.c_str(), 0, KEY_SET_VALUE, &key) != ERROR_SUCCESS) return false;
    const LSTATUS st = RegDeleteValueW(key, name.c_str());
    RegCloseKey(key);
    return st == ERROR_SUCCESS;
}

bool KeyExists(HKEY root, const std::wstring& path) {
    HKEY key = nullptr;
    const LSTATUS st = RegOpenKeyExW(root, path.c_str(), 0, KEY_READ, &key);
    if (st == ERROR_SUCCESS) RegCloseKey(key);
    return st == ERROR_SUCCESS;
}

bool CreateKey(HKEY root, const std::wstring& path) {
    HKEY key = nullptr;
    const LSTATUS st =
        RegCreateKeyExW(root, path.c_str(), 0, nullptr, 0, KEY_READ | KEY_WRITE, nullptr, &key, nullptr);
    if (st == ERROR_SUCCESS) RegCloseKey(key);
    return st == ERROR_SUCCESS;
}

std::vector<std::wstring> EnumSubkeys(HKEY root, const std::wstring& path) {
    std::vector<std::wstring> out;
    HKEY key = nullptr;
    if (RegOpenKeyExW(root, path.c_str(), 0, KEY_READ, &key) != ERROR_SUCCESS) return out;
    DWORD index = 0;
    wchar_t name[512];
    DWORD nameLen = 512;
    while (RegEnumKeyExW(key, index++, name, &nameLen, nullptr, nullptr, nullptr, nullptr) ==
           ERROR_SUCCESS) {
        out.emplace_back(name, nameLen);
        nameLen = 512;
    }
    RegCloseKey(key);
    return out;
}

bool ClearSubtree(HKEY root, const std::wstring& path) {
    HKEY key = nullptr;
    if (RegOpenKeyExW(root, path.c_str(), 0, KEY_READ | KEY_WRITE | DELETE, &key) != ERROR_SUCCESS)
        return false;
    // delete subkeys depth-first
    wchar_t name[512];
    DWORD nameLen = 512;
    while (RegEnumKeyExW(key, 0, name, &nameLen, nullptr, nullptr, nullptr, nullptr) ==
           ERROR_SUCCESS) {
        const std::wstring sub = path + L"\\" + std::wstring(name, nameLen);
        SHDeleteKeyW(key, std::wstring(name, nameLen).c_str());
        nameLen = 512;
        (void)sub;
    }
    // delete values
    DWORD valueCount = 0;
    RegQueryInfoKeyW(key, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, &valueCount,
                     nullptr, nullptr, nullptr, nullptr);
    for (DWORD i = 0; i < valueCount + 100; ++i) {
        wchar_t vname[512];
        DWORD vlen = 512;
        if (RegEnumValueW(key, 0, vname, &vlen, nullptr, nullptr, nullptr, nullptr) !=
            ERROR_SUCCESS)
            break;
        if (RegDeleteValueW(key, vname) != ERROR_SUCCESS) break;
    }
    RegCloseKey(key);
    return true;
}

}  // namespace tig::reg
