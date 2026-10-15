#include "core/log.h"

#include "util/fs.h"
#include "util/str.h"

namespace tig::log {

namespace {
SRWLOCK g_lock = SRWLOCK_INIT;
std::deque<Entry> g_ring;
constexpr size_t kRingMax = 500;
constexpr int kKeepDays = 14;
std::wstring g_dir;
std::wstring g_currentFile;
DWORD g_currentDay = 0;

std::wstring DayStamp() {
    SYSTEMTIME st{};
    GetLocalTime(&st);
    return str::Format(L"%04d%02d%02d", st.wYear, st.wMonth, st.wDay);
}

void EnsureFile() {
    const std::wstring day = DayStamp();
    DWORD dayNum = 0;
    for (wchar_t c : day) dayNum = dayNum * 10 + static_cast<DWORD>(c - L'0');
    if (g_currentFile.empty() || dayNum != g_currentDay) {
        g_currentDay = dayNum;
        g_currentFile = g_dir + L"\\TrayIconGuard-" + day + L".log";
    }
}
}  // namespace

void Init() {
    AcquireSRWLockExclusive(&g_lock);
    g_dir = fs::LogsDir();
    EnsureFile();
    const int removed = fs::DeleteOlderThan(g_dir, L"TrayIconGuard-", L".log", kKeepDays);
    ReleaseSRWLockExclusive(&g_lock);
    if (removed > 0) Info(str::Format(L"log retention: removed %d old file(s)", removed));
}

std::wstring LevelName(Level lv) {
    switch (lv) {
        case Level::Debug: return L"DEBUG";
        case Level::Info: return L"INFO ";
        case Level::Event: return L"EVENT";
        case Level::Warn: return L"WARN ";
        case Level::Error: return L"ERROR";
    }
    return L"INFO ";
}

void Write(Level lv, const std::wstring& msg) {
    AcquireSRWLockExclusive(&g_lock);
    Entry e;
    GetLocalTime(&e.time);
    e.level = lv;
    e.msg = msg;
    g_ring.push_back(e);
    while (g_ring.size() > kRingMax) g_ring.pop_front();
    EnsureFile();
    const std::wstring path = g_currentFile;
    ReleaseSRWLockExclusive(&g_lock);

    const std::string line = str::ToUtf8(str::Format(
        L"%04d-%02d-%02d %02d:%02d:%02d.%03d [%s] %s\r\n", e.time.wYear, e.time.wMonth,
        e.time.wDay, e.time.wHour, e.time.wMinute, e.time.wSecond, e.time.wMilliseconds,
        LevelName(lv).c_str(), msg.c_str()));
    HANDLE h = CreateFileW(path.c_str(), FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE,
                           nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (h != INVALID_HANDLE_VALUE) {
        DWORD written = 0;
        WriteFile(h, line.data(), static_cast<DWORD>(line.size()), &written, nullptr);
        CloseHandle(h);
    }
}

void Debug(const std::wstring& m) { Write(Level::Debug, m); }
void Info(const std::wstring& m) { Write(Level::Info, m); }
void Event(const std::wstring& m) { Write(Level::Event, m); }
void Warn(const std::wstring& m) { Write(Level::Warn, m); }
void Error(const std::wstring& m) { Write(Level::Error, m); }

std::deque<Entry> Tail(size_t maxEntries) {
    AcquireSRWLockShared(&g_lock);
    std::deque<Entry> out;
    const size_t start = g_ring.size() > maxEntries ? g_ring.size() - maxEntries : 0;
    for (size_t i = start; i < g_ring.size(); ++i) out.push_back(g_ring[i]);
    ReleaseSRWLockShared(&g_lock);
    return out;
}

std::wstring CurrentFilePath() {
    AcquireSRWLockShared(&g_lock);
    const std::wstring p = g_currentFile;
    ReleaseSRWLockShared(&g_lock);
    return p;
}

}  // namespace tig::log
