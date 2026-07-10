---
name: initiative
origin: authored
public: true
description: Initiative lifecycle management — start an initiative (orient Operator, show milestone chain, identify first unblocked milestone) or close it (verify all milestones Done, write retro, capture a retro decision via storage record_decision, surface follow-ons). Sits above the milestone level in the planning hierarchy.
trigger: /initiative
argument-hint: [start|close] {initiative_id_or_name}
---

# Initiative Lifecycle Management

> **Initiative → Milestone → Epic → Issue**
> An Initiative is the "why this set of milestones" layer.
> Created by `/mvp`. Planned in detail by `/ccb`. Executed milestone by milestone.

## Step 0: Load project context (run first)

Read `.claude/project-context.md` for `task_manager`, `task_team_id`, `task_prefix`,
`storage_backend`, `secret_manager`, `factory_enabled`, `roadmap_file`, `scripts_dir`. Load the
task-manager adapter and storage backend.

> **Requires an initiative-capable task manager.** Like `/project`, this skill works above the
> adapter's Milestone→Epic→Issue model. The Linear GraphQL `curl`/`*`
> calls below are the `linear` adapter's form; a manager without an initiative layer should map
> an Initiative to a project/label-group or skip this skill. The `LINEAR_API_KEY` lookup uses
> `{secret_manager}`. Tracker-regeneration steps are **factory overlay** (`factory_enabled: true`).

`{ID}` = `{task_prefix}-{n}`; team references use `{task_team_id}`.

## Planning Hierarchy

```
/mvp          → births Initiative   (discovery + bet)
/initiative   → start/close         (owns milestone chain)
/milestone    → start/close         (owns epic chain)
/epic         → start/close         (owns issue chain)
/issue        → start/done          (owns commits)
```

## Subcommands

| Command | Purpose |
|---------|---------|
| `/initiative new {name} --bet "{bet}"` | Create a new Linear initiative + master tracker issue |
| `/initiative start {id}` | Orient Operator on initiative scope, identify first milestone, suggest next step |
| `/initiative status {id}` | Read-only snapshot — projects under initiative + their health, no state changes |
| `/initiative close {id}` | Verify all milestones Done, write retro, capture via storage `record_decision` |

---

## `/initiative new {name} --bet "{bet}"` — Create New Initiative + Master Tracker

### Step 1: Create the Linear initiative

```bash
# task-manager auth handled by the adapter via {secret_manager}
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_API_KEY" \
  -d '{"query": "mutation { initiativeCreate(input: { name: \"{name}\", summary: \"{bet}\", status: \"planned\" }) { success initiative { id name } } }"}'
```

### Step 2: Create the Master Tracker issue

```
save_issue(
  title: "[INIT-{NAME-SLUG}] 📋 MASTER TRACKER — {name}",
  team: {task_team_id},
  project: <pick most-relevant existing project; if none, the user must create one first>,
  milestone: <a meta milestone in that project>,
  priority: 1,
  labels: ["initiative-tracker", "type:tracker"],
  description: {use {scripts_dir}/admin/regenerate_tracker.py render_initiative_tracker() format}
)
```

The hook requires project+milestone IDs. Park the tracker in a "host" project (typically the most active one under this initiative) — the content is initiative-level; the location is just storage.

### Step 3: Report

```
INITIATIVE CREATED: {name}
Linear:        {initiative_url}
Master tracker: {ID}
Bet:           {bet}

Next steps:
  /project new "<first-project>" --initiative "{name}"
```

---

## `/initiative status {id}` — Read-Only Snapshot

**Read-only. No Linear mutations. No state transitions.**

```
get_initiative(query: "{id}", includeProjects: true)
```

For each project under the initiative, fetch milestone progress in parallel:

```
get_project(query: "{project_id}", includeMilestones: true)
```

Print a snapshot table — same shape as `/initiative start` Step 2 but without moving anything to In Progress:

