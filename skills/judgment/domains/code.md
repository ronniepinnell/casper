# Domain Judgment — Code & Architecture

> The judgment layer above linters and reviewers: where should logic live,
> what makes change cheap, which complexity is load-bearing. Checklist +
> refutation form, same as the other domains.

## Placement (most bugs are correct code in the wrong place)

1. **Invariants live at the lowest layer that can enforce them.** A NOT NULL
   constraint beats null-checks in 40 components; a typed contract beats
   defensive parsing in every consumer. (Full ladder: `/altitude`.)
   REFUTE: for any guard you're writing, ask "what single lower-layer change
   makes this guard unnecessary everywhere?" If it exists and is feasible,
   the guard is the wrong fix.

2. **One owner per fact.** Every piece of knowledge (a threshold, a format,
   a mapping) has exactly one authoritative home; everything else derives.
   REFUTE: grep for the literal. Found in 2+ places → extract before it
   diverges, because it will diverge.

3. **Boundaries fail fast; interiors trust.** Validate at the edge (API,
   file ingest, user input), then let the interior assume validity. Sprinkling
   validation everywhere means it's reliable nowhere.
   REFUTE: trace one bad input from entry. Where does it die? If the answer
   is "deep inside, with a confusing error", the boundary is missing its job.

## Complexity (the budget is real even though it's invisible)

4. **Complexity must pay rent.** Abstractions, config options, generality —
   each is a loan against every future reader.
   REFUTE: for each layer of indirection, name the SECOND concrete use case
   (today's, not hypothetical). No second case → inline it. The rule of three
   exists because the first abstraction is usually drawn around the wrong axis.

5. **Boring beats clever at 3am.** The metric is time-to-understand for the
   next person, under incident pressure.
   REFUTE: can the on-call engineer who didn't write it predict what this
   code does from its name and shape? Cleverness that fails this test is debt.

6. **Delete is a feature.** Dead code, commented code, unused flags, and
   "might need it later" paths all cost reading time forever.
   REFUTE: "when was this last executed?" If nobody can answer, it's dead;
   version control remembers so the codebase doesn't have to.

## Change safety (make wrong states impossible, not unlikely)

7. **Make illegal states unrepresentable.** Prefer types/schemas/enums that
   can't express the invalid case over runtime checks that catch it sometimes.
   REFUTE: enumerate the states the data structure CAN express; any state
   the business logic considers impossible but the structure allows will
   eventually occur.

8. **Migrations are one-way doors** (see `/door`): dropped columns, changed
   semantics, and reused names are unrecoverable or worse — silently wrong.
   REFUTE: write the rollback BEFORE the migration. Can't write it? You're
   walking through a one-way door; treat it as one.

9. **A red test refutes the test setup first.** Verify the harness against the
   shipped example config before believing the failure — the hooks' first
   sandbox red was invented config keys, not broken hooks (see `/refute`'s
   worked example).
   REFUTE: diff your test's inputs against the shipped example/fixture; only
   a red that survives that diff indicts the code.

10. **The blast radius question.** Before any change: what's the worst thing
   this can break, and would we find out from a test, a monitor, or a customer?
   "A customer" is an answer that demands a test or monitor first.

## Review lenses (run as separate passes, not one blended skim)

- **Correctness:** trace the unhappy paths — error branches, empty inputs,
  concurrency. The happy path was already tested by the author's demo.
- **Placement:** is each piece of logic at its `/altitude`-correct layer?
- **Simplicity:** what could be deleted from this diff with no behavior change?
- **Contract:** does this change any promise other code relies on? (Search
  the callers; don't trust the diff's locality.)
- **Tomorrow:** what does this make harder to change next? One-way-door smells
  (new public API, new stored format, new name in the wild) get flagged.

## Composes with

- `/altitude` — placement decisions, mechanized.
- `/door` — migrations, public APIs, stored formats.
- `/refute` — every review lens above ends in an executable refutation.
- claim-evidence hook — "works" claims in commits need the receipts.
