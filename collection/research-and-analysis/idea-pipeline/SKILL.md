---
name: idea-pipeline
origin: authored
public: true
description: Run product ideas through a full funnel — capture/generate → grill → market research → evaluate → rank → graduate the winner (name it, pick a stack, eject + project-init). Pairs with the `ideate` workspace (00-inbox → 01-ideas → 02-products → 03-projects) but works standalone too. Use to develop, pressure-test, compare, or pick between product/app/project ideas.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, WebSearch, WebFetch
argument-hint: ["idea or theme" | --batch | --stage <inbox|idea|product> | --rank]
---

# Idea Pipeline

A repeatable funnel so ideas don't die in a notes file and winners don't stall before
they're built. Each stage adds rigor; weak ideas get cut, strong ones get sharper, and
stack/naming decisions deepen as an idea moves down-pipe.

```
capture/generate → grill → market research → evaluate → rank → graduate
   00-inbox            01-ideas (exploring)        02-products       03-projects
```

## How it pairs with the `ideate` workspace

If run inside an `ideate` repo (has `00-inbox/`, `scripts/new.sh`, `scripts/promote.sh`):
- Create items with `scripts/new.sh "Name"`; advance them with `scripts/promote.sh <slug> <stage>`.
- Read/write each idea's `README.md` (problem, research, eval live there) and append the Status log.
- Regenerate `scripts/board.sh` after changes.

If run anywhere else: keep the same artifacts as plain markdown in the current dir.

Don't force the whole funnel in one sitting — you can run a single stage (`--stage`),
score what exists (`--rank`), or take one idea all the way through.

---

## Stage 1 — Capture / Generate

- **Have ideas already?** Capture each as an item (`scripts/new.sh "…"` → `00-inbox/`),
  one folder per idea, problem + one-liner in the README.
- **Want ideas?** Generate against a theme: ask for the domain, the user's unfair
  advantages/interests, and constraints, then brainstorm 10–20 framed as
  "for {who}, who struggle with {pain}, a {what} that {benefit}." Land them in inbox.

Triage: which are worth grilling? Promote those to `01-ideas` (status `exploring`).

---

## Stage 2 — Grill (pressure-test each idea)

Interrogate like a skeptical investor. Per idea (reference its README; fill gaps via
`AskUserQuestion`). This is the `/mvp` discovery spirit applied per-idea:

- **Problem** — whose pain, how acute (vitamin vs painkiller), how often, what they do today.
- **Customer** — narrowest viable user. Reachable how?
- **Why now / why you** — timing shift + unfair advantage.
- **Riskiest assumption** — the one belief that, if false, kills it. How to test it cheaply.
- **Wedge & moat** — the first sharp use case; why it compounds.
- **Out of scope** — what you're deliberately NOT doing.

Write findings into the README. If an idea collapses under grilling, promote it to
`99-archive` (status `killed`) with a one-line post-mortem — never silently delete.

---

## Stage 3 — Market research (use the specialist skills)

For surviving ideas, gather evidence — delegate to existing skills where they fit:

- **Competitors / closest alternative** — `/competitive-scan` per serious incumbent, or
  `WebSearch`. Capture who exists, pricing, positioning, and the gap.
- **Market size & demand** — `/market-scout` (TAM, pricing signals, ICP) or `WebSearch`.
- **Deeper unknowns** — `/deep-research` for a cited report on a pivotal question.

Summarize each into the README under `## Market`. Flag fatal collisions (a dominant
incumbent doing exactly this) — those drop the eval score hard.

---

## Stage 4 — Evaluate (score against a rubric)

Score each idea 1–5 on each dimension; note the rationale (don't just emit numbers):

| Dimension | 1 ………………… 5 |
|-----------|----------------|
| Problem severity | nice-to-have → hair-on-fire |
| Market size / pull | tiny/none → large & growing |
| Founder fit / advantage | none → strong unfair edge |
| Differentiation / moat | commodity → defensible |
| Feasibility (you, now) | needs a team/years → shippable solo soon |
| Time-to-signal | slow/expensive → cheap & fast to validate |
| Competition headroom | crowded/locked → open lane |

Weight to taste (default: severity ×2, advantage ×1.5, feasibility ×1.5, others ×1).
Record the scored table in each README (`## Eval`).

---

## Stage 5 — Rank

Produce a leaderboard across all live ideas: weighted score, the single biggest risk,
and the cheapest next test for each. Recommend: **pursue / park / kill** per idea.
Promote winners toward `02-products`; park the rest (status `parked`).

```
#  Idea                Score  Biggest risk            Next test
1  <name>              31/40  demand unproven         5 landing-page signups in a week
2  <name>              27/40  incumbent owns channel  10 cold DMs → 3 calls
```

---

## Stage 6 — Graduate the winner (deepen stack + naming)

For the top pick (now a `02-product`, heading to `03-project`):

1. **Name it** — run `/brand-name-research` (grills on vibe + constraints, then delivers
   only names that pass domain / App Store / trademark screening). Avoids the
   "love it → it's already an app" trap.
2. **Pick a stack** — now that scope is real, decide the stack. Match to the build:
   - B2C SaaS + auth → Next.js + Supabase
   - AI product → Next.js + Supabase + AI SDK (gateway models)
   - Public API → FastAPI + Postgres
   - Internal analytics → Next.js + DuckDB
   - CLI / single binary → Python (Typer) or Go
   Record the decision + rationale in the README (`## Stack`).
3. **Eject & scaffold** — if in an ideate workspace, `scripts/eject.sh <slug> ~/code
   --github <owner>/<repo> --private`, then run `/project-init` in the new repo to
   generate the full AI-ready scaffold. Promote the original to `03-projects` (or archive
   it as ejected).

> Stack discussion is intentionally **late**: don't argue Next-vs-FastAPI for an idea
> that won't survive grilling. Re-open the stack question whenever scope materially shifts.

---

## Output discipline

- Every stage writes back to the idea's README (or a markdown doc) — the funnel leaves a
  trail, so a parked idea can be resumed later without re-litigating.
- When comparing ideas, always show the rubric and the reasoning, not just a winner.
- Surface kills and parks honestly with one-line reasons; keep them in `99-archive`.

## Judgment weave (see /judgment)

- **Graduation is `/door` territory:** name and stack lock in — slow down before ejecting.
- **Before project-init:** run **`/premortem`** on the winning idea.
