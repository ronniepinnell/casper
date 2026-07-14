#!/usr/bin/env bash
# Sandbox matrix for the round-4 additions: todo-debt.sh, doctor.sh, stats-lib.sh.
# Kept separate from test.sh (owned by the extraction workstream). Exit 0 = green.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP" && mkdir -p .claude
cp "$HERE"/{todo-debt.sh,stats-lib.sh} .

pass=0; failc=0
check() { # name expected actual
  if [ "$2" = "$3" ]; then pass=$((pass+1)); else failc=$((failc+1)); echo "FAIL: $1 (expected exit $2, got $3)"; fi
}
run() { echo "$2" | "./$1" >/dev/null 2>&1; echo $?; }

# --- todo-debt ---------------------------------------------------------------
git init -q .
# inert without config
check "todo inert" 0 "$(run todo-debt.sh '{"tool_input":{"command":"git commit -m \"fixed it\""}}')"

cat > .claude/judgment.json <<'EOF'
{ "todo_debt": { "enabled": true } }
EOF

# stage a diff that ADDS a TODO
printf 'def add(a, b):\n    # TODO: handle floats\n    return a + b\n' > calc.py
git add calc.py

check "todo block: claim + added TODO" 2 "$(run todo-debt.sh '{"tool_input":{"command":"git commit -m \"fix: calculator done\""}}')"
check "todo pass: no claim words"      0 "$(run todo-debt.sh '{"tool_input":{"command":"git commit -m \"wip: calculator\""}}')"
check "todo pass: non-commit command"  0 "$(run todo-debt.sh '{"tool_input":{"command":"ls -la"}}')"

# clean diff (no markers) + claim -> pass
git rm -q --cached calc.py; printf 'def add(a, b):\n    return a + b\n' > calc.py; git add calc.py
check "todo pass: claim + clean diff"  0 "$(run todo-debt.sh '{"tool_input":{"command":"git commit -m \"fix: calculator done\""}}')"

# disabled gate -> pass even with TODO staged
printf '# HACK: temp\n' >> calc.py; git add calc.py
cat > .claude/judgment.json <<'EOF'
{ "todo_debt": { "enabled": false } }
EOF
check "todo disabled" 0 "$(run todo-debt.sh '{"tool_input":{"command":"git commit -m \"done\""}}')"

# --- stats-lib ---------------------------------------------------------------
. ./stats-lib.sh
judgment_record_fire "claim_evidence" "fired"
judgment_record_fire "claim_evidence" "fired"
judgment_record_fire "todo_debt" "pass"
if grep -qc '"gate": "claim_evidence"' .claude/.judgment-state/stats.jsonl \
   && [ "$(grep -c '"gate": "claim_evidence"' .claude/.judgment-state/stats.jsonl)" = 2 ]; then
  pass=$((pass+1))
else
  failc=$((failc+1)); echo "FAIL: stats-lib records fires"
fi
if judgment_stats_summary | grep -q 'todo_debt'; then
  pass=$((pass+1))
else
  failc=$((failc+1)); echo "FAIL: stats summary renders"
fi

# --- doctor ------------------------------------------------------------------
# doctor runs from anywhere; here it should report FAILs (no wiring) -> exit 1
bash "$HERE/doctor.sh" > doctor-out.txt 2>&1
rc=$?
if [ "$rc" = 1 ] && grep -q 'judgment.json' doctor-out.txt; then
  pass=$((pass+1))
else
  failc=$((failc+1)); echo "FAIL: doctor flags unwired project (rc=$rc)"
fi

echo "additions matrix: $pass passed, $failc failed"
exit "$((failc > 0 ? 1 : 0))"
