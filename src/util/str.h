// TrayIconGuard v8 "Aurora" — string utilities (UTF-8 <-> UTF-16, matching, formatting).
// Part of agent A1 (core). No external dependencies.
#pragma once
#include <string>
#include <vector>

namespace tig::str {

std::wstring ToWide(const std::string& utf8);
std::string ToUtf8(const std::wstring& w);

// printf-style wide formatting (safe, bounded).
std::wstring Format(const wchar_t* fmt, ...);

bool IEquals(const std::wstring& a, const std::wstring& b);
bool IStartsWith(const std::wstring& s, const std::wstring& prefix);
bool IEndsWith(const std::wstring& s, const std::wstring& suffix);
std::wstring ToLower(std::wstring s);
std::wstring Trim(const std::wstring& s);
std::vector<std::wstring> Split(const std::wstring& s, wchar_t sep);
std::wstring Join(const std::vector<std::wstring>& parts, const std::wstring& sep);
std::wstring ReplaceAll(std::wstring s, const std::wstring& from, const std::wstring& to);

// Case-insensitive wildcard match supporting '*' and '?'.
bool WildcardMatch(const std::wstring& text, const std::wstring& pattern);

std::wstring FileNameOf(const std::wstring& path);
std::wstring DirNameOf(const std::wstring& path);

// "v8.0.1" / "8.0.1" / "8.0" -> comparable tuple; returns <0 / 0 / >0.
int CompareVersions(const std::wstring& a, const std::wstring& b);

}  // namespace tig::str
