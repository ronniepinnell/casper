---
name: plan-milestone
origin: authored
public: true
description: Break a milestone goal into epics and tasks with dependency ordering, acceptance tests, and task manager ticket creation. Works with any task manager via the adapter layer.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, Agent, mcp__claude_ai_Linear__save_issue, mcp__claude_ai_Linear__list_issues, mcp__claude_ai_Linear__list_teams, mcp__claude_ai_Linear__list_issue_labels, mcp__claude_ai_Linear__list_issue_statuses, mcp__claude_ai_Linear__get_issue, mcp__claude_ai_Linear__save_milestone, mcp__claude_ai_Linear__list_milestones, mcp__claude_ai_Linear__list_projects
argument-hint: <area> <sequence> "<goal description>" [--from-ccb]
---

> **Factory mode:** If `CLAUDE_AUTO` is set in the environment, skip these instructions and instead run `./{scripts_dir}/skills/plan-milestone.sh "$@"` via Bash — the shell script handles autonomous dispatch.

> **MCP Tool Map (Gemini/Codex):** See `.claude/skills/_shared/mcp-tool-map.md` for tool name equivalents.

# Plan Milestone — Epic & Task Breakdown

Takes a milestone goal and produces a full execution plan: epics with dependency ordering, tasks with test criteria, and task manager tickets ready for the factory.

## Milestone Naming Rule — HARD GATE

**Milestone titles must describe a CAPABILITY being added, not a STATE being reached.**

The recurring failure mode is the "DAT004→008" pattern: milestones named
`Finish the Schema`, `Complete Phase 10`, `Wrap up the cleanup` are open-ended
buckets that absorb scope until they're marked Done without ever shipping a
discrete capability. Capability names force a clear acceptance test
(`Add Lineage Tracking` → "lineage column exists, populated for all rows").

### Rejected patterns (regex enforced before milestone creation)

| Reject if title matches | Why |
| --- | --- |
| `^(Finish\|Complete\|Close\|Wrap[- ]up\|Finalize)\b` | "Finish X" is state, not capability |
| `^Final\b` | "Final pass" never ships a thing |
| substring: `the schema`, `the cleanup`, `the audit`, `remaining work` | bucket nouns absorb scope |

Canonical regex (case-insensitive — apply with `(?i)` inline flag or
`/.../i` in JS-style engines). Markdown escapes the pipes in the table
above; the raw patterns are:

```regex
^(Finish|Complete|Close|Wrap[- ]up|Finalize)\b
^Final\b
```

Plus literal substring checks (case-insensitive) for:
`the schema`, `the cleanup`, `the audit`, `remaining work`.

### Required pattern

Title MUST start with an **action verb describing the capability added**:

`Add` · `Build` · `Enable` · `Ship` · `Deploy` · `Migrate` · `Lock-in` ·
`Harden` · `Retire` · `Replace` · `Extract` · `Introduce` · `Wire`

| Bad (state) | Good (capability) |
| --- | --- |
| `Finish the Schema` | `Add Lineage Tracking` |
| `Complete Phase 10` | `Ship Multi-Tenant RLS` |
| `Wrap up the cleanup` | `Retire Legacy CSV Loader` |
| `Final auth pass` | `Harden JWT Refresh Flow` |

The skill MUST refuse to create a milestone whose title matches a rejected
pattern. Surface the regex hit, suggest the verb list, and force the operator
to rename before `save_milestone` is called.

## Step 0: Load Project Context (MANDATORY)

Before any planning, read `.claude/project-context.md` to get:
- `task_manager` — which adapter to use
- `task_prefix` — ticket prefix (e.g. `APP`, `BEN`, `WEB`)
- `task_team_id` — team/project identifier
- `milestone_noun` — what this project calls milestones
- `main_branch` — PR target branch
- `areas` — project area codes (if defined)
- `storage_backend` — load `.claude/skills/_shared/storage/{storage_backend}.md`; route all memory reads/writes (`record_decision`, `list_decisions`, `save_task_plan`, `record_test_run`, …) through its operations. Absent → `none` (reads empty, writes discarded). `storage_schema_intel`/`storage_schema_qa` name the namespaces (defaults `intel`/`qa`).
- `agents` — capability→agent map; reference agents below as `{agents.<capability>}`. Absent → template defaults (`completion_audit: completion-audit`, `spec_audit: spec-audit`, `pragmatism_audit: pragmatism-audit`, `scalability_audit: future-self`). If a mapped agent is unavailable, skip that step with a logged note.

Then load the task manager adapter:
```
Read.claude/skills/_shared/adapters/{task_manager}.md
```

If `.claude/project-context.md` is missing: stop and tell the user to run `/project-init` first.

> **GATE ENFORCEMENT: This skill is the ONLY path to write task manager issues.**
> A PreToolUse hook (`guard-task-writes.sh`) blocks task creation calls unless
> `.claude/.plan-milestone-active` exists. This skill creates that flag on entry and
> removes it on exit.
>
> **Step 0b (MANDATORY — before any planning):**
> ```bash
> touch.claude/.plan-milestone-active
> ```
> **Final step (MANDATORY — after all issues created):**
> ```bash
> rm -f.claude/.plan-milestone-active
> ```

## Naming Conventions (CRITICAL)

### Milestone IDs — `{AREA_CODE}{3D}{LETTER}`

Format: 3-letter area code + 3-digit sequence + letter suffix.

**Area codes are defined per project in `.claude/project-context.md`** under `areas:`.
If no areas are defined, auto-derive the code from the area name:

```
Auto-derivation rules (applied in order):
1. Split area name into words
2. If multi-word: take first letter of each word, uppercase, max 3 chars
   "Computer Vision" → CV → pad to CVX? No — use first 3 letters of each word initial: CVX
   "Machine Learning" → ML → MLX (pad single/double initials to 3 with X)
   "Analytics" → ANL (first 3 consonant-rich chars)
3. If single word ≤ 3 chars: uppercase as-is
4. If single word > 3 chars: first 3 chars, uppercase
   "Analytics" → ANL  |  "Factory" → FCT  |  "Platform" → PLT
5. Confirm with user before creating first milestone in a new area
```

Sequence is auto-incremented: fetch existing milestones for this area from the task manager,
find the highest sequence number, add 1. Start at 001 for new areas.

Examples (after derivation):
```
Computer Vision, seq 5, phase A  →  CVX005A
Machine Learning, seq 4, phase A →  MLX004A
Factory, seq 3, phase A          →  FCT003A
```

**Z suffix = hardening/verification** milestone (e.g. `CVX005Z — Verify CV Pipeline E2E`).
**NEVER use decimal suffixes.** Increment the letter (`A`→`B`→`C`…) for sub-phases.

### Epic Titles — `[{MILESTONE_ID}] {Title}`

```
[MLX004A] V3 Hybrid Architecture
[FCT003A] Budget & Safety Gates
[CVX005A] VERIFY: Baseline Verification
```

### Task Titles — plain descriptive

No prefix needed — the parent relationship provides context.

### Milestone Labels

Every epic and task gets a `milestone:{CODE###X}` label for cross-project filtering.

### Git Branching — Derived from `type:*` Label

Each epic gets ONE branch. All tasks commit to that branch. ONE PR per epic to `{main_branch}`.

| `type:*` label | Branch prefix | Example |
|----------------|--------------|---------|
| `type:feature` | `feature/` | `feature/{prefix}-1371-v3-architecture` |
| `type:fix` | `fix/` | `fix/{prefix}-993-auth-regression` |
| `type:refactor` | `refactor/` | `refactor/{prefix}-997-split-module` |
| `type:test` | `test/` | `test/{prefix}-1000-period-validation` |
| `type:audit` | `audit/` | `audit/{prefix}-996-verify-m0004d` |
| `type:docs` | `docs/` | `docs/{prefix}-1010-doc-automation` |

`{prefix}` = `task_prefix` from project-context.md (e.g. `BEN`, `APP`, `WEB`).

**Branch format:** `{type}/{prefix}-{epic_id}-{short-kebab-name}`
**PR target:** `{main_branch}` from project-context.md (NEVER `main` if configured otherwise)
**Commit prefix:** `[{TYPE}] {prefix}-{task_id}: {what changed}`

## Invocation

```
/plan-milestone "Computer Vision" 5 "Ship tracking pipeline"
/plan-milestone CVX005E --update          # patch existing issues to match current spec
/plan-milestone CVX005E --update --dry-run
```

If a milestone ID is passed directly (e.g. `CVX005E`), skip code derivation and use as-is.

When called from `/ccb`, the `--from-ccb` flag is implicit and CCB context (blockers, debt, acceptance criteria) is already in conversation.

### `--update` Flag — Bring Existing Issues Up to Date

When `--update` is passed, skip Steps 2-4 (no new planning). Instead:

#### Update Step 1: Load All Existing Issues

```python
issues = list_issues(team: "{task_team_id}", query: "[{milestone_id}]")
```

#### Update Step 2: Resolve Correct Project & Milestone IDs

Same as Step 5a-pre — look up the Linear project by code prefix and the milestone by name.

#### Update Step 3: Audit Each Issue

For every epic and task in this milestone, check:

| Field | Check | Fix |
|-------|-------|-----|
| `projectId` | Matches resolved project? | Set it |
| `milestoneId` | Matches resolved milestone? | Set it |
| `labels` | Has `milestone:{CODE}` label? | Add it |
| `labels` | Has `model:*` label? (epics + tasks) | Add default from routing table |
| `labels` | Has `machine:*` label? | Add default from routing table |
| `labels` | Has `type:*` label? (epics) | Add based on title prefix |
| `labels` | Has `epic` or `task` label? | Add based on parentId |
| Description | Has `## Execution Context`? | Add from routing defaults |
| Description | Has `## Goal` with real content? | Flag as thin — needs manual fill |
| `blockedBy` | Set correctly per dependency graph? | Flag if missing |
| Parent | Tasks have correct `parentId`? | Flag if orphaned |

#### Update Step 4: Show Audit Report

```
PLAN-MILESTONE UPDATE: {milestone_id}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Issue         Field              Current              Fix
  ──────────── ──────────────────── ──────────────────── ────────────────────
  {prefix}-3433     projectId            (none)               → Computer Vision
  {prefix}-3433     milestoneId          (none)               → CVX005E
  {prefix}-3434     labels               missing model:*      → model:sonnet
  {prefix}-3435     Execution Context    (missing section)    → Add default block
  {prefix}-3436     milestone label      (none)               → milestone:CVX005E

  {fix_count} fixes needed across {issue_count} issues
```

If `--dry-run`: print report and stop.
If not `--dry-run`: use `AskUserQuestion` to confirm, then apply all fixes via `save_issue`.

#### Update Step 5: Verify

Run the same verification sweep as Step 5g — confirm all issues are now linked correctly.

---

## Step 0b: Operator Alignment Check

Ask before loading specs or generating anything:

```
Before planning {milestone_id}: anything to discuss, clarify, or flag?
(scope changes, locked decisions, timeline constraints, things that changed)
```

Use `AskUserQuestion` with options:
- **Nothing — let's plan** (default)
- **I have something to flag** — free-text; capture decisions via `record_decision` (storage) then continue
- **Hold — scope isn't settled yet** — STOP, do not proceed

**If `CLAUDE_AUTO=1`:** skip this step.

**Grill me (strategic milestones):** When the milestone has ≥ 3 epics planned or touches schema/ETL/auth, ask 2–3 clarifying questions before generating the epic breakdown:
1. "What does 'done' look like for this milestone — what can the Operator do that they can't do today?"
2. "Are there any scope items that should NOT be included, even if they seem related?"
3. "Any external dependencies (integrations, data sources, vendors) that could block this?"

Capture answers as decisions if they constrain scope. Skip if Operator answers "looks good" to any question.

---

## Step 0c: Honesty Stack Mode Selection

Before generating epics, lock in the honesty-stack mode that the milestone and every child epic will inherit. The mode controls which honesty hooks fire at `/epic close` / `/milestone close`:

* **`full`** — all hooks (R-43 lint + audit-doubt + verifier-isolation + transition + dependency-audit). Use for P0 milestones (FCT*, DAT*, HARDEN, Z) where the cost of a missed honesty signal is high.
* **`lite`** — cheap hooks only (R-43 lint + transition-validator). The default — keeps routine epics cheap.
* **`off`** — nothing fires. Emergency override for trivial fixes / Operator directive.

### Resolution order (highest precedence first)

1. `HONESTY_MODE` env var (non-interactive fallback for autonomous runs).
2. The Operator's `AskUserQuestion` choice in this step.
3. `resolve_honesty_mode({milestone_id})` from `scripts.factory.lifecycle_helpers` — applies the `per_milestone_overrides` globs declared in `.claude/project-context.md`.

