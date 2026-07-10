#!/usr/bin/env bash
# budget-log.sh — PostToolUse hook (matcher: .*).
# Per-tool token-cost ledger: appends one JSONL row per tool call
# ({ts, tool, tokens, max}) to a daily file so token spend per tool is
# queryable after the run. Warn/log only — never blocks (exit 0 always).
# Promoted from the factory budget-guard-post; log dir now repo-local and
# config-driven instead of $HOME.
#
# Repo-agnostic. Enabled only if .claude/judgment.json exists and has
# guards.budget.enabled = true. Zero-LLM.
#
# Wiring (settings.json):
#   {"hooks": {"PostToolUse": [{"matcher": ".*",
#     "hooks": [{"type": "command", "command": "path/to/budget-log.sh"}]}]}}
set -uo pipefail

CONFIG=".claude/judgment.json"
[ -f "$CONFIG" ] || exit 0

export JUDGMENT_INPUT="$(cat 2>/dev/null || true)"

python3 - "$CONFIG" <<'PY'
import datetime, json, os, sys

cfg = json.load(open(sys.argv[1]))
gate = cfg.get("guards", {}).get("budget", {})
if not gate.get("enabled", False):
    sys.exit(0)

try:
    data = json.loads(os.environ.get("JUDGMENT_INPUT") or "{}")
except json.JSONDecodeError:
    data = {}

tool = data.get("tool_name") or os.environ.get("CLAUDE_TOOL_NAME", "unknown")
try:
    tokens = int(os.environ.get("CLAUDE_CONTEXT_TOKENS", "0"))
    max_t = int(os.environ.get("CLAUDE_CONTEXT_MAX", "0"))
except ValueError:
    tokens = max_t = 0

log_dir = gate.get("log_dir", ".claude/.judgment-state/cost-log")
os.makedirs(log_dir, exist_ok=True)
now = datetime.datetime.now(datetime.timezone.utc)
row = {"ts": now.strftime("%Y-%m-%dT%H:%M:%SZ"), "tool": tool,
       "tokens": tokens, "max": max_t}
with open(os.path.join(log_dir, f"tool-cost-{now:%Y-%m-%d}.jsonl"), "a") as f:
    f.write(json.dumps(row) + "\n")
sys.exit(0)
PY
