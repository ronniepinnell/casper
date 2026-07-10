---
name: sync-skills
origin: authored
public: true
description: Push or pull changes to the shared shared-config repo. Shows shared repo status AND flags project overlays that have diverged from the shared version.
---

# Sync Skills

Syncs the shared `shared-config` repo that backs `~/.claude/{agents,skills,hooks,prompts}`.

## Usage

- `/sync-skills` — show status (shared repo changes + overlay divergence)
- `/sync-skills push` — commit and push shared repo changes to remote
- `/sync-skills pull` — pull latest shared repo from remote

**To promote an overlay change back to the shared skill:** use `/skill-writer` to edit the overlay,
then answer "yes" when it asks if the change is universal. The promote flow is built into skill-writer.

## Instructions

### Step 1: Find the shared repo

```bash
REPO_DIR=$(readlink ~/.claude/skills)/..
```

If not a symlink, tell the user to run `install.sh` first.

### Step 2: Based on the argument

**No argument (status):**

```bash
cd "$REPO_DIR" && git status --short
```

Then also scan for project overlays that differ from the shared version:

```bash
# Find any .claude/skills/ directory in the current project (not a symlink)
if [ -d ".claude/skills" ] && [ ! -L ".claude/skills" ]; then
  for overlay in .claude/skills/*/SKILL.md; do
    skill=$(basename $(dirname "$overlay"))
    shared="$REPO_DIR/skills/$skill/SKILL.md"
    if [ -f "$shared" ]; then
      diff_lines=$(diff "$overlay" "$shared" | grep -c "^[<>]")
      if [ "$diff_lines" -gt 0 ]; then
        echo "  overlay diverges: $skill ($diff_lines changed lines)"
      fi
    else
      echo "  overlay only (no shared version): $skill"
    fi
  done
fi
```

Print two sections:
```
Shared shared-config (affects all projects):
  M skills/milestone/SKILL.md
  M skills/epic/SKILL.md

Project overlays diverging from shared:
  find-bugs          12 changed lines  ← run /skill-writer to edit and optionally promote
  hockey-analyst     overlay only      ← project-specific, no shared version
```

If no overlays differ: print "No overlay divergence."

**`push`:**
```bash
cd "$REPO_DIR" && git add -A && git commit -m "[SYNC] Update shared Claude config" && git push
```

**`pull`:**
```bash
cd "$REPO_DIR" && git pull --rebase
```

### Step 3: Report

Show what changed — files added, modified, deleted.
Remind the user: "To promote overlay changes upstream, use /skill-writer → edit overlay → answer 'yes' to promote."

## Judgment weave (see /judgment)

- **On divergence flags:** before overwriting either side, run **`/drift`** to decide which copy is lying — the shared repo or the project overlay.
