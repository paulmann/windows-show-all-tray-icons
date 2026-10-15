#include "core/backup.h"

#include <algorithm>

#include "core/json.h"
#include "core/version.h"
#include "core/log.h"
#include "core/trayicons.h"
#include "util/fs.h"
#include "util/str.h"

namespace tig::backup {

namespace {
std::wstring TimeStamp() {
    SYSTEMTIME st{};
    GetLocalTime(&st);
    return str::Format(L"%04d%02d%02d-%02d%02d%02d", st.wYear, st.wMonth, st.wDay, st.wHour,
                       st.wMinute, st.wSecond);
}
}  // namespace

std::wstring FilePath(const std::wstring& fileName) {
    return fs::BackupsDir() + L"\\" + fileName;
}

std::vector<Info> List() {
    std::vector<Info> out;
    auto files = fs::ListFiles(fs::BackupsDir(), L"TrayIconState-*.json");
    std::sort(files.begin(), files.end(),
              [](const fs::FileItem& a, const fs::FileItem& b) { return a.writeTime > b.writeTime; });
    for (const auto& f : files) {
        Info info;
        info.fileName = f.name;
        info.size = f.size;
        info.writeTime = f.writeTime;
        // peek metadata
        std::string raw;
        if (fs::ReadTextFile(FilePath(f.name), raw)) {
            json::Value v;
            std::wstring err;
            if (json::Parse(str::ToWide(raw), v, err)) {
                info.iconCount = v.GetInt(L"iconCount", -1);
                info.promoted = v.GetInt(L"promoted", -1);
                info.note = v.GetStr(L"note", L"");
            }
        }
        out.push_back(std::move(info));
    }
    return out;
}

bool Create(std::wstring& outPath, std::wstring& err, const std::wstring& note) {
    if (!store::Supported()) {
        err = L"NotifyIconSettings store is not present on this Windows build";
        return false;
    }
    const std::vector<TrayIconEntry> snap = store::Rescan();
    json::Value root = json::Value::MakeObject();
    root.Set(L"schema", json::Value::MakeNumber(8));
    root.Set(L"app", json::Value::MakeString(std::wstring(L"TrayIconGuard ") + kVersion));
    root.Set(L"note", json::Value::MakeString(note));
    SYSTEMTIME st{};
    GetLocalTime(&st);
    root.Set(L"created", json::Value::MakeString(str::Format(
        L"%04d-%02d-%02dT%02d:%02d:%02d", st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute,
        st.wSecond)));
    int promoted = 0;
    json::Value icons = json::Value::MakeArray();
    for (const auto& e : snap) {
        if (e.promoted) ++promoted;
        json::Value o = json::Value::MakeObject();
        o.Set(L"id", json::Value::MakeString(e.id));
        o.Set(L"exe", json::Value::MakeString(e.exePath));
        o.Set(L"iconResource", json::Value::MakeString(e.iconResource));
        o.Set(L"promoted", json::Value::MakeBool(e.promoted));
        icons.Push(o);
    }
    root.Set(L"icons", icons);
    root.Set(L"iconCount", json::Value::MakeNumber(static_cast<int>(snap.size())));
    root.Set(L"promoted", json::Value::MakeNumber(promoted));

    const std::wstring name = L"TrayIconState-" + TimeStamp() + L".json";
    outPath = FilePath(name);
    if (!fs::WriteTextFileAtomic(outPath, str::ToUtf8(json::Write(root, true)))) {
        err = L"cannot write " + outPath;
        return false;
    }
    log::Info(str::Format(L"backup created: %s (%zu icons)", name.c_str(), snap.size()));
    Prune(30);
    return true;
}

int Restore(const std::wstring& fileName, std::wstring& err) {
    std::string raw;
    if (!fs::ReadTextFile(FilePath(fileName), raw)) {
        err = L"snapshot not found: " + fileName;
        return -1;
    }
    json::Value root;
    if (!json::Parse(str::ToWide(raw), root, err)) return -1;
    const json::Value* icons = root.Find(L"icons");
    if (!icons || icons->type != json::Value::Array) {
        err = L"snapshot has no icons array";
        return -1;
    }
    int applied = 0;
    for (const auto& o : icons->arr) {
        const std::wstring id = o.GetStr(L"id", L"");
        if (id.empty()) continue;
        const bool promoted = o.GetBool(L"promoted", false);
        if (store::SetPromoted(id, promoted)) ++applied;
    }
    log::Info(str::Format(L"backup restored: %s (%d icons applied)", fileName.c_str(), applied));
    return applied;
}

bool Remove(const std::wstring& fileName) {
    if (fileName.find(L"\\") != std::wstring::npos || fileName.find(L"/") != std::wstring::npos ||
        fileName.find(L"..") != std::wstring::npos)
        return false;  // path traversal guard
    return fs::DeleteFileNow(FilePath(fileName));
}

bool Export(const std::wstring& fileName, const std::wstring& destPath, std::wstring& err) {
    std::string raw;
    if (!fs::ReadTextFile(FilePath(fileName), raw)) {
        err = L"snapshot not found";
        return false;
    }
    if (!fs::WriteTextFileAtomic(destPath, raw)) {
        err = L"cannot write destination";
        return false;
    }
    return true;
}

void Prune(int keep) {
    const auto list = List();  // newest first
    for (size_t i = static_cast<size_t>(keep); i < list.size(); ++i) {
        fs::DeleteFileNow(FilePath(list[i].fileName));
    }
}

}  // namespace tig::backup
