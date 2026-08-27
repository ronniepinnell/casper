#!/usr/bin/env python3
"""Sandbox matrix for merge_train.classify — the adversarial-review evidence gate.

`adversarial-review:passed` is the only way a PR reaches SAFE without a real
approval. The rule "the label must carry an evidence comment"
lived in prose as a spot-check; these cases make it a gate. Exit 0 = all green.
"""
import os
import sys
import importlib.util

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location(
    "merge_train", os.path.join(HERE, "merge_train.py"))
mt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mt)

GREEN = [{"name": "ci", "conclusion": "SUCCESS"}]
LBL = lambda *n: [{"name": x} for x in n]
CMT = lambda *b: [{"body": x} for x in b]


def pr(**kw):
    base = {"statusCheckRollup": GREEN, "reviewDecision": "APPROVED",
            "mergeable": "MERGEABLE", "labels": LBL("autonomy:green"),
            "body": "", "comments": [], "baseRefName": "main"}
    base.update(kw)
    return base


passed = failed = 0


def check(name, want_safe, p):
    global passed, failed
    reasons = mt.classify(p, "main")
    ok = (not reasons) == want_safe
    if ok:
        passed += 1
    else:
        failed += 1
        print(f"FAIL: {name} — want {'SAFE' if want_safe else 'HELD'}, "
              f"got {reasons or 'SAFE'}")


# --- baseline: the five facts still behave -----------------------------------
check("approved+green is SAFE", True, pr())
check("no autonomy label HELD", False, pr(labels=[]))
check("red CI HELD", False, pr(statusCheckRollup=[{"name": "ci",
                                                   "conclusion": "FAILURE"}]))
check("conflict HELD", False, pr(mergeable="CONFLICTING"))
check("unacked override HELD", False, pr(body="JUDGMENT-OVERRIDE: x — y"))
check("acked override SAFE", True,
      pr(body="JUDGMENT-OVERRIDE: x — y",
         labels=LBL("autonomy:green", "override-acked")))

# --- the new gate ------------------------------------------------------------
NOAPP = dict(reviewDecision="REVIEW_REQUIRED")
check("unapproved, no label HELD", False, pr(**NOAPP))
check("label WITHOUT evidence comment HELD", False,
      pr(labels=LBL("autonomy:green", "adversarial-review:passed"), **NOAPP))
check("label + unrelated chatter HELD", False,
      pr(labels=LBL("autonomy:green", "adversarial-review:passed"),
         comments=CMT("lgtm!", "rebased on main"), **NOAPP))
check("label + word 'adversarial' but no evidence HELD", False,
      pr(labels=LBL("autonomy:green", "adversarial-review:passed"),
         comments=CMT("ran adversarial review, all good"), **NOAPP))
check("label + file:line findings SAFE", True,
      pr(labels=LBL("autonomy:green", "adversarial-review:passed"),
         comments=CMT("adversarial pass: scripts/foo.py:42 unchecked None"),
         **NOAPP))
check("label + documented no-findings phrase SAFE", True,
      pr(labels=LBL("autonomy:green", "adversarial-review:passed"),
         comments=CMT("adversarial pass: no blocking findings — checked "
                      "correctness, security, migrations"), **NOAPP))
check("evidence on a genuinely approved PR is irrelevant SAFE", True,
      pr(comments=CMT("adversarial pass: no blocking findings")))

print(f"merge-train classify: {passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
