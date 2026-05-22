#!/usr/bin/env python3
"""Entry point for the `better_internet_connectivity_checker` benchmark suite.

Thin argparse + dispatch shim. Every subcommand lives under `bicc_bench/`:

- `build`    AOT-compile all scenarios (parallel) - see `bicc_bench.subcommands.build`
- `run`      execute scenarios, write per-scenario JSON   - `bicc_bench.subcommands.runner`
- `report`   render PNG charts + SUMMARY.md              - `bicc_bench.subcommands.report`
- `compare`  Mann-Whitney + paired charts + COMPARE.md   - `bicc_bench.subcommands.compare`

Workflow (run from `benchmark/python/`):

    uv sync                                       # one-time: create .venv + install deps
    uv run python run.py build                    # AOT-compile all scenarios
    uv run python run.py run --iterations 10 --out ../results-local/run-1/
    uv run python run.py report ../results-local/run-1/aggregated.json
    uv run python run.py compare ../results-local/baseline/aggregated.json \\
                                  ../results-local/run-1/aggregated.json

Both `report` and `compare` default to writing into `benchmark/reports/` -
the canonical committed dir referenced from the package README. Pass `--out`
to override (e.g. for ad-hoc local snapshots that shouldn't overwrite the
committed set).

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
import sys

from bicc_bench.config import DEFAULT_ITERATIONS, REPORTS_DIR, RESULTS_DIR
from bicc_bench.subcommands.build import cmd_build
from bicc_bench.subcommands.compare import cmd_compare
from bicc_bench.subcommands.report import cmd_report
from bicc_bench.subcommands.runner import cmd_run


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    _add_build_parser(sub)
    _add_run_parser(sub)
    _add_compare_parser(sub)
    _add_report_parser(sub)

    args = parser.parse_args(argv)
    return args.func(args)


def _add_build_parser(sub: argparse._SubParsersAction) -> None:
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


def _add_run_parser(sub: argparse._SubParsersAction) -> None:
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


def _add_compare_parser(sub: argparse._SubParsersAction) -> None:
    parser_compare = sub.add_parser(
        "compare",
        help="Mann-Whitney U diff of two aggregated.json files + paired charts",
    )
    parser_compare.add_argument("baseline", help="path to baseline aggregated.json")
    parser_compare.add_argument("current", help="path to current aggregated.json")
    parser_compare.add_argument(
        "--out",
        default=None,
        help=f"output dir for compare_*.png + COMPARE.md. Default: {REPORTS_DIR} (committed).",
    )
    parser_compare.set_defaults(func=cmd_compare)


def _add_report_parser(sub: argparse._SubParsersAction) -> None:
    parser_report = sub.add_parser(
        "report",
        help="render PNG charts + SUMMARY.md from aggregated.json",
    )
    parser_report.add_argument("results", help="path to aggregated.json")
    parser_report.add_argument(
        "--out",
        default=None,
        help=f"output dir for charts + SUMMARY.md. Default: {REPORTS_DIR} (committed).",
    )
    parser_report.set_defaults(func=cmd_report)


if __name__ == "__main__":
    sys.exit(main())
