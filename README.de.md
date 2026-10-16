# TrayIconGuard v8 «Aurora» 🛡️✨

[![Version](https://img.shields.io/badge/Version-8.6.0-green)](https://github.com/paulmann/windows-show-all-tray-icons/releases/latest)
[![Lizenz](https://img.shields.io/badge/Lizenz-PolyForm%20Noncommercial%201.0.0-orange)](LICENSE)
[![Native C++17](https://img.shields.io/badge/native-C%2B%2B17-00599C?logo=cplusplus&logoColor=white)](https://en.cppreference.com/w/)
[![Keine Abhängigkeiten](https://img.shields.io/badge/Abhängigkeiten-NULL-brightgreen)](docs/BUILD.md)
[![EXE-Größe](https://img.shields.io/badge/exe-~1.05%20MB-blue)](https://github.com/paulmann/windows-show-all-tray-icons/releases/latest)
[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows/)
[![CI](https://github.com/paulmann/windows-show-all-tray-icons/actions/workflows/ci.yml/badge.svg)](https://github.com/paulmann/windows-show-all-tray-icons/actions/workflows/ci.yml)

> **Hält alle Symbole im Infobereich (System Tray) unter Windows 10/11 sichtbar — und sorgt
> dafür, dass sie sichtbar bleiben. Eine native exe, null Abhängigkeiten, null Telemetrie.**

**In anderen Sprachen:** [English](README.md) · [Русский](README.ru.md) · Deutsch · [中文](README.zh.md) · [Español](README.es.md) · [हिन्दी](README.hi.md)

TrayIconGuard holt Symbole, die Windows im Overflow-Flyout versteckt, zurück in die Taskleiste —
und ein **ereignisgesteuerter Guard** holt sie in dem Moment zurück, in dem Explorer sie erneut
versteckt (App-Start, Update, Neuregistrierung). Geschrieben wird exakt der Registry-Speicher,
den auch der Windows-Einstellungen-Schalter benutzt — pro Benutzer, ohne Adminrechte — und das
alles in **einer statisch gelinkten ~1-MB-exe** mit modernem Fluent-GUI, Headless-Watcher und
vollständiger CLI, lauffähig auf jedem Standard-Windows.

![Dashboard hell & dunkel, alle Seiten](shots/preview-2x2.png)

---

## 📋 Inhaltsverzeichnis

- [🚀 Warum TrayIconGuard?](#-warum-trayiconguard)
- [✨ Kernfunktionen](#-kernfunktionen)
- [⚡ Schnellstart](#-schnellstart)
- [📦 Installationsoptionen](#-installationsoptionen)
- [🖥️ GUI-Rundgang](#-gui-rundgang)
- [🧰 CLI-Referenz](#-cli-referenz)
- [🏗️ Funktionsweise](#-funktionsweise)
- [🔄 Selbstupdate über Git](#-selbstupdate-über-git)
- [🌍 Sprachen](#-sprachen)
- [🌗 Themes & Design](#-themes--design)
- [🏢 Deployment & Automatisierung](#-deployment--automatisierung)
- [🔍 Fehlerbehebung](#-fehlerbehebung)
- [🛠️ Aus dem Quellcode bauen](#-aus-dem-quellcode-bauen)
- [🗂️ Repository-Übersicht](#-repository-übersicht)
- [🤝 Mitwirken](#-mitwirken)
- [📄 Lizenz](#-lizenz)
- [👨‍ Autor & Support](#-autor--support)
- [🎯 Roadmap](#-roadmap)

---

## 🚀 Warum TrayIconGuard?

Windows merkt sich die Sichtbarkeit von Tray-Symbolen pro Symbol — und **vergisst sie ständig**:
Jedes Mal, wenn eine Anwendung ihr Infobereich-Symbol (neu) registriert, erzeugt Explorer den
Registry-Unterschlüssel mit `IsPromoted=0` neu, und die Symbole verschwinden wieder im
`^`-Flyout. Einmalige Tweaks und `.reg`-Dateien zerfallen deshalb innerhalb weniger Stunden.

```text
# Was auf einem Standard-Windows 10/11 tatsächlich passiert
App startet / wird aktualisiert / registriert Tray-Symbol neu
        │
        ▼
Explorer erzeugt HKCU\Control Panel\NotifyIconSettings\{id} neu
mit IsPromoted = 0          ← Symbol hat sich gerade versteckt
        │
        ▼
TrayIconGuard-Watcher (RegNotifyChangeKeyValue, ~400 ms Debounce)
        │
        ▼
IsPromoted = 1 wiederhergestellt ← Symbol ist sofort zurück in der Taskleiste
```

### Praxisnutzen

- **⚡ Sofort**: ereignisgesteuert statt Polling — Korrekturen in unter einer halben Sekunde
- **🎯 Präzise**: Steuerung pro Symbol, Ausschlüsse, Ziehen für die Reihenfolge, drei Sichtbarkeitsmodi
- **🛡️ Rücksichtsvoll**: nur HKCU, Standardbenutzer, nie Admin, keine Telemetrie, Autostart opt-in
- **📦 Winzig**: eine statische exe (~1,05 MB) — kein .NET, keine Runtimes, keine Redistributables
- **🔁 Selbstheilend**: überlebt Explorer-Neustarts, App-Updates und Anmeldezyklen

## ✨ Kernfunktionen

### 🛡️ **Korrektheit & Sicherheit**

- **Mechanik auf Einstellungen-Niveau** — schreibt `IsPromoted` in
  `HKCU\Control Panel\NotifyIconSettings`, exakt der Speicher des Windows-Schalters
  (siehe [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md))
- **JSON-Snapshots** (Schema v8) mit automatischem Backup vor destruktiven Operationen,
  Restore/Export/Delete-Manager, Aufbewahrung von 30 Snapshots
- **Sanfte Degradation** auf alten Builds: klarer Status, Legacy-Fallbacks, keine Abstürze
- **Stabile Exit-Codes** (`0/1/2/3`) für Scripting und RMM

### 🎯 **Intelligente Guard-Engine**

- **Ereignis-Watcher**: `RegNotifyChangeKeyValue` auf dem Speicher-Unterbaum + Debounce,
  optionaler Polling-Fallback, Erkennung neuer Symbole, Pause/Fortsetzen
- **Sichtbarkeitsmodi**: *Voll* (alles sichtbar), *Benutzerdefiniert* (Ihre Wahl pro Symbol),
  *Kompakt* (alles außer TrayIconGuard verstecken) — aus dem Tray-Menü oder per CLI
- **Steuerung pro Symbol**: anzeigen/verstecken/ausschließen mit Wildcard-Ausschlüssen
  (`onedrive.exe`, `*teams*`)
- **Ziehen zum Sortieren** der Tray-Symbole, pro PC gespeichert
- **Sicherer Explorer-Neustart** mit Cooldown und Bestätigung

### 🎨 **Modernes Fluent UI (2026)**

- Eigengezeichnetes Win32/GDI+-Interface: Nav-Rail, Karten, animierte Schalter,
  Segment-Controls, Overlay-Scrollbars, Per-Monitor-V2-DPI, Windows-11-Rundungen & dunkle Titelleiste
- **Hell / Dunkel / System** mit Quick-Switcher, persistiert, beim ersten Start automatisch erkannt
- **Akzentfarbe**: Windows folgen oder 8 Presets
- Responsives Layout (Nav-Rail kollabiert unter 860 px), vollständige Tastaturnavigation

### 📦 **Eingebetteter Installer**

- Erststart-Assistent: **Umfang** (*Nur für mich* / *Für alle Benutzer* — ein UAC-Prompt),
  Installationsordner, Autostart, Desktop- & Startmenü-Verknüpfungen — oder *nur einmal ausführen*
- Eintrag in „Apps & Features"; `--uninstall` entfernt alles (eleviert bei Bedarf automatisch)

### 🔄 **Git-basiertes Selbstupdate**

- Opt-in-Prüfung gegen `update/stable.json` in diesem Repo, **SHA-256-gepinnter** Download,
  Selbstersetzung & Relaunch; manueller Button + optionale tägliche Auto-Prüfung (nur Balloon)
- Publikationsvertrag für Release-Engineers: [Updater_SKILL.MD](Updater_SKILL.MD)

## ⚡ Schnellstart

```text
# 1. Neuestes Release herunterladen (exe oder zip)
https://github.com/paulmann/windows-show-all-tray-icons/releases/latest

# 2. Entsperren (Mark-of-the-Web) und starten — das ist die ganze Installation
Rechtsklick TrayIconGuard.exe → Eigenschaften → Zulassen → OK
TrayIconGuard.exe

# 3. Erststart: Der Assistent fragt Umfang / Ordner / Verknüpfungen ab
#    …oder „Nur einmal ausführen" für den portablen Modus wählen
```

Headless / Einzeiler:

```powershell
TrayIconGuard.exe --promote-all          # jetzt alles anzeigen, dann beenden
TrayIconGuard.exe --watch                # Headless-Guard (ohne GUI), z. B. per Task Scheduler
TrayIconGuard.exe --status --json        # maschinenlesbarer Zustand für Monitoring
TrayIconGuard.exe --check-update         # Git-Feed fragen, ob es eine neue Version gibt
```

## 📦 Installationsoptionen

| Modus | Wie | Admin? | Ergebnis |
|---|---|---|---|
| **Portabel** | exe überall starten | ❌ | nichts außer Einstellungen in `%APPDATA%` |
| **Pro Benutzer** (Standard) | Assistent → *Nur für mich* | ❌ | `%LOCALAPPDATA%\Programs\TrayIconGuard`, HKCU-Run-Autostart, Benutzer-Verknüpfungen, Apps-&-Features-Eintrag |
| **Für alle Benutzer** | Assistent → *Für alle Benutzer* | ✅ einmal (UAC) | `%ProgramFiles%\TrayIconGuard`, HKLM-Run-Autostart, gemeinsame Desktop-/Startmenü-Verknüpfungen, Maschinen-Uninstall-Eintrag |

Deinstallation: *Apps & Features → TrayIconGuard* oder `TrayIconGuard.exe --uninstall`.

![Setup-Assistent](shots/setup-wizard-light.png)

## 🖥️ GUI-Rundgang

| Seite | Funktion |
|---|---|
| **Dashboard** | Live-Zähler (registriert / in Taskleiste / versteckt / ausgeschlossen), Guard-Status, Ein-Klick-Aktionen, System- & Aktivitätskarten |
| **Tray-Symbole** | Suche, Filter, Schalter pro Symbol, Ausschlüsse, Ziehen zum Sortieren, Kontextmenü |
| **Guard** | Watcher-Feintuning (Debounce, Polling, Explorer-Neustart), Legacy-Reparaturen, Statistik, Ausschlüsse |
| **Design** | Theme (Hell/Dunkel/System), Akzent, Sprache, Animationen, kompakte Zeilen |
| **Backups** | Snapshot-Liste, erstellen/wiederherstellen/exportieren/löschen, Auto-Backup |
| **Aktivität** | Log-Viewer mit Levelfilter, Export, Ordner öffnen |
| **Info** | Version, Update-Panel, Lizenz- & Wiki-Buttons, Diagnose-Kopie, Installationsmodus-Chip |

Dunkler Modus, Info-Seite mit Update-Panel und Links:

![Info, dunkel](shots/dark-about.png)

## 🧰 CLI-Referenz

| Befehl | Wirkung |
|---|---|
| *(ohne Argumente)* | tray-residentes GUI starten |
| `--minimized` | versteckt im Infobereich starten |
| `--show` / `--toggle-guard` | IPC an laufende Instanz (aktivieren / Pause-Fortsetzen) |
| `--status [--json]` | Tray-Zustand ausgeben und beenden |
| `--promote-all` | alle versteckten Symbole anzeigen, dann beenden |
| `--restore-defaults` | `IsPromoted`-Werte löschen (Kontrolle an Windows zurückgeben) |
| `--restart-explorer` | sicherer Shell-Neustart, dann beenden |
| `--backup` / `--restore-latest` | JSON-Snapshot erstellen / wiederherstellen |
| `--watch` | Headless-Guard-Loop (ereignisgesteuert, ohne GUI) |
| `--install-autostart` / `--uninstall-autostart` | HKCU-Run-Eintrag verwalten |
| `--install-machine <dir> [--autostart] [--desktop] [--menu]` | Installation für alle Benutzer (muss erhöht laufen) |
| `--uninstall` | Verknüpfungen, Autostart und installierte Kopie entfernen (eleviert bei Machine-Installation automatisch) |
| `--mode full\|custom\|compact` | Sichtbarkeitsmodus setzen |
| `--check-update` / `--update-now` | Update-Prüfung über Git-Feed / nicht interaktives Update |
| `--version` / `--help` | Introspektion |

**Exit-Codes:** `0` ok · `1` ungültige Argumente · `2` OS nicht unterstützt · `3` Teilfehler.

## 🏗️ Funktionsweise

Primärer Speicher (Windows 10 1703+ / 11), pro Benutzer, ohne Admin:

```text
HKCU\Control Panel\NotifyIconSettings\{<icon-id>}
    IsPromoted            DWORD      1 = in Taskleiste, 0 = Overflow-Flyout
    ExecutablePath       REG_SZ     Eigentümerprozess
    IconResource         REG_SZ     Pfad,-id
    IconSnapshot         REG_BINARY zwischengespeichertes Bild
    LastNotificationAddedTime  REG_QWORD
```

Legacy-Doppelboden (optional): `EnableAutoTray=0` und Entfernen der `HideSCA*`-Richtlinien unter
`HKCU\…\Policies\Explorer`. Vollständige Analyse, Decay-Betrachtung und die
„Nicht anfassen"-Liste (`StuckRects3` u. a.): [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md).

## 🔄 Selbstupdate über Git

- Feed: [`update/stable.json`](update/stable.json) auf `main` (Schema, sha256-Pins, Hinweise)
- Client: WinHTTP-Download → BCrypt-SHA-256-Prüfung → Rename-Chain-Selbstersetzung → Relaunch
- Nie still: Bestätigungsdialog bei manuellen Updates; Auto-Prüfung opt-in, ≤ 1×/24 h, nur Balloon
- CI pinnt den Feed **aus den Bytes, die das Release tatsächlich ausliefert** (`scripts/make_feed.py`),
  daher können Feed und Assets nie auseinanderlaufen — siehe [Updater_SKILL.MD](Updater_SKILL.MD)

## 🌍 Sprachen

30 Locales mit per-String-Englisch-Fallback und automatischer Erkennung der OS-Sprache beim
ersten Start (live umschaltbar unter **Design → Sprache**):

| | | | |
|---|---|---|---|
| English (Standard) | Русский | 中文 (简体) | हिन्दी |
| Español | Deutsch | Français | Português |
| 日本語 | 한국어 | Italiano | العربية |
| Indonesian | اردو | Türkçe | Tiếng Việt |
| Polski | ไทย | Українська | Nederlands |
| Română | Ελληνικά | Čeština | Svenska |
| Magyar | Suomi | Dansk | עברית |
| فارسی | বাংলা | | |

Details & Übersetzungsleitfaden: [docs/I18N.md](docs/I18N.md).

## 🌗 Themes & Design

- **Hell / Dunkel / System** — persistiert, beim ersten Start auto-erkannt, Quick-Switcher in
  der Titelleiste; immersive dunkle Titelleiste & Rundungen unter Windows 11
- **Akzent**: Windows-Farbgebung folgen oder 8 integrierte Presets
- **Bewegung**: 140-ms-Schalteranimationen & Hover-Zustände (abschaltbar), Kompaktzeilen-Modus
- Per-Monitor-V2-DPI-korrekt überall

## 🏢 Deployment & Automatisierung

- **Task Scheduler / GPO-Logon-Skripte**: `TrayIconGuard.exe --watch` (headless) oder
  `--minimized` (GUI im Tray)
- **RMM / Monitoring**: `--status --json`, stabile Exit-Codes, 14-Tage-Rotationslogs in
  `%LOCALAPPDATA%\TrayIconGuard\logs`
- **Flottensicher**: Pro-Benutzer-Umfang ohne Admin; Machine-Umfang via `--install-machine`
  aus erhöhtem Kontext
- Store-fähig: MSIX-Manifest + Assets + Packscript in [`store/`](store/) — siehe
  [docs/STORE.md](docs/STORE.md)

## 🔍 Fehlerbehebung

| Symptom | Lösung |
|---|---|
| „Side-by-side-Konfiguration ist falsch" beim Start | exe in einen Ordner namens `*.exe` entpackt oder nicht entsperrt; siehe [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |
| SmartScreen-Warnung beim ersten Start | bei unsignierten Binärdateien erwartet: Eigenschaften → Zulassen; Signieranleitung in [docs/SMARTSCREEN.md](docs/SMARTSCREEN.md) |
| Symbole verstecken sich nach einem App-Update wieder | Guard pausiert? Tray-Menü → *Pause/Fortsetzen*; Aktivitäten-Seite zeigt Watcher-Ereignisse |
| Update abgelehnt: sha256 mismatch | Feed/Asset-Drift — neu publizieren gemäß [Updater_SKILL.MD](Updater_SKILL.MD) §3 |
| Nichts wird unter Win10 < 1703 angezeigt | Speicher nicht unterstützt; die App sagt das und bietet Legacy-Schalter an |

Mehr: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) · [Wiki-FAQ](https://github.com/paulmann/windows-show-all-tray-icons/wiki)

## 🛠️ Aus dem Quellcode bauen

```bash
# Cross-Compile unter Linux (statisch, gestrippt, exe ohne Abhängigkeiten)
sudo apt install g++-mingw-w64-x86-64 cmake
./scripts/build.sh          # Gates: 0 Warnings, Manifest-Check, Nur-OS-DLLs-Audit
./scripts/package.sh        # zip + SHA256SUMS

# Oder nativ mit MSVC unter Windows
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

CI fährt beides bei jedem Push (Ubuntu-Cross + Windows-MSVC) und publiziert Releases bei `v*`-Tags.
Details: [docs/BUILD.md](docs/BUILD.md).

## 🗂️ Repository-Übersicht

| Pfad | Inhalt |
|---|---|
| `src/core` | Engine: Registry-Speicher, Guard, Explorer, Backup, Autostart, Installer, Updater, CLI |
| `src/ui` | Fluent-Kit, Seiten, Assistent, Tray, Themes, i18n mit 30 Locales |
| `docs/` | Engineering- & User-Docs (HOW-IT-WORKS, CLI, DESIGN, I18N, STORE, SMARTSCREEN…) |
| `store/` | MSIX-Manifest + Store-Assets + `make_msix.ps1` |
| `scripts/` | Build-/Package-/Feed-Tooling (`build.sh`, `package.sh`, `make_feed.py`) |
| `installer/` | optionale ps1/bat/Inno-Helfer für Enterprise-Paketierung |
| `update/` | Live-Update-Feed (`stable.json`) |
| `.github/workflows/ci.yml` | Gates + Release + Feed-Pinning-Pipeline |

## 🤝 Mitwirken

Issues und PRs sind willkommen. Bitte bewahren Sie: null Runtime-Abhängigkeiten,
HKCU-only-Sicherheitsmodell, den Warning-freien Build-Gate (`-Wall -Wextra`) und den
Feed-Vertrag aus `Updater_SKILL.MD`. Siehe [`CONTRIBUTING.md`](CONTRIBUTING.md) und den [Verhaltenskodex](CODE_OF_CONDUCT.md); Sicherheitslücken bitte über [`SECURITY.md`](SECURITY.md) melden.

## 📄 Lizenz

[PolyForm Noncommercial License 1.0.0](LICENSE) — frei für nicht-kommerzielle Nutzung;
kommerzielle Lizenzierung: Kontakt zum Autor.

## 👨‍💻 Autor & Support

**Mikhail Deynekin** · <icons@Deynekin.com> · [Deynekin.com](https://Deynekin.com) ·
[GitHub](https://github.com/paulmann) ·
[Wissensbasis (Wiki)](https://github.com/paulmann/windows-show-all-tray-icons/wiki) ·
[Lizenz](https://github.com/paulmann/windows-show-all-tray-icons/blob/main/LICENSE)

## 🎯 Roadmap

- [ ] Code-Signing-Pipeline (SmartScreen-Reputation)
- [ ] RTL-Layout-Spiegelung für Arabisch/Hebräisch/Persisch/Urdu
- [ ] MSI-Paketierung für SCCM/Intune-Win32-Apps
- [ ] Nativer ARM64-Build

---

<sub>Mit 🧡 für aufgeräumte Taskleisten gemacht. TrayIconGuard ist nicht mit Microsoft verbunden.</sub>
