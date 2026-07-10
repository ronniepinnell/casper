# /wave — Operator Manual

> Operator-facing manual. The agent-facing spec is `SKILL.md`; the deterministic helper is `wave.py`.
> `/wave` is the shift lead: it reads live ground truth (git/PRs, Linear, DB health, exit gates),
> judges priority against the critical path, and emits a dispatch-ready N-slot factory run.

## When to reach for it
- "What should the next batch of parallel work be?" → `/wave`
- "Plan the next run focused on X" → `/wave "get cutover done"` or `/wave --focus gates`
- "Launch the plan" → `/wave run` (or `run slot 3` for a single slot)
- After each wave lands, run it again — it is built to be invoked repeatedly.

## Cheat sheet
| You type | What happens |
|---|---|
| `/wave` | Assess + emit the 10-slot plan. Read-only. Persists to `.claude/.wave-current.json`. |
| `/wave 6` | Same, capped at 6 slots. Short honest waves beat padded ones. |
| `/wave "directive"` | Directed mode: grill → mini-CCB → PM intake first, then plan around YOUR goal. |
| `/wave --focus cutover` | Bias prioritization to one lane (cutover/gates/features/db). |
| `/wave --milestone CUT002A` | Scope to one milestone's ready work. |
| `/wave run` | Plan, ask approval, then dispatch every non-gated slot via /epic start. |
| `/wave run --accept-all` | Skip the approval question. Operator-gated slots are STILL excluded. |
| `/wave run slot 3` | Dispatch only slot 3 from the persisted plan, at its routed model. |
| `/wave abort` | Mark pending slots cancelled. In-flight workers keep running (reported). |

## What a slot looks like
Every slot is a self-contained `/epic start BEN-XXXX` prompt with Required Reading, Agents to
Call, and a TDD requirement (RED first, R-50 Playwright where a dashboard surface changes,
R-51 evidence for gated issues) — a factory worker can run it cold.

## What it will NEVER do
- Dispatch destructive/cutover-execution/migration-push/`autonomy:red` work — those are listed
  separately as **Operator-gated** and wait for you, even under `--accept-all`.
- Pad the wave. Fewer than N ready items → shorter wave + a bench list with why-blocked.
- Trust the tracker blindly — it re-verifies claims against live logs/DB/DOM before planning.

## Reading the output
1. **State-of-the-union** (≤1 screen): what landed, the critical path, top 3 risks.
2. **The N slots**: `/epic start` prompt + model + one-line why (+ `after:`/`touches:` guards).
3. **Operator-gated / bench**: what needs you, what's blocked and why.
4. **The one decision**: the single call only you can make to unblock the critical path.

## Recipes
- Nightly batch: `/wave run --accept-all` before signing off; read the report over coffee.
- Pre-launch crunch: `/wave "everything blocking launch" --focus gates` then `run`.
- Suspicious tracker: run `/deep-dive <milestone> --shallow` first, then `/wave`.
- One hot task: `/wave` (plan), then `/wave run slot 1`.

## Guardrails baked in
≤2 concurrent builder/UI slots · dbt parallel only across distinct models · migrations serial +
Operator-gated · slots with overlapping `touches` auto-serialize · re-verifies an issue isn't already
in flight before dispatch (no double-dispatch across waves) · merged ≠ done: post-merge smoke
gates every slot's completion (R-49).
