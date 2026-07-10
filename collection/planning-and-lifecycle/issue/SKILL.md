---
name: issue
origin: authored
public: true
description: Issue (task) lifecycle management — start work on a task (read plan, move to In Progress) or mark it done (commit, update plan status, mark Done in the task manager). Use at the beginning and end of each task within an epic.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, mcp__claude_ai_Linear__get_issue, mcp__claude_ai_Linear__save_issue, mcp__claude_ai_Linear__save_comment, mcp__claude_ai_Supabase__execute_sql
argument-hint: [start|done] {task_id}
---

> **Factory mode:** If `CLAUDE_AUTO` is set in the environment, skip these instructions and instead run `{scripts_dir}/skills/issue.sh "$@"` via Bash — the shell script handles autonomous dispatch. (`scripts_dir` from project-context; default `scripts`.)

# Issue (Task) Lifecycle Management

> **One task = one commit on the epic branch.**
> `/issue start` reads the plan and moves the task to In Progress. `/issue done` commits the work and marks the task Done in the task manager.

## Step 0: Load project context (REQUIRED — run first)

This skill is repo/tool-agnostic. Resolve all couplings from config before doing anything:

1. Read `.claude/project-context.md`. If missing → ask the user to run `/project-init` first.
2. From it, take: `task_manager`, `task_prefix`, `task_team_id`, `main_branch`, `scripts_dir`, `storage_backend`, `factory_enabled`.
3. Load the **task-manager adapter** `.claude/skills/_shared/adapters/{task_manager}.md` — use its operations (`get_issue`, `update_issue`, `add_comment`, …) for ALL task-manager actions below. Never call a task-manager API directly.
4. Load the **storage backend** `.claude/skills/_shared/storage/{storage_backend}.md` — use its operations (`get_task_plan`, `set_task_plan_status`, …) for ALL memory actions. If `storage_backend` is absent → treat as `none` (reads empty, writes discarded; skill still works).

**Notation below:** `{ID}` = a task id formatted `{task_prefix}-{n}` (Acme profile: `APP-123`). Adapter calls are shown as abstract operations; the loaded adapter file maps them to the concrete tool (for `linear`, `get_issue(ID)` → `mcp__claude_ai_Linear__get_issue`; for `github`, `gh issue view`; etc. — see `_shared/mcp-tool-map.md`).

## Subcommands

| Command | Purpose |
|---------|---------|
| `/issue start {ID}` | Begin a task — read plan, move to In Progress, show steps |
| `/issue status {ID}` | Read-only snapshot — task ready state, blockers, parent epic context, no state changes |
| `/issue done {ID}` | Close a task — commit, mark Done, update plan status |

---

## `/issue status {ID}` — Read-Only Snapshot

**Read-only. No task-manager mutations. No git ops.**

```
get_issue(ID, includeRelations: true)
```

If the issue has a parent epic, also fetch it for context:
```
get_issue(parentId)
```

Print the task's ready/blocked state, parent context, and the steps the task body declares:

```
TASK {ID} — {title}
Status: {current status}
Parent epic: {epic ID} — {epic title} ({epic status})
Branch: {gitBranchName or "—"}

GATE STATE
─────────────────────────────────────────────────────────────────────
  Blocked by:  {list of open blockedBy ticket IDs, or "—"}
  Blocks:      {list of tickets this blocks, or "—"}
  Ready:       {YES if not Done and no open blockers, else NO}

ACCEPTANCE CRITERIA
─────────────────────────────────────────────────────────────────────
  (Parsed from issue body ## Acceptance Criteria section. Show as checkboxes.)

STEPS
─────────────────────────────────────────────────────────────────────
  (Parsed from issue body ## Steps section. Numbered list, first 10 items.)

EXECUTION CONTEXT
─────────────────────────────────────────────────────────────────────
  Machine: {label machine:* or "any"}
  Model:   {label model:* or "—"}
  Size:    {label size:* or "—"}
```

End with:
```
Suggested next: {one-line — "Run /issue start {ID}" if ready, or "Blocked: wait on {ticket} before starting" if not.}
```

---

## `/issue start {ID}` — Begin Task

### Step 1: Read Task from the task manager

```
get_issue(ID)
```

Extract:
- **Goal** — what must be delivered
- **Steps** — ordered implementation steps
- **Required Reading** — files/docs to read first
- **Acceptance Criteria** — the checkboxes that must all be true
- **Model / Machine** — execution context
- **Parent epic** — the branch to work on

### Step 1a: Body Freshness Check

Verify the task description has all required sections:

