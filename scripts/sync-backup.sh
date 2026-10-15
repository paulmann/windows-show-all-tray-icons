#!/usr/bin/env bash
# Sync work -> backup and commit to git. Usage: sync-backup.sh "milestone message"
set -e
MSG="${1:-checkpoint $(date -u +%Y%m%d-%H%M%S)}"
mkdir -p "$ARENA_WORKSPACE"/backup/work
rsync -a --delete \
  --exclude 'build/' --exclude '.git/objects/pack/tmp_*' \
  "$ARENA_WORKSPACE"/work/ "$ARENA_WORKSPACE"/backup/work/
cp -f "$ARENA_WORKSPACE"/work/REWORK-STATE.md "$ARENA_WORKSPACE"/REWORK-STATE.md 2>/dev/null || true
cd "$ARENA_WORKSPACE"/work
git add -A
git -c user.email=qwen@arena.local -c user.name="Qwen Orchestrator" commit -q -m "$MSG" || echo "nothing to commit"
echo "[sync] OK: $MSG"
