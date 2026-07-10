---
name: pipeline
origin: authored
public: true
description: Autonomous pipeline orchestrator — runs one or more milestones end-to-end by composing ccb, plan-milestone, milestone, epic, and issue skills sequentially. Replaces manual session handoffs with automated dispatch. Use for overnight runs or batch milestone execution.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, Agent, mcp__claude_ai_Linear__get_issue, mcp__claude_ai_Linear__list_issues, mcp__claude_ai_Linear__list_teams, mcp__claude_ai_Linear__list_issue_labels, mcp__claude_ai_Linear__list_issue_statuses, mcp__claude_ai_Linear__save_issue, mcp__claude_ai_Linear__save_comment, mcp__claude_ai_Linear__list_comments, mcp__claude_ai_Linear__save_milestone, mcp__claude_ai_Linear__list_milestones, mcp__claude_ai_Linear__list_projects, mcp__claude_ai_Linear__get_project, mcp__claude_ai_Linear__save_project, mcp__claude_ai_Supabase__execute_sql
argument-hint: [plan|run] {CODE###X|{ID}} [{CODE###X|{ID}} ...] [--skip-ccb]
---

> **Factory mode:** If `CLAUDE_AUTO` is set in the environment, skip these instructions and instead run `{scripts_dir}/skills/pipeline.sh "$@"` via Bash — the shell script handles autonomous dispatch.

> **Tool Map (Gemini/Codex):** See `.claude/skills/_shared/mcp-tool-map.md` for task-manager/storage tool-name equivalents across runtimes.

# Pipeline — Autonomous Milestone Orchestrator

## Step 0 — load project context (run first)

Read `.claude/project-context.md` for `task_manager`, `task_prefix`, `task_team_id`,
`main_branch`, `storage_backend`, `scripts_dir`, `factory_enabled`. Load the task-manager
adapter `_shared/adapters/{task_manager}.md` and storage backend
`_shared/storage/{storage_backend}.md`; route all task-manager and memory actions through
their abstract operations. `{ID}` = `{task_prefix}-{n}`.

> **Factory orchestrator.** `/pipeline` is autonomous, multi-session orchestration — it is
> inherently a **factory** capability. It runs end-to-end only when `factory_enabled: true`
> (session logging, machine routing, auto-merge gates). With it off, prefer running the composed
> lifecycle skills (`/milestone`, `/epic`, `/issue`) interactively. The session-log writes below
> are no-ops under `storage_backend: none`.

> **Composes:** `/ccb`, `/plan-milestone`, `/milestone`, `/epic`, `/issue`, `/iterate-pr`, `/coderabbitai-autofix`
>
> Runs one or more milestones end-to-end without manual session handoffs.
> Each epic gets its own branch, PR, CodeRabbit review cycle, and auto-merge.
> Failures are flagged and skipped — the pipeline continues to the next epic.

## Subcommands

| Command | Purpose |
|---------|---------|
| `/pipeline plan M0005A M0005B` | Plan only — ensure all milestones have epics/tasks in Linear, show execution diagram |
| `/pipeline run M0005A M0005B` | Full execution — plan (if needed) + start + work + close each milestone sequentially |
| `/pipeline run {task_prefix}-1234 {task_prefix}-1235` | Epic mode — run specific epics (start → work → close) without milestone lifecycle |
| `/pipeline run M0005A --skip-ccb` | Skip CCB audit phase, go straight to milestone start (use when CCB already ran) |

---

## Argument Detection

The pipeline auto-detects whether arguments are **milestones** or **epics**:

| Pattern | Detected As | Example |
|---------|-------------|---------|
| `M` + digits + letter(s) | Milestone code | `M0005A`, `FCT003E`, `DAT004B` |
| `{task_prefix}-` + digits | epic issue | `{ID}` (e.g. Acme `APP-1234`) |

**Milestone mode** (default): runs the full lifecycle — plan → milestone start → all epics → milestone close.

**Epic mode**: skips milestone start/close entirely. Runs each epic through the epic start → work tasks → epic close cycle sequentially. Useful when:
- You want to run specific epics from different milestones
- The milestone is already open and you just need to execute certain epics
- You're re-running skipped or paused epics after fixing issues

**You cannot mix milestones and epics in the same invocation.** Use one or the other.

### Epic Mode Differences

| Behavior | Milestone Mode | Epic Mode |
|----------|---------------|-----------|
| `qa.factory_session_log` | Pipeline + milestone rows | Pipeline row only |
| Milestone start/close | ✓ Runs | ✗ Skipped |
| `qa.milestone_outcomes` | ✓ Written | ✗ Skipped |
| completion-audit + spec-audit audits | ✓ At milestone close | ✗ Skipped |
| CLEANUP epic | ✓ Created at close | ✗ Not created (skipped epics get labels only) |
| Dependency checking | Within milestone | Across all provided epics + Linear `blockedBy` |
| Plan if missing | `/plan-milestone` | ✗ Error — epics must exist in Linear already |

---

## Overview: What the Pipeline Does

```
/pipeline run M0005A M0005B
  │
  ├─ For each milestone (SEQUENTIAL):
  │   │
  │   ├─ Phase 1: PLAN
  │   │   ├─ Check Linear for epics/tasks
  │   │   └─ If missing → /plan-milestone {M}
  │   │
  │   ├─ Phase 2: START
  │   │   └─ /milestone start {M}
  │   │       → qa.factory_session_log row
  │   │       → Load task plans, show execution diagram
  │   │
  │   ├─ Phase 3: EXECUTE (for each epic, topo-sorted by blockedBy)
  │   │   ├─ If epic has no tasks → /plan-milestone scoped to epic
  │   │   ├─ /epic start {E} → branch, Linear → In Progress
  │   │   ├─ For each task (dependency order):
  │   │   │   ├─ /issue start {T} → read plan, work steps
  │   │   │   ├─ Checkpoint commits (≥3 files rule)
  │   │   │   └─ /issue done {T} → commit, mark Done
  │   │   ├─ /epic close {E}:
  │   │   │   ├─ Create PR → develop
  │   │   │   ├─ CodeRabbit review → fix loop (max 3 cycles)
  │   │   │   ├─ If CR green → AUTO-MERGE (pipeline downgrade)
  │   │   │   ├─ If CR fails 3x → label blocked:cr-review, SKIP
  │   │   │   ├─ Post-merge: doc-sync + rules-audit agents
  │   │   │   └─ Write qa.reviewer_feedback, qa.epic_outcomes
  │   │   └─ Next epic...
  │   │
  │   ├─ Phase 4: CLOSE
  │   │   └─ /milestone close {M}
  │   │       → completion-audit + spec-audit audits
  │   │       → CLEANUP epic created
  │   │       → qa.milestone_outcomes written
  │   │
  │   └─ Next milestone...
  │
  └─ DONE — Final summary report
```

---

## `/pipeline plan {CODE###X} [CODE###X ...]` — Plan Only

For each milestone argument (sequential):

### Step 1: Check Linear for Existing Plans

```
list_issues({ query: "{CODE###X}" })
```

Filter for issues with label `epic` AND label containing `milestone:{CODE###X}`.

Count epics and their child tasks.

### Step 2: Plan if Missing

**If 0 epics found:**

The milestone has no plan. Run `/plan-milestone`:

```
Skill(skill: "plan-milestone", args: "{CODE###X}")
```

This creates all epics, tasks, dependencies, test scaffolds, and `qa.task_plans` rows in Linear.

**If epics exist but any have 0 child tasks:**

Run `/plan-milestone` scoped to fill in missing tasks:

```
Skill(skill: "plan-milestone", args: "{CODE###X} --fill-empty-epics")
```

**If epics AND tasks exist:**

Print confirmation and move on:
```
✓ {CODE###X} — {epic_count} epics, {task_count} tasks already planned
```

### Step 3: Show Execution Diagram

For each milestone, print the same execution diagram as `/milestone start` Step 5 — epics in topo-sorted order with status, deps, and task counts. This lets the Operator review the full run scope before committing.

### Step 4: Summary

```
PIPELINE PLAN COMPLETE
━━━━━━━━━━━━━━━━━━━━━━

  Milestone    Epics    Tasks    Status
  ──────────── ──────── ──────── ────────────
  {CODE###X}   {n}      {n}      ✓ Ready
  {CODE###X}   {n}      {n}      ✓ Ready (planned this session)
  {CODE###X}   {n}      {n}      ⚠ Partial (2 epics have no tasks)

Total: {N} milestones | {N} epics | {N} tasks

To execute: /pipeline run {CODE###X} {CODE###X} --skip-ccb
```

---

## `/pipeline run {CODE###X} [CODE###X ...]` — Full Execution

### Step 0: Register Pipeline Session

Open a pipeline-level session via the storage backend (supabase → `qa.factory_session_log`;
no-op under `storage_backend: none`):

```
log_session("pipeline_start", { machine: detected_machine, model: detected_model,
                                branch: "{main_branch}", mode: "pipeline" })
```

Store the returned id as `{pipeline_session_uuid}`. This is the parent session — individual milestone/epic sessions are children.

### Step 1: Plan Phase (unless --skip-ccb)

For each milestone: run the same logic as `/pipeline plan` Step 1-2.

If `--skip-ccb` is NOT set and this is the first milestone in the list, optionally run a lightweight CCB:

```
Agent(subagent_type: "{agents.completion_audit}" (default: completion-audit), prompt: "Quick audit of {CODE###X}: check Linear for completeness, verify no blocking dependencies on external milestones. Report in under 200 words.")
```

This is advisory only — it does not block the pipeline. Print completion-audit's findings and continue.

### Step 2: Execute Each Milestone (Sequential)

For each milestone in argument order:

#### 2a: Milestone Start

Run the equivalent of `/milestone start {CODE###X}`:

0. **Detect runtime environment** — hostname → machine handle, system prompt → actual model
1. Insert `qa.factory_session_log` row with **detected** machine/model (not config defaults)
2. Load task plans from `qa.task_plans` (fallback to Linear)
3. Query Linear for all epics + tasks
4. Identify unblocked epics (topo-sort by `blockedBy`)
5. **Body freshness check** — verify all epics have projectId, milestoneId, required sections
6. Print execution diagram with branch + model info:
   ```
   📍 Branch: {main_branch}
      Model:  {actual_model} on {actual_machine}
   ```

#### 2b: Execute Each Epic (Sequential, Dependency-Ordered)

For each epic in topo-sorted order:

**Pre-check: Dependencies met?**
Verify all `blockedBy` epics are Done. If a dependency was skipped (labelled `blocked:cr-review`), treat it as a soft dependency:
- If the current epic's code doesn't touch files changed by the skipped epic → proceed with warning
- If overlap exists → skip this epic too, label `blocked:dependency-skipped`

**Epic Start:**

1. **Body freshness check** — verify epic has all required sections, projectId, milestoneId, model/machine labels
   If stale: run `/plan-milestone {milestone} --update` scoped to this epic before proceeding
2. **Model/agent match check** — compare epic's assigned agent/model to current runtime
   - Non-Claude agent → skip epic, generate `/brief` for manual dispatch
   - Claude model mismatch → log warning, continue (pipeline mode doesn't ask — it logs and proceeds)
3. **Create branch and print:**
   ```bash
   git checkout {main_branch} && git pull origin {main_branch}
   git checkout -b {branch_name}
   git push -u origin {branch_name}
   ```
   ```
   📍 Branch: {branch_name}
      Epic:   {ID} — {title}
      Model:  {actual_model} on {actual_machine}
      Assigned: {epic_model} on {epic_machine}
   ```
4. Move epic to In Progress in the task manager:
   ```
   update_issue({ID}, { state: "In Progress" })
   ```

**Work Each Task (Sequential):**

For each child task in dependency order:

1. Read task from Linear (`get_issue`)
2. **Body freshness check** — verify task has Goal, Steps, Required Reading, Acceptance Criteria
3. **Verify on correct branch** — `git branch --show-current` must match epic branch
4. Read `## Required Reading` files
5. Follow `## Steps` — implement each step
6. Checkpoint commit after each step (≥3 files rule, max 5 files per commit)
7. Run task's test command after all steps
8. Mark task Done in Linear
7. Update the stored task plan status:
   ```
   set_task_plan_status({ID}, "done")
   ```

**Epic Close — PR + Review + Merge:**

1. Run acceptance tests:
   ```bash
   pytest tests/milestones/{milestone_lower}/test_{epic_short}.py -v --tb=short
   ```

2. Create PR:
   ```bash
   gh pr create --base {main_branch} --head {branch} \
     --title "[{MILESTONE}] {Epic Title}" \
     --body "## Summary ..."
   ```

3. **CodeRabbit Review Loop (max 3 cycles):**

   Wait for CodeRabbit review (~5 min):
   ```bash
   # Poll for CR review
   for i in {1..30}; do
     REVIEW=$(gh pr reviews {pr_number} --json author,state | jq '.[] | select(.author.login == "coderabbitai")')
     [ -n "$REVIEW" ] && break
     sleep 10
   done
   ```

   If CodeRabbit has blocking feedback:
   - Read feedback, fix issues, commit, push
   - Increment `{fix_cycle}` counter
   - If `{fix_cycle} >= 3`:
     - Label the epic `blocked:cr-review` in Linear
     - Post comment: "Pipeline: skipped after 3 failed CR cycles"
     - Close the PR: `gh pr close {pr_number}`
     - Delete the branch: `git push origin --delete {branch}`
     - **SKIP to next epic**
   - Otherwise loop back to wait for new CR review

4. **Auto-Merge Gate:**

   Pipeline mode auto-merges unless the PR meets ANY safety threshold:
   - PR touches `supabase/migrations/` → **STOP, flag for Operator**
   - PR changes >15 files → **STOP, flag for Operator**
   - Epic has label `ceo-required` → **STOP, flag for Operator**

   If none of the above:
   ```bash
   gh pr merge {pr_number} --squash --delete-branch
   ```

   If safety threshold hit:
   - Post Slack notification: "Pipeline paused: {reason}. PR #{pr_number} needs Operator approval."
   - Label epic `pipeline:paused` in Linear
   - **Continue to next epic** (don't block the whole pipeline)

5. **Post-Merge Agents (Parallel):**

   ```
   Agent(subagent_type: "documentation-engineer", prompt: "Run doc-sync for epic {ID}...")
   Agent(subagent_type: "rules-audit", prompt: "Run compliance check on PR #{pr_number}...")
   ```

6. **Write Telemetry:**

   - `qa.reviewer_feedback` — one row per reviewer
   - `qa.review_events` — one row per review round
   - `qa.gate_results` — acceptance test outcome
   - `qa.epic_outcomes` — epic close result

7. **Mark Done in Linear:**

   All child tasks → Done. REVIEW gate task → Done. Epic → Done.

8. **Post "What Actually Happened"** on epic in Linear (same format as `/epic close` Step 6).

9. **Log epic result for pipeline summary:**
   ```
   {epic_id}: {DONE | SKIPPED:cr-review | SKIPPED:dependency | PAUSED:ceo-required}
   ```

#### 2c: Milestone Close

After all epics in this milestone are processed:

Run the equivalent of `/milestone close {CODE###X}`:

1. Git & Linear cleanup (delete merged branches, close orphan PRs)
2. Verify all non-skipped epics are Done
3. Create CLEANUP epic for deferred/skipped items
4. Spawn `{agents.completion_audit}` + `{agents.spec_audit}` audit agents (default: completion-audit + spec-audit), in parallel
5. Post "What Actually Happened" on each epic
6. Write `qa.milestone_outcomes`
7. Git tag: `milestone/{CODE###X}`
8. Update parent project description

**Skipped epics handling:**
- Skipped epics are listed in the CLEANUP epic description
- They get label `ccb-candidate` so the next CCB picks them up
- They do NOT block milestone close — the milestone closes with a `PARTIAL` verdict

### Step 3: Pipeline Summary

After all milestones are processed:

```
PIPELINE COMPLETE
━━━━━━━━━━━━━━━━━

Started:  {start_time}
Finished: {end_time}
Duration: {hours}h {minutes}m

MILESTONES
──────────────────────────────────────────────────────────────────
  Milestone    Epics Done    Epics Skipped    Epics Paused    Verdict
  ──────────── ──────────── ──────────────── ──────────────── ────────
  {CODE###X}   {n}/{total}   {n}              {n}              ✓ DONE
  {CODE###X}   {n}/{total}   {n}              {n}              ⚠ PARTIAL

SKIPPED EPICS (blocked:cr-review — need manual attention)
  {ID} [{CODE###X}] {title} — failed CR after 3 cycles
  {ID} [{CODE###X}] {title} — dependency {dep_ID} was skipped

PAUSED EPICS (Operator approval needed)
  {ID} [{CODE###X}] {title} — PR #{pr} touches migrations
  {ID} [{CODE###X}] {title} — PR #{pr} changes 23 files

CLEANUP EPICS CREATED
  {ID} [{CODE###X}] CLEANUP: Post-Milestone Debt
  {ID} [{CODE###X}] CLEANUP: Post-Milestone Debt

Total: {epics_done} done | {epics_skipped} skipped | {epics_paused} paused
       {commits} commits | {prs_merged} PRs merged | {tests_passed}/{tests_total} tests
```

Close the pipeline session log:
```
log_session("pipeline_finish", { session: "{pipeline_session_uuid}",
  status: {any_skipped_or_paused} ? "partial" : "completed",
  commits: {total_commits}, files_changed: {total_files} })
```

---

## `/pipeline run {ID} [{ID} ...]` — Epic Mode

When all arguments match `BEN-{digits}`, the pipeline runs in **epic mode** — no milestone lifecycle, just sequential epic execution.

### Step 0: Validate Epics Exist

For each {ID} argument:

```
get_issue({ID})
```

Verify each issue:
- Exists in Linear
- Has label `epic` (not a task — tasks can't be pipeline targets)
- Is NOT already Done

If any argument is not a valid epic, print error and stop:
```
ERROR: {ID} is not an epic (it's a {type}). Pipeline requires epic-level issues.
```

### Step 1: Dependency Sort

Read `blockedBy` relations for all provided epics. Topo-sort them.

If an epic depends on another epic NOT in the argument list:
- Check if that dependency is already Done → proceed
- If NOT Done → print warning, skip the dependent epic with `blocked:dependency-external`

### Step 2: Register Pipeline Session

Same as milestone mode — insert `qa.factory_session_log` with `mode: 'pipeline-epics'`.

### Step 3: Execute Each Epic (Sequential)

For each epic in topo-sorted order, run the same epic execution logic as milestone mode Step 2b:

1. Epic start → create branch, move to In Progress
2. Work each task sequentially
3. Epic close → PR, CodeRabbit loop, auto-merge (same safety valves)
4. Write all telemetry (reviewer_feedback, epic_outcomes, etc.)
5. Mark Done in Linear

### Step 4: Summary

```
PIPELINE COMPLETE (Epic Mode)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Started:  {start_time}
Finished: {end_time}
Duration: {hours}h {minutes}m

EPICS
──────────────────────────────────────────────────────────────────
  Epic          Milestone    Title                          Verdict
  ──────────── ──────────── ────────────────────────────── ────────
  {ID}      {CODE###X}   {title}                        ✓ DONE
  {ID}      {CODE###X}   {title}                        ⚠ SKIPPED (cr-review)
  {ID}      {CODE###X}   {title}                        ⏸ PAUSED (migrations)

Total: {done} done | {skipped} skipped | {paused} paused
```

---

## Safety Valves

| Condition | Action | Pipeline continues? |
|-----------|--------|---------------------|
| CodeRabbit fails 3 fix cycles | Label `blocked:cr-review`, skip epic | ✓ Yes |
| PR touches `supabase/migrations/` | Label `pipeline:paused`, Slack Operator, skip | ✓ Yes |
| PR changes >15 files | Label `pipeline:paused`, Slack Operator, skip | ✓ Yes |
| Epic has `ceo-required` label | Label `pipeline:paused`, Slack Operator, skip | ✓ Yes |
| Dependency epic was skipped | Check file overlap → skip if overlap | ✓ Yes |
| Acceptance tests fail critically | Label `blocked:tests`, skip epic | ✓ Yes |
| `git push` fails (network) | Retry 3x with backoff, then skip epic | ✓ Yes |
| Linear API unavailable | Retry 3x, then log warning and continue without Linear updates | ✓ Yes |

The pipeline NEVER stops entirely. Individual epics fail; the pipeline continues.

---

## Supabase Tables Written

All writes go through the same paths as the composed skills:

| Table | When | What |
|-------|------|------|
| `qa.factory_session_log` | Pipeline start, milestone start/close | Session lifecycle |
| `qa.task_plans` | Task completion | Status → done |
| `qa.reviewer_feedback` | After CR review | Per-reviewer findings |
| `qa.review_events` | After each review round | Round summary |
| `qa.gate_results` | After acceptance tests | Pass/fail + rationale |
| `qa.epic_outcomes` | After epic close | Epic result |
| `qa.milestone_outcomes` | After milestone close | Milestone result |
| `qa.usage_budget` | Milestone close | Cost rollup |
| `intel.decisions` | Sweep at epic/milestone close | Captured decisions |
| `intel.ideas` | Sweep at epic/milestone close | Captured ideas |

---

## Key Rules

- Milestones execute **sequentially** — never in parallel (shared `develop` branch)
- Epics within a milestone execute **sequentially** in topo-sorted dependency order
- Auto-merge is the default — Operator approval only for migrations, large PRs, or `ceo-required` label
- Max 3 CodeRabbit fix cycles per epic before skip
- Skipped epics get `blocked:cr-review` label and appear in CLEANUP epic
- Paused epics get `pipeline:paused` label and need Operator action
- The pipeline NEVER stops entirely — it flags and continues
- All Supabase telemetry from composed skills is preserved
- `/pipeline plan` is non-destructive — it only creates Linear issues, never merges code
- `--skip-ccb` bypasses the advisory completion-audit audit (use when CCB already ran)

## Judgment weave (see /judgment)

Every dispatched prompt carries a **handoff contract** — reject dispatch if missing:

1. **Claim** — the falsifiable statement the work must make true ("page X renders leaders from live data").
2. **Gate(s)** — the numeric abort conditions the worker must honor (`/gate` format), including the universal effort gate (`> 2× estimate → STOP + report`).
3. **Evidence format** — exactly what proof must come back (command + output, screenshot, test run). "It's done" with no artifact is auto-REFUTED.

Post-run, the orchestrator runs `/gate check` against each dispatched gate before accepting the wave, and logs verdicts → `/verdict log`. Autonomous workers are exactly the executors that most need mechanical gates — they have no one watching their optimism.

At each milestone close and in the final summary report, fold in the escalation queue: reference every `.claude/escalation-queue.md` entry queued during the run (verbatim, not paraphrased). Queued escalations surface in the run report; a run with unburned ESC entries closes as **PARTIAL, not failed** — and not clean — until the Operator burns or dismisses them.
