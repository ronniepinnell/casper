---
name: milestone
origin: authored
public: true
description: Milestone lifecycle — start, status, close. Wires the shared lifecycle narrative blocks. A milestone is a coherent slice of work with multiple epics + a CLEANUP epic at the end.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, Agent, mcp__claude_ai_Linear__save_issue, mcp__claude_ai_Linear__get_issue, mcp__claude_ai_Linear__list_issues, mcp__claude_ai_Linear__list_milestones, mcp__claude_ai_Linear__list_comments, mcp__claude_ai_Linear__save_comment, mcp__claude_ai_Supabase__execute_sql
argument-hint: [start|status|close] {milestone_id} [--honesty full|lite|off]
owner: factory
last_verified: 2026-05-25
generator: manual
area: factory
---

# /milestone — milestone lifecycle (start / status / close)

## Step 0 — load project context (run first)

Read `.claude/project-context.md` for `task_manager`, `task_prefix`, `task_team_id`,
`main_branch`, `storage_backend`, `scripts_dir`, `factory_enabled`. Load the task-manager
adapter `_shared/adapters/{task_manager}.md` and storage backend
`_shared/storage/{storage_backend}.md`; use their abstract operations for all task/memory
actions. `{ID}` = `{task_prefix}-{n}`.

> **Factory overlay.** Steps tagged **[factory]** run only when `factory_enabled: true` — the
> honesty stack, `factory_state` slot tracking, the loose-ends sweep, tripwire/blast-radius/
> rollback gates, and `/verify` integration. With `factory_enabled: false`, `/milestone` runs the
> **core lifecycle**: start = read milestone + mark first epic In Progress; status = gather +
> render; close = verify epics Done → CLEANUP epic → record outcome → mark Done. Factory steps
> reference `{scripts_dir}/factory/lifecycle_helpers.py` and friends; skip cleanly when absent.

> A milestone has format `M000{N}{Letter}` (e.g. `M0003A`) OR area-tagged like `FCT011C`, `DAT008A`. Every milestone ends in a CLEANUP epic for deferred items.
>
> **Lifecycle narrative blocks:** every status/start/close call renders the four blocks defined in `.claude/skills/_shared/lifecycle_blocks.md` — open that file before rendering output.
>
> **Inline state breadcrumbs:** emit `🧭 [slot-N · /milestone <sub> · step X/Y · last: <prev> · next: <next>]` at every numbered step. See `.claude/skills/_shared/breadcrumb.md`.
>
> **End-of-skill receipt block:** every `/milestone start` and `/milestone close` ends with the `═══` receipt block per `.claude/skills/_shared/receipt-block.md`.
>
> **Subagent dispatches:** pre-dispatch line + 5-min keepalive per `.claude/skills/_shared/agent-dispatch.md`.

## Subcommands

| Command | Purpose | Blocks rendered |
| --- | --- | --- |
| `/milestone start {id}` | Open the milestone, mark first epic In Progress | NARRATIVE (full) + AGENT SUGGESTIONS (LIGHT) |
| `/milestone status {id}` | Where the milestone is right now | NARRATIVE + HONEST ASSESSMENT + OPERATOR ACTIONS + AGENT SUGGESTIONS (full) |
| `/milestone close {id}` | Close — final audits, CLEANUP epic, telemetry | NARRATIVE + HONEST ASSESSMENT + OPERATOR ACTIONS + AGENT SUGGESTIONS (full) |

---

## `/milestone start {id}`

### Step 0 — load shared template
### Step 1 — read milestone from Linear

```text
list_milestones({ query: "{id}" })
```
### Step 2 — list epics + dependencies
### Step 3 — register session (storage `log_session`)

**3a — parse `--honesty` flag if present (T9).** The full args string may end
with `--honesty <mode>`. Extract `<mode>` if present, else None:

```python
# argv is the raw post-subcommand string (e.g. "FCT011C --honesty lite")
parts = argv.split()
cli_override = None
if "--honesty" in parts:
    i = parts.index("--honesty")
    if i + 1 < len(parts) and parts[i + 1] in ("full", "lite", "off"):
        cli_override = parts[i + 1]
# An unrecognised value falls through — resolve_honesty_mode treats invalid
# override as "ignore me" and uses the per-milestone glob or default_mode.
```

