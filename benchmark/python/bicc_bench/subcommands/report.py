"""`cmd_report` - render PNGs + SUMMARY.md from one aggregated.json.

Default output dir is `benchmark/reports/` (committed - inlined from the
package README). Override with `--out` for ad-hoc snapshots that shouldn't
overwrite the committed set.
"""

from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path

from bicc_bench.data.dtos.result_record import flatten_records
from bicc_bench.data.utils.io import load_aggregated, resolve_outdir


def cmd_report(args: argparse.Namespace) -> int:
    """Generate PNG charts + SUMMARY.md from one aggregated.json file.

    Charts (one PNG each):
    - headline_tick_drift.png  - max scheduler stall per scenario
    - memory_peak_rss.png      - peak RSS per scenario
    - scenario_stability.png   - noise floor (slow_observer excluded)
    - subscriber_scaling.png   - broadcast cost vs N (from status_emission)
    """
    # Fail-fast probe for analysis deps. Chart helpers fail later anyway,
    # but the explicit message points users at `uv sync`.
    missing = [
        name
        for name in ("matplotlib", "polars", "seaborn", "pandas")
        if importlib.util.find_spec(name) is None
    ]
    if missing:
        print(f"missing analysis deps: {', '.join(missing)}", file=sys.stderr)
        print("  run `uv sync` from benchmark/python/", file=sys.stderr)
        return 1

    # Local imports keep cmd_report importable without the chart stack.
    import polars as pl

    from bicc_bench.data.utils import charts, markdown

    records = load_aggregated(args.results)
    if not records:
        print("no records found in input", file=sys.stderr)
        return 1

    out_dir = resolve_outdir(args)
    out_dir.mkdir(parents=True, exist_ok=True)

    # Flatten records into a DataFrame. We carry both metadata cols
    # (scenario, iteration, git_sha, ...) and summary metrics in one frame.
    dataframe = pl.DataFrame(flatten_records(records), infer_schema_length=None)

    charts.set_default_theme()

    chart_paths: list[Path] = [
        charts.plot_headline_tick_drift(dataframe, out_dir / "headline_tick_drift.png"),
        charts.plot_memory_peak_rss(dataframe, out_dir / "memory_peak_rss.png"),
        charts.plot_scenario_stability(dataframe, out_dir / "scenario_stability.png"),
    ]
    sub_chart = charts.plot_subscriber_scaling(dataframe, out_dir / "subscriber_scaling.png")
    if sub_chart is not None:
        chart_paths.append(sub_chart)

    summary_path = out_dir / "SUMMARY.md"
    summary_path.write_text(
        markdown.render_summary_markdown(dataframe, chart_paths=chart_paths, records=records)
    )

    print(f"\nwrote charts + summary to: {out_dir}")
    for p in chart_paths:
        print(f"  {p.name}")
    print(f"  {summary_path.name}")

    return 0
