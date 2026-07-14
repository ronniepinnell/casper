#!/usr/bin/env python3
"""audit_skills.py — evidence-driven efficiency audit of the live skill library.

Measures FOUR axes per skill (no vibes — every claim carries a number):

  1. token cost      — size estimate (chars/4) of SKILL.md; the input-token
                       price paid every time the skill loads.
  2. bloat           — ceremony ratio: preamble before the first operative
                       section, duplicated boilerplate blocks shared verbatim
                       with other skills, and prose-per-procedure ratio.
  3. trigger quality — static flags on the frontmatter description (the only
                       text the harness matches against): missing "use when"
                       cue, too short/long, vague-only wording.
  4. overlap         — description+body shingle/Jaccard similarity clusters
                       (dependency-free; no embeddings).

Usage axes (dead-weight, trigger-precision) fold in ONLY if the telemetry log
exists (.claude/.judgment-state/skill-usage.jsonl, written by
hooks/telemetry/skill-usage.sh). Absent that file they are printed as
UNVERIFIED — fire counts are never guessed.

Usage:
  python3 audit_skills.py [--repo PATH] [--scope name,name,...] [--all]
                          [--json out.json] [--top N]

Default scope: the high-traffic lifecycle + judgment skills (the set that
loads constantly and where token efficiency compounds). Everything else is
reported as out-of-scope, not audited.

Exit 0 always (this is an auditor, not a gate — the gate lives in
scripts/lint-skills.py token-budget rule).
"""
import argparse
import glob
import json
import os
import re
import sys
from collections import defaultdict

DEFAULT_SCOPE = []  # empty -> audit every skill in the tree (use --scope to narrow)

OUT_OF_SCOPE_HINTS = re.compile(
    r"^(hockey-|nhl-|aspiring-|beer-league|upstash|vercel|supabase|roboflow|"
    r"posthog|trigger|modal|ollama|openrouter|langfuse|fastf1|duckdb|sred-)")

TELEMETRY_LOG = ".claude/.judgment-state/skill-usage.jsonl"

# Operative section heads — text before the first of these is "preamble"
OPERATIVE = re.compile(r"^## +(Invocation|Procedure|Phase|Usage|Steps|Commands)",
                       re.I | re.M)

VAGUE_ONLY = re.compile(
    r"^(helps?|assists?|handles?|manages?|supports?|provides?)\b", re.I)
TRIGGER_CUE = re.compile(
    r"\buse (when|for|before|after|at|whenever|monthly|to|during)\b"
    r"|\btrigger|\binvoke\b|\brun (when|before|after|on)\b", re.I)

WORD = re.compile(r"[a-z0-9']+")


def est_tokens(text):
    return len(text) // 4  # standard chars/4 heuristic; consistent across skills


