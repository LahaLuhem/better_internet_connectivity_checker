"""Package-wide constants: paths, scenario defaults, chart style.

All values are `Final[...]` - reassignment is a bug, not a feature. Modules
import the constants they need; nothing here imports from other `bicc_bench`
modules (would create a cycle).
"""

from __future__ import annotations

from pathlib import Path
from typing import Final

# ---- paths ----------------------------------------------------------------

THIS_FILE: Final[Path] = Path(__file__).resolve()
# THIS_FILE lives at benchmark/python/bicc_bench/config.py. Walk up:
#   .parent         -> benchmark/python/bicc_bench/
#   .parent.parent  -> benchmark/python/         (PYTHON_DIR)
# Then BENCHMARK_DIR and PROJECT_ROOT are one and two parents above that.
PYTHON_DIR: Final[Path] = THIS_FILE.parent.parent
BENCHMARK_DIR: Final[Path] = PYTHON_DIR.parent
PROJECT_ROOT: Final[Path] = BENCHMARK_DIR.parent
SCENARIOS_DIR: Final[Path] = BENCHMARK_DIR / "scenarios"
MICRO_DIR: Final[Path] = BENCHMARK_DIR / "micro"
BUILD_DIR: Final[Path] = BENCHMARK_DIR / "build"
RESULTS_DIR: Final[Path] = BENCHMARK_DIR / "results-local"
# The canonical committed report+compare output dir. Both `report` and
# `compare` write here by default; both honour `--out` for ad-hoc locations.
# Referenced from the package README via committed PNGs, so contributors only
# overwrite this when refreshing the maintainer baseline.
REPORTS_DIR: Final[Path] = BENCHMARK_DIR / "reports"

# ---- scenario defaults ----------------------------------------------------

# Default number of iterations per scenario. Override with --iterations.
DEFAULT_ITERATIONS: Final[int] = 10

# How many warmup iterations to discard from every run. The analyzer trims
# when computing aggregates - the scenario itself emits every iteration.
WARMUP_ITERATIONS: Final[int] = 2

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
FALLBACK_DURATION: Final[int] = 10

# Scenarios that emit MORE THAN ONE record per iteration (one per
# subscriber_count). Used by `records_per_scenario` to pick a sensible
# "iterations per scenario" value for SUMMARY.md / COMPARE.md headers.
MULTI_RECORD_SCENARIOS: Final[frozenset[str]] = frozenset(
    {"many_subscribers", "status_emission"},
)

# ---- chart style ----------------------------------------------------------

# 150 DPI strikes the right balance for README inlining - sharp on retina
# without bloating the committed PNGs.
CHART_DPI: Final[int] = 150
CHART_PALETTE: Final[str] = "Set2"

# Forest plot colours - direction + significance encoded into one bar.
FOREST_COLOUR_REGRESSION: Final[str] = "#c0392b"  # red
FOREST_COLOUR_IMPROVEMENT: Final[str] = "#27ae60"  # green
FOREST_COLOUR_NOT_SIG: Final[str] = "#bdc3c7"  # gray

# Significance threshold for Mann-Whitney U test claims.
SIGNIFICANCE_THRESHOLD: Final[float] = 0.05
