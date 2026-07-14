#!/usr/bin/env bash
# commit-style.sh — PreToolUse hook (matcher: Bash). One repo, one commit
# dialect. The fleet audit found the same author using bracket tags
# ([FEAT] …) in one repo and Conventional Commits (feat: …) everywhere else;
# this gate pins each repo's declared style mechanically.
#
# Inert unless .claude/judgment.json exists with
#   "commit_style": {"enabled": true, "style": "conventional"}   # or "bracket"
# Optional: "extra_pattern" — a custom regex that overrides both presets.
#
# Wiring (settings.json):
#   {"hooks": {"PreToolUse": [{"matcher": "Bash",
#     "hooks": [{"type": "command", "command": "path/to/commit-style.sh"}]}]}}
set -uo pipefail

CONFIG=".claude/judgment.json"
[ -f "$CONFIG" ] || exit 0

export GUARD_INPUT="$(cat)"

python3 - "$CONFIG" <<'PY'
import json, os, re, sys

cfg = json.load(open(sys.argv[1]))
gate = cfg.get("commit_style", {})
if not gate.get("enabled", False):
    sys.exit(0)

data = json.loads(os.environ.get("GUARD_INPUT", "{}"))
cmd = (data.get("tool_input") or {}).get("command", "")
if not re.search(r"\bgit\b.*\bcommit\b", cmd):
    sys.exit(0)

# First line of the commit message: quoted -m arg, or first heredoc line.
m = re.search(r"-m\s+(?:\"\$\(cat\s+<<-?\s*'?\w+'?\s*\n([^\n]*)|\"([^\"\n]*)|'([^'\n]*))", cmd)
subject = next((g for g in (m.groups() if m else ()) if g), "").strip()
if not subject:
    sys.exit(0)  # editor-based or unparsable; not this gate's problem

PRESETS = {
    "conventional": (r"^(feat|fix|docs|chore|refactor|test|perf|build|ci|style|revert)(\([\w./-]+\))?!?: \S",
                     "conventional commits: type(scope): subject — e.g. 'fix(auth): reject expired tokens'"),
    "bracket": (r"^\[(FEAT|FIX|DOCS|CHORE|REFACTOR|TEST|PERF|BUILD|CI)\] \S",
                "bracket tags: [TYPE] subject — e.g. '[FIX] reject expired tokens'"),
}
style = gate.get("style", "conventional")
pattern, hint = PRESETS.get(style, PRESETS["conventional"])
if gate.get("extra_pattern"):
    pattern, hint = gate["extra_pattern"], f"custom pattern: {gate['extra_pattern']}"

if not re.match(pattern, subject):
    print(f"BLOCKED by commit-style gate: subject line does not match this "
          f"repo's declared style ({style}).\n  subject: {subject!r}\n"
          f"  expected {hint}", file=sys.stderr)
    sys.exit(2)
sys.exit(0)
PY
exit $?
