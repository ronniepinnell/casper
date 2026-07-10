#!/usr/bin/env python3
"""Skills lint: frontmatter + self-containedness.

Rules (CONTRIBUTING.md, authoring rule 6-7):
  1. Every skills/<dir>/SKILL.md exists, has frontmatter with name: matching
     the directory, a non-empty description:, and an origin: field.
  2. Self-containedness: a SKILL.md (or any .md shipped with a skill) may
     reference /commands only for skills that exist in this repo, unless the
     reference sits on a line with an explicit guard phrase
     ("if present", "if your workflow", "where present", "if it exists").
  3. Banned tokens: absolute user paths, personal/project names, and
     references to the private source repo.

Exit 0 with "0 problems" when clean; exit 1 listing every violation.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKILLS = os.path.join(ROOT, "skills")
COLLECTION = os.path.join(ROOT, "collection")

BANNED = [
    r"benchsight", r"upice", r"BEN-\d", r"Operator-history", r"fable-queue",
    r"claude-config", r"/Users/[a-zA-Z]", r"~/Documents", r"Programming_HD",
]
GUARDS = ["if present", "if your workflow", "where present", "if it exists",
          "if one is available", "if your harness"]
# Slash-commands that are NOT skills in this repo but are core/built-in or
# generic placeholders allowed in prose.
ALLOW_COMMANDS = {"plugin", "bug", "clear", "config", "help", "handoff", "loop"}

def skill_dirs():
    return sorted(d for d in os.listdir(SKILLS)
                  if os.path.isdir(os.path.join(SKILLS, d)))

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

def validate_collection(problems):
    """collection/ units: each has public:true + origin:authored, is listed in
    exactly one category README table, and contains no banned tokens."""
    if not os.path.isdir(COLLECTION):
        return 0
    n_units = 0
    all_rows = {}  # name -> [categories it is tabled in]
    for cat in sorted(os.listdir(COLLECTION)):
        cdir = os.path.join(COLLECTION, cat)
        if not os.path.isdir(cdir):
            continue
        readme = os.path.join(cdir, "README.md")
        if not os.path.isfile(readme):
            problems.append(f"collection/{cat}: missing README.md")
            rows = []
        else:
            rows = re.findall(r"^\|\s*`([^`]+)`\s*\|", open(readme, encoding="utf-8").read(), re.M)
        for nm in rows:
            all_rows.setdefault(nm, []).append(cat)

        units = []  # (name, primary_file)
        for entry in sorted(os.listdir(cdir)):
            p = os.path.join(cdir, entry)
            if os.path.isdir(p) and os.path.isfile(os.path.join(p, "SKILL.md")):
                units.append((entry, os.path.join(p, "SKILL.md")))
            elif entry.endswith(".md") and entry != "README.md":
                units.append((entry[:-3], p))
        for name, primary in units:
            n_units += 1
            fm = frontmatter(open(primary, encoding="utf-8").read())
            if fm.get("public") != "true":
                problems.append(f"collection/{cat}/{name}: missing 'public: true'")
            if fm.get("origin") != "authored":
                problems.append(f"collection/{cat}/{name}: origin must be 'authored' (got {fm.get('origin')!r})")

        # table rows must match the units present, exactly once each
        unit_names = sorted(n for n, _ in units)
        if sorted(rows) != unit_names:
            problems.append(
                f"collection/{cat}/README.md table {sorted(rows)} "
                f"!= units present {unit_names}")

    # banned-token scan across every .md under collection/
    for base, _, files in os.walk(COLLECTION):
        for f in files:
            if not f.endswith(".md"):
                continue
            p = os.path.join(base, f)
            rel = os.path.relpath(p, ROOT)
            for n, line in enumerate(open(p, encoding="utf-8"), 1):
                for pat in BANNED:
                    if re.search(pat, line, re.I):
                        problems.append(f"{rel}:{n}: banned token /{pat}/")

    for nm, cats in all_rows.items():
        if len(set(cats)) > 1:
            problems.append(f"collection unit '{nm}' tabled in multiple categories: {sorted(set(cats))}")
    return n_units


def main():
    problems = []
    dirs = skill_dirs()
    known = set(dirs)

    for d in dirs:
        path = os.path.join(SKILLS, d, "SKILL.md")
        if not os.path.isfile(path):
            problems.append(f"{d}: missing SKILL.md")
            continue
        text = open(path, encoding="utf-8").read()
        fm = frontmatter(text)
        if fm.get("name") != d:
            problems.append(f"{d}/SKILL.md: frontmatter name '{fm.get('name')}' != dir '{d}'")
        if not fm.get("description"):
            problems.append(f"{d}/SKILL.md: missing/empty description")
        if fm.get("origin") not in ("authored", "imported", "forked"):
            problems.append(f"{d}/SKILL.md: origin must be authored/imported/forked (got {fm.get('origin')!r})")

    # scan every md shipped under skills/ for banned tokens + unknown commands
    for base, _, files in os.walk(SKILLS):
        for f in files:
            if not f.endswith(".md"):
                continue
            p = os.path.join(base, f)
            rel = os.path.relpath(p, ROOT)
            for n, line in enumerate(open(p, encoding="utf-8"), 1):
                low = line.lower()
                for pat in BANNED:
                    if re.search(pat, line, re.I):
                        problems.append(f"{rel}:{n}: banned token /{pat}/")
                if any(g in low for g in GUARDS):
                    continue  # guarded line: external refs allowed
                for cmd in re.findall(r"`/([a-z][a-z0-9_-]{2,})", line):
                    if cmd not in known and cmd not in ALLOW_COMMANDS:
                        problems.append(
                            f"{rel}:{n}: references `/{cmd}` which is not a skill "
                            f"in this repo (guard it with 'if your workflow has one' or remove)")

    n_units = validate_collection(problems)

    if problems:
        print(f"{len(problems)} problems:")
        for p in problems:
            print("  " + p)
        return 1
    print(f"0 problems ({len(dirs)} judgment skills + {n_units} collection units checked)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
