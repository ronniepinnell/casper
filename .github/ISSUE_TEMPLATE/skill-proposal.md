---
name: Skill / gate proposal
about: Propose a new skill, hook, or domain checklist line
labels: proposal
---

**Failure class it catches** (the class, not an incident — e.g. "claimed done without running it")

**Layer** (per MANUAL.md §6 decision tree): hook / skill / domain checklist line

**The block case** (a concrete input it must catch)

**The pass case** (a concrete input it must let through)

**Verdict line format** it will emit (e.g. `GATE: <metric> | <threshold> | …`)

**For hooks:** confirm it will ship default-OFF and config-gated, with both
cases added to `hooks/judgment/test.sh`.
