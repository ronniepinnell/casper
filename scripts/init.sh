#!/usr/bin/env bash
# init.sh — casper onboarding wizard. Zero-LLM, bash + python3 only.
#
#   ./scripts/init.sh            # interactive: detect stack, ask <=3 questions,
#                                # write .claude/judgment.json, run a live demo
#   ./scripts/init.sh --yes      # accept every default (non-interactive/CI)
#   ./install.sh --init [...]    # same thing, via the installer
#
# What it does, in order:
#   1. Detects your stack: migrations dirs (supabase/migrations, */migrations,
#      alembic, prisma), schema files, .github/workflows, test dir patterns.
#   2. Asks at most 3 questions: confirm protected paths, enable the
#      dangerous-git guard, turn the telemetry ledger on.
#   3. Writes a tuned .claude/judgment.json for THIS repo.
#   4. Live mini-demo: feeds a fake `git commit -m "fixed it"` through the
#      claim-evidence hook against your own repo — using a THROWAWAY git index
#      (GIT_INDEX_FILE in mktemp), so no real commit and no touched staging —
#      and shows you the exact block message Claude Code would see.
#
# Never overwrites an existing .claude/judgment.json (aborts with a message).
set -euo pipefail

TOOLKIT_NAME="casper"   # single rename point (see RENAME.md)
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_ROOT="$(pwd)/.claude"
CONFIG="$TARGET_ROOT/judgment.json"
ASSUME_YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y) ASSUME_YES=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ -f "$CONFIG" ]; then
  echo "ERROR: $CONFIG already exists — $TOOLKIT_NAME init never overwrites it." >&2
  echo "Delete or move it first if you want a fresh config." >&2
  exit 1
fi

echo "== $TOOLKIT_NAME init — $(pwd)"
echo

# ---- 1. stack detection -----------------------------------------------------
PROTECTED=()
add_glob() { PROTECTED+=("$1"); echo "  detected: $2 -> protecting $1"; }

[ -d supabase/migrations ] && add_glob "supabase/migrations/*" "Supabase migrations"
if [ -f alembic.ini ] || [ -d alembic/versions ]; then
  add_glob "alembic/versions/*" "Alembic migrations"
fi
if [ -d prisma ] || [ -f prisma/schema.prisma ]; then
  add_glob "prisma/*" "Prisma schema + migrations"
