"""Filesystem + JSON helpers.

`discover_sources` walks the Dart source dirs. `filter_by_name` restricts
a path list to those whose stem matches a user-supplied set. `resolve_outdir`
picks where charts/markdown land (shared between `report` and `compare`).
`load_aggregated` is the only JSON-read path - everything goes through it
so we have one place to add validation if the schema drifts.
"""

from __future__ import annotations

import argparse
import json
from collections.abc import Iterable
from pathlib import Path

from bicc_bench.config import MICRO_DIR, REPORTS_DIR, SCENARIOS_DIR
from bicc_bench.data.dtos.result_record import ResultRecord


def discover_sources() -> Iterable[Path]:
    """Yield all .dart entry-point files under scenarios/ and micro/."""
    for d in (SCENARIOS_DIR, MICRO_DIR):
        if d.exists():
            yield from sorted(d.glob("*.dart"))


def filter_by_name(exes: list[Path], wanted: list[str] | None) -> list[Path]:
    """Restrict `exes` to those whose stem appears in `wanted`. None == no filter."""
    if not wanted:
        return exes
    wanted_set = set(wanted)
    return [e for e in exes if e.stem in wanted_set]


def load_aggregated(path: str | Path) -> list[ResultRecord]:
    """Read an `aggregated.json` file and return the list of records.

    The file is always a JSON array (see `cmd_run`); this helper just
    centralises the read so future schema validation lives in one place.
    """
    return json.loads(Path(path).read_text())


def resolve_outdir(args: argparse.Namespace) -> Path:
    """Pick the chart output directory used by both `report` and `compare`.

    Precedence: `--out` > default (`REPORTS_DIR` = `benchmark/reports/`,
    committed). The override is resolved to an absolute path so downstream
    subprocesses inheriting `cwd` see the same path the user typed.
    """
    if args.out:
        return Path(args.out).resolve()
    return REPORTS_DIR
