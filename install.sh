#!/usr/bin/env bash
# casper installer — non-invasive by design.
#
#   ./install.sh                       # the 13 judgment skills -> ./.claude/skills of the CURRENT project
#   ./install.sh --global              # -> ~/.claude instead
#   ./install.sh --only refute,gate    # subset, by name (judgment OR collection skills/agents)
#   ./install.sh --category <name>     # every unit in collection/<name>/ (skills + agents)
#   ./install.sh --all                 # the 13 judgment skills + the ENTIRE collection
#   ./install.sh --hooks               # also copy hooks/ + judgment.json template (default-OFF)
#   ./install.sh --dry-run             # print the plan, write nothing
#   ./install.sh --init                # onboarding wizard: detect stack, tune
#                                      # .claude/judgment.json, live block demo
#                                      # (delegates to scripts/init.sh; extra
#                                      # flags like --yes pass through)
#
# Skills install to .claude/skills/<name>/, agents to .claude/agents/<name>.md.
# Everything written is recorded in a manifest (.claude/.casper-manifest);
# ./uninstall.sh reverts exactly that — files, then any directories it created.
# Existing files are NEVER overwritten (skipped with a warning, not recorded).
set -euo pipefail

TOOLKIT_NAME="casper"   # single rename point (see RENAME.md)
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "${1-}" = "--init" ]; then shift; exec "$SRC/scripts/init.sh" "$@"; fi

TARGET_ROOT="$(pwd)/.claude"
ONLY=""
CATEGORY=""
ALL=0
WITH_HOOKS=0
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --global) TARGET_ROOT="$HOME/.claude" ;;
    --only) ONLY="$2"; shift ;;
    --only=*) ONLY="${1#--only=}" ;;
    --category) CATEGORY="$2"; shift ;;
    --category=*) CATEGORY="${1#--category=}" ;;
    --all) ALL=1 ;;
    --hooks) WITH_HOOKS=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

MANIFEST="$TARGET_ROOT/.${TOOLKIT_NAME}-manifest"
if [ -f "$MANIFEST" ] && [ "$DRY_RUN" -eq 0 ]; then
  # Additive re-run (e.g. base install first, --hooks later — the normal
  # adoption path). Existing files are never overwritten anyway; new writes
  # append to the same manifest so ONE ./uninstall.sh still reverts all.
  # (Cold-clone refute 2026-07-15: the old hard abort forced a full
  # uninstall just to add hooks.)
  echo "note: existing install detected — running additively; new files append to the manifest."
fi

# --- unit resolution -------------------------------------------------------
# Populate two lists: SKILL_DIRS (name -> source dir) and AGENT_FILES (name ->
# source file). Names are resolved across the top-level judgment skills/ and the
# whole collection/ tree.
SKILL_NAMES=()   ; SKILL_SRCS=()
AGENT_NAMES=()   ; AGENT_SRCS=()

add_skill() { SKILL_NAMES+=("$1"); SKILL_SRCS+=("$2"); }
add_agent() { AGENT_NAMES+=("$1"); AGENT_SRCS+=("$2"); }

