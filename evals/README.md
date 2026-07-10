# Skill evals

A tiny, dependency-free harness that proves the judgment skills actually behave
— the "the gate has a track record" ethos applied to the skills themselves. In
2026 a skill that ships without evals is a skill nobody can trust; this directory
is that proof for the judgment layer.

These are **shape / contract checks, not LLM calls.** They never invoke a model,
touch the network, or install anything (`json`, `os`, `re`, `sys` — all stdlib).
They verify that each skill *documents* the verdict line it promises and that a
canonical example of that line *parses* under the shared verdict grammar.

## What it proves

For every skill in [`cases.json`](./cases.json), [`run-evals.py`](./run-evals.py)
asserts three things:

- **(a) Documented output contract.** `skills/<skill>/SKILL.md` exists and
  contains every `doc_markers` substring — i.e. the skill actually documents its
  verdict line grammar (e.g. `DOOR:`, `GATE:`, `on-fail:`, the allowed tokens
  `CONFIRMED` / `REFUTED` / `UNVERIFIED`, …).
- **(b) The grammar supports the line.** The skill's `canonical_ledger_line`
  parses non-malformed under the verdict grammar, reusing
  [`../verdict-grammar/parse_verdicts.py`](../verdict-grammar/parse_verdicts.py)
  when it ships alongside and an equivalent local parser otherwise. For skills
  whose ledger `TYPE` is a *known* grammar type (`DOOR GATE PREMORTEM REFUTE
  DRIFT ALTITUDE`) the parsed TYPE must match; for pass-through skills
  (`ESCALATE`, `PRECEDENT`) it must parse cleanly as an unknown type. An allowed
  verdict token must appear, and the in-skill `PREFIX: …` line must match the
  skill's own `verdict_regex`.
- **(c) Self-containedness.** Frontmatter declares `origin:` and the body carries
  the standalone-essentials structure every skill in this repo ships with — an
  `## Invocation` block and a `## Composes with` block.

> **Note on "standalone essentials".** This repo does not use a literal
> `## Standalone essentials` heading. Self-containedness is enforced through
> frontmatter `origin:` + [`scripts/lint.py`](../scripts/lint.py) (no machine
> paths, no unguarded external `/command` refs) + the fixed section structure
> (`## Invocation` … `## Composes with`). Check (c) verifies those real markers.

Exit code is `0` only when every skill passes; any failure prints the reason and
exits non-zero. It runs in CI as the `evals` job.

## Run it

```
python3 evals/run-evals.py
```

## Adding an eval when you add a skill

When you add a judgment skill that emits a grep-able verdict line, add one object
to the `cases` array in `cases.json`:

| field                    | meaning                                                            |
| ------------------------ | ------------------------------------------------------------------ |
| `skill`                  | directory name under `skills/`                                     |
| `situation`              | one-line human description of the test prompt (documentation only) |
| `ledger_type`            | the `TYPE` token in `verdicts.log`, or `null` for the ledger skill |
| `ledger_known`           | `true` if `ledger_type` is a known grammar type; `false` = passthrough |
| `allowed_tokens`         | the verdict tokens the line may carry (e.g. `CONFIRMED`/`REFUTED`) |
| `doc_markers`            | substrings that MUST appear in `SKILL.md` (its documented grammar) |
| `canonical_ledger_line`  | a full `date \| TYPE \| verdict \| … \| by:` line that must parse   |
| `canonical_verdict_line` | the in-skill `PREFIX: …` line the skill emits                       |
| `verdict_regex`          | a regex the `canonical_verdict_line` must match                    |

Then run `python3 evals/run-evals.py` and confirm your skill prints `PASS`. If a
skill genuinely emits no verdict line, it needs no eval case here — but most
judgment skills should.
