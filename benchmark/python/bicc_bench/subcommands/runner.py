"""`cmd_run` - execute each AOT scenario once with `--iterations N`.

Renamed from `run.py` to `runner.py` so it doesn't shadow the top-level
`run.py` entry script when Python resolves imports from `benchmark/python/`.
Iterations are batched into one subprocess per scenario - saves N-1 process
startups per scenario without breaking measurement isolation (each iteration
runs alone inside the process, with `forceGc` + 100 ms settle between).
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from bicc_bench.config import BUILD_DIR, PROJECT_ROOT
from bicc_bench.data.dtos.result_record import ResultRecord
from bicc_bench.data.utils.io import filter_by_name
from bicc_bench.data.utils.meta import (
    current_git_sha,
    current_package_version,
    parse_duration_overrides,
    resolve_duration,
)


def cmd_run(args: argparse.Namespace) -> int:
    """Execute each AOT scenario once with `--iterations N`, capture JSON.

    Output structure (per scenario):
        <outdir>/
        |- <scenario-name>/
        |   `- iterations.json    # one JSON array with N records
        `- aggregated.json        # all records across all scenarios
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

    scenarios = filter_by_name(exes, args.scenarios)
    all_records: list[ResultRecord] = []

    git_sha = current_git_sha()
    package_version = current_package_version()
    per_scenario_overrides = parse_duration_overrides(args.duration)

    for exe in scenarios:
        scenario_outdir = outdir / exe.stem
        scenario_outdir.mkdir(parents=True, exist_ok=True)
        duration = resolve_duration(
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
