# Verification & Audit

Prove the work is real: completion reality-checks, spec/rules conformance, bug hunts, and over-engineering review.

[← Back to the collection index](../../README.md)

### Skills (8)

| Unit | What it does | When to call | Install |
|---|---|---|---|
| `cleanup` | Mass reconciliation when things are out of whack | — | `./install.sh --only cleanup` |
| `completion-audit` | Session/project-scope reality audit. Independently establishes how much of the claimed-done work is genuinely functional, cross-checked against every… | Use before committing or closing issues, when statuses say done but the system misbehaves, or whenever an honest project snapshot is needed. Supports… | `./install.sh --only completion-audit` |
| `dossier` | Frontier dossier session — run a repo's deepest available review with the strongest available model and bank ALL of it in one committed, append-only… | Use when frontier-model time is scarce and its judgment must survive as a permanent artifact; rerun periodically and diff against the last section | `./install.sh --only dossier` |
| `find-bugs` | Find bugs, security vulnerabilities, and code quality issues in local branch changes | Use when asked to review changes, find bugs, security review, or audit code on the current branch. ALWAYS run before committing | `./install.sh --only find-bugs` |
| `pragmatism-audit` | Over-engineering review. Examines recently written code for complexity that the project's actual scale and needs don't justify, and proposes the smal… | Use after implementing a feature or making an architectural decision, before completion review | `./install.sh --only pragmatism-audit` |
| `rules-audit` | Project-rules enforcer. Reviews recent changes strictly against the binding instructions in CLAUDE.md (and any project rule checklist), flagging ever… | Use after any code change and before commit | `./install.sh --only rules-audit` |
| `spec-audit` | Code-vs-spec comparator. Reads the source first-hand and compares it against written specification documents, classifying every divergence as absent,… | Use before PRs, after spec'd feature work, or when spec drift is suspected | `./install.sh --only spec-audit` |
| `validate-completion` | Single-task completion verifier. When an implementer claims a task or feature is finished, establish whether the goal was genuinely achieved — by exe… | Use immediately on any "done" claim, before the status is recorded | `./install.sh --only validate-completion` |

### Agents (10)

| Unit | What it does | When to call | Install |
|---|---|---|---|
| `completion-audit` | Session/project-scope reality auditor. Establishes how much claimed-done work is genuinely functional, cross-checks every planning source, and return… | — | `./install.sh --only completion-audit` |
| `critic` | Adversarially refute a claim before it is believed — a thin dispatcher that runs the `/refute` procedure end-to-end and returns CONFIRMED / REFUTED /… | On any "it works / done / fixed" claim, before commits, PRs, or closing issues | `./install.sh --only critic` |
| `future-self` | Use this agent when you need to evaluate decisions, implementations, and architecture choices against scalability | — | `./install.sh --only future-self` |
| `ledger-keeper` | Append to and query the append-only verdict ledger — a thin dispatcher over `/verdict` and `.claude/verdicts.log` that logs a well-formed line or ans… | Whenever a judgment produces a verdict, or you need "every gate we overrode" as a query | `./install.sh --only ledger-keeper` |
| `pr-reviewer` | Review pull requests for code quality, spec compliance, and CLAUDE.md adherence before merging | — | `./install.sh --only pr-reviewer` |
| `pragmatism-audit` | Over-engineering reviewer. Examines recently written code for complexity the project's actual scale doesn't justify and proposes the smallest design… | — | `./install.sh --only pragmatism-audit` |
| `rules-audit` | Project-rules enforcer. Checks recent changes strictly against the binding instructions in CLAUDE.md and any project rule checklist, citing the exact… | — | `./install.sh --only rules-audit` |
| `spec-audit` | Code-vs-spec conformance auditor. Reads the source first-hand and compares it against written specs, classifying divergences as ABSENT, PARTIAL, WRON… | — | `./install.sh --only spec-audit` |
| `validate-completion` | Single-task completion verifier. Dispatch the instant an implementer (human or agent) claims a task or feature is finished, before the status is reco… | — | `./install.sh --only validate-completion` |
| `verifier` | Run Casper's zero-LLM gates over a diff before it lands — a thin dispatcher that shells the shipped claim-evidence + spec-citation hooks and reports p… | Before committing or opening a PR | `./install.sh --only verifier` |

Install the whole category at once: `./install.sh --category verification-and-audit`
