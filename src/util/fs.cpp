#include "util/fs.h"

#include <windows.h>
#include <shlobj.h>
#include <shlwapi.h>

#include "util/str.h"

namespace tig::fs {

namespace {
std::wstring KnownFolder(REFKNOWNFOLDERID id) {
    PWSTR raw = nullptr;
    if (FAILED(SHGetKnownFolderPath(id, KF_FLAG_CREATE, nullptr, &raw))) return {};
    std::wstring out(raw);
    CoTaskMemFree(raw);
    return out;
}
}  // namespace

std::wstring AppDataDir() {
    std::wstring p = KnownFolder(FOLDERID_RoamingAppData);
    if (p.empty()) p = KnownFolder(FOLDERID_Profile) + L"\\AppData\\Roaming";
    p += L"\\TrayIconGuard";
    EnsureDir(p);
    return p;
}

std::wstring LocalDataDir() {
    std::wstring p = KnownFolder(FOLDERID_LocalAppData);
    if (p.empty()) p = KnownFolder(FOLDERID_Profile) + L"\\AppData\\Local";
    p += L"\\TrayIconGuard";
    EnsureDir(p);
    return p;
}

std::wstring LogsDir() {
    std::wstring p = LocalDataDir() + L"\\logs";
    EnsureDir(p);
    return p;
}

std::wstring BackupsDir() {
    std::wstring p = LocalDataDir() + L"\\backups";
    EnsureDir(p);
    return p;
}

bool EnsureDir(const std::wstring& path) {
    if (path.empty()) return false;
    if (DirExists(path)) return true;
    // create parents first
    const std::wstring parent = str::DirNameOf(path);
    if (!parent.empty() && parent.size() + 1 < path.size() && !DirExists(parent)) EnsureDir(parent);
    return CreateDirectoryW(path.c_str(), nullptr) || GetLastError() == ERROR_ALREADY_EXISTS;
}

bool DirExists(const std::wstring& path) {
    const DWORD attr = GetFileAttributesW(path.c_str());
    return attr != INVALID_FILE_ATTRIBUTES && (attr & FILE_ATTRIBUTE_DIRECTORY);
}

bool FileExists(const std::wstring& path) {
    const DWORD attr = GetFileAttributesW(path.c_str());
    return attr != INVALID_FILE_ATTRIBUTES && !(attr & FILE_ATTRIBUTE_DIRECTORY);
}

std::wstring ModulePath() {
    wchar_t buf[MAX_PATH + 1] = {};
    const DWORD n = GetModuleFileNameW(nullptr, buf, MAX_PATH);
    return n ? std::wstring(buf, n) : std::wstring();
}

std::wstring ModuleDir() { return str::DirNameOf(ModulePath()); }

bool ReadTextFile(const std::wstring& path, std::string& outUtf8) {
    outUtf8.clear();
    HANDLE h = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                           OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (h == INVALID_HANDLE_VALUE) return false;
    LARGE_INTEGER sz{};
    GetFileSizeEx(h, &sz);
    if (sz.QuadPart > 0 && sz.QuadPart < 64 * 1024 * 1024) {
        outUtf8.resize(static_cast<size_t>(sz.QuadPart));
        DWORD read = 0;
        if (!ReadFile(h, outUtf8.data(), static_cast<DWORD>(outUtf8.size()), &read, nullptr)) {
            outUtf8.clear();
            CloseHandle(h);
            return false;
        }
        outUtf8.resize(read);
    }
    CloseHandle(h);
    return true;
}

bool WriteTextFileAtomic(const std::wstring& path, const std::string& utf8) {
    const std::wstring tmp = path + L".tmp";
    HANDLE h = CreateFileW(tmp.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
                           FILE_ATTRIBUTE_NORMAL, nullptr);
    if (h == INVALID_HANDLE_VALUE) return false;
    DWORD written = 0;
    const BOOL ok = WriteFile(h, utf8.data(), static_cast<DWORD>(utf8.size()), &written, nullptr);
    CloseHandle(h);
    if (!ok || written != utf8.size()) {
        DeleteFileW(tmp.c_str());
        return false;
    }
    return MoveFileExW(tmp.c_str(), path.c_str(),
                       MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != FALSE;
}

std::vector<FileItem> ListFiles(const std::wstring& dir, const std::wstring& pattern) {
    std::vector<FileItem> out;
    const std::wstring q = dir + L"\\" + pattern;
    WIN32_FIND_DATAW fd{};
    HANDLE h = FindFirstFileW(q.c_str(), &fd);
    if (h == INVALID_HANDLE_VALUE) return out;
    do {
        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) continue;
        FileItem it;
        it.name = fd.cFileName;
        it.size = (static_cast<unsigned long long>(fd.nFileSizeHigh) << 32) | fd.nFileSizeLow;
        it.writeTime = (static_cast<unsigned long long>(fd.ftLastWriteTime.dwHighDateTime) << 32) |
                       fd.ftLastWriteTime.dwLowDateTime;
        out.push_back(std::move(it));
    } while (FindNextFileW(h, &fd));
    FindClose(h);
    return out;
}

bool DeleteFileNow(const std::wstring& path) { return DeleteFileW(path.c_str()) != FALSE; }

int DeleteOlderThan(const std::wstring& dir, const std::wstring& prefix,
                    const std::wstring& ext, int keepDays) {
    int removed = 0;
    const unsigned long long cutoff = NowFileTime() -
        static_cast<unsigned long long>(keepDays) * 24ull * 3600ull * 10000000ull;
    for (const auto& f : ListFiles(dir, L"*")) {
        if (!prefix.empty() && !str::IStartsWith(f.name, prefix)) continue;
        if (!ext.empty() && !str::IEndsWith(f.name, ext)) continue;
        if (f.writeTime && f.writeTime < cutoff) {
            if (DeleteFileNow(dir + L"\\" + f.name)) ++removed;
        }
    }
    return removed;
}

unsigned long long FileSize(const std::wstring& path) {
    WIN32_FILE_ATTRIBUTE_DATA ad{};
    if (!GetFileAttributesExW(path.c_str(), GetFileExInfoStandard, &ad)) return 0;
    return (static_cast<unsigned long long>(ad.nFileSizeHigh) << 32) | ad.nFileSizeLow;
}

std::wstring FormatFileTime(unsigned long long ft) {
    if (!ft) return {};
    FILETIME f{};
    f.dwLowDateTime = static_cast<DWORD>(ft & 0xFFFFFFFF);
    f.dwHighDateTime = static_cast<DWORD>(ft >> 32);
    FILETIME local{};
    FileTimeToLocalFileTime(&f, &local);
    SYSTEMTIME st{};
    FileTimeToSystemTime(&local, &st);
    return str::Format(L"%04d-%02d-%02d %02d:%02d:%02d", st.wYear, st.wMonth, st.wDay,
                       st.wHour, st.wMinute, st.wSecond);
}

unsigned long long NowFileTime() {
    SYSTEMTIME st{};
    GetLocalTime(&st);
    FILETIME f{};
    SystemTimeToFileTime(&st, &f);
    return (static_cast<unsigned long long>(f.dwHighDateTime) << 32) | f.dwLowDateTime;
}

}  // namespace tig::fs
