---
name: rules-audit
origin: authored
public: true
description: Project-rules enforcer. Reviews recent changes strictly against the binding instructions in CLAUDE.md (and any project rule checklist), flagging every deviation with the exact rule cited and a concrete fix. Deliberately narrow — conformance only, not general code quality. Use after any code change and before commit.
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[files/area to check, default: recent changes]"
---

# /rules-audit — Did the Change Break a House Rule?

CLAUDE.md rules exist because something already burned this project once.
This audit checks recent changes against them and nothing else: it does not
judge style, architecture, or cleverness — only documented constraints, which
outrank every other consideration (including specs).

Report format, ruling grammar, severity tiers, JSON trailer, degradation
rules, and routing table: see `_shared/audit-report-contract.md`.

## Invocation

```
/rules-audit                        # audit the working tree / recent commits
/rules-audit src/etl/               # audit an explicit area
```

## Procedure

1. **Load the authorities.** Project CLAUDE.md (and user/global rule files it
   defers to), plus any project-specific checklist of banned and required
   patterns referenced there (e.g. `.claude/` rule docs).
2. **Enumerate the changes.** `git diff` / `git status` for changed and
   created files; explicit list if given. Record what was examined.
3. **Check every rule against every change.** Typical rule families: banned
   constructs (with their explicitly-allowed alternatives — do NOT flag
   those); mandatory calculation/attribution semantics; required key/schema
   patterns on new tables (respect stated exemptions); branch-naming and
   environment-pointing constraints (dev vs prod identifiers in config);
   unsolicited documentation-file creation; commit-message format;
   client-side aggregation, shared in-process state, blocking IO in render
   paths, oversized files, schema changes without migrations, app-generated
   sequential keys. The rule file's own list is authoritative — this list is
   illustrative.
4. **Rule per rule:** pass, or violation with the rule quoted (rule-file
   file:line), how the change breaches it (code file:line), a concrete
   remediation, a severity tier, and a CONFIRMED/REFUTED/UNVERIFIED ruling
   backed by command or citation.
5. **Escalate patterns, not just instances.** The same rule violated
   repeatedly is a signal the rule, tooling, or layer is wrong — say so and
   route to `/altitude` or `/escalate` instead of re-flagging forever.
6. **Report:** changes examined, per-rule pass/fail, violations
   most-severe-first, what was done in conformance, JSON trailer, verdict
   line logged via `/verdict`:

```
AUDIT: rules-audit | <scope> | <pass|fail|inconclusive> | <blocking>/<total> findings
```

## Rules

- False positives destroy trust: an explicitly-permitted alternative to a
  banned pattern is a pass, full stop.
- Scope creep beyond what was asked is a finding even when the extra code is good.
- Out-of-scope findings route per the shared table (fix needs functional
  proof → validate-completion; fix adds complexity → pragmatism-audit;
  rule/spec collision → spec-audit, rules win).

## Judgment weave

- Every violation is a candidate for MANUAL §4 conversion: if a regex could
  have caught it, propose a hook (default-OFF), not another prose warning.
- Repeat-offender rules → `/calibrate` will show them; adjudications →
  `/verdict`; genuinely ambiguous rule readings → `/escalate`.

## Composes with

- `/completion-audit` — consumes this unit's trailer at session scope.
- `/spec-audit` — same engine, spec authority; this unit's authority wins conflicts.
- `scope-creep` + `spec-citation` hooks — the mechanical, edit-time slice of this audit.
- `/commit`, `/issue done` — invoke this first.
