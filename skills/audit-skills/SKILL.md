---
name: audit-skills
origin: authored
description: Efficiency audit of a skill library on four measured axes — token cost, ceremony/duplication bloat, trigger-description precision, and overlap clusters — plus usage axes when invocation telemetry exists. Every claim carries a number; findings land as diffs and budgets, not advice. Use before tightening skills, after adding many, or as a periodic library health check.
allowed-tools: Read, Glob, Grep, Bash, Edit, Write
argument-hint: "[--all | --scope name,name,…]"
---

# /audit-skills — A Number or It Didn't Happen

Skills are input tokens paid on every invocation. "This skill feels bloated"
is a claim; this skill replaces it with measurements — and marks what it
cannot measure UNVERIFIED instead of guessing.

## Invocation

```
/audit-skills                       # audit the high-traffic set
/audit-skills --all                 # every skill in the library
```

## Procedure

1. **Measure** (`python3 scripts/audit_skills.py --json out.json` — works on
   any `skills/<name>/SKILL.md` tree): per skill, token estimate, bloat %
   (preamble + cross-skill duplicated boilerplate), trigger-description
   flags, and overlap clusters (shingle Jaccard, no heavy deps).
2. **Fold in usage only if real telemetry exists** (an invocation log).
   Absent that, dead-weight and trigger-precision are reported
   **UNVERIFIED** — fire counts are never invented.
3. **Classify before cutting** — the heuristics lie sometimes:
   dense procedure (big, low ceremony) → keep; deliberate shared blocks →
   keep; extractable payload (verbatim templates, catalogs) → move to
   `references/` with a read-on-demand stub; true overlap → merge.
4. **Bank the result as a budget**: record each audited skill's size + ~10%
   headroom and wire a lint check that fails on re-bloat. Prove the gate:
   append filler, watch it fail, revert.
5. **Refute your own edit** — measure the before/after token delta and run
   the library's full check suite before claiming "tighter, behavior
   unchanged". End with ONE verdict line, logged to the ledger:

```
AUDIT: skills | <n> in scope | <before>→<after> tok | tightened: <list> | UNVERIFIED: <axes or none>
```

## Rules

- Size alone is not bloat; dense forced procedure is the product.
- "Dead" requires a fire count; "overlapping" requires a similarity score AND
  a human-verified same-job read.
- UNVERIFIED axes stay UNVERIFIED until telemetry exists. Re-run then.

## Composes with

- `/refute` — step 5 is a forced refutation of the audit's own claim.
- `/gate` — the per-skill budget is a standing gate.
- `/verdict` — `AUDIT:` lines land in the ledger; the next audit diffs
  against the last.
