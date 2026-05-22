"""Chart renderers - 4 report PNGs, 4 paired compare PNGs, 1 forest plot.

Module-level imports of matplotlib / polars / seaborn / pandas are
intentional - this module only makes sense if the analysis stack is
installed. Subcommands gate the call site (`cmd_report` / `cmd_compare`)
with an explicit `find_spec` check so the import error message points
users at `uv sync` rather than crashing here.

Each plot fn returns the output `Path` it wrote to (caller threads the
return into a chart-paths list); helpers that can produce nothing return
`None` so the caller knows to skip the slot in markdown.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
import polars as pl
import seaborn as sns

from bicc_bench.config import (
    CHART_DPI,
    CHART_PALETTE,
    FOREST_COLOUR_IMPROVEMENT,
    FOREST_COLOUR_NOT_SIG,
    FOREST_COLOUR_REGRESSION,
)
from bicc_bench.data.dtos.compare_row import CompareRow
from bicc_bench.data.dtos.result_record import ResultRecord, flatten_records


def set_default_theme() -> None:
    """Apply the shared seaborn theme. Idempotent; cmd_X calls once at start."""
    sns.set_theme(style="whitegrid", context="paper", palette=CHART_PALETTE)


def write_empty_chart(out_path: Path, message: str) -> None:
    """Render a 'no data' placeholder PNG. Keeps markdown image refs valid."""
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.text(0.5, 0.5, message, ha="center", va="center", fontsize=12, color="#888")
    ax.set_axis_off()
    fig.savefig(out_path, dpi=CHART_DPI)
    plt.close(fig)


# ---- report charts (single dataset) ---------------------------------------


def plot_headline_tick_drift(dataframe: pl.DataFrame, out_path: Path) -> Path:
    """Box plot of max_drift_microseconds per scenario, log y-scale.

    `slow_observer` stalls the scheduler with sleep(50ms) every 100ms tick.
    On the log y-axis its box will tower ~3 orders of magnitude above the
    other scenarios - that gap IS the bug story.
    """
    metric = "max_drift_microseconds"
    plot_df = (
        dataframe.filter(pl.col(metric).is_not_null()).select(["scenario", metric]).to_pandas()
    )
    if plot_df.empty:
        write_empty_chart(out_path, "No tick-drift data found.")
        return out_path

    fig, ax = plt.subplots(figsize=(9, 5))
    sns.boxplot(
        data=plot_df,
        x="scenario",
        y=metric,
        ax=ax,
        order=sorted(plot_df["scenario"].unique()),
        hue="scenario",
        legend=False,
    )
    ax.set_yscale("log")
    ax.set_ylabel("Max tick drift (us, log scale)")
    ax.set_xlabel("")
    ax.set_title("Worst-case scheduler stall per scenario")
    plt.xticks(rotation=30, ha="right")
    plt.tight_layout()
    fig.savefig(out_path, dpi=CHART_DPI)
    plt.close(fig)
    return out_path


def plot_memory_peak_rss(dataframe: pl.DataFrame, out_path: Path) -> Path:
    """Box plot of peak_rss_bytes per scenario, MB on y-axis."""
    metric = "peak_rss_bytes"
    plot_df = (
        dataframe.filter(pl.col(metric).is_not_null()).select(["scenario", metric]).to_pandas()
    )
    if plot_df.empty:
        write_empty_chart(out_path, "No peak_rss data found.")
        return out_path

    plot_df["peak_rss_mb"] = plot_df[metric] / (1024.0 * 1024.0)

    fig, ax = plt.subplots(figsize=(9, 5))
    sns.boxplot(
        data=plot_df,
        x="scenario",
        y="peak_rss_mb",
        ax=ax,
        order=sorted(plot_df["scenario"].unique()),
        hue="scenario",
        legend=False,
    )
    ax.set_ylabel("Peak RSS (MB)")
    ax.set_xlabel("")
    ax.set_title("Peak resident set size per scenario")
    plt.xticks(rotation=30, ha="right")
    plt.tight_layout()
    fig.savefig(out_path, dpi=CHART_DPI)
    plt.close(fig)
    return out_path


def plot_scenario_stability(dataframe: pl.DataFrame, out_path: Path) -> Path:
    """Box plot of max_drift_microseconds EXCLUDING slow_observer.

    Slow observer's tick-drift is ~1000x the others, so it dominates the
    y-scale of the headline chart. Excluding it here lets the noise floor
    of the other scenarios be readable. Narrow boxes = reproducible.
    """
    metric = "max_drift_microseconds"
    plot_df = (
        dataframe.filter(pl.col(metric).is_not_null())
        .filter(pl.col("scenario") != "slow_observer")
        .select(["scenario", metric])
        .to_pandas()
    )
    if plot_df.empty:
        write_empty_chart(out_path, "No non-slow_observer drift data found.")
        return out_path

    fig, ax = plt.subplots(figsize=(9, 5))
    sns.boxplot(
        data=plot_df,
        x="scenario",
        y=metric,
        ax=ax,
        order=sorted(plot_df["scenario"].unique()),
        hue="scenario",
        legend=False,
    )
    sns.stripplot(
        data=plot_df,
        x="scenario",
        y=metric,
        ax=ax,
        order=sorted(plot_df["scenario"].unique()),
        color="black",
        alpha=0.4,
        size=3,
    )
    ax.set_ylabel("Max tick drift (us)")
    ax.set_xlabel("")
    ax.set_title("Per-scenario noise floor (slow_observer excluded)")
    plt.xticks(rotation=30, ha="right")
    plt.tight_layout()
    fig.savefig(out_path, dpi=CHART_DPI)
    plt.close(fig)
    return out_path


def plot_subscriber_scaling(dataframe: pl.DataFrame, out_path: Path) -> Path | None:
    """Line plot of `microseconds_per_emission` vs subscriber_count.

    Uses the `status_emission` micro: synchronous broadcast cost in
    isolation. Production `InternetConnection` uses async broadcast where
    the producer pays constant cost regardless of N; this chart isolates
    the per-listener delivery cost.

    Returns None (and writes nothing) when there's no status_emission data
    in the input - the caller skips the slot in SUMMARY.md.
    """
    metric = "microseconds_per_emission"
    has_subscriber_count = "subscriber_count" in dataframe.columns
    has_metric = metric in dataframe.columns
    if not (has_subscriber_count and has_metric):
        return None

    plot_df = (
        dataframe.filter(pl.col("scenario") == "status_emission")
        .filter(pl.col(metric).is_not_null())
        .filter(pl.col("subscriber_count").is_not_null())
        .select(["subscriber_count", metric])
        .to_pandas()
    )
    if plot_df.empty:
        return None

    fig, ax = plt.subplots(figsize=(8, 5))
    sns.pointplot(
        data=plot_df,
        x="subscriber_count",
        y=metric,
        ax=ax,
        errorbar=("pi", 50),
        marker="o",
        linestyle="-",
        color="#4c72b0",
    )
    ax.set_xlabel("Subscriber count")
    ax.set_ylabel("Broadcast cost (us / emit)")
    ax.set_title("Sync-broadcast cost scales linearly with subscribers")
    plt.tight_layout()
    fig.savefig(out_path, dpi=CHART_DPI)
    plt.close(fig)
    return out_path


# ---- compare charts (two datasets) ----------------------------------------


def paired_dataframe(
    baseline_records: list[ResultRecord],
    current_records: list[ResultRecord],
) -> pl.DataFrame:
    """Combine baseline + current records into one polars DataFrame.

    Adds a `run` column ("baseline" / "current") so seaborn's `hue=` can
    render the two series side-by-side on the same axes. Uses
    `pl.concat(how="diagonal")` to align columns by name and fill missing
    metrics with null - the two sides may have emitted slightly different
    summary metrics if the schema drifted between captures.
    """
    base = pl.DataFrame(flatten_records(baseline_records), infer_schema_length=None).with_columns(
        pl.lit("baseline").alias("run")
    )
    curr = pl.DataFrame(flatten_records(current_records), infer_schema_length=None).with_columns(
        pl.lit("current").alias("run")
    )

    return pl.concat([base, curr], how="diagonal")


def plot_compare_headline_tick_drift(paired: pl.DataFrame, out_path: Path) -> Path:
    """Paired box plot of max_drift_microseconds per scenario, log y-scale."""
    metric = "max_drift_microseconds"
    plot_df = (
        paired.filter(pl.col(metric).is_not_null()).select(["scenario", metric, "run"]).to_pandas()
    )
    if plot_df.empty:
        write_empty_chart(out_path, "No tick-drift data in both runs.")
        return out_path

    fig, ax = plt.subplots(figsize=(11, 5))
    sns.boxplot(
        data=plot_df,
        x="scenario",
        y=metric,
        hue="run",
        ax=ax,
        order=sorted(plot_df["scenario"].unique()),
        hue_order=["baseline", "current"],
    )
    ax.set_yscale("log")
    ax.set_ylabel("Max tick drift (us, log scale)")
    ax.set_xlabel("")
    ax.set_title("Worst-case scheduler stall: baseline vs current")
    ax.legend(title="", loc="best")
    plt.xticks(rotation=30, ha="right")
    plt.tight_layout()
    fig.savefig(out_path, dpi=CHART_DPI)
    plt.close(fig)
    return out_path


def plot_compare_memory_peak_rss(paired: pl.DataFrame, out_path: Path) -> Path:
    """Paired box plot of peak RSS per scenario, MB on y-axis."""
    metric = "peak_rss_bytes"
    plot_df = (
        paired.filter(pl.col(metric).is_not_null()).select(["scenario", metric, "run"]).to_pandas()
    )
    if plot_df.empty:
        write_empty_chart(out_path, "No peak_rss data in both runs.")
        return out_path

    plot_df["peak_rss_mb"] = plot_df[metric] / (1024.0 * 1024.0)

    fig, ax = plt.subplots(figsize=(11, 5))
    sns.boxplot(
        data=plot_df,
        x="scenario",
        y="peak_rss_mb",
        hue="run",
        ax=ax,
        order=sorted(plot_df["scenario"].unique()),
        hue_order=["baseline", "current"],
    )
    ax.set_ylabel("Peak RSS (MB)")
    ax.set_xlabel("")
    ax.set_title("Peak resident set size: baseline vs current")
    ax.legend(title="", loc="best")
    plt.xticks(rotation=30, ha="right")
    plt.tight_layout()
    fig.savefig(out_path, dpi=CHART_DPI)
    plt.close(fig)
    return out_path


def plot_compare_scenario_stability(paired: pl.DataFrame, out_path: Path) -> Path:
    """Paired box plot of max_drift_microseconds EXCLUDING slow_observer.

    Same framing as report's stability chart - excluding the outlier so the
    noise-floor scenarios stay readable on a linear axis. Paired here shows
    whether the refactor moved (or destabilised) the noise floor.
    """
    metric = "max_drift_microseconds"
    plot_df = (
        paired.filter(pl.col(metric).is_not_null())
        .filter(pl.col("scenario") != "slow_observer")
        .select(["scenario", metric, "run"])
        .to_pandas()
    )
    if plot_df.empty:
        write_empty_chart(out_path, "No non-slow_observer drift data in both runs.")
        return out_path

    fig, ax = plt.subplots(figsize=(11, 5))
    sns.boxplot(
        data=plot_df,
        x="scenario",
        y=metric,
        hue="run",
        ax=ax,
        order=sorted(plot_df["scenario"].unique()),
        hue_order=["baseline", "current"],
    )
    ax.set_ylabel("Max tick drift (us)")
    ax.set_xlabel("")
    ax.set_title("Per-scenario noise floor: baseline vs current (slow_observer excluded)")
    ax.legend(title="", loc="best")
    plt.xticks(rotation=30, ha="right")
    plt.tight_layout()
    fig.savefig(out_path, dpi=CHART_DPI)
    plt.close(fig)
    return out_path


def plot_compare_subscriber_scaling(
    paired: pl.DataFrame,
    out_path: Path,
) -> Path | None:
    """Paired line plot of broadcast cost vs subscriber count.

    Two lines (baseline + current) showing how the per-listener delivery
    cost shifts. Returns None when the input has no status_emission data
    on either side - the caller skips the slot in COMPARE.md.
    """
    metric = "microseconds_per_emission"
    if metric not in paired.columns or "subscriber_count" not in paired.columns:
        return None

    plot_df = (
        paired.filter(pl.col("scenario") == "status_emission")
        .filter(pl.col(metric).is_not_null())
        .filter(pl.col("subscriber_count").is_not_null())
        .select(["subscriber_count", metric, "run"])
        .to_pandas()
    )
    if plot_df.empty:
        return None

    fig, ax = plt.subplots(figsize=(8, 5))
    sns.pointplot(
        data=plot_df,
        x="subscriber_count",
        y=metric,
        hue="run",
        ax=ax,
        hue_order=["baseline", "current"],
        errorbar=("pi", 50),
        marker="o",
        linestyle="-",
    )
    ax.set_xlabel("Subscriber count")
    ax.set_ylabel("Broadcast cost (us / emit)")
    ax.set_title("Sync-broadcast cost: baseline vs current")
    ax.legend(title="", loc="best")
    plt.tight_layout()
    fig.savefig(out_path, dpi=CHART_DPI)
    plt.close(fig)
    return out_path


def plot_compare_forest(rows: list[CompareRow], out_path: Path) -> Path:
    """Horizontal bar chart of % delta per (scenario, metric), sorted by |delta|.

    Color encoding (interpretation: most metrics are 'lower is better' -
    drift, memory, microseconds/op):
      - Red:   significant regression  (delta > 0, p < 0.05)
      - Green: significant improvement (delta < 0, p < 0.05)
      - Gray:  not significant (p >= 0.05)
    """
    plot_rows = [r for r in rows if r.delta_finite]
    if not plot_rows:
        write_empty_chart(out_path, "No comparable (scenario, metric) pairs.")
        return out_path

    # Sort ascending by |delta| - largest delta lands at the TOP of the
    # horizontal bar chart (which renders the first row at the bottom).
    plot_rows = sorted(plot_rows, key=lambda r: abs(r.delta_pct))

    labels = [f"{r.scenario} / {r.metric}" for r in plot_rows]
    deltas = [r.delta_pct for r in plot_rows]
    colors = [_forest_colour(r) for r in plot_rows]

    # Height scales with row count - keeps bars readable from 5 rows to 50.
    height = max(4.0, len(plot_rows) * 0.28)
    fig, ax = plt.subplots(figsize=(10, height))
    ax.barh(labels, deltas, color=colors, edgecolor="#555", linewidth=0.5)
    ax.axvline(0, color="#333", linewidth=0.8)
    ax.set_xlabel("Delta from baseline (%)")
    ax.set_title("Per-(scenario, metric) delta - red=regression, green=improvement, gray=not sig")
    ax.grid(True, axis="x", alpha=0.3)
    plt.tight_layout()
    fig.savefig(out_path, dpi=CHART_DPI)
    plt.close(fig)
    return out_path


def _forest_colour(row: CompareRow) -> str:
    """Pick the forest-bar colour for a single CompareRow."""
    if not row.significant:
        return FOREST_COLOUR_NOT_SIG
    return FOREST_COLOUR_REGRESSION if row.delta_pct > 0 else FOREST_COLOUR_IMPROVEMENT


# `pd` is intentionally imported at module level even though only the type
# annotations would notice - keeping it ensures pandas is available when
# polars hands off frames to seaborn via `.to_pandas()` (which uses pyarrow
# under the hood). Suppress the unused warning here.
_ = pd
