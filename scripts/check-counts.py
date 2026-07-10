#!/usr/bin/env python3
"""check-counts.py — Casper's public-tree counts stay true, mechanically.

Casper's thesis is "your claim must match reality." So the numbers Casper
prints about *itself* — in the README badges and prose — must be provably
true and self-checking, not hand-maintained strings that quietly drift.

This recomputes every public-tree count from the tree itself and verifies it
against COUNT markers in README.md, using the same marker convention as the
private scripts/sync-docs.py:

    <!-- COUNT: <key> -->N<!-- /COUNT -->

Derived keys:
  judgment-skills   top-level skills/ dirs with a SKILL.md
  collection-skills collection/**/SKILL.md
  collection-agents collection agent .md files (mindepth2/maxdepth2, not README)
  collection-units  collection-skills + collection-agents
  hooks             hooks/**/*.sh excluding test harnesses (test.sh)
  hook-tests        assertions run by hooks/judgment/test.sh

Modes:
  --check   exit 1 listing every drift (marker value != derived value,
            unknown key, or missing key that the tree defines).
  --write   rewrite each marker in README.md from the tree.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
README = os.path.join(ROOT, "README.md")

COUNT_RE = re.compile(r"(<!-- COUNT: ([a-z0-9-]+) -->)(.*?)(<!-- /COUNT -->)")

# Shields.io badge numbers can't hold COUNT markers (HTML comments contain
# spaces, which terminate a markdown link destination and break the image), so
# the badge digits are gated here instead: each regex has one capture group per
# number, matched against the keys listed alongside it.
BADGES = [
    (re.compile(r"badge/hook__tests-(\d+)%2F(\d+)-"),
     ["hook-tests", "hook-tests"]),
    (re.compile(r"badge/judgment__skills-(\d+)-"),
     ["judgment-skills"]),
    (re.compile(r"badge/collection-(\d+)__units_=_(\d+)__skills_\+_(\d+)__agents-"),
     ["collection-units", "collection-skills", "collection-agents"]),
]


def _count_dirs_with_skill(base):
    n = 0
    if not os.path.isdir(base):
        return 0
    for d in sorted(os.listdir(base)):
        if os.path.isfile(os.path.join(base, d, "SKILL.md")):
            n += 1
    return n


def judgment_skills():
    return _count_dirs_with_skill(os.path.join(ROOT, "skills"))


def collection_skills():
    n = 0
    for dirpath, _dirs, files in os.walk(os.path.join(ROOT, "collection")):
        if "SKILL.md" in files:
            n += 1
    return n


def collection_agents():
    """Agent .md files two levels under collection/ (category/agent.md), not READMEs."""
    base = os.path.join(ROOT, "collection")
    n = 0
    if not os.path.isdir(base):
        return 0
    for cat in sorted(os.listdir(base)):
        catdir = os.path.join(base, cat)
        if not os.path.isdir(catdir):
            continue
        for f in sorted(os.listdir(catdir)):
            if f.endswith(".md") and f != "README.md" and os.path.isfile(
                    os.path.join(catdir, f)):
                n += 1
    return n


def hooks():
    """Shipped hook scripts (*.sh) excluding the test harness."""
    n = 0
    for dirpath, _dirs, files in os.walk(os.path.join(ROOT, "hooks")):
        for f in files:
            if f.endswith(".sh") and f != "test.sh":
                n += 1
    return n


def hook_tests():
    """Assertions reported by the hook test matrix (parse 'N passed')."""
    res = subprocess.run(
        ["bash", os.path.join(ROOT, "hooks", "judgment", "test.sh")],
        capture_output=True, text=True)
    out = res.stdout + res.stderr
    m = re.search(r"(\d+)\s+passed", out)
    if not m:
        raise SystemExit("check-counts: could not parse hook test count from:\n" + out)
    return int(m.group(1))


def derive():
    cs, ca = collection_skills(), collection_agents()
    return {
        "judgment-skills": judgment_skills(),
        "collection-skills": cs,
        "collection-agents": ca,
        "collection-units": cs + ca,
        "hooks": hooks(),
        "hook-tests": hook_tests(),
    }


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode not in ("--check", "--write"):
        print(__doc__)
        return 2
    want = {k: str(v) for k, v in derive().items()}
    seen = set()
    problems = []
    text = open(README, encoding="utf-8").read()

    def sub(m):
        key, cur = m.group(2), m.group(3)
        seen.add(key)
        if key not in want:
            problems.append(f"README.md: unknown COUNT key '{key}'")
            return m.group(0)
        if cur != want[key]:
            if mode == "--check":
                problems.append(
                    f"README.md: COUNT {key} says '{cur}', tree has '{want[key]}'")
            return m.group(1) + want[key] + m.group(4)
        return m.group(0)

    new = COUNT_RE.sub(sub, text)

    def badge_sub(keys):
        def _repl(m):
            base = m.start()
            out, pos = [], base
            for i, key in enumerate(keys, start=1):
                cur, exp = m.group(i), want[key]
                out.append(m.string[pos:m.start(i)])
                out.append(exp)
                pos = m.end(i)
                if cur != exp and mode == "--check":
                    problems.append(
                        f"README.md: badge {key} shows '{cur}', tree has '{exp}'")
            out.append(m.string[pos:m.end()])
            return "".join(out)
        return _repl

    for rx, keys in BADGES:
        if not rx.search(new):
            problems.append(f"README.md: missing badge for {'/'.join(keys)}")
            continue
        new = rx.sub(badge_sub(keys), new)

    missing = sorted(set(want) - seen)
    if missing:
        problems.append("README.md: missing COUNT markers for: " + ", ".join(missing))

    if mode == "--write":
        if new != text:
            open(README, "w", encoding="utf-8").write(new)
            print("check-counts: markers written from tree.")
        else:
            print("check-counts: markers already match tree.")
        for p in problems:
            if "unknown COUNT" in p or "missing COUNT" in p:
                print("WARN:", p)
        return 0

    # --check
    if problems:
        print("check-counts: DRIFT")
        for p in problems:
            print("  -", p)
        return 1
    print("check-counts: OK — all README counts match the tree "
          + " ".join(f"{k}={v}" for k, v in want.items()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
