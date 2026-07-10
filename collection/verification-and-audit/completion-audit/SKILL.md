---
name: completion-audit
origin: authored
public: true
description: Session/project-scope reality audit. Independently establishes how much of the claimed-done work is genuinely functional, cross-checked against every planning source, and produces a prioritized remediation plan. Use before committing or closing issues, when statuses say done but the system misbehaves, or whenever an honest project snapshot is needed. Supports --task <id> for single-task scope.
allowed-tools: Read, Glob, Grep, Bash, Agent
argument-hint: "[session summary | PR # | task list] [--task <id>]"
---

# /completion-audit — Claimed vs Real

"Marked Done" is a claim, not a fact. This audit treats every completion claim
as false until an executed check fails to break it, then prices the difference
between claimed and real as a remediation plan. Right-sized is the target:
happy-path-only work is incomplete; gold-plating that misses the actual need
is also incomplete.

Report format, ruling grammar (CONFIRMED/REFUTED/UNVERIFIED), severity tiers,
JSON trailer, degradation rules, and routing table: see
`_shared/audit-report-contract.md`. Task state via the task-manager adapter
(`{task_prefix}-###`); decisions via the storage adapter.

## Invocation

```
/completion-audit                     # audit this session's claimed work
/completion-audit PR #42              # audit a PR's claims
/completion-audit --task {task_prefix}-123   # single-task scope = validate-completion's job
```

`--task <id>` narrows scope to one claim and runs only steps 2–4; that scoped
mode IS `/validate-completion` (which is a thin alias for it).

## Procedure

1. **Collect the claims.** Session summary, PR description, task statuses via
   the adapter. One falsifiable sentence per claim — vague claims get rewritten
   before they get audited.
2. **Cross-check every planning source.** Plan doc, tracker, spec files,
   original prompt/brief, roadmap, decision log. A claim contradicted by any
   source is a finding; contradictions BETWEEN sources are findings too.
3. **Rule on each claim via /refute's procedure.** Construct the break most
   likely to succeed and run it. Delegate narrow checks where they belong
   (per-claim execution → `{agents.validate_completion}`; spec conformance →
   `{agents.spec_audit}`; rule breaches → `{agents.rules_audit}`;
   over-engineering → `{agents.pragmatism_audit}`) and reconcile their
   trailers — a delegate `fail` can't sit under an overall `pass`.
4. **Catch the classic false-completes:** works only under ideal conditions;
   code that exists but is never wired/reachable end-to-end; missing error
   handling that makes it unusable; over-abstraction posing as done work;
   fragility posing as MVP scope; missing basics excused as "design choice".
5. **Price the gap.** For each REFUTED/UNVERIFIED claim: severity tier,
   file:line, evidence, and a remediation item with a testable definition of
   done, dependency order, and honest effort framing.
6. **Report.** What actually works (plainly), the gap list (most severe first),
   the remediation plan, process recommendations to prevent recurrence, the
   JSON trailer, and the verdict line logged via `/verdict`:

```
AUDIT: completion-audit | <scope> | <pass|fail|inconclusive> | <blocking>/<total> findings
```

## Rules

- Never average: one S0 finding means the session is not done, regardless of
  how many claims CONFIRMED.
- "Couldn't run it" is UNVERIFIED, reported as such — not a pass.
- The remediation plan must be executable by someone with no session context.

## Judgment weave

- Each claim ruling runs `/refute` (this skill is /refute applied at scale).
- Gaps found repeatedly across sessions → author a hook or checklist line per
  `judgment/MANUAL.md` §4; a lesson not banked evaporates.
- Verdict line → `/verdict` ledger; scoring later via `/calibrate`.
- Borderline pass/fail calls → `/escalate`, don't round in your own favor.

## Composes with

- `/validate-completion` — the `--task` scope of this skill, as its own entry point.
- `/spec-audit`, `/rules-audit`, `/pragmatism-audit` — delegated narrow checks (routing table in the shared contract).
- `/epic close`, `/milestone close`, `/ccb` — invoke this before accepting Done.
- `claim-evidence` hook — mechanically demands the evidence this audit produces.
