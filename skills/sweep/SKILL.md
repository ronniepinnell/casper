---
name: sweep
origin: authored
description: Massive multi-agent audit sweep — the generalized FAB-project pattern. Fans out parallel domain auditors over a whole system (codebase, data stack, spec tree, product surface), adversarially verifies findings, and converges to a graded report where every finding lands as a ticket, gate, or patch. Use for "audit everything", pre-launch reviews, post-chaos reconciliation, or grading a stack against best-in-class.
allowed-tools: Read, Glob, Grep, Bash, Agent, Workflow, Write
argument-hint: "<scope> [--dimensions d1,d2,…] [--grade] (e.g. 'data stack --grade', 'docs/specs vs src')"
---

# /sweep — The Full-System Audit Fan-Out

The pattern behind every high-yield mega-audit (21-agent data audits,
FAB-style architecture maps, exit dossiers): **decompose into dimensions →
independent parallel auditors → adversarial verification → graded synthesis →
every finding becomes a mechanism.** One agent can't hold a system; a swept
fan-out can. This skill is the repeatable harness.

Siblings (if your workflow has them): a per-object forensic review skill goes
deep on ONE planning object against its claims; a cleanup skill is fix-first
reconciliation. `/sweep` is breadth-first discovery across a whole system —
it FEEDS both.

## Invocation

```
/sweep data stack --grade            # full-stack audit, scored vs best-in-class
/sweep ui/dashboard                  # product-surface sweep
/sweep docs/specs vs src --drift     # spec-vs-reality sweep (mass /drift)
/sweep security                      # one dimension, full depth
```

## Phase 0 — Scope & dimension slate (inline, before any fan-out)

1. Fix the boundary: what's IN the sweep (paths, schemas, surfaces) and what's
   explicitly OUT. An unbounded sweep never converges.
2. Pick dimensions — default slate, prune/extend per scope:
   - **correctness** (does it do what it claims) · **spec-drift** (mass `/drift`)
   - **security/permissions** · **performance/scale** · **data quality**
   - **test coverage** (real tests, not shells) · **architecture/placement**
     (`/altitude` violations, duplicated owners) · **honesty** (claimed-done
     vs actually-done — the completion-audit dimension) · **UX/product** (if user-facing)
3. Declare the sweep's own gates (`/gate`): effort ceiling, and a finding
   budget ("if >N criticals in dimension X, stop sweeping and start fixing").

## Phase 1 — Fan-out (parallel, one auditor per dimension)

Dispatch independent subagents/workflow stages, one per dimension. Each
auditor's prompt MUST carry a handoff contract:

- the dimension's question, the scope boundary, where to look first
- **evidence format:** every finding = one line of `file:line` / query / output
  proof — no vibes, no "seems like"
- **severity grammar:** Critical (wrong results / data loss / security) ·
  High (will bite soon) · Medium (debt) · Low (polish)
- return findings as structured list, not prose

Auditors are blind to each other — convergent findings from independent
auditors are the strongest signal a sweep produces. Note them explicitly.

## Phase 2 — Adversarial verification (the step lazy sweeps skip)

Raw findings lie. Before synthesis:
1. Dedup across dimensions (same root cause surfaces in many coats — use
   `/altitude` to name the shared layer).
2. Every Critical/High gets a `/refute` pass by a verifier that did NOT find
   it: reproduce it or kill it. Verdicts: CONFIRMED / REFUTED / PLAUSIBLE.
3. Only CONFIRMED findings may use the word "broken" in the report.
   PLAUSIBLE ships in an appendix, clearly labeled.

## Phase 3 — Graded synthesis

One report, led by the number that matters:
```
SWEEP: <scope> | <n> dimensions | X confirmed (C/H/M/L: a/b/c/d) | grade: B-
```
- If `--grade`: score each dimension 1–5 against the best-in-class benchmark
  for its domain, WITH evidence per score. The grade's job is honesty, not
  motivation — a B- that's real beats an A that isn't.
- Convergent findings and systemic patterns first (three dimensions hitting
  the same subsystem = an `/altitude` problem, not three bugs).
- The "what's NOT broken" section is mandatory — a sweep that only lists
  problems can't be used to decide what's safe to build on.

## Phase 4 — Findings become mechanisms (or the sweep was theater)

Every confirmed finding lands as exactly one of:
- **patch** (fixed in the sweep's follow-up PRs, smallest first)
- **ticket** (filed with the evidence line attached, severity mapped)
- **gate** (a tripwire/CI check so the class can't recur — preferred for
  anything that recurred)
- **accepted risk** (`/verdict log`, named human on the acceptance)

Close by logging the sweep itself: `/verdict log SWEEP: <scope> | grade |
top systemic finding | date`. The next sweep of the same scope starts by
diffing against this line — grades that don't move are the real report.

## Rules

- Breadth-first, fix-later. Auditors that stop to fix lose coverage; the
  single exception is a Critical actively corrupting data — stop the sweep,
  raise it immediately.
- Cap the fan-out to what the finding budget can absorb. 21 agents producing
  400 findings nobody triages is worse than 6 producing 40 that all land.
- Sweeps are periodic, not heroic: the value compounds when grade N+1 is
  compared against grade N.

## Composes with

- `/drift` (the spec-drift dimension), `/refute` (Phase 2), `/altitude`
  (dedup + systemic naming), `/gate` (sweep budgets + recurrence tripwires),
  `/verdict` (the sweep ledger line). If your workflow has a per-object
  deep-review or planning-review step, a sweep is its strongest input.
