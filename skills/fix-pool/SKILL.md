---
name: fix-pool
origin: authored
description: Findings→fixes pooler for a coordinator session. Polls the task manager for new issues (walkthrough/tester-filed or manual), triages each (auto-fix / investigate / hold-for-operator / duplicate), and dispatches throttled background fix agents that stop at PR. Use when a build-hub session runs alongside human testing slots and new findings should flow into the builder workflow without the operator relaying them. Arm with `/fix-pool arm`, check `/fix-pool status`, stop with `/fix-pool drain`.
allowed-tools: Bash, Read, Agent, TaskList, TaskStop
---

# Fix Pool — findings→fixes pooler

One coordinator session + N human testing slots produce a stream of freshly-filed
issues. This skill turns the coordinator into the drain: poll → triage → dispatch
→ report, on a loop, with hard throttles. Capture stays with the testers (they
have the context); pickup is centralized here (dedup + sequencing live in one
place).

## Invocation

```
/fix-pool arm [--interval 10m] [--max-agents 3] [--since <ISO|now>]
/fix-pool status
/fix-pool drain     # stop polling; let in-flight fix agents finish
```

## Resolve config first

Read the task-manager adapter per `_shared/adapters/{tracker.kind}.md` (resolved
from `.claude/project.yml` / project-context). All issue reads/links go through
the adapter — never a hardcoded API. State file: `.claude/.fix-pool-state.json`
(`last_poll_iso`, `seen_ids[]`, `dispatched{id→agent,pr}`, `held[]`). Not
committed.

## Arm (the loop)

On `arm`, record the baseline timestamp (`--since`, default now) and start a
polling cycle every `--interval` (default 10m) using the session's
wake/scheduling mechanism (background monitor or ScheduleWakeup — whatever the
harness provides; never a foreground sleep).

Each cycle:

1. **Poll** — adapter: issues created since `last_poll_iso` in the configured
   team/project (include tester-session-filed and manually-filed; exclude issues
   this session created itself unless labeled for the pool). **Self-filter is
   mandatory in the poll query or first triage step** — the hub files tickets
   too, and without it the pool re-triages its own output (observed live,
   2026-07-17). Track hub-created ids in the state file and drop them on sight.
   Also drop issues whose domain an ACTIVE sibling workstream owns (e.g. a
   migration terminal's own ledger ticket) — that's a HOLD with a named owner,
   not a dispatch.
2. **Triage each new issue** (read title+body, check `seen_ids`):

   | Verdict | Criteria | Action |
   |---|---|---|
   | `AUTO-FIX` | Clear repro + scope is test-only, docs, or a small UI/logic fix; no schema, no auth/security semantics, no design decision | Dispatch a fix agent (worktree, own branch, PR to the integration branch, **never merges**) |
   | `INVESTIGATE` | Real defect, root cause unclear | Dispatch an investigate agent: repro + root cause + proposed fix posted as an issue comment; fix only if the cause turns out AUTO-FIX-class |
   | `HOLD` | Schema/migration, security posture, product/design decision, or anything one-way-door | Add to `held[]`; surface in the next report; never auto-built |
   | `DUP` | Matches an open issue/known finding | Link via adapter comment; no work |

3. **Throttle** — at most `--max-agents` fix/investigate agents in flight
   (check TaskList); excess stays queued in order. New dispatches only as slots
   free.
4. **Report** — one short message per cycle **only when something changed**:
   new findings by verdict, dispatches started, PRs ready, held items. Silent
   cycles stay silent.

## Hard rules

- **PR-only.** Pool agents never merge. Merges/deploys happen at operator break
  points — a deploy mid-test invalidates the testers' ground truth.
- **No schema pushes, ever.** Migration-class findings are always `HOLD`.
- **Surface mutex.** Never dispatch a fix touching a surface an active testing
  slot is walking (the operator names the active surfaces at arm time, or the
  walkthrough epics define them); queue until that slot completes.
- **Dedup before dispatch.** Two findings, one root cause → one agent, both
  issues linked.
- **Honest triage beats fast triage.** If AUTO-FIX vs HOLD is unclear, it's
  HOLD. A wrong auto-fix during a test session poisons two things at once.

## Drain

`drain`: stop the poll loop, let in-flight agents finish and open their PRs,
emit a final consolidated report: all findings routed, PRs awaiting merge,
held items needing operator rulings. The pool is not drained until every
finding has a disposition.
