#!/usr/bin/env python3
"""Orchestrator for the `better_internet_connectivity_checker` benchmark suite.

Workflow (run from `benchmark/python/`):

    uv sync                                       # one-time: create .venv + install deps
    uv run python run.py build                    # AOT-compile all scenarios (parallel)
    uv run python run.py run --iterations 10 --out results-local/run-1/
    uv run python run.py compare baseline.json results-local/run-1/aggregated.json
    uv run python run.py report results-local/run-1/aggregated.json
                                                  # writes PNGs + SUMMARY.md alongside the JSON
    uv run python run.py report results-local/run-1/aggregated.json --reference
                                                  # writes to benchmark/charts/reference/
                                                  # (the committed maintainer baseline)

Design notes:
- Dart owns scenario *bodies* (must be in-process - instantiates the lib,
  observes streams). Each scenario is AOT-compiled for deterministic warmup.
- This Python script owns *orchestration + analysis* - invokes the AOT
  scenarios via subprocess, aggregates per-iteration JSON, runs statistical
  significance tests (Mann-Whitney U via scipy.stats), wrangles result sets
  with polars, and renders PNG charts via matplotlib + seaborn.
- Each scenario binary accepts `--iterations N` and emits N records from a
  single subprocess invocation. Iterations stay sequential inside the
  process so measurement isolation is preserved; the win is dropping
  N-1 process startups + dyld + AOT-load overhead per scenario.
- `cmd_build` parallelises `dart compile exe` across workers - safe because
  compilation does no measurement and contention only affects wall-clock.

Methodology rules (do not break - see ../README.md for rationale):
- AOT compile, not JIT (`dart compile exe`).
- N >= 10 iterations per scenario. Report median + IQR.
- Mann-Whitney U for significance claims. p < 0.05.
- AC power, no competing apps.
- Localhost HTTP only - no real network.
- NEVER parallelise scenario *runs* - CPU contention destroys signal.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import subprocess
import sys
from collections.abc import Iterable
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Final

# ---- paths ----------------------------------------------------------------

THIS_FILE: Final[Path] = Path(__file__).resolve()
BENCHMARK_DIR: Final[Path] = THIS_FILE.parent.parent
PROJECT_ROOT: Final[Path] = BENCHMARK_DIR.parent
SCENARIOS_DIR: Final[Path] = BENCHMARK_DIR / "scenarios"
MICRO_DIR: Final[Path] = BENCHMARK_DIR / "micro"
BUILD_DIR: Final[Path] = BENCHMARK_DIR / "build"
RESULTS_DIR: Final[Path] = BENCHMARK_DIR / "results-local"
REFERENCE_CHARTS_DIR: Final[Path] = BENCHMARK_DIR / "charts" / "reference"

# Default number of iterations per scenario. Override with --iterations.
DEFAULT_ITERATIONS: Final[int] = 10

# How many warmup iterations to discard from every run. The analyzer trims
# when computing aggregates - the scenario itself emits every iteration.
WARMUP_ITERATIONS: Final[int] = 2

# JSON-decoded scenario records have a fixed schema (see README §5), but the
# Python json module returns `Any` for everything. We narrow to `dict[str, Any]`
# here and validate-on-use rather than ceremony with TypedDict / pydantic
# models for a tool with a stable internal schema. `Any` is justified.
ResultRecord = dict[str, Any]

# Per-scenario default durations (seconds). Tuned to capture meaningful
# behaviour per scenario without wasting time. Micros ignore duration entirely
# (`benchmark_harness` self-times). Override the whole row with
# `--duration-seconds N` or one entry with `--duration scenario=N`.
SCENARIO_DURATIONS: Final[dict[str, int]] = {
    # Scenarios - wall-clock durations per iteration.
    "quiet_app": 5,
    "slow_observer": 5,
    "flapping_network": 9,  # captures 3 toggles at 3s cadence
    "trigger_storm": 5,  # 500 triggers at 100/sec
    "many_subscribers": 3,  # x3 sub-Ns inside the binary = ~9s actual per iter
    "long_running": 30,  # smoke; raise to 3600 for a full hour bake
    # Micros - value is irrelevant (ignored by the binary), but listed so
    # the orchestrator passes _something_.
    "check_once_overhead": 0,
    "observer_dispatch": 0,
    "status_emission": 0,
}
_FALLBACK_DURATION: Final[int] = 10

# Charts: shared output settings. 150 DPI strikes the right balance for
# README inlining - sharp on retina without bloating the committed PNGs.
_CHART_DPI: Final[int] = 150
_CHART_PALETTE: Final[str] = "Set2"


# ---- subcommand: build ----------------------------------------------------


def cmd_build(args: argparse.Namespace) -> int:
    """AOT-compile every .dart file under scenarios/ and micro/ to BUILD_DIR.

    Uses `dart compile exe`. Skips files that compile cleanly already unless
    --force is given. AOT compilation is required for deterministic warmup
    characteristics - JIT introduces too much variance.

    Parallelises across workers - compilation is CPU-bound but the workers
    are just waiting on subprocess; ThreadPoolExecutor releases the GIL on
    `subprocess.run` so threads suffice and there's no extra IPC overhead.
    """
    BUILD_DIR.mkdir(parents=True, exist_ok=True)

    sources = list(_discover_sources())
    if not sources:
        print("no scenario or micro sources to build (yet)", file=sys.stderr)
        return 0

    targets: list[tuple[Path, Path]] = []
    for src in sources:
        out = BUILD_DIR / src.stem
        if out.exists() and not args.force:
            print(f"skip   {src.relative_to(PROJECT_ROOT)} (exe up to date; --force to rebuild)")
            continue
        targets.append((src, out))

    if not targets:
        return 0

    cpu = os.cpu_count() or 1
    # Cap at 4 - parallel `dart compile exe` can spike RAM (~1 GB each peak)
    # and we don't want to OOM on 16 GB machines. Override with --workers.
    workers = args.workers if args.workers else min(cpu, 4)
    print(f"building {len(targets)} target(s) with {workers} parallel worker(s)")

    failed: list[Path] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        future_to_src = {pool.submit(_compile_one, src, out): src for src, out in targets}
        for future in concurrent.futures.as_completed(future_to_src):
            src = future_to_src[future]
            ok = future.result()
            status = "ok  " if ok else "FAIL"
            print(f"{status}  {src.relative_to(PROJECT_ROOT)}")
            if not ok:
                failed.append(src)

    if failed:
        print(f"\n{len(failed)} build(s) failed", file=sys.stderr)
        return 1
    return 0


def _compile_one(src: Path, out: Path) -> bool:
    """Single `dart compile exe` invocation. Suppresses stdout, surfaces stderr on failure."""
    result = subprocess.run(
        ["dart", "compile", "exe", str(src), "-o", str(out)],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        print(f"\n--- {src.name} stderr ---\n{result.stderr}\n", file=sys.stderr)
        return False
    return True


# ---- subcommand: run ------------------------------------------------------


def cmd_run(args: argparse.Namespace) -> int:
    """Execute each AOT scenario once with `--iterations N`, capture JSON.

    Output structure (per scenario):
        <outdir>/
        |- <scenario-name>/
        |   `- iterations.json    # one JSON array with N records
        `- aggregated.json        # all records across all scenarios

    Iterations are batched into one subprocess per scenario, saving N-1
    process startups per scenario. The scenario body loops 0..N-1 internally
    with forceGc + settle between iterations.
    """
    # Resolve to absolute up front - we pass this path to subprocesses with
    # `cwd=PROJECT_ROOT`, so a relative `--out` from the user's shell cwd
    # would resolve to a different directory inside the subprocess.
    outdir = Path(args.out).resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    exes = sorted(BUILD_DIR.glob("*"))
    if not exes:
        print("no compiled scenarios found - run `build` first", file=sys.stderr)
        return 1

    scenarios = _filter_by_name(exes, args.scenarios)
    all_records: list[ResultRecord] = []

    git_sha = _current_git_sha()
    package_version = _current_package_version()
    per_scenario_overrides = _parse_duration_overrides(args.duration)

    for exe in scenarios:
        scenario_outdir = outdir / exe.stem
        scenario_outdir.mkdir(parents=True, exist_ok=True)
        duration = _resolve_duration(
            exe.stem,
            global_override=args.duration_seconds,
            per_scenario=per_scenario_overrides,
        )
        print(f"\nrun    {exe.stem}  ({args.iterations} iterations, {duration}s each)")

        out_json = scenario_outdir / "iterations.json"
        result = subprocess.run(
            [
                str(exe),
                "--iterations",
                str(args.iterations),
                "--output",
                str(out_json),
                "--git-sha",
                git_sha,
                "--package-version",
                package_version,
                "--duration-seconds",
                str(duration),
            ],
            cwd=PROJECT_ROOT,
            check=False,
        )
        if result.returncode != 0:
            print(f"  FAILED (exit {result.returncode})", file=sys.stderr)
            continue
        try:
            records = json.loads(out_json.read_text())
            if isinstance(records, list):
                all_records.extend(records)
                print(f"  captured {len(records)} record(s)")
            else:
                all_records.append(records)
                print("  captured 1 record")
        except json.JSONDecodeError as e:
            print(f"  BAD JSON: {e}", file=sys.stderr)

    aggregated_path = outdir / "aggregated.json"
    aggregated_path.write_text(json.dumps(all_records, indent=2))
    print(f"\nwrote aggregated results: {aggregated_path}")
    print(f"  total records: {len(all_records)}")

    return 0


# ---- subcommand: compare --------------------------------------------------


def cmd_compare(args: argparse.Namespace) -> int:
    """Diff two aggregated.json result sets with Mann-Whitney U.

    Output: table of (scenario, metric, baseline median, current median,
    delta %, p-value, significant?).
    """
    try:
        from scipy import stats as scipy_stats
    except ImportError:
        print(
            "scipy required - run `uv sync` from benchmark/python/",
            file=sys.stderr,
        )
        return 1

    baseline = _load_aggregated(args.baseline)
    current = _load_aggregated(args.current)

    base_groups = _group_samples(baseline)
    curr_groups = _group_samples(current)

    header = (
        f"{'scenario':<24} {'metric':<28} "
        f"{'baseline':>12} {'current':>12} {'delta':>10} {'p-value':>10} {'sig?':<5}"
    )
    print(header)
    print("-" * 105)

    any_significant = False
    for key in sorted(set(base_groups) | set(curr_groups)):
        scenario, metric = key
        base_samples = base_groups.get(key, [])
        curr_samples = curr_groups.get(key, [])
        if not base_samples or not curr_samples:
            continue

        base_median = float(_median(base_samples))
        curr_median = float(_median(curr_samples))
        delta_pct = (
            (curr_median - base_median) / base_median * 100.0 if base_median else float("inf")
        )

        try:
            _u_stat, p_value = scipy_stats.mannwhitneyu(
                base_samples, curr_samples, alternative="two-sided"
            )
        except ValueError:
            # All samples identical - Mann-Whitney undefined. Treat as not significant.
            p_value = 1.0
        significant = p_value < 0.05
        any_significant = any_significant or significant

        sig_marker = "*" if significant else ""
        print(
            f"{scenario:<24} {metric:<28} "
            f"{base_median:>12.3f} {curr_median:>12.3f} "
            f"{delta_pct:>+9.1f}% {p_value:>10.4f} {sig_marker:<5}"
        )

    print()
    if any_significant:
        print("* = statistically significant at p < 0.05 (Mann-Whitney U)")
    else:
        print("no significant differences detected")

    return 0


# ---- subcommand: report ---------------------------------------------------


def cmd_report(args: argparse.Namespace) -> int:
    """Generate PNG charts + SUMMARY.md from one aggregated.json file.

    Default output dir is `<aggregated.json parent>/charts/` (contributor-local,
    gitignored under `results-local/`). With `--reference`, writes to
    `benchmark/charts/reference/` (committed - this is the maintainer's
    blessed reference set inlined in the README).

    Charts (one PNG each):
    - headline_tick_drift.png  - max scheduler stall per scenario (THE bug viz)
    - memory_peak_rss.png      - peak RSS per scenario
    - scenario_stability.png   - noise floor (slow_observer excluded)
    - subscriber_scaling.png   - broadcast cost vs N (from status_emission)

    Plus SUMMARY.md - per-chart sections with summary tables above each PNG.
    The maintainer can drop SUMMARY.md content into the package README.
    """
    # Fail-fast probe for analysis deps. Chart helpers import these per-function
    # so the build/run subcommands stay usable when only the orchestration deps
    # are available; cmd_report needs the full stack.
    import importlib.util as _importlib_util

    missing = [
        name
        for name in ("matplotlib", "polars", "seaborn", "pandas")
        if _importlib_util.find_spec(name) is None
    ]
    if missing:
        print(f"missing analysis deps: {', '.join(missing)}", file=sys.stderr)
        print("  run `uv sync` from benchmark/python/", file=sys.stderr)
        return 1

    import polars as pl
    import seaborn as sns

    records = _load_aggregated(args.results)
    if not records:
        print("no records found in input", file=sys.stderr)
        return 1

    out_dir = _resolve_report_outdir(args)
    out_dir.mkdir(parents=True, exist_ok=True)

    # Flatten records into a DataFrame. We carry both metadata cols
    # (scenario, iteration, git_sha, ...) and summary metrics in one frame.
    rows = _flatten_records(records)
    dataframe = pl.DataFrame(rows, infer_schema_length=None)

    # Seaborn theme: whitegrid + paper context = readable in a markdown viewer
    # without looking like a presentation slide.
    sns.set_theme(style="whitegrid", context="paper", palette=_CHART_PALETTE)

    chart_paths: list[Path] = []
    chart_paths.append(_plot_headline_tick_drift(dataframe, out_dir / "headline_tick_drift.png"))
    chart_paths.append(_plot_memory_peak_rss(dataframe, out_dir / "memory_peak_rss.png"))
    chart_paths.append(_plot_scenario_stability(dataframe, out_dir / "scenario_stability.png"))

    sub_chart = _plot_subscriber_scaling(dataframe, out_dir / "subscriber_scaling.png")
    if sub_chart is not None:
        chart_paths.append(sub_chart)

    summary_path = out_dir / "SUMMARY.md"
    summary_path.write_text(
        _render_summary_markdown(dataframe, chart_paths=chart_paths, records=records)
    )

    print(f"\nwrote charts + summary to: {out_dir}")
    for p in chart_paths:
        print(f"  {p.name}")
    print(f"  {summary_path.name}")

    return 0


def _resolve_report_outdir(args: argparse.Namespace) -> Path:
    """Pick the chart output directory based on flags.

    Precedence: --reference > --out > default (<results parent>/charts/).
    """
    if args.reference:
        return REFERENCE_CHARTS_DIR
    if args.out:
        return Path(args.out)
    return Path(args.results).parent / "charts"


def _flatten_records(records: list[ResultRecord]) -> list[dict[str, Any]]:
    """Flatten each record's `summary` block into a single row.

    Per-iteration raw `samples` arrays stay in the record; for chart
    rendering we use the pre-computed summary metrics (median, peak, etc).
    """
    out: list[dict[str, Any]] = []
    for rec in records:
        flat: dict[str, Any] = {
            "scenario": rec.get("scenario", "?"),
            "iteration": rec.get("iteration", -1),
            "git_sha": rec.get("git_sha", "?"),
            "package_version": rec.get("package_version", "?"),
            "sdk_version": rec.get("sdk_version", "?"),
        }
        summary: dict[str, Any] = rec.get("summary", {})
        flat.update(summary)
        out.append(flat)
    return out


# ---- chart renderers ------------------------------------------------------


def _plot_headline_tick_drift(dataframe: Any, out_path: Path) -> Path:
    """Box plot of max_drift_microseconds per scenario, log y-scale.

    `slow_observer` stalls the scheduler with sleep(50ms) every 100ms tick.
    On the log y-axis its box will tower ~3 orders of magnitude above the
    other scenarios - that gap IS the bug story.
    """
    import matplotlib.pyplot as plt
    import polars as pl
    import seaborn as sns

    metric = "max_drift_microseconds"
    plot_df = (
        dataframe.filter(pl.col(metric).is_not_null()).select(["scenario", metric]).to_pandas()
    )
    if plot_df.empty:
        _write_empty_chart(out_path, "No tick-drift data found.")
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
    fig.savefig(out_path, dpi=_CHART_DPI)
    plt.close(fig)
    return out_path


def _plot_memory_peak_rss(dataframe: Any, out_path: Path) -> Path:
    """Box plot of peak_rss_bytes per scenario, MB on y-axis."""
    import matplotlib.pyplot as plt
    import polars as pl
    import seaborn as sns

    metric = "peak_rss_bytes"
    plot_df = (
        dataframe.filter(pl.col(metric).is_not_null()).select(["scenario", metric]).to_pandas()
    )
    if plot_df.empty:
        _write_empty_chart(out_path, "No peak_rss data found.")
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
    fig.savefig(out_path, dpi=_CHART_DPI)
    plt.close(fig)
    return out_path


def _plot_scenario_stability(dataframe: Any, out_path: Path) -> Path:
    """Box plot of max_drift_microseconds EXCLUDING slow_observer.

    Slow observer's tick-drift is ~1000x the others, so it dominates the
    y-scale of the headline chart. Excluding it here lets the noise floor
    of the other scenarios be readable. Narrow boxes = reproducible.
    """
    import matplotlib.pyplot as plt
    import polars as pl
    import seaborn as sns

    metric = "max_drift_microseconds"
    plot_df = (
        dataframe.filter(pl.col(metric).is_not_null())
        .filter(pl.col("scenario") != "slow_observer")
        .select(["scenario", metric])
        .to_pandas()
    )
    if plot_df.empty:
        _write_empty_chart(out_path, "No non-slow_observer drift data found.")
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
    fig.savefig(out_path, dpi=_CHART_DPI)
    plt.close(fig)
    return out_path


def _plot_subscriber_scaling(dataframe: Any, out_path: Path) -> Path | None:
    """Line plot of `microseconds_per_emission` vs subscriber_count.

    Uses the `status_emission` micro: synchronous broadcast cost in
    isolation. Production `InternetConnection` uses async broadcast where
    the producer pays constant cost regardless of N; this chart isolates
    the per-listener delivery cost.

    Returns None (and writes nothing) when there's no status_emission data
    in the input - the caller skips the slot in SUMMARY.md.
    """
    import matplotlib.pyplot as plt
    import polars as pl
    import seaborn as sns

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
        errorbar=("pi", 50),  # show IQR (25th-75th percentile band)
        marker="o",
        linestyle="-",
        color="#4c72b0",
    )
    ax.set_xlabel("Subscriber count")
    ax.set_ylabel("Broadcast cost (us / emit)")
    ax.set_title("Sync-broadcast cost scales linearly with subscribers")
    plt.tight_layout()
    fig.savefig(out_path, dpi=_CHART_DPI)
    plt.close(fig)
    return out_path


def _write_empty_chart(out_path: Path, message: str) -> None:
    """Render a 'no data' placeholder PNG. Keeps the SUMMARY.md image refs valid."""
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(8, 4))
    ax.text(0.5, 0.5, message, ha="center", va="center", fontsize=12, color="#888")
    ax.set_axis_off()
    fig.savefig(out_path, dpi=_CHART_DPI)
    plt.close(fig)


# ---- summary markdown -----------------------------------------------------


def _render_summary_markdown(
    dataframe: Any,
    *,
    chart_paths: list[Path],
    records: list[ResultRecord],
) -> str:
    """Render SUMMARY.md - per-chart sections with a table above each PNG.

    The maintainer can drop this verbatim into the package README, or
    excerpt the sections most relevant to a given release.
    """
    import polars as pl

    metadata = _summary_metadata(records)
    chart_names = {p.name for p in chart_paths}

    parts: list[str] = []
    parts.append("# Benchmark results\n")
    parts.append(
        f"Captured **{metadata['date']}** against "
        f"`{metadata['package_version']}` at `{metadata['git_sha']}` "
        f"on Dart SDK {metadata['sdk_version']}. N={metadata['iterations']} "
        "iterations per scenario.\n"
    )
    parts.append(
        "> Per-machine measurements. Numbers below reflect *this* machine "
        "(CPU, GC, OS scheduler, thermal state). Your numbers WILL differ - "
        "capture your own local baseline before measuring a code delta.\n"
    )

    parts.append("## Headline: worst-case scheduler stall per scenario\n")
    parts.append(
        "The `slow_observer` scenario simulates a heavy synchronous observer "
        "(50 ms per callback) running against a 100 ms tick. Pre-refactor, "
        "this blocks the scheduler - the box for `slow_observer` should "
        "tower over the others on the log axis below.\n"
    )
    parts.append(_metric_table(dataframe, "max_drift_microseconds", units="us"))
    if "headline_tick_drift.png" in chart_names:
        parts.append("\n![Headline tick drift](headline_tick_drift.png)\n")

    parts.append("## Peak resident set size per scenario\n")
    parts.append(
        "Peak RSS captured via `ProcessInfo.currentRss` sampled every 500 ms "
        "(every 250 ms in `long_running`). The package's memory footprint "
        "baseline; future refactors should not regress this without reason.\n"
    )
    parts.append(_metric_table(dataframe, "peak_rss_bytes", units="MB"))
    if "memory_peak_rss.png" in chart_names:
        parts.append("\n![Memory peak RSS](memory_peak_rss.png)\n")

    parts.append("## Stability: noise floor across scenarios (slow_observer excluded)\n")
    parts.append(
        "Same metric as the headline chart, but with the `slow_observer` "
        "outlier excluded so the y-scale is readable. A narrow box = the "
        "metric is reproducible iteration-to-iteration.\n"
    )
    parts.append(
        _metric_table(
            dataframe,
            "max_drift_microseconds",
            units="us",
            exclude_scenario="slow_observer",
        )
    )
    if "scenario_stability.png" in chart_names:
        parts.append("\n![Scenario stability](scenario_stability.png)\n")

    if "subscriber_scaling.png" in chart_names:
        parts.append("## Subscriber scaling: broadcast cost vs N listeners\n")
        parts.append(
            "From the `status_emission` micro (synchronous broadcast, "
            "isolated from the rest of the package). Production "
            "`InternetConnection` uses async-default broadcast where the "
            "producer pays a constant cost regardless of N; this chart "
            "isolates the per-listener *delivery* cost.\n"
        )
        parts.append(
            _subscriber_scaling_table(dataframe.filter(pl.col("scenario") == "status_emission"))
        )
        parts.append("\n![Subscriber scaling](subscriber_scaling.png)\n")

    return "\n".join(parts)


def _summary_metadata(records: list[ResultRecord]) -> dict[str, str]:
    """Pull captured-at + version metadata from the first record for the header."""
    first = records[0] if records else {}
    return {
        "date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "git_sha": str(first.get("git_sha", "unknown")),
        "package_version": str(first.get("package_version", "unknown")),
        "sdk_version": str(first.get("sdk_version", "unknown")),
        "iterations": str(_records_per_scenario(records)),
    }


def _records_per_scenario(records: list[ResultRecord]) -> int:
    """How many records belong to the most-emitted scenario.

    A single scenario emits one record per iteration (with the exception of
    `many_subscribers` and `status_emission`, which emit 3 per iteration -
    those over-count, but the header value is informational and we pick the
    mode rather than the max).
    """
    counts: dict[str, int] = {}
    for r in records:
        s = str(r.get("scenario", "?"))
        counts[s] = counts.get(s, 0) + 1
    if not counts:
        return 0
    # Use the most common scalar-scenario count, ignoring the multi-record ones.
    multi = {"many_subscribers", "status_emission"}
    scalar_counts = [v for k, v in counts.items() if k not in multi]
    if scalar_counts:
        return max(scalar_counts)
    return max(counts.values())


def _metric_table(
    dataframe: Any,
    metric: str,
    *,
    units: str,
    exclude_scenario: str | None = None,
) -> str:
    """Render a markdown table: per-scenario {N, median, IQR, min, max} for a metric.

    `units = "MB"` divides byte-valued numbers by 1024^2 before display.
    `units = "us"` displays as integer microseconds. Other units pass through.
    """
    import polars as pl

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

    fmt = _value_formatter(units)
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


def _subscriber_scaling_table(dataframe: Any) -> str:
    """Render a markdown table indexed by subscriber_count for status_emission."""
    import polars as pl

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

    fmt = _value_formatter("us")
    header = "| Subscribers | N | Median (us/emit) | IQR (us) |"
    sep = "|---:|---:|---:|---:|"
    rows = [header, sep]
    for row in agg.iter_rows(named=True):
        iqr = row["q75"] - row["q25"]
        rows.append(
            f"| {row['subscriber_count']} | {row['n']} | {fmt(row['median'])} | {fmt(iqr)} |"
        )
    return "\n".join(rows) + "\n"


def _value_formatter(units: str):
    """Return a unary fn that formats a numeric value for the requested units.

    Precision tier: large values (>= 1000) round to integers with thousands
    separators; mid values (1 to 1000) get two decimal places; sub-1 values
    get three. Keeps both the slow_observer headline (~1.8M us) and the
    status_emission micro (~0.13 us / emit) readable in the same table.
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


