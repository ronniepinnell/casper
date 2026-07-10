---
name: continue
origin: authored
public: true
description: Resume interrupted session. Loads context, companion findings, and git state.
allowed-tools: Bash, Read, Grep, Glob
---

# /continue — Resume Interrupted Session

Picks up where the last session left off.

## What Happens

1. **Load state**: Read `{plan_file}` "Current State" section
2. **Git state**: `git status`, `git log --oneline -5`, check current branch
3. **Memory**: Load relevant memory files from MEMORY.md index
4. **Companion findings**: Read `.companion-output/` for anything new since last session
5. **Runner results**: Check `.claude/prompts/logs/` for completed/failed prompts
6. **Present briefing**: Unified summary of where things stand

## Team Mode / Fallback Mode

Not applicable — /continue is a context-loading operation, not an agent workflow.

## What It Does NOT Do

- Does not auto-start any mode — Operator decides what to work on
- Does not commit or push anything
- Does not modify any files

## Judgment weave (see /judgment)

- **On resume:** run **`/drift`** — the handoff doc vs actual git state; trust the repo, then fix the doc.