| Section | Required |
|---------|----------|
| `## Goal` | 2-4 sentences (not just title restated) |
| `## Context` | 3+ sentences |
| `## Steps` | ≥3 numbered items with file paths |
| `## Required Reading` | ≥3 real file paths (verify with `test -f`) |
| `## Acceptance Criteria` | ≥3 checkboxes |
| `## Execution Context` | Model, machine, agent assigned |

If ≥2 sections are missing or contain `{placeholder}` text:

```
⚠ TASK BODY IS INCOMPLETE — {ID}
  Missing: {list}
  Run /plan-milestone {milestone} --update to fix, or continue with incomplete instructions?
```

### Step 1aa: Enforce Branch (CRITICAL)

Read the parent epic to get the correct branch name from `## Git`:

```bash
CURRENT=$(git branch --show-current)
EXPECTED="{type}/{epic_ID}-{short-name}"
```

**If on wrong branch:**
```
⚠ WRONG BRANCH
━━━━━━━━━━━━━━
  Current:  {CURRENT}
  Expected: {EXPECTED}

  Switching to {EXPECTED}...
```

Checkout the correct branch. If it doesn't exist, create it from `{main_branch}` (project-context; default `main`).

**Always print the active branch:**
```
📍 Branch: {EXPECTED}
```

### Step 1b: Validate Model & Agent Match (CRITICAL)

Check the task's `model:` and `machine:` labels against the actual runtime.

**If the task is assigned to a non-Claude agent (Codex, Gemini, Cursor, Ollama):**

```
⚠ AGENT MISMATCH
━━━━━━━━━━━━━━━━
  Running:  Claude ({current_model}) on {current_machine}
  Assigned: {agent} ({model}) on {machine}
```

Use `AskUserQuestion` with options:
- **Run with Claude anyway** — override the assignment, proceed with current model
- **Generate brief for {agent}** — run `/brief {ID}` to create a copy-paste prompt, then STOP
- **Skip this task** — mark as deferred, move to next task

**If the task is assigned to Claude but a different model tier:**

```
⚠️  MODEL MISMATCH
━━━━━━━━━━━━━━━━━━
  Running:  {actual_model} on {actual_machine}
  Task expects: {task_model} on {task_machine}

  Continue with {actual_model}? (y/n)
```

Use `AskUserQuestion` to confirm. Options:
- **Continue** — proceed with current model
- **Skip** — mark task as deferred, move to next task
- **Update assignment** — change the task's model label to match current

### Step 2: Load Task Plan (if available)

```
get_task_plan(ID)
```

Returns the stored plan (title, goal, steps, acceptance_criteria, estimated_tokens, status) or
null. **If it returns null** (no stored plan, or `storage_backend: none`), use the issue
description from the task manager as the plan — never block on missing storage.

### Step 3: Verify Branch Context

Confirm the current branch is the parent epic's branch:

```bash
git branch --show-current
```

If not on the correct branch, switch:
```bash
git checkout {epic_branch_name}
```

### Step 4: Read Required Files

For each item in `## Required Reading`:
- Read the file/section specified
- Do NOT proceed to implementation without reading these first

### Step 5: Move Task to In Progress

```
update_issue(ID, { state: "In Progress" })
```

### Step 5a: Enhanced Advisors pre-task gate (only if active)

> Factory/quality overlay — runs only when the marker file exists. Skip entirely otherwise.

Check whether the parent epic activated the Enhanced Advisors bundle:

```bash
test -f .claude/.enhanced-advisors-active && echo "active" || echo "inactive"
```

**If active**, run two pre-task gates before showing the task brief:

1. **`rules-audit`** on the task scope. Pass it the task's `## Steps`, `## Files to Create`, and `## Files to Modify` so it can flag anything that would violate the project rule file (e.g. CLAUDE.md / AGENTS.md) before you commit to an approach.

   ```
   Skill("rules-audit", args: "{ID} pre-task")
   ```

   If the checker returns BLOCKING findings: STOP, surface to Operator, do not begin work. Address the approach gap first.

2. **`/advisor` natural-language trigger** — internalize this rule for the remainder of this task:
   > "If the task's `## Steps` reference files, functions, or concepts I don't fully understand, OR if `## Required Reading` reveals context that contradicts the task description, consult `/advisor` with the ambiguity + my proposed interpretation before writing code."

Print one line confirming the gate result:

```
ADVISORS — {ID} pre-task
  Compliance check: {PASS | BLOCKING | ADVISORY}
  Advisor trigger:  armed
```

**If inactive** (no marker file): skip Step 5a entirely.

### Step 6: Show Task Brief

```
TASK {ID} — {title}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Branch:  {epic_branch_name}

  Primary:  {machine}/{agent}/{model}
  Backup 1: {b1_machine}/{b1_agent}/{b1_model}
  Backup 2: {b2_machine}/{b2_agent}/{b2_model}

GOAL
{goal from task description}

STEPS
{numbered steps}

ACCEPTANCE CRITERIA
{checkboxes}

Status: In Progress — begin work.
```

