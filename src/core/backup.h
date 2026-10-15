// TrayIconGuard v8 — JSON state snapshots (schema v8) in %LOCALAPPDATA%\TrayIconGuard\backups.
#pragma once
#include <string>
#include <vector>

namespace tig::backup {

struct Info {
    std::wstring fileName;
    unsigned long long size = 0;
    unsigned long long writeTime = 0;
    int iconCount = -1;     // filled by List() reading the file header lazily? no: cheap metadata
    int promoted = -1;
    std::wstring note;      // "auto" | "manual" | "cli"
};

std::vector<Info> List();  // newest first
bool Create(std::wstring& outPath, std::wstring& err, const std::wstring& note = L"manual");
// Applies IsPromoted values from a snapshot. Returns applied count (<0 on error).
int Restore(const std::wstring& fileName, std::wstring& err);
bool Remove(const std::wstring& fileName);
bool Export(const std::wstring& fileName, const std::wstring& destPath, std::wstring& err);
void Prune(int keep = 30);
std::wstring FilePath(const std::wstring& fileName);

}  // namespace tig::backup
