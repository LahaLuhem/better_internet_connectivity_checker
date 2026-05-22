"""`cmd_compare` - Mann-Whitney diff + paired charts + COMPARE.md.

Prints the significance table to stdout for interactive use, then writes
the same data plus paired-chart PNGs and a forest plot to the output dir
(default: `benchmark/reports/`). Chart rendering is best-effort: if the
analysis deps are missing we still print the table - the maintainer gets
the answer even without seaborn installed.
"""

from __future__ import annotations

import argparse
import importlib.util
import math
import sys
from pathlib import Path

from bicc_bench.data.dtos.compare_row import CompareRow
from bicc_bench.data.utils.io import load_aggregated, resolve_outdir
from bicc_bench.data.utils.stats import compute_compare_rows


def cmd_compare(args: argparse.Namespace) -> int:
    """Diff two aggregated.json result sets with Mann-Whitney U.

    Output files in `<out>/`:
      - compare_headline_tick_drift.png  - paired box plot of max_drift
      - compare_memory_peak_rss.png      - paired box plot of peak RSS
      - compare_scenario_stability.png   - paired box plot, slow_observer excluded
      - compare_subscriber_scaling.png   - paired line plot from status_emission
      - compare_forest.png               - % deltas, colored by sig + direction
      - COMPARE.md                       - significance table + chart embeds
    """
    try:
        # scipy is imported here only so the failure message points at
        # `uv sync` rather than a stack trace deep inside stats.py.
        from scipy import stats as _scipy_stats  # noqa: F401
    except ImportError:
        print(
            "scipy required - run `uv sync` from benchmark/python/",
            file=sys.stderr,
        )
        return 1

    baseline_records = load_aggregated(args.baseline)
    current_records = load_aggregated(args.current)
    rows = compute_compare_rows(baseline_records, current_records)
    _print_compare_table(rows)

    # Chart rendering needs the analysis deps; the text table above is the
    # interactive-use deliverable, so we don't fail the whole command if
    # charts can't render. Users can still get the table from `compare`.
    missing = [
        name
        for name in ("matplotlib", "polars", "seaborn", "pandas")
        if importlib.util.find_spec(name) is None
    ]
    if missing:
        print(
            f"\nskipping chart generation - missing deps: {', '.join(missing)}",
            file=sys.stderr,
        )
        print("  run `uv sync` from benchmark/python/", file=sys.stderr)
        return 0

    # Local imports so cmd_compare stays importable without the chart stack.
    from bicc_bench.data.utils import charts, markdown

    out_dir = resolve_outdir(args)
    out_dir.mkdir(parents=True, exist_ok=True)

    paired = charts.paired_dataframe(baseline_records, current_records)
    charts.set_default_theme()

    chart_paths: list[Path] = [
        charts.plot_compare_headline_tick_drift(
            paired, out_dir / "compare_headline_tick_drift.png"
        ),
        charts.plot_compare_memory_peak_rss(paired, out_dir / "compare_memory_peak_rss.png"),
        charts.plot_compare_scenario_stability(paired, out_dir / "compare_scenario_stability.png"),
    ]
    sub_chart = charts.plot_compare_subscriber_scaling(
        paired, out_dir / "compare_subscriber_scaling.png"
    )
    if sub_chart is not None:
        chart_paths.append(sub_chart)
    chart_paths.append(charts.plot_compare_forest(rows, out_dir / "compare_forest.png"))

    compare_path = out_dir / "COMPARE.md"
    compare_path.write_text(
        markdown.render_compare_markdown(
            rows,
            chart_paths=chart_paths,
            baseline_records=baseline_records,
            current_records=current_records,
        )
    )

    print(f"\nwrote compare artifacts to: {out_dir}")
    for p in chart_paths:
        print(f"  {p.name}")
    print(f"  {compare_path.name}")

    return 0


def _print_compare_table(rows: list[CompareRow]) -> None:
    """Print the Mann-Whitney significance table to stdout for interactive use."""
    header = (
        f"{'scenario':<24} {'metric':<28} "
        f"{'baseline':>12} {'current':>12} {'delta':>10} {'p-value':>10} {'sig?':<5}"
    )
    print(header)
    print("-" * 105)

    any_significant = False
    for row in rows:
        any_significant = any_significant or row.significant
        sig_marker = "*" if row.significant else ""
        delta_str = f"{row.delta_pct:>+9.1f}%" if math.isfinite(row.delta_pct) else "       inf"
        print(
            f"{row.scenario:<24} {row.metric:<28} "
            f"{row.baseline_median:>12.3f} {row.current_median:>12.3f} "
            f"{delta_str} {row.p_value:>10.4f} {sig_marker:<5}"
        )

    print()
    if any_significant:
        print("* = statistically significant at p < 0.05 (Mann-Whitney U)")
    else:
        print("no significant differences detected")
