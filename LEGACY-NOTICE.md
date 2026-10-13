# Legacy files notice (pre-7.0 artifacts retained verbatim)

The four files below predate the v7 "Phoenix" rewrite. They are **deprecated** but are
kept in the repository root, byte-identical to the upstream `main` branch, because:

1. Public `raw.githubusercontent.com` URLs point at them and external scripts/docs may
   reference them (removal would turn `200` into `404`).
2. An independent audit (2026-10-13) explicitly flagged their removal as an
   owner-level decision; until the owner opts into deletion, the non-destructive
   option applies: old files stay, new code lives alongside them.

| Legacy file | Status | v7 replacement |
|---|---|---|
| `Enable-AllTrayIcons.bat` | Deprecated. Uses only the legacy `EnableAutoTray` switch; lacks the modern `IsPromoted` mechanism, watcher and correct policy paths. | `bat/Show-AllTrayIcons.bat` (standalone, menu + watch loop) |
| `Enable-AllTrayIcons.ps1` | Deprecated. Targets Windows PowerShell 5.1; monolithic (~300 KB); contains claims (Group Policy "AllUsers") that do not reflect real Windows behavior. | `powershell/Enable-AllTrayIcons.ps1` + `ShowAllTrayIcons` module (pwsh 7.6+) |
| `enable-all-tray-icons.reg` | Deprecated. Writes `HideSCA*` and `NotifyIconSettings` to **invalid** paths; includes resolution-specific `StuckRects3` data that can corrupt taskbar layout. See `docs/HOW-IT-WORKS.md`. | `Enable-AllTrayIcons` (module) — correct paths only |
| `disable-auto-hide.reg` | Deprecated. Inverse of the above with the same path defects. | `Disable-AllTrayIcons` (module) |

**Do not extend or fix these files.** They are frozen. New development happens in
`powershell/`, `bat/`, and `app/` only.

## Removal procedure (if the owner later opts in)

1. Confirm no deployment depends on the raw URLs (search internal scripts, Intune/SCCM
   packages, docs sites for `raw.githubusercontent.com/.../Enable-AllTrayIcons.*` and
   `.../*.reg`).
2. Announce one minor release in advance (README + CHANGELOG "breaking" note).
3. Delete in a dedicated commit referencing this notice, and keep GitHub releases for
   v6.x tags so the old content remains retrievable.
