#!/usr/bin/env python3
"""wave.py — deterministic helper for the /wave skill.

Handles the parts that must NOT depend on the model remembering: persisting the
planned wave, looking up a slot by number, and resolving/validating the routed
model (so `/wave run slot N` dispatches at the right tier by construction).

Stdlib only. State lives at $PWD/.claude/.wave-current.json (per-project).

Commands
--------
  wave.py save            < plan.json      # persist a planned wave (stdin = JSON array)
  wave.py list                             # summarize the persisted wave
  wave.py slot N                           # print slot N; exit 3 if gated, 4 if missing
  wave.py model <routed> [--current C]     # resolve routed model → CLI id + dispatch mode

Commands (cont.)
  wave.py next                             # next ready slot: pending, deps met, not gated, no file-conflict with in-flight
  wave.py mark N <status>                  # set slot status: dispatched|merged|failed|cancelled
  wave.py abort                            # mark every pending slot cancelled (kill switch)

Slot schema (each element of the saved array):
  {"slot": 1, "id": "APP-1234", "model": "opus", "gated": false,
   "after": [],            # slot numbers that must be status=merged before this dispatches
   "touches": [],          # path globs this slot writes — non-interference: `next` won't hand out
                           #   a slot whose touches overlap a currently-dispatched slot (auto-serialize)
   "status": "pending",    # pending|dispatched|merged|failed|cancelled  (managed by mark/abort)
   "why": "one-liner", "prompt": "/epic start APP-1234\n..."}
"""
from __future__ import annotations
import argparse, json, os, sys

STATE = os.path.join(os.getcwd(), ".claude", ".wave-current.json")

# routed name -> (CLI model id, is_claude). Non-Claude routes go through /brief.
MODELS = {
    "opus":   ("claude-opus-4-8", True),
    "sonnet": ("claude-sonnet-5", True),
    "haiku":  ("claude-haiku-4-5-20251001", True),
    "fable":  ("claude-fable-5", True),
    "codex":  ("gpt-4.1", False),
    "gemini": ("gemini-2.5-pro", False),
    "ollama": ("qwen3:32b", False),
    "cursor": ("cursor", False),
}
# tokens that force a slot to be CEO-gated regardless of the plan's gated flag
GATED_TOKENS = ("autonomy:red", "destructive", "migration", "safe_db_push", "cutover-execute")


def _load() -> list:
    if not os.path.exists(STATE):
        return []
    with open(STATE) as f:
        return json.load(f)


def _is_gated(slot: dict) -> bool:
    if slot.get("gated"):
        return True
    blob = json.dumps(slot).lower()
    return any(tok in blob for tok in GATED_TOKENS)


def _glob_head(g: str) -> str:
    """Non-wildcard directory prefix of a path glob, e.g. 'a/b/c/*.ts' -> 'a/b/c'."""
    head = []
    for seg in g.split("/"):
        if any(c in seg for c in "*?["):
            break
        head.append(seg)
    return "/".join(head)


def _touches_conflict(a: list, b: list) -> bool:
    """Two slots conflict if any touch-prefix of one is a prefix of the other (either way)."""
    ha, hb = [_glob_head(x) for x in (a or [])], [_glob_head(x) for x in (b or [])]
    for x in ha:
        for y in hb:
            if x and y and (x == y or x.startswith(y + "/") or y.startswith(x + "/")):
                return True
    return False


def cmd_save(_args) -> int:
    raw = sys.stdin.read()
    try:
        plan = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"wave: invalid JSON on stdin: {e}", file=sys.stderr)
        return 2
    if not isinstance(plan, list):
        print("wave: plan must be a JSON array of slot objects", file=sys.stderr)
        return 2
    for i, s in enumerate(plan, 1):
        s.setdefault("slot", i)
        if "id" not in s or "model" not in s:
            print(f"wave: slot {s.get('slot')} missing id/model", file=sys.stderr)
            return 2
        if s["model"] not in MODELS:
            print(f"wave: slot {s.get('slot')} unknown model '{s['model']}' "
                  f"(known: {', '.join(MODELS)})", file=sys.stderr)
            return 2
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w") as f:
        json.dump(plan, f, indent=2)
    gated = sum(1 for s in plan if _is_gated(s))
    print(f"wave: saved {len(plan)} slots ({gated} CEO-gated) → {STATE}")
    return 0


def cmd_list(_args) -> int:
    plan = _load()
    if not plan:
        print("wave: no persisted plan (run /wave plan first)")
        return 4
    for s in plan:
        cli, is_claude = MODELS[s["model"]]
        flag = "  ⛔ GATED" if _is_gated(s) else ""
        route = "" if is_claude else "  (→ /brief, non-Claude)"
        print(f"  Slot {s['slot']:>2} · {s['id']:<10} · {s['model']:<7}{route}{flag}  {s.get('why','')[:60]}")
    return 0


