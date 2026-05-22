"""Markdown renderers - SUMMARY.md (report) + COMPARE.md (compare).

The maintainer drops sections from these files into the package README,
so the structure is one h2 section per chart with a summary table above
and the image embed below. `value_formatter` is the precision-aware
number formatter that keeps both `1,812,265 us` (slow_observer drift) and
`0.138 us/emit` (status_emission micro) readable in the same column.
"""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path

import polars as pl

from bicc_bench.data.dtos.compare_row import CompareRow
from bicc_bench.data.dtos.result_record import ResultRecord
from bicc_bench.data.utils.meta import summary_metadata


def value_formatter(units: str) -> Callable[[float | int | None], str]:
    """Return a unary fn that formats a numeric value for the requested units.

    Precision tier (for "us" / freeform): values >= 1000 round to integers
    with thousands separators; values 1-1000 get two decimal places; sub-1
    values get three. Keeps both the slow_observer headline (~1.8M us) and
    the status_emission micro (~0.13 us / emit) readable in the same table.

    "MB" divides byte-valued numbers by 1024^2 and shows two decimals.
    """

    def _format_microseconds(value: float | int | None) -> str:
        if value is None:
            return "-"
        abs_value = abs(value)
        if abs_value >= 1000:
            return f"{value:,.0f}"
        if abs_value >= 1:
            return f"{value:,.2f}"
        return f"{value:,.3f}"

    if units == "MB":
        return lambda v: f"{v / (1024.0 * 1024.0):,.2f}" if v is not None else "-"
    if units == "us":
        return _format_microseconds
    return lambda v: f"{v:,.2f}" if v is not None else "-"


def metric_table(
    dataframe: pl.DataFrame,
    metric: str,
    *,
    units: str,
    exclude_scenario: str | None = None,
) -> str:
    """Render a markdown table: per-scenario {N, median, IQR, min, max}.

    `units = "MB"` divides byte-valued numbers by 1024^2 before display.
    `units = "us"` uses the precision-tier formatter (integer for >= 1000,
    decimals for smaller). Other units pass through with two decimals.
    """
    if metric not in dataframe.columns:
        return f"_(no `{metric}` data in input)_\n"

    df = dataframe.filter(pl.col(metric).is_not_null())
    if exclude_scenario is not None:
        df = df.filter(pl.col("scenario") != exclude_scenario)
    if df.is_empty():
        return f"_(no `{metric}` data in input after filters)_\n"

    agg = (
        df.group_by("scenario")
        .agg(
            [
                pl.col(metric).count().alias("n"),
                pl.col(metric).median().alias("median"),
                pl.col(metric).quantile(0.25).alias("q25"),
                pl.col(metric).quantile(0.75).alias("q75"),
                pl.col(metric).min().alias("min"),
                pl.col(metric).max().alias("max"),
            ]
        )
        .sort("scenario")
    )

    fmt = value_formatter(units)
    header = f"| Scenario | N | Median ({units}) | IQR ({units}) | Min ({units}) | Max ({units}) |"
    sep = "|---|---:|---:|---:|---:|---:|"
    rows = [header, sep]
    for row in agg.iter_rows(named=True):
        iqr = row["q75"] - row["q25"]
        rows.append(
            f"| `{row['scenario']}` | {row['n']} | {fmt(row['median'])} "
            f"| {fmt(iqr)} | {fmt(row['min'])} | {fmt(row['max'])} |"
        )
    return "\n".join(rows) + "\n"


def subscriber_scaling_table(dataframe: pl.DataFrame) -> str:
    """Render a markdown table indexed by subscriber_count for status_emission."""
    metric = "microseconds_per_emission"
    if metric not in dataframe.columns or "subscriber_count" not in dataframe.columns:
        return "_(no status_emission data in input)_\n"

    df = dataframe.filter(pl.col(metric).is_not_null()).filter(
        pl.col("subscriber_count").is_not_null()
    )
    if df.is_empty():
        return "_(no status_emission data in input)_\n"

    agg = (
        df.group_by("subscriber_count")
        .agg(
            [
                pl.col(metric).count().alias("n"),
                pl.col(metric).median().alias("median"),
                pl.col(metric).quantile(0.25).alias("q25"),
                pl.col(metric).quantile(0.75).alias("q75"),
            ]
        )
        .sort("subscriber_count")
    )

    fmt = value_formatter("us")
    header = "| Subscribers | N | Median (us/emit) | IQR (us) |"
    sep = "|---:|---:|---:|---:|"
    rows = [header, sep]
    for row in agg.iter_rows(named=True):
        iqr = row["q75"] - row["q25"]
        rows.append(
            f"| {row['subscriber_count']} | {row['n']} | {fmt(row['median'])} | {fmt(iqr)} |"
        )
    return "\n".join(rows) + "\n"