add_category() { # add every unit under collection/<cat>/
  local cat="$1" cdir="$SRC/collection/$1"
  [ -d "$cdir" ] || { echo "ERROR: unknown category '$cat'" >&2; exit 1; }
  local d
  for d in "$cdir"/*/; do
    [ -f "${d}SKILL.md" ] && add_skill "$(basename "$d")" "${d%/}"
  done
  local f
  for f in "$cdir"/*.md; do
    [ -e "$f" ] || continue
    [ "$(basename "$f")" = "README.md" ] && continue
    add_agent "$(basename "$f" .md)" "$f"
  done
}

resolve_name() { # find one name across judgment skills + collection; add all matches
  local n="$1" found=0
  if [ -f "$SRC/skills/$n/SKILL.md" ]; then add_skill "$n" "$SRC/skills/$n"; found=1; fi
  local d
  for d in "$SRC"/collection/*/"$n"/; do
    [ -f "${d}SKILL.md" ] && { add_skill "$n" "${d%/}"; found=1; }
  done
  for d in "$SRC"/collection/*/"$n".md; do
    [ -e "$d" ] && { add_agent "$n" "$d"; found=1; }
  done
  [ "$found" -eq 1 ] || { echo "ERROR: unknown unit '$n'" >&2; exit 1; }
}

if [ "$ALL" -eq 1 ]; then
  for d in "$SRC"/skills/*/; do add_skill "$(basename "$d")" "${d%/}"; done
  for c in "$SRC"/collection/*/; do add_category "$(basename "$c")"; done
elif [ -n "$CATEGORY" ]; then
  add_category "$CATEGORY"
elif [ -n "$ONLY" ]; then
  for n in $(echo "$ONLY" | tr ',' ' '); do resolve_name "$n"; done
else
  # default: the 13 judgment skills
  for d in "$SRC"/skills/*/; do add_skill "$(basename "$d")" "${d%/}"; done
fi

CREATED_FILES=()
CREATED_DIRS=()

ensure_dir() { # records every directory level it actually creates
  local d="$1" stack=()
  while [ ! -d "$d" ]; do stack=("$d" "${stack[@]+"${stack[@]}"}"); d="$(dirname "$d")"; done
  for d in ${stack[@]+"${stack[@]}"}; do
    if [ "$DRY_RUN" -eq 1 ]; then echo "  mkdir $d"; else mkdir "$d"; fi
    CREATED_DIRS+=("$d")
  done
}

put() { # put <src-file> <dest-file>
  local src="$1" dest="$2"
  if [ -e "$dest" ]; then echo "  SKIP (exists): $dest" >&2; return 0; fi
  ensure_dir "$(dirname "$dest")"
  if [ "$DRY_RUN" -eq 1 ]; then echo "  copy  $dest"; else cp "$src" "$dest"; fi
  CREATED_FILES+=("$dest")
}

echo "$TOOLKIT_NAME install -> $TARGET_ROOT $([ "$DRY_RUN" -eq 1 ] && echo '(dry-run)')"

i=0
for name in ${SKILL_NAMES[@]+"${SKILL_NAMES[@]}"}; do
  srcdir="${SKILL_SRCS[$i]}"; i=$((i+1))
  for f in $(cd "$srcdir" && find . -type f | sed 's|^\./||'); do
    put "$srcdir/$f" "$TARGET_ROOT/skills/$name/$f"
  done
done

i=0
for name in ${AGENT_NAMES[@]+"${AGENT_NAMES[@]}"}; do
  srcfile="${AGENT_SRCS[$i]}"; i=$((i+1))
  put "$srcfile" "$TARGET_ROOT/agents/$name.md"
done

if [ "$WITH_HOOKS" -eq 1 ]; then
  for f in $(cd "$SRC/hooks" && find . -type f -name '*.sh' | sed 's|^\./||'); do
    put "$SRC/hooks/$f" "$TARGET_ROOT/hooks/$f"
    [ "$DRY_RUN" -eq 1 ] || chmod +x "$TARGET_ROOT/hooks/$f"
  done
  put "$SRC/hooks/judgment/judgment.json.example" "$TARGET_ROOT/judgment.json.example"
  echo
  echo "Hooks copied DEFAULT-OFF. To activate:"
  echo "  1. cp $TARGET_ROOT/judgment.json.example $TARGET_ROOT/judgment.json  (flip enabled per gate)"
  echo "  2. wire each script into .claude/settings.json per its header comment"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "dry-run: nothing written (manifest would be $MANIFEST)"
  exit 0
fi

# Append on re-run so ONE uninstall reverts every batch; write header once.
[ -f "$MANIFEST" ] || echo "# $TOOLKIT_NAME manifest — consumed by uninstall.sh; do not edit" > "$MANIFEST"
{
  for f in ${CREATED_FILES[@]+"${CREATED_FILES[@]}"}; do echo "F $f"; done
  for d in ${CREATED_DIRS[@]+"${CREATED_DIRS[@]}"}; do echo "D $d"; done
} >> "$MANIFEST"

echo "installed ${#SKILL_NAMES[@]} skill(s) + ${#AGENT_NAMES[@]} agent(s). Manifest: $MANIFEST"
echo "Uninstall any time: ./uninstall.sh (from the same directory you installed from)"
