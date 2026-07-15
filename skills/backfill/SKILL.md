---
name: backfill
origin: authored
description: Retroactively grade merged PRs against the claim-evidence discipline — which done-claims shipped with evidence, which shipped unproven. Zero-LLM (gh CLI); optionally seeds the verdicts ledger with UNVERIFIED BACKFILL rows. Use when adopting the toolkit on a repo with history, before trusting old "done"s, or to measure how the discipline is trending.
allowed-tools: Bash, Read, Grep
argument-hint: "[--repo owner/name] [--since YYYY-MM-DD] [--limit 100] [--ledger .claude/verdicts.log]"
---

# /backfill — Grade the Dones You Already Shipped

The gates protect the next hundred PRs; history is where the false-dones you
can already feel came from. This runs the claim-evidence check retroactively:
every merged PR is graded EVIDENCED / UNEVIDENCED / NO-CLAIM, mechanically.

## Invocation

```
/backfill                                  # last 100 merged PRs, current repo
/backfill --since 2026-01-01 --ledger .claude/verdicts.log   # window, not the whole history
/backfill --limit 300                                            # hard cap either way
```

## Procedure

1. Run `python3 <toolkit>/scripts/backfill.py [--repo …] [--since DATE] [--limit N]`
   — on a repo with thousands of PRs, ALWAYS pass `--since` (server-side
   filter); grade a window and widen only if the baseline needs it.
   (same claim words and evidence paths as the claim-evidence hook: an
   `Evidence:` line in the body, or test files in the diff).
2. Read the UNEVIDENCED list — those are the PRs whose "done" was asserted,
   never proven. Spot-check the worst 3 against reality (the layer rule:
   observe the deployed behavior, not the diff).
3. With `--ledger`, the summary + each UNEVIDENCED PR land as append-only
   `BACKFILL | UNVERIFIED` rows — history can be graded, not re-run, so
   retro rows are never CONFIRMED/REFUTED.
4. The score is the baseline: re-run monthly; the trend is the report.
   ```
   BACKFILL: <repo> | <n> merged PRs | <c> done-claims | <e> evidenced (p%) | <u> shipped unproven
   ```

## Rules

- Report, never a gate — exit 0 always. The gate is the claim-evidence hook
  you install so the next PRs grade better.
- Retro rows are UNVERIFIED by construction; upgrading one requires actually
  re-verifying the claim today (that's a /refute, logged separately).

## Composes with

- claim-evidence hook — the forward-looking half of the same check.
- `/refute` — how an UNEVIDENCED PR's claim gets actually tested today.
- `/calibrate` — the monthly trend of the backfill score.
- `/verdict` — the ledger the `--ledger` flag writes to.
