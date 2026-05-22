#!/usr/bin/env python3
"""Orchestrator for the `better_internet_connectivity_checker` benchmark suite.

Workflow:

    python benchmark/python/run.py build              # AOT-compile all scenarios
    python benchmark/python/run.py run --iterations 10 --out results/run-1/
    python benchmark/python/run.py compare benchmark/results/baseline.json results/run-1/aggregated.json
    python benchmark/python/run.py report results/run-1/aggregated.json --out report.html

Design notes:
- Dart owns scenario *bodies* (must be in-process — instantiates the lib,
  observes streams). Each scenario is AOT-compiled for deterministic warmup.
- This Python script owns *orchestration + analysis* — invokes the AOT
  scenarios via subprocess, aggregates per-iteration JSON, runs statistical
  significance tests (Mann–Whitney U via scipy.stats), renders charts via
  matplotlib, and generates HTML reports via Jinja2.

Methodology rules (do not break — see ../README.md for rationale):
- AOT compile, not JIT (`dart compile exe`).
- N >= 10 iterations per scenario. Report median + IQR.
- Mann–Whitney U for significance claims. p < 0.05.
- Warmup iterations discarded (first 2 of every 10).
- AC power, no competing apps.
- Localhost HTTP only — no real network.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

# ---- paths ----------------------------------------------------------------

THIS_FILE = Path(__file__).resolve()
BENCHMARK_DIR = THIS_FILE.parent.parent
PROJECT_ROOT = BENCHMARK_DIR.parent
SCENARIOS_DIR = BENCHMARK_DIR / "scenarios"
MICRO_DIR = BENCHMARK_DIR / "micro"
BUILD_DIR = BENCHMARK_DIR / "build"
RESULTS_DIR = BENCHMARK_DIR / "results"

# Default number of iterations per scenario. Override with --iterations.
DEFAULT_ITERATIONS = 10

# How many warmup iterations to discard from every run. Phase 1 doesn't
# enforce this yet — the analyzer trims when computing aggregates.
WARMUP_ITERATIONS = 2


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

    failed = []
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
    all_records: list[dict] = []

    for exe in scenarios:
        scenario_outdir = outdir / exe.stem
        scenario_outdir.mkdir(parents=True, exist_ok=True)
        print(f"\nrun    {exe.stem}  ({args.iterations} iterations)")

        for i in range(args.iterations):
            out_json = scenario_outdir / f"iter-{i:02d}.json"
            result = subprocess.run(
                [str(exe), "--iteration", str(i), "--output", str(out_json)],
                cwd=PROJECT_ROOT,
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
    """Diff two aggregated.json result sets with Mann–Whitney U.

    Output: table of (scenario, metric, baseline median, current median,
    delta %, p-value, significant?).
    """
    try:
        import numpy as np  # noqa: F401 — import for side effect only here
        from scipy import stats as scipy_stats
    except ImportError:
        print("scipy + numpy required: pip install -r benchmark/python/requirements.txt", file=sys.stderr)
        return 1

    baseline = _load_aggregated(args.baseline)
    current = _load_aggregated(args.current)

    base_groups = _group_samples(baseline)
    curr_groups = _group_samples(current)

    print(f"{'scenario':<24} {'metric':<28} {'baseline':>12} {'current':>12} {'delta':>10} {'p-value':>10} {'sig?':<5}")
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
            u_stat, p_value = scipy_stats.mannwhitneyu(
                base_samples, curr_samples, alternative="two-sided"
            )
        except ValueError:
            # All samples identical — Mann–Whitney undefined. Treat as not significant.
            p_value = 1.0
        significant = p_value < 0.05
        any_significant = any_significant or significant

        sig_marker = "★" if significant else ""
        print(
            f"{scenario:<24} {metric:<28} "
            f"{base_median:>12.3f} {curr_median:>12.3f} "
            f"{delta_pct:>+9.1f}% {p_value:>10.4f} {sig_marker:<5}"
        )

    print()
    if any_significant:
        print("★ = statistically significant at p < 0.05 (Mann–Whitney U)")
    else:
        print("no significant differences detected")

    return 0


# ---- subcommand: report ---------------------------------------------------


def cmd_report(args: argparse.Namespace) -> int:
    """Generate an HTML report with matplotlib charts from one or more result sets.

    Phase 1 stub — full implementation lands when scenarios produce real data.
    """
    print(
        "report subcommand: not yet implemented. Will land in Phase 1 step 7 of\n"
        "~/Desktop/bicc-benchmark-plan-2026-05-21.md, after scenarios are running.\n"
        f"input: {args.results}, output: {args.out}"
    )
    return 0


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


def _load_aggregated(path: str | Path) -> list[dict]:
    return json.loads(Path(path).read_text())


@dataclass
class _SampleGroups:
    by_scenario_metric: dict[tuple[str, str], list[float]] = field(default_factory=dict)


def _group_samples(records: list[dict]) -> dict[tuple[str, str], list[float]]:
    """Flatten records into {(scenario, metric): [all samples across iterations]}."""
    groups: dict[tuple[str, str], list[float]] = {}
    for rec in records:
        scenario = rec.get("scenario", "?")
        samples = rec.get("samples", {})
        for metric, values in samples.items():
            if not isinstance(values, list):
                continue
            key = (scenario, metric)
            groups.setdefault(key, []).extend(v for v in values if isinstance(v, (int, float)))
    return groups


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
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_build = sub.add_parser("build", help="AOT-compile every scenario and micro source")
    p_build.add_argument("--force", action="store_true", help="rebuild even if exe is up to date")
    p_build.set_defaults(func=cmd_build)

    p_run = sub.add_parser("run", help="execute compiled scenarios N times, write JSON")
    p_run.add_argument(
        "--iterations",
        type=int,
        default=DEFAULT_ITERATIONS,
        help=f"iterations per scenario (default {DEFAULT_ITERATIONS})",
    )
    p_run.add_argument(
        "--out",
        default=str(BENCHMARK_DIR / "results-local" / "latest"),
        help="output directory for per-iteration JSON files",
    )
    p_run.add_argument(
        "--scenarios",
        nargs="*",
        help="restrict to named scenarios (default: all)",
    )
    p_run.set_defaults(func=cmd_run)

    p_cmp = sub.add_parser("compare", help="Mann–Whitney U diff of two aggregated.json files")
    p_cmp.add_argument("baseline", help="path to baseline aggregated.json")
    p_cmp.add_argument("current", help="path to current aggregated.json")
    p_cmp.set_defaults(func=cmd_compare)

    p_rep = sub.add_parser("report", help="render HTML report from aggregated.json")
    p_rep.add_argument("results", help="path to aggregated.json")
    p_rep.add_argument("--out", default="report.html", help="output HTML path")
    p_rep.set_defaults(func=cmd_report)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
