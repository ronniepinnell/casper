# Casper 👻

> **Your AI ghosted you with a "done." Casper caught it.**
>
> _The friendly ghost in your git — it keeps the receipts._

[![CI](https://img.shields.io/badge/CI-passing-brightgreen)](#) [![hook tests](https://img.shields.io/badge/hook_tests-24%2F24-brightgreen)](#) [![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE) [![judgment skills](https://img.shields.io/badge/judgment_skills-13-blueviolet)](#the-judgment-toolkit) [![collection](https://img.shields.io/badge/collection-51_units-9cf)](#the-full-collection) [![release](https://img.shields.io/badge/release-v0.1.0-lightgrey)](#)

<!-- DEMO GIF SLOT: record with demo/demo.tape, save the gif under demo/, embed it here -->
_A 20-second demo of a fake "done" commit getting blocked goes here._

A commit says `fix: done, all tests pass` — but zero tests ran. That's your AI
**ghosting** you: it claims it's finished and vanishes, leaving you the broken
code. Casper is the friendly ghost that catches it — when a "done" has no proof,
it blocks the commit and says:

```
👻 Boo — that ain't done yet.
   claim-evidence gate: this commit claims completion but has no evidence attached.
```

**Casper** is a curated set of Claude Code skills + agents built around one
thesis: **correction history is the asset, not the model.** Its headline act is the **judgment
toolkit** — 13 skills + 7 CI-tested, zero-LLM hooks that block unproven "done"
claims, keep an append-only verdict ledger, and score how your confidence aged.
Around it sits a browsable **collection** of the planning, verification, and
tooling skills we actually run in production.

## 30-second quickstart

```bash
git clone https://github.com/ronniepinnell/casper && cd casper

./install.sh --only refute              # one skill, into ./.claude/skills of this project
./install.sh                            # the whole judgment toolkit (13 skills)
./install.sh --all                      # toolkit + the entire collection (skills + agents)
```

Then, inside Claude Code: `/refute the login fix works`.

Non-invasive by design: `install.sh` copies only what you ask into
`.claude/` (`--global` for `~/.claude`), writes a manifest, and `./uninstall.sh`
reverts byte-for-byte exactly what was installed. `--dry-run` shows the plan
without touching anything. Hooks are separate and **default-OFF**
(`./install.sh --hooks`).

## The judgment toolkit

The flagship. 13 skills that turn "trust me, it's done" into a checkable record.

| Command | One-liner |
|---|---|
| `/refute` | Try to break the claim before believing it — CONFIRMED / REFUTED / UNVERIFIED |
| `/door` | Reversible? pick fast. Irreversible? enumerate the lock-in first |
| `/gate` | No plan without a numeric abort condition |
| `/drift` | Spec vs code-as-built — which one is lying? |
| `/altitude` | Fix at the cause's layer, not the symptom's |
| `/premortem` | It already failed — write the incident report first |
| `/think` | Forced thinking moves: invert, second-order, base-rate, analogy, flip, decompose |
| `/verdict` | Append-only judgment ledger — "every gate we overrode" is a grep |
| `/calibrate` | Score how your past confidence aged; corrections become mechanisms |
| `/escalate` | Queue the hard call, ship the rest; `burn` to batch-adjudicate |
| `/precedent` | Grep prior rulings: FOLLOW or explicitly DISTINGUISH |
| `/sweep` | Massive audit fan-out → adversarial verification → graded synthesis |
| `/judgment` | The map + router: given a situation, names the one tool that fits |

**Start here — 5 tools:** `/refute`, `/gate`, `/verdict`, `/door`, `/calibrate`.

Backed by 7 zero-LLM hooks (claim-evidence, spec-citation, scope-creep,
dangerous-git, and three telemetry/guard hooks), each with a block-case AND
pass-case regression test — 24 assertions, run in CI (`hooks/judgment/test.sh`).
Every skill appends a one-line, grep-able verdict to `.claude/verdicts.log`:

```bash
grep 'GATE.*OVERRIDE' .claude/verdicts.log   # every gate we overrode, with who signed it
```

Full deep-dive — thesis, operating loop, hook wiring, the ledger badge, weekly
digest — lives in **[MANUAL.md](MANUAL.md)**.

## The full collection

51 authored units (`origin: authored`, CI-checked provenance), organized into
six categories. Each category page has a table — unit, what it does, when to
call, and a one-line install. Install one skill, a whole category, or everything.

| Category | What's inside | Units |
|---|---|---|
| [Planning & Lifecycle](collection/planning-and-lifecycle/README.md) | Initiative → milestone → epic → task cadence + orchestration | 11 |
| [Verification & Audit](collection/verification-and-audit/README.md) | Completion reality-checks, spec/rules conformance, bug hunts, over-engineering review | 15 |
| [Docs & Context](collection/docs-and-context/README.md) | Keep docs, AI-context files, and project records in sync | 4 |
| [Research & Analysis](collection/research-and-analysis/README.md) | Generate and pressure-test ideas, names, designs, decisions | 6 |
| [Meta & Tooling](collection/meta-and-tooling/README.md) | Scaffolding, session control, import/sync, dev-tool integrations | 13 |
| [Communication](collection/communication/README.md) | Hand work off cleanly — to the next session or another agent | 2 |

```bash
./install.sh --category verification-and-audit   # a whole category
./install.sh --only spec-audit,find-bugs         # pick individual units by name
```

## Docs

- **[MANUAL.md](MANUAL.md)** — the one deep doc: thesis, operating loop,
  authoring guide, skill-vs-hook decision tree, troubleshooting.
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — how to add a unit; the collection flow.
- **[ROADMAP.md](ROADMAP.md)** · **[LAUNCH.md](LAUNCH.md)**

## License

MIT © 2026 Ronnie Pinnell. All skills and agents are original authored work
(`origin: authored` frontmatter, CI-checked provenance).

---

Built by the team behind the autonomous software factory where these
procedures run in production. Casper is and stays free; if you want the hosted
verdict ledger, team calibration dashboards, or CI enforcement at org scale,
that's where they live.

---

_Casper is the free, friendly ghost — it watches your commits while you're away._
_Its bigger sibling runs the whole factory while you're gone._ 👻
