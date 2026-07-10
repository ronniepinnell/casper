---
name: epic
origin: authored
public: true
description: Epic lifecycle management — start, status, close. Wires the shared lifecycle narrative blocks at every transition. Use when transitioning between epics in a milestone.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, Agent, mcp__claude_ai_Linear__save_issue, mcp__claude_ai_Linear__list_issues, mcp__claude_ai_Linear__list_comments, mcp__claude_ai_Linear__get_issue, mcp__claude_ai_Linear__save_comment, mcp__claude_ai_Supabase__execute_sql
argument-hint: [start|status|close] {epic_id} [--honesty full|lite|off]
owner: factory
last_verified: 2026-05-25
generator: manual
area: factory
---

# /epic — epic lifecycle (start / status / close)

## Step 0 — load project context (run first)

Read `.claude/project-context.md` for `task_manager`, `task_prefix`, `task_team_id`,
`main_branch`, `storage_backend`, `scripts_dir`, `closed_epics_dir`, `factory_enabled`. Load the
task-manager adapter `_shared/adapters/{task_manager}.md` and storage backend
`_shared/storage/{storage_backend}.md`. Use their abstract operations (`get_issue`,
`update_issue`, `add_comment`, `record_decision`, `write_lifecycle_output`, …) for all
task/memory actions — never a task-manager API or raw table directly.

`{ID}` = `{task_prefix}-{n}`.

> **Factory overlay.** Steps tagged **[factory]** run only when `factory_enabled: true` — the
> honesty stack, `factory_state` slot tracking, regret replay, breadcrumbs, machine routing,
> closed-epic YAML receipts, and GHA label swaps. With `factory_enabled: false` (the default for
> a plain repo), `/epic` runs the **core lifecycle**: start = branch + mark In Progress;
> status = gather + render; close = acceptance check → PR → review → merge → mark Done → persist
> outcome. The factory steps below reference `{scripts_dir}/factory/lifecycle_helpers.py` and
> friends, which exist only in a factory repo; skip them cleanly when the helper/marker is absent.

> **One epic = one branch = one PR.** All tasks in an epic are commits on that branch. The PR ships when the epic closes.
>
> **Lifecycle narrative blocks:** every status/start/close call renders the four blocks defined in `.claude/skills/_shared/lifecycle_blocks.md` — open that file BEFORE rendering output.
>
> **Inline state breadcrumbs:** emit `🧭 [slot-N · /epic <sub> · step X/Y · last: <prev> · next: <next>]` at the START of every numbered step. See `.claude/skills/_shared/breadcrumb.md` for the full spec. `slot-N` comes from `scripts.infra.slot_id.get_slot_id()`.
>
> **Subagent dispatches:** every `Agent(...)` call is preceded by a `🤖 Dispatching <agent> →... (~Nmin)` line per `.claude/skills/_shared/agent-dispatch.md`. Long-running agents (≥5min expected) get a 5-min keepalive line via `run_in_background: true` + `ScheduleWakeup`.
>
> **End-of-skill receipt block:** `/epic start`, `/epic close` emit the standardized `═══` receipt box per `.claude/skills/_shared/receipt-block.md`. Three components required: WHAT closed · WHERE (slot/repo) · WHAT'S NEXT.

## Subcommands

| Command | Purpose | Blocks rendered |
| --- | --- | --- |
| `/epic start {ID}` | Begin work — branch, prompts, kickoff | NARRATIVE (full) + AGENT SUGGESTIONS (LIGHT) |
| `/epic status {ID}` | Where we are right now | NARRATIVE + HONEST ASSESSMENT + OPERATOR ACTIONS + AGENT SUGGESTIONS (full) |
| `/epic close {ID}` | Close — PR review loop, audits, mark done, handoff | NARRATIVE + HONEST ASSESSMENT + OPERATOR ACTIONS + AGENT SUGGESTIONS (full) |

`--deep` flag on `/epic close` opts in to the full subagent panel (otherwise close uses inline reasoning).

---

## `/epic start {ID}`

### Step 0 — load the shared template

Read `.claude/skills/_shared/lifecycle_blocks.md`. The four-block schema and tone-calibration guardrails are non-negotiable.

Also read `.claude/skills/_shared/{breadcrumb,receipt-block,agent-dispatch}.md` once at session start to anchor format rules.

🧭 Emit breadcrumb: `[slot-N · /epic start · step 0/5 · last: invocation · next: read epic]`

