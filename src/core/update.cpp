#include "core/update.h"

#include <windows.h>
#include <winhttp.h>
#include <bcrypt.h>

#include "core/json.h"
#include "core/log.h"
#include "core/settings.h"
#include "core/version.h"
#include "util/fs.h"
#include "util/str.h"

namespace tig::update {

namespace {

constexpr wchar_t kDefaultFeed[] =
    L"https://raw.githubusercontent.com/paulmann/windows-show-all-tray-icons/main/update/stable.json";

bool UrlAllowed(const std::wstring& url) {
    if (str::IStartsWith(url, L"https://")) return true;
    // loopback http is permitted for local QA servers only
    return str::IStartsWith(url, L"http://127.0.0.1") || str::IStartsWith(url, L"http://localhost");
}

struct UrlParts {
    std::wstring host, path;
    int port = 0;
    bool https = true;
};

bool ParseUrl(const std::wstring& url, UrlParts& out) {
    std::wstring u = url;
    if (str::IStartsWith(u, L"https://")) {
        out.https = true;
        u = u.substr(8);
    } else if (str::IStartsWith(u, L"http://")) {
        out.https = false;
        u = u.substr(7);
    } else {
        return false;
    }
    const size_t slash = u.find(L'/');
    std::wstring hostport = slash == std::wstring::npos ? u : u.substr(0, slash);
    out.path = slash == std::wstring::npos ? L"/" : u.substr(slash);
    const size_t colon = hostport.find(L':');
    if (colon == std::wstring::npos) {
        out.host = hostport;
        out.port = out.https ? INTERNET_DEFAULT_HTTPS_PORT : INTERNET_DEFAULT_HTTP_PORT;
    } else {
        out.host = hostport.substr(0, colon);
        out.port = _wtoi(hostport.substr(colon + 1).c_str());
    }
    return !out.host.empty();
}

// GET url -> body (string) or file. Exactly one of outBody/outFile used.
bool HttpGet(const std::wstring& url, std::string* outBody, const std::wstring* outFile,
             std::wstring& err) {
    if (!UrlAllowed(url)) {
        err = L"only https (or loopback http for tests) feeds are allowed";
        return false;
    }
    UrlParts up;
    if (!ParseUrl(url, up)) {
        err = L"bad feed url";
        return false;
    }
    bool ok = false;
    HINTERNET session = WinHttpOpen(L"TrayIconGuard/" TIG_VERSION_A, WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
                                    nullptr, nullptr, 0);
    if (!session) {
        err = str::Format(L"WinHttpOpen failed (%lu)", GetLastError());
        return false;
    }
    WinHttpSetTimeouts(session, 8000, 8000, 10000, 60000);
    HINTERNET conn = WinHttpConnect(session, up.host.c_str(), static_cast<INTERNET_PORT>(up.port), 0);
    if (!conn) {
        err = str::Format(L"connect failed (%lu)", GetLastError());
        WinHttpCloseHandle(session);
        return false;
    }
    HINTERNET req = WinHttpOpenRequest(conn, L"GET", up.path.c_str(), nullptr, nullptr,
                                       WINHTTP_DEFAULT_ACCEPT_TYPES,
                                       up.https ? WINHTTP_FLAG_SECURE : 0);
    if (!req) {
        err = str::Format(L"open request failed (%lu)", GetLastError());
        WinHttpCloseHandle(conn);
        WinHttpCloseHandle(session);
        return false;
    }
    BOOL sent = WinHttpSendRequest(req, WINHTTP_NO_ADDITIONAL_HEADERS, 0, nullptr, 0, 0, 0);
    if (sent) sent = WinHttpReceiveResponse(req, nullptr);
    if (!sent) {
        err = str::Format(L"request failed (%lu)", GetLastError());
    } else {
        DWORD status = 0, sz = sizeof(status);
        WinHttpQueryHeaders(req, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER, nullptr,
                            &status, &sz, nullptr);
        if (status != 200) {
            err = str::Format(L"HTTP %lu", status);
        } else {
            HANDLE hf = INVALID_HANDLE_VALUE;
            if (outFile) {
                hf = CreateFileW(outFile->c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
                                 FILE_ATTRIBUTE_NORMAL, nullptr);
                if (hf == INVALID_HANDLE_VALUE) {
                    err = L"cannot create destination file";
                }
            }
            if (!outFile || hf != INVALID_HANDLE_VALUE) {
                ok = true;
                for (;;) {
                    DWORD avail = 0;
                    if (!WinHttpQueryDataAvailable(req, &avail) || avail == 0) break;
                    std::string chunk(avail, '\0');
                    DWORD read = 0;
                    if (!WinHttpReadData(req, chunk.data(), avail, &read)) {
                        ok = false;
                        err = str::Format(L"read failed (%lu)", GetLastError());
                        break;
                    }
                    if (outBody) {
                        outBody->append(chunk.data(), read);
                    } else {
                        DWORD written = 0;
                        if (!WriteFile(hf, chunk.data(), read, &written, nullptr) ||
                            written != read) {
                            ok = false;
                            err = L"disk write failed";
                            break;
                        }
                    }
                }
            } else {
                ok = false;
            }
            if (hf != INVALID_HANDLE_VALUE) CloseHandle(hf);
        }
    }
    WinHttpCloseHandle(req);
    WinHttpCloseHandle(conn);
    WinHttpCloseHandle(session);
    return ok;
}

std::wstring HexOf(const BYTE* buf, DWORD len) {
    std::wstring out;
    static const wchar_t* digits = L"0123456789abcdef";
    for (DWORD i = 0; i < len; ++i) {
        out.push_back(digits[buf[i] >> 4]);
        out.push_back(digits[buf[i] & 0xF]);
    }
    return out;
}
}  // namespace

std::wstring DefaultFeedUrl() { return kDefaultFeed; }

std::wstring EffectiveFeedUrl() {
    const std::wstring& over = settings::Get().updateFeedUrl;
    return over.empty() ? std::wstring(kDefaultFeed) : over;
}

FeedInfo FetchFeed(const std::wstring& url) {
    FeedInfo fi;
    std::string body;
    if (!HttpGet(url, &body, nullptr, fi.err)) return fi;
    json::Value v;
    std::wstring jerr;
    if (!json::Parse(str::ToWide(body), v, jerr)) {
        fi.err = L"bad feed JSON: " + jerr;
        return fi;
    }
    fi.version = v.GetStr(L"version", L"");
    fi.url = v.GetStr(L"url", L"");
    fi.sha256 = str::ToLower(v.GetStr(L"sha256", L""));
    fi.notes = v.GetStr(L"notes", L"");
    fi.released = v.GetStr(L"released", L"");
    fi.channel = v.GetStr(L"channel", L"stable");
    if (fi.version.empty() || fi.url.empty() || fi.sha256.size() != 64) {
        fi.err = L"feed missing version/url/sha256(64 hex)";
        return fi;
    }
    fi.ok = true;
    return fi;
}

Result Check(const std::wstring& currentVersion) {
    Result r;
    const FeedInfo fi = FetchFeed(EffectiveFeedUrl());
    if (!fi.ok) {
        // fall back to the legacy GitHub releases probe
        HINTERNET session = WinHttpOpen(L"TrayIconGuard/" TIG_VERSION_A,
                                        WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY, nullptr, nullptr, 0);
        if (!session) {
            r.err = fi.err;
            return r;
        }
        HINTERNET conn = WinHttpConnect(session, L"api.github.com", INTERNET_DEFAULT_HTTPS_PORT, 0);
        HINTERNET req = conn ? WinHttpOpenRequest(conn, L"GET",
                                                  L"/repos/paulmann/windows-show-all-tray-icons/releases/latest",
                                                  nullptr, nullptr, WINHTTP_DEFAULT_ACCEPT_TYPES,
                                                  WINHTTP_FLAG_SECURE)
                             : nullptr;
        std::string body;
        if (req && WinHttpSendRequest(req, WINHTTP_NO_ADDITIONAL_HEADERS, 0, nullptr, 0, 0, 0) &&
            WinHttpReceiveResponse(req, nullptr)) {
            for (;;) {
                DWORD avail = 0;
                if (!WinHttpQueryDataAvailable(req, &avail) || !avail) break;
                std::string chunk(avail, '\0');
                DWORD read = 0;
                if (!WinHttpReadData(req, chunk.data(), avail, &read)) break;
                body.append(chunk.data(), read);
            }
        }
        if (req) WinHttpCloseHandle(req);
        if (conn) WinHttpCloseHandle(conn);
        WinHttpCloseHandle(session);
        json::Value v;
        std::wstring jerr;
        if (body.empty() || !json::Parse(str::ToWide(body), v, jerr)) {
            r.err = fi.err.empty() ? L"feed and releases probe failed" : fi.err;
            return r;
        }
        r.latestTag = v.GetStr(L"tag_name", L"");
        r.url = v.GetStr(L"html_url", L"");
        r.ok = !r.latestTag.empty();
        r.isNewer = r.ok && str::CompareVersions(r.latestTag, currentVersion) > 0;
        return r;
    }
    r.ok = true;
    r.latestTag = fi.version;
    r.url = fi.url;
    r.isNewer = str::CompareVersions(fi.version, currentVersion) > 0;
    return r;
}

bool DownloadFile(const std::wstring& url, const std::wstring& dest, std::wstring& err) {
    return HttpGet(url, nullptr, &dest, err);
}

bool Sha256File(const std::wstring& path, std::wstring& hexLower) {
    BCRYPT_ALG_HANDLE alg = nullptr;
    if (BCryptOpenAlgorithmProvider(&alg, BCRYPT_SHA256_ALGORITHM, nullptr, 0) != 0) return false;
    BCRYPT_HASH_HANDLE hash = nullptr;
    bool ok = false;
    if (BCryptCreateHash(alg, &hash, nullptr, 0, nullptr, 0, 0) == 0) {
        HANDLE hf = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                                OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (hf != INVALID_HANDLE_VALUE) {
            ok = true;
            char buf[65536];
            DWORD read = 0;
            while (ReadFile(hf, buf, sizeof(buf), &read, nullptr) && read > 0) {
                if (BCryptHashData(hash, reinterpret_cast<PUCHAR>(buf), read, 0) != 0) {
                    ok = false;
                    break;
                }
            }
            CloseHandle(hf);
            if (ok) {
                BYTE digest[32];
                if (BCryptFinishHash(hash, digest, sizeof(digest), 0) == 0) {
                    hexLower = HexOf(digest, sizeof(digest));
                } else {
                    ok = false;
                }
            }
        }
        BCryptDestroyHash(hash);
    }
    BCryptCloseAlgorithmProvider(alg, 0);
    return ok;
}

bool ApplyUpdate(const std::wstring& newExePath, std::wstring& err) {
    const std::wstring self = fs::ModulePath();
    const std::wstring old = self + L".old";
    DeleteFileW(old.c_str());
    // renaming the running image is allowed; overwriting it is not
    if (!MoveFileExW(self.c_str(), old.c_str(), 0)) {
        err = str::Format(L"cannot rename running exe (%lu)", GetLastError());
        return false;
    }
    if (!MoveFileExW(newExePath.c_str(), self.c_str(),
                     MOVEFILE_REPLACE_EXISTING | MOVEFILE_COPY_ALLOWED)) {
        err = str::Format(L"cannot move new exe into place (%lu)", GetLastError());
        MoveFileExW(old.c_str(), self.c_str(), MOVEFILE_REPLACE_EXISTING);  // rollback
        return false;
    }
    MoveFileExW(old.c_str(), nullptr, MOVEFILE_DELAY_UNTIL_REBOOT);
    log::Info(L"update applied: " + self);
    return true;
}

}  // namespace tig::update
