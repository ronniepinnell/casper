#!/usr/bin/env python3
"""report.py — the monthly casper report: digest the verdicts ledger.

Reads an append-only verdicts.log and prints what a team lead actually wants:
claims graded, evidenced rate, gates fired (kill counts!), verdict mix by
TYPE, and the month-over-month trend of the backfill score if BACKFILL rows
exist. Zero-LLM. The badge acquires users; this keeps them.

Usage: python3 scripts/report.py [.claude/verdicts.log] [--month YYYY-MM]
"""
import re
import sys
from collections import Counter, defaultdict

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    month = None
    for i, a in enumerate(sys.argv):
        if a == "--month" and i + 1 < len(sys.argv):
            month = sys.argv[i + 1]
    path = args[0] if args else ".claude/verdicts.log"
    try:
        lines = [l.strip() for l in open(path, encoding="utf-8", errors="replace")
                 if l.strip() and not l.startswith("#")]
    except OSError:
        sys.exit(f"no ledger at {path} — nothing to report (that IS the report)")

    by_type, verdicts, months = Counter(), Counter(), defaultdict(Counter)
    backfill_scores = []
    for l in lines:
        parts = [p.strip() for p in l.split("|")]
        if len(parts) < 3:
            continue
        date, typ, verdict = parts[0], parts[1].upper(), parts[2]
        if month and not date.startswith(month):
            continue
        by_type[typ] += 1
        verdicts[verdict.split()[0].upper() if verdict else "?"] += 1
        months[date[:7]][typ] += 1
        if typ == "BACKFILL":
            m = re.search(r"(\d+) evidenced \((\d+)%\)", l)
            if m:
                backfill_scores.append((date, int(m.group(2))))

    scope = f" ({month})" if month else ""
    print(f"casper report{scope} — {sum(by_type.values())} ledger rows\n")
    print("by type:")
    for t, n in by_type.most_common():
        print(f"  {t:<12} {n}")
    print("\nverdict mix:")
    for v, n in verdicts.most_common(8):
        print(f"  {v:<12} {n}")
    gates = by_type.get("GATE", 0)
    print(f"\ngates: {gates} rows — a gate with no rows this period has a "
          f"kill count of zero: sharpen or delete it.")
    if backfill_scores:
        print("\nevidenced-dones trend (BACKFILL rows):")
        for d, s in backfill_scores[-6:]:
            print(f"  {d}  {s}%")
    return 0

if __name__ == "__main__":
    sys.exit(main())
