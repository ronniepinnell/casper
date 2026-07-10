---
name: brief
origin: authored
public: true
description: Generate a copy-paste prompt to brief a non-Claude agent (Codex, Gemini, Ollama, Cursor) on an epic or task. Auto-triggers when /epic start detects a model mismatch. Also callable directly.
allowed-tools: Read, Write, Glob, Grep, Bash, mcp__claude_ai_Linear__get_issue, mcp__claude_ai_Linear__list_issues, mcp__claude_ai_Linear__save_comment
argument-hint: {task_prefix}-{epic_id}
---


> **MCP Tool Map (Gemini/Codex):** See `.claude/skills/_shared/mcp-tool-map.md` for tool name equivalents. Linear: `get_issue`/`update_issue`/`create_issue`/`list_issues`/`search_issues`. Supabase: use `python3 {scripts_dir}/infra/run_sql.py "<SQL>"` via Bash.


# Agent Briefing Generator

> When the assigned agent isn't Claude, don't run the epic — generate the prompt to hand off.

## When This Skill Runs

1. **Auto-invoked** by `/epic start` when it detects the epic's Execution Context specifies a non-Claude agent/model
2. **Manually invoked** via `/brief {ID}` when the Operator wants a ready-to-paste prompt for another agent

## Execution

### Step 1: Read the Epic

```
get_issue(id: "{ID}")
```

Extract from the epic description:
- **Title** and **Goal** (first paragraph of `## Goal`)
- **Branch name** from `## Git`
- **Milestone** name
- **Machine / Agent / Model** from `## Execution Context`
- **Acceptance tests** file path
- **Dependencies** — list their {ID} and status
- **Tasks** — list all child task identifiers
- **Area** — infer from labels (dashboard, etl, schema, factory, api, tracker, cv)

### Step 2: Read All Child Tasks

For each child task, call:
```
get_issue(id: "{task_prefix}-{task_id}")
```

Extract from each task:
- Title
- `## Goal` (first sentence)
- `## Steps` (full text)
- `## Required Reading` (if present)
- `## Outcome` (verification command or test)

### Step 3: Detect Area Rules

Map epic labels to `rules/areas/` files:

| Label contains | Rules file |
|---------------|------------|
| dashboard, ui, brand | `rules/areas/dashboard.md` |
| etl, pipeline | `rules/areas/etl.md` |
| schema, database | `rules/areas/schema.md` |
| factory | `rules/areas/factory.md` |
| api | `rules/areas/api.md` |
| tracker | `rules/areas/tracker.md` |
| cv, vision | `rules/areas/cv.md` |

If no label matches, default to no area-specific rules file.

### Step 4: Generate the Prompt

Output a fenced code block containing the complete prompt. The prompt follows this structure:

```markdown
## Task: [{MILESTONE}] {Epic Title} ({{ID}})

You are working on {project_name} ({one-line product description}).

### Required Reading (read these files BEFORE writing any code)

1. `.agents/reference/lifecycle_process.md` — full lifecycle process (git flow, telemetry, checks)
2. `CLAUDE.md` — project rules (CRITICAL, never violate)
3. `rules/BASE.md` — core engineering rules
{4. `rules/areas/{area}.md` — area-specific rules (if applicable)}
{5. any files from tasks' ## Required Reading sections, deduplicated}

### Epic Details

- **Epic:** {ID} — {title}
- **Branch:** `{branch_name}` (branch from `develop`)
- **Milestone:** {milestone}
- **Acceptance tests:** `{test_file_path}`

### Goal

{Full ## Goal text from epic description}

### Outcome (how to verify you're done)

{Full ## Outcome text from epic description}

### Tasks (work in order, one commit per task)

#### Task 1: {task_prefix}-{t1} — {title}
**Goal:** {goal}
**Steps:**
{steps from task description}
**Verify:** {outcome/test from task description}
**Commit:** `[{TYPE}] {task_prefix}-{t1}: {description}`

#### Task 2: {task_prefix}-{t2} — {title}
...

### Process

Follow `.agents/reference/lifecycle_process.md` exactly:
1. `git checkout develop && git pull && git checkout -b {branch_name}`
2. Work each task, commit after each one passes verification
3. Run acceptance tests: `pytest {test_file} -v`
4. Create PR to develop: `gh pr create --base develop --title "[{MILESTONE}] {Epic Title}"`
5. Do NOT merge — wait for Operator approval
6. Post results as a comment on the PR

### Rules (from CLAUDE.md — violations are rejected)

- Never use `.iterrows()` on DataFrames — use vectorized ops
- Goal filter: `(event_type == 'Shot') & (event_variant == 'Shot_Goal')` — never `event_type == 'Goal'`
- No client-side aggregation in React/Node — use SQL views
- No files over 2,000 lines
- No hardcoded brand strings — import from `@/lib/brand`
- Commit format: `[TYPE] {task_prefix}-{task_id}: {description}`
- Never include "Closes #XX" or "Generated with Claude Code" in PRs
```

### Step 5: Add Agent-Specific Notes

Append a section based on the target agent:

