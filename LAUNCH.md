# Launch assets (drafts — distribution itself is Operator-gated)

## Announcement post draft (~700 words)

**Title: Your AI's "done" is a claim, not a fact — so we made it prove it.**

Last month an agent session ended with `fix: calculator done, all tests pass`.
Zero tests had been run. Not lied exactly — the model *believed* it. That
commit message is the default failure mode of every coding agent and every
tired human: plausible-but-wrong, asserted with confidence.

Most fixes for this are prompts: "be careful", "double-check your work",
"think harder". They don't transfer. Swap the model, start a new session, and
the discipline evaporates, because it lived in phrasing.

Casper is built on a different thesis: **correction history is the asset,
not the model.** Capability transfers between models two ways only —

1. **Forced procedure**: numbered steps with mandatory outputs, where skipping
   a step is visible. A weaker model running a strong procedure beats a strong
   model running on vibes.
2. **Mechanical gates**: zero-LLM shell hooks that fire regardless of what any
   model believes. The model can be wrong; the regex doesn't care.

So Casper ships both. Thirteen skills — `/refute` (construct the input that
breaks the claim, then run it), `/door` (one-way vs two-way decisions),
`/gate` (no plan without a numeric abort condition), `/premortem`, `/drift`,
`/altitude`, `/calibrate`, and friends — plus seven hooks for Claude Code.
The flagship hook, `claim-evidence.sh`, blocks any `git commit` whose message
claims done/fixed/works but carries no evidence: no staged tests, no
`Evidence:` line. [demo gif here]

Unusually for this ecosystem, the hooks have their own regression tests: a
24-assertion matrix (block case AND pass case AND inert-without-config case)
that runs in CI. If you're going to trust a gate, the gate needs a track
record too.

The part that compounds is the **ledger**. Every skill ends with a one-line,
grep-able verdict appended to `.claude/verdicts.log` — committed, append-only,
union-merged. Six months later, "show me every gate we overrode and who signed
it" is a grep, not archaeology:

    grep 'GATE.*OVERRIDE' .claude/verdicts.log

And then `/calibrate` closes the loop: it samples your old tagged claims —
[HIGH]s, gate predictions, premortem risks, estimates — and scores them
against what actually happened. A [HIGH] that's right 60% of the time is a
[MED] wearing a costume. Corrections don't land as resolutions to do better;
they land as mechanisms — a new checklist line, a retuned threshold, a
demoted confidence tier. Gates that never fire get deleted. The toolkit
audits itself with its own tools.

What Casper is NOT: a methodology. It doesn't tell you how to plan, branch,
or structure work, and it pairs fine with whatever workflow (or workflow
framework) you already run. It's the enforcement-and-memory layer underneath:
claims need evidence, decisions need verdicts, verdicts need a ledger, and the
ledger needs to be scored.

Install is deliberately boring and non-invasive — it copies skills into your
project's `.claude/skills/`, writes a manifest, and uninstall reverts
byte-for-byte. Hooks are default-OFF until a project opts in.

    git clone https://github.com/ronniepinnell/casper && cd casper
    ./install.sh --only refute,gate,verdict

Your AI said done. Make it prove it.

## HN title options

1. Show HN: CI-tested hooks that block your AI's unproven "done" commits
2. Show HN: Casper – your AI said "done", this blocks the commit until it proves it
3. Your AI's "done" is a claim, not a fact – so we made it prove it
4. Show HN: An append-only judgment ledger for AI coding sessions
5. A lie detector for "all tests pass" commits (13 skills + 7 tested hooks for Claude Code)

Recommended: #1 (leads with the tested-hooks novelty — the verifiable claim
nobody else in the ecosystem can make).

## r/ClaudeAI angle

Lead with the demo gif of the blocked commit; first comment carries the
install one-liner and the ledger grep. Title: "I made Claude prove its 'done'
claims — a hook that blocks commits with no test evidence (open source)".

## awesome-claude-code PR text

Follows the repo's CSV pipeline + per-entry rationale convention:

> **Casper** — Judgment toolkit: 13 skills + 7 zero-LLM hooks that block
> unproven "done" claims, keep an append-only verdict ledger
> (`.claude/verdicts.log`), and score past confidence via `/calibrate`.
> Rationale: the only hook suite in the ecosystem with its own CI-run
> regression matrix (block + pass case per gate); adds a category the list
> lacks — enforcement and organizational memory rather than workflow or
> personas. MIT, non-invasive installer with manifest-driven uninstall.

Also prepare (v0.2, after plugin packaging verifies): VoltAgent/awesome-agent-skills,
awesome-claude-code-subagents.


## Positioning note (internal)

Casper is the top of the the factory funnel. Rules: the free repo must earn trust
standalone — light attribution only ("built by the team behind the factory"), never
hard-sell. Product-tier ideas (hosted ledger, calibration dashboards,
enforcement-as-a-service / GitHub App at org scale) route to the factory's roadmap,
NOT the public ROADMAP.md. The /refute GitHub Action stays free — it is the
demo and the wedge; the paid line starts at multi-repo/team aggregation.
