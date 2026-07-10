---
name: premortem
origin: authored
description: Write the incident report before shipping. Assume the work shipped and failed 3 months from now; write the post-mortem first, then harden the top risks. Use before locking a design, launching a feature, running a migration, or dispatching autonomous work.
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[what is about to ship, e.g. 'the new onboarding flow']"
---

# /premortem — It Already Failed. Write the Report.

Prospection is weak; hindsight is strong. The trick is to fake hindsight:
declare the failure as an accomplished fact, and the failure modes people
couldn't "imagine" become obvious. Ten minutes here routinely deletes the
worst week of the next quarter.

## Invocation

```
/premortem the pgvector search migration
/premortem                                # premortem the plan currently under discussion
```

## Procedure

1. **Set the scene, in past tense, as fact:**
   "It is 3 months from now. <X> shipped. It failed badly enough that we rolled
   it back / lost the customer / spent a week firefighting."

2. **Write 5–8 causes of death.** Each one concrete and past-tense — "the
   migration locked the events table for 40 minutes at peak", not "performance
   issues". Force coverage across categories; at least one from each:
   - **Data** — bad/missing/dirty data, volume 100× the test set, migration loss
   - **Integration** — the dependency that behaved differently than its docs
   - **Human** — misuse, misunderstanding, the user who clicked the other button
   - **Scale/time** — worked at demo size, died at real size; the slow leak
   - **Assumption** — the thing everyone "knew" that was false

3. **Score each cause:** likelihood (H/M/L) × blast radius (H/M/L).

4. **For every H×H and H×M, do one of exactly three things, now:**
   - **Redesign** — change the plan so this death can't happen
   - **Gate it** — hand it to `/gate`: metric, threshold, checkpoint, on-fail
   - **Accept it** — in writing, with the owner's name on the acceptance
   Anything else ("we'll be careful") is not a mitigation.

5. **Output block** (goes in the plan/PR/issue):
   ```
   PREMORTEM: <X>
   deaths: <n> | hardened: <n redesigned + n gated> | accepted: <n, by whom>
   top risk: <one line> → <what changed because of it>
   ```

## Rules

- Past tense is mandatory. "Could fail because" reopens the door to optimism;
  "failed because" keeps it shut.
- If the premortem finds nothing scary, the scene wasn't set hard enough —
  raise the stakes ("we lost the biggest customer") and rerun once.
- Timebox: 10–20 minutes. A premortem that becomes a design review lost its job.

## Composes with

- `/door` — mandatory before walking through any one-way door.
- `/gate` — step 4's "gate it" outputs land there.
- `/refute` — after shipping, the top causes of death are the first refutations
  to run against "it works".
- `/altitude` — premortems catch wrong-altitude designs before they ship.
- `/think` — /premortem is `invert` specialized for shipping; /think covers the open field.
- `/verdict` — top causes of death and their mitigations are logged there.