def cmd_slot(args) -> int:
    plan = _load()
    match = [s for s in plan if str(s.get("slot")) == str(args.n)]
    if not match:
        print(f"wave: slot {args.n} not found (have {len(plan)} slots; run /wave plan)", file=sys.stderr)
        return 4
    slot = match[0]
    slot = dict(slot)
    slot["gated"] = _is_gated(slot)
    slot["cli_model"], slot["is_claude"] = MODELS[slot["model"]]
    print(json.dumps(slot, indent=2))
    if slot["gated"]:
        print(f"wave: slot {args.n} is CEO-gated — refuse to auto-dispatch; "
              f"surface for manual trigger.", file=sys.stderr)
        return 3
    return 0


def cmd_next(_args) -> int:
    """Next dispatchable slot: pending, not gated, and all `after` deps merged."""
    plan = _load()
    if not plan:
        print("wave: no persisted plan (run /wave plan first)", file=sys.stderr)
        return 4
    by_slot = {s.get("slot"): s for s in plan}
    inflight = [s for s in plan if s.get("status") == "dispatched"]
    for s in sorted(plan, key=lambda x: x.get("slot", 0)):
        if s.get("status", "pending") != "pending" or _is_gated(s):
            continue
        deps = s.get("after", []) or []
        if not all(by_slot.get(d, {}).get("status") == "merged" for d in deps):
            continue
        # non-interference: don't hand out a slot that writes files an in-flight slot writes
        if any(_touches_conflict(s.get("touches"), f.get("touches")) for f in inflight):
            continue
        s = dict(s); s["cli_model"], s["is_claude"] = MODELS[s["model"]]
        print(json.dumps(s, indent=2))
        return 0
    waiting = [s.get("slot") for s in plan
               if s.get("status", "pending") == "pending" and not _is_gated(s)]
    if waiting:
        print(f"wave: no slot ready now — {len(waiting)} held on deps or file-conflict "
              f"with in-flight: {waiting}", file=sys.stderr)
        return 5
    print("wave: all non-gated slots dispatched or merged.", file=sys.stderr)
    return 6


def cmd_abort(_args) -> int:
    plan = _load()
    if not plan:
        print("wave: no persisted plan", file=sys.stderr); return 4
    n = 0
    for s in plan:
        if s.get("status", "pending") == "pending":
            s["status"] = "cancelled"; n += 1
    with open(STATE, "w") as f:
        json.dump(plan, f, indent=2)
    print(f"wave: aborted — {n} pending slot(s) cancelled (in-flight slots keep running).")
    return 0


def cmd_mark(args) -> int:
    if args.status not in ("pending", "dispatched", "merged", "failed", "cancelled"):
        print("wave: status must be pending|dispatched|merged|failed|cancelled", file=sys.stderr)
        return 2
    plan = _load()
    match = [s for s in plan if str(s.get("slot")) == str(args.n)]
    if not match:
        print(f"wave: slot {args.n} not found", file=sys.stderr)
        return 4
    match[0]["status"] = args.status
    with open(STATE, "w") as f:
        json.dump(plan, f, indent=2)
    print(f"wave: slot {args.n} → {args.status}")
    return 0


def cmd_model(args) -> int:
    routed = args.routed.lower()
    if routed not in MODELS:
        print(f"wave: unknown model '{routed}' (known: {', '.join(MODELS)})", file=sys.stderr)
        return 2
    cli, is_claude = MODELS[routed]
    out = {"routed": routed, "cli_model": cli, "is_claude": is_claude,
           "dispatch": "worker" if is_claude else "brief"}
    if args.current:
        cur = args.current.lower()
        cur_cli = MODELS.get(cur, (cur, True))[0]
        out["current"] = cur
        out["mismatch"] = (cur != routed)
        if out["mismatch"] and is_claude:
            out["fix"] = f"dispatch a worker at {cli}, or /model {routed} in an interactive session"
    print(json.dumps(out, indent=2))
    return 0


def main() -> int:
    p = argparse.ArgumentParser(prog="wave.py")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("save").set_defaults(fn=cmd_save)
    sub.add_parser("list").set_defaults(fn=cmd_list)
    sub.add_parser("next").set_defaults(fn=cmd_next)
    sub.add_parser("abort").set_defaults(fn=cmd_abort)
    sp = sub.add_parser("slot"); sp.add_argument("n"); sp.set_defaults(fn=cmd_slot)
    kp = sub.add_parser("mark"); kp.add_argument("n"); kp.add_argument("status"); kp.set_defaults(fn=cmd_mark)
    mp = sub.add_parser("model"); mp.add_argument("routed"); mp.add_argument("--current"); mp.set_defaults(fn=cmd_model)
    args = p.parse_args()
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
