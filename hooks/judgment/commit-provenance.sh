#!/usr/bin/env bash
# commit-provenance.sh — git prepare-commit-msg script (NOT a Claude Code
# PreToolUse hook: rewriting -m arguments in flight is fragile, so this stamps
# the message file where git itself hands it to us).
# Appends a provenance trailer to every commit made in a judgment-enabled
# project:
#   Judgment: hooks=<enabled-count> matrix=<pass|unknown> [commit=<sha>] [model=<CLAUDE_MODEL>]
# hooks=  number of "enabled": true gates in .claude/judgment.json
# matrix= "pass" if .claude/.judgment-state/last-matrix contains "pass"
#         (written by a green hooks/judgment/test.sh run), else "unknown"
# commit= short sha this commit builds on (git rev-parse --short HEAD); this is
#         the commit-linkage anchor that verdict ledger lines (grammar v1,
#         `commit: <sha>`) reference. Omitted for a repo's root commit.
#
# Repo-agnostic. Enabled only if .claude/judgment.json exists in the project
# and has commit_provenance.enabled = true. Zero-LLM, pure bash+python3.
# Skips merge/squash commits and never duplicates an existing trailer.
#
# Config (judgment.json):
#   "commit_provenance": {"enabled": true}
#
# Wiring (git-hooks/prepare-commit-msg, hooksPath dir — see git-hooks/pre-commit):
#   #!/usr/bin/env bash
#   ~/.claude/hooks/judgment/commit-provenance.sh "$@"
set -uo pipefail

MSG_FILE="${1:-}"
SOURCE="${2:-}"
[ -n "$MSG_FILE" ] && [ -f "$MSG_FILE" ] || exit 0
case "$SOURCE" in merge|squash) exit 0 ;; esac

CONFIG=".claude/judgment.json"
[ -f "$CONFIG" ] || exit 0

python3 - "$CONFIG" "$MSG_FILE" <<'PY'
import json, os, sys

cfg = json.load(open(sys.argv[1]))
if not cfg.get("commit_provenance", {}).get("enabled", False):
    sys.exit(0)

def count_enabled(node):
    n = 0
    if isinstance(node, dict):
        if node.get("enabled") is True:
            n += 1
        for v in node.values():
            n += count_enabled(v)
    return n

matrix = "unknown"
try:
    if "pass" in open(".claude/.judgment-state/last-matrix").read():
        matrix = "pass"
except Exception:
    pass

trailer = f"Judgment: hooks={count_enabled(cfg)} matrix={matrix}"
# commit-linkage anchor: the sha this commit builds on. Verdict ledger lines
# (grammar v1) carry `commit: <sha>`; stamping it here ties the provenance
# trailer to the same commit graph. Degrades silently outside a repo / at root.
try:
    import subprocess
    head = subprocess.run(["git", "rev-parse", "--short", "HEAD"],
                          capture_output=True, text=True)
    if head.returncode == 0 and head.stdout.strip():
        trailer += f" commit={head.stdout.strip()}"
except Exception:
    pass
model = os.environ.get("CLAUDE_MODEL", "")
if model:
    trailer += f" model={model}"

msg = open(sys.argv[2]).read()
if "\nJudgment: hooks=" in msg or msg.startswith("Judgment: hooks="):
    sys.exit(0)  # already stamped (amend / retry)
with open(sys.argv[2], "w") as f:
    f.write(msg.rstrip("\n") + "\n\n" + trailer + "\n")
sys.exit(0)
PY
exit 0
