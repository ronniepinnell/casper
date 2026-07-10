#!/usr/bin/env bash
# casper doctor — install/config diagnostic.
#
#   ./scripts/doctor.sh            # diagnose ./.claude in the current project
#   ./scripts/doctor.sh --global   # diagnose ~/.claude
#
# Answers, with a clear ✓/✗ per line:
#   - is python3 available (the hooks need it)?
#   - is .claude/judgment.json present AND valid JSON?
#   - which gates are enabled?
#   - are the hooks wired into .claude/settings.json?
#   - is the verdict ledger writable?
# Exit 0 if nothing is broken (warnings allowed), 1 if a ✗ was printed.
set -uo pipefail

ROOT="$(pwd)/.claude"
[ "${1:-}" = "--global" ] && ROOT="$HOME/.claude"

FAIL=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }

echo "👻 casper doctor — inspecting $ROOT"
echo

# --- prerequisites ---------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
  ok "python3 available ($(python3 --version 2>&1))"
else
  bad "python3 NOT found — the zero-LLM hooks require it"
fi

if [ -d "$ROOT" ]; then
  ok ".claude directory exists"
else
  bad ".claude directory missing at $ROOT — run install.sh first"
fi

# --- judgment.json ---------------------------------------------------------
CFG="$ROOT/judgment.json"
if [ -f "$CFG" ]; then
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$CFG" 2>/dev/null; then
    ok "judgment.json present and valid JSON"
    # which gates are enabled?
    ENABLED="$(python3 - "$CFG" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
on = []
for key in ("claim_evidence", "spec_citation", "scope_creep", "telemetry"):
    if isinstance(cfg.get(key), dict) and cfg[key].get("enabled"):
        on.append(key)
guards = cfg.get("guards", {})
if isinstance(guards, dict):
    for gk, gv in guards.items():
        if isinstance(gv, dict) and gv.get("enabled"):
            on.append("guards." + gk)
print(",".join(on))
PY
)"
    if [ -n "$ENABLED" ]; then
      ok "gates enabled: $ENABLED"
    else
      warn "no gates enabled — hooks are inert (flip 'enabled': true per gate)"
    fi
  else
    bad "judgment.json present but is INVALID JSON — hooks will no-op"
  fi
else
  warn "no judgment.json — hooks are default-OFF and inert (copy judgment.json.example)"
fi

# --- settings.json wiring --------------------------------------------------
SETTINGS="$ROOT/settings.json"
if [ -f "$SETTINGS" ]; then
  if grep -q 'claim-evidence.sh\|spec-citation.sh\|scope-creep.sh' "$SETTINGS" 2>/dev/null; then
    ok "hooks are wired into settings.json"
  else
    warn "settings.json exists but references no casper hook (gates won't fire on commit)"
  fi
else
  warn "no settings.json — nothing wires the hooks into Claude Code yet"
fi

# --- ledger ----------------------------------------------------------------
LEDGER="$ROOT/verdicts.log"
if [ -f "$LEDGER" ]; then
  if [ -w "$LEDGER" ]; then
    ok "verdict ledger present and writable ($(wc -l < "$LEDGER" | tr -d ' ') lines)"
  else
    bad "verdict ledger exists but is NOT writable: $LEDGER"
  fi
elif [ -d "$ROOT" ] && [ -w "$ROOT" ]; then
  ok "verdict ledger not created yet, but $ROOT is writable (first /verdict will create it)"
else
  warn "cannot confirm ledger writability (missing/unwritable $ROOT)"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "Diagnosis: healthy. 👻"
else
  echo "Diagnosis: problems found (see ✗ above)."
fi
exit "$FAIL"
