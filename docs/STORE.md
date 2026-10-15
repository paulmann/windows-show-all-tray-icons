# Microsoft Store publication guide — TrayIconGuard

Everything needed for a Store listing is in `store/`:

| File | Purpose |
|---|---|
| `AppxManifest.xml` | MSIX manifest (Desktop Bridge, `runFullTrust`), 16 resource languages, startup-task extension (disabled by default) |
| `assets/*.png` | All required Store/logo tiles: Square44x44 (5 scales + 10 target sizes), Square150x150, Small/Large/Wide tiles, StoreLogo, SplashScreen |
| `make_msix.ps1` | Packs `dist/TrayIconGuard-<ver>.msix` with SDK `makeappx.exe` (the only tool needed) |

## One-time account steps
1. Partner Center: register a developer account (one-time fee), verify identity.
2. **Reserve the app name** “TrayIconGuard” (Store → New app).
3. Copy the reserved **Package name** and your **Publisher CN** into
   `store/AppxManifest.xml` (`Identity/@Name`, `Identity/@Publisher`).

## Per-release steps
1. `scripts/build.sh` + `scripts/package.sh` (produces the signed-candidate exe).
2. Bump `Identity/@Version` in `AppxManifest.xml` to `<ver>.0`.
3. `store/make_msix.ps1 -Version <ver>` → `dist/TrayIconGuard-<ver>.msix`
   (unsigned is fine: Partner Center signs Store packages).
4. Partner Center → submission:
   - Upload the MSIX package.
   - Listing: category **Utilities**; description = README “Features” section (EN + RU
     listings; add others from `Resources` as desired).
   - Age rating: no restrictions required (no content).
   - **Privacy policy URL**: publish `docs/PRIVACY.md` (GitHub Pages/gist URL) — mandatory
     field even though the app collects nothing.
   - Notes for certification: “Win32 (Desktop Bridge) fullTrust app; no admin required;
     writes only HKCU and per-user AppData; autostart is opt-in via in-app wizard and the
     disabled-by-default startupTask; no telemetry.”
5. Submit. Certification typically 1–3 business days.

## Store-specific behavior notes
- Packaged fullTrust apps keep real HKCU access (the guard works unchanged); file writes to
  `%APPDATA%` are redirected to the package-private AppData — TrayIconGuard creates its
  folders on first run, so settings/logs/backups live inside the package private store
  (visible to the app itself and to `--status`).
- The in-app embedded installer wizard detects the packaged environment implicitly: users
  of the Store build simply never see it if you preset `install.mode=installed` via a
  future store-config; by default the wizard still offers portable mode, which is the
  correct Store behavior (Store apps must not copy themselves outside the package).
  Recommended Store default: set `settings.install.mode = "installed"` on first run when
  `PACKAGE_FAMILY_NAME` env is present (tracked as a follow-up; current build shows the
  wizard with “Just run once” as the Store-appropriate choice).
- Autostart: prefer the `windows.startupTask` extension (user-toggleable in
  Settings → Apps → Startup) over the HKCU Run key for the packaged build.

## Pricing & license
Free, no ads, no IAP. The project license is **PolyForm Noncommercial 1.0.0**; distribute
the Store listing as free/noncommercial and paste the license text (see `LICENSE`) as the
Store EULA/terms link.
