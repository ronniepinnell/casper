---
name: precedent
origin: authored
description: Precedent lookup before deciding. Greps prior rulings — the verdicts ledger, decision stores, the adjudicated escalation queue — for anything bearing on a pending decision, then either FOLLOWS the precedent or explicitly DISTINGUISHES the case. Use before any /door call, gate override, or decision in a domain the project has ruled on before. No silent departures.
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[the pending decision, e.g. 'ID format for new events table']"
---

# /precedent — Has This Already Been Decided?

The ledger only compounds if it's consulted. A team that re-litigates settled
questions wastes frontier effort; a team that silently contradicts its own
rulings is worse — it has two answers in production. This skill makes the
lookup mandatory and the departure explicit.

## Invocation

```
/precedent uuid vs bigint for the new events table
/precedent                 # look up the decision currently under discussion
```

## Procedure

1. **Name the domain and 2–4 keywords** for the pending decision (e.g. "ID
   format": `uuid`, `bigint`, `pk`, `id`).

2. **Grep the ruling stores**, in order:
   - `.claude/verdicts.log` — DOOR / GATE / ESCALATE lines
   - `.claude/escalation-queue.md` `## Adjudicated` section — burned escalations
   - any project decisions store (DECISIONS_INDEX, docs/decisions/, a decisions DB)
   Paste the matching lines. Zero hits in all three → verdict `none-found`,
   decide fresh (via `/door` if it's weighty) and move on.

3. **Cite what's found.** Quote the ruling(s) verbatim with ref (date/ID/file).
   If rulings conflict with each other, that's the finding — escalate the
   conflict via `/escalate`, don't pick a favorite.

4. **Follow or distinguish** — exactly one:
   - **FOLLOW** — apply the prior ruling. One line saying so. Done; this is the
     cheap, common case.
   - **DISTINGUISH** — state the *material* difference between this case and
     the precedent's facts, in one or two sentences. "It feels different" and
     "that was a while ago" are not material differences; changed constraints,
     changed scale, or a ruling whose kill-gate has since tripped are.

5. **Verdict line** (log via `/verdict`):
   `PRECEDENT: followed <ref>` or
   `PRECEDENT: distinguished <ref> — <material difference>` or
   `PRECEDENT: none-found`.

## Rules

- No silent departures. Any decision that contradicts a found ruling without a
  logged DISTINGUISH line is a judgment override — declare it (see the
  Judgment override rule in the repo CLAUDE.md).
- A DISTINGUISH is itself precedent: it narrows the old ruling. Log it.
- If the same precedent gets distinguished three times, the ruling is wrong —
  send it to `/escalate` for re-adjudication instead of a fourth carve-out.

## Composes with

- `/door` — run this first; a found precedent often collapses a one-way-door
  analysis to FOLLOW. No precedent on a one-way door is an `/escalate` trigger.
- `/verdict` — the primary store this greps, and where its own verdicts land.
- `/escalate` — conflicting or thrice-distinguished precedents go there.
