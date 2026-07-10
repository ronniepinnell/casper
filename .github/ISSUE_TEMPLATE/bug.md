---
name: Bug report
about: A skill or hook misbehaved
labels: bug
---

**Which skill or hook?** (e.g. `/refute`, `claim-evidence.sh`)

**What happened vs what you expected?**

**Transcript / command + output** (for hooks: the exact JSON you can reproduce with, e.g. `echo '{"tool_input":{"command":"git commit -m \"done\""}}' | .claude/hooks/claim-evidence.sh; echo $?`)

**Your `.claude/judgment.json`** (hooks only — redact globs if needed)

**Environment:** OS, Claude Code version, `bash --version`, `python3 --version`
