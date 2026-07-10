---
name: judgment
origin: authored
description: Index and installer for the judgment toolkit — six procedure skills (/refute /door /gate /drift /altitude /premortem) and three mechanical hooks (claim-evidence, spec-citation, scope-creep) that bank frontier-model judgment as forced procedure any model can run. Use to see the toolkit, pick the right tool, or install the hooks into a project.
allowed-tools: Read, Glob, Grep, Bash, Write
argument-hint: "[blank for the map | install | <situation to route>]"
---

# /judgment — The Toolkit Map

Capability doesn't transfer between models via vibes or prompt phrasing.
It transfers via **forced procedure** (skills) and **mechanical gates** (hooks).
This toolkit is the accumulated correction history made executable: every time
a model burns you, the fix lands here, and every project inherits it.

## The map

| Command | One-liner | Reach for it when… |
|---|---|---|
| `/refute` | Try to break the claim before believing it | anything is declared done/fixed/working |
| `/door` | Reversible? pick fast. Irreversible? enumerate lock-in | schema, IDs, contracts, stack picks, naming |
| `/gate` | No plan without a numeric abort condition | plan time; long work; "is this good enough?" |
| `/drift` | Spec vs code-as-built — which one is lying? | surprises; before building on a spec |
| `/altitude` | Fix at the cause's layer, not the symptom's | any bug; especially recurring bugs |
| `/premortem` | It already failed — write the report first | before locking designs, launches, migrations |
| `/think` | Forced thinking moves (invert, second-order, base-rate…) | stuck, or the answer came too easily |
| `/verdict` | Append-only judgment ledger | any verdict worth remembering |
| `/calibrate` | Score how past confidence aged | monthly / milestone close |
| `/escalate` | Queue the hard call, ship the rest; `burn` to adjudicate | one-way door w/o precedent; borderline gate; spec-vs-code standoff |
| `/precedent` | Grep prior rulings: follow or explicitly distinguish | before any /door call or decision in a ruled-on domain |
| `/sweep` | Massive audit fan-out → verify → graded synthesis | "audit everything" moments |

Hooks (zero-LLM, fire mechanically — see `hooks/judgment/`):

| Hook | Event | Catches |
|---|---|---|
| `claim-evidence.sh` | PreToolUse:Bash | done-claims in commits with no test/evidence |
| `spec-citation.sh` | PreToolUse:Edit\|Write | protected-path edits without citing the spec |
| `scope-creep.sh` | PostToolUse:Edit\|Write | file-touch count exploding past stated task |

Deep docs: **MANUAL.md at the repo root** (thesis, authoring guide, skill-vs-hook
decision tree) and per-field checklists in **domains/**: [stats](domains/stats.md) ·
[ml-cv](domains/ml-cv.md) · [code](domains/code.md) · [process](domains/process.md).
If your workflow has its own lifecycle commands (planning, task, commit),
wire these tools in at the matching moments — the weave below shows where.

## The standard lifecycle weave

```
PLAN     /door on the big choices → /premortem the plan → /gate the risks
BUILD    spec-citation + scope-creep hooks run silently in the background
FIX      /altitude before writing the fix
VERIFY   /refute the claim → /gate check → claim-evidence hook enforces at commit
AUDIT    /drift sweeps, periodically or when surprised
```

Chain rule of thumb: **door → premortem → gate** going in; **altitude → refute**
coming out. `/drift` is the standing audit between them.

## /judgment install

To wire the hooks into the current project:

1. Copy `hooks/judgment/*.sh` into the project (or reference them from the
   shared checkout) and `chmod +x`.
2. Create `.claude/judgment.json` from `hooks/judgment/judgment.json.example`,
   set `enabled: true` per gate, list the project's protected globs.
3. Add the three entries to the project's `.claude/settings.json` hooks block
   (exact JSON is in each script's header comment).
4. Add `.claude/.judgment-state/` and `.claude/.spec-cited` to `.gitignore`.

All three hooks are inert without `.claude/judgment.json` — safe to ship in
shared config; each project opts in.

## Routing (`/judgment <situation>`)

Given a described situation, name the ONE tool that fits and invoke it.
Don't stack ceremony: most moments need exactly one of these, and two-way-door
decisions need none.

## Install extras

5. **Ledger merge driver** — `.claude/verdicts.log` is append-only and conflicts
   trivially; make git auto-union it:
   ```
   echo ".claude/verdicts.log merge=union" >> .gitattributes
   ```
6. **Calibration cadence** — schedule `/calibrate` monthly (cron/routine or a
   recurring ticket). Corrections it produces must land back in your config
   (domain line, gate default, demotion) — see MANUAL.md §6.

## Composes with

- Every skill in the map above — /judgment is the index and router; each
  companion skill's own "Composes with" section wires it to its neighbors.
- The root **MANUAL.md** (the one deep doc for this toolkit) — the discovery
  entry point into this family.
