// TrayIconGuard v8 — About page: version, updates (manual), links, diagnostics.
#include <windows.h>
#include <shellapi.h>

#include "core/log.h"
#include "core/os.h"
#include "core/settings.h"
#include "core/update.h"
#include "core/installer.h"
#include "ui/setupwizard.h"
#include "pages.h"
#include "ui/theme.h"
#include "util/fs.h"
#include "util/str.h"

namespace tig::ui {

#include "core/version.h"

namespace {
using tig::kVersion;
constexpr wchar_t kRepoUrl[] = L"https://github.com/paulmann/windows-show-all-tray-icons";
constexpr wchar_t kAuthorName[] = L"Mikhail Deynekin";
constexpr wchar_t kAuthorEmail[] = L"icons@Deynekin.com";
constexpr wchar_t kAuthorSite[] = L"https://Deynekin.com";

class AboutPage : public Page {
public:
    l10n::S TitleId() const override { return l10n::S::AboutTitle; }
    l10n::S SubId() const override { return l10n::S::AboutSub; }
    wchar_t Glyph() const override { return 0xE946; }

    Button* btnCheck = nullptr;
    Button* btnInstall = nullptr;
    Button* btnUpdate = nullptr;
    Toggle* tgAutoCheck = nullptr;
    update::FeedInfo feed;
    enum class UpState { Idle, Checking, Available, Failed, Downloading } upState =
        UpState::Idle;
    Button* btnRepo = nullptr;
    Button* btnSite = nullptr;
    Button* btnDiag = nullptr;
    std::wstring updateStatus;
    bool checking = false;

