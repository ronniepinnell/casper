---
name: drift
origin: authored
description: Spec vs code-as-built diff. Compares what a spec/doc/contract declares against what the code and live system actually do, and reports which one is lying. Use when behavior surprises you, before building on a spec, or as a periodic honesty sweep.
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "<spec file or topic> [code path]"
---

# /drift — Which One Is Lying, the Spec or the Code?

Specs rot silently. Code drifts silently. Everything built on the wrong one
inherits the lie. This skill is a focused comparison, not a rewrite session —
cheap models do this well precisely because the procedure tells them exactly
what to compare.

## Invocation

```
/drift {spec_dir}/AUTH_SPEC.md src/auth/    # spec vs implementation
/drift pagination                            # find the governing doc, then compare
```

## Procedure

1. **Fix the two sides.** Side A = the declared truth (spec, README, API doc,
   schema doc, config comment). Side B = the built truth (code, migrations, live
   behavior). If multiple docs claim the same territory, note the conflict — that
   is already a finding.

2. **Extract testable claims from Side A.** Go claim by claim, not vibe by vibe.
   A claim is testable if a grep, a file read, or a command can confirm it:
   endpoints listed, fields and types, defaults, error codes, invariants
   ("one row per event"), sequences ("X runs before Y").

3. **Verify each claim against Side B.** Actual grep/read/run per claim. Three
   outcomes only:
   - `MATCH` — spec and code agree
   - `DRIFT` — they disagree (quote both sides: spec line + code file:line)
   - `UNVERIFIABLE` — claim too vague to test (that's a spec defect; report it)

4. **For every DRIFT, name the liar.** One of:
   - **Spec is stale** — code moved on legitimately → fix: update the spec
   - **Code is wrong** — spec is the intent, code violates it → fix: file a bug
   - **Ambiguous** — can't tell which is authoritative → fix: escalate; someone
     must own the call. Never pick silently.

5. **Report.** A table: claim | verdict | evidence | liar | fix. End with the one
   number that matters: N claims, M drifted. If M/N > ~20%, say plainly that the
   spec can't currently be trusted as a foundation.

## Rules

- Read the spec FIRST, code second. Reading code first contaminates you with
  code-as-intent, and you'll rationalize the drift away.
- Do not fix drift inline while sweeping — sweeping and fixing are different
  altitudes; log fixes, finish the sweep, then fix.
- "The spec doesn't mention it" is a finding (coverage gap), not a MATCH.

### Worked example (real ruling, 2026-07-09 — reproduced as a static transcript)

**Sides:** Side A = the repo's catalog doc (declared skill roster). Side B = the `skills/` tree.

1. Extracted claims: each catalog row asserts "a skill of this name exists here".
2. Verified row by row against the tree: several rows had no matching
   directory — deleted skills and overlay-only skills still listed as present.
3. Verdict per row: DRIFT (doc names it, tree lacks it).
4. Named the liar: **the doc** — the tree had legitimately moved on; the
   catalog never followed.
5. Fix landed at the doc layer, plus a mechanical check so the CLASS can't
   recur: dropped the dead rows, marked overlay-only rows as such, and added
   a CI rows-exist check (overlay rows exempt).

`DRIFT: catalog vs skills/ | liar: spec (stale) | fix: doc + CI gate`

## Composes with

- `/refute` — each spec claim is a claim to refute against the code.
- `spec-citation` hook — forces reading the spec before editing protected paths,
  which is drift prevention at write time; /drift is drift detection after the fact.
- `/altitude` — a DRIFT whose fix keeps recurring is usually a wrong-layer problem.
- `/verdict` — DRIFT/MATCH findings worth remembering are logged there.
- `/escalate` — spec-vs-code conflicts you can't adjudicate queue there.
- `/sweep` — a sweep's spec-drift dimension is /drift fanned out across the repo.