### Procedure

```python
import os
from scripts.skills.plan_milestone_helpers import (
    read_honesty_mode_from_description,
    record_honesty_mode_decision,
    resolve_honesty_mode,
    upsert_honesty_block,
)

resolved_default = resolve_honesty_mode(milestone_id)  # e.g. "full" for FCT*
env_override = (os.getenv("HONESTY_MODE") or "").strip().lower()
existing_mode = read_honesty_mode_from_description(current_milestone_description)

if env_override in {"full", "lite", "off"}:
    # CLI override always wins, even over a persisted block.
    chosen_mode = env_override
    rationale = "HONESTY_MODE env var override"
elif existing_mode in {"full", "lite", "off"} and not honesty_block_is_stale(current_milestone_description):
    # CR PR #9817: re-running /plan-milestone on an already-planned milestone
    # must NOT re-prompt the operator for the mode. Reuse the persisted
    # block when it's fresh.
    chosen_mode = existing_mode
    rationale = "Reused persisted honesty mode from milestone description"
elif os.getenv("CLAUDE_AUTO") == "1":
    chosen_mode = resolved_default
    rationale = f"CLAUDE_AUTO=1, using resolved default for {milestone_id}"
else:
    # Interactive: surface the resolved default + ask the operator.
    # Use AskUserQuestion with three options. The label of the resolved
    # default carries "(Recommended)".
    chosen_mode = ask_via_AskUserQuestion(resolved_default)
    rationale = f"Operator choice (resolved default was {resolved_default})"
```

The `AskUserQuestion` block:

```text
Question: "Honesty stack mode for {milestone_id}? (resolved default: {resolved_default})"
Options:
  - "{resolved_default} (Recommended)" — recap of what {resolved_default} runs
  - "{other_mode_1}" — recap of what {other_mode_1} runs
  - "{other_mode_2}" — recap of what {other_mode_2} runs
```

### Persistence

After resolving `chosen_mode`:

```python
# 1. Write the block into the milestone description (idempotent — replaces
#    any existing block, otherwise inserts at end).
new_description = upsert_honesty_block(
    description=current_milestone_description,
    mode=chosen_mode,
    milestone_id=milestone_id,
    rationale=rationale,
)
# Apply via save_milestone (or save_issue for the
# tracker proxy).

# 2. Record the choice via record_decision (supabase → {storage_schema_intel}.decisions). Returns the decision_number on
#    success, None on failure (never raises).
record_honesty_mode_decision(milestone_id, chosen_mode, rationale)
```

The block rendered by `upsert_honesty_block` looks like:

```markdown
<!-- honesty-stack:begin -->
## Honesty Stack

- mode: `full`
- resolved: 2026-05-18 by /plan-milestone for FCT011C
- rationale: Operator choice (resolved default was full)
<!-- honesty-stack:end -->
```

`/milestone start`, `/pipeline run`, and `/epic start` read this block via `read_honesty_mode_from_description()` to seed each session's `honesty_mode` column.

### Skip conditions

* `CLAUDE_AUTO=1` → use resolved default silently (no prompt).
* Milestone description already contains a non-stale honesty-stack block AND no CLI override → re-use the existing mode, do NOT re-prompt.

---

## Step 1: Spec Grounding — HARD GATE (do NOT skip, do NOT plan from memory)

> Planning from the milestone title or from memory — instead of from the spec files on
> disk — is the #1 cause of drift and false Done marking. You may **not** write
> acceptance criteria (Step 2), epics, or tasks until you have produced and shown the
> **Spec Grounding Digest** below. This gate is as binding as the naming gate above.

### 1a. Discover the relevant specs — run these, don't guess

```bash
ls {spec_dir}/ ; cat {spec_dir}/.abstract.md 2>/dev/null   # what specs exist
# milestone-goal keywords → matching specs (substitute 2-4 real keywords):
grep -rilE '<keyword1>|<keyword2>|<keyword3>' {spec_dir}/ rules/ | head -20
test -f {spec_dir}/GITHUB_FACTORY_SPEC.md && echo "factory spec present"
```

Also load the constraints that bound the plan:
- `list_decisions()` — storage op (supabase → `{storage_schema_intel}.decisions`) — locked decisions (D-block etc.) that constrain choices.
- Prior-milestone `**Spec Section:**` refs and any open carry-over.
- Open / recently-closed issues: `gh issue list --state open --json number,title,labels,milestone --limit 100`.

### 1a-verify. External model cross-check — did you miss any specs? (MANDATORY)

Before reading anything, send your discovered spec list + the milestone goal to Ollama or Gemini.
The external model sees only filenames and the goal — it cannot read the files. Its job is to flag
specs you might have missed based on filename pattern and milestone topic alone.

```bash
python3 {scripts_dir}/skills/verify_spec_coverage.py \
  --goal "{milestone goal as plain English}" \
  --found-specs "{spec_dir}/FOO.md {spec_dir}/BAR.md rules/areas/etl.md" \
  --spec-dirs "docs/specs docs/runbooks rules/areas"
```

The script calls Ollama (→ Gemini fallback) and returns:
- **Confirmed:** specs your search found that the model agrees are relevant
- **Missed:** specs in the tree the model thinks you should also read
- **Irrelevant:** specs your search found that the model thinks don't apply

Any file in **Missed** is a mandatory read — add it to your list before 1b.
If the external model is unavailable, skip with a logged warning and proceed.

### 1b. READ each candidate spec end-to-end, then write the digest

Open every spec relevant to this milestone with the Read tool and read it in full. Then
write a **Spec Grounding Digest** to `.claude/.plan-specs-{milestone_id}.md` *and* show it
to the Operator. One row per relevant spec section:

| Spec ref (`file#§`) | Lines read | Requirement (VERBATIM quote from the file) | Status today | Epic |
|---|---|---|---|---|
| `{spec_dir}/X.md#§4.2` | L120–138 | "the manifest MUST declare every generated table…" | none | E01 |
| `{spec_dir}/X.md#§4.3` | L139–151 | "CI fails if declared ≠ reality" | partial | E02 |

The **verbatim quote** column is the forcing function: you cannot fill it without having
opened the file. Paraphrase-only rows are rejected. Every quote needs its `Lstart–Lend`.

### 1c. Spec Quiz — mechanical verification (do NOT skip)

After writing the digest, run the quiz against every spec file you read. The quiz pulls
verbatim lines and asks you to fill them in — it cannot be passed without having read the file.

```bash
python3 {scripts_dir}/skills/spec_quiz.py <spec_file1> [<spec_file2>...] --questions 2
```

- **Pass (≥70%):** proceed to gate check.
- **Fail:** return to 1b, re-read the flagged file end-to-end, retry once.
- **Still fail:** stop. Tell the Operator which spec is unclear before continuing.

Also verify the digest structure is valid (catches empty-quote cells):

```bash
python3 {scripts_dir}/skills/spec_quiz.py --digest.claude/.plan-specs-{milestone_id}.md
```

This must return `OK` before Step 2.

### 1d. Gate check — ALL must be true before Step 2

- [ ] Spec quiz passed (≥70%) for every spec file read.
- [ ] Digest structure check returned `OK` (no empty quote cells).
- [ ] Every spec path in the digest passed `test -f` (it is a real file).
- [ ] Every row has a **verbatim** quote **and** a line range — no empty/paraphrased quote cells.
- [ ] Every milestone epic in Step 3 maps to ≥1 digest row via its `**Spec Section:**` line.
- [ ] The digest file `.claude/.plan-specs-{milestone_id}.md` exists and is non-empty.
- [ ] Spec **gaps** are explicit: each section is marked `none` / `partial` / `done` — gaps drive the epic breakdown.

If you cannot quote a requirement, you have NOT read that spec — return to 1b. These rows are
the source feeding the §46 spec-coverage producer hook (Step 5a-post); a missing digest there
means you skipped this gate.

---

## Step 2: Generate Acceptance Criteria

**Before any epic planning**, define milestone-level acceptance criteria. These are the tests that the hardening epic will run.

Format:
```markdown
## {milestone_id} Acceptance Criteria

### Functional
- [ ] {User-visible behavior that must work end-to-end}
- [ ] {Another behavior}

### Technical
- [ ] {Performance/reliability requirement}
- [ ] {Integration requirement}

### Quality
- [ ] All new code has test coverage
- [ ] No new files over 500 lines
- [ ] All spec sections for this milestone have implementation
```

**OUTCOME-BASED CRITERIA RULE (CRITICAL):**
Every acceptance criterion MUST assert an observable OUTCOME, never an operation.

| BANNED (operation-based) | REQUIRED (outcome-based) |
|---|---|
| "Migration X applied successfully" | "Table X has columns A (bigint), B (text), C (uuid)" |
| "Script ran without errors" | "Query `SELECT count(*) FROM X` returns > 0" |
| "File was created" | "File exports function Y and passes type-check" |
| "DROP COLUMN ran" | "Column Z does NOT exist in information_schema" |
| "RLS policy created" | "pg_class.relrowsecurity = true for table X" |

Operation-based criteria are how false Done marking happens — a `DROP COLUMN IF EXISTS` silently no-ops, the agent checks "did it run?" (yes), marks Done, and the column is still there. Outcome-based criteria catch this because they check the actual state.

Present to Operator for approval. Adjust based on feedback.

### Step 2b: Write Epic Test Files BEFORE Tasks (TDD — Red First, Independent Model)

> **HARD RULE: Claude does NOT write the tests. A separate model writes them.**
> Claude's implementation plan is NOT shown to the test writer — only the Spec Grounding Digest
> and Exit Criteria. This is the only way tests are independent. Self-review is not review.

#### Step 2b-0: Dispatch Test Writing to External Model (MANDATORY)

After Step 2a (Exit Criteria are written), dispatch test writing to an external model. The test
writer sees ONLY the spec digest and exit criteria — never Claude's internal planning notes.

**Preferred dispatch order (try in sequence, use first available):**

1. **Ollama (local, free)** — try `codestral:22b` or `deepseek-coder-v2` first:
   ```bash
   ollama list 2>/dev/null | grep -E "codestral|deepseek-coder|qwen2.5-coder" | head -3
   ```
   If a suitable model is available:
   ```bash
   # Write the test brief (spec + exit criteria ONLY — no implementation context)
   cat > /tmp/test_brief_{milestone_id}.md << 'EOF'
   # Test Writing Brief — {milestone_id} {epic_id}

   You are a grumpy, adversarial test writer. You do not trust the implementation.
   Your job: write failing (RED) pytest tests that prove the exit criteria below are met.
   You have NOT seen the implementation. Write tests that WOULD CATCH a lazy implementation.

   ## Spec (verbatim from spec digest)
   {paste relevant rows from.claude/.plan-specs-{milestone_id}.md}

   ## Exit Criteria to Test
   {paste this epic's Exit Criteria from Step 2a}

   ## Rules
   - Every criterion gets ≥1 test function
   - Fail with raise NotImplementedError("RED: {criterion}") — NEVER pytest.skip
   - Docstring states which criterion is proven
   - Assert OUTCOMES, not "did the function run"
   - Be adversarial: write the test that would catch a stub or fake
   EOF

   ollama run codestral:22b < /tmp/test_brief_{milestone_id}.md > /tmp/test_output_{milestone_id}.py
   ```
   Review the output. If sensible, copy to the correct test path (see naming below). If garbage, fall back.

2. **Codex (if available)** — same brief, same isolation constraint. Codex does NOT see Claude's plan.

3. **Claude as fallback (last resort only)** — only if Ollama and Codex are both unavailable. If Claude
   must write its own tests, explicitly log in the milestone description:
   ```
   ⚠️ SELF-TESTED: No external model available at planning time. Tests written by Claude.
   Flag for adversarial review before epic closes.
   ```
   Then write tests using the Exit Criteria only — deliberately ignore the implementation plan.

For every epic in this milestone, write the actual test file(s) to disk NOW — before any task is
created in Linear. These tests FAIL immediately (RED). They turn GREEN when the epic is done.
This is not optional. If there is no test file, there is no proof of completion.

**Tests are always specific to what THIS epic builds.** Never write generic scaffolding or
`pytest.skip` placeholders. Derive the test content directly from the epic's Exit Criteria —
each criterion becomes one or more test functions.

#### Layer Routing Table — which suite for which epic type