    void Build(HWND) override {
        auto bc = std::make_unique<Button>();
        bc->style = Button::Style::Outline;
        bc->glyph = 0xE895;
        bc->label = l10n::t(l10n::S::CheckUpdates);
        bc->onClick = [this] { StartCheck(); };
        btnCheck = bc.get();
        widgets.push_back(std::move(bc));

        auto br = std::make_unique<Button>();
        br->style = Button::Style::Subtle;
        br->glyph = 0xE71B;
        br->label = l10n::t(l10n::S::RepoLink);
        br->onClick = [] {
            ShellExecuteW(nullptr, L"open", kRepoUrl, nullptr, nullptr, SW_SHOWNORMAL);
        };
        btnRepo = br.get();
        widgets.push_back(std::move(br));

        auto bu = std::make_unique<Button>();
        bu->style = Button::Style::Accent;
        bu->glyph = 0xE896;
        bu->label = l10n::t(l10n::S::UpdateNow);
        bu->visible = false;
        bu->onClick = [this] {
            if (!dialogs::Confirm(hwndRef, l10n::t(l10n::S::UpdateApplyTitle),
                                  l10n::t(l10n::S::UpdateApplyText)))
                return;
            upState = UpState::Downloading;
            updateStatus = l10n::t(l10n::S::UpdateDownloading);
            InvalidateRect(hwndRef, nullptr, FALSE);
            struct UpJob {
                std::wstring url, sha;
                HWND hwnd;
            };
            auto* job = new UpJob{feed.url, feed.sha256, hwndRef};
            CreateThread(nullptr, 0,
                         [](LPVOID pp) -> DWORD {
                             std::unique_ptr<UpJob> j(static_cast<UpJob*>(pp));
                             wchar_t tmp[MAX_PATH] = {};
                             GetTempPathW(MAX_PATH, tmp);
                             const std::wstring dest =
                                 std::wstring(tmp) + L"TrayIconGuard-update.exe";
                             std::wstring err;
                             bool ok = update::DownloadFile(j->url, dest, err);
                             std::wstring got;
                             if (ok) ok = update::Sha256File(dest, got) && got == j->sha;
                             if (!ok) {
                                 DeleteFileW(dest.c_str());
                                 auto* e2 = new std::wstring(err.empty() ? L"sha256" : err);
                                 PostMessageW(j->hwnd, WM_APP + 64, 0,
                                              reinterpret_cast<LPARAM>(e2));
                                 return 0;
                             }
                             if (!update::ApplyUpdate(dest, err)) {
                                 DeleteFileW(dest.c_str());
                                 auto* e2 = new std::wstring(err);
                                 PostMessageW(j->hwnd, WM_APP + 64, 0,
                                              reinterpret_cast<LPARAM>(e2));
                                 return 0;
                             }
                             DeleteFileW(dest.c_str());
                             PostMessageW(j->hwnd, WM_APP + 62, 0, 0);
                             return 0;
                         },
                         job, 0, nullptr);
        };
        btnUpdate = bu.get();
        widgets.push_back(std::move(bu));

        auto tac = std::make_unique<Toggle>();
        tac->on = settings::Get().updateCheckEnabled;
        tac->onChange = [](bool v) {
            settings::Get().updateCheckEnabled = v;
            settings::Save();
        };
        tgAutoCheck = tac.get();
        widgets.push_back(std::move(tac));

        auto bi = std::make_unique<Button>();
        bi->style = Button::Style::Outline;
        bi->glyph = 0xE896;
        bi->label = l10n::t(l10n::S::AboutInstallBtn);
        bi->onClick = [this] {
            const ui::setup::Result wr =
                ui::setup::RunWizard(GetModuleHandleW(nullptr));
            if (wr.action == ui::setup::Action::Install) {
                std::wstring err;
                if (installer::Install(wr.opts, err)) {
                    if (installer::NeedsRelaunch())
                        dialogs::Info(hwndRef, l10n::t(l10n::S::SetupOkTitle),
                                      l10n::t(l10n::S::SetupOkText));
                    OnDataChanged();
                } else {
                    dialogs::Info(hwndRef, l10n::t(l10n::S::SetupFail),
                                  str::Format(l10n::t(l10n::S::SetupFail), err.c_str()));
                }
            }
            InvalidateRect(hwndRef, nullptr, FALSE);
        };
        btnInstall = bi.get();
        widgets.push_back(std::move(bi));

        auto bs = std::make_unique<Button>();
        bs->style = Button::Style::Subtle;
        bs->glyph = 0xE774;
        bs->label = l10n::t(l10n::S::TrayAuthorSite);
        bs->onClick = [] {
            ShellExecuteW(nullptr, L"open", kAuthorSite, nullptr, nullptr, SW_SHOWNORMAL);
        };
        btnSite = bs.get();
        widgets.push_back(std::move(bs));

        auto bd = std::make_unique<Button>();
        bd->style = Button::Style::Subtle;
        bd->glyph = 0xE8C8;
        bd->label = l10n::t(l10n::S::CopyDiag);
        bd->onClick = [this] { CopyDiagnostics(); };
        btnDiag = bd.get();
        widgets.push_back(std::move(bd));
    }

    void StartCheck() {
        if (checking) return;
        checking = true;
        updateStatus = l10n::t(l10n::S::Checking);
        if (btnCheck) btnCheck->enabled = false;
        InvalidateRect(hwndRef, nullptr, FALSE);
        // worker thread; result posted back via guard-independent message
        CreateThread(nullptr, 0,
                     [](LPVOID self) -> DWORD {
                         auto* page = static_cast<AboutPage*>(self);
                         const update::Result r = update::Check(kVersion);
                         PostMessageW(MainWindow::Instance().Hwnd(), WM_APP + 60,
                                      r.isNewer ? 1 : 0,
                                      reinterpret_cast<LPARAM>(new update::Result(r)));
                         (void)page;
                         return 0;
                     },
                     this, 0, nullptr);
    }

    void OnUpdateMessage(WPARAM, LPARAM lp) override {
        auto* r = reinterpret_cast<update::Result*>(lp);
        checking = false;
        if (btnCheck) btnCheck->enabled = true;
        if (!r->ok)
            updateStatus = str::Format(l10n::t(l10n::S::UpdateFail), r->err.c_str());
        else if (r->isNewer)
            updateStatus = str::Format(l10n::t(l10n::S::UpdateNew), r->latestTag.c_str());
        else
            updateStatus = l10n::t(l10n::S::UpdateLatest);
        InvalidateRect(hwndRef, nullptr, FALSE);
    }