**3b — resolve + insert.** Call `insert_session_log()` from
`{scripts_dir}/factory/lifecycle_helpers.py` with the **detected** runtime values
(hostname → machine, system prompt → model). The helper honors the live check
constraints and writes the resolved `honesty_mode` so downstream hooks can
read it via `current_honesty_mode()`.

```python
from scripts.factory.lifecycle_helpers import (
    insert_session_log, resolve_honesty_mode,
)
mode = resolve_honesty_mode("{id}", override=cli_override)
session_id = insert_session_log(
    machine=detected_machine,        # mothership | workhorse | auditor
    model=detected_model,            # e.g. "claude-opus-4-7"
    branch=current_branch,           # git branch --show-current
    mode="interactive",              # or "factory" / "review" / "companion"
    honesty_mode=mode,               # full | lite | off — surfaced in start ceremony
)
# Persist session_id in conversation state — needed by Step 5 cost footer + Step N close
```

**3c — surface in start banner (T9).** The operator must know which gates
will fire before any work begins:

```text
📍 Branch: {branch}
   Model:  {model} on {machine}
   Honesty stack: {mode.upper()}{cli_override and "  (--honesty override)" or ""}
   To override: re-run with --honesty full|lite|off
```

### Step 4 — identify first unblocked epic
### Step 5 — render output
1. Pre-narrative banners (per `_shared/lifecycle_blocks.md` canonical order — including stale handoff and cognitive load; `time_of_week_gate` skipped — close-only).
2. NARRATIVE (full).
3. AGENT SUGGESTIONS (LIGHT) — preflight from `preflight_lessons(milestone_id)`.
4. Footers: velocity emoji, decision provenance, stakeholders.
5. Cost footer.

Persist: `write_lifecycle_output(issue_id="{id}", level="milestone", skill_point="start",...)`.

---

## `/milestone status {id}`

### Step 0 — load shared template
### Step 1 — gather context (in parallel)
- Linear: all child epics + statuses
- Helpers: full suite + `project_milestone_cost(id, budget)` for the milestone-only footer
- For each open epic: roll up its current lifecycle_output to the milestone summary

### Step 2 — render all four blocks (full)
1. Pre-narrative banners.
2. NARRATIVE — emphasize the milestone's GRAND SCHEME line.
3. HONEST ASSESSMENT — milestone-level optimism reflects pipeline drag, not just on-track epic count.
4. OPERATOR ACTIONS.
5. AGENT SUGGESTIONS (full) — cross-team signal weighted higher at milestone scope.
6. Footers (all): velocity emoji, spec coverage delta (aggregated across child epics), downstream unblocks, decisions, reviewer track record, cost-to-value, **milestone cost projection** (this is the milestone-only signal), MTTR estimate, rollback freshness, calibration accuracy, Sentry, Slack, stakeholders, linked ideas, competitor gap.
7. Cost footer.

### Step 3 — subagent dispatch (deep panel)

### Step 4 — persist
`write_lifecycle_output(issue_id="{id}", level="milestone", skill_point="status",...)`

---

## `/milestone close {id}`

🧭 Emit breadcrumb at every numbered step.

### Step 0 — idempotency check — HARD GATE

Search for prior `## ✅ Milestone Closed — {id}` receipt comment on the master tracker:

```text
list_comments({master_tracker_id}, limit: 50)
```

Regex `^## ✅ Milestone Closed — {id}\b`. If found:

```text
AskUserQuestion:
  question: "Milestone {id} was closed at {prior.closed_at} by slot-{prior.slot}.
             Re-run /milestone close?"
  options:
    - "No — print prior receipt and exit (Recommended)"
    - "Amend — add supplementary receipt"
    - "Yes — full ceremony again"
```

Default to "No." Re-running a clean milestone close is rarely intentional.

### Step 0b — comprehensive loose-ends sweep — gate on HIGH

