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
if not message:
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
# check itself is identical regardless of voice.
_banners = {"casper": "\U0001F47B Boo — that ain't done yet.\n"}
banner = _banners.get(gate.get("voice", "plain"), "")

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
