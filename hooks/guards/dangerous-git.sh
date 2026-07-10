#!/usr/bin/env bash
# dangerous-git.sh — PreToolUse hook (matcher: Bash).
# Blocks destructive git commands (force-push, hard reset, clean -f, branch -D,
# checkout/switch/merge/push against protected branches, --no-verify). Splits
# the command on &&/;/| and newlines so commit messages containing scary words
# don't false-positive — only subcommands that actually START with `git` are
# checked. Promoted from the battle-tested factory guard, genericized.
#
# Repo-agnostic. Enabled only if .claude/judgment.json exists and has
# guards.dangerous_git.enabled = true. Zero-LLM.
#
# Wiring (settings.json):
#   {"hooks": {"PreToolUse": [{"matcher": "Bash",
#     "hooks": [{"type": "command", "command": "path/to/dangerous-git.sh"}]}]}}
set -uo pipefail

CONFIG=".claude/judgment.json"
[ -f "$CONFIG" ] || exit 0

export JUDGMENT_INPUT="$(cat)"

python3 - "$CONFIG" <<'PY'
import json, os, re, sys

cfg = json.load(open(sys.argv[1]))
gate = cfg.get("guards", {}).get("dangerous_git", {})
if not gate.get("enabled", False):
    sys.exit(0)

data = json.loads(os.environ.get("JUDGMENT_INPUT", "{}"))
command = (data.get("tool_input") or {}).get("command", "")
if not command:
    sys.exit(0)

protected = gate.get("protected_branches", ["main", "master", "develop"])
patterns = [
    r"^git push\s+(-f|--force)\b",
    r"^git\s+.*--force-with-lease",
    r"^git reset --hard",
    r"^git clean -f",
    r"^git branch -D\b",
    r"^git checkout \.\s*$",
    r"^git restore \.\s*$",
    r"^git\s+.*--no-verify",
]
for b in protected:
    patterns += [
        rf"^git checkout {re.escape(b)}\s*$",
        rf"^git switch {re.escape(b)}\s*$",
        rf"^git merge\b.*\b{re.escape(b)}\b",
        rf"^git push\b.*\b{re.escape(b)}\b",
    ]
patterns += gate.get("extra_patterns", [])

# Check each subcommand independently; only ones that start with `git`.
for sub in re.split(r"&&|;|\||\n", command):
    sub = sub.strip()
    if not sub.startswith("git"):
        continue
    for pat in patterns:
        if re.search(pat, sub):
            print(f"BLOCKED by dangerous-git guard: '{sub}' matches '{pat}'.\n"
                  f"If this is genuinely intended, the Operator can run it "
                  f"manually, or relax guards.dangerous_git in "
                  f".claude/judgment.json (that edit IS the audit trail).",
                  file=sys.stderr)
            sys.exit(2)
sys.exit(0)
PY
