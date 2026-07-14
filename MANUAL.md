# The Casper Manual

> How to bank hard-won judgment as procedure any model — or any human — can
> execute. This is the one deep doc for the toolkit. The quick map lives in
> `skills/judgment/SKILL.md`; adoption-facing basics live in the README.

## 1. The thesis

Model capability does not transfer through prompt phrasing, personality
emulation, or "think harder" instructions. It transfers through two things:

1. **Forced procedure** (skills) — a numbered sequence with mandatory outputs,
   where skipping a step is visible. A weaker model running a strong procedure
   beats a strong model running on vibes, most days.
2. **Mechanical gates** (hooks) — zero-LLM checks that fire regardless of what
   any model believes. The model can be wrong; the regex doesn't care.

Corollary: **the accumulated correction history is the asset, not the model.**
Every time a model (or a person) burns you, the fix must land as a procedure
step, a gate, or a checklist line in your toolkit. "We learned our lesson"
stored in anyone's head — silicon or meat — evaporates. This toolkit is where
lessons go to stop evaporating.

## 2. The toolkit at a glance

| Layer | Artifacts | Property |
|---|---|---|
| Procedure | /refute /door /gate /drift /altitude /premortem /think /merge-train /audit-skills | model runs it, steps are checkable |
| Record | /verdict (ledger), /calibrate (scoring) | memory that survives sessions and models |
| Routing | /escalate (queue hard calls to `.claude/escalation-queue.md`, burn in batch), /precedent (follow or distinguish prior rulings) | judgment spent where it's strongest, never re-derived |
| Scale | /sweep (audit fan-out) | one agent can't hold a system; a fan-out can |
| Mechanical | claim-evidence, spec-citation, scope-creep hooks (+ optional guards & telemetry) | fires without any model's cooperation |
| Domain | skills/judgment/domains/{stats,ml-cv,code,process}.md | judgment specialized per field |

## 3. The operating loop

Where each tool attaches to a standard build cycle. If your workflow has its
own lifecycle commands (planning, per-task, commit), wire these in at the
matching moments — none of this depends on any particular workflow.

```
PLAN      open by running /drift on the specs you're about to trust
          big choices → /door (run /precedent first)
          plan → /premortem     risks → /gate
BUILD     spec-citation + scope-creep hooks run silently
          stuck → /think        bug → /altitude first
DISPATCH  delegated work carries a handoff contract:
          claim to prove + gate + evidence format expected
VERIFY    /refute the claim → /gate check → claim-evidence hook at commit
CLOSE     refute the work's own completion claim before marking it done
RECORD    every verdict → /verdict log
LEARN     monthly or per-milestone → /calibrate; corrections land in domains/
ESCALATE  judgment-dense question? queue it via /escalate, ship the rest
```

Standing cadence: `/calibrate` monthly · `/escalate burn` whenever your
strongest model (or a human adjudicator) is available.

Anti-ceremony rule: most moments need exactly ONE tool. Two-way-door decisions
need none. If the loop ever feels like paperwork, the calibration data will
show which steps never catch anything — delete those, keep the ones with kills.

## 4. Memory that survives sessions and models

- `.claude/verdicts.log` (per project) — the append-only judgment ledger.
  Committed, never edited, union-merged. Query with `/verdict`, mine with
  `/precedent`. "Show me every gate we overrode" is a grep, not archaeology.
- `.claude/escalation-queue.md` (per project) — the escalation queue; its
  Adjudicated section is a precedent store.
- Your toolkit itself — where every lesson lands as a procedure step, gate,
  or checklist line.

Recommended git plumbing:

```
echo ".claude/verdicts.log merge=union" >> .gitattributes
echo ".claude/.judgment-state/" >> .gitignore
echo ".claude/.spec-cited"      >> .gitignore
```

## 5. How to author a new judgment artifact

When something burns you, run this conversion:

1. **Name the failure class**, not the incident. "Claimed done without running
   it" — not "the login bug".