Dispatch the sweep helper (per `_shared/agent-dispatch.md`):

🤖 Dispatching loose-ends sweep → {id} comprehensive scan (~2min expected)

```bash
python3 {scripts_dir}/infra/milestone_sweep.py {id}
```

The sweep scans (see `{scripts_dir}/infra/milestone_sweep.py` for the source of truth on
what's actually implemented vs. TODO):

1. **Unresolved questions across milestone-issue comments** — regex first-pass
   (`?`, "decision needed", "let me know", "should we", "@" + `?`). All hits are
   surfaced as **LOW** by default. Production-tier LLM triage to promote real
   blockers to MEDIUM/HIGH is a documented follow-on.
2. **Parking-lot reconciliation** — every "deferred" in WAH cross-referenced
   against backlog Linear issues. WAH-says-deferred-X-but-no-ticket → MEDIUM.
3. **Premature-Done detection** — Done tickets with `startedAt: null` (the
   premature-Done pattern). Per-ticket: **HIGH**.
4. **RED placeholder count** — milestone-scope acceptance tests still throwing
   `NotImplementedError`. Per-cluster: **MEDIUM**.
5. **Decision rot** — decision-store entries (storage `list_decisions`) from milestone contradicting each
   other. *TODO — not yet implemented; sweep emits placeholder hint.*
6. **Ceremony:pending labels older than 2h**.
   *TODO — not yet implemented; sweep emits placeholder hint.*

Print the report:

```text
LOOSE ENDS REPORT — {id}
HIGH (blocks close):
  - {item}...
MEDIUM (warns, doesn't block):
  - {item}...
LOW (FYI):
  - {item}...
```

If any HIGH-severity items: BLOCK with `AskUserQuestion` — "Waive this HIGH finding? (yes — provide Operator reason / no — abort close)". Each waived finding calls `record_decision(title, reason, type: "milestone_waiver", ref_id: "{id}")`.

### Step 0c — register slot + mark active in factory-state (T6)

```bash
python3 {scripts_dir}/infra/factory_state.py register
python3 {scripts_dir}/infra/factory_state.py active "/milestone close" "{id}" "1/7"
```

### Step 1 — verify all epics Done (except CLEANUP)

**VERIFY-HUMAN enforcement (APP006A+):** The VERIFY-HUMAN epic (if present) MUST be Done before
milestone close proceeds. This epic contains the Operator walkthrough results from `/verify human`.
If VERIFY-HUMAN is not Done:
```
HARD BLOCK — VERIFY-HUMAN epic {ID} is not Done.
Operator walkthrough must complete before milestone close.
Run: /verify human --continue {ID}
```

### Step 1a — /verify completion check **[factory]**

Ask the storage backend for the latest `/verify` run for this milestone (supabase backend reads
`qa.test_runs`; returns null under `storage_backend: none` → emit the WARNING below and continue):

```
get_latest_test_run({milestone_id}, modes: ["full", "mechanical"])
```

If no `/verify` run found for this milestone:
```
WARNING — no /verify run found for {milestone_id}.
Run: /verify full --milestone {milestone_id}
```

If the most recent run has P0 issues > 0:
```
HARD BLOCK — last /verify run has {n} P0 issues.
Fix them before closing. Epic: {ID}
```

### Step 2 — run final audit checks (reality / spec compliance / doc sync / compliance)
### Step 3 — create CLEANUP epic for deferred items (not optional)
### Step 4 — record the milestone outcome

`record_outcome("milestone", {id}, { goal, epics_done, deferred,... })` (supabase backend →
`qa.milestone_outcomes`; no-op under `storage_backend: none`).
### Step 4a (NEW) — git cleanup
After the milestone-level branch (if any) is merged, run the same fishy-check + safe-delete + prune pattern as `/epic close` Step 4e.2. Scope: only the milestone-coordination branch (NOT child epic branches — those were cleaned at their own close).

### Step 5 — render lifecycle narrative blocks (NEW)
Render full blocks per shared template:
1. Pre-narrative banners + `time_of_week_gate` (soft warning on Fri-evening / weekend close).
2. NARRATIVE — emphasize WHAT IT UNLOCKS.
3. HONEST ASSESSMENT — name every scope cut, every descoped epic, every deferred item.
4. OPERATOR ACTIONS — WHAT I'D DO NOW points to the next milestone.
5. AGENT SUGGESTIONS (full).
6. Footers including **surprises pattern detection** (`detect_close_patterns(id)`) — if a pattern fires, surface the auto-draft prompt.
7. Cost footer.

Persist: `write_lifecycle_output(issue_id="{id}", level="milestone", skill_point="close",...)`.

After persist: extract a one-line lesson and call `write_lifecycle_lesson(...)`.

### Step 5a — Honesty-stack gates — HARD GATE

Before stamping the milestone Done, two pre-flip gates must pass. If
either fails, **STOP** — do not mark Done. Fix the underlying problem
and re-render Step 5 + re-run these gates.

**T3 — audit-doubt validation:** the rendered HONEST ASSESSMENT
must end with a `## What I might be wrong about` block containing ≥2
distinct doubts.

```python
from scripts.factory.lifecycle_helpers import (
    current_honesty_mode,
    run_audit_doubt_check,
    should_run_hook,
)

# Mode gate: the wired hook only fires when the active
# honesty mode includes ``audit-doubt-check`` (i.e. ``full``). Under
# ``lite`` and ``off`` the gate skips silently — treat skip as PASS so the
# milestone close isn't blocked on a hook the operator opted out of.
#
# Scope to THIS close-ceremony's session row — the bare ``current_honesty_mode()``
# lookup with no session_id picks the most-recently-started in-flight row,
# which under concurrent operators could be SOMEONE ELSE'S session. Pass
# ``current_session_id`` (the row id /milestone start inserted) explicitly
# so the gate uses this ceremony's mode. Fall back to ``"lite"`` if the row
# was written without a mode column.
active_mode = current_honesty_mode(session_id=current_session_id) or "lite"
if should_run_hook("audit-doubt-check", mode=active_mode):
    ok, msg = run_audit_doubt_check(rendered_close_output)
    if not ok:
        raise SystemExit(f"audit-doubt-check BLOCKED: {msg}")
```

Milestone-close doubts should reference specific load-bearing claims
across the WHOLE milestone — not generic warnings. Example: "{ID}'s
acceptance test passed under sample N=20 but production traffic is N=500;
the threshold may not hold at scale."

**T4 — verifier-isolation-check:** confirms the Step 2 audit
agents ({agents.completion_audit} + {agents.spec_audit} + reviewer) ran on a different machine/model than
the implementer who closed the load-bearing epics. Pull impl session
from session-log rows (storage `log_session` records) for the milestone's epics; pull
verifier session from this `/milestone close` invocation.

```python
from scripts.factory.lifecycle_helpers import (
    current_honesty_mode,
    run_verifier_isolation_check,
    should_run_hook,
)

# Mode gate: verifier-isolation is a heavy check that only
# fires under ``full``. Under ``lite`` and ``off`` the loop short-circuits.
#
# Scope to THIS close-ceremony's session row to avoid cross-session mode
# leakage under concurrent operators (see the audit-doubt-check block above
# for the full rationale).
active_mode = current_honesty_mode(session_id=current_session_id) or "lite"
if should_run_hook("verifier-isolation-check", mode=active_mode):
    # For each closed epic in this milestone:
    for epic_session in load_bearing_epic_sessions:
        ok, msg = run_verifier_isolation_check(
            impl_machine=epic_session["actual_machine"],
            impl_model=epic_session["actual_model"],
            verifier_machine=current_close_session["actual_machine"],
            verifier_model=current_close_session["actual_model"],
        )
        if not ok:
            raise SystemExit(
                f"verifier-isolation BLOCKED for {epic_session['issue_id']}: {msg}"
            )
```

If a `cross_model_harden_waiver` decision row exists for this milestone
(see `/epic close` Step 0b), the same-model case is allowed — but the
waiver MUST be cited in the milestone-outcome row.

### Step 5b — E10 milestone-close gates — HARD GATE

E10 added three more gates that fire at milestone close. Each is
mode-aware — `lite` / `off` modes skip the heavyweight checks cleanly.

```python
import json
import subprocess
from scripts.factory.lifecycle_helpers import should_run_hook

active_mode = current_honesty_mode(session_id=current_session_id) or "lite"

# 1. Tripwire suite: always-on invariants must be green.
#    Tripwires bypass the mode gate — foundational invariants don't get
#    skipped in `lite` (they DO get skipped in `off`).
if active_mode != "off":
    proc = subprocess.run(
        ["pytest", "tests/tripwires/", "-v", "--tb=short"],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        # A milestone may NOT close with two or more active rows in
        # tests/tripwires/ALLOWLIST.md. If only one allowlist row is
        # in flight, add a one-line entry there linking to the Linear
        # issue that will fix it, with `expires` ≤ 7 days out.
        raise SystemExit(f"tripwire FAIL: {proc.stdout[-2000:]}")

# 2. Blast-radius aggregate: every child epic's
#    blast-radius must PASS before the milestone closes.
if should_run_hook("blast-radius", mode=active_mode):
    failed = []
    for epic in milestone_child_epics:
        proc = subprocess.run(
            ["python3", "-m", "scripts.audit.blast_radius_check",
             "--epic", epic],
            capture_output=True, text=True,
        )
        verdict = json.loads(proc.stdout or "{}").get("status", "INCONCLUSIVE")
        if verdict != "PASS":
            failed.append(f"{epic}: {verdict}")
    if failed:
        raise SystemExit("blast-radius aggregate FAIL:\n" + "\n".join(failed))

# 3. Rollback-drill freshness: load-bearing milestones
#    must have a passing drill in the last 30 days. `priority:p0` label
#    OR id prefix DAT/MLX/FCT (excluding doc-only) → load-bearing.
if should_run_hook("rollback-drill-freshness", mode=active_mode):
    proc = subprocess.run(
        ["python3", "-m", "scripts.audit.rollback_drills_audit",
         "--milestone", milestone_id],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        # STALE → run {scripts_dir}/rollback/drill.sh {milestone_id} first.
        # NEVER_PASSED → create rollback/{milestone_id}.sh from the
        # template, then drill.
        raise SystemExit(f"rollback-drill freshness FAIL: {proc.stdout}")
```

### Step 6 — mark Done + post "What Actually Happened"

The WAH comment header must be exactly `## ✅ Milestone Closed — {id}` so the Step 0 idempotency check on subsequent invocations can find it.

### Step 6a — mark idle in factory-state (T6)

```bash
python3 {scripts_dir}/infra/factory_state.py idle "{id}"
```

### Step 7 — handoff + unmissable receipt block

Emit the standardized receipt block per `_shared/receipt-block.md`:

```text
═══════════════════════════════════════════════════════════
✅  MILESTONE {id} CLOSED  (<milestone goal>)
    SLOT:     {slot}
    REPO:     {repo}
    TIME:     {ISO ts}
    MODEL:    {model}

    RECEIPTS:
      • Linear comment id={canonical receipt id}
      • milestone outcome recorded via storage `record_outcome` (row id={row_id})
      • Master tracker {tracker_id} updated
      • Sweep report: <N HIGH waived, M MEDIUM, K LOW>

    📍 WHAT'S NEXT
    /milestone start {next_milestone_id}
═══════════════════════════════════════════════════════════
```

Then terminal effects (bell + title + macOS notification) per the receipt-block template.

>>> START A NEW SESSION for the next milestone. <<<

---

## Key rules

- Every milestone ends in a CLEANUP epic. Never skip.
- The four-block render lands AFTER all auditing — the assessment must reflect reality.
- Calibration row writes happen regardless of whether the model thinks the milestone passed.

## Judgment weave (see /judgment)

- **Start:** every milestone plan needs `GATE:` lines with numeric abort conditions — author missing ones with **`/gate`**.
- **Close:** run **`/refute`** on the completion claim before marking Done.
