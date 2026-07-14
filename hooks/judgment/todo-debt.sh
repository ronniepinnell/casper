#!/usr/bin/env bash
# todo-debt.sh — PreToolUse hook (matcher: Bash).
# Blocks `git commit` messages that claim completion (fix/done/works/…) while
# the staged diff ADDS deferred-work markers (TODO/FIXME/HACK/XXX). A done-
# claim that smuggles in new debt is not done.
#
# Repo-agnostic. Enabled only if .claude/judgment.json exists in the project
# and has todo_debt.enabled = true. Zero-LLM, pure bash+python3.
#
# Config (judgment.json):
#   "todo_debt": {"enabled": true, "markers": ["TODO","FIXME","HACK","XXX"]}
#
# Wiring (settings.json):
#   {"hooks": {"PreToolUse": [{"matcher": "Bash",
#     "hooks": [{"type": "command", "command": "path/to/todo-debt.sh"}]}]}}
set -uo pipefail

CONFIG=".claude/judgment.json"
[ -f "$CONFIG" ] || exit 0

export JUDGMENT_INPUT="$(cat)"

python3 - "$CONFIG" <<'PY'
import json, os, re, subprocess, sys

cfg = json.load(open(sys.argv[1]))
gate = cfg.get("todo_debt", {})
if not gate.get("enabled", False):
    sys.exit(0)

data = json.loads(os.environ.get("JUDGMENT_INPUT", "{}"))
cmd = (data.get("tool_input") or {}).get("command", "")
if not re.search(r"\bgit\b.*\bcommit\b", cmd):
    sys.exit(0)

msgs = re.findall(r"-m\s+(?:\"([^\"]*)\"|'([^']*)')", cmd, re.S)
message = " ".join(a or b for a, b in msgs)
if not message:
    sys.exit(0)  # editor-based commit; nothing to scan

claim_words = gate.get("claim_words",
    ["fixed", "fixes", "fix", "done", "works", "working", "complete",
     "completed", "resolved", "resolves"])
if not re.search(r"\b(" + "|".join(map(re.escape, claim_words)) + r")\b",
                 message, re.I):
    sys.exit(0)

markers = gate.get("markers", ["TODO", "FIXME", "HACK", "XXX"])
marker_re = re.compile(r"\b(" + "|".join(map(re.escape, markers)) + r")\b")
try:
    diff = subprocess.run(["git", "diff", "--cached", "-U0"],
                          capture_output=True, text=True, timeout=10).stdout
except Exception:
    sys.exit(0)  # never let the gate itself break commits

added = [l[1:].strip() for l in diff.splitlines()
         if l.startswith("+") and not l.startswith("+++") and marker_re.search(l)]
if not added:
    sys.exit(0)

print("todo-debt gate: this commit claims completion but ADDS deferred-work "
      "markers:\n  " + "\n  ".join(added[:5]) +
      ("\n  …" if len(added) > 5 else "") + "\n"
      "Either finish the work, file the TODOs as tracked issues and remove "
      "them, or drop the completion claim from the message.", file=sys.stderr)
sys.exit(2)
PY
