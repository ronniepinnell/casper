---
name: validate-completion
origin: authored
public: true
description: Single-task completion verifier. When an implementer claims a task or feature is finished, establish whether the goal was genuinely achieved — by executing it when possible, by rigorous inspection when not. Compiling, existing, or green tests are not proof. Use immediately on any "done" claim, before the status is recorded.
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[task id or claim, e.g. '{task_prefix}-123' or 'the export feature works']"
---

# /validate-completion — Prove One Claim

Thin entry point: this is `/completion-audit --task <id>` — the same audit
scoped to a single claim, kept as its own name because it fires at a different
moment (the instant "done" is declared) and returns a binary approve/reject.
Procedure detail lives in `completion-audit/SKILL.md` steps 2–4; report
format, ruling grammar, severity tiers, JSON trailer, and routing table live
in `_shared/audit-report-contract.md`.

## Invocation

```
/validate-completion {task_prefix}-123        # verify a tracked task's claim
/validate-completion the CSV export works     # verify an ad-hoc claim
```

## Depth modes (state which was used)

**Execution mode** (runnable environment available) — everything in inspection
mode, plus: invoke the feature for real; feed it invalid input and confirm
graceful failure; UI renders with zero console errors; expected DB state
changes happen; trace input → output end-to-end.

**Inspection mode** (no runnable environment) — artifacts exist and are
non-empty; no TODO/FIXME/placeholder markers or empty bodies; imports resolve
to real modules; tests exercise the real code path (not just mocks); no
hardcoded values that should be configurable; the new unit is actually
registered/wired — a file nothing imports is incomplete. Inspection-only
caps the verdict at `inconclusive` if the primary claim couldn't be executed.

## What disqualifies a claim

Mocked/stubbed implementations passed off as complete; tests that pass
regardless of behavior; integrations wired to fake endpoints or hardcoded
responses; silently swallowed errors; missing supporting artifacts (config,
migrations, deps); security/validation shortcuts; orphaned unreachable code.

## Output

- **APPROVE / REJECT** on the claim, with per-claim CONFIRMED/REFUTED/UNVERIFIED
  rulings and executed evidence (adversarial posture: build the breaking input
  first, per /refute).
- Blocking problems (severity + file:line), missing components, non-blocking
  quality concerns, concrete next steps.
- Out-of-scope failures routed per the shared contract's routing table
  (complexity → pragmatism-audit; requirement confusion → spec-audit; rule
  breakage → rules-audit; whole-project reality → completion-audit).
- JSON trailer per the shared contract, and the verdict line logged via `/verdict`:

```
AUDIT: validate-completion | <task id> | <pass|fail|inconclusive> | <blocking>/<total> findings
```

## Judgment weave

- The core of this skill IS `/refute` pointed at one claim — run its 5 steps.
- REJECT verdicts worth remembering → `/verdict`; recurring rejection causes →
  a hook or domain line per `judgment/MANUAL.md` §4.

## Composes with

- `/completion-audit` — the parent audit; this is its `--task` scope.
- `/issue done`, `/epic close` — call this before recording Done.
- `claim-evidence` hook — blocks evidence-free done-claims; this produces the evidence.
