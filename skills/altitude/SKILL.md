---
name: altitude
origin: authored
description: Right-layer check before coding a fix. Locates which layer a problem actually lives at (data model, storage, API, business logic, UI, process/people) so the fix lands at the cause's layer, not the symptom's. Use before fixing any bug, and whenever the same bug keeps coming back.
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[the problem, e.g. 'player names render blank on the roster page']"
---

# /altitude — Fix at the Layer Where the Problem Lives

Most bad fixes are correct code at the wrong altitude: a UI null-check papering
over a broken join, an API retry papering over a data race, a cron job papering
over a missing constraint. The symptom's layer is where you SEE the problem;
it is usually not where the problem IS.

## Invocation

```
/altitude roster page shows blank names
/altitude                               # triage the bug currently under discussion
```

## The ladder (top = where symptoms appear, bottom = where causes live)

```
L6  Process / people      (who does what, when; missing ownership, missing review)
L5  UI / presentation     (rendering, formatting, client state)
L4  API / transport       (endpoints, contracts, serialization, authz)
L3  Business logic        (rules, calculations, workflows)
L2  Data model / schema   (shapes, constraints, invariants, migrations)
L1  Storage / infra       (DB engine, network, deploy, environment)
```

## Procedure

1. **Name the symptom's layer.** Where was the problem observed? (Usually L4–L6.)

2. **Descend with "what would make this impossible?"** At each layer below the
   symptom, ask: is there a change HERE that would make this whole class of bug
   unrepresentable? A NOT NULL constraint beats a null-check in 40 components.
   A typed API contract beats defensive parsing in every consumer.

3. **Stop at the lowest layer where the cause is real** — not the lowest layer
   that exists. Descending too far is also a failure mode (rewriting the schema
   for a typo-level bug). Test: can you state the defect at that layer in one
   sentence without referencing the layers above it? If yes, that's the layer.

4. **Declare the altitude call, then fix:**
   `ALTITUDE: symptom at L5, cause at L2 (missing FK) — fixing at L2, plus L5 guard`
   - Fix at the cause layer.
   - A thin guard at the symptom layer is acceptable ONLY as defense-in-depth,
     never as the fix, and never silently — name it as a guard.

5. **Recurring-bug override:** the same bug fixed 2+ times is conclusive proof
   the previous fixes were above the cause. The next fix MUST go at least one
   layer lower, or explain in writing why it can't.

## Rules

- "Where is it cheapest to patch?" is the wrong question. "Where does the
  invariant belong?" is the right one.
- One-sentence-per-layer discipline: if the descent takes paragraphs, you're
  investigating, not triaging — go gather facts and come back.
- L6 is a real answer. Some bugs are a missing gate/review/owner, and code at
  any layer will only mask that.

## Composes with

- `/drift` — repeated drift at one spot is an altitude smell.
- `/premortem` — premortems catch wrong-altitude designs before they ship.
- `/refute` — refute the fix at the SYMPTOM layer after fixing at the cause
  layer (proves the fix actually propagated up).
- `/think` — /altitude is `decompose` specialized for bugs; /think covers the open field.
- `/verdict` — layer verdicts worth remembering are logged there.
- `/sweep` — sweeps use altitude thinking to dedup findings into systemic causes.
