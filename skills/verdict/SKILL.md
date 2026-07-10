---
name: verdict
origin: authored
description: Append-only judgment ledger. Every DOOR / GATE / PREMORTEM / REFUTE / DRIFT verdict line gets logged to one grep-able file so "show me every gate we overrode" is a query, not archaeology. Use whenever a judgment skill produces a verdict, and to query past verdicts.
allowed-tools: Read, Glob, Grep, Bash, Write
argument-hint: "log <verdict line> | show [n] | grep <pattern> | stats"
---

# /verdict — The Judgment Ledger

Decisions evaporate; ledgers compound. Every verdict the judgment skills produce
is one line here. Six months later the ledger answers: what did we lock in, what
did we override, what did we accept, and who signed it.

## Invocation

```
/verdict log DOOR: one-way | locked: uuid pks | escape: full remap | gate: join p95
/verdict show 20          # last 20 verdicts
/verdict grep GATE        # all gate verdicts (or any pattern)
/verdict stats            # counts by type, overrides, accepted risks
```

## Ledger location & format

File: `.claude/verdicts.log` in the project (create on first log; add to the
repo, NOT gitignore — the ledger is the point). One line per verdict:

```
2026-07-09 | DOOR | one-way | locked: uuid pks | escape: full remap | by: operator
2026-07-09 | GATE | TRIPPED p95=340ms>200ms | on-fail: STOP executed | by: claude
2026-07-10 | GATE | OVERRIDE 200→400ms | reason: cold cache accepted | by: operator
2026-07-11 | REFUTE | REFUTED "search works" | broke on: unicode names | by: claude
```

Fields: `date | TYPE | verdict | detail… | by: <who>`. TYPE is one of
DOOR, GATE, PREMORTEM, REFUTE, DRIFT, ALTITUDE. Overrides and risk-acceptances
MUST name a human in `by:` — a model cannot accept risk on anyone's behalf.

## Procedure

- **log** — append the line verbatim (plus date + by). Never edit or delete
  prior lines; corrections are new lines referencing the old.
- **show / grep** — read and filter; render as-is.
- **stats** — counts per TYPE, number of GATE OVERRIDE lines, number of
  PREMORTEM accepted-risks, oldest unresolved one-way door. Flag anything
  suspicious plainly (e.g. "4 gate overrides in 2 weeks, all same gate —
  the threshold is wrong or the gate is being gamed").

## Rules

- A verdict not logged is a verdict that didn't happen. The judgment skills
  end by calling this.
- The ledger is append-only. History that can be rewritten is not history.
- If a project keeps decisions elsewhere (e.g. a decisions DB), log there TOO,
  but the flat file stays — it survives every infra migration.

## Composes with

- Every judgment skill (`/door /gate /premortem /refute /drift /altitude /think /sweep`) —
  they emit, this records.
- `/calibrate` — reads this ledger to score how past confidence aged.
- `/precedent` — greps this ledger as its primary store of prior rulings.
- `/escalate` — every queue adjudication lands here; the ledger feeds future precedent.
