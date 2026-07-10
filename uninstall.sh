#!/usr/bin/env bash
# casper uninstaller — reverts EXACTLY what install.sh wrote, nothing else.
#
#   ./uninstall.sh            # uses ./.claude/.casper-manifest (current project)
#   ./uninstall.sh --global   # uses ~/.claude/.casper-manifest
#
# Removes the manifest's files, then removes (rmdir, so only-if-empty) every
# directory the installer created, deepest first, then the manifest itself.
set -euo pipefail

TOOLKIT_NAME="casper"   # single rename point (see RENAME.md)
TARGET_ROOT="$(pwd)/.claude"
[ "${1:-}" = "--global" ] && TARGET_ROOT="$HOME/.claude"

MANIFEST="$TARGET_ROOT/.${TOOLKIT_NAME}-manifest"
[ -f "$MANIFEST" ] || { echo "no manifest at $MANIFEST — nothing to uninstall." >&2; exit 1; }

removed=0
# files
while IFS= read -r line; do
  case "$line" in
    "F "*) f="${line#F }"
           if [ -f "$f" ]; then rm "$f"; removed=$((removed+1)); fi ;;
  esac
done < "$MANIFEST"

# dirs: deepest first, only if empty (never touches user-created content)
grep '^D ' "$MANIFEST" | sed 's/^D //' | awk '{ print length($0), $0 }' | sort -rn | cut -d' ' -f2- | \
while IFS= read -r d; do
  [ -d "$d" ] && rmdir "$d" 2>/dev/null || true
done

rm "$MANIFEST"
# if the installer created .claude itself it's in the D list already; final sweep:
rmdir "$TARGET_ROOT" 2>/dev/null || true

echo "uninstalled: $removed file(s) removed; created directories cleaned up."
