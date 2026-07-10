#!/usr/bin/env bash
# spec-citation.sh — PreToolUse hook (matcher: Edit|Write).
# On the FIRST edit to a protected path (schema, migrations, contracts —
# whatever globs the project declares), halts until the session has cited the
# governing spec by touching .claude/.spec-cited (done after actually quoting
# the spec line in conversation). Citation is valid for the config'd TTL.
#
# Repo-agnostic. Enabled only if .claude/judgment.json exists and has
# spec_citation.enabled = true. Zero-LLM.
#
# Wiring (settings.json):
#   {"hooks": {"PreToolUse": [{"matcher": "Edit|Write",
#     "hooks": [{"type": "command", "command": "path/to/spec-citation.sh"}]}]}}
set -uo pipefail

CONFIG=".claude/judgment.json"
[ -f "$CONFIG" ] || exit 0

export JUDGMENT_INPUT="$(cat)"

python3 - "$CONFIG" <<'PY'
import fnmatch, json, os, sys, time

cfg = json.load(open(sys.argv[1]))
gate = cfg.get("spec_citation", {})
if not gate.get("enabled", False):
    sys.exit(0)

data = json.loads(os.environ.get("JUDGMENT_INPUT", "{}"))
path = (data.get("tool_input") or {}).get("file_path", "")
if not path:
    sys.exit(0)
rel = os.path.relpath(path, os.getcwd())

globs = gate.get("protected_globs", [])
def hit(p):
    return any(fnmatch.fnmatch(p, g) or fnmatch.fnmatch("/" + p, g)
               for g in globs)
if not hit(rel):
    sys.exit(0)

marker = ".claude/.spec-cited"
ttl = gate.get("ttl_seconds", 14400)  # 4h default
if os.path.exists(marker) and time.time() - os.path.getmtime(marker) < ttl:
    sys.exit(0)

specs = gate.get("specs_hint", "the governing spec for this area")
print(f"spec-citation gate: '{rel}' is a protected path (one-way-door "
      f"territory).\nBefore editing, cite your authority:\n"
      f"  1. Open {specs} and QUOTE the specific line(s) that govern this "
      f"change in your reply.\n"
      f"  2. If the spec says nothing about it, say so explicitly — that is "
      f"a spec gap to flag, and /door applies.\n"
      f"  3. Then run: touch {marker}\n"
      f"Citation stays valid for {ttl // 3600}h.", file=sys.stderr)
sys.exit(2)
PY
