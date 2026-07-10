---
name: dossier
origin: authored
public: true
description: Frontier dossier session — run a repo's deepest available review with the strongest available model and bank ALL of it in one committed, append-only file. Spec-truth pass, graded deep review, executable fix rulings, a FULL build-to-spec plan, product/feature/tech ideation with gap analysis, and a premortem. Use when frontier-model time is scarce and its judgment must survive as a permanent artifact; rerun periodically and diff against the last section.
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, Workflow
argument-hint: "[scope hint: 'whole repo' | 'api + schema' | 'delta since last dossier'] | index"
---

# /dossier — Bank the Frontier Session

Deep review + spec truth + full forward plan + ideation, all exiting into ONE
committed file. The premise: strong-model access is intermittent; the artifact
is permanent. Run N+1 always starts by diffing against run N — the compounding
is the point.

Mode: adversarial, evidence-only, confidence tags [HIGH]/[MED]/[LOW] on every
judgment. **Prime directive: nothing exists only as prose or only in chat.**
Every finding exits as a spec patch, an executable fix instruction, a
mechanical gate (test/CI/hook), or a logged accepted risk with a named human.

## The file

`docs/FRONTIER_DOSSIER.md` — create `docs/` if absent; if the repo forbids new
docs, append a "Frontier Dossier" section to the closest existing audit doc and
say so. **Append-only across runs:** each session adds a dated section, never
rewrites prior ones. Commit it. If a prior section exists, Phase 0 includes
diffing current reality against its grades and plans — grade movement IS the
report.

If `/judgment /refute /drift /gate /door /premortem /sweep /verdict` exist as
skills, use them; otherwise use the inline grammar below — same procedure.

## Verdict grammar (exactly these words, nothing softer)

