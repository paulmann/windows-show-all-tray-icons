#include "core/json.h"

#include <cmath>
#include <cstdio>
#include <cwchar>

#include "util/str.h"

namespace tig::json {

namespace {

struct Parser {
    const std::wstring& s;
    size_t i = 0;
    std::wstring err;

    explicit Parser(const std::wstring& text) : s(text) {}

    bool Fail(const std::wstring& msg) {
        err = str::Format(L"%s (at offset %zu)", msg.c_str(), i);
        return false;
    }
    void SkipWs() {
        while (i < s.size() && (s[i] == L' ' || s[i] == L'\t' || s[i] == L'\r' || s[i] == L'\n')) ++i;
    }
    bool Peek(wchar_t c) { SkipWs(); return i < s.size() && s[i] == c; }
    bool Eat(wchar_t c) {
        if (!Peek(c)) return false;
        ++i;
        return true;
    }

    bool ParseValue(Value& out) {
        SkipWs();
        if (i >= s.size()) return Fail(L"unexpected end");
        const wchar_t c = s[i];
        if (c == L'{') return ParseObject(out);
        if (c == L'[') return ParseArray(out);
        if (c == L'"') { out = Value::MakeString(L""); return ParseString(out.str); }
        if (c == L't' || c == L'f') return ParseBool(out);
        if (c == L'n') {
            if (s.compare(i, 4, L"null") == 0) { i += 4; out = Value(); return true; }
            return Fail(L"bad literal");
        }
        return ParseNumber(out);
    }

    bool ParseObject(Value& out) {
        out = Value::MakeObject();
        ++i;  // '{'
        if (Eat(L'}')) return true;
        while (true) {
            SkipWs();
            if (i >= s.size() || s[i] != L'"') return Fail(L"expected key");
            std::wstring key;
            if (!ParseString(key)) return false;
            if (!Eat(L':')) return Fail(L"expected ':'");
            Value v;
            if (!ParseValue(v)) return false;
            out.Set(key, std::move(v));
            if (Eat(L',')) continue;
            if (Eat(L'}')) return true;
            return Fail(L"expected ',' or '}'");
        }
    }

    bool ParseArray(Value& out) {
        out = Value::MakeArray();
        ++i;  // '['
        if (Eat(L']')) return true;
        while (true) {
            Value v;
            if (!ParseValue(v)) return false;
            out.Push(std::move(v));
            if (Eat(L',')) continue;
            if (Eat(L']')) return true;
            return Fail(L"expected ',' or ']'");
        }
    }

    bool ParseString(std::wstring& out) {
        ++i;  // '"'
        out.clear();
        while (i < s.size()) {
            wchar_t c = s[i++];
            if (c == L'"') return true;
            if (c == L'\\') {
                if (i >= s.size()) break;
                const wchar_t e = s[i++];
                switch (e) {
                    case L'"': out.push_back(L'"'); break;
                    case L'\\': out.push_back(L'\\'); break;
                    case L'/': out.push_back(L'/'); break;
                    case L'b': out.push_back(L'\b'); break;
                    case L'f': out.push_back(L'\f'); break;
                    case L'n': out.push_back(L'\n'); break;
                    case L'r': out.push_back(L'\r'); break;
                    case L't': out.push_back(L'\t'); break;
                    case L'u': {
                        if (i + 4 > s.size()) return Fail(L"bad \\u escape");
                        unsigned cp = 0;
                        for (int k = 0; k < 4; ++k) {
                            const wchar_t h = s[i++];
                            cp <<= 4;
                            if (h >= L'0' && h <= L'9') cp |= static_cast<unsigned>(h - L'0');
                            else if (h >= L'a' && h <= L'f') cp |= static_cast<unsigned>(h - L'a' + 10);
                            else if (h >= L'A' && h <= L'F') cp |= static_cast<unsigned>(h - L'A' + 10);
                            else return Fail(L"bad hex");
                        }
                        if (cp >= 0xD800 && cp <= 0xDBFF && i + 6 <= s.size() &&
                            s[i] == L'\\' && s[i + 1] == L'u') {
                            i += 2;
                            unsigned lo = 0;
                            for (int k = 0; k < 4; ++k) {
                                const wchar_t h = s[i++];
                                lo <<= 4;
                                if (h >= L'0' && h <= L'9') lo |= static_cast<unsigned>(h - L'0');
                                else if (h >= L'a' && h <= L'f') lo |= static_cast<unsigned>(h - L'a' + 10);
                                else if (h >= L'A' && h <= L'F') lo |= static_cast<unsigned>(h - L'A' + 10);
                                else return Fail(L"bad hex");
                            }
                            cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
                        }
                        if (cp < 0x10000) {
                            out.push_back(static_cast<wchar_t>(cp));
                        } else {
                            cp -= 0x10000;
                            out.push_back(static_cast<wchar_t>(0xD800 + (cp >> 10)));
                            out.push_back(static_cast<wchar_t>(0xDC00 + (cp & 0x3FF)));
                        }
                        break;
                    }
                    default: return Fail(L"bad escape");
                }
            } else if (c == L'\n' || c == L'\r') {
                return Fail(L"newline in string");
            } else {
                out.push_back(c);
            }
        }
        return Fail(L"unterminated string");
    }

