---
name: design
origin: authored
public: true
description: Interactive design session. Agent team debates architecture, captures decisions, logs ideas.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, AskUserQuestion
argument-hint: [topic]
---

# /design — Interactive Design Session

Enters DESIGN mode. Operator drives the conversation, Claude facilitates with domain experts.

## What Happens

1. **Load context**: Read `{plan_file}` "Current State", relevant specs, load recent decisions via storage `list_decisions`
2. **Identify domain**: Match topic against `.claude/agents/AGENTS_GUIDE.md` routing table
3. **Facilitate debate**: Present trade-offs, ask Operator for decisions, challenge assumptions
4. **Capture continuously**: Decisions → storage `record_decision`, Ideas → storage `record_idea`
5. **On `/done`**: Run content pipeline (see `.agents/reference/knowledge_capture.md`)

## Team Mode (if CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is set)

Lead + Spec Writer + Idea Logger + Domain Expert(s) from routing table.
Teammates debate each other, not just report to lead.

## Fallback Mode (if env var not set)

Sequential subagent calls:
1. Domain expert agent(s) for research/analysis
2. Main context facilitates Operator discussion
3. Spec writer agent for doc updates at end

## Mode Rules

- Explicit entry only — Operator invokes `/design`
- Nests: `/meeting` or `/quick` can run inside `/design`
- `/done` pops back to outer mode (or exits if no outer)
- `/done session` clears entire stack + runs close-out

## Gate References

- Gate 1 (pre-push): Ensures design artifacts sync to specs
- Gate 2 (pre-commit): Validates prompt quality if prompts generated

## Judgment weave (see /judgment)

- Diverge phase: `/think` moves are the debate fuel — assign different agents different moves (one runs invert, one base-rate, one analogy) instead of N agents free-associating.
- Converge phase: every surviving option through `/door`; one-way doors get the five questions in the room.
- Exit: chosen design gets `/premortem` + `/gate` lines; all decisions → `/verdict log` (in addition to any project decision store).