**Codex (gpt-4.1):**
```
### Codex Notes
- You have full filesystem access. Read the Required Reading files directly.
- Use `gh` CLI for PR creation (already authenticated).
- **Commit after EACH numbered step — not just at task completion.** Run the step's test first, then commit. Max 5 changed files per commit.
- If a step requires a database, start `sandbox-postgres` first: `docker compose up -d sandbox-postgres`

### When Done — Report Results
1. Print your full completion summary in chat (tasks completed, PR number, test results)
2. Post a completion reply to this Linear issue:
   ```bash
   python3 {scripts_dir}/infra/linear_comment.py {ID} "## ✅ Completion Report

   **Tasks:** {N}/{N} Done
   **PR:** #{pr_number} — {url}
   **Tests:** {pass}/{total} passing

   **Delivered:**
   - {item 1}
   - {item 2}

   **Blockers/Deferred:** {none or list}
   "
   ```
   - If script fails (no LINEAR_API_KEY), skip — Operator will capture from chat
```

**Gemini (2.5-pro / 2.5-flash):**
```
### Gemini Notes
- Read all Required Reading files before starting — you need the full context.
- Use `gh` CLI for PR creation.
- **Commit after EACH numbered step — not just at task completion.** Run the step's test first, then commit. Max 5 changed files per commit.
- If a step requires a database, start `sandbox-postgres` first: `docker compose up -d sandbox-postgres`

### When Done — Report Results
1. Print your full completion summary in chat (tasks completed, PR number, test results)
2. Post a completion reply to this Linear issue:
   ```bash
   python3 {scripts_dir}/infra/linear_comment.py {ID} "## ✅ Completion Report

   **Tasks:** {N}/{N} Done
   **PR:** #{pr_number} — {url}
   **Tests:** {pass}/{total} passing

   **Delivered:**
   - {item 1}
   - {item 2}

   **Blockers/Deferred:** {none or list}
   "
   ```
   - Or use Linear MCP `add_comment` if available
   - If no access, skip — Operator will capture from chat
```

**Ollama (qwen3:32b / codestral:22b):**
```
### Ollama Notes
- You run on mothership only. All file paths are local.
- Keep context focused — process one task at a time.
- **Commit after EACH numbered step — not just at task completion.** Run the step's test first, then commit. Max 5 changed files per commit.
- Use `gh` CLI for PR creation.

### When Done — Report Results
Print your full completion summary in chat:
- Tasks completed (list each {ID})
- PR number and link
- Test results (pass/fail count)
- Any blockers or deferred items

(No Linear access — Operator will capture your output and post to Linear)
```

**Cursor:**
```
### Cursor Notes
- You run on mothership in the IDE. All file paths are local.
- Use terminal for git and gh commands.

### When Done — Report Results
Print your full completion summary in chat:
- Tasks completed (list each {ID})
- PR number and link
- Test results (pass/fail count)
- Any blockers or deferred items

(No Linear access — Operator will capture your output and post to Linear)
```

### Step 6: Save Brief to Feature Branch

Write the brief to a file on the epic's feature branch:

```bash
# Ensure we're on the feature branch (created by /epic start Step 2)
git branch --show-current  # must NOT be develop/main

# Write brief file
Write("{scripts_dir}/factory/briefs/{ID}-{agent}.md", content: {full_prompt})

# Commit and push
git add {scripts_dir}/factory/briefs/{ID}-{agent}.md
git commit -m "[DOCS] {ID}: Add {agent} brief for handoff"
git push origin {branch_name}
```

### Step 7: Post Brief as Linear Comment

Post the brief as a comment on the epic issue so it's discoverable and creates a paper trail:

```
add_comment(
  issueId: "{ID}",
  body: """
## 🤖 Agent Brief: {agent} ({model})

**Branch:** `{branch_name}`
**Machine:** {machine}
**Tasks:** {N}

---

{full_prompt_content}

---

_Brief generated by Claude · Awaiting {agent} execution_
_When done, {agent} should reply to this comment with completion report_
"""
)
```

### Step 8: Print Summary

After posting to Linear, print in chat:

```
Brief generated for {agent} ({model}) on {machine}.
{N} tasks | Branch: {branch_name}

✅ Saved to: {scripts_dir}/factory/briefs/{ID}-{agent}.md
✅ Posted to Linear: {ID} comment thread

Next steps:
1. Copy the prompt above OR find it in Linear issue {ID}
2. Paste into {agent} and run
3. {agent} will post completion report as a reply (if capable)
4. Come back here and run: /epic close {ID}
```

## Key Rules

- The prompt must be SELF-CONTAINED — the agent should need nothing beyond the prompt + the files it references in the repo
- Always reference `lifecycle_process.md` — don't duplicate its contents in the prompt
- Always include the critical CLAUDE.md rules inline (the agent may not read CLAUDE.md thoroughly)
- Deduplicate Required Reading across tasks — list each file once
- Task steps are copied verbatim from Linear — don't summarize or rephrase

## Judgment weave (see /judgment)

- **When briefed work comes back:** run **`/refute`** on the external agent's "done" claim before accepting it into the epic.
