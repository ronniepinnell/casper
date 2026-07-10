---
name: calibrate
origin: authored
description: Score how past confidence aged. Samples old tagged claims ([HIGH]/[MED]/[LOW], gate predictions, premortem risks, estimates) and checks them against what actually happened. Use monthly, after a milestone closes, or whenever confidence tags start feeling like decoration.
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[period or scope, e.g. 'last milestone' or 'June']"
---

# /calibrate — Did the Confidence Mean Anything?

A [HIGH] that's right 60% of the time is a [MED] wearing a costume. Models and
people that never see their misses never improve their tags — this skill closes
the loop. It is the difference between having opinions and having a track record.

## Invocation

```
/calibrate                 # score the last ~20 resolvable claims
/calibrate last milestone  # scope to a period
```

## Procedure

1. **Harvest past claims** from wherever they were recorded, newest first,
   until you have 10–20 that are now RESOLVABLE (enough time has passed to
   know the outcome):
   - `.claude/verdicts.log` (`/verdict` ledger) — gates, doors, premortem risks
   - Confidence-tagged statements in decision logs / issue comments
   - Estimates ("small change", "won't affect X", "2× speedup expected")
   - Premortem accepted-risks (did any fire?)

2. **Resolve each one:** RIGHT / WRONG / PARTIAL / UNRESOLVABLE, with one line
   of evidence (commit, incident, measurement). No evidence → UNRESOLVABLE,
   never a charitable RIGHT.

3. **Score by bucket:**
   ```
   [HIGH]  n=7  right 6/7 (86%)   — target: ≥90%
   [MED]   n=9  right 5/9 (56%)   — target: 60–80%
   [LOW]   n=3  right 1/3          — fine, that's what LOW means
   gates:  2 tripped, both real    — thresholds well-placed
   doors:  1 "two-way" turned out one-way  ← the expensive kind of miss
   ```

4. **Extract the systematic error, not the individual misses.** Look for the
   pattern: overconfident in which domain? Estimates skewed which direction,
   by what factor? "Two-way" calls that were secretly one-way? One sentence
   per pattern found.

5. **Land the correction as a mechanism** (this is the whole point):
   - A recurring blind spot → a new check in the relevant domain manual
   - Systematic 3× underestimation → the `/gate` effort-gate multiplier changes
   - Miscalibrated [HIGH]s in domain X → that domain's claims get demoted to
     [MED] until two clean calibration rounds pass
   Log the correction with `/verdict log CALIBRATE: …`.

## Rules

- Never resolve your own fresh claims — only ones old enough that the outcome
  is independent of the resolver's wishes.
- PARTIAL counts as WRONG for [HIGH] claims. HIGH means load-bearing.
- A calibration round that changes nothing (no manual update, no threshold
  move, no demotion) was a report, not a calibration. Say which it was.

## Composes with

- `/verdict` — primary data source, and where corrections get logged.
- `/gate` — estimate-skew findings retune default effort gates.
- Domain manuals (`skills/judgment/domains/`) — blind spots land there as checks.
- `/escalate` — a burn's provisional-vs-ruling scores are input to the next calibration round.
