---
name: idea-generator
origin: authored
public: true
description: Generate a large, structured batch of product/SaaS/app ideas on demand. Grills you briefly on domain, your unfair advantage, and constraints (or expands an existing theme/doc), then brainstorms 30–50 ideas using explicit ideation frameworks — each written in a consistent Problem / MVP / Missing / Pricing / Difficulty / Notes format and grouped by theme. Can drop them straight into the `ideate` inbox. Use when you want NEW ideas (not to evaluate existing ones — that's /idea-pipeline).
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, WebSearch, WebFetch
argument-hint: ["domain or seed" | --expand <theme-slug> | --count 50 | --to-inbox]
---

# Idea Generator

Produce a big, well-structured batch of ideas fast — in the same format as the existing
idea docs, so they slot right into the pipeline. This skill **diverges** (creates options);
`/idea-pipeline` **converges** (grills, researches, ranks). Generate here, then hand off.

## Phase 0 — Mode

- **Fresh batch**: a domain/seed was given (or ask for one).
- **`--expand <theme-slug>`**: read that theme's README in `00-inbox/…` (or any doc) and
  generate *more like these* / fill the gaps it doesn't cover. Read existing inbox themes
  first to **avoid duplicating** ideas already captured.
- **`--to-inbox`**: after generating, write the batch into the ideate workspace as a new
  theme folder (`scripts/new.sh` or direct), not just chat.

## Phase 1 — Seed me (short interview)

Use `AskUserQuestion`, one batch. Skip anything already given as args / inferable from a doc.

1. **Domain / market** — where to hunt (e.g. local SMB marketing, consumer mobile, dev
   tools, hockey, fintech). Broad is fine; the frameworks will fan out.
2. **Your angle** (multi-select) — what should bias generation: *unfair advantage /
   existing audience · skills you already have · a customer you can reach · a workflow you
   live daily · ride a trend (AI made X 10× cheaper) · pure market size*.
3. **Constraints** — solo vs team · **bootstrap cash-machine** vs **venture-scale** (or both)
   · build-time ceiling (weekend / weeks / months) · monetization (subscription / marketplace
   take-rate / usage / one-time) · hard avoids (no mobile, no ML, no cold sales, etc.).
4. **Count & spread** — how many (default **40**), and how many themes to bucket into (default 4–6).

Echo a 3-line generation brief; proceed (don't wait for a thumbs-up unless they want one).

## Phase 2 — Generate (use frameworks, don't freestyle)

Spread ideas across these lenses so the batch is *diverse*, not 40 variations of one:

- **Pain mining** — concrete recurring frustrations for the target user; what they do today.
- **Jobs-to-be-done** — the job they "hire" a product for; underserved steps.
- **"X for Y"** — proven product transplanted to a new audience/vertical (e.g. "Ahrefs for local").
- **Unbundle an incumbent** — take one feature a bloated/expensive tool does and do it 10× better/cheaper.
- **Re-bundle / aggregate** — combine fragmented point-tools into one sticky system.
- **Trend-ride** — capability that just got cheap (LLMs, cheap transcription, vision) → newly viable.
- **Manual → automatic** — a task people do by hand or hire out; automate it.
- **Expensive → affordable** — enterprise-only category, build the dead-simple $29/mo SMB tier.
- **Audience-first** — start from a reachable audience/advantage, work back to what to sell them.

For **each idea**, write this exact block (matches the existing idea docs):

```
### <Idea Name>
- **Problem:** who hurts + the specific recurring pain.
- **MVP:** the smallest thing that delivers the core value.
- **Missing features:** what nobody does well today (the wedge).
- **Subscription potential / model:** $X–$Y/mo, or take-rate, or usage.
- **Difficulty:** Easy / Medium / Hard (MVP vs full product if they differ).
- **Notes:** the one sharp insight, risk, or positioning angle.
```

Group ideas under `## Theme: <name>` headers. Tag each idea internally as
*bootstrap cash-machine* or *venture-scale* if the user asked for that split.

Aim for the requested count; if a lens runs dry, lean on another rather than padding clones.

## Phase 3 — Light pre-screen (NOT validation)

Before presenting, cheaply prune the obviously-dead so you don't raise false hope:

- **Dedup** against ideas already in the inbox (read existing theme READMEs) and within the batch.
- **Saturation flag** — if a category is obviously locked (a dominant incumbent does exactly
  this for this exact user), mark it `⚠ crowded` rather than dropping silently.
- Optional quick **name sanity**: if a working title is clearly a known app, note it
  (full naming is `/brand-name-research`'s job).

Do **not** do deep market research or scoring here — that's `/idea-pipeline`.

## Phase 4 — Deliver

- Present the themed batch in the block format above.
- Add a 1-line **"start here"** call-out: the 3 ideas that best fit the brief (advantage ×
  feasibility × pull), and why.
- **If `--to-inbox`** (or the user says yes): create a theme folder per `## Theme` in
  `00-inbox/` (frontmatter `kind: theme`, per-idea checklist + the blocks verbatim),
  then run `scripts/board.sh`. Mirror the structure of existing imported themes.
- **Handoff**: "Run `/idea-pipeline --rank` to grill, research, and rank these; then
  `/brand-name-research` on a winner."

## Notes

- This skill is the **divergent** front door; keep it generative and fast. Resist the urge
  to evaluate — capturing a bad idea is cheap, killing it later is the pipeline's job.
- Re-runnable: call again with a different angle/lens to get a fresh, non-overlapping batch
  (it reads what's already in the inbox to avoid repeats).
