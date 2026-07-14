#!/usr/bin/env bash
# claim-evidence.sh — PreToolUse hook (matcher: Bash).
# Blocks `git commit` messages that claim completion (fix/fixed/done/works/
# complete/resolved) unless the commit carries evidence: staged test changes
# or an "Evidence:" line in the message.
#
# Repo-agnostic. Enabled only if .claude/judgment.json exists in the project
# and has claim_evidence.enabled = true. Zero-LLM, pure bash+python3.
#
# Wiring (settings.json):
#   {"hooks": {"PreToolUse": [{"matcher": "Bash",
#     "hooks": [{"type": "command", "command": "path/to/claim-evidence.sh"}]}]}}
set -uo pipefail

CONFIG=".claude/judgment.json"
[ -f "$CONFIG" ] || exit 0

export JUDGMENT_INPUT="$(cat)"

python3 - "$CONFIG" <<'PY'
import json, os, re, subprocess, sys

cfg = json.load(open(sys.argv[1]))
gate = cfg.get("claim_evidence", {})
if not gate.get("enabled", False):
    sys.exit(0)

data = json.loads(os.environ.get("JUDGMENT_INPUT", "{}"))
cmd = (data.get("tool_input") or {}).get("command", "")
if not re.search(r"\bgit\b.*\bcommit\b", cmd):
    sys.exit(0)

# Extract the commit message from -m arguments (rough but effective).
msgs = re.findall(r"-m\s+(?:\"([^\"]*)\"|'([^']*)')", cmd, re.S)
message = " ".join(a or b for a, b in msgs)
# -m "$(cat <<'EOF' … EOF)" style: the quoted-arg regex stops at the FIRST
# embedded double-quote inside the heredoc, which can hide an Evidence: line
# (false block) or a claim word (false pass). Take the first heredoc body
# after the `git commit` token as the real message. Only that one — a later
# heredoc (e.g. a chained `gh pr create` body) must not stand in as evidence.
mcommit = re.search(r"\bgit\b[^&;|]*\bcommit\b", cmd)
if mcommit:
    h = re.search(r"<<-?\s*'?(\w+)'?\s*\n(.*?)\n\1\b", cmd[mcommit.start():], re.S)
    if h:
        message += " " + h.group(2)
if not message.strip():
    sys.exit(0)  # editor-based commit; nothing to scan

claim_words = gate.get("claim_words",
    ["fixed", "fixes", "fix", "done", "works", "working", "complete",
     "completed", "resolved", "resolves"])
if not re.search(r"\b(" + "|".join(map(re.escape, claim_words)) + r")\b",
                 message, re.I):
    sys.exit(0)

# Evidence path 1: explicit Evidence: line with content.
if re.search(r"\bEvidence:\s*\S+", message, re.I):
    sys.exit(0)

# Evidence path 2: staged diff touches test files.
test_pat = re.compile(gate.get(
    "test_pattern", r"(^|/)(tests?|__tests__|spec)/|\.(test|spec)\.|_test\."))
try:
    staged = subprocess.run(["git", "diff", "--cached", "--name-only"],
                            capture_output=True, text=True, timeout=10)
    if any(test_pat.search(f) for f in staged.stdout.splitlines()):
        sys.exit(0)
except Exception:
    sys.exit(0)  # never let the gate itself break commits

# Optional voice: cosmetic banner prepended to the block message. Default plain.
# A project sets claim_evidence.voice to give the gate a personality; the
# check itself is identical regardless of voice. The 'casper' voice rotates
# through quirky one-liners (all start with 👻 so tooling can detect them).
import random
_casper_lines = [
    "\U0001F47B Boo! Caught one. That 'done' brought no receipts.",
    "\U0001F47B A wild 'done' appeared — with zero evidence. Not today.",
    "\U0001F47B I pass through walls, not through unproven commits.",
    "\U0001F47B 'All tests pass'? Name one. I'll wait…",
    "\U0001F47B Spooky: this commit claims victory and packed no proof.",
    "\U0001F47B That 'fixed' is doing a lot of heavy lifting with no evidence.",
    "\U0001F47B Boo — that ain't done yet. (I'd know. I've seen the code.)",
]
voice = gate.get("voice", "plain")
if voice == "casper":
    # Seed by the message so the same commit gets the same quip (stable), but
    # different commits get variety.
    banner = random.Random(message).choice(_casper_lines) + "\n"
else:
    banner = ""

print(banner +
      "claim-evidence gate: this commit message claims completion "
      "(fix/done/works/…) but has no evidence attached.\n"
      "Provide one of:\n"
      "  1. An 'Evidence: <command + result>' line in the commit message "
      "(run /refute to produce it), or\n"
      "  2. Staged test changes covering the claim.\n"
      "Or drop the completion claim from the message.", file=sys.stderr)
sys.exit(2)
PY
