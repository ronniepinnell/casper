# Changelog

All notable changes to Casper are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-07-10

Initial public release.

### Added

- **Judgment toolkit** — 13 skills (`/refute`, `/door`, `/gate`, `/drift`,
  `/altitude`, `/premortem`, `/think`, `/verdict`, `/calibrate`, `/escalate`,
  `/precedent`, `/sweep`, `/judgment`) that turn "trust me, it's done" into a
  checkable, grep-able record.
- **Zero-LLM hooks** — 7 CI-tested hooks (claim-evidence, spec-citation,
  scope-creep, dangerous-git, plus three telemetry/guard hooks) that block
  unproven "done" claims, with a 24-assertion block-case/pass-case regression
  matrix (`hooks/judgment/test.sh`).
- **The collection** — 51 authored units (41 skills + 10 agents,
  `origin: authored` with CI-checked provenance) across six categories:
  Planning & Lifecycle, Verification & Audit, Docs & Context,
  Research & Analysis, Meta & Tooling, and Communication.
- **Non-invasive installer** — `install.sh` copies only what you ask into
  `.claude/` (`--only`, `--category`, `--all`, `--global`, `--hooks`,
  `--dry-run`); `uninstall.sh` reverts byte-for-byte from a manifest.
- **Demo** — animated GIF showing Casper block an evidence-free commit, then
  accept it once proof is attached.
- **CI** — hook regression matrix, skills lint (self-containedness +
  frontmatter), install/uninstall round-trip, and a self-checking counts gate
  (`scripts/check-counts.py`) so no README number can drift from the tree.

[Unreleased]: https://github.com/ronniepinnell/casper/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/ronniepinnell/casper/releases/tag/v0.1.0
