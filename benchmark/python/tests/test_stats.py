"""Tests for `bicc_bench.data.utils.stats`.

The math here is pure and deterministic - perfect regression-prevention
target. Covers median, group_samples, records_per_scenario, and
compute_compare_rows (the cmd_compare workhorse).
"""

from __future__ import annotations

import math

import pytest

from bicc_bench.data.dtos.result_record import ResultRecord
from bicc_bench.data.utils.stats import (
    compute_compare_rows,
    group_samples,
    median,
    records_per_scenario,
)


class TestMedian:
    def test_empty_returns_zero(self) -> None:
        assert median([]) == 0.0

    def test_single_value(self) -> None:
        assert median([42.0]) == 42.0

    def test_odd_count(self) -> None:
        assert median([1.0, 2.0, 3.0]) == 2.0

    def test_even_count_averages_middle_two(self) -> None:
        assert median([1.0, 2.0, 3.0, 4.0]) == 2.5

    def test_unsorted_input(self) -> None:
        assert median([3.0, 1.0, 2.0]) == 2.0

    def test_negatives(self) -> None:
        assert median([-3.0, -1.0, -2.0]) == -2.0

    def test_floats(self) -> None:
        assert median([0.1, 0.2, 0.3]) == pytest.approx(0.2)


class TestGroupSamples:
    def test_empty_returns_empty(self) -> None:
        assert group_samples([]) == {}

    def test_groups_by_scenario_and_metric(self, sample_records: list[ResultRecord]) -> None:
        groups = group_samples(sample_records)
        # quiet_app emitted rss_bytes and tick_drift_microseconds samples
        # across 3 iterations (3 samples each per iteration = 9 total).
        assert ("quiet_app", "rss_bytes") in groups
        assert ("quiet_app", "tick_drift_microseconds") in groups
        assert len(groups[("quiet_app", "rss_bytes")]) == 9
        assert len(groups[("quiet_app", "tick_drift_microseconds")]) == 9

    def test_slow_observer_drift_collected(self, sample_records: list[ResultRecord]) -> None:
        groups = group_samples(sample_records)
        drifts = groups[("slow_observer", "tick_drift_microseconds")]
        # 2 iterations x 3 samples each = 6 values
        assert len(drifts) == 6
        # All in the bug range
        assert all(d >= 1_800_000 for d in drifts)

    def test_summary_only_records_have_no_samples(self) -> None:
        records: list[ResultRecord] = [
            {"scenario": "no_samples", "samples": {}, "summary": {"x": 1}},
        ]
        assert group_samples(records) == {}

    def test_non_list_sample_value_skipped(self) -> None:
        # Defensive: if a record has e.g. `samples: {"x": "not a list"}`,
        # the helper must skip rather than crash.
        records: list[ResultRecord] = [
            {"scenario": "weird", "samples": {"x": "not a list"}, "summary": {}},
        ]
        assert group_samples(records) == {}

    def test_non_numeric_values_filtered(self) -> None:
        records: list[ResultRecord] = [
            {"scenario": "weird", "samples": {"x": [1, 2, "three", 4]}, "summary": {}},
        ]
        assert group_samples(records) == {("weird", "x"): [1.0, 2.0, 4.0]}


class TestRecordsPerScenario:
    def test_empty_returns_zero(self) -> None:
        assert records_per_scenario([]) == 0

    def test_picks_scalar_scenario_count(self, sample_records: list[ResultRecord]) -> None:
        # quiet_app has 3 records, slow_observer has 2, status_emission has 3
        # (but it's multi-record, so ignored). Max scalar count = 3.
        assert records_per_scenario(sample_records) == 3

    def test_ignores_multi_record_scenarios(self) -> None:
        # If status_emission's 3 records were counted as 3 iterations,
        # this would return 3. The correct value is 1 (only quiet_app's count).
        records: list[ResultRecord] = [
            {"scenario": "quiet_app", "iteration": 0, "samples": {}, "summary": {}},
            {"scenario": "status_emission", "iteration": 0, "samples": {}, "summary": {}},
            {"scenario": "status_emission", "iteration": 0, "samples": {}, "summary": {}},
            {"scenario": "status_emission", "iteration": 0, "samples": {}, "summary": {}},
        ]
        assert records_per_scenario(records) == 1

    def test_falls_back_to_max_when_all_multi_record(self) -> None:
        records: list[ResultRecord] = [
            {"scenario": "many_subscribers", "iteration": 0, "samples": {}, "summary": {}},
            {"scenario": "many_subscribers", "iteration": 0, "samples": {}, "summary": {}},
            {"scenario": "status_emission", "iteration": 0, "samples": {}, "summary": {}},
        ]
        assert records_per_scenario(records) == 2


class TestComputeCompareRows:
    def test_empty_inputs_return_empty(self) -> None:
        assert compute_compare_rows([], []) == []

    def test_rows_only_for_pairs_in_both_runs(
        self,
        baseline_records: list[ResultRecord],
        current_records: list[ResultRecord],
    ) -> None:
        rows = compute_compare_rows(baseline_records, current_records)
        # Both runs have quiet_app/tick_drift and slow_observer/tick_drift.
        keys = {(r.scenario, r.metric) for r in rows}
        assert ("quiet_app", "tick_drift_microseconds") in keys
        assert ("slow_observer", "tick_drift_microseconds") in keys

    def test_slow_observer_collapse_is_significant_improvement(
        self,
        baseline_records: list[ResultRecord],
        current_records: list[ResultRecord],
    ) -> None:
        rows = compute_compare_rows(baseline_records, current_records)
        slow = next(
            r
            for r in rows
            if r.scenario == "slow_observer" and r.metric == "tick_drift_microseconds"
        )
        # Drift dropped from ~1.8M to ~18k - that's ~-99%
        assert slow.delta_pct < -90
        assert slow.significant
        # Improvement direction
        assert slow.current_median < slow.baseline_median

    def test_quiet_app_unchanged_not_significant(
        self,
        baseline_records: list[ResultRecord],
        current_records: list[ResultRecord],
    ) -> None:
        rows = compute_compare_rows(baseline_records, current_records)
        quiet = next(
            r for r in rows if r.scenario == "quiet_app" and r.metric == "tick_drift_microseconds"
        )
        # quiet_app samples are identical between baseline and current.
        # Mann-Whitney on identical samples is undefined - we coerce to p=1.0.
        assert not quiet.significant
        assert quiet.p_value == 1.0
        assert quiet.delta_pct == 0.0

    def test_zero_baseline_yields_infinite_delta(self) -> None:
        baseline: list[ResultRecord] = [
            {"scenario": "x", "iteration": 0, "samples": {"m": [0.0, 0.0, 0.0]}, "summary": {}},
        ]
        current: list[ResultRecord] = [
            {"scenario": "x", "iteration": 0, "samples": {"m": [1.0, 2.0, 3.0]}, "summary": {}},
        ]
        rows = compute_compare_rows(baseline, current)
        assert len(rows) == 1
        assert math.isinf(rows[0].delta_pct)
        assert not rows[0].delta_finite
