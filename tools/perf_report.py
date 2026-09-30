#!/usr/bin/env python3
"""Turns a perf run's JSON (integration_test/perf_test.dart via
test_driver/perf_driver.dart) into qa/perf/YYYY-MM-DD-<device>.md (#117).

    tools/perf_report.py <run.json> <out.md> KEY=VALUE...

The KEY=VALUE pairs are the environment tools/perf.sh collected (device,
Android, build, commit, Flutter, charging, hardware or emulator); they are
printed in the order given. Exit 0 always writes the report; the 95 % target
is reported, not enforced here.
"""

from __future__ import annotations

import json
import math
import sys

TARGET = 0.95


def median(values: list[int]) -> float:
    """The middle value, or the mean of the middle two."""
    s = sorted(values)
    n = len(s)
    if n == 0:
        raise ValueError("median of nothing")
    mid = n // 2
    return float(s[mid]) if n % 2 else (s[mid - 1] + s[mid]) / 2


def p95(values: list[int]) -> int:
    """The 95th percentile by nearest rank: the ceil(0.95 n)-th smallest."""
    s = sorted(values)
    if not s:
        raise ValueError("p95 of nothing")
    return s[max(1, math.ceil(0.95 * len(s))) - 1]


def summarise(rows: list[dict]) -> dict:
    """One draw mode's numbers. Only a `within` verdict counts toward the
    target; every other verdict (late, timeout, notFound, error) is a miss.
    Times and deals tried are over the searches that found a deal."""
    found = [r for r in rows if r.get("found") is not None]
    within = sum(1 for r in rows if r["verdict"] == "within")
    ms = [r["ms"] for r in found]
    tried = [r["dealsTried"] for r in found]
    out = {
        "searches": len(rows),
        "within": within,
        "share": within / len(rows) if rows else 0.0,
        "misses": len(rows) - within,
    }
    if found:
        out.update(
            ms_median=median(ms), ms_p95=p95(ms), ms_max=max(ms),
            tried_median=median(tried), tried_p95=p95(tried), tried_max=max(tried),
        )
    out["meets_target"] = bool(rows) and out["share"] >= TARGET
    return out


def render(run: dict, env: list[tuple[str, str]]) -> str:
    lines = ["# Winnable search and deal check", ""]
    lines += [f"- **{k}:** {v}" for k, v in env]
    lines.append(f"- **Node budget:** {run.get('nodeBudget', 'n/a')}")
    lines.append(f"- **Searches per draw mode:** {run.get('searchesPerDraw', 'n/a')}")
    lines.append("")

    golden = run.get("golden")
    lines.append("## Deals match the host")
    lines.append("")
    if golden is None:
        lines.append("Not run.")
    elif golden["mismatches"]:
        lines.append(f"**MISMATCH:** {len(golden['mismatches'])} of {golden['checked']} golden deals differ:")
        lines += [f"- {m}" for m in golden["mismatches"]]
    else:
        lines.append(f"All {golden['checked']} golden deals match `test/fixtures/golden_deals.json`.")
    lines.append("")

    rows = run.get("searches", [])
    lines.append("## Winnable search")
    lines.append("")
    lines.append("| draw | searches | within 5 s | share | target 95 % | median ms | p95 ms | max ms | median tried | p95 tried | max tried |")
    lines.append("|---|---|---|---|---|---|---|---|---|---|---|")
    for draw in (1, 3):
        s = summarise([r for r in rows if r["draw"] == draw])
        if not s["searches"]:
            continue
        nums = [s.get(k, "n/a") for k in ("ms_median", "ms_p95", "ms_max", "tried_median", "tried_p95", "tried_max")]
        lines.append(
            f"| {draw} | {s['searches']} | {s['within']} | {s['share']:.1%} | "
            f"{'met' if s['meets_target'] else 'MISSED'} | " + " | ".join(str(n) for n in nums) + " |"
        )
    lines.append("")
    lines.append("<details><summary>Every search</summary>")
    lines.append("")
    lines.append("| draw | base | found | ms | deals tried | verdict |")
    lines.append("|---|---|---|---|---|---|")
    for r in rows:
        lines.append(
            f"| {r['draw']} | {r['base']} | {r.get('found') or '—'} | {r['ms']} | "
            f"{r.get('dealsTried') or '—'} | {r['verdict']} |"
        )
    lines.append("")
    lines.append("</details>")
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    with open(argv[1]) as f:
        run = json.load(f)
    env = []
    for pair in argv[3:]:
        key, _, value = pair.partition("=")
        env.append((key, value))
    with open(argv[2], "w") as f:
        f.write(render(run, env))
    golden = run.get("golden") or {}
    return 1 if golden.get("mismatches") else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
