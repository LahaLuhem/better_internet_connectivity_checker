"""Subcommands - one module per CLI verb.

Each module exposes a single `cmd_<verb>(args: argparse.Namespace) -> int`
that `run.py` dispatches to. Modules import their helpers from
`bicc_bench.data.utils` and value classes from `bicc_bench.data.dtos`.
"""

from __future__ import annotations
