#!/usr/bin/env python3
"""Orchestrator for the `better_internet_connectivity_checker` benchmark suite.

Workflow (run from `benchmark/python/`):

    uv sync                                      # one-time: create .venv + install deps
    uv run python run.py build                   # AOT-compile all scenarios
    uv run python run.py run --iterations 10 --out results/run-1/
    uv run python run.py compare baseline.json results/run-1/aggregated.json
    uv run python run.py report results/run-1/aggregated.json --out report.html

Design notes:
- Dart owns scenario *bodies* (must be in-process — instantiates the lib,
  observes streams). Each scenario is AOT-compiled for deterministic warmup.
- This Python script owns *orchestration + analysis* — invokes the AOT
  scenarios via subprocess, aggregates per-iteration JSON, runs statistical
  significance tests (Mann-Whitney U via scipy.stats), wrangles result sets
  with polars, renders charts via matplotlib, and generates HTML reports
  via Jinja2.

Methodology rules (do not break — see ../README.md for rationale):
- AOT compile, not JIT (`dart compile exe`).
- N >= 10 iterations per scenario. Report median + IQR.
- Mann-Whitney U for significance claims. p < 0.05.
- Warmup iterations discarded (first 2 of every 10).
- AC power, no competing apps.
- Localhost HTTP only — no real network.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from collections.abc import Iterable
from pathlib import Path
from typing import Any, Final

# ---- paths ----------------------------------------------------------------

THIS_FILE: Final[Path] = Path(__file__).resolve()
BENCHMARK_DIR: Final[Path] = THIS_FILE.parent.parent
PROJECT_ROOT: Final[Path] = BENCHMARK_DIR.parent
SCENARIOS_DIR: Final[Path] = BENCHMARK_DIR / "scenarios"
MICRO_DIR: Final[Path] = BENCHMARK_DIR / "micro"
BUILD_DIR: Final[Path] = BENCHMARK_DIR / "build"
RESULTS_DIR: Final[Path] = BENCHMARK_DIR / "results"

# Default number of iterations per scenario. Override with --iterations.
DEFAULT_ITERATIONS: Final[int] = 10

# How many warmup iterations to discard from every run. Phase 1 doesn't
# enforce this yet - the analyzer trims when computing aggregates.
WARMUP_ITERATIONS: Final[int] = 2

# JSON-decoded scenario records have a fixed schema (see README §5), but the
# Python json module returns `Any` for everything. We narrow to `dict[str, Any]`
# here and validate-on-use rather than ceremony with TypedDict / pydantic
# models for a tool with a stable internal schema. `Any` is justified.
ResultRecord = dict[str, Any]


# ---- subcommand: build ----------------------------------------------------


def cmd_build(args: argparse.Namespace) -> int:
    """AOT-compile every .dart file under scenarios/ and micro/ to BUILD_DIR.

    Uses `dart compile exe`. Skips files that compile cleanly already unless
    --force is given. AOT compilation is required for deterministic warmup
    characteristics — JIT introduces too much variance.
    """
    BUILD_DIR.mkdir(parents=True, exist_ok=True)

    sources = list(_discover_sources())
    if not sources:
        print("no scenario or micro sources to build (yet)", file=sys.stderr)
        return 0

    failed: list[Path] = []
    for src in sources:
        out = BUILD_DIR / src.stem
        if out.exists() and not args.force:
            print(f"skip   {src.relative_to(PROJECT_ROOT)} (exe up to date; --force to rebuild)")
            continue
        print(f"build  {src.relative_to(PROJECT_ROOT)}")
        result = subprocess.run(
            ["dart", "compile", "exe", str(src), "-o", str(out)],
            cwd=PROJECT_ROOT,
        )
        if result.returncode != 0:
            failed.append(src)

    if failed:
        print(f"\n{len(failed)} build(s) failed", file=sys.stderr)
        return 1
    return 0


# ---- subcommand: run ------------------------------------------------------


def cmd_run(args: argparse.Namespace) -> int:
    """Execute each AOT scenario N times, capture per-iteration JSON.

    Output structure:
        <outdir>/
        ├── <scenario-1>/
        │   ├── iter-00.json
        │   ├── iter-01.json
        │   └── ...
        └── aggregated.json    # all records concatenated for analysis
    """
    outdir = Path(args.out)
    outdir.mkdir(parents=True, exist_ok=True)

    exes = sorted(BUILD_DIR.glob("*"))
    if not exes:
        print("no compiled scenarios found — run `build` first", file=sys.stderr)
        return 1

    scenarios = _filter_by_name(exes, args.scenarios)
    all_records: list[ResultRecord] = []

    git_sha = _current_git_sha()
    package_version = _current_package_version()

    for exe in scenarios:
        scenario_outdir = outdir / exe.stem
        scenario_outdir.mkdir(parents=True, exist_ok=True)
        print(f"\nrun    {exe.stem}  ({args.iterations} iterations)")

        for i in range(args.iterations):
            out_json = scenario_outdir / f"iter-{i:02d}.json"
            result = subprocess.run(
                [
                    str(exe),
                    "--iteration",
                    str(i),
                    "--output",
                    str(out_json),
                    "--git-sha",
                    git_sha,
                    "--package-version",
                    package_version,
                    "--duration-seconds",
                    str(args.duration_seconds),
                ],
                cwd=PROJECT_ROOT,
                check=False,
            )
            if result.returncode != 0:
                print(f"  iter {i:02d}  FAILED (exit {result.returncode})", file=sys.stderr)
                continue
            try:
                records = json.loads(out_json.read_text())
                if isinstance(records, list):
                    all_records.extend(records)
                else:
                    all_records.append(records)
                print(f"  iter {i:02d}  ok")
            except json.JSONDecodeError as e:
                print(f"  iter {i:02d}  BAD JSON: {e}", file=sys.stderr)

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
            "scipy required — run `uv sync` from benchmark/python/",
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
    """Generate an HTML report from one aggregated.json file.

    Phase 1 (now): per-scenario summary table with median over iterations of
    every summary metric. polars handles the group-by; HTML is hand-rendered
    (no pandas dep). Matplotlib charts land in Phase 2 once we have real
    baseline data to plot.
    """
    try:
        import polars as pl
    except ImportError:
        print(
            "polars required - run `uv sync` from benchmark/python/",
            file=sys.stderr,
        )
        return 1

    records = _load_aggregated(args.results)
    if not records:
        print("no records found in input", file=sys.stderr)
        return 1

    # Flatten each record's `summary` block into a single row. `samples`
    # (the raw arrays) are deferred until Phase 2 charting.
    rows: list[dict[str, Any]] = []
    metadata_cols = {"scenario", "iteration", "git_sha", "package_version", "sdk_version"}
    for rec in records:
        flat: dict[str, Any] = {
            "scenario": rec.get("scenario", "?"),
            "iteration": rec.get("iteration", -1),
            "git_sha": rec.get("git_sha", "?"),
            "package_version": rec.get("package_version", "?"),
            "sdk_version": rec.get("sdk_version", "?"),
        }
        summary: dict[str, Any] = rec.get("summary", {})
        for metric, value in summary.items():
            flat[metric] = value
        rows.append(flat)

    dataframe = pl.DataFrame(rows, infer_schema_length=None)
    metric_cols = [c for c in dataframe.columns if c not in metadata_cols]
    numeric_metrics = [
        c
        for c in metric_cols
        if dataframe.schema[c].is_numeric()  # type: ignore[union-attr]
    ]

    # Median across iterations per scenario.
    aggregated = dataframe.group_by("scenario").agg(
        [pl.col(c).median().alias(c) for c in numeric_metrics],
    )

    html = _render_summary_html(aggregated, scenarios=list(dataframe["scenario"].unique()))
    Path(args.out).write_text(html)
    print(f"wrote report: {args.out}")
    print(f"  scenarios summarised: {dataframe['scenario'].n_unique()}")
    print(f"  total records: {len(records)}")

    return 0


def _render_summary_html(df: Any, *, scenarios: list[str]) -> str:
    """Render a polars DataFrame as an HTML summary table. No pandas required."""
    cols: list[str] = df.columns
    rows_html: list[str] = []
    for row in df.iter_rows(named=True):
        cells = "".join(f"<td>{_format_cell(row[c])}</td>" for c in cols)
        rows_html.append(f"<tr>{cells}</tr>")
    header = "".join(f"<th>{c}</th>" for c in cols)

    scenarios_label = ", ".join(scenarios) if scenarios else "(none)"

    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>bicc benchmark report</title>
<style>
  body {{ font-family: -apple-system, system-ui, sans-serif; margin: 2em; }}
  table {{ border-collapse: collapse; margin-top: 1em; }}
  th, td {{ border: 1px solid #ccc; padding: 4px 8px; text-align: right; }}
  th:first-child, td:first-child {{ text-align: left; font-weight: 600; }}
  tr:nth-child(even) {{ background: #f7f7f7; }}
  .meta {{ color: #666; font-size: 0.9em; }}
</style>
</head>
<body>
<h1>bicc benchmark report</h1>
<p class="meta">scenarios: {scenarios_label}</p>
<table>
  <thead><tr>{header}</tr></thead>
  <tbody>
{chr(10).join("    " + r for r in rows_html)}
  </tbody>
</table>
<p class="meta">Charts + Mann-Whitney comparisons land in Phase 2.</p>
</body>
</html>
"""


