---
name: export-public
description: Drive the public export layer — the machinery that turns this private repo into the downstream public repos (casper, refute-action, the awesome-style skills collection, …). Use when asked to "export public skills", "publish my skills", "check public export drift", "sync the public repos", "make the free repo", or "update the public skills repo".
origin: authored
public: true
---

# Export Public — generate & publish the downstream public repos

`shared-config` is the **private upstream source of truth**. Every public repo is
**downstream, generated, and never hand-edited**. This skill drives
`scripts/export-public.py`, which reads `export/MANIFEST.json` (one entry per
public artifact) and keeps the generated trees honest.

Only `origin: authored` units are publishable. `imported-*`, `forked`, and
`uncertain` units must never leak (see `library/LICENSE_AUDIT.md`); the drift
gate enforces this mechanically.

## The one-way rule

Public repos are a **generated projection**, not a fork. You never edit a public
repo by hand. Improvements a user contributes upstream (a PR against the public
repo) come **back into shared-config via `/intake`**, stamped
`origin: community-contributed`, and are re-projected on the next `--sync`. Editing
the public repo directly is always wrong — the next sync overwrites it.

## Modes

```bash
python3 scripts/export-public.py --check            # CI drift gate (the point)
python3 scripts/export-public.py --sync             # regenerate vendored exports from source
python3 scripts/export-public.py --publish <name>   # print push plan (dry-run)
python3 scripts/export-public.py --publish <name> --force   # actually push
```

- **`--check`** — for every artifact, recompute what the export SHOULD contain
  from the manifest + current private sources and diff against the on-disk tree.
  Fails listing each stale / missing / extra unit, any file that still contains a
  `forbid` token, and any shipped unit that is not `origin: authored`. This is the
  cross-repo drift gate; it runs in CI (`.github/workflows/lint.yml`).
- **`--sync`** — rebuild each **vendored** export from source, applying scrub
  rules (rename map + lifecycle-skill token replacement → "your workflow's
  equivalent"), then run that export's own tests. It **refuses to leave a broken
  export** (restore + exit 1) and is **idempotent** (running twice = no diff). A
  converged tree is left untouched, so a concurrently-restructured export is not
  clobbered.
- **`--publish <artifact>`** — print the exact git commands (clone / rsync /
  commit / push) that would publish one artifact to its `target_repo`. Dry-run by
  default; `--force` executes. Never invents credentials — it uses your existing
  git auth.

## The manifest

`export/MANIFEST.json` (`_comment` documents the full schema) declares each
artifact and its kind:

- **vendored** (`casper`) — assembled from named private `skills`, `hooks`
  groups, and `docs`; scrub `rename`/`replace` applied on copy.
- **standalone** (`refute-action`, `verdict-viewer`, …) — the export tree *is*
  the source; `--check` only verifies it (forbid tokens, no non-authored units).
- **collection** (`public_collection`) — ships **all** `origin: authored` skills
  + agents (the awesome-style collection a companion agent materializes).

## Typical flows

- **CI / pre-PR:** `--check`. If it flags drift, `--sync` to converge, review the
  diff, commit.
- **Adding an authored skill to casper:** add its name to the `casper`
  artifact's `source.skills` in the manifest, `--sync`, `--check`.
- **Publishing:** `--publish casper` (read the plan), then `--publish casper
  --force` once you're sure. Publishing is irreversible — confirm first.

## Judgment weave (see /judgment)

- **"Sanitized" is a claim:** the `forbid` scan is mechanical, but before a
  `--force` publish run **`/refute`** — grep the export for project names, keys,
  and internal paths as if hunting for a leak. A green `--check` is necessary,
  not sufficient, for putting code on the public internet.
