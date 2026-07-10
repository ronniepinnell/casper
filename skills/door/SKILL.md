---
name: door
origin: authored
description: One-way-door decision triage. Sorts any decision into reversible (just pick) vs irreversible (slow down, enumerate lock-in). Use before schema changes, ID formats, API contracts, auth models, naming, tech-stack picks, or whenever a choice feels weighty.
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[the decision, e.g. 'UUID vs bigint for player ids']"
---

# /door — Is This Decision a One-Way Door?

Most disasters are irreversible choices made casually, and most wasted time is
reversible choices made ceremoniously. This skill sorts them — then spends effort
only where it can't be refunded.

## Invocation

```
/door uuid vs bigint primary keys
/door                              # triage the decision currently under discussion
```

## Procedure

1. **State the decision and the options.** Two sentences max per option.

2. **The sort question:** if this turns out wrong, what does undoing it cost in
   6–12 months? Answer in concrete units: a rename, a migration, a rewrite, a
   breaking API change for N consumers, a data backfill.

3. **TWO-WAY DOOR** (cheap to reverse) →
   - Pick now. Prefer the boring option. Write one line saying why. Move on.
   - Explicitly banned: further research, option matrices, asking for approval.

4. **ONE-WAY DOOR** (expensive/impossible to reverse) → answer all five, in writing:
   - **Lock-in:** exactly what becomes unchangeable (formats, contracts, published
     IDs, wire protocols, stored data shapes)?
   - **Who pays:** which future person/system eats the cost if wrong, and when?
   - **Escape hatch:** what would migration off this cost? Can a seam be added NOW
     to make it cheaper (adapter layer, versioned field, opaque ID)?
   - **Shrink the door:** can any part be deferred or made reversible? The best
     one-way-door answer is often "make it a two-way door first."
   - **Kill-gate:** what measurable signal, by when, tells us we chose wrong?
     (Hand this to `/gate`.)

5. **Verdict line** (goes in the commit / PR / decision log):
   `DOOR: one-way | locked: <what> | escape: <cost> | gate: <signal>`
   or `DOOR: two-way | picked <X> because <one clause>`.

## Disagreement check (one-way verdicts)

For ONE-WAY doors, get a second, independent answer before committing: dispatch
the same decision (options + lock-in facts, no shared reasoning) to a different
model if one is available, otherwise an independent subagent with
no shared context — and diff the two verdicts. Agreement → proceed. Disagreement
is a mechanical proxy for "this is hard": queue it via `/escalate` instead of
deciding inline.

## Rules

- If you can't name the lock-in concretely, you don't understand the decision yet —
  that's the finding; go read the code/spec first.
- Deciding fast on two-way doors is not recklessness, it's the point.
- A one-way door decided under time pressure must at minimum get the escape-hatch
  seam, even if analysis is cut short.

### Worked example (real ruling, 2026-07-09 — reproduced as a static transcript)

**Decision:** merge a PR wholesale vs cherry-pick only the target commits.
The branch carried unrelated feature work alongside the target changes.

1. Options: merge whole (one revertable merge commit) vs cherry-pick (clean
   history, but hand-splitting 13 commits invites conflicts and silent loss).
2. Sort question: undoing a bad merge costs one `git revert -m 1` — cheap.
3. Lock-in enumerated: no schemas, no published IDs, no API contracts touched —
   nothing permanent.
4. The stowaway work wasn't taken on faith: its commit trail (13 deliberate
   commits, including its own fix rounds) showed it was built and corrected,
   not dumped.
5. Merged whole, no option matrix, moved on.

`DOOR: two-way | picked wholesale merge because a merge commit is one revert away and the stowaway work's own commit trail verified it`

## Composes with

- `/gate` — step 4's kill-gate is authored there.
- `/premortem` — run it on any one-way door before committing.
- `spec-citation` hook — one-way-door paths (schema/, migrations/, contracts) are
  exactly what you list in `.claude/judgment.json` protected globs.
- `/precedent` — run it first; a banked ruling can settle the door outright.
- `/escalate` — one-way doors with no precedent, or a failed disagreement
  check, queue there instead of being decided inline.
- `/think` — one-way doors deserve a `second-order` pass before committing.
- `/verdict` — every door ruling is logged there.
