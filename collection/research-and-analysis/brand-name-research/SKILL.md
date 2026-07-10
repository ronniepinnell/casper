---
name: brand-name-research
origin: authored
public: true
description: Generate and vet product/brand names end-to-end. Grills you on the product, vibe, and constraints (or reads a README), brainstorms candidates, then passively screens each for domain, App Store / Play Store, trademark, company, GitHub/npm/PyPI, and social-handle availability — and only delivers names that PASS. Built to kill the "I love this name… oh, it's an app" trap. Use for naming a product, app, company, library, or project.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, WebSearch, WebFetch
argument-hint: ["product or idea" | --from-readme <path> | --check "name1,name2"]
---

# Brand Name Research

Turn a multi-hour, repetitive naming slog into one guided pass. The golden rule:
**never raise hopes on a name that won't survive.** Only fully-screened, PASSING names
are shown — taken ones are filtered out silently (with a count of how many died).

## Operating principle: passive checks only (no front-running)

Domain "search" boxes on registrars (GoDaddy, Namecheap, etc.) and their availability
APIs can **log your query and get the domain front-run** (someone registers it before
you do). This skill NEVER touches those. It only uses:

- `dig` / `whois` (DNS + registry lookups — read-only, no "search intent" leaked)
- Public read APIs: iTunes Search API (App Store), npm registry, PyPI, GitHub profile pages
- `WebSearch` / `WebFetch` for Play Store, trademarks, existing companies, social handles

When the user picks a winner, tell them to **register the .com (and chosen TLDs)
immediately** through a real registrar — don't sit on it.

---

## Phase 0 — Inputs

If `--check "name1,name2"` is passed: skip Phases 1–2, go straight to screening those.
If `--from-readme <path>` (or a `*/README.md` is obviously relevant): read it to seed the
grill, then still confirm the gaps below.

---

## Phase 1 — Grill me (the interview)

Use `AskUserQuestion`. Keep it to 2 batches. Skip anything already known from a README.

**Batch A — the product & the vibe**
1. **What is it, in one sentence?** (who it's for + what it does) — *prefill from README if given.*
2. **Market / category?** (e.g. dev tools, hockey analytics, fintech, consumer notes app)
   — this defines "same-market collisions" to reject.
3. **Name style** (multi-select): real word · coined/invented · compound (two words) ·
   misspelling/respelling · metaphor/evocative · short & abstract · person/place · acronym.
4. **Vibe / adjectives** — 3–5 words it should feel like (e.g. "fast, sharp, technical"
   or "warm, playful, human"). Names you already like (any field) to triangulate taste.

**Batch B — hard constraints**
5. **Desired TLDs**, in priority order (e.g. `.com` required, then `.io`, `.dev`, `.ai`).
   Note if `.com` is mandatory or just preferred.
6. **Length / syllables** ceiling (e.g. ≤ 7 letters, ≤ 2 syllables, "must be typeable").
7. **Must include / must avoid** — letters, sounds, words, themes. Languages to avoid
   bad connotations in. Competitors whose names it must NOT resemble.
8. **Channels that must be clean** (multi-select): domain · Apple App Store · Google Play ·
   US trademark · GitHub org · npm · PyPI · X/Twitter handle · Instagram handle.
   (Only these are treated as PASS-blocking; others are "nice to have, reported.")

Echo back a 4–6 line **naming brief** and get a thumbs-up before generating.

---

## Phase 2 — Generate candidates

Brainstorm **40–60** candidates matching the brief. Use varied techniques so the pool is
diverse, not 50 variations of one root:

- Real words & evocative metaphors from the product's domain.
- Coined words (blend two roots; add suffixes -ly, -ify, -io, -ory, -al; drop vowels).
- Compounds (Adjective+Noun, Noun+Noun) and clipped compounds.
- Greek/Latin/other-language roots tied to the concept (sanity-check meaning).
- Sound-symbolism matching the vibe (plosives = sharp/fast; liquids/nasals = smooth/calm).

Internally note each candidate's style + why it fits. Do **not** show the raw 60 yet —
they haven't been screened.

---

## Phase 3 — Screen (passive, batched)

> **ORDER MATTERS: go BROAD before NARROW.** The #1 failure mode of this skill is trusting
> the App Store API + a market-qualified search and declaring a name "clean" — then a plain
> Google of the bare word instantly surfaces a Google-Play/international app, an apparel
> label, a crypto token, or a supplement vendor on the exact name. **Always run the broad
> gut check (3a) FIRST and let it kill names before you spend lookups on anything else.**

### Phase 3a — BROAD GUT CHECK (mandatory, runs first, no market qualifier)

For EVERY surviving candidate, before any other check:

1. **Bare-word web search** — `WebSearch "<name>"` and `WebSearch "<name> app"`.
   - Do **NOT** append your market keyword here ("fitness", "hockey", etc.). Broad first —
     you're looking for *anyone at all* on the exact string. A market qualifier hides
     collisions in adjacent categories (apparel, crypto, supplements, gaming, music).
   - Read the top ~10–15 results and **catalog every exact-spelling entity in ANY category**:
     apps (iOS **and** Android **and** web, any country), companies/startups, clothing/merch
     brands, crypto tokens, supplement/peptide vendors, bands/musicians, gamers/streamers,
     products. Note what each is + how active/prominent.
2. **App stores, both, explicitly** — `WebSearch "<name> site:play.google.com"` AND
   `WebSearch "<name> site:apps.apple.com"`. The iTunes API in the script misses
   Google Play and many international iOS apps — this catches them.
3. **Socials sweep (always run, not just if selected)** — WebFetch each for 404-vs-profile:
   `x.com/<name>`, `instagram.com/<name>`, `tiktok.com/@<name>`, `youtube.com/@<name>`,
   `twitch.tv/<name>`, `github.com/<name>`. Report which exact handles are taken and by whom.

**Reject in 3a (hard FAIL) if any of:** an exact-name app exists on *any* store; a
*prominent* global brand owns the word; **any** entity uses the exact name **in or adjacent
to the product's category** (for a fitness app that includes activewear, supplements,
wearables, sports gear, gyms, athletes); or the name is so widely used that it's effectively
un-ownable. A few tiny unrelated entities in far-off categories are acceptable but must be
**reported, not hidden** — the user decides.

