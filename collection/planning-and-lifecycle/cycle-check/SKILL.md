---
name: cycle-check
origin: authored
public: true
description: Weekly planning ritual. Reviews last week's progress, upcoming work, and flags blockers across the active milestone.
allowed-tools: Bash, Read, Grep
---

# Cycle Check

Lightweight weekly planning review. Shows what happened, what's next, and what's blocked.

## Invocation

```
/cycle-check              # Use current active milestone
/cycle-check M0003B       # Check specific milestone
```

## Arguments

- `$1` (optional): Milestone title (e.g. `M0003B`). If omitted, auto-detect from `{plan_file}`.

## Step 0: Load project context (run first)

Read `.claude/project-context.md` for `task_manager`, `task_team_id`, and `plan_file`
(default `docs/IMPLEMENTATION_PLAN.md`). The `gh` commands below are the **`github` adapter's**
implementation of the read queries. If `task_manager` is `linear` (or other), load
`.claude/skills/_shared/adapters/{task_manager}.md` and use its `list_milestones` / `list_issues`
operations instead — the report shape is identical; only the query mechanism changes.
`{owner}/{repo}` comes from `task_team_id`.

## What Happens

### 1. Determine Active Milestone

If no argument provided, read `{plan_file}` to find the current active milestone. Otherwise use the provided milestone argument.

### 2. Milestone Progress

```bash
# Get milestone number from title
gh api repos/{owner}/{repo}/milestones --jq '.[] | select(.title=="MILESTONE") | {number, title, open_issues, closed_issues, due_on}'
```

Report: `X/Y issues closed (Z% complete)`, due date if set.

### 3. Issues Closed (Last 7 Days)

```bash
gh issue list --state closed --milestone "MILESTONE" --search "closed:>=$(date -v-7d +%Y-%m-%d)" --limit 20 --json number,title,closedAt
```

List each with issue number and title.

### 4. Issues Opened (Last 7 Days)

```bash
gh issue list --state all --milestone "MILESTONE" --search "created:>=$(date -v-7d +%Y-%m-%d)" --limit 20 --json number,title,state,createdAt
```

List each with issue number, title, and state.

### 5. Blockers

```bash
gh issue list --state open --label "needs:ceo-decision" --limit 10 --json number,title,labels
gh issue list --state open --label "needs:user-input" --limit 10 --json number,title,labels
```

List any issues that require Operator decisions or user input.

### 6. Aging PRs (Open > 3 Days)

```bash
gh pr list --state open --json number,title,createdAt,author --jq '[.[] | select((now - (.createdAt | fromdateiso8601)) > 259200)]'
```

List PRs open longer than 3 days with age in days.

### 7. Generate Summary

Output a focused summary in this format:

```
## Cycle Check — {milestone} — {date}

### Milestone Progress
{X}/{Y} issues closed ({Z}%) | Due: {date or "no due date"}

### This Week (Closed)
- #{num} Title
- ...

### New Issues
- #{num} Title (open/closed)
- ...

### Blockers
- #{num} Title [label]
- ...
(or "None")

### Aging PRs (>3 days)
- PR #{num} Title — {N} days old
- ...
(or "None")

### Recommendations
- {1-3 bullet points: what to focus on next week, risks, suggestions}
```

## Instructions

Run the steps above in order. Use the loaded task-manager adapter's read operations for all queries — the `gh api` / `gh issue list` / `gh pr list` commands shown are the `github` adapter's form. Keep output concise. For recommendations, consider: unblocking blocked items first, closing nearly-done issues, and addressing aging PRs. If a milestone argument is provided, use it directly; otherwise parse it from `{plan_file}`.

## Judgment weave (see /judgment)

- **Look back:** run **`/calibrate`** on last week's confidence tags and estimates.
- **Look ahead:** any plan for next week needs `GATE:` lines — author them with **`/gate`**.
