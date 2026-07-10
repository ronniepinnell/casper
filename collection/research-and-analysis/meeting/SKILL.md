---
name: meeting
origin: authored
public: true
description: Context-aware meeting with auto-selected domain experts who debate.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, AskUserQuestion
argument-hint: [topic or council name]
---

# /meeting — Context-Aware Meeting

Convenes domain experts for debate. Auto-selects participants from routing table.

## What Happens

1. **Identify domain**: Match topic against `.claude/agents/AGENTS_GUIDE.md` routing table
2. **Convene experts**: Launch relevant agents who debate each other
3. **Operator moderates**: Present findings, Operator asks questions and makes decisions
4. **Capture**: Decisions → storage `record_decision`, Ideas → storage `record_idea`
5. **On `/done`**: Pop back to outer mode

## Team Mode (if CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is set)

Auto-assembled team from routing table. Teammates debate each other directly.

## Fallback Mode (if env var not set)

Sequential subagent calls to domain expert agents. Main context synthesizes perspectives.

## Existing Council Mappings

- Hockey topics → hockey agent files in `.claude/agents/`
- Architecture → talk-architecture, architect-reviewer
- QA → talk-qa, {agents.completion_audit}, {agents.spec_audit}
- Product → talk-product, product-manager
- Security → talk-security, security-auditor
- See `.claude/agents/AGENTS_GUIDE.md` for full routing

## Judgment weave (see /judgment)

- **When the experts agree too fast:** run **`/think`** — unanimous panels are the ones that miss things. Log the meeting's decision with **`/verdict`**.
