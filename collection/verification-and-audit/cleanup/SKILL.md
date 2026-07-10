---
name: cleanup
origin: authored
public: true
description: Mass reconciliation when things are out of whack. Audit, triage, fix, verify.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, AskUserQuestion
argument-hint: [scope: docs|code|all]
---

# /cleanup — Mass Reconciliation

For when docs, specs, phase tables, or code are out of sync. Audit everything, triage, fix.

## What Happens

1. **Audit**: Run parallel agents to check:
   - Doc staleness (config/doc_mappings.json)
   - Phase table completeness (captured ideas via storage `list_ideas` → plan rows)
   - Spec coverage (features in specs → phase table rows)
   - Code-spec drift (decision-store entries via storage `list_decisions` → actual code)
   - Dead references (links to files that don't exist)
2. **Triage**: Present findings to Operator with severity (P0/P1/P2)
3. **Generate fix prompts**: Through Gate 2 for validation
4. **Execute**: Fix issues (with Operator approval for P0s)
5. **Verify**: Re-run audit to confirm fixes

## Team Mode (if CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is set)

Audit team: {agents.completion_audit} + {agents.spec_audit} + compliance-checker + {agents.doc_sync} agents in parallel.

## Fallback Mode (if env var not set)

Sequential subagent calls: {agents.completion_audit} → {agents.spec_audit} → compliance-checker → {agents.doc_sync}.

## Gate References

- All fix prompts go through Gate 2 (pre-commit)
- All pushes go through Gate 1 (pre-push content pipeline)

## Judgment weave (see /judgment)

- **Audit phase:** big messes are **`/sweep`** jobs — fan out rather than spot-check.
- **"All clean" claim:** run **`/refute`** before declaring the reconciliation done.
