---
name: done
origin: authored
public: true
description: Checkpoint (pop current mode) OR full close-out with /done session.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent
argument-hint: [session]
---

> **Factory mode:** If `CLAUDE_AUTO` is set in the environment, skip these instructions and instead run `./{scripts_dir}/skills/done.sh "$@"` via Bash — the shell script handles autonomous dispatch.


# /done — Checkpoint or Close-Out

Two behaviors depending on argument:

## `/done` (no argument) — Pop Mode

Pops the innermost mode from the stack.
- If in `/meeting` inside `/design` → back to `/design`
- If in `/design` with no outer → exits all modes

## `/done session` — Full Close-Out

Runs the complete session end procedure:

1. **Commit** all remaining changes
2. **Push** feature branch to remote
3. **Create PR** to `develop` using `gh pr create`
4. **Debrief** (auto-selects depth based on change scope)
5. **Doc sync**: Full sweep per `config/doc_mappings.json` + `.agents/reference/knowledge_capture.md`
6. **Update** `{plan_file}` "Current State"
7. **Session-debrief-light** — invoke `Skill("session-debrief-light")` to capture session learnings to MEMORY.md (new feedback/decision/project memories surfaced during the session that aren't already saved)
8. **Ask Operator** if they want to merge (never auto-merge)

See `.agents/reference/session_handoff.md` for full lifecycle rules.

## Team Mode (if CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is set)

Debrief team: {agents.completion_audit} + {agents.spec_audit} + compliance-checker + {agents.code_review} (depth auto-selected).

## Fallback Mode (if env var not set)

Sequential subagent calls for debrief agents.

## Judgment weave (see /judgment)

Before close-out: any completion claim made this session gets a lightweight `/refute` (claim, one executed break-attempt, verdict). Session produced verdicts (DOOR/GATE/PREMORTEM/REFUTE)? → make sure they hit `/verdict log` before the context evaporates — the ledger is what survives the /clear.
