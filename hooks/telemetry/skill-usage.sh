#!/usr/bin/env bash
# skill-usage.sh — PostToolUse hook (matcher: Skill). Zero-LLM skill telemetry.
#
# Appends one JSONL row per Skill invocation: {"ts": ..., "skill": ..., "args_length": ...}.
# PRIVACY: never logs argument CONTENTS — only their length.
#
# Config-gated like the judgment guards. Inert unless .claude/judgment.json exists
# and has telemetry.enabled = true:
#   "telemetry": {"enabled": false, "log_file": ".claude/.judgment-state/skill-usage.jsonl"}
#
# Wiring (settings.json) — primary, per-invocation:
#   {"hooks": {"PostToolUse": [{"matcher": "Skill",
#     "hooks": [{"type": "command", "command": "path/to/skill-usage.sh"}]}]}}
#
# SessionEnd variant: if your harness supports a SessionEnd hook event, you can
# additionally wire this script there — it receives no Skill payload, so it appends
# a {"ts": ..., "skill": "__session_end__", "args_length": 0} marker row, useful for
# sessionizing the log. Per-invocation PostToolUse wiring is the primary mode.
#
# Query one-liner — top skills this month:
#   jq -r .skill .claude/.judgment-state/skill-usage.jsonl | sort | uniq -c | sort -rn | head
set -uo pipefail

CONFIG=".claude/judgment.json"
[ -f "$CONFIG" ] || exit 0

export TELEMETRY_INPUT="$(cat)"
export TELEMETRY_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

python3 - "$CONFIG" <<'PY'
import json, os, sys

cfg = json.load(open(sys.argv[1]))
tel = cfg.get("telemetry", {})
if not tel.get("enabled", False):
    sys.exit(0)

log_file = tel.get("log_file", ".claude/.judgment-state/skill-usage.jsonl")

try:
    data = json.loads(os.environ.get("TELEMETRY_INPUT", "{}"))
except Exception:
    data = {}
ti = data.get("tool_input") or {}
skill = ti.get("skill") or "__session_end__"
args = ti.get("args") or ""
row = {
    "ts": os.environ.get("TELEMETRY_TS", ""),
    "skill": skill,
    "args_length": len(str(args)),  # length only — never contents
}

os.makedirs(os.path.dirname(log_file) or ".", exist_ok=True)
with open(log_file, "a") as f:
    f.write(json.dumps(row) + "\n")
PY
exit 0