---

## `/issue done {ID}` — Close Task

### Step 1: Run Acceptance Criteria Check (OUTCOME-BASED — CRITICAL)

For each item in the task's `## Acceptance Criteria`:
- Verify each checkbox is genuinely satisfied
- Do NOT mark done if any checkbox is false
- If a checkbox cannot be satisfied, report it and STOP

**Outcome verification rules:**
- Acceptance criteria must assert OUTCOMES, not OPERATIONS.
- "Migration applied successfully" is NOT passing — "table X has column Y with type Z" IS.
- "Script ran without errors" is NOT passing — "query returns expected rows" IS.
- "File was created" is NOT passing — "file contains the required exports and passes type-check" IS.

**For migration/schema tasks specifically:**
- Query the live database to verify schema state AFTER the migration.
- Check: columns exist, types are correct, constraints present, FKs valid, RLS enabled.
- Use `SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '...'` or equivalent.
- A `DROP COLUMN IF EXISTS` that silently no-ops is a FAILURE, not a success.

If acceptance criteria on the task are operation-based (e.g. "run migration X"), rewrite them as outcome-based before checking, and note the rewrite in the report.

### Step 2: Stage and Commit

**Step 2a: Pre-commit advisor screens (only if Enhanced Advisors active)**

If `.claude/.enhanced-advisors-active` exists, screen the diff before staging:

```bash
LINES_CHANGED=$(git diff --shortstat | grep -oE '[0-9]+ insertions' | grep -oE '[0-9]+' | head -1)
TOUCHES_LOGIC=$(git diff --name-only | grep -vE '^tests/|^\.claude/|\.md$|\.json$' | head -1)
```

| Condition | Action |
|-----------|--------|
| `LINES_CHANGED > 100` | Run `Skill("code-simplifier")` on the diff before committing. Apply suggestions or commit with a one-line rationale why you didn't. |
| `TOUCHES_LOGIC` non-empty | Run `Skill("find-bugs")` on the changed non-test files. Address BLOCKING findings before commit; note ADVISORY findings in the commit message. |
| Neither | Skip — small / docs-only / test-only changes don't need extra screening. |

If neither condition matches OR `.claude/.enhanced-advisors-active` is absent: proceed directly to staging.

Commit all changes on the current epic branch:

```bash
git add {specific_files_changed}
git commit -m "[{TYPE}] {ID}: {task_title_brief}"
```

Choose the correct `{TYPE}` — do NOT default to FEAT:
- `FEAT` — new functionality
- `FIX` — bug fix
- `REFACTOR` — structural change, no new behavior
- `DOCS` — documentation only
- `TEST` — test additions/changes
- `CHORE` — configuration, tooling, cleanup

### Step 3: Update Task Plan Status

```
set_task_plan_status(ID, "done", { commit_sha: "{commit_sha}", completed_at: now })
```

This is a no-op under `storage_backend: none` — never blocks completion.

### Step 4: Mark Done in the task manager

```
update_issue(ID, { state: "Done" })
```

**NEVER mark Done unless:**
- All acceptance criteria are truly satisfied
- Code physically exists on the epic branch
- Commit was made in Step 2

A stub is NOT done. A TODO is NOT done.

### Step 5: Report

```
{ID} DONE — {title}

Commit: {sha} on {branch}
Acceptance criteria: {count}/{count} passing

Next task: {next_ID} — {title}
  Primary:  {machine}/{agent}/{model}
  Backup 1: {b1_machine}/{b1_agent}/{b1_model}
  Backup 2: {b2_machine}/{b2_agent}/{b2_model}
Run: /issue start {next_ID}

(Or run /epic close {epic_ID} if all tasks are Done)
```

---

## Key Rules

- ALWAYS read `## Required Reading` before writing code
- NEVER mark Done without proof — all acceptance criteria must be true
- ALWAYS commit before marking Done — no ghost completions
- Work on the PARENT EPIC'S branch — never create a new branch for a task
- Commit format: `[TYPE] {ID}: {description}` — always include the task id
- All task-manager and storage actions go through the loaded adapter/backend — never hardcode a tool, prefix, or table
- If `get_task_plan` returns null, the task manager is the source of truth — no blocking
- After all tasks in an epic are Done, run `/epic close {epic_ID}`

## Judgment weave (see /judgment)

- **Done requires a refutation pass** (lightweight `/refute`): one falsifiable claim, one executed break-attempt, verdict + evidence in the done comment. Ten lines, not a ceremony — but a claim with no executed check stays PARTIAL.
- Commit messages claiming fix/done carry an `Evidence:` line (the claim-evidence hook enforces this where installed).