def _format_cell(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, float):
        return f"{value:,.1f}"
    if isinstance(value, int):
        return f"{value:,}"
    return str(value)


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

    Avoids pulling in `pyyaml` for one field — a line-prefix scan is enough.
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
        default=str(BENCHMARK_DIR / "results-local" / "latest"),
        help="output directory for per-iteration JSON files",
    )
    parser_run.add_argument(
        "--scenarios",
        nargs="*",
        help="restrict to named scenarios (default: all)",
    )
    parser_run.add_argument(
        "--duration-seconds",
        type=int,
        default=10,
        help="per-scenario wall-clock duration; micros ignore this (default 10)",
    )
    parser_run.set_defaults(func=cmd_run)

    parser_compare = sub.add_parser(
        "compare",
        help="Mann-Whitney U diff of two aggregated.json files",
    )
    parser_compare.add_argument("baseline", help="path to baseline aggregated.json")
    parser_compare.add_argument("current", help="path to current aggregated.json")
    parser_compare.set_defaults(func=cmd_compare)

    parser_report = sub.add_parser("report", help="render HTML report from aggregated.json")
    parser_report.add_argument("results", help="path to aggregated.json")
    parser_report.add_argument("--out", default="report.html", help="output HTML path")
    parser_report.set_defaults(func=cmd_report)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
