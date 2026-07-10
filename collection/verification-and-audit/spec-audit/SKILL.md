---
name: spec-audit
origin: authored
public: true
description: Code-vs-spec comparator. Reads the source first-hand and compares it against written specification documents, classifying every divergence as absent, partial, wrong, or extra — with file:line on both sides and an explicit call on which artifact should change. Project rules (CLAUDE.md) outrank specs. Use before PRs, after spec'd feature work, or when spec drift is suspected.
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[spec file(s) or feature name] [files/area to compare]"
---

# /spec-audit — Does the Code Match the Spec?

Second-hand summaries lie in both directions. This audit reads the actual
code and the actual spec, then reports exactly where they disagree and which
side is wrong — it never silently picks a winner.

Report format, ruling grammar, severity tiers, JSON trailer, degradation
rules, and routing table: see `_shared/audit-report-contract.md`. Task refs
via the task-manager adapter (`{task_prefix}-###`).

## Invocation

```
/spec-audit specs/export.md src/export/    # explicit spec + code area
/spec-audit csv-export                     # feature name → resolve to specs + changed files
```

## Procedure

1. **Load the authorities.** The spec document(s), and the project rule file
   (CLAUDE.md). Precedence: rules > spec. A rule/spec conflict is itself a
   finding, resolved in the rules' favor.
2. **Decompose the spec into checkable requirements.** One falsifiable line
   each, with spec file:line.
3. **Read the implementation first-hand.** The changed files, plus whatever
   they wire into. Grep for each requirement's footprint; run behavior checks
   where executable.
4. **Classify every divergence** on the defect-kind axis:
   - `ABSENT` — required behavior in the spec, not in the code
   - `PARTIAL` — started, presented as complete, isn't
   - `WRONG` — implemented contradicting the spec's stated behavior
   - `EXTRA` — built but never specified (scope creep or stale spec)
   Each carries a severity tier, spec-side file:line AND code-side file:line,
   and a per-requirement ruling (CONFIRMED match / REFUTED divergence /
   UNVERIFIED).
5. **Adjudicate each divergence:** state explicitly whether the spec or the
   code should change, and the proposed fix. `EXTRA` findings check drift in
   both directions — a stale spec is a spec bug, not a code bug.
6. **Report:** conformance summary, findings most-severe-first, JSON trailer,
   verdict line logged via `/verdict`:

```
AUDIT: spec-audit | <spec vs area> | <pass|fail|inconclusive> | <blocking>/<total> findings
```

## Rules

- Never rule from a summary, changelog, or PR description — code only.
- A requirement you couldn't trace is UNVERIFIED, not assumed present.
- Out-of-scope findings route per the shared table (rule breach →
  rules-audit; spec-mandated complexity worth challenging → pragmatism-audit;
  functional proof needed → validate-completion).

## Judgment weave

- A full spec-audit is `/drift` with adjudication: batch refutation of a
  spec's claims against the code.
- WRONG-vs-stale-spec calls that feel borderline → `/escalate`; adjudicated
  ones → `/precedent` for next time; all verdicts → `/verdict`.
- `spec-citation` hook enforces spec references at edit time; this audit is
  the after-the-fact sweep of the same failure class.

## Composes with

- `/completion-audit` — consumes this unit's trailer at session scope.
- `/drift` — lighter spec-vs-code sweep without adjudication.
- `/rules-audit` — same comparison engine, different authority (rule file).
- `/gate` — repeated drift in one spec area earns a standing gate.