- Claims: `CONFIRMED` (refutation attempted, failed — evidence pasted) |
  `REFUTED` (broken — how) | `UNVERIFIED` (couldn't test — never rounds up)
- Drift: `MATCH` | `DRIFT` (quote spec line + code file:line, name the liar) |
  `UNVERIFIABLE` (spec too vague — that's a spec defect)
- Doors: `two-way` (pick fast, one-line why) | `one-way` (lock-in, who pays,
  escape-hatch cost, can the door shrink, kill-gate)
- Gates: `GATE: metric | threshold | measured-how+when | on-fail action`
- Severity: Critical (wrong results / data loss / security) | High | Medium | Low

## Phase 0 — Orient (30 min, read-only)

Read: README, CLAUDE.md/AGENTS.md, docs//specs/ tree, last ~50 commits, open
issues/TODOs, and the prior dossier section if one exists. Write the section
header: what this repo claims to be, what state it appears in, the 3 questions
this session must answer, and the scope boundary (what's explicitly OUT).

## Phase 1 — Truth pass (spec vs reality)

Every testable spec/README/doc claim verified against code and — where
runnable — live behavior. Drift table: claim | verdict | evidence | liar
(stale spec / wrong code / ambiguous) | fix.

**No specs? REVERSE the pass:** extract the de-facto spec FROM the code — the
invariants, contracts, and grains it actually enforces — write it into the
dossier as "Spec as-built", and flag every internal inconsistency. This
as-built spec becomes the baseline Phase 4 plans against.

End with the honesty number: N claims, M drifted, and a plain sentence on
whether the docs can be trusted as a foundation.

## Phase 2 — Deep review sweep (scale to repo size)

Small repo: one pass yourself. Larger: fan out blind parallel auditors
(`/sweep` if present), one per dimension, then adversarially verify their
Critical/High findings YOURSELF — reproduce or kill; only CONFIRMED findings
may say "broken". Dimensions (prune to what exists): correctness ·
security/authz (every trust boundary) · data model/schema (grain,
constraints-enforced-vs-hoped, one-way-door blast radius) · performance at 10×
current scale · test reality (do the tests test anything) · architecture
placement (logic at the wrong layer; duplicated owners of one fact) · honesty
(claimed-done vs actually-works).

Dossier gets: graded scorecard (1–5 per dimension, evidence per grade),
systemic findings first (3 findings sharing a root cause = 1 finding at the
right layer), and the mandatory **"safe to build on"** list — what's NOT broken.

## Phase 3 — Rulings & fix instructions

Each Critical/High: a ruling a weaker model or tired human can execute WITHOUT
judgment calls — exact files, exact order, the test that proves it, and a
`GATE:` line so regressions self-detect. Each open design question: a `DOOR:`
analysis + recommendation with confidence tag. Genuine 50/50s go in a **"Needs
owner decision"** list with your provisional answer — never silently pick.

## Phase 4 — Full build-to-spec plan (ALL of it, not a sample)

The complete gap between spec (written or as-built from Phase 1) and reality,
enumerated as a sequenced backlog — every unbuilt/partial spec item, not a
top-N. For each item: what exists now · what the spec requires · concrete build
steps · acceptance evidence (command/demo that proves it) · effort class
(S/M/L) · dependencies. Sequence foundation-before-leaves and mark the critical
path. Where the full list is genuinely huge, tier it (now / next / later) —
but the LIST itself is exhaustive; only the sequencing is prioritized.

Alongside it, the **tech plan**: infrastructure and architecture evolution the
spec work implies — migrations, refactors at the right `/altitude`, scale
prep, tooling/CI gaps — each with its own steps + acceptance evidence, and
one-way doors flagged with `DOOR:` blocks.

## Phase 5 — Ideation: product ideas, feature ideas, gap analysis

The forward-looking half — clearly labeled IDEAS, not commitments:

- **Gap analysis:** score the product against best-in-class in its domain and
  against what its own users plausibly expect. Every gap: evidence, severity,
  and whether closing it is spec work (→ Phase 4) or new scope (→ below).
- **Feature ideas:** each in a fixed format — Problem · Who feels it · Sketch
  (3–6 build steps) · Effort (S/M/L) · Door-risk (any one-way doors it opens) ·
  Kill-gate (what measured signal would prove it wasn't worth it).
- **Product ideas:** adjacent products, spin-offs, integrations, monetization
  angles this codebase makes cheap. Same format, plus "what this repo already
  has that makes it unfair".
- **Tech opportunities:** leverage nobody asked for but the review surfaced —
  extractable libraries, automation of manual steps, data now cheap to collect.

Rank the whole phase by value-per-effort; name the single best idea and why.
Use `/think` moves (invert, base-rate, second-order) rather than free
association — base-rate every "this will be huge" claim.

## Phase 6 — Premortem the plan

Past tense, as fact: "it's 3 months later and this plan failed because…" —
5+ concrete causes across data / integration / human / scale / assumption.
Top risks get redesigned into the Phase 4 sequence, gated, or accepted in
writing. The plan section is not final until the premortem has marked it.

## Phase 7 — Close honestly

Dossier ends with: what this session did NOT get to (adjacent-but-unchased
list, each with a provisional answer + confidence tag — cheap and valuable,
never skip) · every UNVERIFIED item restated · one-paragraph overall grade.
Every section closes with ONE machine-readable line (this is what `index`
mode parses — format is exact):

```
DOSSIER: <YYYY-MM-DD> | grade: <letter or n/a> | top: <one-line systemic finding>
```

Commit the dossier. If a task tracker exists, file Critical/High fixes as
tickets pointing at their dossier sections; if `/verdict` exists, log the
session line (grade, top systemic finding, date).

## `/dossier index` — portfolio view

One-glance health across every repo that has a dossier:

1. Find dossiers: read `~/.claude/dossier-repos.txt` if it exists (one repo
   path per line — the fast path; append every repo on its first run).
   Otherwise scan the user's code roots 2 levels deep for
   `docs/FRONTIER_DOSSIER.md` (use `git -C <dir> ls-files` era tools, never a
   raw deep find) and offer to write the list file from what's found.
2. From each dossier, take the LAST `DOSSIER:` line (latest section).
3. Render: repo | latest grade | date | age | top finding — sorted oldest-run
   first, and flag anything past the cadence window (below) as OVERDUE.
4. No editing, no judging in index mode — it's a read-only HUD.

## Cadence — the frontier judgment lifecycle

Three rhythms, together complete; resist adding more until `/calibrate` data
proves something is missing:

| Ritual | Cadence | Purpose |
|---|---|---|
| `/dossier` | per repo, quarterly OR at each major milestone | re-grade, re-plan, diff vs last section |
| `/calibrate` | monthly | score how confidence tags and estimates aged; corrections land as mechanisms |
| `/escalate burn` | whenever strong-model time is available | batch-adjudicate the queued judgment-dense questions |

`index` mode enforces the first row: >100 days since a repo's last `DOSSIER:`
line = OVERDUE in the table.

## Session gates (self-enforced, verdicts declared at close)

```
GATE: mechanism-ratio | findings without an exit artifact = 0 | count at close | on-fail: convert or log accepted-risk before ending
GATE: plan-completeness | spec items missing from Phase 4 = 0 | diff spec inventory vs plan | on-fail: finish the enumeration
GATE: evidence | "broken"/"works" without pasted proof = 0 | self-scan dossier | on-fail: demote to UNVERIFIED
GATE: effort | > 2× a half-day per phase | honest checkpoint | on-fail: ship partial, list remainder in Phase 7
GATE: scope | no schema/prod writes; code fixes only if trivial+tested, else instructions | on-fail: STOP
```

## Honesty rules

Failed/ugly findings reported as plainly as wins. "No effect", "can't tell
yet", and "this doc is a lie" are valid, valuable sentences. If the repo is in
better shape than expected, say so — a dossier that only lists problems can't
be used to decide what to build on. Ideas are tagged as ideas; a dossier that
launders wishes into plans poisons the next session's trust in it.

## Composes with

- `/sweep` (Phase 2 engine) · `/drift` (Phase 1) · `/refute` (verification
  everywhere) · `/gate` `/door` (rulings + plan) · `/premortem` (Phase 6) ·
  `/think` (Phase 5 rigor) · `/verdict` (session ledger line) · `/escalate`
  (50/50s when an owner isn't present) · `/precedent` (check prior rulings
  before re-deciding).

## Standalone essentials

This skill is executable from this file alone — no other file is required
reading. The operative shared rules, inlined:

- **Ruling grammar** — every claim examined gets exactly one ruling:
  `CONFIRMED` (a refutation was attempted and failed; evidence attached),
  `REFUTED` (the claim is false; the break is shown), or `UNVERIFIED`
  (no real test could be run; reported as such, never silently upgraded).
- **Evidence is mandatory and typed** — `command` (the exact command run plus
  its pasted output) or `citation` (`path/to/file:line`). Impressionistic
  language ("looks good", "should work") is not a ruling.
- **Severity tiers** — S0 critical / S1 major are blocking; S2 minor / S3 note
  are advisory.
- **Verdict line** — end with ONE grep-able line in this skill's own grammar
  (shown in its output format above), loggable via `/verdict` into the
  project's append-only, committed `.claude/verdicts.log`.

Deep reference (optional, canonical): `skills/_shared/audit-report-contract.md`
and the root `MANUAL.md` Part 2.
