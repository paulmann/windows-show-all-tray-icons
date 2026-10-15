#include "core/settings.h"

#include "core/json.h"
#include "core/version.h"
#include "core/log.h"
#include "util/fs.h"
#include "util/str.h"

namespace tig::settings {

namespace {
Settings g_settings;
bool g_firstRun = false;
bool g_loaded = false;
}  // namespace

Settings& Get() { return g_settings; }
bool IsFirstRun() { return g_firstRun; }
std::wstring FilePath() { return fs::AppDataDir() + L"\\settings.json"; }

void Load() {
    if (g_loaded) return;
    g_loaded = true;
    Settings& s = g_settings;
    std::string raw;
    if (!fs::ReadTextFile(FilePath(), raw) || raw.empty()) {
        g_firstRun = true;
        return;
    }
    json::Value root;
    std::wstring err;
    if (!json::Parse(str::ToWide(raw), root, err) || root.type != json::Value::Object) {
        log::Warn(L"settings.json unreadable (" + err + L") — using defaults");
        g_firstRun = true;
        return;
    }
    const json::Value* ap = root.Find(L"appearance");
    if (ap) {
        const int tm = ap->GetInt(L"theme", 0);
        s.theme = (tm >= 0 && tm <= 2) ? static_cast<ThemeMode>(tm) : ThemeMode::System;
        s.accent = ap->GetStr(L"accent", L"system");
        s.language = ap->GetStr(L"language", L"auto");
        s.animations = ap->GetBool(L"animations", true);
        s.compactRows = ap->GetBool(L"compactRows", false);
    }
    const json::Value* bh = root.Find(L"behavior");
    if (bh) {
        s.startMinimized = bh->GetBool(L"startMinimized", false);
        s.closeToTray = bh->GetBool(L"closeToTray", true);
        s.autoStart = bh->GetBool(L"autoStart", false);
        s.notifications = bh->GetBool(L"notifications", true);
        s.confirmExplorerRestart = bh->GetBool(L"confirmExplorerRestart", true);
        s.autoBackup = bh->GetBool(L"autoBackup", true);
    }
    const json::Value* gd = root.Find(L"guard");
    if (gd) {
        s.guardEnabled = gd->GetBool(L"enabled", true);
        s.debounceMs = gd->GetInt(L"debounceMs", 400);
        if (s.debounceMs < 50) s.debounceMs = 50;
        if (s.debounceMs > 5000) s.debounceMs = 5000;
        s.pollMs = gd->GetInt(L"pollMs", 0);
        if (s.pollMs < 0) s.pollMs = 0;
        s.autoRestartExplorer = gd->GetBool(L"autoRestartExplorer", false);
        s.explorerCooldownSec = gd->GetInt(L"explorerCooldownSec", 60);
        if (s.explorerCooldownSec < 10) s.explorerCooldownSec = 10;
        s.legacyBelt = gd->GetBool(L"legacyBelt", true);
    }
    const json::Value* ic = root.Find(L"icons");
    if (ic) {
        const json::Value* uh = ic->Find(L"userHidden");
        if (uh && uh->type == json::Value::Array)
            for (const auto& v : uh->arr)
                if (v.type == json::Value::String && !v.str.empty()) s.userHidden.push_back(v.str);
        const json::Value* ordr = ic->Find(L"order");
        if (ordr && ordr->type == json::Value::Array)
            for (const auto& v : ordr->arr)
                if (v.type == json::Value::String && !v.str.empty()) s.iconsOrder.push_back(v.str);
        const json::Value* ex = ic->Find(L"exclusions");
        if (ex && ex->type == json::Value::Array) {
            for (const auto& v : ex->arr)
                if (v.type == json::Value::String && !v.str.empty())
                    s.exclusions.push_back(v.str);
        }
    }
    s.displayMode = root.Find(L"guard") && root.Find(L"guard")->Find(L"displayMode")
                        ? root.Find(L"guard")->GetStr(L"displayMode", L"custom")
                        : L"custom";
    const json::Value* up = root.Find(L"updates");
    if (up) {
        s.updateCheckEnabled = up->GetBool(L"checkEnabled", false);
        s.updateFeedUrl = up->GetStr(L"feedUrl", L"");
        s.updateLastCheck = static_cast<unsigned long long>(up->GetNum(L"lastCheck", 0));
    }
    const json::Value* ins = root.Find(L"install");
    if (ins) {
        s.installMode = ins->GetStr(L"mode", L"unknown");
        s.installDir = ins->GetStr(L"dir", L"");
    }
    const json::Value* st = root.Find(L"state");
    if (st) {
        s.firstRunDone = st->GetBool(L"firstRunDone", false);
        s.lastPage = st->GetStr(L"lastPage", L"dashboard");
        s.winX = st->GetInt(L"winX", -1);
        s.winY = st->GetInt(L"winY", -1);
        s.winW = st->GetInt(L"winW", 0);
        s.winH = st->GetInt(L"winH", 0);
        s.winMax = st->GetBool(L"winMax", false);
    }
    if (!s.firstRunDone) g_firstRun = true;
}

bool Save() {
    Load();
    const Settings& s = g_settings;
    json::Value root = json::Value::MakeObject();
    root.Set(L"schema", json::Value::MakeNumber(8));
    root.Set(L"app", json::Value::MakeString(std::wstring(L"TrayIconGuard ") + kVersion));

    json::Value ap = json::Value::MakeObject();
    ap.Set(L"theme", json::Value::MakeNumber(static_cast<int>(s.theme)));
    ap.Set(L"accent", json::Value::MakeString(s.accent));
    ap.Set(L"language", json::Value::MakeString(s.language));
    ap.Set(L"animations", json::Value::MakeBool(s.animations));
    ap.Set(L"compactRows", json::Value::MakeBool(s.compactRows));
    root.Set(L"appearance", ap);

    json::Value bh = json::Value::MakeObject();
    bh.Set(L"startMinimized", json::Value::MakeBool(s.startMinimized));
    bh.Set(L"closeToTray", json::Value::MakeBool(s.closeToTray));
    bh.Set(L"autoStart", json::Value::MakeBool(s.autoStart));
    bh.Set(L"notifications", json::Value::MakeBool(s.notifications));
    bh.Set(L"confirmExplorerRestart", json::Value::MakeBool(s.confirmExplorerRestart));
    bh.Set(L"autoBackup", json::Value::MakeBool(s.autoBackup));
    root.Set(L"behavior", bh);

    json::Value gd = json::Value::MakeObject();
    gd.Set(L"enabled", json::Value::MakeBool(s.guardEnabled));
    gd.Set(L"debounceMs", json::Value::MakeNumber(s.debounceMs));
    gd.Set(L"pollMs", json::Value::MakeNumber(s.pollMs));
    gd.Set(L"autoRestartExplorer", json::Value::MakeBool(s.autoRestartExplorer));
    gd.Set(L"explorerCooldownSec", json::Value::MakeNumber(s.explorerCooldownSec));
    gd.Set(L"legacyBelt", json::Value::MakeBool(s.legacyBelt));
    gd.Set(L"displayMode", json::Value::MakeString(s.displayMode));
    root.Set(L"guard", gd);

    json::Value ic = json::Value::MakeObject();
    json::Value uh = json::Value::MakeArray();
    for (const auto& e : s.userHidden) uh.Push(json::Value::MakeString(e));
    ic.Set(L"userHidden", uh);
    json::Value ordr = json::Value::MakeArray();
    for (const auto& e : s.iconsOrder) ordr.Push(json::Value::MakeString(e));
    ic.Set(L"order", ordr);
    json::Value ex = json::Value::MakeArray();
    for (const auto& e : s.exclusions) ex.Push(json::Value::MakeString(e));
    ic.Set(L"exclusions", ex);
    root.Set(L"icons", ic);

    json::Value up = json::Value::MakeObject();
    up.Set(L"checkEnabled", json::Value::MakeBool(s.updateCheckEnabled));
    up.Set(L"feedUrl", json::Value::MakeString(s.updateFeedUrl));
    up.Set(L"lastCheck", json::Value::MakeNumber(static_cast<double>(s.updateLastCheck)));
    root.Set(L"updates", up);

    json::Value ins = json::Value::MakeObject();
    ins.Set(L"mode", json::Value::MakeString(s.installMode));
    ins.Set(L"dir", json::Value::MakeString(s.installDir));
    root.Set(L"install", ins);

    json::Value st = json::Value::MakeObject();
    st.Set(L"firstRunDone", json::Value::MakeBool(true));
    st.Set(L"lastPage", json::Value::MakeString(s.lastPage));
    st.Set(L"winX", json::Value::MakeNumber(s.winX));
    st.Set(L"winY", json::Value::MakeNumber(s.winY));
    st.Set(L"winW", json::Value::MakeNumber(s.winW));
    st.Set(L"winH", json::Value::MakeNumber(s.winH));
    st.Set(L"winMax", json::Value::MakeBool(s.winMax));
    root.Set(L"state", st);

    const bool ok = fs::WriteTextFileAtomic(FilePath(), str::ToUtf8(json::Write(root, true)));
    if (ok) g_firstRun = false;
    else log::Error(L"failed to save settings to " + FilePath());
    return ok;
}

}  // namespace tig::settings
