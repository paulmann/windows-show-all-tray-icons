# A8-qa — task brief
## Scope
QA. Compile -Wall -Wextra zero warnings; cppcheck --enable=warning,style (no errors); wine smoke: --help --version --status --status --json --promote-all(graceful fail under wine) --ui-test + xvfb screenshot review (layout, both themes, all 7 pages via --ui-test page arg); audit checklist: single instance, settings round-trip, no StuckRects3 refs, HKCU-only, atomic writes, thread safety (PostMessage), glyph fallback, DPI math, size <1.5MB, ZIP contents, SHA256, README instructions actually work; report into agents/A8-qa.md.
## Rules
Read "/tmp/arena/tenants/2ac01412-00e0-452b-8d75-2c08c7a303a2/sessions/37021a58-8685-4790-968b-f449bd91bd19/workspace"/work/REWORK-STATE.md (esp. §3 mechanics, §10 pitfalls) before any change.
Write only inside your scope paths. Update Status below. After milestone: bash scripts/sync-backup.sh.
## Status
- [x] DONE (2026-10-16)
See REWORK-STATE.md §8/§11 for evidence.
## Log