| Epic builds... | Test layer | Suite folder | When it runs |
|---|---|---|---|
| A function, class, hook, CLI command | 1 — Unit | `tests/unit/` | Every commit on epic branch |
| DB queries, API endpoints, cross-module flows | 1+2 — Integration + Contract | `tests/integration/`, `tests/contract/` | Every PR |
| Schema migration, RLS policy, column change | 2+8 — Contract + Migration | `tests/contract/`, `tests/migrations/` | VERIFY-1 gate |
| ETL pipeline output, data transformation | 6 — Canonical | `tests/canonical/` | VERIFY-2 gate |
| Auth, RLS, COPPA/parental_consent, anon access | 5 — Security | `tests/security/` | VERIFY-4 gate |
| Dashboard page, user flow, UI interaction | 3 — E2E | `tests/e2e/` | VERIFY-4 gate |
| Fixes a known past bug or false Done claim | 8 — Regression | `tests/regression/` | Every commit forever |
| Invariants that must hold for any input | 4 — Property | `tests/property/` | VERIFY-FINAL + nightly |
| Latency SLO, throughput, scale | 7 — Performance | `tests/performance/` | VERIFY-FINAL + nightly |

Most epics need Layer 1 (unit) + one domain-specific layer. Never skip Layer 1.

#### Naming Convention (mandatory)

```
tests/{suite}/test_{milestone_id_lower}_{epic_short}_{what}.py

Examples:
  tests/unit/test_proc001a_e01_karen_blocks_done.py
  tests/contract/test_dat008a_e03_event_schema.py
  tests/security/test_proc001a_e02_apply_migration_blocked.py
  tests/regression/test_ben3706_onb001a_invite_flow.py   ← issue-named regressions
```

#### How to write the test (not a placeholder)

Read the epic's Exit Criteria. For each criterion, write one test function that:
- **Asserts the OUTCOME directly** — never "did it run?" but "does the result match?"
- **Fails right now** with `raise NotImplementedError(f"RED: {what this epic must deliver}")`
  — NOT `pytest.skip`. `skip` hides the test. `NotImplementedError` shows the gap.
- **Has a docstring** stating which Exit Criterion it proves

```python
# tests/unit/test_proc001a_e01_karen_blocks_done.py
"""
PROC001A E01: completion-audit pre-commit hook tests.
Written RED before implementation. All must pass before epic closes.
"""
import pytest

class TestKarenDoneGuard:
    def test_blocks_commit_when_test_file_missing(self, tmp_branch):
        """Exit Criterion: git commit with 'Done' fails if ## Tests file doesn't exist."""
        raise NotImplementedError("RED: guard-done-marking.sh not yet implemented")

    def test_blocks_commit_when_test_file_has_zero_functions(self, tmp_branch):
        """Exit Criterion: commit blocked if listed test file has no test_ functions."""
        raise NotImplementedError("RED: guard-done-marking.sh not yet implemented")

    def test_allows_commit_when_tests_pass(self, tmp_branch, passing_test_file):
        """Exit Criterion: commit succeeds when listed tests all pass."""
        raise NotImplementedError("RED: guard-done-marking.sh not yet implemented")
```

#### Three layers required per exit criterion (thin tests are rejected)

Every exit criterion must produce tests in all three layers. One criterion = three test functions minimum:

| Layer | Class prefix | What it asserts | Docstring must contain |
|---|---|---|---|
| 1 Mechanical | `TestMech_` | Code runs, returns correct type/shape | "Mechanical:" |
| 2 Spec/Contract | `TestSpec_` | Output matches verbatim spec requirement | "Spec: [quoted requirement]" |
| 3 Outcome | `TestOutcome_` | End user sees correct result | "Outcome: As a [user]..." |

A test file with only Layer 1 tests will be rejected by the TDD gate.
Layer 2 docstrings MUST quote the spec verbatim — no paraphrase.

#### After writing all epic test files

```bash
pytest tests/ --collect-only -q 2>/dev/null | tail -5  # confirm tests are collected
pytest tests/unit/test_{milestone}_{epic}*.py           # confirm they FAIL (RED)
git add tests/
git commit -m "[TEST] {milestone_id}: Write RED test files for all epics (pre-implementation)"
```

This commit is the proof that TDD is real. **The factory cannot claim an epic Done
unless its test file exists and pytest returns 0.**

The `## Tests` section of every Linear task must reference these exact file paths.

### Step 2b.1: Consume CCB Phase 3.26 output — testing-scenarios + walkthrough twin

If this milestone was planned via `/ccb`, Phase 3.26 already produced, per
feature epic: a `## Testing Scenarios` block, a walkthrough-twin issue under
`master_verification_milestone` (`.claude/project-context.md`), and a row in
`config/test_coverage_matrix.json`. `/plan-milestone` does NOT regenerate
these — it writes them verbatim into the epic description alongside `##
Tests`, and confirms the twin link:

```
for each feature epic:
  assert epic.body contains "## Testing Scenarios"      # from CCB 3.26
  assert epic.body contains "Verification twin: {id}"    # walkthrough issue link
  if either missing:
    # This milestone was NOT run through /ccb (or /ccb predates Phase 3.26).
    # /plan-milestone must generate them itself — do not skip.
    build the testing-scenarios block per the template in
    `.claude/skills/ccb/SKILL.md` § Phase 3.26, using this epic's acceptance
    tests + spec refs as source material.
    create the walkthrough-twin issue under master_verification_milestone.
    append the row to config/test_coverage_matrix.json.
```

This is what makes planning output "feature epic AND its verification
twin" with zero extra Operator steps — the twin either arrives pre-built from
`/ccb` or gets built here, but it always exists before the epic is written
to the task manager.

### Step 2c: Write Acceptance Test Scaffolding (Outcome Verification — Red First)

For every epic, also create acceptance test scaffolding in `tests/acceptance/` for each applicable tier. These answer "does this actually work for a real user?" — not just "does the code exist?"

**Tier selection — auto-determine from what the epic builds:**

| Epic builds | Scaffold file | Key assertion to pre-write |
|---|---|---|
| CLI command | `tests/acceptance/cli/test_{milestone}_{epic}.py` | "Running `{project_cli} X Y` returns expected output against live DB" |
| API endpoint | `tests/acceptance/api/test_{milestone}_{epic}.py` | "GET/POST to `/api/X` returns schema matching TS interface" |
| Dashboard page/component | `tests/acceptance/ui/test_{milestone}_{epic}.py` | "Page loads, key data renders, primary action works" |
| ETL table / migration | `tests/acceptance/data/test_{milestone}_{epic}.py` | "Table exists, row count in range, idempotency holds" |

All acceptance tests must:
- Use `pytest.mark.skipif(not os.environ.get("SUPABASE_URL"), reason="requires live credentials")`
- Fail RED with `raise NotImplementedError("RED: {what this must prove}")` until the epic is built
- Have a docstring stating the user story: "As a {user}, I can {action} so that {outcome}"

**Also write the User Story and End-User Verification stub for each epic** directly into the Linear epic description's `## End-User Verification` section. Pre-fill the format:

```
## End-User Verification
**As a {user type}, you can now:** {action in plain English}

**To verify:**
1. {Step 1 — e.g. "Run `{project_cli} X` or go to /page/url"}
2. {Step 2 — what to look for}
3. Expected: {what correct looks like}

**Regression check:** verify {top 2 adjacent features} still work.
```

Write `TBD — fill at close` for the regression check if unknown at planning time.

After writing all acceptance scaffolding:
```bash
pytest tests/acceptance/ --collect-only -q 2>/dev/null | tail -5  # confirm collected
git add tests/acceptance/
git commit -m "[TEST] {milestone_id}: Write acceptance test scaffolding (RED)"
```

---

## Step 3: Epic Breakdown

### 3a: Identify Epics

Group related work into epics. Each epic should:
- Map to 1-2 spec sections
- Be completable in 1-3 days of factory time (5-15 issues)
- Have clear entry criteria (what must exist before this epic starts)
- Have clear exit criteria (how do we know this epic is done)

### 3b: Dependency Ordering

Build a dependency graph:
```
[FCT003A] Codex/Cursor CLI ← no deps
[FCT003A] Clone Slots ← depends on CLI epic
[FCT003A] Review Loop ← depends on Clone Slots
[FCT003A] Auto-Merge ← depends on Review Loop
[FCT003Z] HARDEN ← depends on ALL above
```

### 3b.1: blockedBy Convention (CRITICAL — for all agents)

Every `blockedBy` relationship must be set explicitly via Linear. Never rely on implied ordering.

#### Within-Milestone Patterns

```
VERIFY epic:       blockedBy = []                    (always first, no deps)
Feature epic:      blockedBy = [VERIFY]              (all feature epics blocked by VERIFY)
Feature epic (cross-dep): blockedBy = [VERIFY, {prefix}-{other_feature}]
VERIFY-MECH epic:  blockedBy = [ALL feature epics]   (if selected in Step 3d.5)
HARDEN epic:       blockedBy = [VERIFY-MECH]         (or [ALL feature epics] if no VERIFY-MECH)
VERIFY-HUMAN epic: blockedBy = [HARDEN]              (if selected in Step 3d.5)
```

**Standard within-milestone blockedBy call:**
```python
# VERIFY: no blockers
# Feature epic E02:
save_issue({ id: "{E02}", blockedBy: ["{prefix}-{VERIFY}"] })
# Feature epic E03 (also blocked by E02):
save_issue({ id: "{E03}", blockedBy: ["{prefix}-{VERIFY}", "{prefix}-{E02}"] })
# VERIFY-MECH (blocked by all feature epics, if selected):
save_issue({ id: "{VERIFY_MECH}", blockedBy: ["{prefix}-{E02}", "{prefix}-{E03}", "{prefix}-{E04}"] })
# HARDEN (blocked by VERIFY-MECH, or all feature epics if no VERIFY-MECH):
save_issue({ id: "{HARDEN}", blockedBy: ["{prefix}-{E02}", "{prefix}-{E03}", "{prefix}-{E04}"] })
# VERIFY-HUMAN (blocked by HARDEN, if selected):
save_issue({ id: "{VERIFY_HUMAN}", blockedBy: ["{prefix}-{HARDEN}"] })
```

#### Cross-Milestone Patterns

When one milestone depends on another milestone's completion (e.g. DAT004E depends on DAT004D):

```python
# The VERIFY epic of the dependent milestone is blocked by the HARDEN epic
# of the prerequisite milestone. This is the official cross-milestone dependency wire.

# Example: DAT004E-VERIFY blocked by DAT004D-HARDEN
save_issue({
  id: "{DAT004E_VERIFY}",
  blockedBy: ["{DAT004D_HARDEN}"]
})

# TRK001A-VERIFY blocked by DAT004D-HARDEN (depends on migrations, not views):
save_issue({
  id: "{TRK001A_VERIFY}",
  blockedBy: ["{DAT004D_HARDEN}"]
})
```

**Rule:** Always wire `VERIFY` of the downstream milestone to `HARDEN` of the prerequisite. Never wire individual feature epics to epics in another milestone (too granular, breaks when plans change).

#### Task-Level blockedBy

Within an epic, tasks that must run sequentially:
```python
# Task 2 blocked by Task 1 (schema must exist before API can reference it):
save_issue({ id: "{task2}", blockedBy: ["{prefix}-{task1}"] })

# REVIEW exit gate task is ALWAYS blocked by ALL other tasks in the epic:
save_issue({
  id: "{REVIEW_task}",
  blockedBy: ["{t1}", "{prefix}-{t2}", "{prefix}-{t3}"]
})
```

Tasks that CAN run in parallel have no blockedBy relationship — omit or set `blockedBy: []`.

### 3c: Epic Template

For each epic, produce:

```markdown
## [{milestone_id}] {Title}

**Spec Section:** {spec_file}#§{section}
**Dependencies:** {prefix}-{prev}, {prefix}-{prev2}
**Entry Criteria:** {what must be true before starting}
**Exit Criteria:** {what must be true to close}

### Acceptance Tests (written BEFORE tasks)
- [ ] {Testable criterion 1}
- [ ] {Testable criterion 2}

### Tasks
1. {task title} — {size S/M/L} — {labels}
2. {task title} — {size S/M/L} — {labels}
...

### Task Dependency Order
{which tasks can run in parallel vs must be sequential}
```

### 3d: Add Verification Epic (FIRST)

ALWAYS add as the FIRST epic in any milestone:

