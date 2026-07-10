---
name: wave
origin: authored
public: true
description: Assess current project state and produce (and optionally dispatch) the next N-slot factory run — a wave of parallel `/epic start` prompts with model routing, Operator-gated items flagged, and the critical-path decision surfaced. The repeatable replacement for the manual "give me the next run order by slot with prompts" ask. Use when planning (or launching) the next batch of parallel factory work.
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion, Agent, mcp__claude_ai_Linear__get_issue, mcp__claude_ai_Linear__list_issues, mcp__claude_ai_Linear__list_milestones, mcp__claude_ai_Linear__list_projects, mcp__claude_ai_Linear__get_project, mcp__claude_ai_Linear__save_comment, mcp__plugin_supabase_supabase__get_logs, mcp__plugin_supabase_supabase__get_advisors
argument-hint: "[plan|run|abort] [N] [\"directive / what you want done\"] [--focus cutover|gates|features|db] [--milestone CODE] [--accept-all] [--grill]"
owner: factory
last_verified: 2026-07-08
generator: manual
area: factory
---

> **Factory mode:** if `CLAUDE_AUTO` is set, skip every `AskUserQuestion` and use the documented
> default at each choice; in `run` mode dispatch the wave autonomously (respecting the Operator-gated
> exclusions below) and report, never blocking on input.

> **Tool Map (Gemini/Codex):** task-manager / storage tool-name equivalents across runtimes live
> in `_shared/mcp-tool-map.md`. This skill's Linear/Supabase calls route through the adapter.

# /wave — Next-Wave Run Planner & Launcher

> Sibling of `/deep-dive` (forensic audit) and `/status` (HUD snapshot).
> `/wave` is the ORCHESTRATOR: it reads live ground truth, judges priority
> against the critical path, and emits a **dispatch-ready N-slot run** — each
> slot a self-contained `/epic start {ID}` prompt with a model assignment —
> then, in `run` mode, launches them.

## Modes

