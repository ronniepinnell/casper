#!/usr/bin/env python3
"""backfill.py — run casper's claim-evidence discipline RETROACTIVELY over
merged PRs. Zero-LLM, gh-CLI only.

For each merged PR in the window, three mechanical reads:
  claim      — does the title/body claim completion (fix/done/works/…)?
  evidence   — does the body carry an `Evidence:` line, or did the PR change
               test files? (same two evidence paths as the claim-evidence hook)
  verdict    — EVIDENCED / UNEVIDENCED / NO-CLAIM

Output: a per-PR table, a summary score, and (with --ledger) append-only
BACKFILL rows for the verdicts ledger — every retro row is UNVERIFIED
(history can be graded, not re-run; never silently upgrade).

Usage:
  python3 scripts/backfill.py [--repo owner/name] [--since 2026-01-01] [--limit 100] [--ledger .claude/verdicts.log]

--since filters SERVER-side (gh search `merged:>=DATE`), so grading a huge
repo's recent window never pages thousands of old PRs; --limit stays as the
hard cap either way.

Exit 0 always: history is a report, not a gate. The gate is what you install
so the NEXT hundred PRs grade better.
"""
import argparse
import datetime
import json
import re
import subprocess
import sys

CLAIM_WORDS = ["fixed", "fixes", "fix", "done", "works", "working",
               "complete", "completed", "resolved", "resolves"]
CLAIM_RE = re.compile(r"\b(" + "|".join(CLAIM_WORDS) + r")\b", re.I)
EVIDENCE_RE = re.compile(r"\bEvidence:\s*\S+", re.I)
TEST_PATH_RE = re.compile(r"(^|/)(tests?|__tests__|spec)/|\.(test|spec)\.|_test\.")


def gh(args, repo=None):
    cmd = ["gh"] + args + (["-R", repo] if repo else [])
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        sys.exit(f"gh failed: {r.stderr.strip()[:200]}")
    return r.stdout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=None, help="owner/name (default: current)")
    ap.add_argument("--limit", type=int, default=100)
    ap.add_argument("--since", default=None,
                    help="only PRs merged on/after this date (YYYY-MM-DD); server-side filter")
    ap.add_argument("--badge", default=None,
                    help="write a shields.io endpoint JSON with the evidenced-dones score")
    ap.add_argument("--ledger", default=None,
                    help="append BACKFILL rows to this verdicts ledger")
    a = ap.parse_args()

    args = ["pr", "list", "--state", "merged", "--limit", str(a.limit),
            "--json", "number,title,body,mergedAt,files"]
    if a.since:
        args += ["--search", f"merged:>={a.since}"]
    prs = json.loads(gh(args, a.repo))
    rows, claims, evidenced = [], 0, 0
    for pr in prs:
        text = (pr.get("title") or "") + "\n" + (pr.get("body") or "")
        has_claim = bool(CLAIM_RE.search(text))
        has_evidence = bool(EVIDENCE_RE.search(text)) or any(
            TEST_PATH_RE.search(f.get("path", ""))
            for f in (pr.get("files") or []))
        if not has_claim:
            verdict = "NO-CLAIM"
        elif has_evidence:
            verdict = "EVIDENCED"
            claims += 1
            evidenced += 1
        else:
            verdict = "UNEVIDENCED"
            claims += 1
        rows.append((pr["number"], verdict,
                     (pr.get("mergedAt") or "")[:10], pr["title"][:70]))

    for n, v, d, title in rows:
        mark = {"EVIDENCED": "✓", "UNEVIDENCED": "✗", "NO-CLAIM": "·"}[v]
        print(f"  {mark} #{n:<6} {v:<12} {d}  {title}")

    pct = round(100 * evidenced / claims) if claims else 100
    summary = (f"BACKFILL: {a.repo or 'this repo'} | {len(prs)} merged PRs | "
               f"{claims} done-claims | {evidenced} evidenced ({pct}%) | "
               f"{claims - evidenced} shipped unproven")
    print("\n" + summary)

    if a.badge:
        color = ("brightgreen" if pct >= 90 else "green" if pct >= 75
                 else "yellow" if pct >= 50 else "red")
        with open(a.badge, "w", encoding="utf-8") as f:
            json.dump({"schemaVersion": 1, "label": "evidenced dones",
                       "message": f"{pct}% of {claims}", "color": color}, f)
        print(f"badge endpoint written to {a.badge} — serve it and embed:")
        print("  https://img.shields.io/endpoint?url=<public-url-to-that-json>")

    if a.ledger:
        today = datetime.date.today().isoformat()
        with open(a.ledger, "a", encoding="utf-8") as f:
            f.write(f"{today} | BACKFILL | UNVERIFIED | {summary} | "
                    f"retro grade — history can be graded, not re-run | by: casper-backfill\n")
            for n, v, d, title in rows:
                if v == "UNEVIDENCED":
                    f.write(f"{today} | BACKFILL | UNVERIFIED | PR #{n} ({d}) "
                            f"claimed done without evidence: {title} | by: casper-backfill\n")
        print(f"ledger rows appended to {a.ledger}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
