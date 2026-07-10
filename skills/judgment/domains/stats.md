# Domain Judgment — Statistics & Analytics

> Checklist form: each item is a CHECK plus the REFUTATION that tests it.
> Run the relevant items before trusting any statistical claim — yours or
> anyone's. Phrased for any model to execute against real data.

## Before believing any metric or finding

1. **Baseline first.** No number means anything alone.
   REFUTE: compute the dumbest baseline (mean, last-year, coin flip). If the
   fancy result doesn't clearly beat it, the finding is the baseline.

2. **Effect size over significance.** p<0.05 with a trivial effect is noise
   with paperwork.
   REFUTE: state the effect in domain units ("0.3 goals/season") and ask the
   domain question: would anyone change a decision over that?

3. **Sample size at the grain of the claim.** 50k events can be 12 players.
   REFUTE: count N at the unit the claim is about. Under ~30, say "anecdote".
   Report N in the same sentence as the finding, always.

4. **Multiple comparisons.** Testing 40 stats and reporting the 2 that "hit"
   is p-hacking regardless of intent.
   REFUTE: count how many things were tested (including informal looks).
   Apply that denominator; a finding that survives Bonferroni-ish scrutiny or
   replicates on a holdout period is real, otherwise it's a hypothesis.

5. **Selection & survivorship.** Who is missing from the data?
   REFUTE: describe the unit that would NOT appear (injured players, churned
   users, canceled games, deleted rows). If the missing units correlate with
   the outcome, the estimate is bent — say which direction.

6. **Simpson's check.** Aggregates reverse under grouping shockingly often.
   REFUTE: recompute the headline number split by the 1–2 most obvious
   confounders (team, season, level, cohort). If any split reverses the sign,
   the aggregate claim is dead.

7. **Leakage of the future.** Any feature computed with information from
   after the moment of prediction.
   REFUTE: for each input, write the timestamp when it becomes knowable.
   Anything knowable only after the target event is leakage, full stop.

8. **Denominator integrity.** Rates change meaning when the denominator
   quietly changes (per-game vs per-60 vs per-possession).
   REFUTE: state the denominator out loud and check it's constant across the
   entities being compared.

9. **Regression to the mean.** Extremes revert; "improvement" after a bad
   stretch is often just physics.
   REFUTE: check whether the selected group was selected FOR extremeness.
   If yes, compare against expected reversion, not against zero.

10. **Uncertainty travels with the number.** A point estimate without a range
    is a confidence trick.
    REFUTE: bootstrap or at minimum eyeball the spread. If the interval spans
    "great" and "terrible", the honest answer is "can't tell yet".

## Reporting rules

- Lead with effect size + N + uncertainty. Significance last, if at all.
- "We found no effect" is a publishable, valuable sentence. Use it.
- Every finding states its refutation attempt: what was tried to kill it
  (holdout period, confounder split, permutation) and survived.
- A finding nobody would act on is trivia. Say what decision it changes.

## Composes with

- `/refute` — items above ARE the refutation menu for stats claims.
- `/gate` — pre-register thresholds before running the analysis, or the
  threshold will drift toward whatever the data shows.
