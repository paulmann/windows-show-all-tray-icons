#include "util/str.h"

#include <windows.h>

#include <algorithm>
#include <cstdarg>
#include <cwctype>

namespace tig::str {

std::wstring ToWide(const std::string& utf8) {
    if (utf8.empty()) return {};
    const int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
                                      static_cast<int>(utf8.size()), nullptr, 0);
    if (n <= 0) return {};
    std::wstring out(static_cast<size_t>(n), L'\0');
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
                        static_cast<int>(utf8.size()), out.data(), n);
    return out;
}

std::string ToUtf8(const std::wstring& w) {
    if (w.empty()) return {};
    const int n = WideCharToMultiByte(CP_UTF8, 0, w.data(), static_cast<int>(w.size()),
                                      nullptr, 0, nullptr, nullptr);
    if (n <= 0) return {};
    std::string out(static_cast<size_t>(n), '\0');
    WideCharToMultiByte(CP_UTF8, 0, w.data(), static_cast<int>(w.size()), out.data(), n,
                        nullptr, nullptr);
    return out;
}

std::wstring Format(const wchar_t* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    const int n = _vscwprintf(fmt, args);
    va_end(args);
    if (n < 0) return {};
    std::wstring out(static_cast<size_t>(n), L'\0');
    va_start(args, fmt);
    _vsnwprintf_s(out.data(), static_cast<size_t>(n) + 1, static_cast<size_t>(n), fmt, args);
    va_end(args);
    return out;
}

std::wstring ToLower(std::wstring s) {
    std::transform(s.begin(), s.end(), s.begin(), [](wchar_t c) { return static_cast<wchar_t>(std::towlower(c)); });
    return s;
}

bool IEquals(const std::wstring& a, const std::wstring& b) {
    return a.size() == b.size() && _wcsnicmp(a.c_str(), b.c_str(), a.size()) == 0;
}

bool IStartsWith(const std::wstring& s, const std::wstring& prefix) {
    return s.size() >= prefix.size() && _wcsnicmp(s.c_str(), prefix.c_str(), prefix.size()) == 0;
}

bool IEndsWith(const std::wstring& s, const std::wstring& suffix) {
    return s.size() >= suffix.size() &&
           _wcsnicmp(s.c_str() + (s.size() - suffix.size()), suffix.c_str(), suffix.size()) == 0;
}

std::wstring Trim(const std::wstring& s) {
    const wchar_t* ws = L" \t\r\n";
    const size_t b = s.find_first_not_of(ws);
    if (b == std::wstring::npos) return {};
    const size_t e = s.find_last_not_of(ws);
    return s.substr(b, e - b + 1);
}

std::vector<std::wstring> Split(const std::wstring& s, wchar_t sep) {
    std::vector<std::wstring> out;
    std::wstring cur;
    for (wchar_t c : s) {
        if (c == sep) {
            out.push_back(cur);
            cur.clear();
        } else {
            cur.push_back(c);
        }
    }
    out.push_back(cur);
    return out;
}

std::wstring Join(const std::vector<std::wstring>& parts, const std::wstring& sep) {
    std::wstring out;
    for (size_t i = 0; i < parts.size(); ++i) {
        if (i) out += sep;
        out += parts[i];
    }
    return out;
}

std::wstring ReplaceAll(std::wstring s, const std::wstring& from, const std::wstring& to) {
    if (from.empty()) return s;
    size_t pos = 0;
    while ((pos = s.find(from, pos)) != std::wstring::npos) {
        s.replace(pos, from.size(), to);
        pos += to.size();
    }
    return s;
}

namespace {
// Iterative wildcard matcher (no recursion depth issues).
bool WildcardMatchImpl(const wchar_t* t, const wchar_t* p) {
    const wchar_t* star = nullptr;
    const wchar_t* backtrack = t;
    while (*t) {
        if (*p == L'?') {
            ++t;
            ++p;
        } else if (*p == L'*') {
            star = p++;
            backtrack = t;
        } else if (std::towlower(*t) == std::towlower(*p)) {
            ++t;
            ++p;
        } else if (star) {
            p = star + 1;
            t = ++backtrack;
        } else {
            return false;
        }
    }
    while (*p == L'*') ++p;
    return !*p;
}
}  // namespace

bool WildcardMatch(const std::wstring& text, const std::wstring& pattern) {
    return WildcardMatchImpl(text.c_str(), pattern.c_str());
}

std::wstring FileNameOf(const std::wstring& path) {
    const size_t p = path.find_last_of(L"\\/");
    return p == std::wstring::npos ? path : path.substr(p + 1);
}

std::wstring DirNameOf(const std::wstring& path) {
    const size_t p = path.find_last_of(L"\\/");
    return p == std::wstring::npos ? std::wstring() : path.substr(0, p);
}

namespace {
std::vector<int> ParseVer(const std::wstring& v) {
    std::wstring digits;
    for (wchar_t c : v) {
        if (c >= L'0' && c <= L'9') digits.push_back(c);
        else if (!digits.empty() && digits.back() != L'.') digits.push_back(L'.');
    }
    if (!digits.empty() && digits.back() == L'.') digits.pop_back();
    std::vector<int> out;
    for (const auto& part : Split(digits, L'.')) {
        out.push_back(part.empty() ? 0 : _wtoi(part.c_str()));
    }
    while (out.size() < 4) out.push_back(0);
    return out;
}
}  // namespace

int CompareVersions(const std::wstring& a, const std::wstring& b) {
    const std::vector<int> va = ParseVer(a);
    const std::vector<int> vb = ParseVer(b);
    for (size_t i = 0; i < 4; ++i) {
        if (va[i] != vb[i]) return va[i] < vb[i] ? -1 : 1;
    }
    return 0;
}

}  // namespace tig::str
