"""Benchmark orchestration + analysis for `better_internet_connectivity_checker`.

Package layout (mirrors `mysql_distillery`):

- `config`            - package-wide paths, scenario durations, chart constants
- `subcommands/`      - one module per CLI subcommand (build / runner / compare / report)
- `data/dtos/`        - value classes (one per file)
- `data/utils/`       - stateless helpers (stats, meta, io, charts, markdown)

The orchestrator entry point is `run.py` at the parent directory; it does
argparse + dispatch and nothing else. Everything callable lives here.
"""

from __future__ import annotations
