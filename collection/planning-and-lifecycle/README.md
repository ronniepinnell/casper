# Planning & Lifecycle

Structured project cadence — from initiative down to a single task — and the orchestration that runs it.

[← Back to the collection index](../../README.md)

### Skills (11)

| Unit | What it does | When to call | Install |
|---|---|---|---|
| `ccb` | Change Control Board — executive review that audits project state, prioritizes work, and plans the next milestone | Use when starting a new milestone or major planning cycle | `./install.sh --only ccb` |
| `cycle-check` | Weekly planning ritual. Reviews last week's progress, upcoming work, and flags blockers across the active milestone | — | `./install.sh --only cycle-check` |
| `epic` | Epic lifecycle management — start, status, close | Use when transitioning between epics in a milestone | `./install.sh --only epic` |
| `initiative` | Initiative lifecycle management — start an initiative (orient Operator, show milestone chain, identify first unblocked milestone) or close it (verify… | — | `./install.sh --only initiative` |
| `issue` | Issue (task) lifecycle management — start work on a task (read plan, move to In Progress) or mark it done (commit, update plan status, mark Done in t… | — | `./install.sh --only issue` |
| `milestone` | Milestone lifecycle — start, status, close | — | `./install.sh --only milestone` |
| `mvp` | Intense discovery + design session that births Initiatives in Linear | — | `./install.sh --only mvp` |
| `pipeline` | Autonomous pipeline orchestrator — runs one or more milestones end-to-end by composing ccb, plan-milestone, milestone, epic, and issue skills sequent… | Use for overnight runs or batch milestone execution | `./install.sh --only pipeline` |
| `plan-milestone` | Break a milestone goal into epics and tasks with dependency ordering, acceptance tests, and task manager ticket creation | — | `./install.sh --only plan-milestone` |
| `project` | Project lifecycle (task-manager agnostic via the adapter layer) — start a project (orient Operator on milestone chain, update project status), close… | — | `./install.sh --only project` |
| `wave` | Assess current project state and produce (and optionally dispatch) the next N-slot factory run — a wave of parallel `/epic start` prompts with model… | Use when planning (or launching) the next batch of parallel factory work | `./install.sh --only wave` |

Install the whole category at once: `./install.sh --category planning-and-lifecycle`
