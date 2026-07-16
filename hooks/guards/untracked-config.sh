#!/usr/bin/env bash
# untracked-config.sh — PreToolUse hook (matcher: Bash).
# Blocks `git commit` while .claude/project.yml (or other configured files)
# is untracked — the fleet audit found 4 repos where /project-init's output
# sat untracked for weeks. The scaffold's config is part of the repo; a
# commit that leaves it behind silently forks the project's conventions.
#
# Repo-agnostic. Inert unless .claude/judgment.json exists with
#   "guards": {"untracked_config": {"enabled": true,
#              "files": [".claude/project.yml"]}}
#
# Wiring (settings.json):
#   {"hooks": {"PreToolUse": [{"matcher": "Bash",
#     "hooks": [{"type": "command", "command": "path/to/untracked-config.sh"}]}]}}
set -uo pipefail

CONFIG=".claude/judgment.json"
[ -f "$CONFIG" ] || exit 0

export GUARD_INPUT="$(cat)"

python3 - "$CONFIG" <<'PY'
import json, os, re, subprocess, sys

cfg = json.load(open(sys.argv[1]))
guard = cfg.get("guards", {}).get("untracked_config", {})
if not guard.get("enabled", False):
    sys.exit(0)

data = json.loads(os.environ.get("GUARD_INPUT", "{}"))
cmd = (data.get("tool_input") or {}).get("command", "")
if not re.search(r"\bgit\b.*\bcommit\b", cmd):
    sys.exit(0)

files = guard.get("files", [".claude/project.yml"])
try:
    out = subprocess.run(["git", "status", "--porcelain", "--"] + files,
                         capture_output=True, text=True, timeout=10).stdout
except Exception:
    sys.exit(0)  # never let the guard itself break commits

untracked = [ln[3:] for ln in out.splitlines() if ln.startswith("??")]
if untracked:
    print("BLOCKED by untracked-config guard: these config files exist but "
          "are not tracked:\n  " + "\n  ".join(untracked) +
          "\ngit add them (they are part of the repo's conventions) or, if "
          "one is intentionally local-only, add it to .gitignore so this "
          "guard stops seeing it.", file=sys.stderr)
    import os as _os, datetime as _dt
    _os.makedirs('.claude/.judgment-state', exist_ok=True)
    open('.claude/.judgment-state/gate-events.log','a').write(
        _dt.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ') + ' gate=untracked-config event=block\n')
    sys.exit(2)
sys.exit(0)
PY
exit $?
