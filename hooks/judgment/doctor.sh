#!/usr/bin/env bash
# doctor.sh — judgment toolkit install/config diagnostic. Not a hook; run it
# by hand from a project root when a gate seems silently inert:
#
#   bash path/to/hooks/judgment/doctor.sh
#
# Checks the three failure modes behind most "hook does nothing" reports:
#   1. .claude/judgment.json missing / invalid / gate disabled
#   2. hook scripts missing or not executable
#   3. settings.json hook wiring absent
# Then runs the hook regression matrix (test.sh) if present.
# Exit 0 = healthy, 1 = at least one FAIL.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
fails=0
ok()   { printf 'PASS  %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n      fix: %s\n' "$1" "$2"; fails=$((fails+1)); }
warn() { printf 'WARN  %s\n' "$1"; }

echo "judgment doctor — $(pwd)"
echo "---------------------------------------------"

# 1. config
if [ ! -f .claude/judgment.json ]; then
  bad ".claude/judgment.json missing — every gate is inert" \
      "cp \"$HERE/judgment.json.example\" .claude/judgment.json and enable gates"
else
  if python3 -c 'import json,sys; json.load(open(".claude/judgment.json"))' 2>/dev/null; then
    ok ".claude/judgment.json parses"
    python3 - <<'PY'
import json
cfg = json.load(open(".claude/judgment.json"))
gates = ["claim_evidence", "spec_citation", "scope_creep", "todo_debt"]
on = [g for g in gates if cfg.get(g, {}).get("enabled")]
off = [g for g in gates if g in cfg and not cfg.get(g, {}).get("enabled")]
print(f"      gates enabled: {', '.join(on) or '(none!)'}")
if off:
    print(f"      gates present but disabled: {', '.join(off)}")
PY
  else
    bad ".claude/judgment.json is not valid JSON — every gate is inert" \
        "fix the JSON (python3 -m json.tool .claude/judgment.json shows the error)"
  fi
fi

# 2. hook scripts present + executable
for h in claim-evidence.sh spec-citation.sh scope-creep.sh todo-debt.sh; do
  if [ ! -f "$HERE/$h" ]; then
    warn "$h not found beside doctor.sh (ok if you installed a subset)"
  elif [ ! -x "$HERE/$h" ]; then
    bad "$h is not executable — Claude Code will fail to run it" "chmod +x \"$HERE/$h\""
  else
    ok "$h present and executable"
  fi
done

# 3. settings wiring
wired=0
for s in .claude/settings.json .claude/settings.local.json "$HOME/.claude/settings.json"; do
  if [ -f "$s" ] && grep -q 'judgment' "$s" 2>/dev/null; then
    ok "hook wiring found in $s"; wired=1; break
  fi
done
if [ "$wired" = 0 ]; then
  bad "no settings.json references the judgment hooks — they never fire" \
      "add a PreToolUse Bash hook entry per the header of each hook script"
fi

# 4. regression matrix
if [ -f "$HERE/test.sh" ]; then
  if bash "$HERE/test.sh" >/dev/null 2>&1; then
    ok "hook regression matrix (test.sh) green"
  else
    bad "hook regression matrix (test.sh) FAILED" "run bash \"$HERE/test.sh\" to see which case"
  fi
else
  warn "test.sh not installed — cannot self-verify hook behavior"
fi

echo "---------------------------------------------"
if [ "$fails" -gt 0 ]; then
  echo "doctor: $fails problem(s) found."
  exit 1
fi
echo "doctor: healthy."
exit 0