def render_summary_markdown(
    dataframe: pl.DataFrame,
    *,
    chart_paths: list[Path],
    records: list[ResultRecord],
) -> str:
    """Render SUMMARY.md - per-chart sections with a table above each PNG."""
    metadata = summary_metadata(records)
    chart_names = {p.name for p in chart_paths}

    parts: list[str] = [
        "# Benchmark results\n",
        f"Captured **{metadata['date']}** against "
        f"`{metadata['package_version']}` at `{metadata['git_sha']}` "
        f"on Dart SDK {metadata['sdk_version']}. N={metadata['iterations']} "
        "iterations per scenario.\n",
        "> Per-machine measurements. Numbers below reflect *this* machine "
        "(CPU, GC, OS scheduler, thermal state). Your numbers WILL differ - "
        "capture your own local baseline before measuring a code delta.\n",
        "## Headline: worst-case scheduler stall per scenario\n",
        "The `slow_observer` scenario simulates a heavy synchronous observer "
        "(50 ms per callback) running against a 100 ms tick. Pre-refactor, "
        "this blocks the scheduler - the box for `slow_observer` should "
        "tower over the others on the log axis below.\n",
        metric_table(dataframe, "max_drift_microseconds", units="us"),
    ]

    if "headline_tick_drift.png" in chart_names:
        parts.append("\n![Headline tick drift](headline_tick_drift.png)\n")

    parts.extend(
        [
            "## Peak resident set size per scenario\n",
            "Peak RSS captured via `ProcessInfo.currentRss` sampled every 500 ms "
            "(every 250 ms in `long_running`). The package's memory footprint "
            "baseline; future refactors should not regress this without reason.\n",
            metric_table(dataframe, "peak_rss_bytes", units="MB"),
        ]
    )
    if "memory_peak_rss.png" in chart_names:
        parts.append("\n![Memory peak RSS](memory_peak_rss.png)\n")

    parts.extend(
        [
            "## Stability: noise floor across scenarios (slow_observer excluded)\n",
            "Same metric as the headline chart, but with the `slow_observer` "
            "outlier excluded so the y-scale is readable. A narrow box = the "
            "metric is reproducible iteration-to-iteration.\n",
            metric_table(
                dataframe,
                "max_drift_microseconds",
                units="us",
                exclude_scenario="slow_observer",
            ),
        ]
    )
    if "scenario_stability.png" in chart_names:
        parts.append("\n![Scenario stability](scenario_stability.png)\n")

    if "subscriber_scaling.png" in chart_names:
        parts.extend(
            [
                "## Subscriber scaling: broadcast cost vs N listeners\n",
                "From the `status_emission` micro (synchronous broadcast, "
                "isolated from the rest of the package). Production "
                "`InternetConnection` uses async-default broadcast where the "
                "producer pays a constant cost regardless of N; this chart "
                "isolates the per-listener *delivery* cost.\n",
                subscriber_scaling_table(dataframe.filter(pl.col("scenario") == "status_emission")),
                "\n![Subscriber scaling](subscriber_scaling.png)\n",
            ]
        )

    return "\n".join(parts)


