# Domain Judgment — ML & Computer Vision

> The ladder + kill-gates pattern, generalized. Every model project climbs the
> same rungs, and each rung has a mechanical stop. Skipping rungs is how teams
> spend three months shipping something worse than a lookup table.

## The ladder (climb in order; each rung gates the next)

```
R0  Predict the mean / majority class / persistence ("same as last time")
R1  One obvious feature + linear/logistic model
R2  Sensible features + boosted trees (or the boring standard for the modality)
R3  The fancy thing you actually wanted to build
R4+ The fancy thing, tuned
```

**GATE (universal): R(n) must beat R(n-1) on the SAME eval, or STOP.**
A fancy model losing to persistence is not "promising, needs tuning" —
it's evidence the signal isn't where you think it is. The gate is
`new < baseline → STOP`, numerically, no adjectives.

## Kill-gates every ML plan declares before training

- `GATE: eval-metric | R(n) ≤ R(n-1) | same split, same metric | on-fail: STOP`
- `GATE: reproducibility | rerun differs > atol (e.g. 1e-5) | rerun twice | on-fail: fix seed/pipeline before ANY result is believed`
- `GATE: eval-integrity | any test-set example findable in train | hash-overlap check | on-fail: rebuild splits, discard all prior numbers`
- `GATE: effort | > 2× estimate at checkpoint | honest check | on-fail: STOP + report`

## Leakage & eval hygiene (the sins that fake success)

1. **Split by entity and time, not by row.** Random row splits leak identity:
   the same player/user/scene lands in both sides.
   REFUTE: check the split key. If it isn't (entity, time-boundary), assume
   the metric is inflated and re-split.
2. **Target leakage via features.** Features computed over windows that
   include the label moment.
   REFUTE: per feature, write when it's knowable (same discipline as stats #7).
3. **Metric matches the decision.** Accuracy on imbalanced classes, AUC when
   you act at one threshold, mAP when you care about one class — all lies of
   emphasis. REFUTE: state the downstream decision; pick the metric that prices
   ITS errors (per-class recall at the operating point beats global anything).
4. **Train/serve skew.** The eval preprocessing and the production
   preprocessing are different code paths.
   REFUTE: run the SERVING path on the eval set. Any delta is skew, and skew
   found in prod costs 100× more.
5. **Slice before you ship.** Aggregate metrics hide the group where it fails.
   REFUTE: evaluate on the 3–5 slices that matter (per class, per condition,
   per camera, per cohort). Ship-blocking if any critical slice is broken,
   whatever the average says.

## CV-specific judgment

- **Track identity errors are the product.** Detection mAP can be high while
  ID-switches make the tracks useless downstream. Measure IDF1/ID-switches,
  not just detection metrics, whenever tracks feed analytics.
- **Calibration is a dated artifact.** Homographies and camera calibrations
  drift (bumped cameras, re-mounts, zoom). Every calibration carries a date
  and a reprojection-error check; stale calibration is silent data corruption.
- **Test the ugly frames.** Occlusion, motion blur, lens edge, lighting
  changes, look-alike entities (same jersey, same color). The demo reel is
  drawn from the easy 80%; the product lives or dies in the hard 20%.
  REFUTE: build the hard-case eval set explicitly and report it separately.
- **Coordinates need ground truth.** If XY positions feed analytics, validate
  mapped coordinates against measured reality (known landmarks, rink/field
  markings), not against "looks right on the overlay".

## Reporting rules

- Every result names its rung and its baseline delta: "R3 beats R2 by 4.1 pts
  (metric M, split S)". A result without a baseline delta is not a result.
- Failed rungs are reported as plainly as passed ones. "R3 lost to R1" saves
  the next person a month.
- Model cards state: split scheme, leakage checks run, slices evaluated,
  calibration date (CV), and every gate verdict → `/verdict log`.

## Composes with

- `/gate` — the ladder gates are authored there, pre-training.
- `/refute` — hard-case slices are the standing refutation set.
- `domains/stats.md` — all of it applies; ML is statistics with more knobs.
