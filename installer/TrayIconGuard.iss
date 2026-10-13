; ==========================================================================
; TrayIconGuard - Inno Setup 6 script (optional installer packaging)
; --------------------------------------------------------------------------
; Prereq: run  pwsh -File build.ps1 -Task PublishExe -SelfContained
;         so artifacts\publish\win-x64 contains TrayIconGuard.exe
; Compile: "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\TrayIconGuard.iss
; Result:  artifacts\installer\TrayIconGuard-7.0.3-setup.exe
; ==========================================================================

#define MyAppName "TrayIconGuard"
#define MyAppVersion "7.0.3"
#define MyAppPublisher "windows-show-all-tray-icons"
#define MyAppUrl "https://github.com/paulmann/windows-show-all-tray-icons"
#define MyAppExeName "TrayIconGuard.exe"
#define PublishDir "..\artifacts\publish\win-x64"

[Setup]
AppId={{9C1F5A7E-2B4D-4C8F-A6E3-7D0B1C2E3F40}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppUrl}
AppSupportURL={#MyAppUrl}
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
PrivilegesRequired=lowest
DisableProgramGroupPage=auto
OutputDir=..\artifacts\installer
OutputBaseFilename=TrayIconGuard-{#MyAppVersion}-setup
SetupIconFile=..\app\src\TrayIconGuard\Assets\app.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=force
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "autostart";    Description: "Start TrayIconGuard when I sign in (recommended)"; Flags: checkedonce
Name: "promotenow";   Description: "Show all tray icons now (apply immediately)";      Flags: checkedonce
Name: "desktopicon";  Description: "{cm:CreateDesktopIcon}";                           Flags: unchecked

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}";            Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}";      Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; Autostart (same value the PowerShell edition manages: HKCU Run -> TrayIconGuard)
Root: HKA; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; \
    ValueType: string; ValueName: "TrayIconGuard"; \
    ValueData: """{app}\{#MyAppExeName}"" --minimized"; \
    Flags: uninsdeletevalue; Tasks: autostart

[Run]
; Apply immediately after install (headless one-shot mode of the exe)
Filename: "{app}\{#MyAppExeName}"; Parameters: "--promote-all"; \
    Flags: runhidden nowait skipifsilent; Tasks: promotenow
; Launch minimized when the user finishes the wizard
Filename: "{app}\{#MyAppExeName}"; Parameters: "--minimized"; \
    Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Ensure no orphaned process keeps files locked
Filename: "{sys}\taskkill.exe"; Parameters: "/f /im {#MyAppExeName}"; \
    Flags: runhidden; RunOnceId: "KillTrayIconGuard"

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
