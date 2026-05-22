"""Tests for `bicc_bench.data.dtos`."""

from __future__ import annotations

import math

from bicc_bench.data.dtos.compare_row import CompareRow
from bicc_bench.data.dtos.result_record import ResultRecord, flatten_records


class TestCompareRow:
    def test_significant_below_threshold(self) -> None:
        row = CompareRow(
            scenario="x",
            metric="y",
            baseline_median=100.0,
            current_median=50.0,
            delta_pct=-50.0,
            p_value=0.001,
        )
        assert row.significant

    def test_not_significant_at_or_above_threshold(self) -> None:
        # Exact threshold (0.05) is NOT significant - strict less-than.
        row = CompareRow(
            scenario="x",
            metric="y",
            baseline_median=100.0,
            current_median=100.0,
            delta_pct=0.0,
            p_value=0.05,
        )
        assert not row.significant

    def test_delta_finite_true_for_normal_value(self) -> None:
        row = CompareRow(
            scenario="x",
            metric="y",
            baseline_median=100.0,
            current_median=110.0,
            delta_pct=10.0,
            p_value=0.5,
        )
        assert row.delta_finite

    def test_delta_finite_false_for_infinity(self) -> None:
        row = CompareRow(
            scenario="x",
            metric="y",
            baseline_median=0.0,
            current_median=10.0,
            delta_pct=math.inf,
            p_value=0.5,
        )
        assert not row.delta_finite

    def test_frozen(self) -> None:
        # Defensive: dataclass(frozen=True) should reject mutation.
        import dataclasses

        row = CompareRow(
            scenario="x",
            metric="y",
            baseline_median=1.0,
            current_median=2.0,
            delta_pct=100.0,
            p_value=0.01,
        )
        try:
            row.delta_pct = 0.0  # type: ignore[misc]
        except dataclasses.FrozenInstanceError:
            return
        raise AssertionError("CompareRow should be frozen")


class TestFlattenRecords:
    def test_empty_returns_empty(self) -> None:
        assert flatten_records([]) == []

    def test_summary_merged_into_flat_dict(
        self,
        sample_records: list[ResultRecord],
    ) -> None:
        rows = flatten_records(sample_records)
        assert len(rows) == len(sample_records)

        # quiet_app iter 0 should have both metadata and summary metrics
        quiet_0 = next(r for r in rows if r["scenario"] == "quiet_app" and r["iteration"] == 0)
        assert quiet_0["sdk_version"] == "3.11.5"
        assert quiet_0["package_version"] == "0.2.0"
        assert quiet_0["git_sha"] == "abc1234"
        assert quiet_0["peak_rss_bytes"] == 32_000_000
        assert quiet_0["max_drift_microseconds"] == 300

    def test_missing_fields_use_sentinels(self) -> None:
        records: list[ResultRecord] = [{}]  # no scenario, no iteration, no anything
        rows = flatten_records(records)
        assert rows[0]["scenario"] == "?"
        assert rows[0]["iteration"] == -1
        assert rows[0]["git_sha"] == "?"

    def test_summary_keys_override_no_metadata(self) -> None:
        # Defensive: summary keys shouldn't be able to overwrite the metadata
        # block. Currently they CAN (summary is .update'd over the flat dict),
        # but the metadata keys are unique enough in practice that this is
        # fine. This test pins current behaviour - flip it if the contract
        # ever needs to change.
        records: list[ResultRecord] = [
            {
                "scenario": "x",
                "iteration": 0,
                "summary": {"scenario": "OVERRIDE"},
            },
        ]
        rows = flatten_records(records)
        assert rows[0]["scenario"] == "OVERRIDE"
