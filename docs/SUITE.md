# The Casper Suite

Casper is one repo in a family. Everything below is free and MIT; the pieces
compose but none requires another.

| Piece | What it does | Where |
|---|---|---|
| **casper** (this repo) | 16 judgment skills + tested zero-LLM hooks + the verdict ledger | you are here |
| **refute-action** | The PR gate: reads done-claims on a PR, runs the stated evidence, posts CONFIRMED/UNVERIFIED as a check | github.com/ronniepinnell/refute-action |
| **casper-ledger-mcp** | MCP server over the verdicts ledger — query rulings from any MCP client | github.com/ronniepinnell/casper-ledger-mcp |
| **/backfill + badge** | Retro-grade merged PRs; publish your evidenced-dones % as a shields badge | `scripts/backfill.py --badge` |
| **report** | Monthly ledger digest: verdict mix, gate kill-counts, evidenced-dones trend | `scripts/report.py` |

## The loop these form

```
backfill        → your baseline ("you shipped N unproven dones")
hooks + skills  → the next PRs grade better
refute-action   → enforcement at the trust boundary (CI, not vibes)
badge           → the score, public
report          → the monthly trend; gates without kills get deleted
```

## Coming

- **Liveness check** — "merged" is not "live"; verify a done-claim at the
  layer users experience (see ROADMAP).
- **Suggested fixes** — the missing evidence command and the pinning test,
  posted as PR suggestions (claims lane only — code review is CodeRabbit's).
- **A hosted team layer** (ledger aggregation, org calibration, precedent
  packs) is in development — watch this repo.
