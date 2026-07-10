#!/usr/bin/env bash
# context-watchdog.sh — PostToolUse hook (matcher: .*).
# Warn-only context budget watchdog: reads CLAUDE_CONTEXT_TOKENS /
# CLAUDE_CONTEXT_MAX (set by Claude Code when available) and nags at rising
# utilization thresholds — at the top tier it tells the session to write a
# handoff NOW instead of degrading silently. Never blocks (exit 0 always).
# Promoted from the factory watchdog; thresholds now config-driven.
#
# Repo-agnostic. Enabled only if .claude/judgment.json exists and has
# guards.context_watchdog.enabled = true. Zero-LLM.
#
# Wiring (settings.json):
#   {"hooks": {"PostToolUse": [{"matcher": ".*",
#     "hooks": [{"type": "command", "command": "path/to/context-watchdog.sh"}]}]}}
set -uo pipefail

CONFIG=".claude/judgment.json"
[ -f "$CONFIG" ] || exit 0

python3 - "$CONFIG" <<'PY'
import json, os, sys

cfg = json.load(open(sys.argv[1]))
gate = cfg.get("guards", {}).get("context_watchdog", {})
if not gate.get("enabled", False):
    sys.exit(0)

try:
    tokens = int(os.environ.get("CLAUDE_CONTEXT_TOKENS", "0"))
    max_t = int(os.environ.get("CLAUDE_CONTEXT_MAX", "200000"))
except ValueError:
    sys.exit(0)
if tokens <= 0 or max_t <= 0:
    sys.exit(0)

pct = tokens * 100 // max_t
info, warn, crit = sorted(gate.get("warn_pcts", [50, 70, 85]))[:3]

if pct >= crit:
    print(f"CONTEXT {pct}% — WRITE A HANDOFF NOW. Run /handoff, then /clear "
          f"and resume from the summary.", file=sys.stderr)
elif pct >= warn:
    print(f"Context {pct}% full. Plan a /handoff in the next 5-10 turns.",
          file=sys.stderr)
elif pct >= info:
    print(f"Context {pct}% full.", file=sys.stderr)
sys.exit(0)
PY