```
INITIATIVE {id} — {title}
Bet: {one-line from initiative summary}
Status: {current Linear status}

PROJECTS ({N} total)
─────────────────────────────────────────────────────────────────────
  Project                     Status         Milestones    Done %
  ─────────────────────────── ────────────── ───────────── ─────────
  {Project 1}                 ● In Progress   {n}           {pct}%
  {Project 2}                 ○ Planned       {n}           {pct}%
  {Project 3}                 ✓ Completed     {n}           100%
...

ACTIVE WORK
─────────────────────────────────────────────────────────────────────
  Project       Active milestone(s)       Blocker / next gate
  ─────────────  ────────────────────────  ──────────────────────
...

HEALTH FLAGS
─────────────────────────────────────────────────────────────────────
  (Anything off-track — stale milestones >7d, blocked chains, projects
  in Planned state with active children, etc.)
```

If a project under the initiative has stale milestones (>7 days no movement) or a project is `Planned` while its children are active: flag in HEALTH FLAGS.

End with:
```
Suggested next: {one-line based on snapshot — e.g., "Run /project status {N} for deeper dive on slowest project"}
```

---

## `/initiative start {id}` — Begin Initiative

### Pre-Step 0: Context Load

Before presenting to Operator, load context in parallel so the session is informed:

```bash
# task-manager auth handled by the adapter via {secret_manager}

# Load the initiative itself
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "query { initiative(id: \"{id}\") { id name description milestones { nodes { id name state { name } description dependencies { nodes { id name } } } } } }"}'

# Load all active initiatives for context
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "query { initiatives(filter: { status: { in: [\"inProgress\", \"planned\"] } }) { nodes { id name status } } }"}'
```

Read in parallel:
- `{roadmap_file}` strategy section (skip if unset)
- Recent intel: `list_decisions(limit: 10)` via the storage backend ([] under `none`)
- Last 10 merged PRs: `git log --oneline --merges origin/{main_branch} -10`

If the initiative involves a new product area or customer segment, also spawn:
- `Agent(subagent_type: "product-manager", prompt: "Review {roadmap_file}. Summarize the strategic fit and risk for initiative: {initiative_name}. Under 100 words.")` (skip if `roadmap_file` unset)

### Pre-Step: Autonomous Mode Offer

```
Initiative {id} — {title}
{N} milestones | Bet: {one-line bet statement}

I can run this start autonomously — orient, load milestones, and report
without pausing. I'll still stop at hard gates (dependency blockers).

Run autonomously? (yes / interactive)
```

### Step 1: Load Initiative from Linear

```bash
# task-manager auth handled by the adapter via {secret_manager}
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "query { initiative(id: \"{id}\") { id name description milestones { nodes { id name state { name } description } } } }"}'
```

Extract:
- Bet statement (from `## The Bet` section)
- Success metric and timeframe
- Milestone chain + dependency order
- Trajectory chosen (conservative / expected / ambitious)

### Step 2: Verify Milestone Dependencies

For each milestone, check its state in Linear. Map dependency order from initiative description.

Print dependency-ordered table:

```
INITIATIVE {id} — {title}
Bet: {one-line}
Success metric: {outcome} by {timeframe}
Trajectory: {chosen}

MILESTONES ({N} total)
──────────────────────────────────────────────────────────────
  #   Milestone     Title                     Status       Deps
  ─── ──────────── ──────────────────────────── ──────────── ─────────────
  1   {M1}         {title}                    ○ Ready      —
  2   {M2}         {title}                    ✗ Blocked    M1
  3   {M3}         {title}                    ✗ Blocked    M2
...

Legend: ✓ Done | ● In Progress | ○ Ready | ✗ Blocked
```

### Step 3: Move Initiative to In Progress

```bash
# Update initiative state in Linear
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_API_KEY" \
  -d '{"query": "mutation { initiativeUpdate(id: \"{id}\", input: { status: \"inProgress\" }) { success } }"}'
```

### Step 4: Identify and Surface First Milestone

Find the first milestone whose dependencies are all Done (or none).

```
First milestone: {M1} — {title}

Ready to plan it in detail?
  Run: /ccb        → plan milestone {M1} with full CCB process
  Run: /milestone start {M1}   → start immediately (skip CCB, use existing plan)
```

If the first milestone has no plan yet (no epics in Linear):
```
⚠ Milestone {M1} has no epics yet — it needs planning before it can start.
Run: /ccb to plan it, or /plan-milestone {M1} if you have a clear goal.
```

