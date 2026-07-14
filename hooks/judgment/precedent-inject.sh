#!/usr/bin/env bash
# precedent-inject.sh — SessionStart hook.
# If the project keeps a verdicts ledger (.claude/verdicts.log), surface the
# last N rulings as session context so prior judgment is in scope from turn
# one. Output on stdout is injected as context by SessionStart hooks.
#
# Repo-agnostic. Enabled only if .claude/judgment.json exists in the project
# and has precedent_inject.enabled = true. Zero-LLM, pure bash+python3.
#
# Config (judgment.json):
#   "precedent_inject": {"enabled": true, "max_lines": 10}
#
# Wiring (settings.json):
#   {"hooks": {"SessionStart": [{"hooks": [{"type": "command",
#     "command": "path/to/precedent-inject.sh"}]}]}}
set -uo pipefail

CONFIG=".claude/judgment.json"
[ -f "$CONFIG" ] || exit 0
[ -f ".claude/verdicts.log" ] || exit 0

python3 - "$CONFIG" <<'PY'
import json, sys

cfg = json.load(open(sys.argv[1]))
gate = cfg.get("precedent_inject", {})
if not gate.get("enabled", False):
    sys.exit(0)

max_lines = int(gate.get("max_lines", 10))
MAX_LINE = 110      # truncate long verdict lines
MAX_TOTAL = 1200    # hard cap on injected context

try:
    lines = [l.rstrip() for l in open(".claude/verdicts.log", errors="replace")
             if l.strip()][-max_lines:]
except Exception:
    sys.exit(0)  # never let the injector break session start
if not lines:
    sys.exit(0)

out = ["Prior rulings (see /precedent):"]
total = len(out[0]) + 1
for l in lines:
    if len(l) > MAX_LINE:
        l = l[:MAX_LINE - 1] + "…"
    if total + len(l) + 1 > MAX_TOTAL:
        break
    out.append(l)
    total += len(l) + 1

print("\n".join(out))
sys.exit(0)
PY
exit 0