    void OnFeedMessage(LPARAM lp) {
        auto* fi = reinterpret_cast<update::FeedInfo*>(lp);
        feed = *fi;
        delete fi;
        checking = false;
        if (btnCheck) btnCheck->enabled = true;
        if (!feed.ok) {
            upState = UpState::Failed;
            updateStatus = str::Format(l10n::t(l10n::S::UpdateFail), feed.err.c_str());
        } else if (str::CompareVersions(feed.version, tig::kVersion) > 0) {
            upState = UpState::Available;
            updateStatus = str::Format(l10n::t(l10n::S::UpdateNew), feed.version.c_str());
            if (btnUpdate) btnUpdate->visible = true;
        } else {
            upState = UpState::Idle;
            updateStatus = l10n::t(l10n::S::UpdateLatest);
        }
        InvalidateRect(hwndRef, nullptr, FALSE);
    }

    void OnDownloadError(LPARAM lp) {
        auto* e = reinterpret_cast<std::wstring*>(lp);
        upState = UpState::Failed;
        updateStatus = (*e == L"sha256") ? l10n::t(l10n::S::UpdateShaFail)
                                         : str::Format(l10n::t(l10n::S::UpdateFail), e->c_str());
        delete e;
        InvalidateRect(hwndRef, nullptr, FALSE);
    }

    void CopyDiagnostics() {
        std::wstring text = L"TrayIconGuard 8.0.0 diagnostics\r\n";
        text += L"OS: " + os::Get().caption + L"\r\n";
        text += std::wstring(L"Theme: ") +
                (theme::IsDark() ? L"dark" : L"light") + L"\r\n";
        text += L"Language: " + l10n::CurrentLanguage() + L"\r\n";
        text += L"Settings: " + fs::AppDataDir() + L"\r\n";
        text += L"Log: " + log::CurrentFilePath() + L"\r\n\r\nLast log lines:\r\n";
        for (const auto& e : log::Tail(25)) {
            text += str::Format(L"%02d:%02d:%02d [%s] %s\r\n", e.time.wHour, e.time.wMinute,
                                e.time.wSecond, log::LevelName(e.level).c_str(), e.msg.c_str());
        }
        if (OpenClipboard(hwndRef)) {
            EmptyClipboard();
            const HGLOBAL h = GlobalAlloc(GMEM_MOVEABLE, (text.size() + 1) * sizeof(wchar_t));
            if (h) {
                auto* p = static_cast<wchar_t*>(GlobalLock(h));
                if (p) {
                    wcscpy_s(p, text.size() + 1, text.c_str());
                    GlobalUnlock(h);
                    SetClipboardData(CF_UNICODETEXT, h);
                }
            }
            CloseClipboard();
            log::Info(L"diagnostics copied");
        }
    }

    void Refresh() override {
        Page::Refresh();
        if (btnCheck && !checking) btnCheck->label = l10n::t(l10n::S::CheckUpdates);
        if (btnRepo) btnRepo->label = l10n::t(l10n::S::RepoLink);
        if (btnSite) btnSite->label = l10n::t(l10n::S::TrayAuthorSite);
        if (btnDiag) btnDiag->label = l10n::t(l10n::S::CopyDiag);
    }

