# Rename checklist

The working name is **casper**. The name is deliberately concentrated; to
rename, grep-replace `casper`/`Casper` (case-sensitive both ways) in:

1. `README.md` — title, pitch line, badges, clone URL, install examples
2. `MANUAL.md` — title line only
3. `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — `name`, `description`, repo URL
4. `install.sh` / `uninstall.sh` — `TOOLKIT_NAME` variable (single place)
5. `LAUNCH.md` — every mention (post draft, HN titles, awesome-list blurb)
6. `ROADMAP.md` / `CONTRIBUTING.md` — title lines
7. `demo/README.md` and `demo/fake-done.sh` banner line
8. `scripts/init.sh` — `TOOLKIT_NAME` variable + header comment
9. `ledger-badge/README.md` (companion repo) — the digest cross-reference
   mentions the casper repo by name
10. The GitHub repo/org name itself + badge URLs in README

Skill files (`skills/*/SKILL.md`) and hooks are intentionally name-free —
they never mention the brand, so no changes needed there.

Before committing to a new name: re-run the passive screens (GitHub user+repo,
npm, PyPI, .dev/.sh/.io DNS, trademark web search) — see the naming research
note that chose casper (runner-ups: probandi, showcause).
