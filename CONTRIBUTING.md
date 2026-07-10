# Contributing to Casper

Thanks for helping bank judgment. Two rules matter above all others.

## The JUDGMENT-OVERRIDE rule

Any change that contradicts a logged verdict, a shipped gate default, or a
prior ruling in this repo must say so explicitly in the PR body:
`JUDGMENT-OVERRIDE: <what ruling is being overridden> — <why>`. Silent
departures from precedent are rejected regardless of merit.

## Authoring rules (all contributions)

From MANUAL.md §5 — every new artifact must:

1. Name the **failure class** it catches, not an incident.
2. Land at the right layer: hook (mechanically checkable) → skill (repeatable
   judgment shape) → domain checklist line (field knowledge). See the
   decision tree in MANUAL.md §6.
3. Emit a one-line, grep-able **verdict** (`GATE: …`, `DOOR: …`).
4. **Hooks ship default-OFF** (config-gated via `.claude/judgment.json`) and
   must fail loud once, not nag.
5. **Hooks require tests**: a block case AND a pass case added to
   `hooks/judgment/test.sh`. No test, no merge.
6. Skills must be **self-contained**: reference only skills in this repo,
   core Claude Code tools, or external skills behind an explicit "if your
   workflow has one" guard. No absolute paths, no personal or project names.
7. Frontmatter must carry `name:` (matching the directory), `description:`,
   and `origin:` (`authored`, or `imported` + `source:` with attribution).

## Contributing to the collection

The 13 judgment skills live at `skills/` (the product). Everything else — the
planning, verification, docs, research, tooling, and communication units — lives
under `collection/<category>/`. To add a unit:

1. **Write it** as a skill (`collection/<category>/<name>/SKILL.md`) or an agent
   (`collection/<category>/<name>.md`). Frontmatter must carry `origin: authored`
   and `public: true`.
2. **Pick one category** — `planning-and-lifecycle`, `verification-and-audit`,
   `docs-and-context`, `research-and-analysis`, `meta-and-tooling`, or
   `communication`. A unit belongs to exactly one.
3. **Add a table row** to that category's `README.md`:
   `| \`name\` | what it does | when to call | \`./install.sh --only name\` |`.
   The lint requires the table to match the units present, exactly once each.
4. **Scrub** anything project-specific: no private repo names, absolute user
   paths, internal ticket IDs, or company-internal identifiers.
5. **Lint** (`python3 scripts/lint.py`) — it checks `public: true` +
   `origin: authored`, one-and-only-one category listing, and banned tokens.

### Upstream is elsewhere; sync is one-way

This repo is the **public downstream**. The canonical source of these units is a
private config repo; changes flow **one way, private → public**. That means:

- **PRs land here.** Open your PR against this repo — it's where contributions
  are reviewed and merged.
- **Merged changes are imported upstream** into the private source by the
  maintainers, so the two stay reconciled. Don't expect to edit the upstream;
  you can't see it. Everything you need to contribute is in this repo.

## Before opening a PR

```bash
python3 scripts/lint.py          # skill + collection lint — must print 0 problems
bash hooks/judgment/test.sh      # hook matrix — must be all green
```

Domain checklist contributions (`skills/judgment/domains/`) are the easiest
entry point: one line = a check + the refutation that tests it.

## Worked examples policy

Procedure skills carry exactly one **real** worked example each, reproduced as
a static transcript. Synthetic examples are placeholders only and are replaced
as real rulings accumulate.