    void LayoutContent(HWND hwnd, int width) override {
        const int pad = 28;
        const int W = width - pad * 2;
        int y = 12;
        const int appH = 156;
        RECT appCard{pad, y, pad + W, y + appH};
        y += appH + 12;
        const int updH = 40 + 56 + 44;
        RECT updCard{pad, y, pad + W, y + updH};
        y += updH + 12;
        const int linksH = 40 + 56 + 96;
        RECT linksCard{pad, y, pad + W, y + linksH};
        y += linksH + 16;

        const int bw = btnCheck->PreferredWidth(hwnd);
        btnCheck->Layout({updCard.left + 16, updCard.top + 44, updCard.left + 16 + bw,
                          updCard.top + 76});
        const int bwU = btnUpdate->PreferredWidth(hwnd);
        btnUpdate->Layout({btnCheck->rc.right + 8, updCard.top + 44,
                           btnCheck->rc.right + 8 + bwU, updCard.top + 76});
        tgAutoCheck->Layout({updCard.left + 16, updCard.top + 84, updCard.right - 16,
                             updCard.top + 120});
        btnInstall->visible = settings::Get().installMode != L"installed";
        const int bwI = btnInstall->PreferredWidth(hwnd);
        const int bwR = btnRepo->PreferredWidth(hwnd);
        const int bwS = btnSite->PreferredWidth(hwnd);
        const int bwD = btnDiag->PreferredWidth(hwnd);
        btnRepo->Layout({linksCard.left + 16, linksCard.top + 44, linksCard.left + 16 + bwR,
                         linksCard.top + 76});
        btnSite->Layout({btnRepo->rc.right + 8, linksCard.top + 44, btnRepo->rc.right + 8 + bwS,
                         linksCard.top + 76});
        btnDiag->Layout({btnRepo->rc.right + 8, linksCard.top + 44, btnRepo->rc.right + 8 + bwD,
                         linksCard.top + 76});
        if (btnInstall->visible)
            btnInstall->Layout({btnSite->rc.right + 8, linksCard.top + 44,
                                btnSite->rc.right + 8 + bwI, linksCard.top + 76});
        btnDiag->Layout({linksCard.left + 16, linksCard.top + 84, linksCard.left + 16 + bwD,
                         linksCard.top + 116});
        geoApp = ToWindow(appCard);
        geoUpd = ToWindow(updCard);
        geoLinks = ToWindow(linksCard);
        contentH = y;
    }

    void PaintBackground(PaintCtx& pc) override {
        const Palette& P = theme::Pal();
        const HWND hwnd = hwndRef;
        DrawCard(pc, geoApp);
        Gdiplus::Bitmap* icon = gfx::AppIconBitmap(64);
        if (icon) {
            Gdiplus::RectF ir(geoApp.left + 20.f, geoApp.top + 24.f, 64.f, 64.f);
            pc.g.DrawImage(icon, ir);
        }
        Gdiplus::RectF nr(geoApp.left + 100.f, geoApp.top + 26.f,
                          static_cast<float>(geoApp.right - geoApp.left) - 120.f, 30.f);
        gfx::DrawString(pc.g, L"TrayIconGuard v8 “Aurora”",
                        gfx::Font(hwnd, 20.f, FontStyle::SemiBold), nr, gfx::C(P.textPrimary));
        Gdiplus::RectF vr(nr.X, nr.GetBottom(), nr.Width, 20.f);
        gfx::DrawString(pc.g,
                        str::Format(L"%s %s · %s", l10n::t(l10n::S::Version), tig::kVersion,
                                    l10n::t(l10n::S::BuildLine)),
                        gfx::Font(hwnd, 12.f), vr, gfx::C(P.textSecondary));
        Gdiplus::RectF lr(vr.X, vr.GetBottom() + 2.f, nr.Width, 20.f);
        gfx::DrawString(pc.g, l10n::t(l10n::S::LicenseLine), gfx::Font(hwnd, 12.f), lr,
                        gfx::C(P.textSecondary));
        Gdiplus::RectF ar(lr.X, lr.GetBottom() + 2.f, nr.Width, 20.f);
        gfx::DrawString(pc.g, std::wstring(l10n::t(l10n::S::AuthorLbl)) + L":  " + kAuthorName +
                            L"  <" + kAuthorEmail + L">  ·  " + kAuthorSite,
                        gfx::Font(hwnd, 12.f, FontStyle::Medium), ar, gfx::C(P.textPrimary),
                        Gdiplus::StringAlignmentNear);

    }

