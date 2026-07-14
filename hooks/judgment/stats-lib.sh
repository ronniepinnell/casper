#!/usr/bin/env bash
# stats-lib.sh — opt-in, strictly-LOCAL gate telemetry (F8).
# Not a hook: a sourceable library. A gate that wants fire-counts adds, right
# before its exit-2 block message:
#
#   . "$(dirname "$0")/stats-lib.sh" 2>/dev/null || true
#   judgment_record_fire "claim_evidence" "fired"    # or "override"/"pass"
#
# Records land in .claude/.judgment-state/stats.jsonl — one JSON line per
# event, no command contents, nothing leaves the machine. /calibrate reads
# this to make "delete gates that never catch anything" empirical.
#
# judgment_stats_summary prints per-gate counts.

JUDGMENT_STATS_FILE="${JUDGMENT_STATS_FILE:-.claude/.judgment-state/stats.jsonl}"

judgment_record_fire() { # gate outcome
  local gate="${1:-unknown}" outcome="${2:-fired}"
  mkdir -p "$(dirname "$JUDGMENT_STATS_FILE")" 2>/dev/null || return 0
  printf '{"ts": "%s", "gate": "%s", "outcome": "%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$gate" "$outcome" \
    >> "$JUDGMENT_STATS_FILE" 2>/dev/null || true
  return 0  # telemetry must never affect the gate's exit code
}

judgment_stats_summary() {
  [ -f "$JUDGMENT_STATS_FILE" ] || { echo "no stats recorded"; return 0; }
  python3 - "$JUDGMENT_STATS_FILE" <<'PY'
import collections, json, sys
c = collections.Counter()
for line in open(sys.argv[1]):
    try:
        r = json.loads(line)
        c[(r.get("gate", "?"), r.get("outcome", "?"))] += 1
    except json.JSONDecodeError:
        pass
print(f"{'gate':<20}{'outcome':<12}{'count':>5}")
for (gate, outcome), n in sorted(c.items()):
    print(f"{gate:<20}{outcome:<12}{n:>5}")
PY
}
