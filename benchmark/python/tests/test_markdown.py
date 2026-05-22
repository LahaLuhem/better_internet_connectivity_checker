"""Tests for `bicc_bench.data.utils.markdown`.

Covers the precision-aware value_formatter, the table renderers
(metric_table, subscriber_scaling_table, render_compare_table_markdown),
plus structural assertions on the top-level render_summary_markdown /
render_compare_markdown that verify section headers, embed branches,
and chart-name conditionals. Heading text is the maintainer's
README-drop contract, so a section rename is the kind of regression
worth catching here.
"""

from __future__ import annotations

import math
from pathlib import Path

import polars as pl

from bicc_bench.data.dtos.compare_row import CompareRow
from bicc_bench.data.dtos.result_record import ResultRecord, flatten_records
from bicc_bench.data.utils.markdown import (
    metric_table,
    render_compare_markdown,
    render_compare_table_markdown,
    render_summary_markdown,
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

    def test_all_null_values_returns_placeholder(self) -> None:
        # Columns exist but every row has nulls -> filter empties the df
        # before the agg, hitting the second placeholder branch.
        df = pl.DataFrame(
            {
                "scenario": ["status_emission"],
                "subscriber_count": [None],
                "microseconds_per_emission": [None],
            }
        )
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


class TestRenderSummaryMarkdown:
    def _df(self, records: list[ResultRecord]) -> pl.DataFrame:
        return pl.DataFrame(flatten_records(records), infer_schema_length=None)

    def test_renders_all_sections_when_all_charts_present(
        self,
        sample_records: list[ResultRecord],
    ) -> None:
        df = self._df(sample_records)
        chart_paths = [
            Path("headline_tick_drift.png"),
            Path("memory_peak_rss.png"),
            Path("scenario_stability.png"),
            Path("subscriber_scaling.png"),
        ]
        result = render_summary_markdown(df, chart_paths=chart_paths, records=sample_records)

        # Header block
        assert "# Benchmark results\n" in result
        # All four h2 sections rendered
        assert "## Headline: worst-case scheduler stall per scenario" in result
        assert "## Peak resident set size per scenario" in result
        assert "## Stability: noise floor across scenarios" in result
        assert "## Subscriber scaling: broadcast cost vs N listeners" in result
        # All four chart embeds
        assert "![Headline tick drift](headline_tick_drift.png)" in result
        assert "![Memory peak RSS](memory_peak_rss.png)" in result
        assert "![Scenario stability](scenario_stability.png)" in result
        assert "![Subscriber scaling](subscriber_scaling.png)" in result
        # Metadata bled into header
        assert "abc1234" in result  # git_sha from sample_records
        assert "0.2.0" in result  # package_version
        assert "3.11.5" in result  # sdk_version

    def test_renders_without_chart_embeds_when_chart_paths_empty(
        self,
        sample_records: list[ResultRecord],
    ) -> None:
        df = self._df(sample_records)
        result = render_summary_markdown(df, chart_paths=[], records=sample_records)

        # Three always-rendered h2 sections (subscriber_scaling is the only
        # section gated entirely on chart presence; the other three render
        # their tables even without the chart).
        assert "## Headline: worst-case scheduler stall per scenario" in result
        assert "## Peak resident set size per scenario" in result
        assert "## Stability: noise floor across scenarios" in result
        # Subscriber scaling section is wrapped in `if chart present`, so
        # without the chart its h2 should NOT appear.
        assert "## Subscriber scaling" not in result
        # No image embeds anywhere
        assert "![" not in result


class TestRenderCompareMarkdown:
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

    def test_renders_all_sections_when_all_charts_present(
        self,
        baseline_records: list[ResultRecord],
        current_records: list[ResultRecord],
    ) -> None:
        rows = [self._row(scenario="quiet_app", metric="tick_drift_microseconds", p=0.5)]
        chart_paths = [
            Path("compare_forest.png"),
            Path("compare_headline_tick_drift.png"),
            Path("compare_memory_peak_rss.png"),
            Path("compare_scenario_stability.png"),
            Path("compare_subscriber_scaling.png"),
        ]
        result = render_compare_markdown(
            rows,
            chart_paths=chart_paths,
            baseline_records=baseline_records,
            current_records=current_records,
        )

        # Header + both run metadata blocks
        assert "# Benchmark comparison\n" in result
        assert "**Baseline**" in result
        assert "**Current**" in result
        # Section headers
        assert "## Forest: all comparable" in result
        assert "## Headline: tick drift" in result
        assert "## Memory: peak RSS" in result
        assert "## Stability: noise floor" in result
        assert "## Subscriber scaling, baseline vs current" in result
        assert "## Mann-Whitney U significance table" in result
        # All five chart embeds
        assert "![Forest plot](compare_forest.png)" in result
        assert "![Headline compare](compare_headline_tick_drift.png)" in result
        assert "![Memory compare](compare_memory_peak_rss.png)" in result
        assert "![Stability compare](compare_scenario_stability.png)" in result
        assert "![Scaling compare](compare_subscriber_scaling.png)" in result
        # Significance table includes the row
        assert "`quiet_app`" in result
        assert "`tick_drift_microseconds`" in result

    def test_renders_without_chart_embeds_when_chart_paths_empty(
        self,
        baseline_records: list[ResultRecord],
        current_records: list[ResultRecord],
    ) -> None:
        result = render_compare_markdown(
            [],
            chart_paths=[],
            baseline_records=baseline_records,
            current_records=current_records,
        )

        # Sections present unconditionally
        assert "## Forest: all comparable" in result
        assert "## Headline: tick drift" in result
        assert "## Memory: peak RSS" in result
        assert "## Stability: noise floor" in result
        # Subscriber scaling section is chart-gated - absent here
        assert "## Subscriber scaling, baseline vs current" not in result
        # Mann-Whitney always renders even with no rows
        assert "## Mann-Whitney U significance table" in result
        # No image embeds
        assert "![" not in result
