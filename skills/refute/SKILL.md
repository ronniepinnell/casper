---
name: refute
origin: authored
description: Adversarial claim verification. Before accepting any "it works / it's done / it's fixed" claim, construct the concrete input that would break it and run it. Use before commits, PR creation, closing issues, or whenever a completion claim is made.
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[the claim to refute, e.g. 'the login fix works']"
---

# /refute — Try to Break the Claim

The single highest-leverage quality procedure. Plausible-but-wrong is the default
failure mode of every model and every tired human. This skill converts skepticism
into a forced procedure. Repo-agnostic: works on any project, any language.

## Invocation

```
/refute                          # refute the most recent completion claim in this session
/refute the pagination fix works # refute a specific claim
```

## Procedure (all 5 steps, in order — no skipping)

1. **State the claim precisely.** One sentence, falsifiable. "The fix works" is not
   a claim. "GET /players?page=2 returns rows 51–100 with HTTP 200" is.

2. **Enumerate the ways it could be false.** Minimum 3, each concrete:
   - Wrong input class (empty, null, unicode, huge, negative, concurrent)
   - Wrong environment (fresh clone, missing env var, prod-shaped data volume)
   - Wrong layer (the symptom moved, the root cause didn't)
   - Untested path (error branch, permission denied, timeout)

3. **Pick the strongest refutation and RUN it.** Actual command, actual output.
   Not "this should handle it" — execute. If it can't be executed, say so
   explicitly and downgrade the claim to UNVERIFIED.

4. **Verdict, one of exactly three:**
   - `CONFIRMED` — refutation attempted and failed; paste the command + output as evidence
   - `REFUTED` — found the break; the claim is false, say so plainly, fix or file
   - `UNVERIFIED` — could not execute a real test; the claim stays unproven and must
     be reported as such (never silently upgraded to done)

5. **Record.** The verdict + evidence goes wherever the claim was going: commit
   message (`Evidence:` line), PR body, issue comment. A claim without its verdict
   attached did not happen.

## Rules

- Default posture: the claim is false until step 3 fails to break it.
- One refutation run beats ten paragraphs of reasoning about why it's probably fine.
- If step 2 produces a refutation you can't afford to run (e.g. prod-only), that is
  a finding: name the coverage gap in the verdict.
- Never soften REFUTED. "Mostly works" = REFUTED with details.

### Worked example (real ruling, 2026-07-09 — reproduced as a static transcript)

**Claim:** "the judgment hooks work from a cold clone" (as first shipped).

1. Falsifiable form: in a fresh sandbox with only shipped files, spec-citation
   blocks a protected-path edit (exit 2) and passes an unprotected one (exit 0).
2. Failure candidates: wrong env (cold clone), config not read, glob mismatch.
3. Ran the sandbox matrix with a hand-written config → spec-citation FAILED to
   block: exit 0 where 2 was expected. Before declaring REFUTED, refuted the
   refuter: the test config used invented keys (`protected`/`spec_hint`); the
   shipped keys are `protected_globs`/`specs_hint`.
4. Re-ran against the shipped `judgment.json.example` → block=2, pass=0,
   fire-once marker all green (`hooks/judgment/test.sh`).
5. `CONFIRMED — evidence: sandbox matrix vs shipped example config, all green.`
   The first red was the harness's fault — which is the lesson: refute the
   refutation's setup before trusting a red.

## Composes with

- `/gate` — a kill-gate threshold is a pre-agreed refutation.
- `/premortem` — premortem failure modes are refutation candidates.
- `/altitude` — after a cause-layer fix, refute the original SYMPTOM-layer claim to prove the fix propagated.
- `/drift` — a drift sweep is batch refutation of a spec's claims against the code.
- `/verdict` — REFUTED/SURVIVED outcomes worth remembering get logged there.
- `/sweep` — a sweep's Phase 2 is /refute run adversarially at scale.
- `claim-evidence` hook (hooks/judgment/claim-evidence.sh) — mechanically blocks
  done-claims in commits that carry no evidence; /refute is how you produce it.