# ---- helpers --------------------------------------------------------------


def _discover_sources() -> Iterable[Path]:
    """Yield all .dart entry-point files under scenarios/ and micro/."""
    for d in (SCENARIOS_DIR, MICRO_DIR):
        if d.exists():
            yield from sorted(d.glob("*.dart"))


def _filter_by_name(exes: list[Path], wanted: list[str] | None) -> list[Path]:
    if not wanted:
        return exes
    wanted_set = set(wanted)
    return [e for e in exes if e.stem in wanted_set]


def _load_aggregated(path: str | Path) -> list[ResultRecord]:
    return json.loads(Path(path).read_text())


def _group_samples(records: list[ResultRecord]) -> dict[tuple[str, str], list[float]]:
    """Flatten records into `{(scenario, metric): [all samples across iterations]}`."""
    groups: dict[tuple[str, str], list[float]] = {}
    for rec in records:
        scenario: str = rec.get("scenario", "?")
        samples: dict[str, Any] = rec.get("samples", {})
        for metric, values in samples.items():
            if not isinstance(values, list):
                continue
            key = (scenario, metric)
            groups.setdefault(key, []).extend(v for v in values if isinstance(v, int | float))
    return groups


def _parse_duration_overrides(raw: list[str] | None) -> dict[str, int]:
    """Parse `--duration scenario=N` flag values into a `{scenario: seconds}` map."""
    if not raw:
        return {}
    out: dict[str, int] = {}
    for entry in raw:
        if "=" not in entry:
            print(f"--duration expects scenario=N, got: {entry}", file=sys.stderr)
            sys.exit(64)
        scenario, value = entry.split("=", 1)
        try:
            out[scenario.strip()] = int(value)
        except ValueError:
            print(f"--duration value must be int, got: {value}", file=sys.stderr)
            sys.exit(64)
    return out