### Step 0a — register slot + mark active

First-time registration populates `repo`, `branch`, `model` fields — `update_active`
alone uses `setdefault` and leaves those columns blank, which makes `/factory-status`
show "BRANCH: -" for the slot. Always call `register` before `active`:

```bash
python3 {scripts_dir}/infra/factory_state.py register
python3 {scripts_dir}/infra/factory_state.py active "/epic start" "{ID}" "1/5"
```

Non-blocking — registry writes never block the skill.
If the file is missing or locked, log a warning and continue.

### Step 1 — read epic from Linear

```text
get_issue({ID})
```

Extract: branch name (from `## Git`), dependencies, child tasks, execution context, acceptance tests path, milestone id, spec ref.

If ANY dependency epic is NOT Done, STOP and report.

### Step 2 — create branch + push

```bash
git checkout {main_branch} && git pull --ff-only origin {main_branch}
git checkout -b {branch_name}
git push -u origin {branch_name}
```

### Step 3 — mark In Progress

```text
update_issue({ID}, { state: "In Progress" })
```

Apply to all child tasks as well.

### Step 3a — inherit honesty_mode from active session

The active milestone or pipeline session row carries `honesty_mode` (see
`/milestone start` Step 3 or `/pipeline run` Step 0). Read it back so the
epic-start ceremony surfaces which gates will fire. A `--honesty <mode>`
override on the `/epic start` invocation wins over the inherited value:

```python
# Parse --honesty if present in argv
parts = argv.split()
cli_override = None
if "--honesty" in parts:
    i = parts.index("--honesty")
    if i + 1 < len(parts) and parts[i + 1] in ("full", "lite", "off"):
        cli_override = parts[i + 1]

from scripts.factory.lifecycle_helpers import current_honesty_mode
# Always pass the parent session id explicitly. The no-arg form falls
# back to the global most-recent in-flight row and can leak another
# operator's mode in concurrent runs. The parent_session_id comes from
# the milestone/pipeline session row (stored in conversation state at
# /milestone start Step 3 or /pipeline run Step 0).
inherited = current_honesty_mode(session_id=parent_session_id)
mode = cli_override or inherited or "lite"   # override > inherited > safe fallback
```

Surface in the start banner:

```text
📍 Branch: {branch_name}
   Epic:   {ID} — {title}
   Honesty stack: {mode.upper()}{" (--honesty override)" if cli_override else " (inherited)"}
```

The wired hooks at `/epic close` (verifier-isolation, transition-validator,
audit-doubt-check) consult this mode via `hooks_for_honesty_mode(mode)`
before firing. No need to re-write the session row at the epic level —
the override is conversation-local and tracked via the start banner.

### Step 3b — Regret replay

Before committing to a plan, query the regret log for prior failure modes
in this epic's area:

```bash
python3 {scripts_dir}/intel/query_regrets.py --area "${AREA_CODE}" --limit 5
```

`AREA_CODE` ∈ `factory | schema | cv | etl`. The script returns up to 5
markdown blocks. Copy them into the kickoff under a **"## Prior regrets
in scope"** heading. For each regret, name explicitly how this plan
avoids re-introducing the failure (one sentence). If no regret applies,
write `Prior regrets in scope: none applicable to this scope.` — silence
is not allowed.

### Step 4 — generate factory prompts (existing flow)

Read each task's `## Required Reading` + `## Steps` and dispatch per the model in `## Execution Context`. Non-Claude epics get a `/brief` redirect (see `.agents/reference/lifecycle_process.md`).

### Step 5 — render output

1. Pre-narrative banners (top, in order): `pr_state_banner`, `check_stale_handoff`, `check_multi_slot_collision`, `cognitive_load_banner`, `check_regret_log`, `session_length_banner`. `time_of_week_gate` is NOT rendered on `start` — it only fires on the `/close` merge step.
2. NARRATIVE block (full — see shared template).
3. AGENT SUGGESTIONS — LIGHT variant. Pull preflight ideas from `lifecycle_helpers.preflight_lessons(area)`.
4. Footers (in order from shared template): velocity emoji, downstream unblocks, decision provenance, stakeholders, linked ideas, competitor gap.
5. Cost footer (last line).

Persist with `lifecycle_helpers.write_lifecycle_output(issue_id, "epic", "start", model=...)`.

---

## `/epic status {ID}`

### Step 0 — load shared template

