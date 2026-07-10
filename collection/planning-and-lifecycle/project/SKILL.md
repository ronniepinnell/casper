---
name: project
origin: authored
public: true
description: Project lifecycle (task-manager agnostic via the adapter layer) — start a project (orient Operator on milestone chain, update project status), close a project (verify all milestones Done, write outcome, update description), or open a new project (scaffold with template + first milestone). One level above /milestone in the planning hierarchy. Requires a project-capable task manager.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, mcp__claude_ai_Linear__get_project, mcp__claude_ai_Linear__save_project, mcp__claude_ai_Linear__list_projects, mcp__claude_ai_Linear__list_milestones, mcp__claude_ai_Linear__get_milestone, mcp__claude_ai_Linear__save_milestone, mcp__claude_ai_Linear__list_issues, mcp__claude_ai_Linear__save_issue, mcp__claude_ai_Supabase__execute_sql
argument-hint: [open|start|close|status] <project_name>
---

# Project Lifecycle Management

> **Planning hierarchy:** Initiative → **Project** → Milestone → Epic → Issue
> A Project is a long-running workstream (examples: Factory, Analytics, Tracker).
> `/project start` orients the Operator. `/project close` wraps it up. `/project open` scaffolds a new one.

## Step 0: Load project context (run first)

Read `.claude/project-context.md` for `task_manager`, `task_team_id`, `task_prefix`,
`storage_backend`, `secret_manager`, `factory_enabled`, `spec_dir`, `scripts_dir`. Load the
task-manager adapter `_shared/adapters/{task_manager}.md` and storage backend
`_shared/storage/{storage_backend}.md`.

> **Requires a project-capable task manager.** This skill operates on the *Project* level,
> above the adapter's Milestone→Epic→Issue model. The `*project*` calls
> below are the `linear` adapter's form; a task manager without a project layer (e.g. plain
> GitHub) should map a Project to a milestone-group or skip this skill. Tracker-regeneration
> and session-logging steps are **factory-overlay** — they run only when `factory_enabled: true`.

`{ID}` = `{task_prefix}-{n}`; team references use `{task_team_id}`.

## Subcommands

| Command | Purpose |
|---------|---------|
| `/project open "Name"` | Scaffold new Linear project with template + first milestone |
| `/project start "Name"` | Move project to In Progress, show milestone chain, update description |
| `/project close "Name"` | Verify all milestones Done, mark complete, write outcome to description |
| `/project status "Name"` | Show milestone progress table for the project |

---

## `/project open "Name"` — Scaffold New Project

> **CLI equivalent (factory overlay):** projects with a `{scripts_dir}/infra/linear_project_ops.py`
> helper may expose a CLI, e.g. `acme project open "Name" [--template factory]`.
> Optional — the MCP/adapter path below is the portable default.

### Step 1: Choose Template

| Template flag | Use for |
|--------------|---------|
| `factory` | Factory/infra projects (watchers, dispatch, CLI) |
| `analytics` | Dashboard, ETL, data pipeline projects |
| `tracker` | Game tracker, CV, real-time projects |
| `generic` | Any other project |

### Step 2: Create Linear Project

```
save_project(
  name: "{Name}",
  addTeams: [{task_team_id}],
  description: {template_body},
  summary: "{one-line mission}"
)
```

Standard description template:
```markdown
## Mission
{one-sentence mission — fill in from context}

## Milestone Log
<!-- Auto-updated by the project CLI milestone open/close -->

## Key Decisions
<!-- Populated by the decisions-store companion (storage `list_decisions`) -->

## Acceptance Criteria
- [ ] TBD — fill before first /plan-milestone run
```

### Step 3: Link to Initiative (if specified)

```
save_project(id: "{project_id}", addInitiatives: ["{initiative}"])
```

### Step 3b: Create Master Tracker Issue

Create the project-level master tracker issue (the canonical "where are we?" view).

```
save_issue(
  title: "[{Name}] 📋 MASTER TRACKER — {Name}",
  team: {task_team_id},
  project: "{project_id}",
  milestone: "{first_milestone_id}",   # park in the first milestone; tracker is project-scope
  priority: 1,
  labels: ["milestone-tracker", "type:tracker"],
  description: {use {scripts_dir}/admin/regenerate_tracker.py format — call render_project_tracker()}
)
```

Print the new `{ID}` to the report. **Factory overlay only** (`factory_enabled: true`): if the
parent initiative has a master tracker, cascade to it via `{secret_manager}`:

```bash
{secret_manager} run -- python3 {scripts_dir}/admin/regenerate_tracker.py --initiative "{initiative_name}" --on-failure-issue || \
  echo "WARN: cascade failed — issue auto-filed if --on-failure-issue worked, else manual refresh needed"
```

### Step 4: Create First Milestone

```
save_milestone(
  project: "{project_id}",
  name: "M0001A — {Name} Foundation",
  description: "First milestone — created by project open. Run /plan-milestone to fill in epics."
)
```

### Step 5: Scaffold Docs Folder

```bash
slug=$(echo "{name}" | tr '[:upper:] ' '[:lower:]-' | sed 's/[^a-z0-9-]//g')
mkdir -p "{spec_dir}/$slug"
echo "{name} — project specs. See the task manager's project for the milestone plan." > "{spec_dir}/$slug/.abstract.md"
```

