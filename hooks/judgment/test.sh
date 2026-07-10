#!/usr/bin/env bash
# Sandbox matrix for the judgment hooks + promoted guards. Run after ANY hook edit.
# Asserts: block case exit=2, pass case exit=0, inert-without-config exit=0,
# scope-creep fires exactly once. Exit 0 = all green.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
GUARDS="$(cd "$HERE/../guards" && pwd)"
TELEMETRY="$(cd "$HERE/../telemetry" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP" && mkdir -p .claude
cp "$HERE"/{claim-evidence.sh,spec-citation.sh,scope-creep.sh} .
cp "$GUARDS"/{dangerous-git.sh,context-watchdog.sh,budget-log.sh} .
cp "$TELEMETRY/skill-usage.sh" .

pass=0; failc=0
check() { # name expected actual
  if [ "$2" = "$3" ]; then pass=$((pass+1)); else failc=$((failc+1)); echo "FAIL: $1 (expected exit $2, got $3)"; fi
}
run() { echo "$2" | "./$1" >/dev/null 2>&1; echo $?; }

# inert without config
check "claim inert" 0 "$(run claim-evidence.sh '{"tool_input":{"command":"git commit -m \"fixed it\""}}')"
check "git inert"   0 "$(run dangerous-git.sh '{"tool_input":{"command":"git push --force origin main"}}')"
check "watchdog inert" 0 "$(CLAUDE_CONTEXT_TOKENS=190000 CLAUDE_CONTEXT_MAX=200000 run context-watchdog.sh '{}')"
check "budget inert"   0 "$(run budget-log.sh '{"tool_name":"Bash"}')"
check "telemetry inert" 0 "$(run skill-usage.sh '{"tool_input":{"skill":"commit","args":"foo"}}')"

cp "$HERE/judgment.json.example" .claude/judgment.json

# guards are disabled-by-default in the example config
check "git disabled" 0 "$(run dangerous-git.sh '{"tool_input":{"command":"git push --force origin main"}}')"

# telemetry is disabled-by-default in the example config: exit 0, no log written
run skill-usage.sh '{"tool_input":{"skill":"commit","args":"foo"}}' >/dev/null
if [ ! -f .claude/.judgment-state/skill-usage.jsonl ]; then
  pass=$((pass+1))
else
  failc=$((failc+1)); echo "FAIL: telemetry disabled-by-default (log written while disabled)"
fi

# telemetry enabled: exit 0 and a JSONL row with the skill name (no arg contents) lands
python3 - <<'PY'
import json; c=json.load(open('.claude/judgment.json')); c['telemetry']['enabled']=True; json.dump(c,open('.claude/judgment.json','w'))
PY
run skill-usage.sh '{"tool_input":{"skill":"commit","args":"secret-args"}}' >/dev/null
if grep -q '"skill": "commit"' .claude/.judgment-state/skill-usage.jsonl 2>/dev/null \
   && ! grep -q 'secret-args' .claude/.judgment-state/skill-usage.jsonl; then
  pass=$((pass+1))
else
  failc=$((failc+1)); echo "FAIL: telemetry enabled append (row missing or args leaked)"
fi
python3 - <<'PY'
import json; c=json.load(open('.claude/judgment.json')); c['telemetry']['enabled']=False; json.dump(c,open('.claude/judgment.json','w'))
PY

# enable all guards for the block/pass matrix
python3 - <<'PY'
import json
c = json.load(open('.claude/judgment.json'))
for g in c['guards'].values():
    g['enabled'] = True
json.dump(c, open('.claude/judgment.json', 'w'))
PY

# dangerous-git
check "git block force"  2 "$(run dangerous-git.sh '{"tool_input":{"command":"git push --force origin feature"}}')"
check "git block reset"  2 "$(run dangerous-git.sh '{"tool_input":{"command":"cd /tmp && git reset --hard HEAD~3"}}')"
check "git block main"   2 "$(run dangerous-git.sh '{"tool_input":{"command":"git switch main"}}')"
check "git pass commit"  0 "$(run dangerous-git.sh '{"tool_input":{"command":"git commit -m \"do not force or reset --hard anything\""}}')"
check "git pass nongit"  0 "$(run dangerous-git.sh '{"tool_input":{"command":"rm -rf node_modules"}}')"

# context-watchdog: warn-only — always exit 0, warns to stderr at threshold
check "watchdog pass low"  0 "$(CLAUDE_CONTEXT_TOKENS=10000 CLAUDE_CONTEXT_MAX=200000 run context-watchdog.sh '{}')"
check "watchdog pass high" 0 "$(CLAUDE_CONTEXT_TOKENS=190000 CLAUDE_CONTEXT_MAX=200000 run context-watchdog.sh '{}')"
wd_err="$(CLAUDE_CONTEXT_TOKENS=190000 CLAUDE_CONTEXT_MAX=200000 sh -c 'echo "{}" | ./context-watchdog.sh 2>&1 >/dev/null')"
case "$wd_err" in *HANDOFF*) pass=$((pass+1));; *) failc=$((failc+1)); echo "FAIL: watchdog warns at 95%";; esac

# budget-log: exit 0 and a JSONL row lands in the log dir
check "budget pass" 0 "$(CLAUDE_CONTEXT_TOKENS=5000 CLAUDE_CONTEXT_MAX=200000 run budget-log.sh '{"tool_name":"Bash"}')"
if ls .claude/.judgment-state/cost-log/tool-cost-*.jsonl >/dev/null 2>&1 \
   && grep -q '"tool": "Bash"' .claude/.judgment-state/cost-log/tool-cost-*.jsonl; then
  pass=$((pass+1))
else
  failc=$((failc+1)); echo "FAIL: budget log row written"
fi

# claim-evidence
check "claim block" 2 "$(run claim-evidence.sh '{"tool_input":{"command":"git commit -m \"fixed the bug\""}}')"
check "claim pass"  0 "$(run claim-evidence.sh '{"tool_input":{"command":"git commit -m \"fixed bug. Evidence: pytest 12 passed\""}}')"

# spec-citation (example config protects schema/*)
check "spec block" 2 "$(run spec-citation.sh '{"tool_input":{"file_path":"schema/tables.sql"}}')"
touch .claude/.spec-cited
check "spec pass"  0 "$(run spec-citation.sh '{"tool_input":{"file_path":"schema/tables.sql"}}')"

# scope-creep: fire once at threshold, then stay silent
python3 - <<'PY'
import json; c=json.load(open('.claude/judgment.json')); c['scope_creep']['max_files']=2; json.dump(c,open('.claude/judgment.json','w'))
PY
rm -rf .claude/.judgment-state
run scope-creep.sh '{"tool_input":{"file_path":"f1.py"}}' >/dev/null
run scope-creep.sh '{"tool_input":{"file_path":"f2.py"}}' >/dev/null
check "creep fire"      2 "$(run scope-creep.sh '{"tool_input":{"file_path":"f3.py"}}')"
check "creep fire-once" 0 "$(run scope-creep.sh '{"tool_input":{"file_path":"f4.py"}}')"

echo "hook matrix: $pass passed, $failc failed"
exit "$((failc > 0 ? 1 : 0))"
