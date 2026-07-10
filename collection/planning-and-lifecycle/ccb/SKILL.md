---
name: ccb
origin: authored
public: true
description: Change Control Board — executive review that audits project state, prioritizes work, and plans the next milestone. Spawns adversarial agents (completion-audit, spec-audit, PM, architect) for scrutiny. Use when starting a new milestone or major planning cycle.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, Agent, WebSearch, WebFetch, mcp__claude_ai_Linear__list_issues, mcp__claude_ai_Linear__list_teams, mcp__claude_ai_Linear__list_issue_labels, mcp__claude_ai_Linear__list_issue_statuses, mcp__claude_ai_Linear__get_issue, mcp__claude_ai_Linear__list_milestones, mcp__claude_ai_Linear__list_projects, mcp__claude_ai_Linear__save_comment, mcp__claude_ai_Linear__list_comments
argument-hint: [open|review|close] [--milestone {CODE###X}]
---

> **Factory mode:** If `CLAUDE_AUTO` is set in the environment, skip these instructions and instead run `{scripts_dir}/skills/ccb.sh "$@"` via Bash — the shell script handles autonomous dispatch.


> **Tool Map (Gemini/Codex):** See `.claude/skills/_shared/mcp-tool-map.md` for task-manager/storage tool-name equivalents across runtimes.



## Step 0: Load Project Context

Read `.claude/project-context.md`. Extract:
- `task_team_id` — use in all task manager calls
- `task_prefix` — ticket prefix (`{ID}` = `{task_prefix}-{n}`)
- `task_manager` — load adapter from `.claude/skills/_shared/adapters/{task_manager}.md`; route all task calls through its operations (`list_issues`, `get_issue`, `update_issue`, `create_issue`, `search_issues`, `add_comment`)
- `storage_backend` — load `.claude/skills/_shared/storage/{storage_backend}.md`; route CCB records through its operations (`record_decision`, `save_task_plan`, …)
- `spec_dir`, `roadmap_file`, `scripts_dir`, `factory_enabled`
- `agents` — capability→agent map; reference agents below as `{agents.<capability>}`. Absent → template defaults (`completion_audit: completion-audit`, `spec_audit: spec-audit`, `scalability_audit: future-self`, `pragmatism_audit: pragmatism-audit`). If a mapped agent is unavailable in this repo, skip that step with a logged note.
- `storage_schema_intel` / `storage_schema_qa` — storage namespace names (defaults `intel`/`qa`); never hardcode them.
If file missing: stop and tell user to run /project-init first.

---

> **Factory / CI mode:** If `CLAUDE_AUTO=1` is set, skip all `AskUserQuestion` calls and use
> the defaults described in each step. Never hang waiting for input in automated runs.

# CCB — Change Control Board

> **SKILL FILE LOCATION (for non-Claude agents — Gemini, Codex, Cursor):**
> This skill file lives at:
> `{project_root}/.claude/skills/ccb/SKILL.md`
>
> Related skill files (read before proceeding):
> - Plan-Milestone skill: `{project_root}/.claude/skills/plan-milestone/SKILL.md`
>   → Contains: blockedBy convention, agent routing table, epic/task templates, DoR format
> - Project rules: `{project_root}/CLAUDE.md`
> - Agent routing guide: `{project_root}/.claude/agents/AGENTS_GUIDE.md`
>
> If you are a non-Claude model and a Linear task tells you to "run /ccb" or "follow the CCB skill":
> 1. Read this file at the path above
> 2. Read the plan-milestone skill at the path above — it has the Linear issue templates
> 3. Do NOT create epics/tasks without following the plan-milestone DoR format exactly
>
> ---

> **CRITICAL: Linear is the factory input layer (spec amendment 2026-04-15).**
> - **Planning / tracking / DoR:** Linear (team: {task_team_id}, key: {task_prefix})
> - **Code / CI / reviews:** GitHub (branches, PRs, CodeRabbit, Codex, Gemini)
> - **Queue transport:** task-manager webhook → dispatch queue (storage `enqueue`/`dequeue`; supabase → `{storage_schema_qa}.prompt_queue`) → Trigger.dev tasks
>
> Epics and tasks live in Linear. GitHub keeps: milestone object (PR tagging),
> ONE tracking issue per milestone, and PRs. Never create epics/tasks as GitHub issues.

Executive planning session that audits the state of the world, identifies priorities, and plans the next milestone. Think of this as the "board meeting" before any major work begins.

> **Naming conventions:** Milestone IDs use `{CODE}{3D}{LETTER}` format (e.g. `MLX004A`, `FCT003A`).
> Epic titles: `[{milestone_id}] {Title}`. Task titles: plain descriptive (no prefix).
> Git: one branch per epic, all tasks are commits, one PR per epic to `{main_branch}`.
> Full convention details in `/plan-milestone` skill — § Naming Conventions.

## Subcommands

| Command | Purpose |
|---------|---------|
| `/ccb` or `/ccb open` | Full CCB: sweep + prioritize + plan milestone |
| `/ccb review FCT003A` | Review a specific milestone's completion state |
| `/ccb close FCT003A` | Close a milestone (runs hardening verification first) |

---

## `/ccb open` — Full CCB Session

### Pre-Phase: Branch-First (REQUIRED — before any file writes)

Create an ops branch before writing any files (session state, planning docs, spec stubs). Linear mutations (epic/task creation) may happen without a branch — only file writes need one.

```bash
git checkout {main_branch} && git pull origin {main_branch}
git checkout -b ops/ccb-{YYYYMMDD}
git push -u origin ops/ccb-{YYYYMMDD}
```

Print confirmation: `📍 Branch: ops/ccb-{YYYYMMDD}`

At the end of the CCB session, commit any file writes and open a PR:

```bash
git add -A
git commit -m "[OPS] CCB {YYYYMMDD} — planning files and spec stubs" || true
gh pr create --base {main_branch} --head ops/ccb-{YYYYMMDD} \
  --title "[OPS] CCB {YYYYMMDD}" \
  --body "CCB ops branch. Contains planning file writes. Auto-generated — safe to squash-merge."
```

Ask Operator to merge before the first `/epic start` of the new milestone.

### Phase 0: Briefing (MANDATORY — runs before agents)

Before launching any Phase 1 agents, run `/briefing` to surface what the fleet found since the last CCB:

```
/briefing
```

This gives the Operator current ground truth from the companion fleet (ETL issues, code health, infra alerts, spec drift, business intel) BEFORE the board agents do their sweep. The briefing findings feed directly into Phase 1 agent context and Phase 3 prioritization.

**Do not skip this step.** The briefing takes ~30 seconds and prevents agents from re-discovering things the fleet already found.

After the briefing output, ask:
> "Briefing complete. Any critical findings to highlight for the agents before we start the Phase 1 sweep? [enter to continue]"

Then proceed to Phase 1.

---

### Phase 1: State-of-World Sweep (Parallel Agents)

Launch these agents IN PARALLEL to audit current state. Each agent gets specific instructions:

**Agent 1 — `{agents.completion_audit}` (Reality Manager):**
```
Audit the current state of {project_name}. Use the task manager for epics/tasks, GitHub for PRs/code.

LINEAR (epics + tasks — the source of truth for planning):
Use the adapter op list_issues(team: "{task_team_id}") to get all issues.
Filter by label "epic" for epics, by parent for tasks.
Check status: Done issues → verify code actually exists and works.
In Progress issues → verify actual progress matches claims.

GITHUB (PRs + code — the source of truth for implementation):
Run: gh pr list --state open --json number,title,headRefName,reviewDecision --limit 50
Run: gh pr list --state merged --limit 20 --json number,title,mergedAt
Run: gh api repos/{owner}/{repo}/milestones --jq '.[] | {title,state,open_issues,closed_issues}'

For CLOSED epics: verify claimed completions against actual code.
Do the files exist? Do tests pass? Is the feature wired up?
For OPEN PRs: what's stuck, what's waiting on review, what's stale?
For RECENT MERGED PRs: did they actually deliver what was promised?
Check for: (1) verified completions, (2) lies/gaps (claimed done but code 
doesn't exist), (3) items in limbo (PR open, not merged), (4) stale PRs. 
Be brutal.

Also query the task manager for deferred items with no milestone assigned:
  list_issues(team: "{task_team_id}", labels: ["deferred"])   # adapter op
  Filter: milestone = null
List each one by title, origin epic, priority, and age (days since created).
These are punted items from past epics — surface any that are now unblocked or urgent.

Then: Based on your findings, recommend your TOP 3 PRIORITIES for the next 
milestone. What is the most important work to do next, from a "what's actually 
broken or missing" perspective? Rank by: blocks-other-work > user-facing-gap > debt.
```

**Agent 2 — `{agents.spec_audit}` (Spec Compliance):**
```
Audit spec compliance ruthlessly. Read ALL spec files:
- {spec_dir}/*.md (all product specs)
- {spec_dir}/GITHUB_FACTORY_SPEC.md (factory spec)
- Any other .md files in docs/factory/ that define requirements

But scope the audit to what's been WORKED ON, not the full vision:
Use the adapter op list_issues(team: "{task_team_id}") to get all epics/tasks.
Run: gh pr list --state merged --limit 50 --json number,title,body
Extract spec references from Linear issue descriptions and PR bodies (e.g., "Spec: §12", "spec_file#§section").

For each referenced spec section: READ THE ACTUAL CODE. Don't trust labels 
or issue status. Check if the requirement has real, working implementation.
Be ruthless — a stub is not implementation, a TODO is not done, an import 
with no usage is not wired up.

Report: (1) spec compliance percentage for referenced sections only, 
(2) CRITICAL gaps (issue closed but spec MUST/REQUIRED not implemented — 
these are lies), (3) partially implemented sections with honest % estimate,
(4) unreferenced spec sections summary (not audited — for Operator awareness).
Reference file:line for every finding.

Then: Based on your findings, recommend your TOP 3 PRIORITIES for the next 
milestone. Which spec gaps are most critical to close? Which specs are closest 
to complete and worth finishing? Rank by: user-impact > spec-coverage > completeness.
```

**Agent 3 — `{agents.scalability_audit}` (Scale Review):**
```
Review the current codebase architecture. Identify: (1) things that will break 
at 10 teams, (2) things that will break at 100 teams, (3) tech debt that 
compounds over time. Focus on database schema, ETL pipeline scalability, 
and dashboard performance patterns. Be specific — name files and patterns.

Then: Based on your findings, recommend your TOP 3 PRIORITIES for the next 
milestone. What will hurt most if we don't fix it now? What's the cheapest 
fix-now-vs-expensive-fix-later? Rank by: compounding-cost > blast-radius > effort.
```

**Agent 4 — `{agents.pragmatism_audit}` (Code Health):**
```
Scan the codebase for: (1) files over 500 lines that should be split, 
(2) dead code / unused imports, (3) TODO/FIXME/HACK comments that represent 
real debt, (4) test coverage gaps in critical paths (src/calculations/, 
src/tables/, api/). Report top 10 issues by severity.

Then: Based on your findings, recommend your TOP 3 PRIORITIES for the next 
milestone. Which code health issues will cause the most pain in the next 
30 days? Rank by: bug-risk > maintainability > cleanliness.
```

**Agent 5 — session-briefer (Recent Activity):**
```
Summarize: (1) all PRs merged in the last 7 days, (2) all open PRs and their 
review status, (3) all open GitHub issues by priority label, (4) any failed 
CI runs or blocked work. Keep it factual — numbers and links.

Then: Based on velocity and open work, recommend your TOP 3 PRIORITIES for 
the next milestone. What's the highest-value work that's ready to execute? 
What's been stuck longest? Rank by: ready-to-go > longest-blocked > highest-value.
```

**Agent 6 — product-manager (Strategic Alignment):**
```
Read {roadmap_file} and docs/IDEA_BANK.md.
Understand the product vision (from {roadmap_file} and project docs).
Report: (1) strategic priorities vs what's actually being built, (2) features 
that move the needle for launch readiness, (3) work that's off-strategy.

Then: Recommend your TOP 3 PRIORITIES for the next milestone from a product 
perspective. What gets us closest to a shippable product? What do users 
actually need? Rank by: launch-critical > user-value > strategic-alignment.
```

**Agent 7 — architect-reviewer (Technical Architecture):**
```
Review recent PRs and the current architecture. Check: (1) are we building 
on solid foundations or stacking on shaky ones? (2) any architectural decisions 
that need to be made before more code is written? (3) integration points 
that are missing or fragile?

Then: Recommend your TOP 3 PRIORITIES for the next milestone from an 
architecture perspective. What foundations need shoring up? What's the 
riskiest technical bet? Rank by: foundation-risk > integration-gaps > design-debt.
```

### Phase 1.5: Spec Coverage Gate (BLOCKING)

Before synthesizing findings, check whether the specs needed for this milestone exist and are adequate. This prevents planning epics for features that have no spec — which leads to ambiguous requirements and scope creep.

**Step 1 — Set session context:**
```bash
source {scripts_dir}/infra/get_session_context.sh && set_session_context ccb
```

**Step 2 — Run spec section coverage companion:**
```bash
python {scripts_dir}/companion/spec_section_coverage.py
```

**Step 3 — Query coverage via the storage backend** (supabase → `{storage_schema_qa}.v_spec_section_coverage`; returns `[]` under `storage_backend: none`, in which case skip the gate):
```
get_spec_coverage()
```

**Step 4 — Identify gaps for THIS milestone:**
Based on the milestone goal and the Phase 1 agent findings, identify which spec files this milestone will touch. For each:
- If the spec file exists but has sections with `coverage_status = 'unknown'` → flag as "needs epic mapping"
- If the spec file doesn't exist → flag as "needs spec creation"

**Step 5 — Present spec gaps to Operator:**
```
SPEC COVERAGE GATE — {milestone_id}

Specs this milestone will touch:
  {spec_file}: {pct_complete}% complete, {unknown} unmapped sections
  ...

Missing specs (features with no spec file):
  {feature}: no spec exists — recommend creating {spec_dir}/{NAME}_SPEC.md
  ...

Action needed:
  [ ] Create skeleton specs for unspecced features?
  [ ] Map existing sections to planned epics?
```

**Step 6 — If Operator approves skeleton spec creation:**
- Create skeleton spec files in `{spec_dir}/` (allowed in CCB context via the `{storage_schema_qa}.md_allowlist`)
- Each skeleton has: title, status DRAFT, numbered section headings for the feature's components
- Mark all sections as `coverage_status = 'planned'` in spec-coverage storage (supabase → `{storage_schema_qa}.spec_section_coverage`)

**If no gaps or Operator defers:** proceed to Phase 2.

---

### Phase 2: Synthesize Findings (Board Meeting)

After all agents return:

1. **Merge findings** into a single state-of-world report
2. **Categorize** every finding as:
   - BLOCKER: Must fix before new work (lies, broken features, spec violations)
   - DEBT: Should fix soon (code health, scale risks)
   - BACKLOG: Can wait (nice-to-haves, future concerns)

3. **Build Priority Matrix** — Collect each agent's top 3 recommendations and find consensus:
   ```
   PRIORITY MATRIX — Who Wants What
   
   | Priority | completion-audit | spec-audit | scale | code-health | briefer | PM | architect |
   |----------|------------------|------------|-------|-------------|---------|-----|-----------|
   | #1       | ...   | ...   | ...         | ...         | ...     | ... | ...       |
   | #2       | ...   | ...   | ...         | ...         | ...     | ... | ...       |
   | #3       | ...   | ...   | ...         | ...         | ...     | ... | ...       |
   
   CONSENSUS (3+ agents agree): {items}
   CONTESTED (agents disagree): {items with competing rationale}
   UNIQUE INSIGHTS (only 1 agent flagged): {items}
   ```

4. **Present to Operator** as a structured brief:
   ```
   CCB State of the World — {date}
   
   BLOCKERS ({count}):
   - [B1] {description} — {source agent} — {severity}
   ...
   
   DEBT ({count}):
   - [D1] {description} — {source agent}
   ...
   
   RECENT WINS ({count}):
   - {merged PR or completed milestone}
   ...
   
   OPEN WORK ({count} PRs, {count} issues):
   - ...
   
   AGENT RECOMMENDATIONS:
   - CONSENSUS: {what most agents agree on}
   - CONTESTED: {where agents disagree — present both sides}
   - WILD CARDS: {unique insights worth discussing}
   ```

### Phase 2.5: Parking Lot, Deferred Items & Idea Review

An agent reads P0001A parking lot items, deferred items, and companion findings:
```
Read parking lot items from the task manager (label: "parking-lot" or milestone P0001A).
Use the adapter op search_issues("parking lot") (team: "{task_team_id}")
Also read recent companion findings via list_findings() — storage op (supabase → {storage_schema_intel}.companion_findings), last 30 days. Report:
(1) items now unblocked or newly relevant given current state, 
(2) items that should graduate to real milestone work,
(3) items that are stale and should be bulk-closed.
Pre-filter to top 10 most relevant. Keep it brief.
```

Also query the task manager for **deferred items from past epic closes** (standalone issues, not in any milestone):
```
list_issues(team: "{task_team_id}", labels: ["deferred"])   # adapter op
Filter: projectMilestone = null
Sort by: priority DESC, createdAt ASC
```
For each, note: title, origin epic (from issue body `## Origin` section), priority, days since created.
These were explicitly punted by agents at epic close — they have a defined "Done Looks Like" and "Suggested Priority".
Present them grouped by project (Factory / ML / AI / etc.) alongside the parking lot items.

Present graduating items and promotable deferred items alongside the agent priority matrix in Phase 3.

### Phase 3: Prioritization (Interactive with Operator)

Walk through findings with Operator using AskUserQuestion (ONE at a time):

1. "Here are the {N} blockers. Which do we tackle in the next milestone vs defer?"
2. "These {N} debt items were flagged. Any you want prioritized?"
3. "These {N} parking lot items are now relevant. Promote any to this milestone?"
4. "These {N} deferred items from past epics have no milestone assigned. Promote any to this milestone's backlog? [List each with: title | origin epic | priority | days old | Done-looks-like]"
   - For each promoted item: assign it to the new milestone via the adapter `update_issue({ID}, { milestone: "{milestone_id}" })`
   - For each rejected item: leave milestone null — it stays in the CCB candidate pool for future cycles
5. "Based on the roadmap, what's the GOAL of the next milestone?"
6. For each decision, record in factory spec decisions table (§0.DN)

**Pre-decision advisor pass (run before locking in #5–#6):**

Before recording the milestone GOAL and locking architecture decisions, run two consultative skills to stress-test the direction:

1. **`{agents.scalability_audit}`** — invoke `Skill("{agents.scalability_audit}")` with the proposed milestone goal + the top 2–3 architecture decisions. Get back: which decisions are most likely to need a rewrite at 10x scale, and what shape that rewrite would take. Capture via `record_decision(...)` as the "Scale review" line on each decision row.

2. **`/advisor`** — for any decision where the Operator is uncertain or the agent's recommendation diverges from the obvious-default, consult `/advisor` with: (decision text, Operator's stated preference, the 2 alternatives considered, your recommended path). Use the advisor's response to refine the decision text BEFORE writing it to the decisions table. Document the advisor consult in the decision's rationale field.

Both are advisory — they don't block the decision, they just sharpen it.

### Phase 3.25: Z-Epic Decision (MANDATORY question)

Ask Operator:
```
Does this milestone need a Z verification epic ({milestone_id}Z)?

Z epics add human + machine end-to-end testing AFTER the HARDEN epic.
They define specific scenarios that a human must walk through (Human Proof)
and automated E2E tests that must pass (Machine Proof).

Recommended YES for: user-facing features, CV pipeline, ML model output,
  dashboard changes, tracker changes, API changes
Recommended NO for: pure infra, refactor, docs, internal tooling

Does {milestone_id} need a Z epic? [yes/no]
```

If YES, ask a second question:
```
Does this Z epic need a Human Proof walkthrough (Operator walks through every flow),
or machine tests only (automated Playwright + API smoke)?

  full        — Human Proof + Machine Proof (Operator interactive session required)
  machine-only — Machine Proof only (no Operator walkthrough needed)

Recommended FULL for: user-facing UI changes, new admin flows, role/permission changes
Recommended MACHINE-ONLY for: API-only changes, data pipeline output, CV/ML metrics

E2E mode? [full/machine-only]
```

Record both decisions. The E2E mode is passed to `/plan-milestone` as `E2E Mode: full | machine-only`
and controls which tasks the Z-epic gets. See `/plan-milestone` § Step 3f for Z epic templates.

### Phase 3.26: Test Coverage Per Epic (MANDATORY)

Naming the test file is no longer sufficient — Phase 3.26 now generates a full
**testing-scenarios block** for each feature epic AND spawns its **walkthrough
twin** in the master verification milestone (`master_verification_milestone`
in `.claude/project-context.md`, e.g. `VER001A`). This is what makes
`/plan-milestone`'s output "feature epic AND its verification twin" instead
of a promise to test later.

For each planned epic, ask:

```
For {epic_id} — {title}, what test file(s) prove it works?

  1. Name the file:  test_{milestone_lower}_{epic_short}.py
  2. What does it assert? (outcome-based, not operation-based)
     BAD:  "runs the hook"
     GOOD: "commit with 'DONE foo' on a stub function is blocked"
  3. Which test suite? unit / integration / canonical / contract / security / e2e
```

If Operator says "TBD" for any epic: flag it as a spec gap — the epic is not ready to implement.
If epic is infrastructure/config only with no testable outcome: require justification in ## Tests.

**Then, mechanically, for every feature epic (skip infra/config-only epics
already justified above):**

1. **Build the testing-scenarios block.** Assemble, in this exact structure,
   and write it into the epic's `## Testing Scenarios` section (this is
   IN ADDITION TO `## Tests` — `## Tests` names the file/assertion,
   `## Testing Scenarios` is the walkable spec):

   ```markdown
   ## Testing Scenarios

   ### Human-step skeleton
   1. {first user-visible action, e.g. "Navigate to /players/{id}"}
   2. {second step}
   3. {expected outcome, phrased as what the Operator/user SEES, not what the code does}

   ### Mechanical spec assignments
   - Unit:        {file/assertion from the Phase 3.26 Q&A above}
   - Integration:  {if applicable}
   - E2E:          {Playwright flow name, or "n/a — API-only, see Contract"}

   ### Edge categories (E1–E7 — instantiate each, "n/a" is a real answer)
   - E1 Empty/null input:       {concrete case for this epic, or "n/a — {why}"}
   - E2 Boundary values:        {concrete case, or "n/a — {why}"}
   - E3 Concurrent access:      {concrete case, or "n/a — {why}"}
   - E4 Permission/role denial: {concrete case, or "n/a — {why}"}
   - E5 Malformed/adversarial input: {concrete case, or "n/a — {why}"}
   - E6 Partial failure/rollback:    {concrete case, or "n/a — {why}"}
   - E7 Cross-org / multi-tenant leakage: {concrete case, or "n/a — {why}"}

   ### Role-matrix stub
   | Role       | Can see | Can do | Notes |
   |------------|---------|--------|-------|
   | {role 1}   |         |        |       |
   | {role 2}   |         |        |       |

   ### Spec clauses under test
   - {spec file}#{section} — {one-line claim this epic must satisfy}
   ```

   Every "n/a" MUST carry a reason — a bare "n/a" is a spec gap, treat like
   a Operator "TBD" above.

2. **Create the walkthrough twin issue.** In the task manager, create a
   child issue under `master_verification_milestone`:

   ```
   title: "[WALKTHROUGH] {epic_id} — {epic title}"
   parent: master_verification_milestone issue/epic
   body: copy of the ## Testing Scenarios block above, plus:
     Verifies: {epic_id}
     Status: Not Started
   labels: ["walkthrough", "milestone:{milestone_id}"]
   ```

   Link it bidirectionally: add `Verification twin: {walkthrough_issue_id}`
   to the feature epic's description, and `Verifies: {epic_id}` to the
   walkthrough issue (already above).

3. **Add the matrix row.** Append one row to
   `config/test_coverage_matrix.json` for this epic:

   ```json
   {
     "epic_id": "{epic_id}",
     "milestone_id": "{milestone_id}",
     "walkthrough_issue": "{walkthrough_issue_id}",
     "spec_clauses": ["{spec file}#{section}", "..."],
     "status": "planned"
   }
   ```

   If the matrix file doesn't exist yet (repo predates Phase 3.26), create it with
   `$schema_note` describing the row shape — this is what `/project-init`
   bootstraps going forward (see `/project-init` § bootstrap).

Record answers and include them in each epic's `## Tests` section when writing descriptions, AND the `## Testing Scenarios` section per above. Planning is not
done for an epic until both sections exist and the walkthrough twin issue id
is recorded.

### Phase 3.3: Machine / Agent / Model Assignment (Epic Level)

For each planned epic, assign execution context with **2 backups**. Present to Operator:

```
EPIC ASSIGNMENTS — {milestone_id}
Milestone Backup (if Claude unavailable): workhorse/codex/gpt-4.1
Ollama fallback (always available):       mothership/ollama/qwen3:32b

| Epic    | Primary                  | Backup 1                  | Backup 2                  | Rationale |
|---------|--------------------------|---------------------------|---------------------------|-----------|
| VERIFY  | workhorse/claude/sonnet  | mothership/ollama/qwen3:32b | auditor/gemini/2.5-flash | Routine   |
| {E1}    | {machine/agent/model}    | {machine/agent/model}     | {machine/agent/model}     | {why}     |
| HARDEN  | workhorse/claude/opus    | mothership/gemini/2.5-pro | workhorse/codex/gpt-4.1   | Deep      |
| {Z}     | mothership/claude/opus   | workhorse/gemini/2.5-pro  | mothership/cursor/sonnet  | Operator-int.  |

Agents:   claude | gemini | codex | cursor | ollama
Models:   opus, sonnet, haiku | 2.5-pro, 2.5-flash, 2.0-flash | gpt-4.1, gpt-4.1-mini | qwen3:32b, llama3.3:70b, deepseek-r1:32b, codestral:22b, mistral:7b
Machines: mothership, workhorse, auditor, any
⚠ Ollama = mothership ONLY (GPU required)
```

**Goal: keep costs down and all machines running.** Use the cheapest model/agent that
can handle the task. **Ollama is zero-cost — prefer it for any task it can handle.**

Default routing (see `/plan-milestone` § Step 3g for full catalog):

| Epic Type | Primary | Backup 1 | Backup 2 |
|-----------|---------|----------|----------|
| VERIFY | workhorse/claude/sonnet | mothership/ollama/qwen3:32b | auditor/gemini/2.5-flash |
| Standard code | workhorse/codex/gpt-4.1 | mothership/ollama/qwen3:32b | auditor/gemini/2.5-flash |
| Boilerplate | mothership/ollama/codestral:22b | workhorse/codex/gpt-4.1 | auditor/gemini/2.0-flash |
| Architecture | workhorse/claude/opus | mothership/gemini/2.5-pro | workhorse/codex/gpt-4.1 |
| UI/React | mothership/cursor/sonnet | workhorse/codex/gpt-4.1 | mothership/ollama/qwen3:32b |
| CV/ML | mothership/ollama/deepseek-r1:32b | workhorse/claude/sonnet | mothership/gemini/2.5-pro |
| Data/ETL | workhorse/codex/gpt-4.1 | mothership/ollama/qwen3:32b | auditor/gemini/2.5-flash |
| HARDEN | workhorse/claude/opus | mothership/gemini/2.5-pro | workhorse/codex/gpt-4.1 |
| Z (E2E) | mothership/claude/opus | workhorse/gemini/2.5-pro | mothership/cursor/sonnet |

**Rules:**
- Primary, Backup 1, Backup 2 must ALL use **different agents**
- Ollama = mothership ONLY. Never assign ollama to workhorse or auditor.
- Never pile all tasks on one machine when others are idle.
- Factory falls back automatically: Primary → Backup 1 → Backup 2

Operator can override any assignment. These propagate to child tasks via `/plan-milestone`.

Ask: "Any changes to the epic assignments?"

### Phase 3.5: Gate Review (Standing Agenda Item)

Review current gate levels and decide upgrades/downgrades based on last milestone:

```
Current Active Gates (per §0.D17):
  Epic Entry:  {current level}
  Epic Exit:   {current level}
  Task Entry:  {current level}
  Task Exit:   {current level}

Last milestone experience:
  - Gate noise (false positives)?
  - Things that slipped through?
  - Gates that blocked legitimate work?

Recommendation: upgrade / downgrade / hold for each gate?
```

**Gate tiers (§0.D17):**

| Gate | Tier 1 (minimum) | Tier 2 | Tier 3 (full vision) |
|------|----------------------|--------|---------------------|
| Epic Entry | Prior epic closed + deps met | + regression tests pass | + scope review agent |
| Epic Exit | Acceptance tests pass + Slack notify | + completion/spec audit (`{agents.completion_audit}`/`{agents.spec_audit}`) | + query-backed outcome (§0.D7) |
| Task Entry | `factory:ready` + basic DoR (Goal, size, spec-ref) | + full DoR (all 8 fields, §0.D12) | + review panel locked (§0.D5) |
| Task Exit | PR review loop (CR + 1 model) | + 2 model reviewers | + persona reviewer |

Operator decides tier per gate. Recorded as decision in spec.

### Phase 4: Milestone Planning

Once Operator defines the milestone goal:

1. **Define milestone acceptance criteria** — These are the TOP-LEVEL tests:
   ```markdown
   ## {milestone_id} Acceptance Criteria
   - [ ] Factory daemon runs 24h without intervention on workhorse
   - [ ] All PRs auto-reviewed and merged within 1h (no human needed for Lite tier)
   - [ ] Clone slots prevent branch conflicts on all machines
   - [ ] Budget gate actually stops spend at cap
   ```

2. **Generate epic breakdown** — **BLOCKING: MUST invoke `/plan-milestone` via the Skill tool.**
   ```
   /plan-milestone FCT003A "Factory reaches full autonomous operation"
   ```
   **DO NOT create epics/tasks via direct `save_issue` calls. ALWAYS use `/plan-milestone`.**
   `/plan-milestone` handles: VERIFY first epic, HARDEN last epic, test scaffold, Linear tickets,
   milestone labels, full DoR on every task, and cross-reference validation.
   
   This is NOT optional. This is NOT "call it internally if convenient." 
   If you skip `/plan-milestone` and create issues manually, you WILL produce incomplete 
   artifacts that fail the quality sweep — this has happened repeatedly (M0002A, M0003E CCB 2026-04-24).
   The Operator has explicitly required this gate. Skipping it is a trust violation.

2b. **Wire blockedBy relationships** — After `/plan-milestone` creates all epics, wire
    explicit `blockedBy` dependencies via Linear. Do NOT skip this step.
    Full convention: see `/plan-milestone` skill §3b.1 — blockedBy Convention.
    
    Standard pattern (wire after all epics exist):
    - VERIFY: no blockers
    - Feature epics: each `blockedBy: [VERIFY]` (add cross-deps if needed)
    - HARDEN: `blockedBy: [all feature epic IDs]`
    - Z epic: `blockedBy: [HARDEN]`
    - Cross-milestone: downstream VERIFY `blockedBy` upstream HARDEN
    
    ```
    # Example: wire HARDEN blocked by all feature epics
    update_issue({HARDEN_ID}, { blockedBy: [{E01_ID}, {E02_ID}, {E03_ID}, ...] })
    ```

3. **GATE: Verify epic task coverage** (BLOCKING — cannot proceed without passing):
   ```
   For each epic created in step 2 (in Linear):
     - Use the adapter op list_issues(team: "{task_team_id}") and filter by parentId
     - FAIL if any epic has 0 child tasks
     - FAIL if any epic (except HARDEN) has no REVIEW exit gate task (title contains "-REVIEW")
     - FAIL if any task is missing required labels: task, machine:*, model:*
     - FAIL if any task description is missing ## Goal section
   
   If ANY epic fails:
     - List the failing epics and what's missing
     - Re-run /plan-milestone for those epics
     - Re-check until all pass
     - DO NOT proceed to step 4 until this gate is green
   ```
   This gate exists because CCB Phase 4 previously created empty epics when interrupted.
   The root cause was advisory-only task generation with no enforcement checkpoint.

4. **Review execution diagram** — `/plan-milestone` generates an ASCII dependency graph
   showing the epic execution flow with BEN IDs, parallel branches, and machine/agent/model
   assignments. Present this to Operator for final review before committing.

5. **Commit test scaffold to develop** (§0.D23) — RED tests committed now, Operator present.

5. **Set active gate levels** on the milestone tracking issue based on Phase 3.5 decisions.

### Phase 6: Save & Report (Three-Tier Storage)

CCB records are stored in three places, each serving a different purpose:

1. **Storage backend — full detailed record** (supabase → `{storage_schema_intel}.ccb_sessions`; no-op under `storage_backend: none`):
   - Persist via `record_ccb_session({ milestone_id, date, agent_findings, priority_matrix, decisions, gate_levels, acceptance_criteria, blockers, debt, parking_lot_actions })`
   - This is the queryable source of truth for CCB history

2. **Task-manager milestone issue** — Summary posted as a comment on the milestone issue via the adapter `add_comment`:
   - Decisions made (numbered, with rationale)
   - Epics created (with {task_prefix} issue numbers)
   - Key metrics (blocker count, spec compliance)
   - Gate levels set
   - Acceptance criteria
   - Link to Supabase record ID
   - **Do NOT post to GitHub** — Linear is the planning layer.

3. **Prompt assembly context** — (wired in E0050+, not manual):
   - `prompt_assembler.py` queries active CCB record
   - Injects `## CCB Context` section into factory prompts
   - Workers see: milestone goal, active gates, acceptance criteria

4. **Stored task plans** — Write one plan per task created or approved in this CCB session (supabase → `{storage_schema_qa}.task_plans`; no-op under `storage_backend: none`):
   ```
   for each task:
     save_task_plan({task_ID}, { milestone: "{milestone_id}", epic: "{epic_ID}",
       goal, steps, acceptance, planned_agent, planned_model, planned_machine, status: "planned" })
   ```
   - This feeds the PR review cross-check: reviewers `get_task_plan({task_ID})` to verify implementation matches the approved plan.
   - Only write after Operator confirms the task list (post Phase 3).

**Do NOT create markdown files in the repo for CCB minutes.**

### Phase 6.5: BLOCKING Quality Sweep (Runs Before Report)

Before declaring "CCB Complete", sweep ALL artifacts created or touched by this CCB.
This gate catches everything — milestones, epics, tasks, subtasks. No exceptions.

```
For the active milestone:
  1. MILESTONE ISSUE: verify body has:
     - [ ] ## Goal (not empty)
     - [ ] ## Acceptance Criteria (with checkboxes)
     - [ ] Test scaffold committed: tests/milestones/m{id}/
     - [ ] VERIFY epic referenced (first)
     - [ ] HARDEN epic referenced (last)

  2. ALL EPICS under this milestone: verify each has:
     - [ ] ## Goal (not empty)
     - [ ] ## Outcome with Measured By / Baseline / Target
     - [ ] ## What Should Happen When This Epic Is Done
     - [ ] ### Acceptance Tests (with test file path)
     - [ ] ### Tasks (with issue numbers)
     - [ ] ## What Actually Happened placeholder
     - [ ] ## Auditor Comments placeholder
     - [ ] Labels: epic, priority:*, milestone:*, area:*, lane:*
     - [ ] ### Exit Criteria defined
     - [ ] ### Gate Level defined

  3. ALL TASKS under each epic: verify each has:
     - [ ] ## Goal (not empty)
     - [ ] ## Steps (numbered, with file paths)
     - [ ] ## Outcome with Measured By
     - [ ] ## Guardrails
     - [ ] ## Acceptance Criteria (with checkboxes)
     - [ ] Labels: factory:task, status:todo, machine:*, model:*, 
           autonomy:*, priority:*, area:*, lane:*, milestone:*
     - [ ] Parent epic referenced in body

  4. CROSS-REFERENCES: verify:
     - [ ] Every task listed in its epic's ### Tasks section
     - [ ] Every epic listed in milestone issue
     - [ ] No orphan tasks (task exists but not in any epic)
     - [ ] No orphan epics (epic exists but not in milestone)

  5. SoE (Statement of Evidence) — per TEST_PROTOCOL_SPEC.md:
     - [ ] Every epic has a ## SoE section OR ## Acceptance Tests section
     - [ ] Every task has ## Acceptance Criteria with checkboxes
     - [ ] Milestone tracking issue has ## Acceptance Criteria
     - [ ] At least one Machine Proof item per engineering epic
     - [ ] Human Proof items for any UI/UX epic

HOW TO CHECK (use the task-manager adapter):
  list_issues({ team: {task_team_id} }) — filter by milestone label
  For each epic: get_issue({ID}) to read full description
  Parse body sections and label set.
  GitHub tracking issue: gh issue view #{tracking_issue} --json body,labels
  
  Report format:
  QUALITY SWEEP — {milestone_id}
  ✓ Milestone: {PASS|FAIL} — {details}
  ✓ Epics: {N}/{total} pass — {failing epic numbers + what's missing}
  ✓ Tasks: {N}/{total} pass — {failing task numbers + what's missing}  
  ✓ Cross-refs: {PASS|FAIL} — {orphans found}

  IF ANY FAIL:
    - Fix inline (update via the adapter `update_issue` for epics/tasks, gh for tracking issue)
    - Re-run sweep
    - DO NOT declare "CCB Complete" until sweep is 100% green
```

This gate exists because M0002A epics were created without Outcome sections, 
tasks were created without factory labels, and nothing caught it until the Operator did.

4. **Report to Operator:**
   ```
   CCB Complete — {milestone_id} Planned
   
   Milestone: {goal}
   Epics: {count} ({count} feature + 1 verify + 1 hardening)
   Tasks: {count} total
   Acceptance Criteria: {count} top-level tests (committed to {main_branch})
   Blockers addressed: {count}
   Parking lot items promoted: {count}
   Active gates: {tier per gate}
   Supabase record: {session_id}
   
   Ready for: factory daemon auto-picks up factory:ready tasks
   ```

5. **Clear session context:**
   ```bash
   source {scripts_dir}/infra/get_session_context.sh && clear_session_context
   ```

### Phase 7: Plan Lock (CCB Close Gate)

The plan is NOT locked until these agents run and pass. This is the formal CCB close.

**7a: Run doc-sync agent**
Verify all documentation touched by this milestone's scope is current:
```
Agent(subagent_type: "documentation-engineer", prompt: "Run doc-sync for milestone {milestone_id}.
Check that docs referenced in the planned epics/tasks are not stale. Specifically verify:
- MASTER_ROADMAP.md reflects this milestone
- Any spec files referenced in epic ## Spec Section fields exist and are current
- config/doc_mappings.json entries are valid
Report stale docs that need updating BEFORE work begins.")
```

**7b: Run rules-audit agent**
Verify all created Linear issues comply with CLAUDE.md rules:
```
Agent(subagent_type: "rules-audit", prompt: "Verify the {count} tasks created 
for milestone {milestone_id} don't violate any CLAUDE.md rules. Check for:
- No iterrows patterns in ## Steps
- No client-side aggregation patterns
- No god object designs (files > 2000 lines)
- Goal filter compliance in any ETL-related tasks
- Key format compliance in any schema-related tasks
Report violations that must be fixed before the plan is locked.")
```

**7c: Decision sweep → storage (falsification-gated)**

A decision does not lock without verification scenarios attached. For each
decision captured during this CCB session, before writing it:

1. Ask (or derive from the Phase 3.26 testing-scenarios blocks already
   produced for the epics this decision spawns): "What observation would
   prove this decision WRONG?" — a falsification criterion, not a
   confirmation criterion. Bad: "the feature works." Good: "cross-org query
   returns rows from another org's `team_id`."
2. Attach 1+ concrete verification scenarios (reuse the epic's
   `## Testing Scenarios` E1–E7 rows where the decision maps to a spawned
   epic; write inline ones for decisions with no spawned epic — e.g. a
   pure architecture call).
3. Only THEN write the decision:

```
for each decision:
  if not decision.verification_scenarios:
    STOP — decision does not lock. Go back to step 1.
  record_decision({
    title: "{decision_text}",
    type: "{category}",
    ref_id: "{milestone_id}-CCB",
    body: "{decision rationale}\n\n## Verification scenarios (falsification criteria)\n{scenario list}",
  })
```

This closes the loop from Phase 3.26: epics get testing-scenarios blocks,
decisions get falsification criteria, both trace back to the same spec
clauses. A decision recorded without this section is not a locked decision
— it's a note.

**7d: Idea sweep → storage**
Write ANY ideas surfaced during this CCB via `record_idea(...)` (supabase → `{storage_schema_intel}.ideas`).

**7e: Declare Plan Locked**
```
CCB PLAN LOCKED — {milestone_id}

  Milestone: {goal}
  Epics:     {count} | Tasks: {count}
  Decisions: {decision_count} written via record_decision (storage)
  Doc-sync:  {PASS|FAIL — details}
  Compliance: {PASS|FAIL — details}
  
  Storage:   ccb_sessions record ID: {session_id}
  Task mgr:  All issues created with labels and backlinks
  
  Plan is frozen. Changes require Operator approval or a new /ccb review.
  
  Ready to start: /milestone start {milestone_id}
```

**If doc-sync or rules-audit FAIL:** fix the issues before declaring locked.
The plan cannot be frozen with known violations.

**7f: Find or Create Milestone Master Tracker Issue**

**First: search for an existing tracker before creating.**

```
results = search_issues({ query: "[{milestone_id}] 📋 MASTER TRACKER", label: "milestone-tracker" })
```

**If tracker found (reopened / updated milestone):**
- Read the existing tracker body to understand current state
- Update its body with current epic inventory — reflect any epics already done (✅), in-progress (⏳), or newly added (🔲)
- Update decisions table with any new decisions from this CCB session
- Add a comment: `CCB session {date}. Plan {updated/locked}. Epic list re-evaluated.`
- Note the existing `{task_prefix}-{tracker_number}` — skip to "Set milestone description" below

**If tracker NOT found (new milestone):**
```
create_issue({
  title: "[{milestone_id}] 📋 MASTER TRACKER — {milestone_goal}",
  team: {task_team_id},
  project: "{project}",
  milestone: "{milestone_linear_id}",
  priority: 1,
  labels: ["milestone-tracker", "milestone:{milestone_id}"],
  description: {full tracker body — see /milestone start Step 3b template}
})
```

Key fields to populate at CCB time:
- Epic inventory table: all epics from this CCB, status all 🔲, with blast radius and confidence scores
- Dependency Mermaid graph from the ordering decided in Phase 3
- Decisions table: all decisions made in this CCB session
- Session estimate: total estimated sessions (NOT weeks)
- Acceptance criteria: from Phase 3 / Step 2
- Health emoji: 🟢 (just planned)

Link the tracker to every epic:
```
for each epic {ID}:
  update_issue({ID}, { relatedTo: ["{tracker_id}"] })
```

**Set milestone Linear description** (always — whether tracker was found or created):
```
**Goal:** {one sentence}
**Why:** {one sentence}
**Master tracker:** {task_prefix}-{tracker_number} (always reference as {milestone_id} / {task_prefix}-{tracker_number})
```

Print: `Master tracker: {task_prefix}-{tracker_number} — bookmark this, not the milestone page.`


---

## `/ccb review {CODE###X}` — Milestone Review

Mid-milestone health check. Includes quality enforcement.

1. **Quality sweep** — Run Phase 6.5 quality sweep on ALL milestone artifacts (milestone, epics, tasks, subtasks). Fix any that fail before proceeding. This catches drift and issues created since the CCB opened.
2. Read milestone's acceptance criteria and active gate levels
3. Run `{agents.completion_audit}` + `{agents.spec_audit}` on the milestone's epics only
4. Report: % complete (honestly), blockers, ETA assessment
5. Check companion findings since milestone started — any new issues?
6. Suggest course corrections if needed

---

## `/ccb close {CODE###X}` — Milestone Close

Formal closure with hardening verification. This is where intent meets reality.

### Step 0: Quality Sweep (BLOCKING — runs first, before any close logic)

Run the EXACT same quality sweep from Phase 6.5 of `/ccb open`. 
This catches drift — epics/tasks may have been modified since the CCB opened.
Sweep covers: milestone issue, ALL epics, ALL tasks, ALL subtasks, cross-references.

If ANY item fails the quality check:
- Fix it inline (update issue body/labels)
- Re-run sweep
- DO NOT proceed to Step 1 until sweep is 100% green

This is not optional. This is not "we'll fix it later." 
M0002A shipped with broken templates because this gate didn't exist.

### Step 1: Run Acceptance Tests
```bash
pytest tests/milestones/{milestone_id}/ -v --tb=short
```
Record which pass (GREEN) and which fail (RED).

### Step 2: Run Auditor Agents (Parallel)

**`{agents.completion_audit}`** — audit every epic's claimed completions against actual code
**`{agents.spec_audit}`** — check every spec section touched by this milestone
**`{agents.scalability_audit}`** — any new scale risks introduced?

### Step 3: Fill "What Actually Happened" on Every Epic Issue

Post a comment on each epic via the adapter `add_comment`:
```
## Auditor Report — Epic Close

### What Actually Happened
- {outcome 1 — honest}
- {outcome 2 — what shipped vs planned}

### {agents.completion_audit}: {findings, cite file:line}
### {agents.spec_audit}: {findings, cite spec section + compliance %}
### Test Results: {which pass, which fail}
### Verdict: {PASS | PARTIAL | FAIL}
```

### Step 4: Fill "What Actually Happened" on Milestone Tracking Issue

Post on the GitHub milestone tracking issue via `gh issue comment` (this is the ONE GitHub issue):
```
## Milestone Close Report — {milestone_id}

### What Actually Happened
- Epic 1: {DONE | PARTIAL | FAILED} — {1-line}
- Epic 2: {DONE | PARTIAL | FAILED} — {1-line}

### Global Tests: pytest tests/milestones/{milestone_id}/ — {X}/{Y} passing
### {agents.completion_audit}: {top-line}
### {agents.spec_audit}: {spec compliance % across milestone}
### {agents.scalability_audit}: {scale assessment}
### Regressions / Deferred: {list}
### Verdict: {PASS | PARTIAL}
```

### Step 5: Gate Decision

- **ALL criteria pass + no critical findings:**
  - Move Linear epics to "Done" status
  - Deferred items → P0001A parking lot in Linear (feed next CCB)
  - Report final stats to Operator

- **ANY criteria fail OR critical findings:**
  - Cannot close. List specific failures.
  - Create fix tasks within hardening epic.
  - Re-run after fixes.
  - Operator can override: "close anyway, defer {items} to next milestone"

### Step 6: Handoff to Next CCB

Deferred/failed items from this milestone automatically surface in the next `/ccb open` Phase 1 sweep. The close report on the milestone issue IS the handoff document.

---

## Key Rules

- CCB is Operator-interactive. Never auto-decide priorities.
- Every finding must cite source (agent + file:line)
- Decisions captured in REAL-TIME to factory spec decisions table
- P0001A parking lot reviewed every CCB (§0.D22)
- Gate levels reviewed every CCB — upgrade/downgrade/hold (§0.D17)
- Milestone ALWAYS has VERIFY first epic + HARDEN last epic (+ optional Z epic if Operator approved)
- Epic lifecycle managed via `/epic start` and `/epic close` — CCB plans, `/epic` executes
- One epic = one branch = one PR. Start new session between epics.
- Hardening epic runs acceptance criteria defined at CCB
- Never mark a milestone closed without ALL acceptance criteria passing
- Close report fills "What Actually Happened" on Linear epics (via comments) and GitHub tracking issue
- Deferred items flow to next CCB via parking lot
- The sweep phase uses PARALLEL agents — never sequential
- Companions always running, feed evergreen when milestone work dry (§0.D18)
- Milestone IDs use letter suffixes (M0003A, M0003B) — NEVER decimal (§0.D21, CLAUDE.md)
- **Linear is the input layer.** Epics/tasks in Linear. GitHub for code/PRs/one tracking issue only.

## Judgment weave (see /judgment)

- **Open with `/drift`** on the specs and status claims this board is about to trust — a CCB planning on top of a lying spec compounds the lie.
- Every architectural pick in the session goes through **`/door`**: two-way doors get decided in the room, one-way doors get the full five questions.
- The board does not adjourn until the chosen plan has a **`/premortem`** and its top risks carry **`/gate`** lines with numeric thresholds.
- All verdicts from the session → **`/verdict log`**.
