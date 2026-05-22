"""`CompareRow` - one row in the cmd_compare significance table.

Drives both the terminal output and the COMPARE.md table + forest plot.
Frozen dataclass: this is a value object, not a mutable record.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from bicc_bench.config import SIGNIFICANCE_THRESHOLD


@dataclass(frozen=True)
class CompareRow:
    """One `(scenario, metric)` comparison between baseline and current runs.

    `delta_pct` is `math.inf` when the baseline median is 0 and the delta is
    therefore undefined - renderers must guard for that with `math.isfinite`.
    """

    scenario: str
    metric: str
    baseline_median: float
    current_median: float
    delta_pct: float
    p_value: float

    @property
    def significant(self) -> bool:
        return self.p_value < SIGNIFICANCE_THRESHOLD

    @property
    def delta_finite(self) -> bool:
        return math.isfinite(self.delta_pct)
