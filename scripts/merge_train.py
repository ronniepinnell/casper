#!/usr/bin/env python3
"""merge_train.py — mechanical safe-merge scan/execute for open PRs.

The judgment is banked here once; any model (or cron) executes it. A PR is
SAFE to merge unattended only if ALL of:
  1. CI green            — every status check SUCCESS/NEUTRAL/SKIPPED
  2. approved            — reviewDecision == APPROVED
  3. mergeable           — no conflicts
  4. autonomy label      — carries `autonomy:green` (the Operator's standing
                           pre-approval; absence means "wait for a human")
  5. declared overrides  — any `JUDGMENT-OVERRIDE:` marker in the body must be
                           matched by an `override-acked` label (declared AND
                           adjudicated; see CLAUDE.md judgment override rule)

Everything else is REPORTED, never merged. Default is a dry-run report;
--execute merges the SAFE set base-order-first (PRs targeting the default
branch before stacked PRs) with `gh pr merge --squash`.

Usage:
  python3 scripts/merge_train.py [--execute] [--target main] [--json out.json]

Exit 0 on success (even with 0 safe PRs); 1 on any merge failure.
"""
import argparse
import json
import re
import subprocess
import sys


def gh(args):
    r = subprocess.run(["gh"] + args, capture_output=True, text=True)
    if r.returncode:
        raise SystemExit(f"gh {' '.join(args)} failed: {r.stderr.strip()}")
    return r.stdout


def classify(pr, target):
    reasons = []
    checks = pr.get("statusCheckRollup") or []
    bad = [c for c in checks
           if (c.get("conclusion") or c.get("state") or "").upper()
           not in ("SUCCESS", "NEUTRAL", "SKIPPED")]
    if bad:
        reasons.append("ci-not-green: " +
                       ", ".join(c.get("name") or c.get("context", "?")
                                 for c in bad[:3]))
    if not checks:
        reasons.append("no-ci-checks")
    if pr.get("reviewDecision") != "APPROVED":
        reasons.append(f"not-approved ({pr.get('reviewDecision') or 'none'})")
    if pr.get("mergeable") == "CONFLICTING":
        reasons.append("merge-conflict")
    labels = {l["name"] for l in pr.get("labels", [])}
    if "autonomy:green" not in labels:
        reasons.append("no-autonomy:green-label")
    if re.search(r"JUDGMENT-OVERRIDE:", pr.get("body") or "") \
            and "override-acked" not in labels:
        reasons.append("judgment-override-unacked")
    return reasons


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--execute", action="store_true",
                    help="merge the SAFE set (default: dry-run report)")
    ap.add_argument("--target", default="main")
    ap.add_argument("--json", dest="json_out")
    args = ap.parse_args()

    prs = json.loads(gh(["pr", "list", "--state", "open", "--json",
                         "number,title,labels,reviewDecision,mergeable,"
                         "statusCheckRollup,baseRefName,headRefName,body"]))
    safe, held = [], []
    for pr in prs:
        reasons = classify(pr, args.target)
        (held if reasons else safe).append((pr, reasons))

    # base-order: PRs targeting the default branch merge before stacked PRs
    safe.sort(key=lambda t: (t[0]["baseRefName"] != args.target,
                             t[0]["number"]))

    print(f"merge-train — {len(prs)} open PR(s): "
          f"{len(safe)} SAFE, {len(held)} held")
    for pr, _ in safe:
        print(f"  SAFE #{pr['number']} ({pr['baseRefName']}←"
              f"{pr['headRefName']}) {pr['title']}")
    for pr, reasons in held:
        print(f"  HELD #{pr['number']} {pr['title']}")
        for r in reasons:
            print(f"       - {r}")

    failures = 0
    merged = []
    if args.execute:
        for pr, _ in safe:
            r = subprocess.run(["gh", "pr", "merge", str(pr["number"]),
                                "--squash"], capture_output=True, text=True)
            ok = r.returncode == 0
            failures += 0 if ok else 1
            merged.append({"number": pr["number"], "ok": ok,
                           "err": r.stderr.strip() if not ok else ""})
            print(f"  {'MERGED' if ok else 'FAILED'} #{pr['number']}"
                  + ("" if ok else f" — {r.stderr.strip()}"))

    if args.json_out:
        json.dump({"safe": [p["number"] for p, _ in safe],
                   "held": [{"number": p["number"], "reasons": rs}
                            for p, rs in held],
                   "merged": merged, "executed": args.execute},
                  open(args.json_out, "w"), indent=1)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
