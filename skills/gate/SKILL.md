---
name: gate
origin: authored
description: Numeric kill-gate authoring. No plan, experiment, or migration is accepted without a measurable abort condition — what's measured, what threshold, what happens on fail. Use at plan time, before long-running work, and when adjudicating "is this good enough to continue".
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[the plan or work item to gate]"
---

# /gate — No Plan Without a Kill Condition

"We'll see how it goes" is how three-week tangents happen. A kill-gate is a
pre-agreed, mechanical stop: numbers decided BEFORE the work, so the decision to
abort doesn't depend on the judgment (or sunk-cost bias) of whoever is executing.

## Invocation

```
/gate migrate search to pgvector      # author gates for a plan
/gate                                 # gate the plan currently under discussion
/gate check                           # adjudicate: measure current state against declared gates
```

## Authoring procedure (before work starts)

For the plan, write 1–3 gates. Each gate is one line with four mandatory parts:

```
GATE: <metric> | <threshold> | <measured how + when> | on-fail: <action>
```

- **Metric** — a number obtainable by running a command. Not "quality", not "feels
  fast". Latency ms, error count, test pass rate, rows matched, diff size, $ cost.
- **Threshold** — the abort line, with direction. `p95 > 200ms`, `accuracy < baseline`,
  `> 2× the estimate` (schedule/effort gates are legitimate).
- **Measured how + when** — the exact command/query and the checkpoint ("after first
  batch", "at 25% rollout", "after 2 hours of work").
- **On-fail** — one of: `STOP + report` (default), `rollback`, `escalate to <person>`,
  `fall back to <alternative>`. "Investigate further" is not an on-fail action.

Universal gates worth defaulting to:
- `GATE: new-vs-baseline | new < baseline | run both, compare | on-fail: STOP` —
  a replacement that underperforms what it replaces stops immediately.
- `GATE: effort | > 2× estimate | honest check at checkpoint | on-fail: STOP + report`

## Adjudication procedure (`/gate check`)

1. Locate the declared gates (plan doc, issue body, PR description).
2. Run each gate's measurement command. Paste real output.
3. Verdict per gate: `PASS <value>` or `TRIPPED <value> → executing on-fail`.
4. A tripped gate is executed, not argued with. Overriding a gate requires the
   person who owns the plan to say so explicitly, in writing, with the new number.
   Silent threshold-moving is the failure the gate exists to prevent.

## Rules

- A gate you can't measure with a command is a wish, not a gate. Rewrite it.
- Borderline result (within ~10% of threshold) = report both the number and the
  ambiguity; don't round in your own favor.
- Gates protect the executor too: a tripped gate is a no-fault stop.

### Worked example (real ruling, 2026-07-09 — reproduced as a static transcript)

**Plan:** repo CI + hygiene pass. Gate authored before the work:

```
GATE: coupling-lint warnings | > 0 | lint script in CI, every push | on-fail: STOP + fix to 0
```

Adjudication when it fired:
1. Lint ran on the PR → `TRIPPED: 14 warnings → executing on-fail`.
2. Work stopped; no "close enough", no threshold-moving. Each warning fixed
   until the command printed 0.
3. The honest-scoping move: one skill genuinely coupled to one project and
   couldn't be decoupled inside this PR — so it got a declared
   `project_scope` marker (which the lint respects), not a fake
   fix. Scoping a warning honestly is allowed; silently muting it is the
   failure the gate exists to prevent.
4. Merged only at `PASS 0`.

## Composes with

- `/door` — every one-way door exits with a gate.
- `/refute` — a gate is a standing refutation with a pre-agreed threshold.
- `/premortem` — top premortem risks become gates with thresholds.
- `scope-creep` hook — is exactly this pattern applied to files-touched.
- `/verdict` — gate authorings and adjudications are logged there.
- `/calibrate` — estimate-skew findings feed back into default gate thresholds.
- `/escalate` — borderline results (within ~10% of threshold) queue there rather than round.
- `/sweep` — sweeps run on gate budgets and set recurrence tripwires here.