| Invocation | What it does |
|---|---|
| `/wave` or `/wave plan` | Assess + emit the N-slot run, and **persist it** to `.claude/.wave-current.json`. **Read-only** otherwise — plans, never dispatches. |
| `/wave run` | Emit the plan, then **dispatch each non-gated slot** via `/epic start`. Stops for Operator approval on the plan first unless `--accept-all` (or `CLAUDE_AUTO`). |
| `/wave run slot {N}` | Dispatch **only slot N** from the persisted plan, at that slot's routed model (see § Model matching). No approval gate — running one named slot IS the approval. Re-derives the plan first if no state file exists. |
| `/wave "<directive>"` | **Directed mode.** Plan around the work the Operator NAMES (a goal/theme/priority), not just tracker-derived critical path. Runs the intake (§ Directed mode) first. Combine with `run` to plan+launch. |
| `/wave --grill` | Force the interactive intake even without a directive — grill → mini-CCB → PM before planning. |
| `/wave abort` | Kill switch: `wave.py abort` marks every pending slot cancelled. In-flight slots keep running (can't un-launch a worker) — reported, not killed. |
| `--accept-all` | Skip the "approve this plan?" gate — dispatch the whole wave immediately. Operator-gated items are STILL excluded (never auto-run destructive/migration/`autonomy:red`). |

**N** defaults to 10 (parallel-slot capacity). `--focus` biases prioritization toward one lane;
`--milestone` scopes to one milestone's ready work. A bare positional string is the **directive**.

## Deterministic helper — `wave.py` (do not eyeball these ops)

Persistence, slot lookup, gated-detection and model resolution run through the co-located helper
(`~/.claude/skills/wave/wave.py`, symlinked from shared-config — available in every repo). The model
MUST use it rather than hand-tracking JSON, so `run slot {N}` is reliable, not a memory act:

```bash
W=~/.claude/skills/wave/wave.py
python3 "$W" save   < plan.json            # persist the wave (Step 3 output → JSON array)
python3 "$W" list                          # summarize the persisted wave (⛔ marks gated)
python3 "$W" slot 3                         # print slot 3 as JSON (+cli_model,is_claude,gated); exit 3=gated, 4=missing
python3 "$W" model opus --current sonnet    # resolve routed→CLI model id, dispatch mode (worker|brief), mismatch
```
State: `$PWD/.claude/.wave-current.json`. `save` validates every slot has a known model + id and
auto-flags gated slots (any `autonomy:red` / destructive / migration / cutover-execute token).
`slot N` **exits 3 for a gated slot** — the dispatcher treats a non-zero gated exit as "refuse,
surface for manual trigger."

## Model matching (mismatch is prevented, not just detected)

A slot carries a routed model; `wave.py model` resolves it. Solve mismatch **by construction**:
- **Dispatch at the routed model.** `run` / `run slot {N}` launches each slot's `/epic start {ID}`
  on a worker set to `slot.model`'s `cli_model` (the `/epic start` model flag or `Agent(model=…)`).
  A fresh worker at the right model → mismatch is impossible.
- **Non-Claude target** (`is_claude:false` → dispatch `brief`): do NOT warn — invoke `/brief` to emit
  the copy-paste briefing for that agent (the same path `/epic start` uses on a model mismatch).
- **Can't set the model** (pinned interactive session, no worker path): THEN warn using the helper's
  `fix` line — "slot N is {model}; you're in {current}. `/model {model}` or dispatch to a worker."
- Always print the resolved model per dispatched slot: `🤖 slot N → {ID} ({cli_model})`.

## Think like — the orchestrator mindset (adopt before Step 1)

- **You are the shift lead, not a reporter.** The deliverable is the *next move*, not a status essay. Every slot must be something a worker can `/epic start` cold and finish.
- **Critical-path obsessed.** Un-run exit gates and any cutover almost always dominate. A feature slot that doesn't move the launch date loses to a gate slot that does.
- **Adversarial about priority, honest about readiness.** Assume the tracker is optimistic. If only 6 things are genuinely unblocked, ship a 6-slot wave — **padding with make-work is the failure mode**, not a short wave.
- **Verify, don't inherit.** Re-check prior claims against live DOM/logs/DB. Screenshot-before-hydration, stale "X is broken", and backwards `blockedBy` reads have all burned this planner before — trust the live pull, not the last summary.
- **Right-size the model to the risk.** Don't put architecture/security/migrations on Sonnet to save cost, or chores on Opus to feel safe.
- **Bank nothing in `plan` mode.** Planning is read-only. `run` mode dispatches, reviews, closes epics, and files issues (below) — but never edits specs directly and never force-merges.

## Rules & conventions (govern EVERY step)

- **Follow ALL repo rules.** This skill runs inside the project's rule system — CLAUDE.md + `rules/BASE.md` + `rules/areas/*`. Non-negotiables it must honor: honesty (never present a failed slot as progress; >2× off target → STOP and say so), **never mark Done/close an epic without proof** (R-49/R-51: merged PR + green checks + evidence), **R-50** (dashboard-surface changes carry a passing Playwright, output shown), **migrations are Operator-gated** (flag + STOP before `safe_db_push.sh`; autonomous runs never push schema), and output discipline. The dispatched `/epic start` workers inherit these; the wave orchestrator must not route around them.
- **Secrets via {secret_manager} for everything.** Every command that touches creds/DB/deploy runs under the project’s secret manager wrapper (see project-context.md).
- **Rule-42: file issues for discovered work.** When a slot (or the state-assessment) uncovers new work — a bug, a gap, a follow-up, a blocker — **file a Linear issue before acting on it**, placed in the CORRECT milestone + parent epic (match the surface: a builder bug → under the builder epic; a stat defect → the stat-integrity workstream; a security finding → the security epic), with a real DoR (Goal · Steps · Acceptance · labels incl. `milestone:*`, `type:*`, `priority:*`). For Operator-directed small chores that don't warrant a full plan, use the audited bypass: `touch .claude/.plan-milestone-active` → create the issue → `rm` it. Never do non-trivial work without a `{task_prefix}-XXXX` first. Newly-filed issues that are themselves dispatchable get appended to the wave via `wave.py save` (re-persist), or surfaced to the next `/wave`.

## Step 0 — load project context (run first)

Read `.claude/project-context.md`. Extract `task_manager`, `task_prefix`, `task_team_id`,
`main_branch`, `storage_backend`, `scripts_dir`, `factory_enabled`. Load the task-manager adapter
`_shared/adapters/{task_manager}.md`; route all task reads through its abstract ops
(`list_issues`, `get_issue`, …). `{ID}` = `{task_prefix}-{n}`. Steps tagged **[factory]** run only
when `factory_enabled: true`.

## Step 0.5 — Directed intake: grill → mini-CCB → PM (directed mode or `--grill` only)

Skip in plain auto mode (then priority = critical path). When the Operator gives a **directive** (or
`--grill`), do NOT just build slots around the literal ask — run a fast intake that turns "what I
want" into a critical-path-aware, outcome-ranked plan. Skip all questions under `CLAUDE_AUTO`.

1. **GRILL (AskUserQuestion, one at a time — only what you can't infer):** the OUTCOME (what's true when this is done, in the live product — R-49, not "PRs merged"); scope IN and explicitly OUT; hard constraints (deadline, demo, don't-touch areas); what "good enough" is vs gold-plating. Stop grilling the moment you have enough to plan — don't interrogate.
2. **MINI-CCB (adversarial, honesty over compliance):** pressure-test the directive against reality. Is this the highest-value work, or does the critical path (un-run gates, cutover, a P0) dominate it? Name the tension out loud: "you asked for X; the launch-blocker is Y — here's the cost of doing X first." Spin ≤2 quick adversarial agents (e.g. `{agents.completion_audit}` for reality, a PM/architect lens) ONLY if the call is genuinely contested; otherwise judge inline. The Operator's directive wins if they hold it after hearing the tension — but they hear it.
3. **PM (outcome ranking):** translate the (possibly-adjusted) directive into an outcome-ranked priority list, reconcile with the tracker's actually-ready work (Step 1), and fold in any newly-required issues (file them per Rule-42). That ranked list REPLACES the default prioritization in Step 3.

Output a 3-line intake summary: **Directive · the tension (if any) · the priority order you'll build.** Then proceed.

## Isolation & non-interference (so parallel slots — and parallel waves — never collide)

Enforce all of these before/while dispatching:
- **Branch + worktree per slot.** Every slot's `/epic start` runs on its own branch; slots that
  MUTATE files in parallel dispatch with `Agent(isolation:"worktree")` (or the factory clone-slot)
  so no two workers share a working tree. Read-only/audit slots don't need a worktree.
- **File-overlap serialization (`touches`).** Each slot declares `touches` (path globs it writes).
  `wave.py next` will NOT hand out a slot whose `touches` overlap a currently-`dispatched` slot —
  it auto-serializes them (holds until the conflicting one merges). Declare `touches` at
  DIRECTORY-glob granularity for shared-file lanes (builder `ui/.../cms/*`, a dbt model dir) so the
  guard actually fires; precise files for independent work.
- **Concurrency cap.** ≤2 builder/UI slots in flight at once (they share registries/routes even when
  `touches` differ); dbt parallel across DISTINCT model dirs; migrations serial. `next` + the cap
  together bound concurrency.
- **Cross-wave lock (no double-dispatch).** The persisted `.claude/.wave-current.json` + a live
  re-verify (Step 4.0) are the single source of "what's in flight." Before dispatch, re-check the
  issue isn't already In-Progress / open-PR from ANOTHER wave or a manual run; if it is,
  `wave.py mark N merged/failed` and skip. Two `/wave run`s can't dispatch the same `{ID}`.

## Step 1 — Assess ground truth (never plan from vibes)

**Pre-flight (optional):** if the tracker hasn't been verified recently (last `/deep-dive` or wave
> a few hours ago, or you suspect it's ahead of reality), run `/deep-dive {milestone} --shallow`
first so the wave is built on audited state, not an optimistic tracker.

Pull and synthesize, parallel where possible (Doppler for anything needing creds):

- **Git / PRs:** `gh pr list --state open` (filter dependabot/Bump/Update-requirement) + `gh pr list --state merged --limit 40` since the last wave. Establish **in flight** (open PR — do NOT re-dispatch) vs **landed**.
- **Milestone %:** `list_milestones` for the active project(s). Note superseded/void milestones and any that share a code (e.g. an old + new cutover milestone with different strategies).
- **DB health (if a DB is in scope):** `get_logs` (postgres) — scan for a rising error class (permission-denied, missing-column drift, dup-key floods, timeouts). `get_advisors` — but interpret: `security_definer_view` / owner-context errors are usually a tracked allowlist, not N vulnerabilities; the live-log error RATE is the real signal, not the advisor count.
- **Exit gates:** whether the milestone's VERIFY-MECH / HARDEN / VERIFY-HUMAN gates have a passing artifact. Un-run gates + cutover are almost always the critical path.
- **Ready-vs-blocked:** confirm each candidate is not Done/Canceled/In-Progress and its blockers are cleared. Check `blockedBy` DIRECTION against ground truth (`X blocks Y` on `relations`, `X blocked-by Y` on `inverseRelations`) — do not trust a tool that reports it backwards.

Output a tight state-of-the-union (≤1 screen): what's done, the critical path, top 3 risks. Correct any stale assumption you find against live data.

## Step 2 — Load routing context

- **Model routing:** Opus for architecture / security / RLS / data-correctness / migrations / R0-harness design; Sonnet for bounded UI / dbt / dashboard / test-mech; Haiku for chores. Reserve deep-work (Fable) for judgment, not slots. Autonomous factory slots run Opus (never the banned 4.7).
- **Banked design:** if the repo has a "design capital banked" note (e.g. CLAUDE.md Fable-routing block pointing at a spec set + exit dossier), do NOT plan re-design for those domains — plan EXECUTION against the existing specs/gates.
- **Concurrency safety:** ≤2 concurrent builder/UI slots (shared route/registry files); dbt work parallel-safe across DISTINCT models; migrations serial + Operator-gated.

## Step 3 — Produce the N-slot run

Prioritize by the Step-0.5 intake ranking if directed, else: **cutover-critical > exit-gate prep >
residual DB/drift cleanup > remaining features > next-domain rungs > perf debt.** Every slot
unblocked + parallel-safe. For each slot also determine `after` (slot#s that must merge first) and
`touches` (path globs it writes — directory-glob granularity for shared-file lanes) so the
persisted plan drives dep-ordering + non-interference.

For EACH slot, emit exactly:

```
Slot N — /epic start {ID}  (MODEL)  · one-line why   [after: …]  [touches: …]
```
```
/epic start {ID}
<self-contained dispatch prompt:
## Required Reading — file §section
## Agents to Call — named agents
## TDD Requirement — RED first; R-50 (Playwright, output shown) on any dashboard-surface change; R-51 (evidence + explicit PASS) for gated issues>
```

Then build the JSON array (`slot, id, model, gated, after, touches, why, prompt`) and persist it:
`python3 ~/.claude/skills/wave/wave.py save < plan.json`.

**Rules for the wave:**
- Every prompt starts with the literal `/epic start {ID}` slash command.
- **Operator-GATED items go in a SEPARATE list, never in the lights-out slots or an `--accept-all` run:** destructive cutover execution, any schema migration (stops for approval before `safe_db_push.sh`), anything `autonomy:red`.
- Flag anything already IN FLIGHT (open PR) so a slot doesn't collide.
- **No make-work.** Fewer than N genuinely-ready items → ship a shorter wave + list the bench with why-blocked.
- Restate per-slot guardrails: migrations stop for Operator; a design-heavy epic stops at an exemplar for review before fan-out; empirical (CV/ML) slots must not fabricate baselines — honest "not measured yet" over a fake GO.

**Persist** the finished plan at the end of Step 3 (all modes): `python3 ~/.claude/skills/wave/wave.py save < plan.json` so `run slot {N}` is deterministic later.

## Step 4 — Dispatch + review-to-merge (`run` and `run slot {N}` only)

Skip entirely in `plan` mode. Otherwise, for each slot **to dispatch** — in `run` iterate via
`wave.py next` (respects `after` deps + status, skips gated); in `run slot {N}` the one named slot:

0. **Re-verify (staleness guard).** Plans go stale in hours — the factory may have already done a
   slot, or a PR may be open. Before launching, re-check LIVE: the issue is still not Done/Canceled/
   In-Progress and has no open PR (adapter `get_issue` + `gh pr list --search {ID}`). If it moved,
   `wave.py mark N merged` (or `failed`) and skip — do not re-dispatch completed work.
1. **Approval:** in `run`, approve the plan (`AskUserQuestion`) unless `--accept-all` / `CLAUDE_AUTO`. In `run slot {N}` naming the slot is the approval.
2. **Refuse gated slots:** `wave.py slot N` exits 3 for a gated target — do NOT dispatch; surface for manual Operator trigger, even when named.
3. **Dispatch via `/epic start` at the routed model** (§ Model matching): factory path if `factory_enabled`, else `Agent(...)` with `model = slot.cli_model`; non-Claude routes go through `/brief`. Then `wave.py mark N dispatched`. Emit `🤖 slot N → /epic start {ID} ({cli_model})`; long runs get `run_in_background: true` + a keepalive.
4. **Review-to-merge (every slot that opens a PR).** Do NOT leave PRs unreviewed:
   - `/pr-review-loop {PR}` — polls CodeRabbit, applies fixes, **up to 3 cycles**, merges when clean + required checks green.
   - **If CodeRabbit is down/unavailable** (no CR review after the poll window, or CR API/bot errors): fall back to **adversarial review** — the `code-reviewer` agent (frame the diff as an external contributor's; review to an explicit PASS), plus `/coderabbitai-review` (CLI, if only the GitHub app is down). Still bounded at 3 cycles; a finding surviving 3 cycles is escalated to the Operator, never force-merged.
   - Never merge on a non-PASS review; never merge a Operator-gated or migration PR autonomously.
5. **Post-merge smoke (outcome, not output — R-49).** Merged ≠ working. After the PR merges, before declaring the slot done, verify the change is real on the affected surface: run the project's smoke gate (the surface-quality predicate / `/verify smoke` / the slot's own Playwright, under Doppler). If it fails → reopen, `wave.py mark N failed`, file a fix issue (Rule-42), do NOT count it as done. This is the "we merged it but is it actually real" guard that screenshot/hydration false-positives kept tripping.
6. **Close the epic.** On a green smoke, run `/epic close {ID}` (lifecycle narrative / receipt / status), then `wave.py mark N merged` — unblocking any slot whose `after` names it. On a slot that FAILS (worker died, review can't reach PASS in 3 cycles, smoke red, blocked mid-run): `wave.py mark N failed`, surface it + file a follow-up issue, and CONTINUE — one bad slot never stalls the others; never silently drop it.
7. **Loop:** in `run`, call `wave.py next` again for the next ready slot (it already honors deps, `touches` conflicts, and gated-skip); respect the ≤2-builder concurrency cap. Stop when `next` reports none ready.
8. [factory] **Telemetry + audit:** record a one-line dispatch/outcome comment on the milestone tracker (`save_comment`), and write a wave-outcome row via storage `write_lifecycle_output` (skill_point='wave', slots × status × review-cycles × smoke) so velocity/escalation history is queryable by the next `/ccb`.
9. Report per slot: dispatched model · review outcome (merged / N cycles / escalated) · smoke · epic-close; then gated/held items and the one critical-path decision. When all non-gated slots are merged, prompt: re-run `/wave` for the next wave.

## Step 5 — Output contract

Emit in the final message:
1. **State-of-the-union** (≤1 screen).
2. **The N-slot run** — per-slot `/epic start` prompt + model + one-line why.
3. **Operator-gated / on-the-bench** list.
4. **The one decision** (if any) only the Operator can make to unblock the critical path.
5. (`run` mode) **What was dispatched** vs held.

## Notes

- Pairs with `/deep-dive` (run first when the tracker looks ahead of reality) and `/pipeline` (fully autonomous multi-milestone execution). `/wave` is the human-in-the-loop planner/launcher between them: one well-scoped parallel batch you can inspect before it runs.
- Best driven by a deep-work model (prioritization under a deadline is judgment-heavy) but works on any tier — `plan` mode is read-only and formulaic in output.
- Re-invoke after each wave lands; the skill is built to run repeatedly as work completes.

## Judgment weave (see /judgment)

- **Before dispatch:** every slot needs numeric abort conditions — author missing ones with **`/gate`**; a wave without gates is an overnight incident generator.
- **At wave close (step 9):** surface the escalation queue — concatenate any `.claude/escalation-queue.md` entries queued during the run into the report, verbatim. Queued escalations are deferred judgment, not noise: a wave that merged every slot but left unburned ESC entries reports **PARTIAL, not failed** (and never a clean pass) until the Operator burns or dismisses them.
