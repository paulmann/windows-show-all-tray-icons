// TrayIconGuard v8 — i18n: 30 locales, English default, per-string EN fallback.
#pragma once
#include <string>
#include <vector>

namespace tig::l10n {

enum class S {
    // nav
    NavDashboard, NavIcons, NavGuard, NavAppearance, NavBackups, NavActivity, NavAbout,
    Tagline,
    // dashboard
    DashTitle, DashSub, StatusGuarding, StatusPaused, StatusOff, StatusUnsupported,
    StatTotal, StatPromoted, StatHidden, StatExcluded,
    PromoteAllNow, PauseGuard, ResumeGuard, RestartExplorer,
    CardSystem, CardRecent, NoRecent, RowOs, RowStore, RowStoreOk, RowStoreNo, RowExplorer,
    RowLegacy, LegacyNone, LegacyAutoTray, LegacySca,
    HintAutostartTitle, HintAutostartText, EnableAutostart, DisableAutostart, AutostartOn, AutostartOff,
    WelcomeTitle, WelcomeText,
    // icons page
    IconsTitle, IconsSub, SearchHint, FilterAll, FilterPromoted, FilterHidden, FilterExcluded,
    PromoteAll, RestoreDefaults, RestoreDefaultsTitle, RestoreDefaultsText,
    EmptyIcons, IconsCount, Never, LastNotif,
    MenuPromote, MenuHide, MenuExclude, MenuUnexclude, MenuOpenLocation, MenuCopyPath, MenuCopyId,
    // guard page
    GuardTitle, GuardSub, CardWatcher, ToggleGuardRun, ToggleGuardRunDesc,
    Debounce, Polling, PollingDesc, PollOff, MsFmt, SecFmt,
    AutoRestartExp, AutoRestartExpDesc, Cooldown,
    Balloons, BalloonsDesc,
    CardRepairs, LegacyBelt, LegacyBeltDesc, RemoveSca, RemoveScaDesc, ResetCache, ResetCacheDesc,
    ResetCacheTitle, ResetCacheText, ScaRemoved, CacheReset,
    CardStats, StatPasses, StatPromotions, StatLastFix, StatUptime, StatNone,
    CardExclusions, ExclDesc, ExclHint, Add, Remove, ExclEmpty, ExclInvalid,
    // appearance
    AppTitle, AppSub, CardTheme, ThemeLight, ThemeDark, ThemeSystem, ThemeDesc,
    CardAccent, AccentSystem, CardLanguage, LangAuto, CardEffects,
    Animations, AnimationsDesc, CompactRows, CompactRowsDesc, ResetAppearance,
    // backups
    BackTitle, BackSub, AutoBackup, AutoBackupDesc, CreateSnapshot, RestoreLatest, OpenFolder,
    EmptyBackups, Restore, Delete, Export, RestoreTitle, RestoreText, DeleteTitle, DeleteText,
    ColSnapshot, ColWhen, ColIcons, ColActions, SnapshotOk, SnapshotFail, RestoredFmt,
    // activity
    ActTitle, ActSub, FilterAllLv, FilterEvents, FilterIssues, ExportLog, FollowNew, EmptyLog,
    LogExported,
    // about
    AboutTitle, AboutSub, Version, CheckUpdates, Checking, UpdateNew, UpdateLatest, UpdateFail,
    CopyDiag, DiagCopied, Links, RepoLink, LicenseLine, CreditsLine, PrivacyLine, BuildLine,
    // common
    Ok, Cancel, Close, Yes, No,
    TrayShow, TrayPromote, TrayPause, TrayResume, TrayRestartExp, TrayExit,
    BalloonPromotedTitle, BalloonPromotedText, BalloonWelcomeTitle, BalloonWelcomeText,
    BalloonCloseTitle, BalloonCloseText,
    StatusbarFmt, Running, Paused, Off,
    ExpRestartTitle, ExpRestartText, ExpRestartDone, ExpRestartFail,
    ThemeTip,
    SetupTitle, SetupSub, SetupWhere, SetupWhereHint, SetupBrowse,
    SetupAutostart, SetupAutostartDesc, SetupDesktop, SetupDesktopDesc,
    SetupMenu, SetupMenuDesc, SetupInstall, SetupPortable, SetupNote,
    SetupOkTitle, SetupOkText, SetupFail, AboutInstallBtn, ModeInstalled, ModePortable,
    UninstallDone, SetupOptions, LangHint,
    ModeFull, ModeCompact, ModeCustom, TrayAuthorSite, AuthorLbl,
    DragHint, UpdateAvailTitle, UpdateNotesLbl, UpdateNow, UpdateDownloading,
    UpdateApplyTitle, UpdateApplyText, UpdateShaFail, UpdateCheckAuto,
    // installer scope (8.4)
    SetupScopeMe, SetupScopeAll, SetupHintMachine, SetupNoteMachine, LicenseBtn, WikiBtn,
    Count_,
};

struct Entry { int id; const wchar_t* s; };
struct LangTable {
    const wchar_t* code;      // BCP-47 primary tag, e.g. "pt"
    const wchar_t* native;    // endonym, e.g. "Português"
    const wchar_t* english;   // English name, e.g. "Portuguese"
    const Entry* entries;     // sparse translations (nullptr for the EN base)
    size_t count;
};

// 30 locales ordered by worldwide prevalence; English first (default/fallback).
const std::vector<LangTable>& Languages();
const wchar_t* t(S id);
// "auto" | <code>; auto resolves via the OS UI language, unknown -> "en".
void SetLanguage(const std::wstring& code);
std::wstring CurrentLanguage();    // resolved code actually in use
std::wstring ConfiguredLanguage(); // raw setting ("auto" allowed)

}  // namespace tig::l10n
