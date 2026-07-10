---
name: code
origin: authored
public: true
description: Build/fix features with test-first development, review, and doc sync.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, AskUserQuestion
argument-hint: [feature or issue description]
---

# /code — Build/Fix Features

Enters CODE mode. Structured implementation with TDD, review, and doc sync.

## What Happens

1. **Load context**: Read `{plan_file}`, relevant specs, `CLAUDE.md` coding rules
2. **Plan**: Enter plan mode, identify files to change, get Operator approval
3. **Implement**: Write tests first, then code, following `.agents/reference/code_modularization.md`
4. **Review**: Launch code-reviewer + compliance-checker agents
5. **Doc sync**: Update docs per `config/doc_mappings.json` mappings
6. **On `/done`**: Commit, verify gates pass

## Team Mode (if CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is set)

Lead Dev + Test Writer + Reviewer + Doc Sync agent.

## Fallback Mode (if env var not set)

Sequential subagent calls:
1. Specialized agent (etl-specialist, dashboard-developer, etc.) for implementation
2. code-reviewer agent for review
3. compliance-checker agent for CLAUDE.md adherence
4. Doc sync in main context

## Gate References

- Gate 2 (pre-commit): Validates any generated prompts
- Gate 3 (honesty): Verifies claims match actual output

## Judgment weave (see /judgment)

- **Bug fixes:** run **`/altitude`** before coding — land the fix at the cause's layer, not the symptom's.
- **Before claiming done:** run **`/refute`** on your own completion claim.
