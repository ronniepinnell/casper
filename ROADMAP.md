# Roadmap

## v0.1 — Extraction (this release)
- 13 self-contained skills, 7 tested hooks, one MANUAL, non-invasive
  install/uninstall with manifest, CI (hook matrix + skill lint).

## v0.2 — Distribution surfaces
- **Suggested fixes, casper-flavored (PR comments).** CodeRabbit suggests code
  changes; casper suggests the two things a claims-reviewer can: (1) the
  EVIDENCE to produce — "this done-claim needs `pytest tests/x -k y` output
  pasted as an Evidence: line" — and (2) the PINNING TEST — /refute step 6's
  regression stub, filed as a ready-to-commit suggestion block. Delivery:
  refute-action already posts PR checks/comments on GitHub; the comment
  surface goes behind the review-bot adapter so GitLab/Gitea land later
  (agnostic core, forge-specific last mile). Casper never comments on style
  or structure — that lane is taken; claims and evidence are ours.
- **Liveness check (the layer rule, mechanized).** "Merged" is the code
  layer; "done" claims the user layer. A companion check for refute-action
  that, given a done-claim, verifies the claim's LAYER: commit is an ancestor
  of the release branch, contained in the deployed SHA (pluggable endpoint),
  and any migrations in the diff are applied (pluggable command). Each check
  reports a named diff or UNVERIFIED — never assumed live. Event-driven (runs
  when the claim is made, PR/release-time), not a cron: casper reviews claims
  like CodeRabbit reviews code — at the moment they're asserted. Origin:
  2026-07-15 operator finding — three deployment-lag gaps manufacturing
  false-dones that commit-level evidence structurally cannot catch.
- **`/refute` GitHub Action (flagship next).** Local hooks are bypassable —
  "I'll just commit from another terminal." The Action moves enforcement to
  the trust boundary: it reads a PR's done-claims, runs the stated evidence
  commands, and posts CONFIRMED / UNVERIFIED as a PR check, writing to the
  ledger. Kill-gate: <3 external repos adopt within 90 days of launch.
- Claude Code plugin/marketplace packaging verified end-to-end (`.claude-plugin/`).
- npx one-liner (`npx casper@latest install --only refute`).
- Tagged releases + CHANGELOG.

## v0.3 — Community & flywheel
- docs-sync CI gate: generated README/map tables regenerated from the tree;
  drift fails CI.
- Community domain manuals: `domains/frontend.md`, `domains/data-eng.md`
  (good first issues — one checklist line + its refutation).
- New hook: `todo-debt.sh` — blocks done-commits that ADD TODO/FIXME/HACK lines.
- `judgment doctor` — install/config diagnostic (the #1 support-load killer).
- `verdict-viewer` — ledger pretty-printer (`--stats`, `--export md`).
- `calibrate --report` — committable confidence-vs-outcome scorecard.
- Precedent packs: importable, sanitized ruling libraries (`format: 0, unstable`).
- Windows/PowerShell hook ports · i18n READMEs (zh/ja) · Discussions seeded
  (Show your ledger · Gate proposals · Domain manuals · Calibration results).

## v1.0 — Stability promise
- The verdict grammar is the API. v1.0 freezes the ledger line formats
  (`DOOR:`, `GATE:`, `REFUTE:`, `ESCALATE:`, `PRECEDENT:` …) so third-party
  tools can parse ledgers forever.
- Cross-tool shims: pure-git pre-commit variant of claim-evidence; notes for
  non-Claude agents.

House rule for every feature above: it ships with its own kill-gate, and
calibration data decides what gets deleted. Gates that never fire get removed.
