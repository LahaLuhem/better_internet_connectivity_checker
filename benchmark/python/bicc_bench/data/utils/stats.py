"""Statistical helpers - pure math, no I/O. Highest-value test target.

`median` is hand-rolled (no numpy) because we never have enough samples to
matter, and the small surface keeps the dep graph clean. `group_samples`
flattens raw `samples` arrays across records for Mann-Whitney input.
`compute_compare_rows` is the cmd_compare workhorse extracted for unit-
testability.
"""

from __future__ import annotations

import math

from bicc_bench.config import MULTI_RECORD_SCENARIOS
from bicc_bench.data.dtos.compare_row import CompareRow
from bicc_bench.data.dtos.result_record import ResultRecord


def median(values: list[float]) -> float:
    """Median of `values`. Returns 0.0 for an empty list (caller's choice).

    Hand-rolled to avoid pulling numpy for a one-liner; our sample sizes
    are small enough that the pure-Python sort is fine.
    """
    sorted_vals = sorted(values)
    n = len(sorted_vals)
    if n == 0:
        return 0.0
    if n % 2 == 1:
        return float(sorted_vals[n // 2])
    return (sorted_vals[n // 2 - 1] + sorted_vals[n // 2]) / 2.0


def group_samples(
    records: list[ResultRecord],
) -> dict[tuple[str, str], list[float]]:
    """Flatten records into `{(scenario, metric): [all samples across iterations]}`.

    Reads ONLY the `samples` arrays (raw per-tick measurements), not the
    pre-computed `summary` scalars. Mann-Whitney prefers raw data: more
    samples = more statistical power.
    """
    groups: dict[tuple[str, str], list[float]] = {}
    for rec in records:
        scenario: str = rec.get("scenario", "?")
        samples: dict[str, object] = rec.get("samples", {})
        for metric, values in samples.items():
            if not isinstance(values, list):
                continue
            key = (scenario, metric)
            groups.setdefault(key, []).extend(
                float(v) for v in values if isinstance(v, int | float)
            )
    return groups


def records_per_scenario(records: list[ResultRecord]) -> int:
    """How many records belong to the most-emitted scalar scenario.

    A scalar scenario emits one record per iteration. Multi-record
    scenarios (`many_subscribers`, `status_emission`) emit one per
    subscriber count per iteration, so their counts would inflate the
    "iterations per scenario" header. We ignore them when picking the
    representative count, falling back to the overall max if every
    scenario is multi-record.
    """
    counts: dict[str, int] = {}
    for r in records:
        scenario = str(r.get("scenario", "?"))
        counts[scenario] = counts.get(scenario, 0) + 1
    if not counts:
        return 0
    scalar_counts = [v for k, v in counts.items() if k not in MULTI_RECORD_SCENARIOS]
    if scalar_counts:
        return max(scalar_counts)
    return max(counts.values())


def compute_compare_rows(
    baseline_records: list[ResultRecord],
    current_records: list[ResultRecord],
) -> list[CompareRow]:
    """Build the per-(scenario, metric) significance table.

    For every `(scenario, metric)` pair present in BOTH runs, compute:
    - baseline median, current median
    - delta % (or `math.inf` when baseline median is 0)
    - Mann-Whitney U two-sided p-value

    Runs that don't share a key are skipped (no fair comparison possible).
    Mann-Whitney is undefined when all samples are identical; we coerce
    that to `p = 1.0` so the row sorts as "no difference".

    scipy is imported inside this function so consumers of the dtos /
    config modules don't pay the scipy import cost transitively.
    """
    from scipy import stats as scipy_stats

    base_groups = group_samples(baseline_records)
    curr_groups = group_samples(current_records)

    rows: list[CompareRow] = []
    for key in sorted(set(base_groups) | set(curr_groups)):
        scenario, metric = key
        base_samples = base_groups.get(key, [])
        curr_samples = curr_groups.get(key, [])
        if not base_samples or not curr_samples:
            continue

        base_median = median(base_samples)
        curr_median = median(curr_samples)
        delta_pct = (curr_median - base_median) / base_median * 100.0 if base_median else math.inf

        try:
            _u_stat, p_value = scipy_stats.mannwhitneyu(
                base_samples, curr_samples, alternative="two-sided"
            )
        except ValueError:
            # All samples identical - Mann-Whitney undefined. Treat as not significant.
            p_value = 1.0

        rows.append(
            CompareRow(
                scenario=scenario,
                metric=metric,
                baseline_median=base_median,
                current_median=curr_median,
                delta_pct=delta_pct,
                p_value=float(p_value),
            )
        )

    return rows
