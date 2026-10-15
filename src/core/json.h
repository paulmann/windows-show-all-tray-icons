// TrayIconGuard v8 — minimal dependency-free JSON (subset sufficient for
// settings/backups: objects, arrays, strings, numbers, bools, null).
// Parser is strict-ish but tolerant of trailing whitespace; writer emits
// pretty or compact UTF-8 (via caller conversion). Agent A1.
#pragma once
#include <string>
#include <vector>

namespace tig::json {

class Value {
public:
    enum Type { Null, Bool, Number, String, Array, Object };

    Type type = Null;
    bool boolean = false;
    double number = 0.0;
    std::wstring str;
    std::vector<Value> arr;
    std::vector<std::pair<std::wstring, Value>> obj;  // insertion-ordered

    static Value MakeObject() { Value v; v.type = Object; return v; }
    static Value MakeArray() { Value v; v.type = Array; return v; }
    static Value MakeString(std::wstring s) { Value v; v.type = String; v.str = std::move(s); return v; }
    static Value MakeNumber(double d) { Value v; v.type = Number; v.number = d; return v; }
    static Value MakeBool(bool b) { Value v; v.type = Bool; v.boolean = b; return v; }

    const Value* Find(const std::wstring& key) const {
        if (type != Object) return nullptr;
        for (const auto& kv : obj)
            if (kv.first == key) return &kv.second;
        return nullptr;
    }
    Value& Set(const std::wstring& key, Value v) {
        if (type != Object) { type = Object; obj.clear(); }
        for (auto& kv : obj)
            if (kv.first == key) { kv.second = std::move(v); return kv.second; }
        obj.emplace_back(key, std::move(v));
        return obj.back().second;
    }
    void Push(Value v) {
        if (type != Array) { type = Array; arr.clear(); }
        arr.push_back(std::move(v));
    }

    bool GetBool(const std::wstring& k, bool def) const {
        const Value* v = Find(k);
        return v && v->type == Bool ? v->boolean : def;
    }
    double GetNum(const std::wstring& k, double def) const {
        const Value* v = Find(k);
        return v && v->type == Number ? v->number : def;
    }
    int GetInt(const std::wstring& k, int def) const {
        const Value* v = Find(k);
        return v && v->type == Number ? static_cast<int>(v->number) : def;
    }
    std::wstring GetStr(const std::wstring& k, const std::wstring& def) const {
        const Value* v = Find(k);
        return v && v->type == String ? v->str : def;
    }
};

// Returns true on success; err receives a human-readable message.
bool Parse(const std::wstring& text, Value& out, std::wstring& err);
// pretty=false -> compact single line.
std::wstring Write(const Value& v, bool pretty);

}  // namespace tig::json
