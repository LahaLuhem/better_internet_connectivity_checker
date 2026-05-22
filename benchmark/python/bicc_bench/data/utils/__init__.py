"""Stateless helpers split by concern.

- `stats`     - median, group_samples, compute_compare_rows, records_per_scenario
- `meta`      - git_sha, package_version, summary_metadata, duration parsing
- `io`        - source discovery, name filtering, JSON load, outdir resolution
- `charts`    - PNG renderers (report + compare + forest)
- `markdown`  - SUMMARY.md / COMPARE.md renderers + value formatter
"""

from __future__ import annotations
