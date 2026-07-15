#!/usr/bin/env python3
"""adoption.py — measure the roadmap's own kill-gates.

The casper roadmap declares adoption kill-gates (e.g. refute-action: <3
external repos within 90 days). A gate nobody measures is decoration — this
script IS the measurement. Zero-LLM, gh CLI.

Usage: python3 scripts/adoption.py [--owner ronniepinnell]
"""
import argparse
import json
import subprocess
import sys

def gh_json(args):
    r = subprocess.run(["gh"] + args, capture_output=True, text=True)
    return json.loads(r.stdout) if r.returncode == 0 and r.stdout.strip() else None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--owner", default="ronniepinnell")
    a = ap.parse_args()

    # 1. external repos using refute-action (code search)
    res = gh_json(["api", "-X", "GET", "search/code",
                   "-f", f"q={a.owner}/refute-action path:.github/workflows",
                   "--jq", "{total: .total_count, repos: [.items[].repository.full_name]}"])
    ext = []
    if res:
        ext = sorted({r for r in res.get("repos", [])
                      if not r.startswith(a.owner + "/")})
        print(f"refute-action: {res.get('total', 0)} workflow hits, "
              f"{len(ext)} external repo(s): {ext or '—'}")
    else:
        print("refute-action: UNVERIFIED (code search unavailable)")

    # 2. star/fork/watch counts across the suite
    for repo in ("casper", "refute-action", "casper-ledger-mcp"):
        d = gh_json(["api", f"repos/{a.owner}/{repo}",
                     "--jq", "{s:.stargazers_count,f:.forks_count,w:.subscribers_count}"])
        if d:
            print(f"{repo}: ★{d['s']} forks:{d['f']} watchers:{d['w']}")

    print(f"\nKILL-GATE (roadmap): refute-action <3 external repos in 90 days "
          f"of launch → currently {len(ext)} external. Measure weekly; "
          f"decide at day 90, not by feel.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