2. **Pick the layer:**
   - Can a regex/script catch it? → **hook** (strongest; needs no cooperation)
   - Does it need judgment but follows a repeatable shape? → **skill** with
     numbered steps and a mandatory output format
   - Is it domain knowledge? → **checklist line** in
     `skills/judgment/domains/<field>.md`, phrased as a check + the refutation
     that tests it
3. **Give it a verdict format.** Every artifact must emit a one-line,
   grep-able verdict (`GATE: …`, `DOOR: …`). Unloggable output is unlearnable.
4. **Make it fail loud, once.** Gates that nag get disabled; gates that fire
   once with a clear demand get obeyed (see scope-creep's fired-marker pattern).
5. **Default OFF for hooks.** Ship inert (config-gated); each project opts in.
   A hook that breaks someone's workflow uninvited gets ripped out along with
   your credibility.
6. **Test it by refuting it.** Feed it the case it must block AND the case it
   must pass — that's what `hooks/judgment/test.sh` does for every shipped
   hook. The first version of this toolkit's own hooks shipped broken and was
   caught only because /refute was run on "the hooks work". Physician, heal
   thyself — mechanically.

## 6. Choosing skill vs hook vs manual line

```
Can it be checked without understanding? ──yes→ HOOK
        │ no
Does it recur with the same shape?       ──yes→ SKILL (procedure)
        │ no
Is it "know this when working in X"?     ──yes→ DOMAIN MANUAL line
        │ no
It's a one-off → /verdict log it and move on
```

## 7. Operating notes

- **Hooks are inert without `.claude/judgment.json`** in the host project.
  Install: copy `hooks/judgment/judgment.json.example` to
  `.claude/judgment.json`, flip `enabled: true` per gate, list your protected
  globs, and wire each script into `.claude/settings.json` per the exact JSON
  snippet in that script's header comment. `./install.sh --hooks` automates
  the copy; the settings wiring stays explicit and reviewable.
- **The ledger (`.claude/verdicts.log`) is committed**, append-only, per project.
- **Calibration closes the loop:** /calibrate reads the ledger, finds the
  systematic errors, and its corrections must land back in the toolkit — a new
  domain line, a retuned gate default, a demoted confidence tier. A calibration
  that changes nothing was a report.
- **Model routing:** procedures are model-agnostic by design. Spend your
  strongest model on authoring NEW procedure (one-way doors, borderline gate
  calls, spec-drift adjudication); cheaper models execute existing procedure.
  Never pay frontier prices to re-derive what a checklist already knows.
- **Override rule:** any decision that contradicts a logged verdict or a
  found precedent without an explicit, logged DISTINGUISH/OVERRIDE line is a
  judgment override — declare it, name a human on it.

## 8. Troubleshooting

1. **Hook not firing** — hooks are inert unless the project has
   `.claude/judgment.json` with that gate's `enabled: true`, AND the hook is
   wired in `.claude/settings.json` per the script's header snippet, AND the
   script is executable (`chmod +x`).
2. **Hook fires when it shouldn't** — check the config keys against
   `judgment.json.example`; invented keys silently disable gates (the shipped
   keys are e.g. `protected_globs`, not `protected`).
3. **Skill not appearing** — `skills/<name>/SKILL.md` must exist (exact case)
   in your project's `.claude/skills/` with a frontmatter `name:` matching the
   directory and a real `description:`. `scripts/lint.py` pinpoints problems.
4. **Everything at once** — run `hooks/judgment/test.sh`; it exercises every
   shipped hook's block case, pass case, and inert-without-config case.

## 9. Worked examples

Rules without cases don't transfer to weaker models. Each procedure skill
(/door /refute /drift /gate) carries exactly one **real** worked example —
a ruling from the toolkit's own development history, reproduced as a static
transcript — showing input → steps actually taken → verdict line in the
skill's own grammar. New cases come from `/escalate` burn transcripts: as real
rulings accumulate, they replace any synthetic examples. An invented example
teaches the format; a real one teaches the judgment.
