#!/usr/bin/env python3
"""Skill evals — a tiny, dependency-free contract harness for the judgment skills.

These are SHAPE / CONTRACT checks, not LLM calls. For each skill listed in
cases.json we assert:

  (a) its skills/<skill>/SKILL.md exists and DOCUMENTS its verdict line
      (every `doc_markers` substring appears in the file);
  (b) a canonical example verdict line PARSES under the verdict grammar —
      reusing export/verdict-grammar's reference parser when present, else a
      local regex — and, for skills whose ledger TYPE is a known grammar type,
      that the parsed TYPE matches and carries an allowed verdict token; the
      in-skill `PREFIX:` verdict line also matches the skill's own grammar
      regex;
  (c) the skill is SELF-CONTAINED: frontmatter declares `origin:` and the body
      carries the standalone-essentials structure this repo ships every skill
      with — an `## Invocation` block and a `## Composes with` block. (This repo
      expresses self-containedness through frontmatter `origin:` + scripts/lint.py
      + this fixed section structure rather than a literal "Standalone
      essentials" heading; see README.md.)

Zero external dependencies, no network, no LLM. Exits non-zero on any failure.
MIT (c) Ronnie Pinnell.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CASPER = os.path.dirname(HERE)                     # export/casper
SKILLS = os.path.join(CASPER, "skills")
GRAMMAR_DIR = os.path.join(os.path.dirname(CASPER), "verdict-grammar")

# --- (b) reuse the reference parser if it ships alongside; else fall back ----
_parse_line = None
_KNOWN_TYPES = {"DOOR", "GATE", "PREMORTEM", "REFUTE", "DRIFT", "ALTITUDE"}
if os.path.isfile(os.path.join(GRAMMAR_DIR, "parse_verdicts.py")):
    sys.path.insert(0, GRAMMAR_DIR)
    try:
        import parse_verdicts as _pv  # type: ignore
        _parse_line = _pv.parse_line
        _KNOWN_TYPES = _pv.KNOWN_TYPES
    except Exception:
        _parse_line = None


def parse_line(raw):
    """Parse a `date | TYPE | verdict | detail... | by: who` ledger line.

    Uses the reference parser when available; otherwise a local, equivalent
    regex-free splitter so the evals run standalone.
    """
    if _parse_line is not None:
        return _parse_line(raw)
    line = raw.strip()
    if not line or line.startswith("#"):
        return None
    parts = [p.strip() for p in line.split("|")]
    if len(parts) < 3:
        return {"date": "", "type": "", "verdict": "", "detail": [],
                "commit": "", "by": "", "malformed": True, "raw": line}
    by = ""
    detail = parts[3:]
    if detail and detail[-1].lower().startswith("by:"):
        by = detail[-1][3:].strip()
        detail = detail[:-1]
    commit = ""
    kept = []
    for d in detail:
        if d.lower().startswith("commit:"):
            commit = d.split(":", 1)[1].strip()
        else:
            kept.append(d)
    return {"date": parts[0], "type": parts[1].upper(), "verdict": parts[2],
            "detail": kept, "commit": commit, "by": by,
            "malformed": False, "raw": line}


def frontmatter(text):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return {}
    fm = {}
    for line in m.group(1).splitlines():
        m2 = re.match(r"^([A-Za-z_-]+):\s*(.*)$", line)
        if m2:
            fm[m2.group(1)] = m2.group(2).strip().strip('"')
    return fm


def check_case(case):
    """Return (ok: bool, failures: list[str]) for one skill case."""
    skill = case["skill"]
    fails = []
    path = os.path.join(SKILLS, skill, "SKILL.md")

    # (a) SKILL.md exists + documents its verdict line
    if not os.path.isfile(path):
        return False, [f"SKILL.md missing at skills/{skill}/SKILL.md"]
    text = open(path, encoding="utf-8").read()
    for marker in case["doc_markers"]:
        if marker not in text:
            fails.append(f"(a) SKILL.md does not document marker {marker!r}")

    # (b) canonical ledger line parses under the grammar
    row = parse_line(case["canonical_ledger_line"])
    if row is None or row.get("malformed"):
        fails.append(f"(b) canonical ledger line is malformed / unparsable: "
                     f"{case['canonical_ledger_line']!r}")
    else:
        lt = case.get("ledger_type")
        if case.get("ledger_known"):
            # verdict skill (ledger_type null) just needs a known TYPE present
            if lt is not None and row["type"] != lt:
                fails.append(f"(b) parsed TYPE {row['type']!r} != expected {lt!r}")
            if row["type"] not in _KNOWN_TYPES:
                fails.append(f"(b) TYPE {row['type']!r} not a KNOWN grammar type")
        else:
            # passthrough type: must parse cleanly AND be an unknown type
            if row["type"] in _KNOWN_TYPES:
                fails.append(f"(b) TYPE {row['type']!r} unexpectedly a KNOWN type "
                             f"(expected passthrough)")
        # an allowed verdict token must appear somewhere in the line
        if not any(tok in case["canonical_ledger_line"] for tok in case["allowed_tokens"]):
            fails.append(f"(b) no allowed verdict token {case['allowed_tokens']} in line")

    # (b') in-skill verdict-line shape matches the skill's own grammar
    if not re.search(case["verdict_regex"], case["canonical_verdict_line"]):
        fails.append(f"(b) in-skill verdict line {case['canonical_verdict_line']!r} "
                     f"does not match /{case['verdict_regex']}/")

    # (c) self-containedness: origin frontmatter + standalone section structure
    fm = frontmatter(text)
    if fm.get("origin") not in ("authored", "imported", "forked"):
        fails.append(f"(c) frontmatter origin missing/invalid ({fm.get('origin')!r})")
    if "## Invocation" not in text:
        fails.append("(c) missing '## Invocation' (standalone-essentials structure)")
    if "## Composes with" not in text:
        fails.append("(c) missing '## Composes with' (standalone-essentials structure)")

    return (not fails), fails


def main():
    with open(os.path.join(HERE, "cases.json"), encoding="utf-8") as f:
        cases = json.load(f)["cases"]

    engine = "verdict-grammar reference parser" if _parse_line else "local fallback parser"
    print(f"skill evals — grammar engine: {engine}")
    print(f"cases: {len(cases)}  skills-dir: {os.path.relpath(SKILLS, CASPER)}/\n")

    n_fail = 0
    for case in sorted(cases, key=lambda c: c["skill"]):
        ok, fails = check_case(case)
        print(f"  {'PASS' if ok else 'FAIL'}  {case['skill']}")
        if not ok:
            n_fail += 1
            for msg in fails:
                print(f"          - {msg}")

    print()
    if n_fail:
        print(f"FAILED: {n_fail}/{len(cases)} skills")
        return 1
    print(f"OK: {len(cases)}/{len(cases)} skills pass their output-contract evals")
    return 0


if __name__ == "__main__":
    sys.exit(main())
