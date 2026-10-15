// TrayIconGuard v8 — filesystem / app-data helpers (agent A1).
#pragma once
#include <string>
#include <vector>

namespace tig::fs {

// %APPDATA%\TrayIconGuard (created on demand)
std::wstring AppDataDir();
// %LOCALAPPDATA%\TrayIconGuard (created on demand)
std::wstring LocalDataDir();
std::wstring LogsDir();      // %LOCALAPPDATA%\TrayIconGuard\logs
std::wstring BackupsDir();   // %LOCALAPPDATA%\TrayIconGuard\backups

bool EnsureDir(const std::wstring& path);
bool DirExists(const std::wstring& path);
bool FileExists(const std::wstring& path);

// Path of the running executable.
std::wstring ModulePath();
std::wstring ModuleDir();

bool ReadTextFile(const std::wstring& path, std::string& outUtf8);
// Crash-safe: writes <path>.tmp then MoveFileExW(REPLACE_EXISTING).
bool WriteTextFileAtomic(const std::wstring& path, const std::string& utf8);

struct FileItem {
    std::wstring name;
    unsigned long long size = 0;
    unsigned long long writeTime = 0;  // FILETIME as u64
};
std::vector<FileItem> ListFiles(const std::wstring& dir, const std::wstring& pattern);
bool DeleteFileNow(const std::wstring& path);
// Removes files matching prefix*.log older than keepDays. Returns count deleted.
int DeleteOlderThan(const std::wstring& dir, const std::wstring& prefix,
                    const std::wstring& ext, int keepDays);

unsigned long long FileSize(const std::wstring& path);

// FILETIME (u64) -> "2026-10-16 14:03:22" (local time). "" on failure.
std::wstring FormatFileTime(unsigned long long ft);
unsigned long long NowFileTime();

}  // namespace tig::fs