def read_skill(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    lines = text.split("\n")
    fm, body = {}, text
    if lines and lines[0].strip() == "---":
        try:
            end = lines[1:].index("---") + 1
            for ln in lines[1:end]:
                m = re.match(r"^([A-Za-z_-]+):\s*(.*)$", ln)
                if m:
                    fm[m.group(1)] = m.group(2).strip().strip("\"'")
            body = "\n".join(lines[end + 1:])
        except ValueError:
            pass
    return text, fm, body


def shingles(text, k=4):
    words = WORD.findall(text.lower())
    return {" ".join(words[i:i + k]) for i in range(len(words) - k + 1)}


def jaccard(a, b):
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def preamble_ratio(body):
    """Chars of prose before the first operative section / total body chars."""
    m = OPERATIVE.search(body)
    if not m or not body:
        return 0.0
    return m.start() / len(body)


def duplicate_blocks(bodies):
    """Lines (non-trivial) appearing verbatim in >=3 skills → shared boilerplate.
    Returns {skill: dup_char_count}."""
    line_owners = defaultdict(set)
    for name, body in bodies.items():
        for ln in set(body.split("\n")):
            if len(ln.strip()) > 40:
                line_owners[ln].add(name)
    dup = defaultdict(int)
    for ln, owners in line_owners.items():
        if len(owners) >= 3:
            for o in owners:
                dup[o] += len(ln) + 1
    return dup


def trigger_flags(desc):
    flags = []
    if not desc:
        return ["no-description"]
    if len(desc) < 60:
        flags.append("too-short(<60ch)")
    if len(desc) > 1000:
        flags.append("too-long(>1000ch)")
    if VAGUE_ONLY.match(desc):
        flags.append("vague-opener")
    if not TRIGGER_CUE.search(desc):
        flags.append("no-use-when-cue")
    return flags


def self_contained(body):
    """Mirror of lint-skills.py rule 8: hard 'read X first' external deps."""
    rx = re.compile(
        r"(?i)\b(read|load|consult)\b[^.\n]{0,100}"
        r"(_shared/|MANUAL\.md|adapters/|project-context)[^.\n]{0,100}"
        r"\b(before|first|prerequisite|required|must)\b")
    return not any(rx.search(ln) for ln in body.split("\n"))


def load_telemetry(repo):
    p = os.path.join(repo, TELEMETRY_LOG)
    if not os.path.isfile(p):
        return None
    counts = defaultdict(int)
    for ln in open(p, encoding="utf-8", errors="replace"):
        try:
            row = json.loads(ln)
        except Exception:
            continue
        if row.get("skill") and row["skill"] != "__session_end__":
            counts[row["skill"]] += 1
    return dict(counts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    ap.add_argument("--scope", help="comma-separated skill names")
    ap.add_argument("--all", action="store_true",
                    help="audit every non-vendor skill dir")
    ap.add_argument("--json", dest="json_out")
    ap.add_argument("--top", type=int, default=10)
    ap.add_argument("--overlap-threshold", type=float, default=0.12)
    args = ap.parse_args()
    repo = os.path.abspath(args.repo)

    all_dirs = sorted(d for d in glob.glob(os.path.join(repo, "skills", "*/"))
                      if not os.path.basename(d.rstrip("/")).startswith("_")
                      and not os.path.islink(d.rstrip("/"))
                      and os.path.isfile(os.path.join(d, "SKILL.md")))
    all_names = [os.path.basename(d.rstrip("/")) for d in all_dirs]

    if args.scope:
        scope = [s.strip() for s in args.scope.split(",")]
    elif args.all:
        scope = [n for n in all_names if not OUT_OF_SCOPE_HINTS.match(n)]
    else:
        scope = ([s for s in DEFAULT_SCOPE if s in all_names]
                 or [n for n in all_names if not OUT_OF_SCOPE_HINTS.match(n)])

    out_of_scope = sorted(set(all_names) - set(scope))

    bodies, records = {}, {}
    for name in scope:
        p = os.path.join(repo, "skills", name, "SKILL.md")
        text, fm, body = read_skill(p)
        bodies[name] = body
        records[name] = {
            "skill": name,
            "bytes": len(text),
            "tokens_est": est_tokens(text),
            "lines": text.count("\n") + 1,
            "preamble_ratio": round(preamble_ratio(body), 3),
            "trigger_flags": trigger_flags(fm.get("description", "")),
            "self_contained": self_contained(body),
        }

    dup = duplicate_blocks(bodies)
    for name, rec in records.items():
        d = dup.get(name, 0)
        rec["dup_boilerplate_chars"] = d
        rec["dup_boilerplate_pct"] = round(100 * d / max(1, rec["bytes"]), 1)
        rec["bloat_pct"] = round(
            100 * (rec["preamble_ratio"] * 0.5 + d / max(1, rec["bytes"])), 1)

    # overlap clusters (pairwise Jaccard on 4-gram shingles)
    sh = {n: shingles(b) for n, b in bodies.items()}
    pairs = []
    names = sorted(bodies)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            j = jaccard(sh[a], sh[b])
            if j >= args.overlap_threshold:
                pairs.append({"a": a, "b": b, "jaccard": round(j, 3)})
    pairs.sort(key=lambda p: -p["jaccard"])
    cluster_of = {}
    for p in pairs:
        ca, cb = cluster_of.get(p["a"]), cluster_of.get(p["b"])
        c = ca or cb or f"C{len(set(cluster_of.values())) + 1}"
        cluster_of[p["a"]] = cluster_of[p["b"]] = c
    for name, rec in records.items():
        rec["overlap_cluster"] = cluster_of.get(name)

    # usage axes — real data or explicit UNVERIFIED
    tel = load_telemetry(repo)
    if tel is None:
        usage_status = ("UNVERIFIED — no telemetry log at " + TELEMETRY_LOG +
                        " (enable telemetry.enabled in .claude/judgment.json, "
                        "run for a week, re-audit)")
        for rec in records.values():
            rec["fires"] = None
    else:
        usage_status = f"telemetry loaded: {sum(tel.values())} invocations"
        for name, rec in records.items():
            rec["fires"] = tel.get(name, 0)

    ranked = sorted(records.values(), key=lambda r: -r["tokens_est"])
    total_tokens = sum(r["tokens_est"] for r in ranked)

    print(f"\naudit-skills — {len(ranked)} skills in scope, "
          f"{total_tokens:,} est. tokens total")
    print(f"usage axes (dead-weight, trigger-precision): {usage_status}")
    print(f"out-of-scope (reported, not audited): {len(out_of_scope)} skills\n")
    hdr = f"{'skill':<16}{'tokens':>8}{'bloat%':>8}{'dup%':>6}{'pre%':>6}" \
          f"{'fires':>7}  {'cluster':<8}{'flags'}"
    print(hdr)
    print("-" * len(hdr))
    for r in ranked:
        fires = "UNVER" if r["fires"] is None else str(r["fires"])
        print(f"{r['skill']:<16}{r['tokens_est']:>8}{r['bloat_pct']:>8}"
              f"{r['dup_boilerplate_pct']:>6}{round(100*r['preamble_ratio']):>6}"
              f"{fires:>7}  {r['overlap_cluster'] or '-':<8}"
              f"{','.join(r['trigger_flags']) or '-'}"
              f"{'' if r['self_contained'] else ' NOT-SELF-CONTAINED'}")

    if pairs:
        print("\noverlap pairs (4-gram Jaccard ≥ "
              f"{args.overlap_threshold}):")
        for p in pairs:
            print(f"  {p['a']} <-> {p['b']}: {p['jaccard']}")

    print(f"\ntop {args.top} token offenders (tighten candidates):")
    for r in ranked[:args.top]:
        print(f"  {r['skill']}: {r['tokens_est']} tok "
              f"({r['dup_boilerplate_chars']} dup chars)")

    if args.json_out:
        payload = {
            "scope": scope,
            "out_of_scope": out_of_scope,
            "total_tokens_est": total_tokens,
            "usage_status": usage_status,
            "skills": ranked,
            "overlap_pairs": pairs,
        }
        with open(args.json_out, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=1)
        print(f"\nJSON written: {args.json_out}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
