---
name: merge-train
origin: authored
description: Merge every open PR that is mechanically safe — CI green, approved, mergeable, autonomy label present, no unacknowledged override markers — in base-first order; everything else is reported with the exact fact it is missing. Use at end of week, before a release, or whenever open PRs have piled up. Dry-run by default.
allowed-tools: Read, Grep, Bash
argument-hint: "[--execute] [--target main]"
---

# /merge-train — Merge What's Proven, Report the Rest

"Safe to merge" is a claim, and claims need receipts. This skill reduces the
claim to five mechanical facts and merges only where all five hold. A held PR
is not a failure — its reason line tells a human exactly what to supply
(a review, a label, a green run). No judgment happens at merge time; the
judgment was banked here once.

## The five facts (all must hold)

1. **CI green** — every status check concluded SUCCESS/NEUTRAL/SKIPPED.
2. **Approved** — review decision is APPROVED.
3. **Mergeable** — no conflicts with the target branch.
4. **Autonomy label** — the PR carries `autonomy:green`, applied by a human.
   The label IS the standing approval; the model executing this skill never
   applies it.
5. **Overrides acknowledged** — any `JUDGMENT-OVERRIDE:` marker in the PR body
   is matched by an `override-acked` label.

## Invocation

```
/merge-train              # dry-run: SAFE/HELD report, no merges
/merge-train --execute    # merge the SAFE set, base-first
```

## Procedure

1. Enumerate open PRs (GitHub: `python3 scripts/merge_train.py` ships the
   whole check; other forges: gather the same five facts via their CLI/API).
   **No forge access → every PR is UNVERIFIED**, reported as such — never
   assumed safe.
2. Classify each PR SAFE or HELD; a HELD PR lists every missing fact.
3. On `--execute`: merge the SAFE set in base-first order (PRs targeting the
   default branch before stacked PRs). A merge failure stops the train.
4. Verify after: target-branch CI still green.
5. End with ONE verdict line and log it to the ledger:

```
MERGE-TRAIN: <n> merged (#ids) | <m> HELD (<top missing fact>) | <k> UNVERIFIED | target CI: green|red
```

## Rules

- Never widen the safe set inline. "That red check is flaky" is a judgment
  call — the PR waits for a human, or the check gets fixed. Loosening the
  five facts is a one-way-door decision (/door), not an edit.
- HELD and UNVERIFIED are never silently upgraded.

## Composes with

- `/refute` — how a PR earns its evidence before approval.
- `/gate` — the five facts are a standing gate; the ledger line is its record.
- `/verdict` — `MERGE-TRAIN:` lines land in the append-only ledger, so the
  next train diffs against the last.