### Step 6: Report

```
PROJECT CREATED: {Name}
Linear: {project_url}
First milestone: M0001A — {Name} Foundation

Next steps:
  1. /plan-milestone M0001A   — break into epics
  2. /milestone start M0001A  — begin execution
```

---

## `/project start "Name"` — Open Existing Project

### Step 1: Fetch Project from Linear

```
get_project(query: "{Name}", includeMilestones: true)
```

### Step 2: Update Project State and Description

```
save_project(id: "{id}", state: "started")
```

Append to `## Milestone Log` in description:
```
- **PROJECT STARTED** ▶ YYYY-MM-DD
```

### Step 3: Show Milestone Chain

Print all milestones with status:

```
PROJECT: {Name}
Status: In Progress ▶ (was: {previous_state})
Initiative: {initiative_name}

MILESTONE CHAIN
───────────────────────────────────────────
  #   Milestone      Title                   Status      Progress
  ─── ────────────── ─────────────────────── ─────────── ────────
  1   FCT001A        Ship Factory OS         ○ Planned   0%
  2   FCT003A        Run Factory 24/7        ○ Planned   0%
  3   FAC002A        Model-Agnostic CLI      ▶ Active    43%  ← CURRENT
  4   FCT004A        Lifecycle Automation    ○ Planned   15%

First unblocked milestone with work remaining: FAC002A
Run: /milestone start FAC002A
```

### Step 4: Register Session (factory overlay — only if `factory_enabled`)

If starting an interactive session, record it via the storage backend (no-op under
`storage_backend: none`):
```
log_session("project_start_interactive", { project: "{Name}", machine, model, cli: "claude-code" })
```

---

## `/project close "Name"` — Close Project

### Step 1: Verify All Milestones Done

```
list_milestones(project: "{Name}")
```

For each milestone: check status. If any is NOT completed/cancelled → STOP.

```
CANNOT CLOSE — incomplete milestones:
  FAC002A — Model-Agnostic CLI (43% complete)
  FCT004A — Lifecycle Automation (15% complete)

Close or defer these milestones first.
```

### Step 2: Mark Project Complete

```
save_project(id: "{id}", state: "completed")
```

### Step 3: Update Project Description

Append to `## Milestone Log`:
```
- **PROJECT CLOSED** ✓ YYYY-MM-DD — {N} milestones complete
```

### Step 4: Write Outcome to storage

```
record_decision(
  title: "Project {Name} closed",
  body:  "Closed YYYY-MM-DD. {N} milestones complete. Key outcomes: {summary}.",
  type:  "project_close",
  area:  "{slug}"
)
```
No-op under `storage_backend: none`.

### Step 4b: Cascade — Regenerate Parent Initiative Tracker (factory overlay only)

Runs only when `factory_enabled: true`. After marking the project complete, regenerate the
parent initiative's master tracker (if one exists) so its project chain reflects Done state.

```bash
# Best-effort: never fail the close on cascade failure.
{secret_manager} run -- python3 {scripts_dir}/admin/regenerate_tracker.py \
  --initiative "{initiative_name}" \
  --on-failure-issue || \
  echo "WARN: cascade failed — issue auto-filed if --on-failure-issue worked, else manual refresh needed"
```

If the initiative tracker doesn't exist, the cascade no-ops.

### Step 5: Identify Next Project

Query initiative for other projects not yet started:
```
list_projects(initiative: "{initiative_name}", state: "planned")
```

### Step 6: Report

```
PROJECT CLOSED: {Name} ✓
{N}/{N} milestones Done
Initiative: {initiative_name}

{If next project exists:}
Next project in initiative: {Next Name}
Run: /project start "{Next Name}"

{If all projects done:}
All projects in "{initiative_name}" are complete.
Run: /initiative close {initiative_id}
```

---

## `/project status "Name"` — Status Check

```
get_project(query: "{Name}", includeMilestones: true)
```

Print the milestone chain table (same as `/project start` Step 3) without changing any state.

---

## Planning Hierarchy Navigation

```
/initiative start → shows projects → /project start → shows milestones → /milestone start → shows epics → /epic start
/initiative close ← /project close ← /milestone close ← /epic close
```

Each level's `close` calls the script that updates the level above:
- `epic close` → updates milestone project description via `linear_milestone_ops.py epic-milestone`
- `milestone close` → updates project description via `linear_milestone_ops.py close`
- `project close` → updates initiative (future: `linear_project_ops.py close`)

---

## CLI Equivalents (factory overlay — optional)

Projects that ship a `{scripts_dir}/infra/linear_project_ops.py` helper may expose a CLI.
Example (with a project CLI):

```bash
acme project open  "BenchFactory" [--template factory] [--initiative "Factory & Infrastructure"]
acme project start "Factory"
acme project close "Factory"
acme project status "Factory"
```

Absent the helper, use the `/project` subcommands directly — they're the portable path.

## Judgment weave (see /judgment)

- **Open/start:** confirm each milestone carries `GATE:` abort conditions; author missing ones with `/gate`.
- **Close:** run **`/refute`** on the "all milestones Done" claim before writing the outcome; verdicts → **`/verdict log`**.