Same as `/epic start`.

### Step 1 — gather context (parallel where possible)

- Linear: `get_issue` + child task statuses
- Git: `git diff --name-only {main_branch}...{branch}` for changed files
- Supabase via helpers: `query_spec_coverage_delta`, `query_decision_provenance`, `query_downstream_unblocks`, `query_reviewer_track_record`, `check_regret_log`
- gh: `pr_state_banner`, `check_multi_slot_collision`

### Step 2 — render all four blocks (full)

Render in this order:
1. Pre-narrative banners.
2. NARRATIVE block.
3. HONEST ASSESSMENT — apply tone calibration guardrails.
4. OPERATOR ACTIONS.
5. AGENT SUGGESTIONS (full) — use `lifecycle_helpers.select_consultation_agents(...)` with all 7 signals enabled.
6. Footers per shared template (full list).
7. Cost footer (last line).

### Step 3 — subagent dispatch (deep panel)

For each of the agent suggestions, optionally spawn a `code-reviewer` subagent in parallel to deepen the relevant section. This is the default behavior of `/status`; `/epic status` inherits it.

### Step 4 — persist

`lifecycle_helpers.write_lifecycle_output(issue_id, "epic", "status", model=..., narrative={...}, assessment={...}, actions={...}, agent_suggestions=[...])`

---

## `/epic close {ID}`

The full close runbook is unchanged from prior epic skill — the four-block render is layered ON TOP at Step 6, and a new git cleanup step lands at 4e.2.

🧭 Emit breadcrumb at every step transition (see header).

### Step 0 — idempotency check — HARD GATE

Before any other work, check whether this epic has already been closed:

```text
# 1. task-manager receipt comment
list_comments({ID}, limit: 50)
```

Scan for any comment body matching `^## ✅ Epic Closed — {ID}\b`. If found:

```text
get_issue({ID})  # for the existing receipt
```

```python
# 2. Closed-epic YAML receipt file
from scripts.infra.closed_epic_receipt import read_receipt
prior = read_receipt("{ID}")
```

If EITHER signal indicates prior close:

```text
AskUserQuestion:
  question: "{ID} was closed at {prior.closed_at} by slot-{prior.slot}/{prior.model}.
             Re-run /epic close?"
  options:
    - "No — print prior receipt and exit (Recommended)"
    - "Amend — add a supplementary receipt comment (don't overwrite YAML)"
    - "Yes — full ceremony again (write new qa.gate_results row, new YAML with overwrite=True)"
```

Default to "No — print prior receipt and exit." Re-running a clean close is rarely intentional.

If neither signal: proceed to Step 1.

### Step 0a — register slot + mark active in factory-state (T6)

```bash
python3 {scripts_dir}/infra/factory_state.py register
python3 {scripts_dir}/infra/factory_state.py active "/epic close" "{ID}" "1/8"
```

### Step 0b — Cross-model HARDEN enforcement — HARD GATE

**Fires only when** the epic title contains `HARDEN` or `VERIFY`. Skip otherwise.

A HARDEN epic that runs on the same model as the feature epic it's hardening
is a fox-guarding-henhouse pattern — the same blind spots that let the bug
ship will let it pass HARDEN. This step enforces cross-model execution.

1. Read the epic's parent milestone:

   ```text
   get_issue({ID})
   ```

   Extract `milestone_id` from the labels (`milestone:{CODE###X}`).

2. List sibling Done feature epics in the same milestone:

   ```text
   list_issues({ team: {task_team_id}, label: "milestone:{CODE###X}", state: "Done" })
   ```

   Filter to feature epics (exclude HARDEN/VERIFY/CLEANUP siblings).

3. Collect the `model:*` label from each sibling (every epic close-comment
   carries the model that ran it via `model:claude-opus-4-7` etc.).

4. Read the current runtime model from the prompt context (the `Opus 4.7` /
   `Sonnet 4.6` / `Haiku 4.5` line in the system prompt, or
   `$CLAUDE_MODEL` / `$ANTHROPIC_MODEL` env var if running headless).