Only names that survive 3a proceed to 3b.

### Phase 3b — Structured checks (only on 3a survivors)

Run the bundled screener:

```bash
scripts/check-name.sh "<candidate>" --tlds <com,io,dev,...>
```

It reports per-candidate: domain status per TLD, Apple App Store match, GitHub/npm/PyPI,
and a final `VERDICT: PASS|FAIL`. Run candidates in batches (independent — fire several Bash
calls in parallel). Then:

- **Existing company in the same market** — NOW you may add the market keyword:
  `WebSearch "<name> <market keyword>"` → a real player in the category = reject.
- **US trademark** (if selected): `WebSearch "<name> trademark"` or check
  `tmsearch.uspto.gov`; flag live marks in related classes. (Advisory, not legal advice.)
- **Domains/handles**: confirm the specific TLDs and the exact handles you'd actually use.

A candidate **PASSES** only if (a) it cleared the broad gut check 3a, and (b) every channel
the user marked PASS-blocking (Phase 1 Q8) is clear. Keep a tally: `screened N → M passed`,
and note *why* each died (broad-search collision / app / domain / company / trademark).

---

## Phase 4 — Deliver only survivors

Aim to present **8–15 PASSING names** (generate another batch and re-screen if too few).
Rank by fit to the brief (vibe + style + length + how clean across channels).

Output a table — every row is a name that already survived screening (incl. the 3a broad gut check):

| Name | Style | Why it fits | Broad web (any exact-name entity?) | .com | other TLDs | App stores (iOS+Play) | TM signal | Handles |
|------|-------|-------------|------------------------------------|------|-----------|-----------------------|-----------|---------|
| Saber | real word | sharp, fast, technical | only a tiny unrelated EU firm | ✅ free | .io ✅ .dev ✅ | clear both | none seen | @saber taken→@saberhq ✅ |

Then:

- **Top 3 picks** with a one-line rationale each.
- **Footer**: "Screened {N} candidates, {N−M} eliminated (apps/domains/companies)."
- **Action**: "Register the .com + chosen TLDs now before sharing the name anywhere —
  searches elsewhere can tip off squatters."

Offer to: save the report to the product folder (`Write` a `NAMING.md` next to the
README), run another round with a tweaked brief, or deep-dive trademark on a finalist.

---

## Notes & limits

- DNS-clear is a strong but not 100% signal a domain is unregistered (rarely, a registered
  domain has no DNS); the screener confirms with `whois`. Conservative by design — it
  would rather call a free name "registered" than the reverse.
- Trademark output is a **signal, not legal clearance**. For anything you'll build a
  business on, do a proper search / consult counsel before filing.
- This skill checks availability and collisions; it does not register anything.

## Judgment weave (see /judgment)

- **Before delivering the winner:** names are **`/door`** territory — one-way once shipped. Enumerate the lock-in (domains bought, handles claimed, SEO) before the user commits.
