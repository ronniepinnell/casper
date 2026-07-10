---
name: pragmatism-audit
origin: authored
public: true
description: Over-engineering review. Examines recently written code for complexity that the project's actual scale and needs don't justify, and proposes the smallest design that still works. Use after implementing a feature or making an architectural decision, before completion review.
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[files/area or decision to review, default: recent changes]"
---

# /pragmatism-audit — Is All This Complexity Earning Its Keep?

The orienting question for every abstraction, layer, and dependency: what
breaks if this is deleted? Anything that can be removed or flattened without
losing essential behavior should be. Complexity is judged against the
project's ACTUAL scale (MVP vs enterprise), not against theoretical best
practice.

Report format, ruling grammar, severity tiers, JSON trailer, degradation
rules, and routing table: see `_shared/audit-report-contract.md`.

## Invocation

```
/pragmatism-audit                    # review recent changes
/pragmatism-audit src/cache/         # review an area or decision
```

## Procedure

1. **Establish the scale context.** Read the project brief/context
   (`.claude/project-context.md`, plan docs) for actual requirements, users,
   and load. Complexity proportional to a need that exists is fine.
2. **Sweep the changed code for the complexity classes:** abstraction stacks
   and wrappers around simple logic; enterprise infrastructure (caching
   layers, resilience frameworks, heavy middleware) with no demonstrated
   need; premature abstraction, speculative flags, compatibility shims for
   code nothing uses; a heavier tech choice where a simpler one meets the
   requirement; process/tooling overhead disproportionate to project size;
   decisions contradicting earlier banked decisions (check the decision log
   via the storage adapter); dependency/version mismatches causing avoidable
   friction; blind spec-following where a practical adaptation was warranted.
3. **Test each candidate by deletion.** The ruling grammar applies:
   CONFIRMED over-engineering (the simpler form demonstrably suffices —
   show it), REFUTED (the complexity is justified; say why), UNVERIFIED.
   Every finding: severity tier, file:line, code evidence.
4. **Rank and propose.** Overall complexity rating (low/medium/high) with
   justification; the top ~5 most impactful problems; a concrete
   simplification per problem with before/after sketches where useful; the
   highest-leverage 1–3 called out as priority actions.
5. **Report:** the above plus the JSON trailer (findings are a subtype of the
   shared schema so `/completion-audit` can consume them), verdict line
   logged via `/verdict`:

```
AUDIT: pragmatism-audit | <scope> | <pass|fail|inconclusive> | <blocking>/<total> findings
```

## Rules

- Deletion proposals must preserve essential behavior — prove it or mark the
  proposal UNVERIFIED and route to `/validate-completion` after the cut.
- Complexity mandated by a spec is challenged at the spec (route:
  spec-audit), not silently ripped out; rule-mandated structure is not a
  finding (route conflicts: rules-audit).
- Under-engineering is out of scope here — fragility findings route to
  completion-audit / validate-completion.

## Judgment weave

- Each "is this justified?" call on a big design is `/door` material; log the
  keep/cut adjudications to `/verdict` and reuse them via `/precedent`.
- A simplification estimated > 2× its claimed effort gets a `/gate` before
  anyone starts it.

## Composes with

- `/completion-audit` — over-engineering is one of its gap types; it consumes this trailer.
- `/simplify` — applies fixes; this audit decides which fixes are worth it.
- `/altitude` — recurring complexity in one layer usually means the problem lives at another.