```markdown
## [{milestone_id}] VERIFY: Prior Milestone Verification

**Dependencies:** None (runs first)
**Entry Criteria:** Previous milestone closed OR first milestone (baseline audit)

### Tasks
1. **Smoke test infrastructure** — verify build, CI, daemon, and core systems are healthy:
   - `npm run build` in ui/dashboard/ exits 0
   - `pytest tests/` core tests pass
   - Factory daemon starts and claims 1 test issue
   - Supabase connectivity verified
   Size: M — type:test
2. **Quality sweep** — run Phase 6.5 quality sweep on ALL milestone artifacts:
   - Milestone issue has required sections
   - All epics have Outcome/Tasks/Exit Criteria/Gate Level
   - All tasks have Goal/Steps/Outcome/Guardrails/factory labels
   - Cross-references intact (no orphans)
   Fix anything that fails. Size: M — type:audit
3. Run prior milestone acceptance criteria (regression check) — M — type:test
4. {agents.completion_audit} audit: verify prior milestone completions still hold — M — type:audit
5. {agents.spec_audit} audit: verify spec sections from prior milestone — M — type:audit
6. Fix any regressions found — variable — type:fix
7. Generate baseline test snapshot for this milestone — S — type:test

### Exit Criteria
Infrastructure healthy. All artifacts pass quality sweep. Prior milestone criteria still pass. No regressions. Baseline captured.
```

For the FIRST-EVER milestone (no prior), this becomes a reality reconciliation:
```markdown
## [{milestone_id}] VERIFY: Baseline Reality Audit

### Tasks
1. {agents.completion_audit}: audit all items marked DONE in the task-manager milestone — L — type:audit
2. {agents.spec_audit}: spec compliance sweep across all specs — L — type:audit
3. Fix critical lies/gaps found — variable — type:fix
4. Establish baseline acceptance test suite — M — type:test
```

### 3d.5: Gate Epic Selection — VERIFY-MECH / HARDEN / VERIFY-HUMAN

Not every milestone needs all three gate epics. Analyze the milestone scope and RECOMMEND
which gates apply. Present to Operator for approval via `AskUserQuestion`.

**Decision logic:**

| Milestone touches... | VERIFY-MECH | HARDEN | VERIFY-HUMAN |
|---------------------|-------------|--------|--------------|
| UI pages, dashboard, Next.js components | ✓ (full 30 modules) | ✓ | ✓ (full 30 flows) |
| Admin CRUD, forms, user-facing features | ✓ (full) | ✓ | ✓ (full) |
| API routes only (no UI) | ✓ (api-contracts, security modules only) | ✓ | ✗ skip |
| Data pipeline, ETL, dbt models | ✗ skip | ✓ (completion + spec audits) | ✗ skip |
| Schema migrations, RLS policies | ✓ (security + database-qa modules only) | ✓ | ✗ skip |
| Infrastructure, CI/CD, monitoring | ✗ skip | ✓ (completion audit only) | ✗ skip |
| Security hardening | ✓ (security modules only) | ✓ | ✗ skip |
| Mobile app | ✓ (cross-browser + responsive) | ✓ | ✓ (mobile-focused flows) |

**Ask the Operator:**

```
GATE EPIC RECOMMENDATION for {milestone_id}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This milestone touches: {UI pages / data pipeline / security / etc.}

Recommended gates:
  ✓ VERIFY-MECH — {reason: "UI pages need Playwright testing across all roles"}
  ✓ HARDEN — {reason: "Always included — completion + spec audits"}
  ✓ VERIFY-HUMAN — {reason: "User-facing features need Operator walkthrough"}

  or for a data milestone:
  ✗ VERIFY-MECH — skip (no UI pages)
  ✓ HARDEN — completion + spec audits
  ✗ VERIFY-HUMAN — skip (no user-facing changes)
```

Use `AskUserQuestion`:
```
question: "Gate epics for {milestone_id}?"
options:
  - "All three (Recommended)" — VERIFY-MECH + HARDEN + VERIFY-HUMAN
  - "HARDEN + VERIFY-MECH only" — skip human walkthrough
  - "HARDEN only" — audits only, no Playwright
  - "Custom" — let me pick
```

If Operator picks "Custom", ask which modules/flows to include.

**If `CLAUDE_AUTO=1`:** use the recommendation without asking.

### 3e: Add VERIFY-MECH Epic (if selected in 3d.5)

Only add if Operator approved VERIFY-MECH in Step 3d.5. Runs `/verify mechanical`.

### 3f: Add Hardening Epic (ALWAYS included)

ALWAYS add after all feature epics. HARDEN runs the completion + spec audits (`{agents.completion_audit}` + `{agents.spec_audit}`). If VERIFY-MECH
exists, HARDEN depends on it. If not, HARDEN depends directly on feature epics.

HARDEN runs automated verification via `/verify mechanical` ONLY if no separate VERIFY-MECH epic exists.

**CRITICAL: Milestone-specific outcome criteria.** After generating all feature epics,
extract their acceptance tests and translate them into HARDEN-specific test criteria.
These go in a `## Milestone-Specific Test Criteria` section in the HARDEN description.
The `/verify mechanical` skill reads these at runtime to generate targeted Playwright assertions.

```python
# For each feature epic just created:
#   Read its ## Acceptance Tests section
#   Translate each criterion into a machine-testable assertion:
#     "Player can RSVP in/out/maybe" → "POST /api/rsvp returns 200, fact_rsvp row created"
#     "Standings update after game" → "After game submit, /standings shows updated W-L record"
#   Add to HARDEN description under ## Milestone-Specific Test Criteria
```

Format in the HARDEN epic description:
```markdown
## Milestone-Specific Test Criteria (from feature epic acceptance tests)

### From E01: {epic_title}
- [ ] {machine-testable criterion derived from E01's acceptance test 1}
- [ ] {machine-testable criterion derived from E01's acceptance test 2}

### From E02: {epic_title}
- [ ] {criterion}
- [ ] {criterion}

### Cross-Epic Integration
- [ ] {criterion that spans multiple epics — e.g. "player created in E01 appears in standings from E03"}
```

