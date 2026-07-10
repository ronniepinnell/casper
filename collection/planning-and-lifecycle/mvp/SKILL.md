---
name: mvp
origin: authored
public: true
description: Intense discovery + design session that births Initiatives in Linear. Grills Operator on problem, customer, risk, and scope — then forces cuts, simulates future trajectories, and creates a structured Initiative with linked milestones ready for CCB.
trigger: /mvp
argument-hint: ["topic or idea" | --simulate | --validate {initiative_id}]
---

# `/mvp` — MVP Discovery & Initiative Builder

> Not a lifecycle manager — a creative/discovery session.
> Output: 1 Initiative in Linear with ordered milestones, dependencies, and a one-paragraph bet statement.

## Modes

| Argument | Mode | What it does |
|----------|------|-------------|
| `"topic"` or no arg | **Discovery** | Full grill + design session for a new idea |
| `--simulate` | **Simulation** | No new idea — plays out existing roadmap at 3 trajectories |
| `--validate {id}` | **Validation** | Challenges an existing Initiative before CCB |

---

## Mode: Discovery (default)

### Phase 0 — Full Context Load (runs before first question)

Before asking anything, load full project context in parallel. This gives the session depth — the agent arrives informed, not blank.

#### 0a: Linear Snapshot

```bash
# task-manager auth handled by the adapter via {secret_manager}

# All open initiatives
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "query { initiatives { nodes { id name status description } } }"}'

# In-progress + backlog milestones
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "query { projects(filter: { state: { in: [\"started\", \"planned\"] } }) { nodes { id name state description } } }"}'
```

#### 0b: Codebase + Specs Scan

Read in parallel:
- `{roadmap_file}` — strategy + 5-year vision
- `docs/MASTER_INDEX.md` — what's built + what's planned
- `docs/.abstract.md` + `{spec_dir}/.abstract.md` — orient before diving
- Last 20 merged PRs: `git log --oneline --merges origin/develop -20`
- `CLAUDE.md` vision paragraph (The Utopia)

#### 0c: Competitive + Market Intelligence

```bash
# Read latest competitive analysis
cat docs/COMPETITOR_ANALYSIS.md | head -100
```

Spawn in parallel:
- `Agent(subagent_type: "market-scout", prompt: "Give me a 5-bullet state-of-market for the product. Focus on: who owns youth/junior hockey analytics today, pricing signals, biggest unmet needs. Report in under 150 words.")`
- `Agent(subagent_type: "competitive-analyst", prompt: "Read docs/COMPETITOR_ANALYSIS.md and give me the 3 most dangerous competitive gaps for the product as of today. Under 150 words.")`

#### 0d: Domain + Customer Intelligence

Spawn in parallel:
- `Agent(subagent_type: "hockey-analytics-sme", prompt: "What are the top 3 analytics capabilities that youth/junior coaches currently lack but would pay for? Be specific — not 'better stats', actual capability gaps. Under 150 words.")`
- `Agent(subagent_type: "product-manager", prompt: "Review {roadmap_file} and docs/MASTER_INDEX.md. What are the most important unaddressed user needs across coach, parent, and scout personas? Under 150 words.")`
- `Agent(subagent_type: "customer-success-manager", prompt: "Based on {roadmap_file} and any onboarding/engagement specs you can find in {spec_dir}/, what friction points or drop-off risks exist today for our customers? Under 150 words.")`

#### 0e: Intel Snapshot

```
list_decisions(limit: 20)   # recent decisions — what's already locked
list_ideas(limit: 10)        # recent ideas — what's already been explored
```
(Storage backend ops; return `[]` under `storage_backend: none`.)

#### 0f: Present Context Summary to Operator

After all parallel loads complete, present a compact brief:

```
CONTEXT LOADED — {topic or "new idea"}

Project State:
  {N} open milestones | {M} initiatives in progress
  Last merged: {last PR title} ({date})

Competitive Landscape (2-line summary from agents):
  {market-scout finding}
  {competitive-analyst finding}

Domain Gaps (from hockey SME):
  {top 1-2 gaps relevant to this topic}

Recent Decisions Relevant to This Topic:
  {1-3 from storage `list_decisions` if applicable, else "none found"}

Ideas Already Logged:
  {1-2 from storage `list_ideas` if applicable, else "none found"}

Ready to explore: {topic}
```

Then proceed to Phase 1.

---

### Phase 1 — Frame the Bet (5 questions max)

Ask one at a time. Wait for answer before continuing.

```
1. Describe the idea in one sentence — not what it does, what problem it solves.

2. Who specifically has this problem? Not "coaches" — which coaches, at what level,
   in what situation? Paint the person.

3. What do they do today instead? How do they solve this without you?

4. Why hasn't someone built this already — or if they have, why does your version win?

5. What does success look like in 12 months? Not features — outcomes.
   (Revenue, users, retention, data volume, partnerships — pick one number.)
```

After each answer, probe once if the answer is vague:
> "Can you be more specific? 'Better analytics' isn't a bet — what number moves?"

### Phase 2 — Stress Test (adversarial)

```
6. What's the single riskiest assumption in this idea?
   (Not technical risk — market/customer/timing risk.)

7. What would have to be true for this to completely fail?

8. Who is the best-positioned competitor to copy this in 6 months?
   What's your moat?

9. If you could only build ONE thing from this idea — the thing that
   proves the bet is right — what is it?
```

