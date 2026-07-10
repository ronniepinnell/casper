---
name: escalate
origin: authored
description: Judgment escalation queue. When a session hits a judgment-dense question it shouldn't wing — a one-way door with no precedent, a borderline gate, a spec-vs-code conflict, a calibration miss — it stops that thread, queues the question to .claude/escalation-queue.md with a provisional answer, and ships the rest. Use /escalate burn to batch-adjudicate the queue with a frontier model or human.
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
argument-hint: "[the question to queue | burn]"
---

# /escalate — Queue the Hard Call, Ship the Rest

The expensive failure isn't the hard question — it's a mid-strength answer to a
hard question, silently baked into shipped work. This skill splits them: the
work ships now, the judgment call goes to a queue where a frontier model or a
human adjudicates it in batch, with full context preserved.

## Invocation

```
/escalate should verdicts.log move into the decisions DB?   # queue a question
/escalate                                                    # queue the question under discussion
/escalate burn                                               # batch-adjudicate the queue
```

## Triggers — queue instead of deciding inline when:

- **(a) One-way door, no precedent** — `/door` says one-way and neither
  `/precedent` nor the ledger has a banked contract or prior ruling to lean on.
- **(b) Borderline gate** — a `/gate check` lands within ~10% of threshold in
  either direction. Don't round; queue.
- **(c) Spec-vs-code conflict** — `/drift` finds a disagreement and neither
  side is clearly authoritative.
- **(d) Systematic error** — `/calibrate` surfaces a pattern whose correction
  isn't obvious (which mechanism to change, or whether to demote a domain).

## Queue procedure

1. **STOP the judgment thread.** No further analysis; you already know it's
   above this session's pay grade — that's the trigger firing.
2. **Append an entry to `.claude/escalation-queue.md`** (create with `## Queue` and
   `## Adjudicated` sections on first use; commit it — the queue is the point):
   ```
   ### ESC-NNN | 2026-07-09 | trigger: one-way-no-precedent
   Q: <the question, one or two sentences>
   Context: <files, claims, numbers — everything an adjudicator needs cold>
   Provisional: <this session's own answer> [MED]
   Shipped despite: <what work went out with this question open>
   ```
   IDs are sequential (grep the file for the last ESC-).
3. **Take the provisional path that keeps the door open** — prefer the option
   with the cheapest escape hatch, add the seam if you can (see `/door` step 4).
4. **Ship the rest of the work.** The queue entry is the record that the open
   question was seen, not skipped.
5. **Verdict line:** `ESCALATE: ESC-NNN | <trigger> | queued`

## Burn procedure (`/escalate burn`)

1. Read `## Queue`. If empty, say so and stop.
2. For each entry, adjudicate with the strongest available judge — frontier
   model session or human. Present the full entry; get a ruling and a one-line
   rationale. The provisional answer is scored (right/wrong) — free calibration
   data.
3. Log each ruling: `/verdict log ESCALATE: ESC-NNN | <trigger> | adjudicated — <ruling>`.
4. Move the entry from `## Queue` to `## Adjudicated`, appending the ruling,
   rationale, adjudicator, and date. Never delete — adjudicated entries are the
   precedent store `/precedent` greps.
5. If any provisional answer was wrong AND already shipped, open a follow-up
   task to unwind it; note it in the entry.

## Rules

- Queueing is not punting: an entry without a provisional answer + confidence
  tag is rejected. You must commit to a best guess so the burn can score it.
- One question per entry. A tangle of questions means you haven't isolated the
  judgment call yet — do that first.
- Don't queue two-way doors. If undoing it is cheap, just pick (see `/door`).
- A queue older than one burn cycle with unshipped entries is a smell: either
  burn it or admit the questions didn't matter and close them as such.

## Composes with

- `/door` — trigger (a); one-way doors with no precedent land here instead of
  being decided inline. The disagreement check in /door routes here too.
- `/gate` — trigger (b); borderline results queue rather than round.
- `/drift` — trigger (c); unadjudicatable spec-vs-code conflicts queue here.
- `/calibrate` — trigger (d); and the burn's provisional-vs-ruling scores feed
  the next calibration round.
- `/verdict` — every adjudication is logged there; the queue's Adjudicated
  section is a `/precedent` source.
