#!/usr/bin/env bash
# digest.sh — weekly judgment digest. Zero-LLM, bash + python3 only.
#
# Reads .claude/verdicts.log (the append-only ledger, grammar:
# `date | TYPE | verdict | detail… | by: <who>`) plus .claude/.judgment-state
# (scope-creep counters, skill-usage telemetry) and emits a markdown digest:
# gates fired, overrides, REFUTEs, escalations queued, streak stats.
#
#   ./scripts/digest.sh                    # last 7 days, markdown to stdout
#   ./scripts/digest.sh --since 30d        # last 30 days
#   ./scripts/digest.sh --since 2026-07-01 # explicit start date
#   ./scripts/digest.sh --ledger path/to/verdicts.log
#   ./scripts/digest.sh --badge badge.json # ALSO write shields.io endpoint
#                                          # JSON (see export/ledger-badge)
#
# GitHub Actions weekly cron (also shipped as examples/digest-action.yml):
#   on:
#     schedule: [{cron: '0 8 * * 1'}]   # Mondays 08:00 UTC
#   jobs:
#     digest:
#       runs-on: ubuntu-latest
#       steps:
#         - uses: actions/checkout@v4
#         - run: ./scripts/digest.sh --since 7d >> "$GITHUB_STEP_SUMMARY"
set -euo pipefail

LEDGER=".claude/verdicts.log"
STATE_DIR=".claude/.judgment-state"
QUEUE=".claude/escalation-queue.md"
SINCE="7d"
BADGE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --since) SINCE="$2"; shift ;;
    --since=*) SINCE="${1#--since=}" ;;
    --ledger) LEDGER="$2"; shift ;;
    --ledger=*) LEDGER="${1#--ledger=}" ;;
    --badge) BADGE="$2"; shift ;;
    --badge=*) BADGE="${1#--badge=}" ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

LEDGER="$LEDGER" STATE_DIR="$STATE_DIR" QUEUE="$QUEUE" SINCE="$SINCE" BADGE="$BADGE" \
python3 - <<'PY'
import datetime, json, os, re, sys

since_raw = os.environ["SINCE"]
today = datetime.date.today()
m = re.fullmatch(r"(\d+)d", since_raw)
if m:
    start = today - datetime.timedelta(days=int(m.group(1)))
else:
    start = datetime.date.fromisoformat(since_raw)

lines = []
try:
    with open(os.environ["LEDGER"], encoding="utf-8", errors="replace") as f:
        lines = [l.strip() for l in f if l.strip() and not l.startswith("#")]
except FileNotFoundError:
    pass

def parse(l):
    parts = [p.strip() for p in l.split("|")]
    m = re.match(r"\d{4}-\d{2}-\d{2}", parts[0])
    if not m or len(parts) < 2:
        return None
    return datetime.date.fromisoformat(m.group(0)), parts[1].upper(), l

rows = [r for r in (parse(l) for l in lines) if r]
window = [r for r in rows if r[0] >= start]

def sub(typ, pat=None):
    return [l for d, t, l in window
            if t == typ and (pat is None or re.search(pat, l, re.I))]

gates_tripped = sub("GATE", r"TRIPPED")
gates_override = sub("GATE", r"OVERRIDE")
gates_passed = sub("GATE", r"PASS")
refute_unv = sub("REFUTE", r"UNVERIFIED")
refute_ref = sub("REFUTE", r"\bREFUTED\b")
refute_conf = sub("REFUTE", r"CONFIRMED")
escal = sub("ESCALATE")
queued = [l for l in escal if "queued" in l.lower()]

# streak stats (whole ledger, not just the window)
all_overrides = [d for d, t, l in rows if t == "GATE" and "OVERRIDE" in l.upper()]
days_since_override = (today - max(all_overrides)).days if all_overrides else None
active_days = sorted({d for d, t, l in window})

# open escalation queue depth
open_q = 0
try:
    with open(os.environ["QUEUE"], encoding="utf-8") as f:
        open_q = len(re.findall(r"^###?\s*ESC-\d+", f.read(), re.M))
except FileNotFoundError:
    pass

# telemetry: top skills in window
skill_counts = {}
tpath = os.path.join(os.environ["STATE_DIR"], "skill-usage.jsonl")
try:
    with open(tpath, encoding="utf-8") as f:
        for l in f:
            try:
                row = json.loads(l)
            except ValueError:
                continue
            ts = str(row.get("ts", ""))[:10]
            try:
                if datetime.date.fromisoformat(ts) < start:
                    continue
            except ValueError:
                pass
            s = row.get("skill")
            if s:
                skill_counts[s] = skill_counts.get(s, 0) + 1
except FileNotFoundError:
    pass

print(f"# Judgment digest — {start} → {today}\n")
print(f"| Metric | Count |")
print(f"|---|---|")
print(f"| Verdicts logged | {len(window)} |")
print(f"| Gates tripped | {len(gates_tripped)} |")
print(f"| Gate overrides | {len(gates_override)} |")
print(f"| Gates passed | {len(gates_passed)} |")
print(f"| REFUTE: unverified | {len(refute_unv)} |")
print(f"| REFUTE: refuted | {len(refute_ref)} |")
print(f"| REFUTE: confirmed | {len(refute_conf)} |")
print(f"| Escalations queued | {len(queued)} |")
print(f"| Escalation queue open | {open_q} |")
print()
print("## Streaks")
print(f"- Days since last gate override: "
      f"{'never overridden' if days_since_override is None else days_since_override}")
print(f"- Active ledger days in window: {len(active_days)}")
print(f"- Ledger size (all time): {len(rows)} verdicts")
if gates_override:
    print("\n## Overrides this window (each one is a signed exception)")
    for l in gates_override:
        print(f"- `{l}`")
if refute_unv or refute_ref:
    print("\n## Claims that failed verification")
    for l in refute_unv + refute_ref:
        print(f"- `{l}`")
if queued:
    print("\n## Escalations queued")
    for l in queued:
        print(f"- `{l}`")
if skill_counts:
    print("\n## Skill usage (telemetry)")
    for s, n in sorted(skill_counts.items(), key=lambda kv: -kv[1])[:10]:
        print(f"- {s}: {n}")

# --badge: shields.io endpoint JSON (same schema as export/ledger-badge)
badge = os.environ["BADGE"]
if badge:
    if not rows:
        msg, color = "no ledger", "lightgrey"
    elif days_since_override is None:
        msg, color = f"{len(rows)} verdicts · 0 overrides", "brightgreen"
    else:
        d = days_since_override
        msg = f"{len(rows)} verdicts · {d}d since override"
        color = "brightgreen" if d > 30 else "yellow" if d > 7 else "orange"
    json.dump({"schemaVersion": 1, "label": "judgment ledger",
               "message": msg, "color": color}, open(badge, "w"))
    print(f"\n(badge JSON written to {badge})", file=sys.stderr)
PY
