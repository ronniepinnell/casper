#!/bin/bash
# casper demo: claim-evidence.sh blocks a "done" commit with no evidence,
# passes once evidence is in the message. Run from the repo root: ./demo/fake-done.sh
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO=$(mktemp -d); cd "$DEMO"
git init -q demo-project && cd demo-project
mkdir -p .claude
cat > .claude/judgment.json <<'EOF'
{ "claim_evidence": { "enabled": true } }
EOF
cp "$REPO/hooks/judgment/claim-evidence.sh" .claude/
echo 'def add(a, b): return a + b' > calc.py
git add -A
echo '$ git commit -m "fix: calculator done, all tests pass"'
# Simulate the PreToolUse hook invocation exactly as Claude Code fires it
echo '{"tool_input":{"command":"git commit -m \"fix: calculator done, all tests pass\""}}' \
  | bash .claude/claim-evidence.sh && echo "COMMIT ALLOWED" || echo "✗ BLOCKED: done-claim with no test evidence"
sleep 2
echo
echo '$ python3 -m pytest -q  # actually run the tests this time'
python3 -c "import calc; assert calc.add(2,2)==4; print('1 passed in 0.01s')"
echo
echo '$ git commit -m "fix: calculator done. Evidence: pytest 1 passed"'
echo '{"tool_input":{"command":"git commit -m \"fix: calculator done. Evidence: pytest 1 passed\""}}' \
  | bash .claude/claim-evidence.sh && echo "✓ COMMIT ALLOWED — evidence present"
