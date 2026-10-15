#include "ui/lang/strings.h"

#include "core/os.h"
#include "core/settings.h"

namespace tig::l10n {

namespace {

// Order MUST match enum S exactly (enforced by array size + review).
const wchar_t* kEn[] = {
    /* NavDashboard */ L"Dashboard",
    /* NavIcons */ L"Tray icons",
    /* NavGuard */ L"Guard",
    /* NavAppearance */ L"Appearance",
    /* NavBackups */ L"Backups",
    /* NavActivity */ L"Activity",
    /* NavAbout */ L"About",
    /* Tagline */ L"Keep every tray icon visible",
    /* DashTitle */ L"Dashboard",
    /* DashSub */ L"Live state of your notification area",
    /* StatusGuarding */ L"Guard active",
    /* StatusPaused */ L"Guard paused",
    /* StatusOff */ L"Guard is off",
    /* StatusUnsupported */ L"Not supported on this Windows build",
    /* StatTotal */ L"Registered icons",
    /* StatPromoted */ L"On taskbar",
    /* StatHidden */ L"Hidden in flyout",
    /* StatExcluded */ L"Excluded",
    /* PromoteAllNow */ L"Promote all now",
    /* PauseGuard */ L"Pause guard",
    /* ResumeGuard */ L"Resume guard",
    /* RestartExplorer */ L"Restart Explorer",
    /* CardSystem */ L"System",
    /* CardRecent */ L"Recent activity",
    /* NoRecent */ L"No events yet this session",
    /* RowOs */ L"Windows",
    /* RowStore */ L"Icon store",
    /* RowStoreOk */ L"NotifyIconSettings (per-icon)",
    /* RowStoreNo */ L"Unavailable (build < 15063)",
    /* RowExplorer */ L"Explorer",
    /* RowLegacy */ L"Legacy switches",
    /* LegacyNone */ L"none active",
    /* LegacyAutoTray */ L"EnableAutoTray=0",
    /* LegacySca */ L"HideSCA* policies",
    /* HintAutostartTitle */ L"Start with Windows",
    /* HintAutostartText */ L"TrayIconGuard is not set to launch at logon. Enable autostart so your tray stays fixed after every reboot.",
    /* EnableAutostart */ L"Enable autostart",
    /* DisableAutostart */ L"Disable autostart",
    /* AutostartOn */ L"Autostart: on",
    /* AutostartOff */ L"Autostart: off",
    /* WelcomeTitle */ L"Welcome aboard",
    /* WelcomeText */ L"Every tray icon is visible now, and the guard keeps them that way. Tune anything on the pages at the left.",
    /* IconsTitle */ L"Tray icons",
    /* IconsSub */ L"Per-icon visibility, exactly like the Windows Settings toggle",
    /* SearchHint */ L"Search icons by name or path…",
    /* FilterAll */ L"All",
    /* FilterPromoted */ L"On taskbar",
    /* FilterHidden */ L"Hidden",
    /* FilterExcluded */ L"Excluded",
    /* PromoteAll */ L"Promote all",
    /* RestoreDefaults */ L"Restore Windows defaults",
    /* RestoreDefaultsTitle */ L"Restore Windows defaults?",
    /* RestoreDefaultsText */ L"This deletes the IsPromoted values of every tray icon and hands visibility control back to Windows. Hidden icons will return to the overflow flyout.",
    /* EmptyIcons */ L"No icons match the current filter",
    /* IconsCount */ L"icons",
    /* Never */ L"never",
    /* LastNotif */ L"last notification",
    /* MenuPromote */ L"Show on taskbar",
    /* MenuHide */ L"Hide in flyout",
    /* MenuExclude */ L"Keep hidden (exclude)",
    /* MenuUnexclude */ L"Remove exclusion",
    /* MenuOpenLocation */ L"Open file location",
    /* MenuCopyPath */ L"Copy executable path",
    /* MenuCopyId */ L"Copy icon id",
    /* GuardTitle */ L"Guard",
    /* GuardSub */ L"The watcher that defeats Windows' icon-hiding decay",
    /* CardWatcher */ L"Watcher",
    /* ToggleGuardRun */ L"Run the guard",
    /* ToggleGuardRunDesc */ L"Watch the tray store and instantly re-promote icons Explorer hides again",
    /* Debounce */ L"Debounce",
    /* Polling */ L"Polling fallback",
    /* PollingDesc */ L"Periodic rescan in case registry notifications are missed",
    /* PollOff */ L"Off",
    /* MsFmt */ L"%d ms",
    /* SecFmt */ L"%d s",
    /* AutoRestartExp */ L"Auto-restart Explorer",
    /* AutoRestartExpDesc */ L"If icons keep flipping back, restart the shell (with cooldown)",
    /* Cooldown */ L"Restart cooldown",
    /* Balloons */ L"Balloon notifications",
    /* BalloonsDesc */ L"Show a tray balloon when the guard promotes icons",
    /* CardRepairs */ L"Repairs && legacy",
    /* LegacyBelt */ L"Keep EnableAutoTray = 0",
    /* LegacyBeltDesc */ L"Harmless belt-and-suspenders switch that helps legacy shell components show all icons",
    /* RemoveSca */ L"Remove HideSCA* policies",
    /* RemoveScaDesc */ L"Deletes force-hidden system icons (volume, network, power) from Policies\\Explorer",
    /* ResetCache */ L"Reset legacy tray cache",
    /* ResetCacheDesc */ L"Clears IconStreams/PastIconsStream to remove phantom icons. Restart Explorer afterwards.",
    /* ResetCacheTitle */ L"Reset legacy tray cache?",
    /* ResetCacheText */ L"Phantom and stale icons will be cleared. A shell restart is recommended afterwards.",
    /* ScaRemoved */ L"HideSCA* policies removed",
    /* CacheReset */ L"Legacy tray cache reset",
    /* CardStats */ L"Session statistics",
    /* StatPasses */ L"Reconciliation passes",
    /* StatPromotions */ L"Icons promoted",
    /* StatLastFix */ L"Last fix",
    /* StatUptime */ L"Guard uptime",
    /* StatNone */ L"—",
    /* CardExclusions */ L"Exclusions (stay hidden)",
    /* ExclDesc */ L"Apps you want Windows to keep in the flyout. Wildcards * and ? are supported.",
    /* ExclHint */ L"e.g. onedrive.exe or *teams*",
    /* Add */ L"Add",
    /* Remove */ L"Remove",
    /* ExclEmpty */ L"No exclusions — every icon gets promoted.",
    /* ExclInvalid */ L"Pattern is empty",
    /* AppTitle */ L"Appearance",
    /* AppSub */ L"Make TrayIconGuard feel like home",
    /* CardTheme */ L"Theme",
    /* ThemeLight */ L"Light",
    /* ThemeDark */ L"Dark",
    /* ThemeSystem */ L"System",
    /* ThemeDesc */ L"System follows the Windows app mode automatically",
    /* CardAccent */ L"Accent color",
    /* AccentSystem */ L"Follow Windows",
    /* CardLanguage */ L"Language",
    /* LangAuto */ L"Auto",
    /* CardEffects */ L"Effects",
    /* Animations */ L"Animations",
    /* AnimationsDesc */ L"Smooth toggles, pills and page transitions",
    /* CompactRows */ L"Compact icon rows",
    /* CompactRowsDesc */ L"Single-line rows to fit more icons on screen",
    /* ResetAppearance */ L"Reset appearance",
    /* BackTitle */ L"Backups",
    /* BackSub */ L"JSON snapshots of the full tray state",
    /* AutoBackup */ L"Snapshot before bulk changes",
    /* AutoBackupDesc */ L"Automatically back up the tray state before promote-all and restore-defaults",
    /* CreateSnapshot */ L"Create snapshot now",
    /* RestoreLatest */ L"Restore latest",
    /* OpenFolder */ L"Open folder",
    /* EmptyBackups */ L"No snapshots yet",
    /* Restore */ L"Restore",
    /* Delete */ L"Delete",
    /* Export */ L"Export",
    /* RestoreTitle */ L"Restore this snapshot?",
    /* RestoreText */ L"The IsPromoted state of every icon in the snapshot will be written back to the registry.",
    /* DeleteTitle */ L"Delete snapshot?",
    /* DeleteText */ L"The snapshot file will be permanently removed.",
    /* ColSnapshot */ L"Snapshot",
    /* ColWhen */ L"Created",
    /* ColIcons */ L"Icons",
    /* ColActions */ L"Actions",
    /* SnapshotOk */ L"Snapshot created",
    /* SnapshotFail */ L"Snapshot failed",
    /* RestoredFmt */ L"Restored %d icon(s)",
    /* ActTitle */ L"Activity log",
    /* ActSub */ L"Everything the guard and you have done",
    /* FilterAllLv */ L"All",
    /* FilterEvents */ L"Events",
    /* FilterIssues */ L"Issues",
    /* ExportLog */ L"Export…",
    /* FollowNew */ L"Follow new entries",
    /* EmptyLog */ L"Nothing logged yet",
    /* LogExported */ L"Log exported",
    /* AboutTitle */ L"About",
    /* AboutSub */ L"TrayIconGuard v8 “Aurora”",
    /* Version */ L"Version",
    /* CheckUpdates */ L"Check for updates",
    /* Checking */ L"Checking…",
    /* UpdateNew */ L"Update available: %s",
    /* UpdateLatest */ L"You are on the latest version",
    /* UpdateFail */ L"Check failed: %s",
    /* CopyDiag */ L"Copy diagnostics",
    /* DiagCopied */ L"Diagnostics copied to clipboard",
    /* Links */ L"Links",
    /* RepoLink */ L"GitHub repository",
    /* LicenseLine */ L"License: PolyForm Noncommercial 1.0.0",
    /* CreditsLine */ L"Registry mechanics researched by paulmann/windows-show-all-tray-icons (v7 “Phoenix”). v8 is an independent native C++ rewrite.",
    /* PrivacyLine */ L"No telemetry. Nothing leaves this PC except a manual update check.",
    /* BuildLine */ L"Native x64 build, zero runtime dependencies",
    /* Ok */ L"OK",
    /* Cancel */ L"Cancel",
    /* Close */ L"Close",
    /* Yes */ L"Yes",
    /* No */ L"No",
    /* TrayShow */ L"Show TrayIconGuard",
    /* TrayPromote */ L"Promote all now",
    /* TrayPause */ L"Pause guard",
    /* TrayResume */ L"Resume guard",
    /* TrayRestartExp */ L"Restart Explorer",
    /* TrayExit */ L"Exit",
    /* BalloonPromotedTitle */ L"Icons promoted",
    /* BalloonPromotedText */ L"%d icon(s) back on the taskbar",
    /* BalloonWelcomeTitle */ L"TrayIconGuard is on duty",
    /* BalloonWelcomeText */ L"All tray icons are visible now. The guard keeps them that way.",
    /* BalloonCloseTitle */ L"Still running",
    /* BalloonCloseText */ L"TrayIconGuard minimized to the tray. Right-click its icon to exit.",
    /* StatusbarFmt */ L"Guard: %s  ·  %d on taskbar  ·  %d hidden  ·  %s  ·  v%s",
    /* Running */ L"active",
    /* Paused */ L"paused",
    /* Off */ L"off",
    /* ExpRestartTitle */ L"Restart Explorer?",
    /* ExpRestartText */ L"The shell (taskbar, desktop) will blink for a moment while Explorer restarts. Open folders stay open.",
    /* ExpRestartDone */ L"Explorer restarted",
    /* ExpRestartFail */ L"Explorer restart failed",
    /* ThemeTip */ L"Theme: %s",
    /* SetupTitle */ L"Install TrayIconGuard",
    /* SetupSub */ L"First run on this PC — choose how to run it",
    /* SetupWhere */ L"Install folder",
    /* SetupWhereHint */ L"Per-user location, no admin rights needed",
    /* SetupBrowse */ L"Browse…",
    /* SetupAutostart */ L"Start with Windows",
    /* SetupAutostartDesc */ L"Add to autostart (HKCU Run, minimized)",
    /* SetupDesktop */ L"Desktop shortcut",
    /* SetupDesktopDesc */ L"Place an icon on the desktop",
    /* SetupMenu */ L"Start Menu shortcut",
    /* SetupMenuDesc */ L"Programs group + uninstall entry in Apps & Features",
    /* SetupInstall */ L"Install",
    /* SetupPortable */ L"Just run once, no install",
    /* SetupNote */ L"Everything stays in your user profile. Uninstall any time via Apps & Features or --uninstall.",
    /* SetupOkTitle */ L"Installation complete",
    /* SetupOkText */ L"TrayIconGuard is installed. The app will now start from the new location.",
    /* SetupFail */ L"Installation failed: %s",
    /* AboutInstallBtn */ L"Install to this PC…",
    /* ModeInstalled */ L"Installed",
    /* ModePortable */ L"Portable",
    /* UninstallDone */ L"TrayIconGuard uninstalled",
    /* SetupOptions */ L"What to set up",
    /* LangHint */ L"Community-grade translations; missing strings fall back to English.",
    /* ModeFull */ L"Full (all icons shown)",
    /* ModeCompact */ L"Compact (hide all but TrayIconGuard)",
    /* ModeCustom */ L"Custom (as configured)",
    /* TrayAuthorSite */ L"Author's website",
    /* AuthorLbl */ L"Author",
    /* DragHint */ L"Drag rows up/down to reorder (saved on this PC)",
    /* UpdateAvailTitle */ L"Update available",
    /* UpdateNotesLbl */ L"What's new",
    /* UpdateNow */ L"Download and update",
    /* UpdateDownloading */ L"Downloading update…",
    /* UpdateApplyTitle */ L"Apply update now?",
    /* UpdateApplyText */ L"The app will close, replace itself and start the new version.",
    /* UpdateShaFail */ L"Update rejected: checksum mismatch",
    /* UpdateCheckAuto */ L"Check for updates automatically",
};
}  // namespace


std::wstring g_configured = L"auto";
std::wstring g_resolved = L"en";
const wchar_t* g_table[static_cast<int>(S::Count_)];

extern const LangTable kTable_zh;
extern const LangTable kTable_hi;
extern const LangTable kTable_es;
extern const LangTable kTable_ar;
extern const LangTable kTable_fr;
extern const LangTable kTable_bn;
extern const LangTable kTable_ru;
extern const LangTable kTable_pt;
extern const LangTable kTable_ur;
extern const LangTable kTable_id;
extern const LangTable kTable_de;
extern const LangTable kTable_ja;
extern const LangTable kTable_tr;
extern const LangTable kTable_ko;
extern const LangTable kTable_vi;
extern const LangTable kTable_it;
extern const LangTable kTable_th;
extern const LangTable kTable_pl;
extern const LangTable kTable_nl;
extern const LangTable kTable_uk;
extern const LangTable kTable_fa;
extern const LangTable kTable_el;
extern const LangTable kTable_cs;
extern const LangTable kTable_sv;
extern const LangTable kTable_hu;
extern const LangTable kTable_ro;
extern const LangTable kTable_he;
extern const LangTable kTable_fi;
extern const LangTable kTable_da;

namespace {
const LangTable kTable_en = {L"en", L"English", L"English", nullptr, 0};
}  // namespace

const std::vector<LangTable>& Languages() {
    static const std::vector<LangTable> v = {
        kTable_en, kTable_zh, kTable_hi, kTable_es, kTable_ar, kTable_fr, kTable_bn,
        kTable_ru, kTable_pt, kTable_ur, kTable_id, kTable_de, kTable_ja, kTable_tr,
        kTable_ko, kTable_vi, kTable_it, kTable_th, kTable_pl, kTable_nl, kTable_uk,
        kTable_fa, kTable_el, kTable_cs, kTable_sv, kTable_hu, kTable_ro, kTable_he,
        kTable_fi, kTable_da,
    };
    return v;
}

namespace {
void Rebuild() {
    const int n = static_cast<int>(S::Count_);
    for (int i = 0; i < n; ++i) g_table[i] = kEn[i];
    for (const auto& lt : Languages()) {
        if (g_resolved == lt.code) {
            for (size_t k = 0; k < lt.count; ++k) {
                const int id = lt.entries[k].id;
                if (id >= 0 && id < n) g_table[id] = lt.entries[k].s;
            }
        }
    }
}
}  // namespace

void SetLanguage(const std::wstring& code) {
    g_configured = code.empty() ? L"auto" : code;
    std::wstring want = g_configured;
    if (want == L"auto") want = os::UiLanguage();
    std::wstring found;
    for (const auto& lt : Languages()) {
        if (want == lt.code) { found = lt.code; break; }
    }
    g_resolved = found.empty() ? L"en" : found;
    Rebuild();
}

std::wstring CurrentLanguage() { return g_resolved; }
std::wstring ConfiguredLanguage() { return g_configured; }

const wchar_t* t(S id) {
    const int i = static_cast<int>(id);
    if (i < 0 || i >= static_cast<int>(S::Count_)) return L"?";
    return g_table[i] ? g_table[i] : kEn[i];
}

}  // namespace tig::l10n
