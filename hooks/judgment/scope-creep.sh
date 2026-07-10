#!/usr/bin/env bash
# scope-creep.sh — PostToolUse hook (matcher: Edit|Write).
# Counts distinct files modified this session. Past the threshold it fires
# ONCE: stop, compare against the stated task, justify or split. The
# mechanical version of "you said one fix, you're 23 files deep".
#
# Repo-agnostic. Enabled only if .claude/judgment.json exists and has
# scope_creep.enabled = true. Zero-LLM.
#
# Wiring (settings.json):
#   {"hooks": {"PostToolUse": [{"matcher": "Edit|Write",
#     "hooks": [{"type": "command", "command": "path/to/scope-creep.sh"}]}]}}
set -uo pipefail

CONFIG=".claude/judgment.json"
[ -f "$CONFIG" ] || exit 0

export JUDGMENT_INPUT="$(cat)"

python3 - "$CONFIG" <<'PY'
import json, os, sys, time

cfg = json.load(open(sys.argv[1]))
gate = cfg.get("scope_creep", {})
if not gate.get("enabled", False):
    sys.exit(0)

data = json.loads(os.environ.get("JUDGMENT_INPUT", "{}"))
path = (data.get("tool_input") or {}).get("file_path", "")
if not path:
    sys.exit(0)

session = data.get("session_id", "default")
state_dir = ".claude/.judgment-state"
os.makedirs(state_dir, exist_ok=True)
touch_log = os.path.join(state_dir, f"scope-{session}.txt")
fired = os.path.join(state_dir, f"scope-{session}.fired")

# Reset stale state (fresh day, new task): TTL on the log itself.
ttl = gate.get("reset_seconds", 28800)  # 8h default
if os.path.exists(touch_log) and time.time() - os.path.getmtime(touch_log) > ttl:
    os.remove(touch_log)
    if os.path.exists(fired):
        os.remove(fired)

files = set()
if os.path.exists(touch_log):
    files = set(open(touch_log).read().splitlines())
files.add(os.path.relpath(path, os.getcwd()))
with open(touch_log, "w") as f:
    f.write("\n".join(sorted(files)))

threshold = gate.get("max_files", 15)
if len(files) <= threshold or os.path.exists(fired):
    sys.exit(0)

open(fired, "w").close()  # fire once, don't nag
print(f"scope-creep tripwire: {len(files)} distinct files modified this "
      f"session (threshold {threshold}).\nStop and answer in your reply:\n"
      f"  1. What was the stated task?\n"
      f"  2. Do all {len(files)} files serve it, or has the task grown?\n"
      f"  3. If grown: split — ship the original scope, file the rest.\n"
      f"To proceed knowingly, raise scope_creep.max_files in "
      f".claude/judgment.json for this task (that edit IS the audit trail).",
      file=sys.stderr)
sys.exit(2)
PY
