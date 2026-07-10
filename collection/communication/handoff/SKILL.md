---
name: handoff
origin: authored
public: true
description: >
  Context-rot prevention: write a structured handoff document capturing the current session
  state so you can /clear and continue in a fresh session without losing context.
  Use when: context >70%, session >15 turns, hitting limits, or switching tasks mid-work.
  Invoke: /handoff [optional-filename]
---

# /handoff — Session Handoff Document

Write a structured handoff doc to `docs/state/handoffs/YYYY-MM-DD-HH-MM.md` (or user-specified path).

## Steps

1. Determine output path: `docs/state/handoffs/<YYYY-MM-DD-HH-MM>.md`. Create dirs if needed.

2. Write the handoff doc with exactly these sections:

```
# Handoff — <YYYY-MM-DD HH:MM UTC>

## Branch & Git State
- Branch: <current branch>
- Last commit: <hash> <message>
- Uncommitted: <list files or "clean">

## Goal
<1-2 sentences: what we're trying to accomplish>

## Done This Session
<bulleted list of completed items with file paths>

## Pending / Next Steps
<ordered list of what to do next — be specific, include file paths and line numbers>

## Key Decisions Made
<any non-obvious choices: why X not Y>

## Active Linear Tickets
<BEN-XXXX: title — status>

## Resume Command
Continue from handoff: docs/state/handoffs/<filename>.md
```

3. Print: `Handoff written: docs/state/handoffs/<filename>.md`
4. Print: `Next: /clear → new session → paste: "Continue from handoff: docs/state/handoffs/<filename>.md"`

## On "continue from handoff <path>"

When a session starts with "Continue from handoff: <path>":
1. Read the handoff file at <path>
2. Confirm the branch, verify git state
3. Resume exactly at "Pending / Next Steps" — no recap needed
4. Say: "Resuming from handoff. Next: <first pending item>"

## Judgment weave (see /judgment)

The handoff doc must carry the judgment state, or the next session re-derives it: open `GATE:` lines and their current readings, unresolved `/door` analyses, UNVERIFIED claims awaiting refutation. Fresh sessions inherit the ledger for free (`.claude/verdicts.log` is committed) — point at it rather than re-summarizing.
