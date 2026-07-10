# Domain Judgment — Process, Focus & Honest Status

> The failure modes here waste more than all the technical ones combined:
> tangents, sunk cost, dishonest status, and ceremony. Checklist + refutation
> form. These are people-and-model rules — both fail the same ways.

## Focus

1. **Ship, don't tangent.** The unit of progress is a merged, verified change —
   not a report, an investigation, or a cleaned-up adjacent mess. A red gate or
   flaky login discovered mid-task is a TICKET, not a detour.
   REFUTE: "is what I'm doing right now on the critical path of the named
   task?" Answer in one sentence. Can't → you're on a tangent; note it, file
   it, return.

2. **Timebox discovery.** Investigation without a deadline becomes a lifestyle.
   REFUTE: before starting a hunt, declare the box ("2 passes / 30 min"). At
   the box's edge: deliver what's clean, file the rest. The box is a `/gate`
   effort-gate — tripping it is a no-fault stop, not a failure.

3. **Throwaway-restart reflex.** The same approach corrected 3+ times means
   the frame is wrong, not the details. Restart from a clean statement of the
   problem; the sunk work was the cost of learning the frame.
   REFUTE (mechanical): count your own retries. At 3, restarting is cheaper
   than persisting — this is empirical, not motivational.

4. **>2× off the estimate → STOP and say so.** Out loud, immediately. "I
   burned the morning on the wrong thing" costs one sentence; the silent
   version costs the rest of the week.

## Honest status (the currency everything else runs on)

5. **Done means demonstrated.** Merged PRs, green tests, and shell files are
   OUTPUT. Done = the outcome shown working where the stakeholder lives.
   Anything less is PARTIAL, and saying PARTIAL is what keeps the word
   "done" worth anything.
   REFUTE: `/refute` the done-claim — what command/demo proves it, run now?

6. **Failed results are reported as failures.** Never as "progress",
   "learnings", or "80% there". The reader must be able to act on your status
   without decoding your optimism.

7. **No hypochondria, no denial.** A normal bug is not a systemic crisis; a
   real crisis is not "a small issue". Read the evidence, size the response
   to it, and be equally ready to say "this is fine" and "this is bad".

8. **The correction is right enough to act on.** When the person who owns the
   outcome says "you're off, go do X" — drop the thread and do X. Defending
   a tangent is a second tangent.

## Ceremony control (process must also pay rent)

9. **Every gate needs a kill count.** Track (even roughly) what each review,
   checklist, and hook actually catches. A gate that hasn't caught anything
   in months is ceremony; delete it or sharpen it. `/calibrate` is where this
   gets adjudicated.

10. **Approval steps only where doors are one-way.** Two-way-door work flows
    without asking (see `/door`). If everything requires sign-off, the
    sign-offs protect nothing — attention is a budget, spend it at the doors.

11. **When a catalog/spec names things the tree doesn't have, the doc is
    lying.** Fix the doc AND add the mechanical check so the class can't
    recur — a skill catalog once listed deleted skills until a rows-exist
    CI gate landed with the fix (see `/drift`'s worked example).

12. **Decisions decay into folklore unless written.** "Why do we do it this
    way?" answered with a shrug means the constraint is now unquestionable
    AND unverifiable — the worst combination. Log to `/verdict`; folklore
    with a date and a reason can be re-examined when the world changes.

## The meta-rule

Every process failure that actually bites gets converted into a mechanism —
a hook, a gate, a checklist line here — within a day of being understood
(conversion guide: `../MANUAL.md §4`). Process improvements that live in
retro notes are retro theater.

## Composes with

- `/gate` — timeboxes and estimate-gates are effort gates.
- `/refute` — the done-claim test.
- `/calibrate` — ceremony kill-counts and estimate skew.
- scope-creep hook — rule 1, mechanized.