fi
# generic */migrations dirs (depth 2), skipping ones already covered
while IFS= read -r d; do
  case "$d" in
    ./supabase/migrations|./alembic/*|./prisma/*) continue ;;
  esac
  add_glob "${d#./}/*" "migrations dir"
done < <(find . -maxdepth 2 -type d -name migrations -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null)
[ -d schema ] && add_glob "schema/*" "schema/ dir"
if ls ./*openapi* >/dev/null 2>&1 || ls docs/*openapi* >/dev/null 2>&1; then
  add_glob "*openapi*" "OpenAPI spec"
fi
if find . -maxdepth 2 -name '*.proto' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | grep -q .; then
  add_glob "*.proto" "protobuf schemas"
fi
if [ "${#PROTECTED[@]}" -eq 0 ]; then
  echo "  no migrations/schema dirs detected — using the generic defaults"
  PROTECTED=("*/migrations/*" "schema/*")
fi

HAS_TESTS=0
for t in tests test spec __tests__; do [ -d "$t" ] && HAS_TESTS=1; done
[ "$HAS_TESTS" -eq 1 ] && echo "  detected: test dir — claim-evidence will accept staged test diffs as proof"

[ -d .github/workflows ] && echo "  detected: .github/workflows — consider the /refute CI action for PR-level enforcement"

DEFAULT_BRANCH="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||' || true)"
[ -n "$DEFAULT_BRANCH" ] || DEFAULT_BRANCH="main"
echo

# ---- 2. at most 3 questions -------------------------------------------------
ask() { # ask <prompt> <default y|n> -> echoes y or n
  local prompt="$1" def="$2" ans
  if [ "$ASSUME_YES" -eq 1 ]; then echo "$def"; return; fi
  read -r -p "$prompt [$([ "$def" = y ] && echo Y/n || echo y/N)] " ans </dev/tty || ans=""
  ans="$(echo "${ans:-$def}" | tr '[:upper:]' '[:lower:]')"
  [ "$ans" = y ] || [ "$ans" = yes ] && echo y || echo n
}

echo "Q1. Protect these paths behind the spec-citation gate?"
printf '      %s\n' "${PROTECTED[@]}"
Q1="$(ask "    Confirm" y)"

Q2="$(ask "Q2. Enable the dangerous-git guard (blocks force-push, hard reset, direct '$DEFAULT_BRANCH' pushes)?" y)"

Q3="$(ask "Q3. Turn the telemetry ledger on (skill usage -> .claude/.judgment-state, names only)?" n)"
echo

# ---- 3. write the tuned judgment.json ---------------------------------------
mkdir -p "$TARGET_ROOT"
PROTECTED_JSON="$(printf '%s\n' "${PROTECTED[@]}")" Q1="$Q1" Q2="$Q2" Q3="$Q3" \
DEFAULT_BRANCH="$DEFAULT_BRANCH" CONFIG="$CONFIG" EXAMPLE="$SRC/hooks/judgment/judgment.json.example" \
python3 - <<'PY'
import json, os

cfg = json.load(open(os.environ["EXAMPLE"]))
cfg.pop("_comment", None)
if os.environ["Q1"] == "y":
    cfg["spec_citation"]["protected_globs"] = [
        g for g in os.environ["PROTECTED_JSON"].splitlines() if g]
cfg["spec_citation"]["enabled"] = os.environ["Q1"] == "y"
cfg["guards"]["dangerous_git"]["enabled"] = os.environ["Q2"] == "y"
cfg["guards"]["dangerous_git"]["protected_branches"] = sorted(
    {"main", "master", os.environ["DEFAULT_BRANCH"]})
cfg["telemetry"]["enabled"] = os.environ["Q3"] == "y"
json.dump(cfg, open(os.environ["CONFIG"], "w"), indent=2)
print(f"wrote {os.environ['CONFIG']}")
PY
echo

# ---- 4. live mini-demo: fake "fixed it" commit, throwaway index -------------
echo "== live demo: what happens when the AI claims 'fixed it' with no proof"
echo
DEMO_INDEX="$(mktemp)"; trap 'rm -f "$DEMO_INDEX"' EXIT
echo '   $ git commit -m "fixed the login bug"        (throwaway index — nothing real is committed)'
set +e
printf '%s' '{"tool_input":{"command":"git commit -m \"fixed the login bug\""}}' \
  | GIT_INDEX_FILE="$DEMO_INDEX" "$SRC/hooks/judgment/claim-evidence.sh" 2>&1 | sed 's/^/   | /'
DEMO_EXIT=${PIPESTATUS[1]}
set -e
echo
if [ "$DEMO_EXIT" -eq 2 ]; then
  echo "   BLOCKED (exit 2) — this is the message Claude Code sees before the commit runs."
else
  echo "   NOTE: demo did not block (exit $DEMO_EXIT) — is claim_evidence.enabled true in $CONFIG?"
fi
echo
# ---- 5. the mirror: grade the dones this repo ALREADY shipped ---------------
if command -v gh >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1 \
   && gh repo view >/dev/null 2>&1; then
  echo "== your history, graded (last 50 merged PRs — the gates protect the NEXT ones)"
  python3 "$SRC/scripts/backfill.py" --limit 50 2>/dev/null | tail -8 || true
  echo
fi

echo "Done. Next steps:"
echo "  1. Wire the hooks into .claude/settings.json (each script's header shows the snippet)."
echo "  2. Commit $CONFIG so the whole team gets the same gates."
echo "  3. Inside Claude Code, try: /refute the login fix works"
