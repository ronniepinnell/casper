## What & why

<!-- One paragraph. Name the failure class if adding/changing a judgment artifact. -->

## Checklist

- [ ] `python3 scripts/lint.py` prints 0 problems
- [ ] `bash hooks/judgment/test.sh` all green
- [ ] Hook changes include BOTH a block case and a pass case in `test.sh`
- [ ] New hooks ship default-OFF (config-gated via `.claude/judgment.json`)
- [ ] Frontmatter carries `name:`, `description:`, `origin:` (+ `source:` if imported)
- [ ] Skill is self-contained (no external-skill refs without an "if your workflow has one" guard, no absolute paths, no personal/project names)
- [ ] `JUDGMENT-OVERRIDE:` line included if this contradicts any logged verdict, gate default, or prior ruling (see CONTRIBUTING.md)
