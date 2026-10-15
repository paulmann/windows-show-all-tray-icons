# A1-core — task brief
## Scope
CORE ENGINE. Files src/core/* src/util/*. Registry helpers, TrayIconStore(NotifyIconSettings/IsPromoted), Guard watcher thread (RegNotifyChangeKeyValue+debounce 400ms+poll fallback+auto explorer restart w/ cooldown), legacy fixes (EnableAutoTray=0, HideSCA* removal under Policies\Explorer, TrayNotify cache reset), explorer restart (kill->wait 8s->start), backup JSON v8, autostart HKCU Run, update check (WinHTTP GitHub), CLI+IPC(COPYDATA), settings.json+log. Win32 threads only (mingw win32 model). UI-thread safety: worker->PostMessage only.
## Rules
Read "/tmp/arena/tenants/2ac01412-00e0-452b-8d75-2c08c7a303a2/sessions/37021a58-8685-4790-968b-f449bd91bd19/workspace"/work/REWORK-STATE.md (esp. §3 mechanics, §10 pitfalls) before any change.
Write only inside your scope paths. Update Status below. After milestone: bash scripts/sync-backup.sh.
## Status
- [x] DONE (2026-10-16)
See REWORK-STATE.md §8/§11 for evidence.
## Log