    bool ParseBool(Value& out) {
        if (s.compare(i, 4, L"true") == 0) { i += 4; out = Value::MakeBool(true); return true; }
        if (s.compare(i, 5, L"false") == 0) { i += 5; out = Value::MakeBool(false); return true; }
        return Fail(L"bad literal");
    }

    bool ParseNumber(Value& out) {
        const size_t start = i;
        if (i < s.size() && (s[i] == L'-' || s[i] == L'+')) ++i;
        while (i < s.size() && ((s[i] >= L'0' && s[i] <= L'9') || s[i] == L'.' ||
                                s[i] == L'e' || s[i] == L'E' || s[i] == L'-' || s[i] == L'+'))
            ++i;
        if (start == i) return Fail(L"bad number");
        const std::wstring tok = s.substr(start, i - start);
        out = Value::MakeNumber(wcstod(tok.c_str(), nullptr));
        return true;
    }
};

void EscapeInto(std::wstring& out, const std::wstring& s) {
    out.push_back(L'"');
    for (wchar_t c : s) {
        switch (c) {
            case L'"': out += L"\\\""; break;
            case L'\\': out += L"\\\\"; break;
            case L'\n': out += L"\\n"; break;
            case L'\r': out += L"\\r"; break;
            case L'\t': out += L"\\t"; break;
            case L'\b': out += L"\\b"; break;
            case L'\f': out += L"\\f"; break;
            default:
                if (c < 0x20) {
                    wchar_t buf[8];
                    swprintf(buf, 8, L"\\u%04x", c);
                    out += buf;
                } else {
                    out.push_back(c);  // raw UTF-16 -> UTF-8 at serialization boundary
                }
        }
    }
    out.push_back(L'"');
}

void WriteInto(const Value& v, bool pretty, int depth, std::wstring& out) {
    const wchar_t* pad = pretty ? L"\n" : L"";
    std::wstring indent;
    if (pretty) indent.assign(static_cast<size_t>(depth) * 2, L' ');
    const std::wstring indentNext = pretty ? indent + L"  " : indent;
    switch (v.type) {
        case Value::Null: out += L"null"; break;
        case Value::Bool: out += v.boolean ? L"true" : L"false"; break;
        case Value::Number: {
            if (v.number == std::floor(v.number) && std::fabs(v.number) < 1e15) {
                out += str::Format(L"%lld", static_cast<long long>(v.number));
            } else {
                out += str::Format(L"%.17g", v.number);
            }
            break;
        }
        case Value::String: EscapeInto(out, v.str); break;
        case Value::Array: {
            out += L'[';
            for (size_t k = 0; k < v.arr.size(); ++k) {
                if (k) out += L',';
                out += pad;
                out += indentNext;
                WriteInto(v.arr[k], pretty, depth + 1, out);
            }
            if (!v.arr.empty()) { out += pad; out += indent; }
            out += L']';
            break;
        }
        case Value::Object: {
            out += L'{';
            for (size_t k = 0; k < v.obj.size(); ++k) {
                if (k) out += L',';
                out += pad;
                out += indentNext;
                EscapeInto(out, v.obj[k].first);
                out += pretty ? L": " : L":";
                WriteInto(v.obj[k].second, pretty, depth + 1, out);
            }
            if (!v.obj.empty()) { out += pad; out += indent; }
            out += L'}';
            break;
        }
    }
}

}  // namespace

bool Parse(const std::wstring& text, Value& out, std::wstring& err) {
    Parser p(text);
    if (!p.ParseValue(out)) { err = p.err; return false; }
    p.SkipWs();
    if (p.i != text.size()) { err = p.Fail(L"trailing garbage"); return false; }
    return true;
}

std::wstring Write(const Value& v, bool pretty) {
    std::wstring out;
    WriteInto(v, pretty, 0, out);
    return out;
}

}  // namespace tig::json
