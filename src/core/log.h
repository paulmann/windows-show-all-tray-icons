// TrayIconGuard v8 — rotating file log + in-memory ring for the Activity page.
// Thread-safe (SRWLOCK). Daily files: TrayIconGuard-yyyyMMdd.log, 14-day retention.
#pragma once
#include <deque>
#include <string>
#include <windows.h>

namespace tig::log {

enum class Level { Debug = 0, Info = 1, Event = 2, Warn = 3, Error = 4 };

struct Entry {
    SYSTEMTIME time{};
    Level level = Level::Info;
    std::wstring msg;
};

void Init();  // sets log dir, cleans old files, writes session header
void Write(Level lv, const std::wstring& msg);
void Debug(const std::wstring& msg);
void Info(const std::wstring& msg);
void Event(const std::wstring& msg);  // guard/promotion events
void Warn(const std::wstring& msg);
void Error(const std::wstring& msg);

std::deque<Entry> Tail(size_t maxEntries);  // snapshot copy, oldest first
std::wstring LevelName(Level lv);
std::wstring CurrentFilePath();

}  // namespace tig::log