def render_compare_markdown(
    rows: list[CompareRow],
    *,
    chart_paths: list[Path],
    baseline_records: list[ResultRecord],
    current_records: list[ResultRecord],
) -> str:
    """Render COMPARE.md - forest + paired charts + Mann-Whitney table.

    Same drop-into-README shape as SUMMARY.md, with both baseline and
    current capture metadata in the header so the reader can verify the
    comparison is apples-to-apples (same machine, same SDK).
    """
    base_meta = summary_metadata(baseline_records)
    curr_meta = summary_metadata(current_records)
    chart_names = {p.name for p in chart_paths}

    parts: list[str] = [
        "# Benchmark comparison\n",
        f"- **Baseline**: `{base_meta['package_version']}` at "
        f"`{base_meta['git_sha']}` (Dart SDK {base_meta['sdk_version']}) "
        f"captured {base_meta['date']}, N={base_meta['iterations']} per scenario\n"
        f"- **Current**:  `{curr_meta['package_version']}` at "
        f"`{curr_meta['git_sha']}` (Dart SDK {curr_meta['sdk_version']}) "
        f"captured {curr_meta['date']}, N={curr_meta['iterations']} per scenario\n",
        "> Per-machine measurement. Both baseline and current must be "
        "captured on the same machine, in the same thermal/power state, "
        "with no competing workload - otherwise the delta is noise rather "
        "than signal.\n",
        "## Forest: all comparable (scenario, metric) deltas\n",
        "Bars sorted by `|delta|` ascending (largest at top). Color encodes "
        "direction + significance: red = significant regression "
        "(p < 0.05, current > baseline), green = significant improvement, "
        "gray = no significant difference detected.\n",
    ]

    if "compare_forest.png" in chart_names:
        parts.append("\n![Forest plot](compare_forest.png)\n")

    parts.extend(
        [
            "## Headline: tick drift, baseline vs current\n",
            "Paired box plot per scenario. The `slow_observer` box should "
            "collapse from ~10^6 us to the noise floor (~10^4 us) post-refactor; "
            "other scenarios should not move significantly.\n",
        ]
    )
    if "compare_headline_tick_drift.png" in chart_names:
        parts.append("\n![Headline compare](compare_headline_tick_drift.png)\n")

    parts.extend(
        [
            "## Memory: peak RSS, baseline vs current\n",
            "Steady-state memory footprint should not regress. A shift > "
            "5-10 MB warrants investigation; below that is noise on most "
            "machines.\n",
        ]
    )
    if "compare_memory_peak_rss.png" in chart_names:
        parts.append("\n![Memory compare](compare_memory_peak_rss.png)\n")

    parts.extend(
        [
            "## Stability: noise floor, baseline vs current\n",
            "`slow_observer` excluded so the y-axis stays linear. Box widths "
            "tell you how stable the measurement is iteration-to-iteration; "
            "the refactor should not destabilise the noise floor.\n",
        ]
    )
    if "compare_scenario_stability.png" in chart_names:
        parts.append("\n![Stability compare](compare_scenario_stability.png)\n")

    if "compare_subscriber_scaling.png" in chart_names:
        parts.extend(
            [
                "## Subscriber scaling, baseline vs current\n",
                "From the `status_emission` micro. The per-listener broadcast "
                "cost should stay essentially identical - the refactor changes "
                "the producer-side dispatch, not the listener-side delivery.\n",
                "\n![Scaling compare](compare_subscriber_scaling.png)\n",
            ]
        )

    parts.extend(
        [
            "## Mann-Whitney U significance table\n",
            "Each row is one `(scenario, metric)` pair where both runs emitted "
            "samples. `Delta` is `(current_median - baseline_median) / "
            "baseline_median * 100`. `Sig?` flags `p < 0.05`.\n",
            render_compare_table_markdown(rows),
        ]
    )

    return "\n".join(parts)


def render_compare_table_markdown(rows: list[CompareRow]) -> str:
    """Render the per-(scenario, metric) Mann-Whitney table as markdown."""
    header = "| Scenario | Metric | Baseline median | Current median | Delta | p-value | Sig? |"
    sep = "|---|---|---:|---:|---:|---:|:---:|"
    out = [header, sep]
    fmt = value_formatter("us")
    for r in rows:
        delta_str = f"{r.delta_pct:+.1f}%" if r.delta_finite else "inf"
        sig_str = "**Yes**" if r.significant else ""
        out.append(
            f"| `{r.scenario}` | `{r.metric}` | "
            f"{fmt(r.baseline_median)} | {fmt(r.current_median)} | "
            f"{delta_str} | {r.p_value:.4f} | {sig_str} |"
        )
    return "\n".join(out) + "\n"
