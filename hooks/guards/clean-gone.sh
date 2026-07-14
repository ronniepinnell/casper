#!/usr/bin/env bash
# clean-gone.sh — SessionStart hook. Reports (and optionally deletes) local
# branches whose upstream is gone — squash-merged PR branches that pile up
# (the fleet audit found ~30 in one repo). Report-only by default; deletion
# is opt-in AND restricted to branches that are fully merged or squash-gone.
#
# Inert unless .claude/judgment.json exists with
#   "guards": {"clean_gone": {"enabled": true, "auto_delete": false}}
#
# Wiring (settings.json):
#   {"hooks": {"SessionStart": [{"matcher": "",
#     "hooks": [{"type": "command", "command": "path/to/clean-gone.sh"}]}]}}
set -uo pipefail

CONFIG=".claude/judgment.json"
[ -f "$CONFIG" ] || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

enabled=$(python3 -c "
import json,sys
g=json.load(open('$CONFIG')).get('guards',{}).get('clean_gone',{})
print('1' if g.get('enabled') else '0', '1' if g.get('auto_delete') else '0')
" 2>/dev/null) || exit 0
set -- $enabled
[ "${1:-0}" = "1" ] || exit 0
AUTO="${2:-0}"

git fetch --prune --quiet 2>/dev/null || true
gone=$(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads \
       | awk '$2 == "[gone]" {print $1}')
[ -n "$gone" ] || exit 0

current=$(git branch --show-current)
count=$(printf "%s\n" "$gone" | wc -l | tr -d ' ')

if [ "$AUTO" = "1" ]; then
  deleted=""
  for b in $gone; do
    [ "$b" = "$current" ] && continue
    # -d only (never -D): refuses if the branch isn't merged/squash-detectable
    if git branch -d "$b" >/dev/null 2>&1; then
      deleted="$deleted $b"
    fi
  done
  echo "clean-gone: deleted$deleted (upstream gone, fully merged)." >&2
  remaining=$(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads \
              | awk '$2 == "[gone]" {print $1}')
  [ -n "$remaining" ] && echo "clean-gone: NOT deleted (unmerged or current — review by hand): $remaining" >&2
else
  echo "clean-gone: $count local branch(es) whose upstream is gone:" >&2
  printf "  %s\n" $gone >&2
  echo "clean-gone: run 'git branch -d <name>' per branch, or set guards.clean_gone.auto_delete=true." >&2
fi
exit 0
