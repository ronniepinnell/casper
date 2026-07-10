---
name: iterate-pr
origin: authored
public: true
description: Iterate on a PR until CI passes. Use when you need to fix CI failures, address CodeRabbit feedback, or continuously push fixes until all checks are green. Automates the feedback-fix-push-wait cycle. Use with /loop for continuous monitoring.
---

# Iterate on PR Until CI Passes

Continuously iterate on the current branch until all CI checks pass and review feedback is addressed.

**Requires**: GitHub CLI (`gh`) authenticated.

> **Project note**: Use `gh pr checks`, `gh run view --log-failed`, and `gh pr comments` directly.
> Use with `/loop 1m iterate-pr` for hands-free monitoring.

## Workflow

### 1. Identify PR

```bash
gh pr view --json number,url,headRefName,statusCheckRollup
```

Stop if no PR exists for the current branch.

### 2. Gather Review Feedback

```bash
# Get all PR comments and reviews
gh pr view --json comments,reviews --jq '.comments[] | select(.author.login == "coderabbitai") | .body'
```

Categorize by priority:
- **High** (fix immediately): blockers, security issues, CHANGES_REQUESTED
- **Medium** (should fix): standard feedback, architectural concerns  
- **Low** (optional): nits, style, suggestions

### 3. Check CI Status

```bash
gh pr checks
```

For failed checks, get full logs:
```bash
gh run list --branch $(git branch --show-current) --limit 5
gh run view <run-id> --log-failed
```

### 4. Fix Failures (Investigation First)

**Before touching code:**
1. Read the full log — not just the snippet
2. Trace the error to root cause in source code
3. State clearly: "This fails because X, introduced by Y"
4. Only then fix

Fix the root cause. Never paper over with workarounds.

### 5. Verify Locally, Then Commit and Push

```bash
# Run affected tests
pytest tests/path/to/affected_test.py -v    # Python
npm run type-check                           # TypeScript
npm run lint                                 # ESLint

# Commit and push
git add <files>
git commit -m "[FIX] <descriptive message>"
git push
```

### 6. Monitor CI Loop

```bash
# Poll every 30 seconds
while true; do
  STATUS=$(gh pr checks --json name,state --jq '[.[] | select(.state == "FAILURE")] | length')
  PENDING=$(gh pr checks --json name,state --jq '[.[] | select(.state == "PENDING" or .state == "IN_PROGRESS")] | length')
  
  if [ "$STATUS" = "0" ] && [ "$PENDING" = "0" ]; then
    echo "✅ All checks passed!"
    break
  elif [ "$PENDING" = "0" ] && [ "$STATUS" != "0" ]; then
    echo "❌ Checks done with failures — fixing..."
    break
  fi
  
  sleep 30
done
```

In Claude Code, use the Monitor tool instead of sleep polling for efficiency.

### 7. Repeat

If new failures or feedback appear after CI passes, return to Step 2.

## Exit Conditions

**Success**: All checks pass, no unaddressed high/medium feedback.

**Ask for help**: Same failure after 2 fix attempts, unclear failure cause.

**Stop**: No PR exists, branch needs rebase.

## Example CI Checks

Key checks that must pass:
- TypeScript type-check (`npm run type-check` in `ui/dashboard/`)
- ESLint (`npm run lint` in `ui/dashboard/`)
- pytest (Python ETL tests)
- Vercel preview deployment build
- CodeRabbit review (wait ~5 min after push)

## Judgment weave (see /judgment)

- **Green CI is not done:** before declaring the loop finished, run **`/refute`** against the PR's actual acceptance criteria, not just the checks.
