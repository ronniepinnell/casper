---
name: sync-ai-context
origin: authored
public: true
description: Diff and re-sync all AI context files (GEMINI.md, Cursor rules, Copilot instructions, rules/BASE.md) against AGENTS.md. Run after editing AGENTS.md or changing critical rules to propagate updates to all derived files.
allowed-tools: Bash, Read, Write, Edit, Glob
---

# Sync AI Context

AGENTS.md is the canonical source of truth. All other AI context files derive from it.
This skill diffs each derived file against AGENTS.md and propagates changes.

**Run this after:**
- Editing AGENTS.md directly
- Running `/project-init update rules`
- Adding a new critical rule to CLAUDE.md that should apply to all AI tools
- Any time you suspect drift across AI files

---

## Step 1: Verify AGENTS.md exists

```bash
ls AGENTS.md 2>/dev/null
```

If missing: "AGENTS.md not found. Run `/project-init` first, or create AGENTS.md as the
canonical source of truth for this project's AI context."

---

## Step 2: Read AGENTS.md

Read the full file. Extract these key sections by heading:
- `## NEVER Do These Things` (or equivalent rules section)
- `## Commands`
- `## Architecture` / `## Key Entry Points`
- `## Code Standards`
- `## Git Workflow`
- `## What Is This Project?` / overview paragraph

These are the sections that must stay in sync across derived files.

---

## Step 3: Scan for derived files

Check which derived files exist:

```bash
ls GEMINI.md .cursorrules .cursor/rules/project.mdc \
   .github/copilot-instructions.md rules/BASE.md CLAUDE.md 2>/dev/null
```

---

## Step 4: Diff each file

For each file found, compare its key sections against AGENTS.md.
Classify each difference as one of:

| Type | Meaning |
|------|---------|
| `MISSING` | Rule/section exists in AGENTS.md but not in derived file |
| `OUTDATED` | Section exists but content differs from AGENTS.md |
| `EXTRA` | Content in derived file with no counterpart in AGENTS.md — may be intentional |
| `CONTRADICTION` | Derived file says opposite of AGENTS.md |

CLAUDE.md is special: it may have Claude-specific additions. Only flag `CONTRADICTION`
and `MISSING` for CLAUDE.md — never flag its extras as drift.

---

## Step 5: Print drift report

```
AI Context Drift Report — {project_name}
══════════════════════════════════════════════════════
  AGENTS.md                  ← canonical source
  ─────────────────────────────────────────────────
  GEMINI.md                  2 rules MISSING, Commands OUTDATED
  .cursor/rules/project.mdc  1 CONTRADICTION ("never use iterrows" missing)
  .cursorrules               in sync ✓
  copilot-instructions       Commands OUTDATED
  rules/BASE.md              in sync ✓
  CLAUDE.md                  in sync ✓ (3 Claude-specific extras kept)
══════════════════════════════════════════════════════
```

If all files are in sync: "All AI context files are in sync with AGENTS.md. Nothing to do."
Exit early.

---

## Step 6: Offer sync options

Ask:
> "How would you like to sync?"
> Options:
> - **Sync all** — propagate all MISSING/OUTDATED/CONTRADICTION changes now
> - **Show diffs** — print each change before applying, confirm per-file
> - **Sync one file** — pick which file to update
> - **Skip** — report only, no writes

---

## Step 7: Apply changes

For each file being synced:

### GEMINI.md
- Add any MISSING rules to the `## Critical Rules` section
- Update `## Commands` if OUTDATED
- Do NOT touch: `## Model Guidance`, `## Common Gemini CLI Patterns` — these are Gemini-specific

### .cursor/rules/project.mdc
- Update the section derived from AGENTS.md critical rules
- Do NOT touch: `---` frontmatter, `## Domain Context` (project-specific)

### .cursorrules
- Mirror `.cursor/rules/project.mdc` content, strip frontmatter

### .github/copilot-instructions.md
- Update `## Never` and `## Commands` sections
- Do NOT touch: `## Always` if it has project-specific additions
- Keep under 80 lines — if adding rules would exceed, summarize

### rules/BASE.md
- Add MISSING rules to `## Never`
- Update `## Result Reporting` if OUTDATED
- Do NOT add prose — imperatives only

### CLAUDE.md
- Only fix CONTRADICTION — never remove Claude-specific content
- Add MISSING critical rules to `## Critical Rules`

---

## Step 8: Report what changed

After sync:
```
Synced:
  GEMINI.md              ✓ added 2 rules, updated Commands
  .cursor/rules/         ✓ fixed contradiction in iterrows rule
  copilot-instructions   ✓ updated Commands

Unchanged (in sync or skipped):
  .cursorrules           ✓
  rules/BASE.md          ✓
  CLAUDE.md              ✓

Run /project-init sync for a full structural re-sync including templates.
```

## Judgment weave (see /judgment)

- **This is a drift check by construction** — when a derived file disagrees with AGENTS.md in a way that suggests the *canon* is stale, escalate to **`/drift`** instead of blindly re-syncing.
