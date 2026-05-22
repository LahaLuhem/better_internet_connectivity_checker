"""Tests for `bicc_bench.data.utils.markdown`.

Focuses on the precision-aware value_formatter and the table renderers
(metric_table, render_compare_table_markdown). Chart embeds in the
top-level render_*_markdown functions are integration-tested via the
end-to-end smoke; here we hit the deterministic pieces.
"""

from __future__ import annotations

import math

import polars as pl

from bicc_bench.data.dtos.compare_row import CompareRow
from bicc_bench.data.dtos.result_record import ResultRecord, flatten_records
from bicc_bench.data.utils.markdown import (
    metric_table,
    render_compare_table_markdown,
    subscriber_scaling_table,
    value_formatter,
)


class TestValueFormatterMicroseconds:
    """`units="us"` uses the precision-tier formatter.

    Pin the contract: large drifts stay readable as integers; small
    micro-benchmark numbers keep their decimal places.
    """

    def test_large_value_thousands_separated_integer(self) -> None:
        fmt = value_formatter("us")
        assert fmt(1_812_265) == "1,812,265"

    def test_mid_value_two_decimals(self) -> None:
        fmt = value_formatter("us")
        assert fmt(1.03) == "1.03"
        assert fmt(8.99) == "8.99"

    def test_sub_one_value_three_decimals(self) -> None:
        fmt = value_formatter("us")
        assert fmt(0.138) == "0.138"

    def test_exact_thousand_boundary(self) -> None:
        # 1000 hits the >= 1000 tier - integer format
        fmt = value_formatter("us")
        assert fmt(1000) == "1,000"

    def test_exact_one_boundary(self) -> None:
        # 1 hits the >= 1 tier - two decimals
        fmt = value_formatter("us")
        assert fmt(1) == "1.00"

    def test_negative_uses_magnitude_for_tier(self) -> None:
        # abs(-5000) >= 1000 -> integer format with sign preserved
        fmt = value_formatter("us")
        assert fmt(-5000) == "-5,000"

    def test_none_renders_as_dash(self) -> None:
        fmt = value_formatter("us")
        assert fmt(None) == "-"


class TestValueFormatterMegabytes:
    def test_bytes_to_mb_with_two_decimals(self) -> None:
        fmt = value_formatter("MB")
        # 32 MiB = 33554432 B
        assert fmt(33_554_432) == "32.00"

    def test_handles_fractional_mb(self) -> None:
        fmt = value_formatter("MB")
        # 1.5 MiB = 1572864 B
        assert fmt(1_572_864) == "1.50"

    def test_none_renders_as_dash(self) -> None:
        fmt = value_formatter("MB")
        assert fmt(None) == "-"


class TestValueFormatterDefault:
    def test_freeform_two_decimals(self) -> None:
        fmt = value_formatter("anything-else")
        assert fmt(3.14159) == "3.14"

    def test_none_renders_as_dash(self) -> None:
        fmt = value_formatter("freeform")
        assert fmt(None) == "-"


class TestMetricTable:
    def test_missing_metric_returns_placeholder(
        self,
        sample_records: list[ResultRecord],
    ) -> None:
        df = pl.DataFrame(flatten_records(sample_records), infer_schema_length=None)
        result = metric_table(df, "metric_we_dont_have", units="us")
        assert "no `metric_we_dont_have` data" in result

    def test_renders_header_row_per_scenario(
        self,
        sample_records: list[ResultRecord],
    ) -> None:
        df = pl.DataFrame(flatten_records(sample_records), infer_schema_length=None)
        result = metric_table(df, "max_drift_microseconds", units="us")
        # Header row
        assert "| Scenario | N |" in result
        # Both scenarios with max_drift_microseconds present
        assert "`quiet_app`" in result
        assert "`slow_observer`" in result

    def test_exclude_scenario_filters(
        self,
        sample_records: list[ResultRecord],
    ) -> None:
        df = pl.DataFrame(flatten_records(sample_records), infer_schema_length=None)
        result = metric_table(
            df, "max_drift_microseconds", units="us", exclude_scenario="slow_observer"
        )
        assert "`quiet_app`" in result
        assert "`slow_observer`" not in result

    def test_exclude_removes_all_data_returns_placeholder(
        self,
        sample_records: list[ResultRecord],
    ) -> None:
        df = pl.DataFrame(flatten_records(sample_records), infer_schema_length=None)
        # Exclude the only scenario - placeholder triggers
        result = metric_table(df, "peak_rss_bytes", units="MB", exclude_scenario="quiet_app")
        assert "no `peak_rss_bytes` data" in result


class TestSubscriberScalingTable:
    def test_renders_per_subscriber_row(
        self,
        sample_records: list[ResultRecord],
    ) -> None:
        df = pl.DataFrame(flatten_records(sample_records), infer_schema_length=None)
        result = subscriber_scaling_table(df)
        assert "| Subscribers |" in result
        assert "| 1 |" in result
        assert "| 10 |" in result
        assert "| 100 |" in result

    def test_missing_columns_returns_placeholder(self) -> None:
        df = pl.DataFrame([{"scenario": "x", "other": 1}])
        result = subscriber_scaling_table(df)
        assert "no status_emission data" in result


class TestRenderCompareTableMarkdown:
    def _row(
        self,
        scenario: str = "x",
        metric: str = "y",
        baseline: float = 100.0,
        current: float = 110.0,
        delta: float = 10.0,
        p: float = 0.5,
    ) -> CompareRow:
        return CompareRow(
            scenario=scenario,
            metric=metric,
            baseline_median=baseline,
            current_median=current,
            delta_pct=delta,
            p_value=p,
        )

    def test_empty_rows_returns_just_header(self) -> None:
        result = render_compare_table_markdown([])
        # Header + separator only, no data rows
        assert result.count("\n") == 2

    def test_significant_row_marked_yes(self) -> None:
        rows = [self._row(p=0.001)]
        result = render_compare_table_markdown(rows)
        assert "**Yes**" in result

    def test_non_significant_row_blank(self) -> None:
        rows = [self._row(p=0.5)]
        result = render_compare_table_markdown(rows)
        # Last column should be empty (no "Yes")
        assert "**Yes**" not in result

    def test_finite_delta_rendered_with_sign(self) -> None:
        rows = [self._row(delta=10.5), self._row(delta=-5.2)]
        result = render_compare_table_markdown(rows)
        assert "+10.5%" in result
        assert "-5.2%" in result

    def test_infinite_delta_rendered_as_inf(self) -> None:
        rows = [self._row(delta=math.inf)]
        result = render_compare_table_markdown(rows)
        assert "| inf |" in result
        # Should NOT crash on inf or render "+inf%"
        assert "+inf" not in result
