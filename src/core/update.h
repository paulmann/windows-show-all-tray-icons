// TrayIconGuard v8 — git-based updater: feed JSON from a Git repo (raw URL),
// download over WinHTTP, SHA-256 verify (BCrypt), self-replace via rename chain.
// See Updater_SKILL.MD for the publication contract.
#pragma once
#include <string>

namespace tig::update {

struct Result {           // legacy simple check (kept for compatibility)
    bool ok = false;
    std::wstring latestTag;
    std::wstring url;
    std::wstring err;
    bool isNewer = false;
};

struct FeedInfo {
    bool ok = false;
    std::wstring err;
    std::wstring version;   // "8.3.0"
    std::wstring url;       // direct download URL of the new exe (https, or http on loopback for tests)
    std::wstring sha256;    // lowercase hex of the exe
    std::wstring notes;     // release notes (one paragraph)
    std::wstring released;  // ISO date
    std::wstring channel;   // "stable" | "beta"
};

// Default feed: raw file in the project Git repository (see Updater_SKILL.MD).
std::wstring DefaultFeedUrl();
// Effective feed: settings.updateFeedUrl override or DefaultFeedUrl().
std::wstring EffectiveFeedUrl();

FeedInfo FetchFeed(const std::wstring& url);
Result Check(const std::wstring& currentVersion);  // legacy GitHub-releases probe

bool DownloadFile(const std::wstring& url, const std::wstring& dest, std::wstring& err);
bool Sha256File(const std::wstring& path, std::wstring& hexLower);
// Replace the running exe: self -> self.old, new -> self, self.old deleted at reboot.
bool ApplyUpdate(const std::wstring& newExePath, std::wstring& err);

}  // namespace tig::update