Agent challenges weak answers:
> "That moat sounds like a feature, not a moat. Features get copied. What's structural?"

### Phase 3 — Scope Forcing

Present back what you heard as a "bet statement":

```
──────────────────────────────────────────────────
THE BET

We believe {target customer} needs {specific capability}
because {root problem}.

We'll know we're right when {measurable outcome} within {timeframe}.

The riskiest assumption is {assumption}.
The minimum thing we can build to test it is {MVP scope}.
──────────────────────────────────────────────────

Does this capture it? Or what's wrong?
```

Operator corrects. Iterate max 2 rounds until Operator says "yes" or "close enough."

Then force the cut:
```
10. If you had to ship the MVP in 8 weeks, what survives from the bet above?
    What gets cut? What gets deferred?

11. Name the MVP in 5 words or fewer.
```

### Phase 4 — Future Simulation

Present 3 trajectories based on what you heard:

```
THREE TRAJECTORIES

CONSERVATIVE — builds only the proven core
  Milestones: {M1} → {M2} → {M3}
  12-month outcome: {outcome}
  Risk: {risk}

EXPECTED — your current bet, executed well
  Milestones: {M1} → {M2} → {M3} → {M4}
  12-month outcome: {outcome}
  Risk: {risk}

AMBITIOUS — if the bet is right and you move fast
  Milestones: {M1} → {M2} → {M3} → {M4} → {M5}
  12-month outcome: {outcome}
  Risk: {risk}
```

Force a choice:
```
12. You can only fully commit to one trajectory. Which?

13. What would make you upgrade from Expected to Ambitious?
    What single signal unlocks it?
```

### Phase 5 — Build Initiative in Linear

Once trajectory is chosen, confirm the milestone chain:

```
INITIATIVE: {MVP name} — {one-line bet}

Milestones (in order):
  1. {milestone_id} — {title} — {one-line goal}
  2. {milestone_id} — {title} — {one-line goal}
...

Dependencies:
  M2 depends on M1, M4 depends on M2+M3

Create this in Linear? (yes / adjust first)
```

On Operator approval, create in Linear:

```bash
# task-manager auth handled by the adapter via {secret_manager}

# Create Initiative
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation {
      initiativeCreate(input: {
        name: \"{MVP name}\",
        description: \"## The Bet\\n{bet_statement}\\n\\n## Target Customer\\n{customer}\\n\\n## Success Metric\\n{outcome} by {timeframe}\\n\\n## Riskiest Assumption\\n{assumption}\\n\\n## Trajectory\\n{chosen_trajectory}\\n\\n## Milestones\\n{milestone_list}\\n\\n## Created\\n/mvp session — {date}\"
      }) { success initiative { id name } }
    }"
  }'
```

Then create each milestone in Linear and link to the initiative.

Report:
```
Initiative created: {Linear URL}

Milestones created:
  {M1} — {title} — {Linear URL}
  {M2} — {title} — {Linear URL}

Next step: /ccb to plan the first milestone in detail
Or: /initiative start {initiative_id} to begin immediately
```

Also capture the bet statement via the storage backend (no-op under `storage_backend: none`):
```
record_decision(
  title: "MVP Bet: {MVP name}",
  body:  "{bet_statement}\n\nTrajectory: {chosen}\nRiskiest assumption: {assumption}",
  type:  "mvp"
)
```

---

## Mode: `--simulate`

No new idea. Agent reads the current Linear roadmap and plays out the existing milestones at 3 trajectories (conservative/expected/ambitious) based on current velocity and scope.

Asks:
1. What's slipping? What's ahead of schedule?
2. What would you cut if you had to ship 2 months early?
3. What single milestone, if done perfectly, unlocks the rest?

Produces a trajectory comparison table. Does NOT create new Linear items — simulation only.

---

## Mode: `--validate {initiative_id}`

Reads an existing Initiative from Linear and stress-tests it before CCB:

1. Reads the initiative description and linked milestones
2. Runs Phase 2 (adversarial questions) against the stated bet
3. Checks: is the bet statement clear? Is there a measurable success metric? Are dependencies ordered correctly?
4. Produces a validation report: STRONG / SHAKY / WEAK with specific gaps
5. Does NOT modify the initiative — advisory only

---

## Key Rules

- One question at a time. Always wait for the answer.
- Probe vague answers once before moving on. Don't accept "better UX" as a bet.
- The bet statement must have: customer, problem, outcome, timeframe. Missing any = probe.
- Never skip Phase 2 (adversarial). The stress test is the most valuable part.
- Initiative is not created until Operator explicitly approves the milestone chain.
- `/mvp` is upstream of `/ccb` — it produces the initiative. CCB plans the first milestone in detail.

## Judgment weave (see /judgment)

- The grill phase should include `base-rate` from `/think`: what happens to MOST products/features of this shape? Justify beating the base rate with specifics or cut.
- Scope cuts are `/door` calls — cutting reversibly is free; cutting something expensive to re-add gets the lock-in questions.
- The initiative doesn't get created until it carries a `/premortem` and at least one kill `GATE:` ("if metric X < Y by checkpoint Z, we stop").