5. If the current model matches ANY sibling model:

   ```text
   AskUserQuestion:
     question: "HARDEN must be cross-model. Sibling epics ran on
                {model_list}. Current runtime is {current_model}.
                Continue anyway with attestation?"
     options:
       - "No — assign to a different model (Recommended)"
       - "Yes — log attestation in intel.decisions and continue"
   ```

   If "Yes":

   ```
   record_decision(
     title: "Same-model HARDEN proceeded with operator attestation",
     body:  "{operator-supplied reason}",
     type:  "cross_model_harden_waiver",
     ref_id: "{ID}"
   )
   ```

   If "No": STOP. Do not proceed with close. Re-dispatch the epic to a
   different model (see `/brief` skill for cross-model briefing).

### Steps 1-3 — pre-close validation, acceptance tests, PR creation

(Unchanged from prior `/epic close` flow — see `.agents/reference/lifecycle_process.md` "Closing an Epic" for the full procedure.)

### Step 3a — PR review loop gate — skill-prose enforcement

**Soft gate enforced by skill prose.** A compliant agent stops at this `AskUserQuestion`
prompt; non-compliant agents could march past. Real enforcement (branch protection,
required status checks, CodeRabbit GHA) lives outside this skill — this step closes
the soft loop. Documented honestly per the close-audit findings.

Cannot proceed past this step without one of:

1. `/pr-review-loop {pr_number}` run to terminal state (MERGED, READY_FOR_CEO, NEEDS_WORK), OR
2. Explicit `skip-with-reason: "<Operator directive>"` from the operator.

```text
AskUserQuestion (only if neither condition is detected):
  question: "PR review loop has not run for #{pr_number}. Required before merge."
  options:
    - "Run /pr-review-loop {pr_number} now (Recommended)"
    - "Skip — Operator has reviewed manually (must provide reason)"
    - "Skip — out-of-scope hotfix (must provide reason)"
    - "Cancel — abort /epic close"
```

If "Skip" with reason: record it immediately via the storage backend:

```
record_decision(
  title: "pr-review-loop-skipped",
  body:  "{reason}",
  type:  "pr-review-loop-skipped",
  ref_id: "{ID}"
)
```

This makes every skipped review-loop discoverable later (no-op under `storage_backend: none`).

### Step 3b — Acceptance Query gate — HARD GATE

**Fires when** the epic title contains `HARDEN` or `VERIFY`, OR the epic body has an
`## Outcome` section with quantitative thresholds (e.g. `≥ N`, `< 5%`, percentages,
row counts). Otherwise skip this step.

When fired, the epic body MUST contain a fenced ```` ```sql ```` block under an
`## Acceptance Query` heading. The skill:

1. Extracts the SQL via the helper:

   ```bash
   python3 {scripts_dir}/skills/parse_acceptance_query.py /tmp/epic_body.md
   ```

   - Exit 2 → no `## Acceptance Query` section. STOP and require the epic
     author to add one before close can proceed.
   - Exit 3 → SQL contains `LIMIT \d+` (T8: sampling-vs-enumeration rule).
     STOP and require the author to replace LIMIT with `COUNT(...)` or full
     enumeration. The error message names the offending line.
   - Exit 0 → SQL printed to stdout.

2. Runs the extracted SQL against the live DB:

   ```bash
   python3 {scripts_dir}/infra/run_sql.py "<SQL>" > /tmp/aq_result.json
   ```

3. Pastes the JSON result verbatim into the epic close comment under a
   `### Acceptance Query Result` subheading so future readers see the exact
   numbers without re-running the query.

4. Compares the result against the threshold stated in `## Outcome`. If the
   measured value falls below the stated threshold:

   - **STOP. Cannot mark Done.** Surface the gap (`measured=X, threshold=Y`)
     to the operator and require either:
       - Fix the gap and re-run the gate, OR
       - Convert the epic to PARTIAL with explicit deferred items captured
         in `intel.decisions` (category=`acceptance_query_partial`).

This step is the teeth behind every "VERIFY" claim — sampling/LIMIT and
"looks done" assertions are the recurring pattern that ships broken epics.

### Step 4 — PR review loop (unchanged)

Three-phase wait → reviewers → fix cycles → Operator confirmation.

🤖 Dispatch agents (`{agents.completion_audit}`, `{agents.code_review}`, specialists — defaults: completion-audit, code-reviewer) per `_shared/agent-dispatch.md` — pre-dispatch line + 5-min keepalive on long runs.

### Step 4e — merge PR (Operator confirms)

```bash
gh pr merge {pr_number} --squash --delete-branch
```

If `time_of_week_gate()` returns a banner, surface it AT this step and require explicit `y` before merging.

### Step 4e.2 — local git cleanup (NEW — added by lifecycle-narrative-v1)