    void Paint(PaintCtx& pc) override {
        Page::Paint(pc);
        const Palette& P = theme::Pal();
        const HWND hwnd = hwndRef;
        DrawCard(pc, geoUpd, l10n::t(l10n::S::CheckUpdates));
        {
            Gdiplus::RectF al(geoUpd.left + 16.f, static_cast<float>(tgAutoCheck->rc.top),
                              300.f, 36.f);
            gfx::DrawString(pc.g, l10n::t(l10n::S::UpdateCheckAuto),
                            gfx::Font(hwnd, 13.f, FontStyle::Medium), al,
                            gfx::C(P.textPrimary), Gdiplus::StringAlignmentNear);
        }
        if (upState == UpState::Available && !feed.notes.empty()) {
            Gdiplus::RectF nn(geoUpd.left + 16.f, static_cast<float>(btnCheck->rc.bottom) + 6.f,
                              static_cast<float>(geoUpd.right - geoUpd.left) - 32.f, 34.f);
            Gdiplus::StringFormat wrap;
            wrap.SetAlignment(Gdiplus::StringAlignmentNear);
            wrap.SetLineAlignment(Gdiplus::StringAlignmentNear);
            Gdiplus::SolidBrush br2(gfx::C(P.textSecondary));
            const std::wstring notes =
                std::wstring(l10n::t(l10n::S::UpdateNotesLbl)) + L": " + feed.notes;
            pc.g.DrawString(notes.c_str(), -1, gfx::Font(hwnd, 11.f), nn, &wrap, &br2);
        }
        if (!updateStatus.empty()) {
            Gdiplus::RectF us(btnCheck->rc.right + 16.f, static_cast<float>(btnCheck->rc.top),
                              static_cast<float>(geoUpd.right - btnCheck->rc.right - 32), 32.f);
            gfx::DrawString(pc.g, updateStatus, gfx::Font(hwnd, 12.5f, FontStyle::Medium), us,
                            gfx::C(checking ? P.textSecondary : P.textPrimary),
                            Gdiplus::StringAlignmentNear);
        }

        DrawCard(pc, geoLinks, l10n::t(l10n::S::Links));
        const std::wstring modeTxt = settings::Get().installMode == L"installed"
                                           ? l10n::t(l10n::S::ModeInstalled)
                                           : l10n::t(l10n::S::ModePortable);
        Gdiplus::RectF mr(geoLinks.left + 16.f, static_cast<float>(geoLinks.top) + 44.f, 200.f, 32.f);
        gfx::DrawString(pc.g, modeTxt, gfx::Font(hwnd, 12.f, FontStyle::Medium), mr,
                        gfx::C(P.textSecondary), Gdiplus::StringAlignmentNear);
        Gdiplus::RectF cr(geoLinks.left + 16.f, static_cast<float>(btnDiag->rc.bottom) + 10.f,
                          static_cast<float>(geoLinks.right - geoLinks.left) - 32.f, 80.f);
        Gdiplus::StringFormat fmt;
        fmt.SetAlignment(Gdiplus::StringAlignmentNear);
        fmt.SetLineAlignment(Gdiplus::StringAlignmentNear);
        Gdiplus::SolidBrush br1(gfx::C(P.textSecondary));
        const std::wstring credits =
            l10n::t(l10n::S::CreditsLine) + std::wstring(L"\n") + l10n::t(l10n::S::PrivacyLine);
        pc.g.DrawString(credits.c_str(), -1, gfx::Font(hwnd, 11.5f),
                        Gdiplus::RectF(cr.X, cr.Y, cr.Width, cr.Height), &fmt, &br1);
    }

    RECT geoApp{}, geoUpd{}, geoLinks{};
};

}  // namespace

std::unique_ptr<Page> MakeAboutPage() { return std::make_unique<AboutPage>(); }

}  // namespace tig::ui