---

## `/initiative close {id}` — Close Initiative

### Pre-Step: Autonomous Mode Offer

```
Initiative {id} — {title}

I can run this close autonomously — verify milestones, write retro,
capture to intel, and identify follow-ons without pausing.

Run autonomously? (yes / interactive)
```

### Step 1: Milestone Progress Snapshot

Query all milestones in this initiative. Any NOT Done = BLOCKING.

```
INITIATIVE {id} — {title}
Progress: {done}/{total} milestones Done

  #   Milestone   Title                   Status
  ─── ─────────── ─────────────────────── ──────────
  1   {M1}        {title}                 ✓ Done
  2   {M2}        {title}                 ✓ Done
  3   {M3}        {title}                 ✗ In Progress  ← BLOCKING
```

If any milestone is NOT Done:
```
CANNOT CLOSE — incomplete milestones:
  {Mn} — {title} ({status})

Close or defer these first.
```

If all Done: proceed.

### Step 2: Verify Success Metric

Read the initiative's `## Success Metric` section. Ask Operator:

```
Initiative bet: {bet_statement}
Success metric: {outcome} by {timeframe}

Did we hit it? What actually happened?
(Be honest — partial counts. Exceeded also counts.)
```

Record Operator's answer. This goes into the retro.

### Step 3: Write Retro

Post a comment on the initiative in Linear:

```markdown
## Initiative Retro — {date}

### The Bet
{bet_statement}

### What We Built
- {Milestone 1}: {one-line outcome}
- {Milestone 2}: {one-line outcome}
- {Milestone N}: {one-line outcome}

### Success Metric
Target: {outcome} by {timeframe}
Actual: {Operator's answer}
Verdict: HIT | PARTIAL | MISSED

### What We Learned
{Operator's answer from Step 2 — key learnings, surprises, what changed}

### What We Got Wrong
{Any assumptions that turned out to be false}

### What's Left (Deferred)
{Items that didn't make it — link to Linear issues}

### Follow-On Initiatives
{Any natural next bets that emerged}
```

### Step 4: Capture the decision to storage

```
record_decision(
  title: "Initiative Closed: {title}",
  body:  "Bet: {bet_statement}\n\nVerdict: {HIT|PARTIAL|MISSED}\nActual outcome: {Operator answer}\n\nKey learnings:\n{learnings}",
  type:  "retro"
)
```
No-op under `storage_backend: none`.

### Step 5: Mark Done in Linear

```bash
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_API_KEY" \
  -d '{"query": "mutation { initiativeUpdate(id: \"{id}\", input: { status: \"completed\" }) { success } }"}'
```

### Step 5b: Final Regeneration of Master Tracker (factory overlay only)

Runs only when `factory_enabled: true`. Regenerate the initiative's master tracker one last
time so its final state is the Done snapshot.

```bash
{secret_manager} run -- python3 {scripts_dir}/admin/regenerate_tracker.py --initiative "{name}" --on-failure-issue || \
  echo "WARN: final tracker regen failed — issue auto-filed if --on-failure-issue worked"
```

### Step 6: Surface Follow-Ons

Based on the retro, identify natural next bets:

```
INITIATIVE {id} is DONE.

What emerged:
  {1-3 follow-on ideas from the retro}

Next steps:
  Run: /mvp "{follow-on idea}"   → discover and build the next initiative
  Run: /initiative start {id}    → start an existing planned initiative
  Or: nothing — initiative complete, no follow-on needed
```

---

## Key Rules

- Initiative close requires ALL milestones Done — no exceptions without Operator override
- Success metric verdict must be honest — MISSED is a valid outcome
- Retro always captures what was wrong, not just what worked
- Follow-on initiatives are surfaced, never auto-created — Operator must approve via `/mvp`
- `/initiative` does not plan milestones — that is `/ccb` and `/plan-milestone`'s job

## Judgment weave (see /judgment)

- **Start:** run **`/premortem`** on the milestone chain before committing.
- **Close:** run **`/calibrate`** on the initiative's original estimates and confidence.