Auto-run, fishy-check first:

```bash
# Switch back to {main_branch}
git checkout {main_branch}
git pull --ff-only origin {main_branch}

# Fishy-check: any commits ahead of the merged PR's merge commit?
LOCAL_HEAD=$(git rev-parse {epic_branch})
MERGE_COMMIT=$(gh pr view {pr_number} --json mergeCommit --jq '.mergeCommit.oid')
AHEAD_COUNT=$(git rev-list --count "$MERGE_COMMIT".."$LOCAL_HEAD" 2>/dev/null || echo 0)
if [ "$AHEAD_COUNT" -gt 0 ]; then
  echo "⚠ Skipping cleanup: local branch has $AHEAD_COUNT commit(s) ahead of merged PR. Investigate manually."
  return 0
fi

# Fishy-check: uncommitted changes?
if [ -n "$(git status --porcelain)" ]; then
  echo "⚠ Skipping cleanup: uncommitted changes in worktree. Stash or commit first."
  return 0
fi

# Safe-delete local branch (refuses if not merged — extra safety net)
git branch -d {epic_branch} 2>&1

# Prune stale remote tracking refs
git fetch --prune origin

echo "✓ Local cleanup complete — back on {main_branch}, {epic_branch} removed, remote refs pruned."
```

Scope: ONLY operates on the current slot's worktree and the merged epic's branch. Do NOT touch other slots' worktrees. Do NOT `git worktree remove` — worktrees are session-scoped infrastructure that outlive epics.

### Step 4f — post-merge agents (unchanged)

doc-sync + rules-audit in parallel.

### Step 4g — Honesty-stack gates — HARD GATE

Before flipping the epic to Done, two pre-flip gates must pass. If either
fails, **STOP** — do not mark Done. Fix the underlying problem and re-run
the close.

**T5 — transition-validator:** confirms the Linear transition
is honest (not Backlog → Done with no startedAt; not In Progress → Done
with zero commits referencing the issue).

```python
import subprocess
from scripts.factory.lifecycle_helpers import (
    current_honesty_mode,
    run_transition_validator,
    should_run_hook,
)

# Mode gate: ``transition-validator`` is the cheapest of
# the honesty hooks and fires under both ``full`` and ``lite``. Only ``off``
# skips it. Resolve up-front so we can also skip the (modest) git rev-list
# probe when the hook itself is gated out.
#
# Scope to THIS close-ceremony's session row — the bare ``current_honesty_mode()``
# lookup with no session_id picks the most-recently-started in-flight row,
# which under concurrent operators could be SOMEONE ELSE'S session. Pass
# ``current_session_id`` (the row id /epic start inserted) explicitly so the
# gate uses this ceremony's mode. Fall back to ``"lite"`` if the row was
# written without a mode column (rare, but possible for legacy rows).
active_mode = current_honesty_mode(session_id=current_session_id) or "lite"
if should_run_hook("transition-validator", mode=active_mode):
    # commit_count:= number of commits on the epic branch referencing this
    # epic ID between Linear startedAt and now. Use subprocess.run(check=False)
    # so a missing branch / git error degrades to commits=0 (which the hook
    # treats as "no work done" and BLOCKS the close) instead of raising
    # CalledProcessError mid-ceremony.
    proc = subprocess.run(
        ["git", "rev-list", "--count", f"--grep={ID}", f"{epic_branch}", "^{main_branch}"],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode == 0:
        try:
            commits = int(proc.stdout.strip() or "0")
        except ValueError:
            commits = 0
    else:
        commits = 0  # git failed — treat as no evidence of work; the hook will BLOCK

    ok, msg = run_transition_validator(
        current_status=current_status,   # from get_issue
        new_status="Done",
        started_at=started_at_iso,        # from get_issue
        commit_count=commits,
    )
    if not ok:
        raise SystemExit(f"transition-validator BLOCKED: {msg}")
```

**T4 — verifier-isolation-check:** confirms the verifier that
ran the close-time audits (Step 2-3 in /milestone close, or the CR
verdict here) is NOT the same machine + model as the implementer.

For epic close: implementer = the model/machine that did the work (from
the active `qa.factory_session_log` row). Verifier = the model/machine
that ran the close ceremony OR the CR review. Pull both from the session
log.