def _resolve_duration(
    scenario: str,
    *,
    global_override: int | None,
    per_scenario: dict[str, int],
) -> int:
    """Per-scenario duration resolution: per-scenario > global > map default > fallback."""
    if scenario in per_scenario:
        return per_scenario[scenario]
    if global_override is not None:
        return global_override
    return SCENARIO_DURATIONS.get(scenario, _FALLBACK_DURATION)


def _current_git_sha() -> str:
    """Return the current git HEAD short SHA, or 'unknown' if git is unavailable."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "unknown"
    return result.stdout.strip() or "unknown"


def _current_package_version() -> str:
    """Read the `version:` field from the root `pubspec.yaml`.

    Avoids pulling in `pyyaml` for one field - a line-prefix scan is enough.
    Returns 'unknown' if not found.
    """
    pubspec = PROJECT_ROOT / "pubspec.yaml"
    if not pubspec.exists():
        return "unknown"
    for line in pubspec.read_text().splitlines():
        if line.startswith("version:"):
            return line.split(":", 1)[1].strip()
    return "unknown"


def _median(values: list[float]) -> float:
    sorted_vals = sorted(values)
    n = len(sorted_vals)
    if n == 0:
        return 0.0
    if n % 2 == 1:
        return sorted_vals[n // 2]
    return (sorted_vals[n // 2 - 1] + sorted_vals[n // 2]) / 2.0


# ---- CLI ------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    parser_build = sub.add_parser("build", help="AOT-compile every scenario and micro source")
    parser_build.add_argument(
        "--force",
        action="store_true",
        help="rebuild even if exe is up to date",
    )
    parser_build.add_argument(
        "--workers",
        type=int,
        default=0,
        help="parallel compile workers (default: min(cpu_count, 4))",
    )
    parser_build.set_defaults(func=cmd_build)

    parser_run = sub.add_parser("run", help="execute compiled scenarios N times, write JSON")
    parser_run.add_argument(
        "--iterations",
        type=int,
        default=DEFAULT_ITERATIONS,
        help=f"iterations per scenario (default {DEFAULT_ITERATIONS})",
    )
    parser_run.add_argument(
        "--out",
        default=str(RESULTS_DIR / "latest"),
        help="output directory for per-scenario JSON files",
    )
    parser_run.add_argument(
        "--scenarios",
        nargs="*",
        help="restrict to named scenarios (default: all)",
    )
    parser_run.add_argument(
        "--duration-seconds",
        type=int,
        default=None,
        help=(
            "global wall-clock duration override applied to every scenario. "
            "Default: use the per-scenario value from SCENARIO_DURATIONS."
        ),
    )
    parser_run.add_argument(
        "--duration",
        action="append",
        metavar="SCENARIO=SECONDS",
        help=(
            "per-scenario duration override (repeatable). "
            "Example: --duration long_running=3600 --duration quiet_app=30. "
            "Takes precedence over --duration-seconds."
        ),
    )
    parser_run.set_defaults(func=cmd_run)

    parser_compare = sub.add_parser(
        "compare",
        help="Mann-Whitney U diff of two aggregated.json files",
    )
    parser_compare.add_argument("baseline", help="path to baseline aggregated.json")
    parser_compare.add_argument("current", help="path to current aggregated.json")
    parser_compare.set_defaults(func=cmd_compare)

    parser_report = sub.add_parser(
        "report",
        help="render PNG charts + SUMMARY.md from aggregated.json",
    )
    parser_report.add_argument("results", help="path to aggregated.json")
    parser_report.add_argument(
        "--out",
        default=None,
        help=(
            "output dir for charts + SUMMARY.md. Default: "
            "<aggregated.json parent>/charts/. Ignored when --reference is set."
        ),
    )
    parser_report.add_argument(
        "--reference",
        action="store_true",
        help=(
            "write to benchmark/charts/reference/ (committed maintainer baseline). "
            "Use after capturing the canonical reference run."
        ),
    )
    parser_report.set_defaults(func=cmd_report)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