```markdown
## [{milestone_id}] HARDEN: Verification & Hardening

**Dependencies:** ALL previous feature epics in this milestone
**Entry Criteria:** All feature epics marked complete
**Skill:** `/verify mechanical --milestone {milestone_id} --severity-gate p0`
**Tool spec:** `.claude/skills/verify/SKILL.md`
**Specs under test:** {list every spec file referenced by this milestone's feature epics}
**Decisions:** {list relevant accepted decisions from storage `list_decisions()` that affect this milestone}

## What This Epic Does

Runs the full `/verify mechanical` automated test suite via Playwright across all roles (commissioner, coach, parent, scorekeeper, anonymous). Uses the existing HARDEN gate epic (created by /plan-milestone) — does NOT create a duplicate. Reads milestone-specific outcome criteria from this description to generate targeted Playwright assertions. Creates child issues for every failure. Screenshots uploaded to Linear (never the repo), console error captures, and step-by-step reproduction logs as issue comments.

## Automated Test Modules (30 total)

### Core Mechanical (7)
- **role-matrix** — every page × 5 roles. Expected access vs actual (200/302/403)
- **crud** — create, read, update, delete per admin entity. DB verification after each op. Test data seeded and cleaned up.
- **org-compat** — `?org=`, no `?org=`, invalid `?org=`, subdomain, old `[org]/*` backward compat
- **links** — recursive crawler from `/` and `/demo`, 4 levels deep, 500 page cap. Every `<a>` and `<Link>` followed.
- **data-edges** — empty org, single record, missing fields, stale data
- **responsive** — desktop (1280×800), tablet (768×1024), mobile (375×812) for top 20 pages
- **interactive** — click every button, dropdown, tab, modal, toggle on every page. Verify open/close/populate.

### Security (5)
- **idor** — cross-org data access via direct URL, API call, query param
- **role-escalation** — coach POSTs to admin endpoints, URL param manipulation
- **input-validation** — XSS, SQL injection, oversized input in every form
- **api-contracts** — every `/api/*` route: no-auth=401, wrong-role=403, bad-body=400, valid=200+correct shape
- **permission-mutation** — change role mid-session, toggle privacy, verify immediate effect

### Specialized (7)
- **privacy-coppa** — under-13 default private, parental consent toggles, data deletion
- **user-lifecycle** — invite flow, join code, registration, waitlist, approval/rejection
- **config-fields** — custom JSONB field lifecycle: create → validate → filter → export → delete
- **uploads** — player photos, team logos, CSV import, PDF export, R2 storage verification
- **storage** — R2 file lifecycle, orphan detection, signed URL expiry
- **realtime** — Supabase subscription fire, live update propagation, cleanup on unmount
- **notifications** — RSVP reminders, registration approvals, announcements → verify DB rows

### Resilience (5)
- **chaos** — kill API mid-request, 3G throttle, concurrent edits, corrupt JSONB, token expiry
- **session** — expired token redirect, concurrent sessions, role change mid-session
- **navigation-state** — back/forward, refresh mid-form, deep links, stale tab
- **form-state** — validation, double submit, special chars, max length, navigate away
- **rate-limiting** — 100 rapid requests, verify throttling

### Performance (3)
- **api-performance** — p50/p95/p99 latency per endpoint, 10 concurrent requests, error response shape
- **page-speed** — TTFB, FCP, DOM loaded, full load, transfer size. Score <50 = P2, <25 = P1
- **cache-freshness** — mutation → verify all views reflect change immediately

### Quality (6)
- **accessibility** — axe-core scan, keyboard-only navigation, screen reader flow, color contrast
- **seo-social** — meta tags, OG images, Twitter cards, structured data, sitemap.xml, robots.txt
- **print** — print stylesheet on scoresheets, report cards, bench cards
- **pwa-offline** — service worker, offline fallback, manifest
- **cross-browser** — Chromium, Firefox, WebKit
- **embed-widget** — `/player/[key]/widget` in iframe, CORS, responsive

### Data (4)
- **database-qa** — schema conformance, RLS coverage, orphans, duplicates, migration chain, view freshness, dead tuples
- **database-health** — slow queries (pg_stat_statements >100ms), missing indexes, connection pool
- **data-integrity** — UI prevents invalid data: negative numbers, future birth dates, duplicate slugs
- **spec-compliance** — read specs + decisions, verify each requirement is implemented

### Observability (2)
- **analytics-verify** — PostHog events fire with correct flat-route paths, no PII, org group set
- **monitoring** — /api/health returns 200, Sentry captures errors, background jobs running

## Issue Severity

| Level | Label | Criteria | Blocks Close? |
|-------|-------|----------|---------------|
| P0 | severity:blocker | Security breach, data loss, crash, CRUD broken | YES |
| P1 | severity:major | Feature broken, wrong data, role access wrong | YES |
| P2 | severity:minor | UI wrong, bad copy, layout issue | NO |
| P3 | severity:nit | Spacing, font weight, nice-to-have | NO |

## Process

1. `/verify mechanical` creates `[VERIFY-MECH]` epic in Linear
2. Each test module runs (parallel agents where safe)
3. Failures → child issues with screenshots (uploaded to Linear, never repo)
4. Every step logged as comment on the issue
5. Test data seeded before, cleaned up after
6. Living docs updated incrementally: `docs/testing/SITEMAP.md`, `COVERAGE.md`, `JOURNEYS.md`
7. Results written via `record_test_run` — storage op (supabase → `{storage_schema_qa}.test_runs`)
8. `--fix` mode: auto-fix P0/P1, re-test, close issues (max 3 attempts per issue)

## Tasks
1. Run `/verify mechanical --milestone {milestone_id}` — L — type:test
2. Fix all P0/P1 issues found by /verify — variable — type:fix
3. {agents.completion_audit} audit of all epic completions — M — type:audit
4. {agents.spec_audit} spec compliance check — M — type:audit
5. Fix gaps found by audits — variable — type:fix
6. Re-run `/verify mechanical --severity-gate p0` — must pass clean — S — type:gate

## Exit Criteria
ALL `/verify mechanical` tests pass with zero P0/P1 issues. Completion + spec audits clean. Living docs updated.
```

### 3f: Add VERIFY-HUMAN Epic (SECOND-TO-LAST — always included)

ALWAYS add after HARDEN. This is the interactive Operator walkthrough using `/verify human`.
The mechanical tests (HARDEN) proved the code works. The human tests prove the PRODUCT works.

**CRITICAL: Milestone-specific content.** The VERIFY-HUMAN description must include:
1. **Spec references** from the feature epics (the specs being TESTED, not the verify skill)
2. **Outcome-based walkthrough criteria** derived from feature epic acceptance tests
3. **Milestone-specific flows** — not just generic "30 flows" but flows tailored to what this milestone built

```python
# After generating all feature epics, build the VERIFY-HUMAN content:
# 1. Collect all spec refs from feature epics' **Spec Section:** lines
# 2. Collect all acceptance tests from feature epics
# 3. Translate each into a human-walkable outcome:
#     Machine: "POST /api/rsvp returns 200"
#     Human: "Parent taps 'I'm In' → confirmation shown, RSVP count updates"
# 4. Group by the 30-flow categories (role walkthroughs, CRUD, journeys, etc.)
# 5. Add a ## Milestone-Specific Specs section listing every spec this milestone touches
```

```markdown
## [{milestone_id}] VERIFY-HUMAN: Operator Walkthrough

**Dependencies:** [{milestone_id}] HARDEN epic must be Done
**Entry Criteria:** All mechanical tests pass, all audits clean
**Skill:** `/verify human --milestone {milestone_id}`
**Tool spec:** `.claude/skills/verify/SKILL.md`
**Specs under test:** {list every spec file referenced by this milestone's feature epics}
**Decisions:** {list relevant accepted decisions from storage `list_decisions()`}
**Resume:** `/verify human --continue {task_prefix}-{this_epic_id}`

## What This Epic Does

Interactive Playwright walkthrough with the Operator. The agent drives the browser, navigates each page, shows it to the Operator, waits for feedback, fixes issues in real-time (edit → commit → re-test), and marks each flow Done. This is NOT "create issues and leave" — it's a live session.

The HARDEN epic proved the CODE works. This epic proves the PRODUCT works — UX, intuitiveness, flow, feel, design, and data correctness through human eyes.

## How It Works

1. Agent creates child issues for each walkthrough flow under this epic
2. For each flow: agent navigates via Playwright, screenshots each step, describes what it sees
3. Operator watches and gives feedback ("fix that", "try on mobile", "what about as a coach?")
4. Agent fixes bugs immediately — edit, commit, re-test, close the bug issue
5. Every step logged as a comment on the flow's Linear issue
6. Screenshots uploaded to Linear (never the repo)
7. When a flow is complete, agent marks that flow's issue Done
8. Session can pause anytime — resume with `/verify human --continue {task_prefix}-{this_epic_id}`

## 30 Walkthrough Flows (mirrors mechanical modules through human lens)

### Role Walkthroughs (5) — does each role's view make sense?
1. Commissioner: Admin overview — dashboard layout, quick actions, data summary
2. Coach: Coach overview — practice tools, player access, eval access
3. Parent: Parent overview — kid's info, schedule, stats visibility
4. Scorekeeper: Scorekeeper overview — game list, start game flow
5. Public: Anonymous browse — landing page, what's visible without login

### CRUD Usability (6) — are the forms obvious? Fields in right order?
6. Player CRUD — add, edit, delete, search, filter, export
7. Team CRUD — add, edit, roster assignment
8. Game CRUD — add game, edit, cancel
9. Season CRUD — create, configure, open/close
10. Registration CRUD — open, approve, reject, waitlist
11. User CRUD — invite, role change, deactivate

### User Journeys (4) — would a real person complete this without help?
12. Registration: landing → signup → join code → approve → access
13. Game Day: lineup → track → score → stats update
14. Season Setup: create → register → draft → schedule → play
15. Config Change: toggle feature → verify across all roles

### UI/UX/Mobile (5) — does mobile feel native? Is the nav logical?
16. Mobile: Parent at rink — RSVP, schedule, live score on phone (375×812)
17. Mobile: Scorekeeper — game tracking on tablet (768×1024)
18. Navigation: Can you find it? — 10 tasks, measure clicks to complete
19. Error UX: Trigger 5 error types — are the messages helpful or confusing?
20. First Impression: Fresh eyes — would you pay for this? What's confusing?

### Entity Pages (6) — is the data correct and well-presented?
21. Player profile — stats, tabs, sub-pages, sharing, portfolio
22. Team page — roster, standings context, schedule
23. Game detail — box score, play-by-play, analytics
24. Standings — sort, filter, season selector
25. Leaders — leaderboard accuracy, filtering
26. Schedule — calendar view, upcoming/past

### Config & Customization (4) — can an admin figure it out?
27. Custom fields: create field → appears on form → filters → export
28. Feature toggles: toggle off → hidden for all roles → toggle on
29. Org settings: name, logo, timezone → reflected everywhere
30. Privacy controls: make player private → verify public can't see

## Issue Structure

Each walkthrough flow = a Linear issue under this epic:
```
[VERIFY-HUMAN] {Role}: {Flow Name}
Labels: verify-finding, module:human, role:{role}
```

Bugs found during walkthrough = separate child issues:
```
[VERIFY-HUMAN] P{severity} — {page} — {description}
Labels: verify-finding, severity:{level}, module:human
```

Every step logged as a comment:
```
### Step 3/8 — {timestamp}
Action: Click 'Add Player' button
Result: Modal opened — "Add New Player" form
Screenshot: [attached]
Verdict: ✓ PASS

Operator feedback: "fields should be in order: name, position, jersey, team"
→ Created: BEN-XXXX — P3 — field order on add player modal
```

## Session Continuity

At break points, the agent prints progress and offers to pause:
```
VERIFY-HUMAN — {task_prefix}-{epic_id}
  ✓ 8/30 flows complete
  Bugs: 5 found | 3 fixed | 2 open
  Resume: /verify human --continue {task_prefix}-{epic_id}
```

Any session can resume — Linear tracks what's done and what's left.

## Spec-Informed Testing

Before testing each feature, the agent reads:
- Relevant spec from `{spec_dir}/`
- Accepted decisions from storage `list_decisions()`
- Epic acceptance criteria from the milestone's feature epics
- Tests against ALL of the above — not just "does it render"

## Tasks
1. Run `/verify human --milestone {milestone_id}` — L — type:test
2. Fix all bugs found during walkthrough — variable — type:fix
3. Re-test fixed issues with Operator — S — type:gate
4. Operator sign-off on all 30 flows — S — type:gate

## Exit Criteria
ALL 30 walkthrough flows marked Done in Linear. Operator satisfied with UX, design, and data correctness. All P0/P1 bugs fixed. Living docs updated.
```

### Z Epic — DEPRECATED (removed 2026-05-29)

The Z (E2E Verification) epic is no longer created. Its responsibilities are fully covered by:
- **VERIFY-MECH** — automated Playwright testing (replaces Machine Proof)
- **VERIFY-HUMAN** — interactive Operator walkthrough (replaces Human Proof)

The old `--z-epic` flag and `E2E Mode` settings are ignored. CCB Phase 3.25 no longer
asks about Z epics.

---

## Step 3g: Assign Machine / Agent / Model per Epic

Every epic gets execution context assigned. This comes from CCB Phase 3.3 decisions
(if called from `/ccb`) or is auto-assigned using these defaults.

**Goal: keep costs down and all machines running.** Use the cheapest model/agent that
can handle the task. Distribute work across machines to maximize throughput. Only use
opus for work that genuinely requires deep reasoning. Prefer free/cheap agents for
routine code generation. **Ollama is zero-cost and should be the first choice for
any task it can handle.**

### Agent & Model Catalog

> Full lifecycle process for all agents: `.agents/reference/lifecycle_process.md`

| Agent | Sub-Models | Machine Constraint | Cost | Best For |
|-------|-----------|-------------------|------|----------|
| claude | opus, sonnet, haiku | any | $$$/$$/$ | Full tool access, complex reasoning, implementation |
| gemini | 2.5-pro, 2.5-flash, 2.0-flash | any | $$/$/ free | Architecture, specs, review, large context |
| codex | gpt-4.1, gpt-4.1-mini | any (cloud) | free | Standard code gen, tests, bulk work |
| cursor | sonnet, gpt-4.1 | mothership | $$/free | IDE-based UI/React, multi-file edits |
| ollama | qwen3:32b, llama3.3:70b, deepseek-r1:32b, codestral:22b, mistral:7b | **mothership ONLY** | free | Boilerplate, tests, docs, small refactors, code completion |

**Cost tiers:**
- **Free:** codex/gpt-4.1, codex/gpt-4.1-mini, ollama/*, gemini/2.0-flash
- **Cheap:** claude/haiku, gemini/2.5-flash
- **Standard:** claude/sonnet, gemini/2.5-pro, cursor/sonnet
- **Premium:** claude/opus (use sparingly — architecture, audits, gates only)

**Ollama sub-model selection:**
- `qwen3:32b` — default, best general code quality at 32B
- `codestral:22b` — pure code completion, fast
- `deepseek-r1:32b` — reasoning-heavy tasks (mini-opus)
- `llama3.3:70b` — largest context, slower, use for bigger tasks
- `mistral:7b` — fastest, use for trivial tasks only

### Epic-Level Routing Defaults

Every epic gets **Primary + Backup 1 + Backup 2**. All three must use DIFFERENT agents.

| Epic Type | Primary | Backup 1 | Backup 2 | Why |
|-----------|---------|----------|----------|-----|
| VERIFY | workhorse/claude/sonnet | mothership/ollama/qwen3:32b | auditor/gemini/2.5-flash | Routine checks — try local first |
| Feature (standard code) | workhorse/codex/gpt-4.1 | mothership/ollama/qwen3:32b | auditor/gemini/2.5-flash | Free tier cascade |
| Feature (boilerplate/CRUD) | mothership/ollama/codestral:22b | workhorse/codex/gpt-4.1 | auditor/gemini/2.0-flash | Cheapest possible |
| Feature (architecture/spec) | workhorse/claude/opus | mothership/gemini/2.5-pro | workhorse/codex/gpt-4.1 | Deep reasoning needed |
| Feature (UI/React) | mothership/cursor/sonnet | workhorse/codex/gpt-4.1 | mothership/ollama/qwen3:32b | Cursor excels at UI |
| Feature (CV/ML) | mothership/ollama/deepseek-r1:32b | workhorse/claude/sonnet | mothership/gemini/2.5-pro | Local inference + reasoning |
| Feature (data/ETL) | workhorse/codex/gpt-4.1 | mothership/ollama/qwen3:32b | auditor/gemini/2.5-flash | ETL is standard code |
| Feature (Python/complex) | workhorse/claude/sonnet | mothership/ollama/qwen3:32b | auditor/gemini/2.5-flash | Needs Python expertise |
| HARDEN (audits) | workhorse/claude/opus | mothership/gemini/2.5-pro | workhorse/codex/gpt-4.1 | Deep reasoning |
| Z (E2E) | mothership/claude/opus | workhorse/gemini/2.5-pro | mothership/cursor/sonnet | Operator-interactive |

**Backup rules:**
- Primary, Backup 1, and Backup 2 must ALL use **different agents** (never claude→claude→gemini)
- Backup machine SHOULD differ from primary when possible
- Backup model must be from its agent's ecosystem
- If primary fails/is unavailable, factory falls back to Backup 1 automatically, then Backup 2

**Ollama Emergency Fallback (MANDATORY):**
Every epic and every task MUST specify an Ollama model in its Execution Context,
even if Ollama isn't Backup 1 or 2. This is the "tokens ran out" safety net.
Format: `Ollama fallback: mothership/ollama/{model}` — always mothership, always free.
- Default: `mothership/ollama/qwen3:32b` (best general quality)
- For pure code tasks: `mothership/ollama/codestral:22b`
- For reasoning-heavy: `mothership/ollama/deepseek-r1:32b`
- For large context: `mothership/ollama/llama3.3:70b`

### Milestone-Level Backup

In addition to per-epic assignments, assign ONE milestone-level backup — the agent+model
you'd use if you had to run the ENTIRE milestone on a single fallback:

```
## Milestone Backup
If Claude is unavailable for this milestone:
  Fallback: {machine}/{agent}/{model}  (e.g. workhorse/codex/gpt-4.1)
  Ollama tasks: mothership/ollama/qwen3:32b (always available, zero cost)
```

This goes in the milestone description in Linear.

### Task-Level Routing Overrides

Tasks inherit epic defaults but can override. Route by task characteristics:

| Task Type | Model Override | Why |
|-----------|---------------|-----|
| size:S + type:test | ollama/codestral:22b or haiku | Simple test scaffolds — try local first |
| size:S + type:docs | ollama/mistral:7b or gemini/2.0-flash | Cheapest for docs |
| size:S + non-critical | ollama/qwen3:32b or codex/gpt-4.1-mini | Zero/low cost |
| size:M + standard code | codex/gpt-4.1 or ollama/qwen3:32b | Cost-effective code gen |
| size:M + Python-heavy | claude/sonnet or ollama/qwen3:32b | Needs Python expertise |
| size:L + architecture | claude/opus | Worth the cost |
| type:audit | claude/opus or gemini/2.5-pro | Must be thorough |
| type:gate | claude/opus | Critical decision point |
| Schema/migration | claude/opus | Correctness critical |

### Machine Distribution

Spread work across machines to maximize parallelism:
- **Mothership**: Operator-interactive tasks, ALL Ollama tasks, Cursor tasks, CV pipeline
- **Workhorse**: Always-on factory tasks (claude/codex), bulk code gen, tests, ETL
- **Auditor**: Review tasks, gemini tasks, lightweight builds

**Ollama runs ONLY on mothership** — it requires the local GPU. Never assign ollama to workhorse or auditor.

Never pile all tasks on one machine when others are idle.

Add to epic labels: `agent:{agent}`, `model:{model}`, `machine:{machine}`
These propagate to child tasks as defaults (tasks can override).

Operator can override any assignment during Step 4 review.

---

## Step 4: Operator Review (Interactive)

Present the full plan to Operator:

```
Milestone {milestone_id}: {goal}
Acceptance Criteria: {count}
Epics: {count} ({count} feature + 1 hardening)
Total Tasks: {count}
Estimated Factory Time: {estimate}

Epic Order:
1. [{milestone_id}] VERIFY ({task_count} tasks)
2. [{milestone_id}] {title} ({task_count} tasks, {deps})
3. [{milestone_id}] {title} ({task_count} tasks, {deps})
...
N. [{milestone_id}] HARDEN ({task_count} tasks)
```

Ask Operator:
1. "Does this epic ordering make sense?"
2. "Any tasks missing or unnecessary?"
3. "Should any epics be split or merged?"
4. "Priority labels for the tasks?" (P0/P1/P2)

---

## Step 5: Create Artifacts (Linear Only)

> **Linear is the sole planning/tracking layer. No GitHub milestones or tracking issues.**
> Epics and tasks go to Linear. The factory webhook reads from the task manager queue.
> GitHub is for code, PRs, and CI only.

> **BATCH STRATEGY — MANDATORY to maintain quality across all tasks:**
> Do NOT write task descriptions on-the-fly during `save_issue` calls. That pattern causes
> later tasks to be thin because context is exhausted. Instead:
>
> 1. **Draft ALL task descriptions in conversation first** (before any `save_issue` calls).
>    Write each task body in full — all 15+ sections with real content.
> 2. **Review the full set** for quality and consistency.
> 3. **Then create in Linear** — at that point you're copy-pasting complete descriptions,
>    not generating under pressure.
>
> This ensures task #1 and task #30 receive equal attention.

### 5a-pre: Resolve Project & Milestone in Linear (CRITICAL)

**Before creating ANY issue, resolve the Linear project and milestone IDs.**

```python
# 1. Find the Linear project by code prefix
projects = list_projects(team: "{task_team_id}")
# Match project by milestone code prefix (e.g., CVX → "Computer Vision", ETL → "Pipeline / ETL")
# Store: {project_id}

# 2. Find or create the Linear milestone
milestones = list_milestones(team: "{task_team_id}")
# Match milestone by name containing {milestone_id} (e.g., "CVX005E")
# If not found, create it:
#   save_milestone(name: "{milestone_id}: {goal}", team: "{task_team_id}")
# Store: {milestone_id_linear}
```

**CONFIRMATION GATE — show the user before proceeding:**

```
LINEAR TARGET CONFIRMATION
━━━━━━━━━━━━━━━━━━━━━━━━━

  Team:      {task_team_id}
  Project:   {project_name} ({project_id})
  Milestone: {milestone_name} ({milestone_id_linear})
  Labels:    milestone:{milestone_id}, epic, type:{type}

  Creating: {epic_count} epics, {task_count} tasks

  Confirm? (y/n)
```

Use `AskUserQuestion` to confirm. **Do NOT create any issues until confirmed.**
If the project or milestone looks wrong, let the user correct it before proceeding.

### 5a: Create Epic Issues in Linear

**DEDUP CHECK:** Before creating ANY epic, search Linear:
```
list_issues(team: "{task_team_id}", query: "E{number}")
```
If a matching epic exists, update it with `save_issue(id: "{n}",...)`.

For each epic, call `save_issue` with:

```
title: "[{milestone_id}] {title}"
team: "{task_team_id}"
state: "Backlog"
priority: {1=Urgent, 2=High, 3=Normal, 4=Low}
projectId: {project_id}              ← MUST be set
milestoneId: {milestone_id_linear}   ← MUST be set
labels: ["epic", "priority:{level}", "machine:{machine}", "type:{type}", "milestone:{milestone_id}"]
description: (markdown — same structure as before, see below)
```

> **blockedBy wiring — do NOT skip:** After all epics are created, wire `blockedBy` relations per
> Section 3b.1. See Step 5a.5 below for the two-pass algorithm. The Linear UI "Blocked by"
> widget, `/epic start` dependency check, and `linear_epic_ops.py next` all read the structured
> field — markdown bullets alone are invisible to these tools.

Epic description body (markdown — ALL placeholders must be replaced with real content, minimum 2-3 sentences per section):
```markdown
## Goal
{2-4 sentences: WHAT this epic delivers, WHY it matters for the milestone, and what breaks if it's skipped}

## Milestone
{milestone_id}: {goal}

## Git
- **Branch:** `{type}/{prefix}-{epic_id}-{short-kebab-name}`
- **PR target:** `develop`
- **PR scope:** All tasks in this epic ship as one PR
- **Commit prefix:** `[{TYPE}] {prefix}-{task_id}: {what changed}`

## Outcome
- **Measured By:** {SQL query, test command, or metric that proves completion}
- **Baseline:** {current state}
- **Target:** {what "done" looks like in numbers}

## What Should Happen When This Epic Is Done
- {Concrete outcome 1}
- {Concrete outcome 2}

**Spec Section:** {spec_file}#§{section}
**Dependencies:** {deps — list {prefix}-{n} identifiers}

### Acceptance Tests
`tests/milestones/m{id}/test_e{number}_{name}.py`
- [ ] {test 1}
- [ ] {test 2}

### Tasks
_Task {prefix}-{n} identifiers filled after task creation._

### Exit Criteria
{criteria}

---

## Execution Context

- **Machine:** {machine}
- **Agent:** {agent}
- **Model:** {model}
- **Backup 1:** {backup1_machine}/{backup1_agent}/{backup1_model}
- **Backup 2:** {backup2_machine}/{backup2_agent}/{backup2_model}
- **Ollama fallback:** mothership/ollama/{ollama_model}

## Process Reference

All agents MUST read `.agents/reference/lifecycle_process.md` before starting work.
This file contains the full branch, commit, PR, and review process — agent-agnostic.

## Lifecycle Instructions (for all agents — Claude, Gemini, Codex, Cursor, Ollama)

### Starting This Epic
1. Branch from `develop`: `git checkout -b {branch_name}`
2. All tasks are commits on this branch — do NOT create sub-branches
3. Commit format: `[{TYPE}] {prefix}-{task_id}: {description}`
4. If using Claude Code: run `/epic start {prefix}-{epic_id}`

### Working Tasks
1. Read the task's ## Required Reading section first
2. Follow ## Steps exactly
3. Run the test in ## Outcome after each task
4. Commit immediately after each task passes
5. Mark each task Done in Linear when its commit is pushed

### Closing This Epic
1. Run acceptance tests: `pytest {test_file} -v`
2. Create PR to `develop` with title: `[{MILESTONE}] {Epic Title}`
3. Wait for CodeRabbit + assigned model reviewers
4. Fix any blocking review feedback, push, re-request review
5. Do NOT merge — wait for Operator approval (unless autonomy:green)
6. After merge: mark all tasks and this epic as Done in Linear
7. Post "What Actually Happened" comment on this epic: delivered items, PR link, test results, deferred items
8. **Start a new session for the next epic**
9. If using Claude Code: run `/epic close {prefix}-{epic_id}`

---

## What Actually Happened
_To be completed at epic close._

## Auditor Comments
_To be completed at epic close._
```

**Record the returned `id` (e.g. {prefix}-7) — you need it as `parentId` for tasks.**

### 5a-post: Spec Coverage Producer Hook (REQUIRED — D-1427)

Immediately after each successful `save_issue` epic
creation, write the epic's spec-coverage row to spec-coverage storage (supabase → `{storage_schema_qa}.spec_section_coverage`).
This is the producer half of the §46 spec-coverage loop. Locked by
[D-1427](../../../docs/decisions/D-1427-spec-coverage-producer-interface.md).

For each epic created in 5a, build a JSON payload from the epic and pass
it on stdin to Python — never embed the epic description as a raw
triple-quoted string (epic bodies frequently contain quotes, backticks,
and shell metacharacters that would break the literal):

```bash
EPIC_PAYLOAD=$(python3 -c "import json; print(json.dumps({
  'epic_id': '{epic_id}',
  'epic_status': 'Backlog',
  'epic_description': '''{epic_description_python_safe}''',
}))")

echo "$EPIC_PAYLOAD" | python3 -c "
import sys, json
from scripts.factory.spec_coverage_writer import upsert_planned_coverage_from_description
payload = json.load(sys.stdin)
results = upsert_planned_coverage_from_description(**payload)
for r in results:
    print(json.dumps(r))
"
```

If the calling agent already has the epic body in a Python variable
(`epic["description"]`), prefer calling
`upsert_planned_coverage_from_description(...)` directly — the
JSON-via-stdin shape exists only for shell-based invocations where the
body needs to cross a shell boundary safely.

The hook is **non-blocking** — if Supabase is unreachable or the
section row is missing from the scanner ledger, the writer logs a
warning and returns a result dict; it never raises. Epic creation
proceeds regardless. Skipped silently when the epic body has no
`**Spec Section:**` line (epics without spec refs are valid).

Print one line per (spec_file, section_id) pair: `coverage: {epic_id}
{spec_file}#{section_id} → ok|warning|error`. After all epics, expect
≥1 `ok` per epic that carries a `**Spec Section:**` line.

### 5a.5: Wire Epic blockedBy Relations (Two-Pass — REQUIRED)

Epic `blockedBy` cannot always be set on create because a blocker may not exist yet (forward
reference). Use this two-pass strategy after ALL epics are created:

**Pass 1 — already done in Step 5a:** create every epic, collect returned identifiers in a map:
```
epic_ids = {
  "VERIFY": "{ID}",
  "E01":    "{task_prefix}-{n+1}",
  "E02":    "{task_prefix}-{n+2}",
...
}
```

**Pass 2 — wire blockedBy for each epic that has planned blockers:**
```
# Example: 3-epic chain E1 → E2 → E3, all gated by VERIFY, HARDEN at the end
save_issue({ id: epic_ids["E01"], blockedBy: [epic_ids["VERIFY"]] })
save_issue({ id: epic_ids["E02"], blockedBy: [epic_ids["VERIFY"]] })
save_issue({ id: epic_ids["HARDEN"], blockedBy: [epic_ids["E01"], epic_ids["E02"]] })
save_issue({ id: epic_ids["Z"], blockedBy: [epic_ids["HARDEN"]] })
```

**Rules:**
- `blockedBy` is append-only — calling `save_issue` with `blockedBy` on an existing epic ADDS
  relations without removing existing ones. Safe to call multiple times.
- `blocks` (inverse) is auto-populated by Linear — never set it explicitly.
- Markdown `## Blocked by` sections STILL appear in epic descriptions — relations supplement,
  they do not replace the human-readable markdown. Both must agree.
- Cross-milestone deps follow Section 3b.1 pattern: wire the dependent milestone's VERIFY epic
  to the prerequisite milestone's HARDEN epic.

> **Verification after Pass 2:** For each epic with blockers, call
> `get_issue(id: "{n}", includeRelations: true)` and confirm
> `relations.blockedBy` is non-empty. If empty, the wire was silently skipped — retry.

### 5d: Create Task Issues in Linear (DoR-Compliant)

> **QUALITY WARNING — READ BEFORE CREATING ANY TASK:**
> Every task description MUST be substantial. The factory agent reads ONLY the Linear issue —
> there is no other source of truth. Thin descriptions = broken factory runs.
>
> **Minimum content requirements (enforced — not advisory):**
> - `## Goal` — 2-4 sentences explaining WHAT and WHY (not just the title restated)
> - `## Context` — 3+ sentences: parent epic relationship, spec motivation, what depends on this
> - `## Steps` — 3-8 numbered steps, each with a specific file path or function name. Every step must be atomic (one green commit). Never write "implement X" without naming the file.
> - `## Required Reading` — at minimum 3 real file paths that exist in the repo (verify with `test -f`)
> - `## Pre-Answered Questions` — at minimum 2 Q&A pairs that pre-answer what a factory agent would ask
> - `## Acceptance Criteria` — at minimum 3 checkboxes with testable conditions
> - `## Spec Updates` — either list >=1 spec file + section, or write "None — no spec impact" with justification
> - `## Tests` — use the layer routing table (Step 2b) to identify which layer(s) apply to what THIS task builds. For every layer that applies, the test file is MANDATORY — not optional, not deferred, not "TODO." The file must exist on disk and fail (RED) before this task is created. Writing "None" is only valid if no layer in the routing table matches — justify it.
>
> **Anti-patterns that will FAIL review (do not do these):**
> - Placeholder text like "{one sentence}" or "{why}" left unfilled
> - Steps that say "implement X" without naming files or functions
> - `## Required Reading` with fewer than 3 files
> - `## Steps` with fewer than 3 numbered items
> - `## Goal` that just restates the title
> - Any section left at its template default
>
> **You are writing for a factory agent that has ZERO context beyond this ticket.**
> Write as if you are handing this to a smart developer starting on day 1 with no prior knowledge.
> Every ambiguity you skip = a wrong implementation or a stuck agent.

**DEDUP CHECK:** Search Linear for existing tasks before creating:
```
list_issues(team: "{task_team_id}", query: "{task title keywords}")
```

For each task, call `save_issue` with:

```
title: "{title}"
team: "{task_team_id}"
parentId: "{epic_identifier}"   ← e.g. "{{prefix}}-7" (the epic's Linear ID)
projectId: {project_id}         ← MUST match the epic's project
milestoneId: {milestone_id_linear} ← MUST match the epic's milestone
state: "Todo"
priority: {1-4}
labels: ["task", "model:{model}", "machine:{machine}", "priority:{level}", "autonomy:{level}", "milestone:{milestone_id}"]
description: (full DoR markdown body — see below)
```

Task description body (markdown — ALL sections required, ALL placeholders must be filled with real content):
```markdown
## Goal
{One sentence: what does this task achieve and why}

## Context
{Why this matters — link to parent epic, what depends on this, spec motivation}
Parent epic: {prefix}-{epic} — {epic_title}
{If blocked by prior task: "Blocked by {prefix}-{prev} which delivers {what}"}

## Git
- **Branch:** Work on parent epic branch `{type}/{prefix}-{epic_id}-{short-kebab-name}` — do NOT create a separate branch
- **Commit prefix:** `[{TYPE}] {prefix}-{task_id}: {what changed}`

## Spec Ref
{spec_file}#{section}

## Required Reading
- `{file_path_1}` — {why}
- `{file_path_2}` — {why}
- `rules/areas/{area}.md` — area-specific rules

## Pre-Answered Questions
- Q: {question} → A: {answer}

## Steps
1. Read Required Reading files above
2. {Concrete step with file path and function name}
3. {Next step}
4. {Verification: "Run `{test_command}` — expect {outcome}"}

> **Step authoring rule:** Each step must be atomic enough to be a single green commit.
> After each step: run its test, then commit. Max 5 files per step.
> If a step would touch >5 files or take >2 hours, split it into sub-steps.
> If a step needs a database, note: "Start `sandbox-postgres` before this step."

## Acceptance Criteria
- [ ] {testable criterion 1}
- [ ] {testable criterion 2}

## Outcome
- **Measured By:** {test command or file check}

## Guardrails
- {Scope limits}
- Do not modify files outside the scope of this task

## Spec Updates
Update these spec files if your changes affect their documented behavior:
- `{spec_file_1}` — §{section}: {what to update}
- `{spec_file_2}` — §{section}: {what to update}

_Spec updates MUST be included in the same PR as the code change. Do not merge code that makes a spec inaccurate._

## Tests
- Layer {N} ({layer_name}) — `tests/{suite}/test_{milestone_id_lower}_{epic_short}_{what}.py`
  - Asserts: {exact outcome this test checks — derived from exit criteria above}
  - Run: `pytest {test_file_path} -x --tb=short`

_Only include layers that match what this task actually builds (see layer routing table in Step 2b).
A SQL migration doesn't get a Playwright test. A hook doesn't get a canonical golden test.
Pick the 1-2 layers that directly prove this specific task's exit criterion — no more.
File must already exist on disk, written RED (failing) before tasks execute — see Step 2b.
completion-audit reads this section and runs these files before accepting Done/Complete.
Pre-commit guard blocks Done commits if the file is missing or pytest fails._

## Agents to Call
- {agent_1} — {what to review}
- code-reviewer — final code quality check

## TDD
- **Test file:** `tests/milestones/{milestone_id}/test_{epic_short_name}.py`
- **Test class:** `Test{MilestoneId}{EpicName}`

## Execution Context
- **Model:** {model}
- **Machine:** {machine}
- **Agent:** {agent}
- **Backup 1:** {backup1_machine}/{backup1_agent}/{backup1_model}
- **Backup 2:** {backup2_machine}/{backup2_agent}/{backup2_model}
- **Ollama fallback:** mothership/ollama/{ollama_model}

## Process Reference

**READ FIRST:** `.agents/reference/lifecycle_process.md` — full agent-agnostic process.
**Area rules:** `rules/areas/{area}.md`
**Core rules:** `rules/BASE.md`

## Lifecycle Instructions (for all agents — Claude, Gemini, Codex, Cursor, Ollama)

1. Work on parent epic branch `{branch_name}` — do NOT create a new branch
2. Commit format: `[{TYPE}] {prefix}-{task_id}: {description}`
3. **Commit after EACH step — not just at task completion.** Run the step's test first, then commit. Max 5 files per commit.
4. If a step requires a database, start `sandbox-postgres` first: `docker compose up -d sandbox-postgres`
5. Run `{test_command}` after implementation — must pass
6. Mark this task Done in Linear when complete
7. If using Claude Code and this is the last task: run `/epic close {prefix}-{epic_id}`

---
**Size:** {S|M|L}
**Blocked by:** {{prefix}-{prev} or "None"}

### Files to Modify
- `{file_path}` — {what changes}

### Files to Create
- `{file_path}` — {purpose}
```

#### 5d.0: Project-Specific Agent Routing (domain-specific — override in project overlay skill)

Use these when task domain matches. Each entry includes the agent definition file path
so non-Claude models (Gemini, Codex) can read the agent spec directly.

| Task Domain | Agent to Call | Agent File (absolute path) |
|---|---|---|
| Supabase migrations, RLS policies, Realtime config | `supabase-specialist` | `.claude/agents/07-specialized-domains/supabase-specialist.md` |
| dbt models, mart views, ETL transforms, stage→fact | `etl-specialist` | `.claude/agents/07-specialized-domains/etl-specialist.md` |
| FastAPI routes, Pydantic models, API endpoints | `backend-developer` | `.claude/agents/01-core-development/backend-developer.md` |
| Tracker / Scorekeeper UI (v30 event model, React) | `tracker-specialist` | `.claude/agents/07-specialized-domains/tracker-specialist.md` |
| Dashboard pages, live feed, Next.js pages | `dashboard-developer` | `.claude/agents/07-specialized-domains/dashboard-developer.md` |
| Playwright E2E tests, UI smoke tests | `ui-comprehensive-tester` | `.claude/agents/07-specialized-domains/ui-comprehensive-tester.md` |
| Completion reality audit (is it actually done?) | `{agents.completion_audit}` (default: `completion-audit`) | `.claude/agents/07-specialized-domains/completion-audit.md` |
| Spec compliance audit (does code match spec?) | `{agents.spec_audit}` (default: `spec-audit`) | `.claude/skills/spec-audit/SKILL.md` |
| Code quality review, PR review | `code-reviewer` | `.claude/agents/04-quality-security/code-reviewer.md` |
| IndexedDB, offline/sync, frontend state | `frontend-developer` | `.claude/agents/01-core-development/frontend-developer.md` |
| Hockey domain logic, event types, stat rules | `hockey-analytics-sme` | `.claude/agents/07-specialized-domains/hockey-analytics-sme.md` |
| Computer vision pipeline, XY tracking | `cv-engineer` | `.claude/agents/05-data-ai/cv-engineer.md` |
| Python ETL, pandas, calculations | `python-pro` | `.claude/agents/02-language-specialists/python-pro.md` |
| TypeScript, React, Next.js components | `typescript-pro` | `.claude/agents/02-language-specialists/typescript-pro.md` |

**How to use in task descriptions:**
The `## Agents to Call` section in each task body MUST list the specific agent names from this table
(not just "reviewer" or "audit agent"). Format:

```markdown
## Agents to Call
- `supabase-specialist` — review migration SQL for correctness and RLS policy
  File: `.claude/agents/07-specialized-domains/supabase-specialist.md`
- `code-reviewer` — final code quality check on all changed files
  File: `.claude/agents/04-quality-security/code-reviewer.md`
```

Non-Claude models: to read an agent's capabilities before calling it, `Read` the file at the
path listed above. All agent files are relative to the repo root:
`{project_root}/`

---

#### 5d.1: Auto-Populate DoR Sections

Before generating each task body, resolve these sections from plan context:

**Required Reading** — auto-discover from:
1. The task's area → map to key files using `areas` from `.claude/project-context.md`.
   If the project defines area→path mappings, use them. Otherwise, use `grep -rl {area_keyword}.`
   to find relevant files.
   > **Project overlay:** define your area mappings in `.claude/skills/plan-milestone/SKILL.md`
   > so this step uses project-specific paths instead of generic discovery.
2. The spec ref → include the spec file itself
3. `grep -rl` for function/class names mentioned in the task steps → include those files
4. Relevant decisions from your project's decision log (location defined in CLAUDE.md)

**Every file listed MUST exist in the repo.** Run `test -f {path}` before including.

**Model** — route by complexity (cheapest that works):
- `size:S` + `type:test` → `haiku` (cheapest)
- `size:S` + `type:docs` → `flash` (cheapest)
- `size:S` + non-critical → `sonnet`
- `size:M` + standard code → `sonnet` or `gpt-4.1` (if epic uses codex)
- `size:L` or architecture/spec-heavy → `opus`
- `type:audit` → `opus`
- `type:gate` → `opus`
- Schema/migration work → `opus`

**Agent** — inherit from epic, override if task needs differ:
- Tasks inherit parent epic's agent by default
- Override only when task requires a different capability
- E.g.: UI task in a data epic → cursor override

**Machine** — distribute across fleet:
- Default: inherit from parent epic
- Docker/container tasks → `workhorse`
- Tasks needing Ollama → `mothership`
- Interactive/Operator tasks → `mothership`
- Lightweight review/test tasks → `auditor` (keep it busy)
- Never stack all tasks on one machine

#### 5d.2: DoR Self-Check (MANDATORY before creating)

Before creating each task, verify ALL of these are true. **Do not skip — this is the gate.**

```
DoR CHECKLIST (all must pass — quality, not just presence):
[ ] Goal: 2-4 sentences, explains WHAT and WHY — not just the title restated
[ ] Context: 3+ sentences referencing parent epic, spec motivation, and what depends on this
[ ] Spec Ref: a real spec file path (test -f passes) — not a placeholder
[ ] Required Reading: >=3 files that exist in the repo (verified with test -f)
[ ] Pre-Answered Questions: >=2 Q&A pairs answering what a factory agent would ask
[ ] Steps: >=3 numbered items, each naming a specific file path or function
[ ] Steps: each step is atomic enough to be one green commit (max 5 files)
[ ] Acceptance Criteria: >=3 checkboxes with testable, specific conditions
[ ] Outcome: a concrete verification command (e.g., "pytest tests/... expect X passing")
[ ] Guardrails: >=1 specific scope limit (files NOT to touch, behaviors NOT to add)
[ ] Agents to Call: >=1 agent from the project routing table with file path
[ ] TDD: names a specific test file path and class name (not "TBD" or generic)
[ ] Model: set to a real model (not inherited placeholder)
[ ] Machine: set to a specific machine (mothership/workhorse/auditor)
[ ] Spec Updates: real file+section listed, or "None — no spec impact" with justification
[ ] Tests: layer number + file path matching what THIS task builds (use routing table) — file exists on disk and fails (RED)
[ ] Labels: task, model:*, machine:*, priority:* all present
[ ] NO unfilled placeholders: scan for {curly_braces} — all must be replaced with real values
```

**If ANY item fails:** rewrite the failing sections before calling `save_issue`. Do not create a thin ticket and plan to fix it later — it will fail the CCB quality sweep and require a re-run.

### 5e: Create Epic Exit Gate Task (MANDATORY for every epic)

Every epic MUST have a final review task as a child of the epic in Linear:

```
save_issue({
  title: "{prefix}-{epic}-REVIEW Exit gate verification",
  team: "{task_team_id}",
  parentId: "{epic_identifier}",
  state: "Backlog",
  priority: 2,
  labels: ["task", "model:opus", "machine:any"],
  description: "## Goal\nVerify epic {prefix}-{epic} achieved what it claimed...\n\n## Steps\n1. Run acceptance tests\n2. {agents.completion_audit} audit\n3. Fill What Actually Happened\n..."
})
```

The HARDEN epic does NOT get an exit gate task — it IS the exit gate.
The VERIFY epic DOES get one.

### 5e.1: Specialist Domain Review (MANDATORY for every epic)

After all tasks for an epic are drafted but BEFORE calling `save_issue` for any of them,
spawn the relevant domain specialist(s) to review the task set. This catches scope gaps,
wrong file targets, and missing guardrails that the completion/spec audits don't cover.

**Routing table — which specialist for which epic content:**

| Epic touches... | Specialist to call |
|---|---|
| Any SQL migration, RLS, Supabase schema | `supabase-specialist` |
| ETL pipeline, pandas, `src/calculations/`, dbt | `etl-specialist` |
| Next.js dashboard, React components, `ui/dashboard/` | `dashboard-developer` |
| Tracker UI, v30 event model, scorekeeper | `tracker-specialist` |
| CI/CD, GitHub Actions, `.github/workflows/` | `devops-engineer` |
| Hockey stat logic, xG, Corsi, Fenwick | `hockey-analytics-sme` |
| CV pipeline, `src/cv/`, camera calibration | `cv-engineer` |
| Python code quality, modularization | `python-pro` |
| TypeScript, strict mode, component patterns | `typescript-pro` |

**Always call regardless of domain:**
- `{agents.pragmatism_audit}` — checks for over-engineering, god objects, premature abstractions
- `hockey-analytics-sme` — if any stat counting, goal logic, or hockey domain is touched

**Prompt format (adapt per specialist):**
```
Review these planned tasks for epic [{milestone_id}] {epic_title}.
The epic goal: {goal}.
Tasks:
{numbered task list with Steps and Acceptance Criteria}

Flag: (1) missing files/functions we should read, (2) wrong approach for this domain,
(3) acceptance criteria that won't catch real failures, (4) scope that will cause issues.
Keep response under 300 words — actionable gaps only.
```

Incorporate any flagged gaps by updating task descriptions before creating them.
Document which specialists reviewed in the epic description under `## Specialist Review`.

### 5f: Update Epic with Task References

After all tasks are created, update each epic's description to include the
task {prefix}-{n} identifiers in the ### Tasks section:

```
save_issue({
  id: "{epic_identifier}",
  description: "...updated with task list..."
})
```

### 5g: Verify All Issues Linked Correctly (CRITICAL)

After creating all epics and tasks, run a verification sweep:

```python
# Pull all issues just created
issues = list_issues(team: "{task_team_id}", query: "[{milestone_id}]")

# Verify each one
for issue in issues:
    assert issue.project.id == {project_id}, f"{issue.identifier} has WRONG project: {issue.project.name}"
    assert issue.milestone.id == {milestone_id_linear}, f"{issue.identifier} has WRONG milestone"
    assert "milestone:{milestone_id}" in issue.labels, f"{issue.identifier} missing milestone label"
```

**Print verification report:**
```
LINEAR VERIFICATION
━━━━━━━━━━━━━━━━━━

  Issue         Project              Milestone            Labels                    Status
  ──────────── ──────────────────── ──────────────────── ──────────────────────── ──────
  {prefix}-{n}      ✓ {project_name}    ✓ {milestone_name}   ✓ epic, milestone:...   OK
  {prefix}-{n}      ✓ {project_name}    ✓ {milestone_name}   ✓ task, milestone:...   OK
  {prefix}-{n}      ✗ WRONG: {actual}   ✓ {milestone_name}   ✗ missing milestone:    FIX!

{pass_count}/{total_count} linked correctly
```

**If ANY issues are wrong:** fix them immediately with `save_issue` before proceeding.
**If ALL pass:** continue to 5h.

### 5h: Set Task Dependencies

Use Linear's `blockedBy` field:
```
save_issue({
  id: "{task_identifier}",
  blockedBy: ["{prev_task_identifier}"]
})
```
The REVIEW task is ALWAYS blocked by ALL other tasks in its epic.

---

## Step 5b: Write Task Plans to Supabase

After all task-manager issues are created, record each task via `save_task_plan` (supabase → `{storage_schema_qa}.task_plans`) to enable PR review cross-checks:

For each task created in Step 5a (storage backend op; no-op under `storage_backend: none`):
```
save_task_plan({task_ID}, { milestone: "{milestone_id}", epic: "{epic_ID}",
  goal: "{task goal}", steps, acceptance, planned_agent, planned_model, planned_machine,
  status: "planned" })
```

This feeds the PR review loop — reviewers `get_task_plan({task_ID})` to cross-check the implementation against the approved plan.

---

## Step 6: Save Plan

1. **The Linear project IS the plan.** No separate plan files. No IMPLEMENTATION_PLAN.md updates.
2. **Write decisions via `record_decision` (storage)** for any decisions made during planning
3. **Report** — Generate a full milestone summary with execution diagram:

   ```
   Milestone {milestone_id}: {goal}

   Epics: {count} | Tasks: {count} (all with parent epic relationships)

   EPIC ASSIGNMENTS
   | # | {prefix}-{id} | Title                | Deps       | Run Order | Primary              | Backup               |
   |---|----------|----------------------|------------|-----------|----------------------|----------------------|
   | 1 | {prefix}-{n}  | VERIFY               | none       | 1         | workhorse/claude/son | auditor/gemini/flash |
   | 2 | {prefix}-{n}  | {title}              | VERIFY     | 2 (parallel w/ E3)   | workhorse/codex/gpt4 | auditor/gemini/flash |
   | 3 | {prefix}-{n}  | {title}              | VERIFY     | 2 (parallel w/ E2)   | auditor/gemini/flash | workhorse/codex/gpt4 |
   | 4 | {prefix}-{n}  | {title}              | E2         | 3         | mothership/cursor/son| workhorse/codex/gpt4 |
   | 5 | {prefix}-{n}  | {title}              | E2, E3     | 4         | workhorse/claude/son | auditor/gemini/flash |
   | 6 | {prefix}-{n}  | HARDEN               | ALL (1-5)  | 5         | workhorse/claude/opus| mothership/gemini/pro|
   | 7 | {prefix}-{n}  | Z: E2E               | HARDEN     | 6         | mothership/claude/op | workhorse/gemini/pro |

   Format: machine/agent/model (abbreviated to fit)

   Execution Plan

           VERIFY ({prefix}-{n})
          /    |         \
     E02 ({n}) E03 ({n}) E05 ({n})  ← parallel (all depend only on VERIFY)
         |         |
      E04 ({n})    |                 ← depends on E02
         \        /
     HARDEN ({n})                    ← depends on ALL above
         |
       Z ({n})                       ← depends on HARDEN

   Run Order:
     Step 1: VERIFY
     Step 2: E02, E03, E05 (parallel — different machines)
     Step 3: E04 (blocked by E02)
     Step 4: HARDEN (blocked by ALL)
     Step 5: Z (blocked by HARDEN)

   {count} Tasks: {prefix}-{first} through {prefix}-{last}

   Test Scaffold
   - tests/milestones/{milestone_id}/test_{milestone_id}_acceptance.py — {count} tests, all RED/skipped
   - {count} test classes: {class names with test counts}

   DoR compliance: all tasks passed self-check.
   Ready for factory: run `/epic start {prefix}-{first_epic}` to begin.
   ```

   **Diagram rules:**
   - VERIFY is always the root node (no dependencies)
   - Epics with no cross-dependencies are shown on the same level (← parallel)
   - Epics with dependencies shown vertically with `|` connectors
   - HARDEN always depends on ALL feature epics
   - Z (if present) always depends on HARDEN
   - Include {prefix}-{id} numbers so the diagram is actionable
   - Use ASCII art — no unicode, no mermaid, just pipes and slashes
   - Run Order section lists steps sequentially, noting which can run in parallel
   - Parallel epics should be assigned to DIFFERENT machines when possible

   **Backup assignment rules (CRITICAL):**
   - Every epic gets **Primary + Backup 1 + Backup 2** — three different agents
   - Backup agent MUST be a different agent than primary AND each other (never claude→claude→gemini)
   - Backup machine SHOULD be a different machine than primary
   - Backup model MUST be from the backup agent's ecosystem
   - Ollama backups are ALWAYS on mothership (GPU required)
   - If primary fails/is unavailable, factory falls back to Backup 1 automatically, then Backup 2
   - Examples:
     - Primary: claude/opus → B1: gemini/2.5-pro → B2: codex/gpt-4.1
     - Primary: codex/gpt-4.1 → B1: ollama/qwen3:32b → B2: gemini/2.5-flash
     - Primary: cursor/sonnet → B1: codex/gpt-4.1 → B2: ollama/qwen3:32b
     - Primary: ollama/qwen3:32b → B1: codex/gpt-4.1 → B2: gemini/2.5-flash
   - NEVER: claude/opus → claude/sonnet → gemini (same agent in primary + backup)

   **Milestone-level backup** — shown at the top of the summary:
   ```
   Milestone Backup (if Claude unavailable): workhorse/codex/gpt-4.1
   Ollama fallback (always available): mothership/ollama/qwen3:32b
   ```

---

## Step 7: Find or Create Master Tracker Issue

**First: search for an existing tracker before creating.**

```
results = search_issues(
  query: "[{milestone_id}] 📋 MASTER TRACKER",
  filter: { label: "milestone-tracker" }
)
```

**If tracker found (reopened milestone case):**
- Read the existing tracker body to understand current state
- Update its body with current epic inventory (all epics, 🔲 for not-started, ✅/⏳ for any already done)
- Add a comment: `Milestone reopened {date}. Plan updated via /plan-milestone. Epics re-evaluated.`
- Note the existing `{task_prefix}-{tracker_number}` — skip to "Set milestone description" below

**If tracker NOT found (new milestone):**
```
save_issue(
  title: "[{milestone_id}] 📋 MASTER TRACKER — {goal}",
  team: "{task_team_id}",
  project: "{project}",
  milestone: "{milestone_linear_id}",
  priority: 1,
  labels: ["milestone-tracker", "milestone:{milestone_id}"],
  description: {full tracker body — use Step 3b template from /milestone start skill}
)
```

Populate at plan time:
- **Epic inventory table**: all epics, all 🔲, with blast radius + confidence 🟢 (freshly planned)
- **Mermaid dependency graph**: from the dependency ordering in Step 3b/3c
- **Decisions table**: decisions made during this planning session
- **Session estimate**: total sessions (never weeks — this is an AI factory)
- **Acceptance criteria**: from Step 2
- **Health emoji**: 🟢 (just planned)

Link tracker to every epic created:
```
for each epic {ID}:
  save_issue(id: "{ID}", relatedTo: ["{tracker_id}"])
```

**Set milestone Linear description** (always — whether tracker was found or created):
```
**Goal:** {one sentence}
**Why:** {one sentence}
**Estimate:** {N} sessions
**Master tracker:** {task_prefix}-{tracker_number}

> Always reference this milestone as: **{milestone_id} / {task_prefix}-{tracker_number}**
```

Print: `📋 Master tracker: {task_prefix}-{tracker_number} — always reference as {milestone_id} / {task_prefix}-{tracker_number}`

---

## Key Rules

- Acceptance criteria BEFORE epics. Epics BEFORE tasks. Tests BEFORE code.
- Every task must have testable completion criteria in the issue body
- **Every task must pass the DoR self-check (5d.3) before creation**
- Hardening epic is MANDATORY and ALWAYS last
- Dependencies must be explicit — no implicit ordering
- Epic size: 5-15 tasks. Bigger → split. Smaller → merge with related epic.
- Task size: S (< 30min), M (30min-2h), L (2h-4h). XL → split into subtasks.
- Labels drive factory routing: `machine:*`, `size:*`, `priority:*`, `type:*`
- Never create tasks for work that's already done (check closed issues first)
- Cross-reference spec sections — every task should trace back to a spec requirement
- **Required Reading files must exist** — verify with `test -f` before including
- **Steps must be concrete** — file paths, function names, specific changes (not "implement X")

## Judgment weave (see /judgment)

Before finalizing the epic/task breakdown:

1. **`/premortem`** the milestone plan — 5–8 past-tense causes of death; H×H risks get redesigned or gated.
2. Every epic's acceptance criteria include at least one **`GATE:`** line (metric | threshold | measured how | on-fail). "Works correctly" is not acceptance.
3. Any task that touches a one-way door (schema, stored formats, public contracts) is flagged with **`/door`** output in its ticket body, so the executor inherits the lock-in analysis instead of rediscovering it.
4. Plan-level verdicts → **`/verdict log`**.
