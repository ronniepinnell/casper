---
name: think
origin: authored
description: Structured thinking moves for when you're stuck, the answer feels too easy, or a problem needs depth — invert, second-order, base-rate, analogy, constraint-flip, decompose. Routes a situation to the right move and forces it to completion. Use for design deadlock, suspicious consensus, novel problems, or "we've always done it this way".
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[the problem, or a move name: invert | second-order | base-rate | analogy | flip | decompose]"
---

# /think — Forced Thinking Moves

Depth isn't a mood, it's a set of operations. Each move below is mechanical
enough for any model to execute, and each one reliably surfaces things straight
line reasoning misses. Pick ONE move and run it to completion — six half-moves
are worth nothing.

## The moves

**invert** — Solve the opposite. "How would we guarantee this project fails /
this page is slow / users churn?" List 5+ ways, concretely. Then check which
ones you're currently doing. The anti-goal list is usually more actionable
than the goal list.

**second-order** — "And then what?" three times. Every proposed change: who
reacts, what adapts, what breaks one step later? First-order thinking says
"cache it, it's faster." Second-order asks who now serves stale data, and
third-order asks what they build to work around it.

**base-rate** — Before reasoning about THIS case, ask: what happens to MOST
cases like it? Most rewrites fail. Most "quick migrations" take 3×. Most
features get <10% adoption. Start from the base rate, then justify — with
specifics, not optimism — why this instance beats it. No specifics = it doesn't.

**analogy** — Name 2–3 systems that solved a structurally identical problem
(different domain welcome: logistics, biology, markets, other codebases).
Steal the shape of the solution, then list where the analogy BREAKS — the
break-points are where your real design work lives.

**flip** — Take the binding constraint and negate it. "We can't change the
schema" → design as if you could; is the result 10× better? Then the real task
is removing the constraint, not working around it. Also run the reverse:
add a brutal constraint ("must work offline", "10ms budget", "one file") and
see what the forced simplicity teaches.

**decompose** — The problem resists because it's actually 3 problems wearing
a coat. Split until each piece has a known solution or a nameable unknown.
The nameable unknowns are the real work; everything else is assembly.

## Routing (when invoked with a problem, not a move)

| Smell | Move |
|---|---|
| Consensus came too easily | invert |
| Change looks free | second-order |
| "This time is different" energy | base-rate |
| Genuinely novel problem | analogy, then decompose |
| Grinding against a wall | flip |
| Too big to hold in your head | decompose |

## Procedure

1. State the problem in one sentence.
2. Pick ONE move (use the routing table; say why).
3. Execute it fully — the listed outputs, not a gesture at them.
4. End with: what changed? A new risk found, a decision reversed, a constraint
   to attack, sub-problems named. If nothing changed, say so and either run
   ONE different move or stop — don't move-shop until something agrees with you.

## Composes with

- `/premortem` is `invert` specialized for shipping; `/altitude` is `decompose`
  specialized for bugs. Use those when they fit; /think covers the open field.
- `/door` — one-way doors deserve a `second-order` pass before committing.
- Output verdicts worth keeping → `/verdict log THINK: …`.
- `/premortem` and `/altitude` name /think back as the general form of their moves.