```python
from scripts.factory.lifecycle_helpers import (
    current_honesty_mode,
    run_verifier_isolation_check,
    should_run_hook,
)

# Mode gate: verifier-isolation only fires under ``full``.
# When the active mode is ``lite`` or ``off`` we skip silently — same-model
# closes are tolerated under those modes by design.
#
# Scope to THIS close-ceremony's session row to avoid cross-session mode
# leakage under concurrent operators (see the transition-validator block
# above for the full rationale).
active_mode = current_honesty_mode(session_id=current_session_id) or "lite"
if should_run_hook("verifier-isolation-check", mode=active_mode):
    ok, msg = run_verifier_isolation_check(
        impl_machine=impl_session["actual_machine"],
        impl_model=impl_session["actual_model"],
        verifier_machine=verifier_session["actual_machine"],
        verifier_model=verifier_session["actual_model"],
    )
    if not ok:
        raise SystemExit(f"verifier-isolation BLOCKED: {msg}")
```

If neither isolation field can be determined (e.g. session log row
missing), treat as `(False, "isolation indeterminate")` and STOP — do
not silently pass. Use the `cross_model_harden_waiver` row (see Step 0b)
if and only if the Operator has explicitly approved a same-model close.

### Step 4h — E10 honesty-stack gates — HARD GATE

E10 added five more close-time gates. Each is mode-aware (`should_run_hook`)
so `lite` and `off` mode skips them cleanly. They run in this order — any
FAIL halts the close.

```python
import json
import subprocess
from scripts.factory.lifecycle_helpers import should_run_hook

active_mode = current_honesty_mode(session_id=current_session_id) or "lite"

# 1. done-evidence: every AC checkbox must have inline
#    evidence (PR #N, pytest path, or SELECT…=N). Reads the epic body
#    from Linear, scans `- [x]` lines.
if should_run_hook("done-evidence", mode=active_mode):
    subprocess.run(["bash", "{scripts_dir}/hooks/rule-honesty-H1-done-evidence.sh",
                    "--epic", f"{ID}"], check=True)

# 2. multi-model: COMPLEX epics need ≥2 distinct
#    actual_model rows in qa.factory_session_log for this epic.
if should_run_hook("multi-model", mode=active_mode) and complexity == "COMPLEX":
    subprocess.run(["bash", "{scripts_dir}/hooks/rule-honesty-H4-multi-model.sh",
                    "--epic", f"{ID}"], check=True)

# 3. pre-mortem-quality: the close comment must contain a
#    well-formed `## Pre-mortem` block with `### Likely Failure` + `### Mitigation`
#    sub-headers (≥50 chars, file/function reference). See Step 6 below.
if should_run_hook("pre-mortem-quality", mode=active_mode):
    proc = subprocess.run(
        ["bash", "{scripts_dir}/hooks/pre-mortem-quality-check.sh"],
        input=proposed_close_comment, text=True, capture_output=True,
    )
    if proc.returncode != 0:
        raise SystemExit(f"pre-mortem-quality BLOCKED: {proc.stdout}")

# 4. blast-radius: distinct (reviewer, reviewer_model) for
#    this epic must meet intel.blast_radius_policy threshold for (area, type).
if should_run_hook("blast-radius", mode=active_mode):
    proc = subprocess.run(
        ["python3", "-m", "scripts.audit.blast_radius_check", "--epic", f"{ID}"],
        capture_output=True, text=True,
    )
    verdict = json.loads(proc.stdout or "{}").get("status", "INCONCLUSIVE")
    if verdict in {"FAIL", "INCONCLUSIVE"}:
        raise SystemExit(f"blast-radius {verdict}: see {proc.stdout}")

# 5. eval-harness variance probe: on high-stakes COMPLEX
#    epics, re-run {agents.completion_audit} N=5 to measure auditor variance. Exit code 2 =
#    auditor unreliable on this target → ESCALATE.
if complexity == "COMPLEX" and feeling == "🔴":
    proc = subprocess.run(
        ["python3", "{scripts_dir}/audit/eval_harness.py",
         "--auditor", "{agents.completion_audit}",  # default: completion-audit
         "--target", f"{ID}",
         "--samples", "5", "--threshold", "0.05"],
        capture_output=True, text=True,
    )
    if proc.returncode == 2:
        # stddev > threshold — single auditor unreliable. Caller decides
        # between {increase samples, switch model, manual override}.
        # Do NOT mark Done. See docs/runbooks/honesty-stack.md.
        raise SystemExit(f"eval-harness ESCALATE: {proc.stdout}")
