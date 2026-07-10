#!/usr/bin/env bash
# casper share — turn your verdict ledger into a copy-pasteable brag line.
#
#   ./scripts/share.sh            # reads ./.claude/verdicts.log
#   ./scripts/share.sh --global   # reads ~/.claude/verdicts.log
#   ./scripts/share.sh path/to/verdicts.log
#
# Computes REAL stats from the append-only ledger and prints one shareable line:
#
#   👻 Casper caught a fake 'done' — 3rd this week. 2 gate overrides, 0 in 6 days.
#
# No fabrication: every number comes from grep/awk over the actual log.
set -uo pipefail

LEDGER="$(pwd)/.claude/verdicts.log"
if [ "${1:-}" = "--global" ]; then
  LEDGER="$HOME/.claude/verdicts.log"
elif [ -n "${1:-}" ]; then
  LEDGER="$1"
fi

if [ ! -f "$LEDGER" ]; then
  echo "casper share: no ledger at $LEDGER — nothing to share yet." >&2
  echo "(run some /refute and /gate checks first; they append verdicts here)" >&2
  exit 1
fi

# Ledger line grammar:  date | TYPE | verdict | detail… | by: who
# Dates are ISO (YYYY-MM-DD). Compute counts with awk over real lines only.
python3 - "$LEDGER" <<'PY'
import sys, datetime, re

path = sys.argv[1]
today = datetime.date.today()

def parse_date(line):
    m = re.match(r"\s*(\d{4}-\d{2}-\d{2})", line)
    if not m:
        return None
    try:
        return datetime.date.fromisoformat(m.group(1))
    except ValueError:
        return None

refutes_week = 0        # REFUTED verdicts in the last 7 days ("fake done" caught)
refutes_total = 0
overrides_total = 0     # GATE ... OVERRIDE (a human accepted risk)
last_override = None
gate_days = set()       # days on which any GATE fired

for raw in open(path, encoding="utf-8", errors="replace"):
    line = raw.rstrip("\n")
    if "|" not in line:
        continue
    d = parse_date(line)
    up = line.upper()
    if "REFUTE" in up and "REFUTED" in up:
        refutes_total += 1
        if d and (today - d).days < 7:
            refutes_week += 1
    if "GATE" in up:
        if d:
            gate_days.add(d)
        if "OVERRIDE" in up:
            overrides_total += 1
            if d and (last_override is None or d > last_override):
                last_override = d

# "N days since last override" — the streak you actually want to brag about.
if last_override is not None:
    since = (today - last_override).days
    override_streak = f"{overrides_total} gate override{'s' if overrides_total != 1 else ''}, 0 in {since} day{'s' if since != 1 else ''}."
elif overrides_total:
    override_streak = f"{overrides_total} gate override{'s' if overrides_total != 1 else ''}."
else:
    override_streak = "0 gate overrides — clean."

def ordinal(n):
    if 10 <= n % 100 <= 20:
        suf = "th"
    else:
        suf = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
    return f"{n}{suf}"

if refutes_week:
    catch = f"Casper caught a fake 'done' — {ordinal(refutes_week)} this week."
elif refutes_total:
    catch = f"Casper has caught {refutes_total} fake 'done'{'s' if refutes_total != 1 else ''} so far."
else:
    catch = "Casper is watching my commits — no fake 'done' has slipped through yet."

print(f"👻 {catch} {override_streak}")
PY