```

**Preview URL gate — UI-touching epics only:** When this
epic touches `ui/dashboard/**`, Step 3 PR creation requires a Vercel
preview URL in the PR body. The `preview-url-gate` workflow HEAD-checks
the URL on every push. See `{scripts_dir}/hooks/pre-pr-create-preview-url.sh`.

**Provenance pin — automatic:** Every commit on this
branch carries an `X-Generated-By: {model}/{session}/{prompt}` trailer
via `.git-hooks/commit-msg`. The `intel.commit_provenance` table is
written by `.git-hooks/post-commit`. No skill-side wiring required, but
operators must run `bash {scripts_dir}/setup/install-git-hooks.sh` once per
clone to activate.

### Step 4v — /verify smoke gate (APP006A+)

After all post-merge agents complete, run a quick smoke check to catch regressions introduced by this epic:

```bash
# Only runs if the dev server is available (non-blocking if not)
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 && {
  echo "Dev server detected — running /verify smoke"
  # Invoke verify skill in smoke mode for pages touched by this epic
  # The skill reads the epic's changed files and maps them to routes
}
```

If the epic title contains `HARDEN`:
- Run `/verify mechanical --milestone {milestone_id} --severity-gate p0` instead of smoke
- HARD GATE: cannot mark Done if any P0 issues remain

If the epic title contains `VERIFY-HUMAN`:
- Verify the VERIFY-HUMAN Linear epic has all flow issues marked Done
- HARD GATE: cannot mark Done if any walkthrough flows are incomplete

### Step 5 — mark Done in Linear (unchanged)

### Step 5a — Pre-mortem block — REQUIRED in close comment

Every `/epic close` ceremony MUST include a `## Pre-mortem` block in the
close comment, with two sub-headers ≥50 chars each that reference at
least one file or function:

```markdown
## Pre-mortem

### Likely Failure
<naming the most-probable failure mode for this work over the next
30 days, referencing at least one file or function>

### Mitigation
<concrete mitigation, also referencing at least one file or function>
```

Step 4h pipes the proposed close comment through
`{scripts_dir}/hooks/pre-mortem-quality-check.sh`. Exit code 2 → block.

Post-close, the values land in `qa.lifecycle_outputs` columns
`premortem`, `premortem_quality_score`, `premortem_blocked` (migration
`20261218180001_add_premortem_to_lifecycle_outputs.sql`).

### Step 6 — render lifecycle narrative blocks (NEW)

Render full blocks per the shared template:
1. Pre-narrative banners.
2. NARRATIVE block — emphasize WHAT IT UNLOCKS (the value just delivered).
3. HONEST ASSESSMENT — explicit scope retreats, candid MY THOUGHTS.
4. OPERATOR ACTIONS — focus WHAT I'D DO NOW on the next epic.
5. AGENT SUGGESTIONS (full).
6. All footers (close-specific: spec coverage delta is now post-vs-pre, surprises pattern detection, cost-to-value, cheaper-alt suggestion).
7. Cost footer.

Persist with `write_lifecycle_output(issue_id, "epic", "close",...)`.

After persisting: if a one-line pattern note can be extracted from the run ("ETL epics in this area need pg_sandbox reset"), call `write_lifecycle_lesson(issue_id, "epic", area, lesson)`.

### Step 6a — audit-doubt validation — HARD GATE

The rendered HONEST ASSESSMENT block MUST contain a
`## What I might be wrong about` block with ≥2 distinct doubts. The
`audit-doubt-check.sh` hook enforces this contract.

```python
from scripts.factory.lifecycle_helpers import (
    current_honesty_mode,
    run_audit_doubt_check,
    should_run_hook,
)

# Mode gate: audit-doubt fires under ``full`` only. Under
# ``lite`` and ``off`` the gate skips silently — operators have opted into
# a thinner doubt regime and the epic close proceeds without this hook.
#
# Scope to THIS close-ceremony's session row to avoid cross-session mode
# leakage under concurrent operators (see the transition-validator block
# above for the full rationale).
active_mode = current_honesty_mode(session_id=current_session_id) or "lite"
if should_run_hook("audit-doubt-check", mode=active_mode):
    ok, msg = run_audit_doubt_check(rendered_close_output)
    if not ok:
        raise SystemExit(f"audit-doubt-check BLOCKED: {msg}")
```

If the gate fires, re-render Step 6 with a doubt block that lists at
least two specific things you might be wrong about (not generic risks —
specific load-bearing assumptions in THIS epic's claim of Done). Then
re-validate. Do NOT mark Done until the doubt-check passes.

### Step 7 — close round + write outcome rows (unchanged)

### Step 7a — write closed-epic YAML receipt

```python
from scripts.infra.closed_epic_receipt import write_receipt
from scripts.infra.slot_id import get_slot_id, get_repo_basename

write_receipt(
    epic_id="{ID}",
    title="<epic title>",
    slot=get_slot_id(),
    repo=get_repo_basename(),
    model="<current model id>",
    pr_number=<pr_number>,
    pr_sha="<merge sha>",
    linear_receipt_comment_id="<id of canonical Step 6 comment>",
    gate_results_row_id=<id from Step 4e.1>,
    karen_verdict="<DONE | PARTIAL | NOT DONE>",
    measurements={<domain metrics>},
    deferred_items=[<list>],
    flags_for_ceo=[<list>],
)
```

Then commit + push as a follow-up:

```bash
git add {closed_epics_dir}/{ID}.yaml
git commit -m "[LIFECYCLE] {ID}: close receipt"
git push
```

`write_receipt` raises `ReceiptExistsError` on duplicate — that's expected from Step 0; here it should always succeed unless the user chose "Yes — full ceremony again" in Step 0 (then pass `overwrite=True`).

### Step 7b — mark idle in factory-state (T6)

```bash
python3 {scripts_dir}/infra/factory_state.py idle "{ID}"
```

### Step 7c — swap Linear ceremony label

The GHA workflow `.github/workflows/epic-merge-stamp.yml` stamped this epic
with `ceremony:pending` at PR merge. Now that the close ceremony is complete,
swap to `ceremony:done`. Without this swap, the `ceremony:pending` label
accumulates forever and the "Lifecycle close debt" Linear filter becomes
useless noise.

```text
# Read current labels
issue = get_issue({ID})
labels = [l for l in issue.labels if l != "ceremony:pending"] + ["ceremony:done"]

# Update
update_issue({ID}, { labels: labels })
```

Best-effort: if the task manager is unreachable, log a warning and continue. Do not
block the close on a label swap.

### Step 8 — session handoff + unmissable receipt block

Emit the standardized receipt block per `_shared/receipt-block.md`:

```text
═══════════════════════════════════════════════════════════
✅  EPIC {ID} CLOSED  (<epic title>)
    SLOT:     {slot}
    REPO:     {repo}
    TIME:     {ISO ts}
    MODEL:    {model}

    RECEIPTS:
      • Linear comment id={canonical receipt id}
      • qa.gate_results row id={row_id}
      • PR #{pr_number} sha={merge_sha[0:8]}
      • {closed_epics_dir}/{ID}.yaml

    📍 WHAT'S NEXT
    {one-line concrete next action — usually /epic start {next_ID}}
═══════════════════════════════════════════════════════════
```

Then emit the terminal effects (bell + title escape + macOS notification):

```bash
printf '\a'
printf '\e]0;%s · /epic close · DONE — BEN-%s\a' "$SLOT" "{n}"
command -v terminal-notifier >/dev/null && \
  terminal-notifier -title "[$SLOT] /epic close" \
    -message "{ID} closed — {whats_next}" \
    -sound default 2>/dev/null || true
```

>>> START A NEW SESSION for the next epic. <<<

---

## Key rules

- One epic = one branch = one PR. No exceptions.
- Never merge without Operator approval (unless `autonomy:green`).
- The shared template is non-negotiable — read it on every invocation.
- All narrative output persists to `qa.lifecycle_outputs` (internal-only RLS).
- Git cleanup (4e.2) is auto-run but fishy-checks first; safe-delete only.

## Judgment weave (see /judgment)

- **Start:** read the epic's `GATE:` lines from the plan; if there are none, author them now with `/gate` before any code — a gate added after results exist protects nothing.
- **During:** a bug fixed 2+ times in this epic triggers `/altitude` (mandatory descent one layer).
- **Close:** run **`/refute`** on the epic's own completion claim — state it falsifiably, attempt the strongest break, attach the verdict + evidence to the closing comment. `REFUTED` or `UNVERIFIED` blocks Done; mark PARTIAL honestly instead.
- Close verdicts → **`/verdict log`**.
